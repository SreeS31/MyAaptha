import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  late ApiClient client;

  setUp(() {
    client = ApiClient(
      baseUrl: 'http://localhost:8080',
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );
  });

  test('rejects oversized search values before sending', () async {
    await expectLater(
      client.get('/api/network/search?q=${List.filled(201, 'x').join()}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects control characters and oversized message bodies', () async {
    await expectLater(
      client.post('/api/test', {'message': 'bad\u0000value'}),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      client.post('/api/test', {'message': List.filled(4001, 'x').join()}),
      throwsA(isA<FormatException>()),
    );
  });

  test('accepts bounded nested payloads', () async {
    final response = await client.post('/api/test', {
      'displayName': 'Rambabu',
      'messages': [
        {'message': 'Hello'}
      ],
    });
    expect(response.statusCode, 200);
  });

  test('blocks executable names and disguised upload contents', () async {
    await expectLater(
      client.postMultipart(
        '/api/test/upload',
        {},
        fileName: 'photo.jpg.exe',
        fileBytes: Uint8List.fromList([0x4d, 0x5a, 0x00]),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      client.postMultipart(
        '/api/test/upload',
        {},
        fileName: 'report.pdf',
        fileBytes: Uint8List.fromList('not a pdf'.codeUnits),
      ),
      throwsA(isA<FormatException>()),
    );
  });
  test('native upload sends the chosen expiry from the shared API options', () async {
    final choices=[1,7,30,60,90,180,365,730,1095,1825,3650,0];
    int selected=7;String? uploaded;
    ApiClient.retentionChooser=(level)async{expect(level['retentionDaysOptions'],choices);return selected;};
    addTearDown(()=>ApiClient.retentionChooser=null);
    final api=ApiClient(baseUrl:'http://localhost:8080',httpClient:MockClient((request) async {
      if(request.url.path=='/api/uploads/policy')return http.Response(jsonEncode({'level':{'storageBytes':1073741824,'uploadBytes':26214400},'usedBytes':0,'retentionDaysOptions':choices}),200);
      uploaded=request.body;return http.Response('{}',200);
    }));
    for(final days in [0,7,3650]){
      selected=days;
      await api.postMultipart('/api/files',{},fileBytes:Uint8List.fromList('plain text'.codeUnits),fileName:'sample.txt');
      expect(uploaded,contains('name="retentionDays"\r\n\r\n$days'));
    }
  });

}
