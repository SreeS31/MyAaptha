import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myaaptha_mobile/core/contacts/contact_import.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'package:myaaptha_mobile/features/shell/presentation/address_book_screen.dart';

class ContactApi extends MyAapthaApi {
  ContactApi():super(AuthTokenBundle(tokenType:'Bearer',accessToken:'test',refreshToken:'test',expiresIn:900));
  int saved=0,calls=0;
  @override Future<Map<String,dynamic>> addressBook({String query='',int afterId=0,int? circleId}) async => {'items':[],'total':saved,'nextCursor':null};
  @override Future<Map<String,dynamic>> addressBookProviders() async => {'google':false,'microsoft':false};
  String? connectedEmail;
  @override Future<Map<String,dynamic>> connectAddressBook(String email,String provider,bool organize) async {connectedEmail=email;throw const MyAapthaApiException('Unavailable',statusCode:503);}
  @override Future<List<Map<String,dynamic>>> addressCircles() async => [];
  @override Future<Map<String,dynamic>> importReviewedAddressBook(List<Map<String,dynamic>> contacts,String source,bool organize) async {saved+=contacts.length;calls++;return {'added':contacts.length,'updated':0,'unchanged':0,'organizationMessage':''};}
}
void main(){
  final reviewFixtures=jsonDecode(File('../../shared/contact-import-review-fixtures.json').readAsStringSync()) as List;
  for(final raw in reviewFixtures){
    final fixture=Map<String,dynamic>.from(raw as Map);
    test('shared contact review: ${fixture['name']}',(){
      final existing=(fixture['existing'] as List).cast<String>();
      final result=prepareContactReview((fixture['contacts'] as List).map((c)=>Map<String,dynamic>.from(c as Map)).toList(),existing);
      expect(result.length,fixture['expectedContacts']);
      expect({for(final circle in importCircleSuggestions(result,existing))circle['name']:circle['count']},fixture['expectedCircles']);
      expect(result.where((c)=>c['displayName']=='Unlabeled person').firstOrNull?['circleNames']??[],isEmpty);
    });
  }
  test('contact files retain phone-only contacts, multiple addresses and groups',(){
    final csv=parseContactCsv('Name,Phone 1 - Value,Phone 2 - Value,E-mail 1 - Value,Group Membership\n"Doe, Jane",1234567,7654321,jane@example.test,Family ::: College');
    expect(csv.single['phones'],['1234567','7654321']);expect(csv.single['groups'],['Family','College']);
    final vcf=parseContactVcard('BEGIN:VCARD\r\nTEL:tel:+1234567\r\nCATEGORIES:Family,College\r\nEND:VCARD\r\nBEGIN:VCARD\r\nFN;ENCODING=QUOTED-PRINTABLE:Jos=C3=A9\r\nEND:VCARD');
    expect(vcf.length,2);expect(vcf.first['displayName'],'+1234567');expect(vcf.last['displayName'],'José');
    expect(()=>parseContactCsv('Name\n"Bad'),throwsFormatException);
  });
  test('large imports send all contacts and can stop between batches',() async {
    final contacts=List.generate(2507,(i)=><String,dynamic>{'displayName':'Contact $i','phones':<String>[],'emails':<String>[],'organization':''});
    var calls=0,done=0;final result=await importContactBatches(contacts,(batch) async {calls++;expect(batch.length,lessThanOrEqualTo(100));return {'added':batch.length};},(value)=>done=value,()=>false);
    expect(result['added'],2507);expect(done,2507);expect(calls,26);
    calls=0;final stopped=await importContactBatches(contacts,(batch) async {calls++;return {'added':batch.length};},(_){},()=>calls==1);expect(stopped['processed'],100);
  });
  testWidgets('review keeps named contacts and saves only selected device contacts',(tester) async {
    final api=ContactApi();await tester.pumpWidget(MaterialApp(home:AddressBookScreen(api:api,readDeviceContacts:()async=>List.generate(201,(i)=>{'displayName':'Contact $i','phones':i==200?<String>[]:<String>['+15551234567'],'emails':<String>[],'organization':''}))));await tester.pumpAndSettle();
    await tester.tap(find.text('Other ways to import'));await tester.pumpAndSettle();await tester.ensureVisible(find.text('Import all device contacts'));await tester.tap(find.text('Import all device contacts'));await tester.pump(const Duration(milliseconds:400));expect(api.saved,0);expect(find.text('Review contacts'),findsOneWidget);
    await tester.tap(find.text('Contact 0'));await tester.pump(const Duration(milliseconds:400));
    await tester.tap(find.text('Import selected'));await tester.pumpAndSettle();expect(api.saved,200);expect(api.calls,2);
  });
  testWidgets('provider sign-in is available without an email form or owner setup',(tester) async {
    final api=ContactApi();await tester.pumpWidget(MaterialApp(home:AddressBookScreen(api:api)));await tester.pumpAndSettle();
    final google=find.widgetWithText(FilledButton,'Sign in with Google');
    await tester.scrollUntilVisible(google,200,scrollable:find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(google).onPressed,isNotNull);
    expect(find.widgetWithText(TextField,'Google or Outlook email'),findsNothing);
    await tester.tap(google);await tester.pumpAndSettle();
    expect(find.textContaining('Google contact import is temporarily unavailable'),findsOneWidget);expect(api.calls,0);expect(api.connectedEmail,'');
  });
  testWidgets('permission denial leaves the address book unchanged',(tester) async {
    final api=ContactApi();await tester.pumpWidget(MaterialApp(home:AddressBookScreen(api:api,readDeviceContacts:()async=>throw const MyAapthaApiException('Permission denied. Nothing was uploaded.'))));await tester.pumpAndSettle();
    await tester.tap(find.text('Other ways to import'));await tester.pumpAndSettle();await tester.ensureVisible(find.text('Import all device contacts'));await tester.tap(find.text('Import all device contacts'));await tester.pumpAndSettle();expect(api.calls,0);expect(find.text('Permission denied. Nothing was uploaded.'),findsOneWidget);
  });
}
