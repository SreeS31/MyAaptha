import 'package:myaaptha_mobile/core/config/app_config.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'dart:typed_data';
import 'package:myaaptha_mobile/features/auth/data/session_refresher.dart';

class MyAapthaApi {
  Future<List<Map<String,dynamic>>> timelineEvents() async=>(await _json(_client.get('/api/timeline/events',bearerToken:_token)) as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  Future<void> deleteTimelineEvent(String key) async => _json(_client.delete('/api/timeline/events/${Uri.encodeComponent(key)}',bearerToken:_token));
  Future<Map<String,dynamic>> saveTimelineEvent(Map<String,dynamic> event) async=>Map<String,dynamic>.from(await _json(_client.put('/api/timeline/events/${Uri.encodeComponent(event['eventKey'] as String)}',event,bearerToken:_token)) as Map);
  Future<List<Map<String,dynamic>>> timelineRelationships() async=>(await _json(_client.get('/api/network/relationships',bearerToken:_token)) as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();

  Future<CircleModel> createChatGroup(String name, List<int> members) async => CircleModel.fromJson(Map<String, dynamic>.from(await _json(_client.post('/api/network/chats/groups', {'name': name, 'memberIds': members}, bearerToken: _token)) as Map));
  Future<List<Map<String, dynamic>>> searchAllChats(String query) async => (await _json(_client.get('/api/network/chats/search?q=${Uri.encodeQueryComponent(query)}', bearerToken: _token)) as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
  Future<Map<String, dynamic>> uploadPolicy() async => Map<String, dynamic>.from(await _json(_client.get('/api/uploads/policy', bearerToken: _token)) as Map);
  Future<Map<String, dynamic>> sessionProfile() async => Map<String, dynamic>.from(await _json(_client.get('/api/auth/me', bearerToken: _token)) as Map);
  Future<List<Map<String, dynamic>>> uploadLevels() async => (await _json(_client.get('/api/admin/upload-levels', bearerToken: _token)) as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
  Future<void> saveUploadLevel(Map<String, dynamic> level) async => _json(_client.put('/api/admin/upload-levels', level, bearerToken: _token));
  Future<void> assignUploadLevel(int userId, int levelId) async => _json(_client.put('/api/admin/upload-levels/users/$userId', {'levelId': levelId}, bearerToken: _token));
  Future<List<CircleConversation>> circleConversations() async => (await _json(_client.get('/api/network/chats/circles',bearerToken:_token)) as List).map((v)=>CircleConversation.fromJson(Map<String,dynamic>.from(v as Map))).toList();
  Future<void> forwardChatMessage(String type,int conversation,int message,List<ChatTarget> targets) async => _json(_client.post('/api/network/chats/forward',{'sourceType':type,'conversationId':conversation,'messageId':message,'targets':targets.map((t)=>t.toJson()).toList()},bearerToken:_token));
  Future<void> setCircleMessageFlags(int circle,int id,bool? starred,bool? pinned) async => _json(_client.put('/api/network/chats/circles/$circle/$id/flags',{if(starred!=null)'starred':starred,if(pinned!=null)'pinned':pinned},bearerToken:_token));
  Future<List<ChatTarget>> forwardTargets() async {
    final relations=await relationships();final chats=await directConversations();final groups=await circles();
    final people=<int,String>{for(final chat in chats)chat.userId:chat.displayName};
    for(final relation in relations){if(relation.person.accountStatus=='ACTIVE'&&relation.person.identityType!='MANAGED')people[relation.person.id]=relation.person.displayName;}
    return [...people.entries.map((entry)=>ChatTarget(type:'DIRECT',id:entry.key,name:entry.value)),...groups.where((c)=>c.currentUserCanPost).map((c)=>ChatTarget(type:'CIRCLE',id:c.id,name:c.name))];
  }

  Future<Map<String,dynamic>> addressBook({String query='',int afterId=0,int? circleId}) async => Map<String,dynamic>.from(await _json(_client.get('/api/address-book?q=${Uri.encodeQueryComponent(query)}&afterId=$afterId&limit=50${circleId==null?'':'&circleId=$circleId'}',bearerToken:_token)) as Map);
  Future<Map<String,dynamic>> importReviewedAddressBook(List<Map<String,dynamic>> contacts,String source,bool organize) async => Map<String,dynamic>.from(await _json(_client.post('/api/address-book/import-reviewed',{'consent':true,'source':source,'contacts':contacts.map((row)=>{'contact':{for(final e in row.entries) if(e.key!='selected'&&e.key!='circleNames') e.key:e.value},'circleNames':organize?(row['circleNames'] as List).cast<String>().map((n)=>n.trim()).where((n)=>n.isNotEmpty).toList():<String>[]}).toList()},bearerToken:_token)) as Map);
  Future<Map<String,dynamic>> importAddressBook(List<Map<String,dynamic>> contacts,String source,bool organize) async => Map<String,dynamic>.from(await _json(_client.post('/api/address-book/import',{'consent':true,'contacts':contacts,'source':source,'organize':organize},bearerToken:_token)) as Map);
  Future<void> removeAddressContact(int id) async => _json(_client.delete('/api/address-book/$id',bearerToken:_token));
  Future<void> clearAddressBook() async => _json(_client.delete('/api/address-book?confirm=true',bearerToken:_token));
  Future<Map<String,dynamic>> addressBookProviders() async => Map<String,dynamic>.from(await _json(_client.get('/api/address-book/providers',bearerToken:_token)) as Map);
  Future<Map<String,dynamic>> connectAddressBook(String email,String provider,bool organize) async => Map<String,dynamic>.from(await _json(_client.post('/api/address-book/oauth/start',{'consent':true,'email':email,'provider':provider,'organize':organize},bearerToken:_token)) as Map);
  Future<Map<String,dynamic>> addressBookOAuthResult(String key) async => Map<String,dynamic>.from(await _json(_client.get('/api/address-book/oauth/results/${Uri.encodeComponent(key)}',bearerToken:_token)) as Map);
  Future<List<Map<String,dynamic>>> addressCircles() async => (await _json(_client.get('/api/address-book/circles',bearerToken:_token)) as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  Future<void> assignAddressCircles(int id,List<int> circles) async => _json(_client.put('/api/address-book/$id/circles',{'circleIds':circles},bearerToken:_token));
  Future<void> relateAddressContact(int id,String relationship,String? phone) async => _json(_client.post('/api/address-book/$id/relation',{'consent':true,'relationship':relationship,'phone':phone},bearerToken:_token));

  Future<void> forwardDirectMessage(int other,int id,int recipientId) async => _json(_client.post('/api/network/messages/with/$other/$id/forward',{'recipientId':recipientId},bearerToken:_token));
  Future<void> setMessageFlags(int other,int id,bool? starred,bool? pinned) async => _json(_client.put('/api/network/messages/with/$other/$id/flags', {if(starred!=null)'starred':starred,if(pinned!=null)'pinned':pinned},bearerToken:_token));
  Future<List<ConversationMessage>> savedMessages(int other,String kind,{int? beforeId}) async => (await _json(_client.get('/api/network/messages/with/$other/saved?kind=$kind&limit=50${beforeId==null?'':'&beforeId=$beforeId'}',bearerToken:_token)) as List).map((v)=>ConversationMessage.fromJson(Map<String,dynamic>.from(v as Map))).toList();
  Future<void> acknowledgeMessages(int other,List<int> ids) async => _json(_client.post('/api/network/messages/with/$other/read',{'messageIds':ids},bearerToken:_token));
  Future<void> saveChatSettings(int other,{bool? archived,bool? muted,bool? markedUnread}) async => _json(_client.put('/api/network/messages/with/$other/settings',{if(archived!=null)'archived':archived,if(muted!=null)'muted':muted,if(markedUnread!=null)'markedUnread':markedUnread},bearerToken:_token));
  Future<void> pinConversation(int other,bool pinned) async => _json(_client.put('/api/network/messages/with/$other/pin',{'pinned':pinned},bearerToken:_token));
  Future<bool> messagePreferences() async => (await _json(_client.get('/api/network/messages/preferences',bearerToken:_token)) as Map)['readReceipts']==true;
  Future<void> saveMessagePreferences(bool readReceipts) async => _json(_client.put('/api/network/messages/preferences',{'readReceipts':readReceipts},bearerToken:_token));

  Future<Map<String, dynamic>> helpStatus() async => Map<String, dynamic>.from(await _json(_client.get('/api/ai/help', bearerToken: _token)) as Map);
  Future<void> setHelpEnhanced(bool enabled) async { await _json(_client.put('/api/ai/help/admin/settings',{'enhancedEnabled':enabled},bearerToken:_token)); }
  Future<void> clearSharedHelp() async { await _json(_client.delete('/api/ai/help/admin/answers',bearerToken:_token)); }
  Future<void> publishHelpAnswer(String question,String answer,List<String> sources) async { await _json(_client.post('/api/ai/help/admin/answers',{'question':question,'answer':answer,'sourceIds':sources,'confirmedPublic':true},bearerToken:_token)); }
  Future<Map<String, dynamic>> retryHelp(String exchangeId) async => Map<String,dynamic>.from(await _json(_client.post('/api/ai/help/chat', {'message':'Retry my saved question','history':[],'useAi':true,'retryOf':exchangeId},bearerToken:_token)) as Map);
  Future<void> clearHelpHistory() async { await _json(_client.delete('/api/ai/help/history',bearerToken:_token)); }
  Future<Map<String, dynamic>> askHelp(String message, List<Map<String, String>> history, bool useAi) async => Map<String, dynamic>.from(await _json(_client.post('/api/ai/help/chat', {'message':message,'history':history,'useAi':useAi}, bearerToken:_token)) as Map);
  MyAapthaApi(this.session, {ApiClient? client})
      : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl,
          accessTokenProvider: () => SessionRefresher.shared.accessToken(session));
  final AuthTokenBundle session;
  final ApiClient _client;
  String get _token => session.accessToken;
  Future<PeopleDiscovery> discoverPeople(String query) async => PeopleDiscovery.fromJson(
      Map<String,dynamic>.from(await _json(_client.get('/api/network/discover?q=${Uri.encodeQueryComponent(query)}',bearerToken:_token)) as Map));
  Future<Map<String,dynamic>> applicationSettings() async => Map<String,dynamic>.from(
      await _json(_client.get('/api/settings/me',bearerToken:_token)) as Map);
  Future<Map<String,dynamic>> updateApplicationSettings(Map<String,dynamic> values) async => Map<String,dynamic>.from(
      await _json(_client.put('/api/settings/me',values,bearerToken:_token)) as Map);

  Future<Map<String,dynamic>> healthAnalysisPolicy() async => Map<String,dynamic>.from(await _json(_client.get('/api/health/ai-status',bearerToken:_token)) as Map);
  Future<void> analyzeHealthReport(Uint8List bytes,String name,{required bool processingConsent}) async {
    if(!processingConsent)throw const FormatException('Consent to external processing is required for this report.');
    if(bytes.isEmpty||bytes.length>25*1024*1024)throw const FormatException('Choose a non-empty report of 25 MB or smaller.');
    final extension=name.split('.').last.toLowerCase();
    final type={'pdf':'application/pdf','jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png'}[extension];
    if(type==null)throw const FormatException('Choose a PDF, JPEG or PNG report.');
    await _json(_client.postMultipart('/api/health/reports/analyze',{'processingConsent':'true'},bearerToken:_token,fileBytes:bytes,fileName:name,fileContentType:type,requestRetention:false));
  }
  Future<Map<String, dynamic>> healthDashboard() async =>
      Map<String, dynamic>.from(await _json(
          _client.get('/api/health/dashboard', bearerToken: _token)) as Map);
  Future<void> addHealthReport(Map<String, dynamic> value) async =>
      _json(_client.post('/api/health/reports', value, bearerToken: _token));
  Future<void> deleteHealthReport(int id) async =>
      _json(_client.delete('/api/health/reports/$id', bearerToken: _token));
  Future<List<Map<String,dynamic>>> renewals() async => (await _json(_client.get('/api/finance/renewals',bearerToken:_token)) as List).map((row)=>Map<String,dynamic>.from(row as Map)).toList();
  Future<Map<String,dynamic>> saveRenewal(Map<String,dynamic> value,{int? id}) async {
    final input={for(final key in ['kind','title','provider','referenceNumber','amount','purchasedOn','expiresOn','timezone','notes','remindersEnabled','archived']) if(value.containsKey(key)) key:value[key]};
    return Map<String,dynamic>.from(await _json(id==null?_client.post('/api/finance/renewals',input,bearerToken:_token):_client.put('/api/finance/renewals/$id',input,bearerToken:_token)) as Map);
  }
  Future<Map<String,dynamic>> setRenewalState(int id,{bool? archived,bool? remindersEnabled}) async => Map<String,dynamic>.from(await _json(_client.put('/api/finance/renewals/$id/state',{if(archived!=null)'archived':archived,if(remindersEnabled!=null)'remindersEnabled':remindersEnabled},bearerToken:_token)) as Map);
  Future<void> deleteRenewal(int id) async => _json(_client.delete('/api/finance/renewals/$id',bearerToken:_token));
  Future<void> removeRenewalReceipt(int id) async => _json(_client.delete('/api/finance/renewals/$id/attachment',bearerToken:_token));
  Future<void> attachRenewalReceipt(int id,Uint8List bytes,String name) async {
    final type={'pdf':'application/pdf','jpg':'image/jpeg','jpeg':'image/jpeg','png':'image/png','webp':'image/webp'}[name.split('.').last.toLowerCase()];
    if(type==null||bytes.isEmpty||bytes.length>25*1024*1024)throw const FormatException('Choose a PDF, JPG, PNG or WebP receipt up to 25 MB.');
    await _json(_client.postMultipart('/api/finance/renewals/$id/attachment',{},bearerToken:_token,fileBytes:bytes,fileName:name,fileContentType:type));
  }
  Future<Map<String, dynamic>> financialSummary(String month) async =>
      Map<String, dynamic>.from(await _json(_client.get(
          '/api/finance/summary?month=$month',
          bearerToken: _token)) as Map);
  Future<void> addFinancialTransaction(Map<String, dynamic> value) async =>
      _json(_client.post('/api/finance/transactions', value,
          bearerToken: _token));
  Future<void> deleteFinancialTransaction(int id) async => _json(
      _client.delete('/api/finance/transactions/$id', bearerToken: _token));
  Future<List<Map<String, dynamic>>> trustedPeople(String kind) async =>
      (await _json(_client.get('/api/trust/people?kind=$kind',
              bearerToken: _token)) as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  Future<List<Map<String, dynamic>>> inboundTrustedPeople(String kind) async =>
      (await _json(_client.get('/api/trust/people/inbound?kind=$kind',
              bearerToken: _token)) as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  Future<Map<String, dynamic>> addTrustedPerson(
          int userId, String kind) async =>
      Map<String, dynamic>.from(await _json(_client.post(
          '/api/trust/people', {'userId': userId, 'kind': kind},
          bearerToken: _token)) as Map);
  Future<void> removeTrustedPerson(int userId, String kind) async =>
      _json(_client.delete('/api/trust/people/$userId?kind=$kind',
          bearerToken: _token));
  Future<List<Map<String, dynamic>>> roleModels() async =>
      (await _json(_client.get('/api/trust/role-models', bearerToken: _token))
              as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  Future<Map<String,dynamic>> followConnections(String kind,int page) async => Map<String,dynamic>.from(await _json(_client.get('/api/trust/$kind?page=$page',bearerToken:_token)) as Map);
  Future<void> unfollowRoleModel(int id) async => _json(_client.delete('/api/trust/role-models/$id/follow',bearerToken:_token));
  Future<void> followRoleModel(int userId) async =>
      _json(_client.post('/api/trust/role-models/$userId/follow', const {},
          bearerToken: _token));
  Future<List<Map<String, dynamic>>> emergencyRequests() async =>
      (await _json(_client.get('/api/trust/emergencies', bearerToken: _token))
              as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  Future<Map<String, dynamic>> startEmergencyAccess(
          int ownerUserId, String reason) async =>
      Map<String, dynamic>.from(await _json(_client.post(
          '/api/trust/emergencies',
          {'ownerUserId': ownerUserId, 'reason': reason},
          bearerToken: _token)) as Map);
  Future<void> decideEmergencyAccess(int requestId, bool approved) async =>
      _json(_client.post(
          '/api/trust/emergencies/$requestId/decision', {'approved': approved},
          bearerToken: _token));
  Future<List<Map<String, dynamic>>> emergencyDocuments(int requestId) async =>
      (await _json(_client.get('/api/trust/emergencies/$requestId/documents',
              bearerToken: _token)) as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  Future<List<Map<String, dynamic>>> notifications() async =>
      (await _json(_client.get('/api/notifications', bearerToken: _token))
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  Future<int> unreadNotificationCount() async =>
      ((await _json(_client.get('/api/notifications/unread-count',
              bearerToken: _token)) as Map)['count'] as num)
          .toInt();
  Future<void> readNotification(int id) async => _json(_client
      .post('/api/notifications/$id/read', const {}, bearerToken: _token));
  Future<void> readAllNotifications() async => _json(_client
      .post('/api/notifications/read-all', const {}, bearerToken: _token));
  Future<Map<String, dynamic>> notificationPreferences() async =>
      Map<String, dynamic>.from(await _json(_client
          .get('/api/notifications/preferences', bearerToken: _token)) as Map);
  Future<Map<String, dynamic>> updateNotificationPreferences(
          Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(await _json(_client.put(
              '/api/notifications/preferences', values, bearerToken: _token))
          as Map);
  Future<dynamic> _json(Future<ApiResponse> request) async {
    final response = await request;
    if (!response.isSuccess) {
      String message = 'Request failed (${response.statusCode})';
      try {
        final body = response.decodeJson();
        message = body is Map
            ? (body['message'] ?? body['error'] ?? message).toString()
            : message;
      } catch (_) {}
      throw MyAapthaApiException(message, statusCode: response.statusCode);
    }
    return response.decodeJson();
  }

  Future<List<Relationship>> relationships() async => (await _json(
              _client.get('/api/network/relationships', bearerToken: _token))
          as List)
      .map((item) => Relationship.fromJson(item as Map<String, dynamic>))
      .toList();
  Future<List<Map<String, dynamic>>> socialFeed() async =>
      (await _json(_client.get('/api/social/feed', bearerToken: _token))
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<List<Map<String, dynamic>>> savedSocialPosts() async =>
      (await _json(_client.get('/api/social/saved', bearerToken: _token))
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<List<Map<String, dynamic>>> socialStories() async =>
      (await _json(_client.get('/api/social/stories', bearerToken: _token))
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<Map<String, dynamic>> viewSocialStory(int id) async =>
      Map<String, dynamic>.from(await _json(_client.post(
              '/api/social/stories/$id/view', const {}, bearerToken: _token))
          as Map);
  Future<void> createSocialPost(String caption, String audience,
          {int? circleId, Uint8List? bytes, String? fileName}) async =>
      _json(_client.postMultipart(
          '/api/social/posts',
          {
            'caption': caption,
            'audience': audience,
            if (circleId != null) 'circleId': '$circleId'
          },
          bearerToken: _token,
          fileBytes: bytes,
          fileName: fileName));
  Future<void> createSocialStory(
          String caption, Uint8List bytes, String fileName) async =>
      _json(_client.postMultipart('/api/social/stories',
          {'caption': caption, 'audience': 'RELATIONSHIPS'},
          bearerToken: _token, fileBytes: bytes, fileName: fileName));
  Future<Map<String, dynamic>> toggleSocialLike(int id) async =>
      Map<String, dynamic>.from(await _json(_client.post(
          '/api/social/posts/$id/like', const {},
          bearerToken: _token)) as Map);
  Future<Map<String, dynamic>> toggleSocialSave(int id) async =>
      Map<String, dynamic>.from(await _json(_client.post(
          '/api/social/posts/$id/save', const {},
          bearerToken: _token)) as Map);
  Future<Map<String,dynamic>> reactSocialPost(int id,String? emoji) async => Map<String,dynamic>.from(await _json(_client.put('/api/social/posts/$id/reaction',{'emoji':emoji},bearerToken:_token)) as Map);
  Future<Map<String,dynamic>> pinSocialPost(int id,bool pinned) async => Map<String,dynamic>.from(await _json(_client.put('/api/social/posts/$id/pin',{'pinned':pinned},bearerToken:_token)) as Map);
  Future<void> shareSocialPost(
          int id, String destinationType, int targetId, String message) async =>
      _json(_client.post(
          '/api/social/posts/$id/share',
          {
            'destinationType': destinationType,
            'targetId': targetId,
            'message': message
          },
          bearerToken: _token));
  Future<void> reportContent(
          {int? reportedUserId,
          String? entityType,
          int? entityId,
          required String reason,
          String details = ''}) async =>
      _json(_client.post(
          '/api/moderation/reports',
          {
            if (reportedUserId != null) 'reportedUserId': reportedUserId,
            if (entityType != null) 'entityType': entityType,
            if (entityId != null) 'entityId': entityId,
            'reason': reason,
            'details': details
          },
          bearerToken: _token));
  Future<List<Map<String, dynamic>>> myReports() async => (await _json(
              _client.get('/api/moderation/reports/mine', bearerToken: _token))
          as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  Future<Map<String,dynamic>> moderationPage({String status='OPEN',int? beforeId}) async => Map<String,dynamic>.from(await _json(_client.get('/api/moderation/reports/queue?status=${Uri.encodeQueryComponent(status)}${beforeId==null?'':'&beforeId=$beforeId'}',bearerToken:_token)) as Map);
  Future<List<Map<String, dynamic>>> moderationReports() async =>
      (await _json(_client.get('/api/moderation/reports', bearerToken: _token))
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  Future<void> updateModerationReport(
          int id, String status, String notes) async =>
      _json(_client.put(
          '/api/moderation/reports/$id', {'status': status, 'notes': notes},
          bearerToken: _token));
  Future<void> addSocialComment(int id, String message) async =>
      _json(_client.post('/api/social/posts/$id/comments', {'message': message},
          bearerToken: _token));
  Future<void> updateSocialPost(int id, String caption) async => _json(_client
      .put('/api/social/posts/$id', {'caption': caption}, bearerToken: _token));
  Future<void> deleteSocialPost(int id) async =>
      _json(_client.delete('/api/social/posts/$id', bearerToken: _token));
  Future<void> deleteSocialComment(int postId, int commentId) async =>
      _json(_client.delete('/api/social/posts/$postId/comments/$commentId',
          bearerToken: _token));
  Future<void> deleteSocialStory(int id) async =>
      _json(_client.delete('/api/social/stories/$id', bearerToken: _token));
  Future<Uint8List> socialMedia(String path) async {
    final response = await _client.get(path, bearerToken: _token);
    if (!response.isSuccess) {
      throw const MyAapthaApiException('Media could not be loaded');
    }
    return response.bodyBytes;
  }

  Future<List<CircleModel>> circles() async =>
      (await _json(_client.get('/api/network/circles', bearerToken: _token))
              as List)
          .map((item) => CircleModel.fromJson(item as Map<String, dynamic>))
          .toList();
  Future<Map<int, int>> circleUnreadCounts() async {
    final data = await _json(_client.get('/api/network/circles/unread-counts',
        bearerToken: _token)) as Map<String, dynamic>;
    return data.map(
        (key, value) => MapEntry(int.parse(key), (value as num? ?? 0).toInt()));
  }

  Future<void> heartbeatPresence() async => _json(_client
      .post('/api/network/presence/heartbeat', const {}, bearerToken: _token));
  Future<Map<String, dynamic>> directPresence(int userId) async =>
      Map<String, dynamic>.from(await _json(_client
          .get('/api/network/presence/direct/$userId', bearerToken: _token)));
  Future<void> setDirectTyping(int userId, bool typing) async => _json(_client
      .post('/api/network/presence/direct/$userId/typing', {'typing': typing},
          bearerToken: _token));
  Future<Map<String, dynamic>> circlePresence(int circleId) async =>
      Map<String, dynamic>.from(await _json(_client.get(
          '/api/network/presence/circles/$circleId',
          bearerToken: _token)));
  Future<void> setCircleTyping(int circleId, bool typing) async =>
      _json(_client.post(
          '/api/network/presence/circles/$circleId/typing', {'typing': typing},
          bearerToken: _token));

  Future<List<Person>> search(String query) async {
    final people = (await _json(_client.get(
            '/api/network/search?q=${Uri.encodeQueryComponent(query)}',
            bearerToken: _token)) as List)
        .map((item) => Person.fromJson(item as Map<String, dynamic>))
        .toList();
    if (people.length < 2) return people;
    try {
      final ranked = await _json(_client.post(
          '/api/ai/search/rank',
          {
            'query': query,
            'candidates': people
                .map((person) => {
                      'id': person.id,
                      'name': person.displayName,
                      'location': person.location ?? ''
                    })
                .toList()
          },
          bearerToken: _token)) as List;
      final scores = <int, double>{
        for (final item in ranked.cast<Map>())
          int.parse(item['id'].toString()):
              (item['score'] as num?)?.toDouble() ?? 0
      };
      people.sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));
    } catch (_) {
      // Search remains available when the optional AI ranking service is down.
    }
    return people;
  }

  Future<Relationship> addRelationship(
          Person person, String type, String visibility) async =>
      Relationship.fromJson(await _json(_client.post(
          '/api/network/relationships',
          {
            'relatedUserId': person.id,
            'type': type,
            'visibilityScope': visibility
          },
          bearerToken: _token)) as Map<String, dynamic>);
  Future<Relationship> addPersonRelationship({
    required String fullName,
    required String type,
    required String visibility,
    required int relativeToUserId,
    String? phoneNumber,
    String? email,
  }) async =>
      Relationship.fromJson(await _json(_client.post(
          '/api/network/relationships/add-person',
          {
            'fullName': fullName.trim(),
            'phoneNumber': phoneNumber?.trim(),
            'email': email?.trim(),
            'type': type,
            'visibilityScope': visibility,
            'identityType': 'MANAGED',
            'managedCategory': 'OTHER',
            'relativeToUserId': relativeToUserId,
          },
          bearerToken: _token)) as Map<String, dynamic>);
  Future<void> removeRelationship(int id) async => _json(
      _client.delete('/api/network/relationships/$id', bearerToken: _token));
  Future<Relationship> updateRelationship(
          Relationship relationship, String type, String visibility) async =>
      Relationship.fromJson(await _json(_client.put(
          '/api/network/relationships/${relationship.id}',
          {
            'contactName': relationship.person.displayName,
            'contactPhone': relationship.contactPhone,
            'contactEmail': relationship.contactEmail,
            'type': type,
            'visibilityScope': visibility,
            'visibilityCompany': relationship.visibilityCompany
          },
          bearerToken: _token)) as Map<String, dynamic>);
  Future<CircleModel> createCircle(String name, String description) async =>
      CircleModel.fromJson(await _json(_client.post(
          '/api/network/circles', {'name': name, 'description': description},
          bearerToken: _token)) as Map<String, dynamic>);
  Future<CircleModel> updateCircle(int id, String name, String description,
          String postingPermission) async =>
      CircleModel.fromJson(await _json(_client.put(
          '/api/network/circles/$id',
          {
            'name': name,
            'description': description,
            'postingPermission': postingPermission
          },
          bearerToken: _token)) as Map<String, dynamic>);
  Future<CircleModel> addCircleMember(int id, int userId) async =>
      CircleModel.fromJson(await _json(_client.post(
          '/api/network/circles/$id/members', {'userId': userId},
          bearerToken: _token)) as Map<String, dynamic>);
  Future<CircleModel> removeCircleMember(int id, int userId) async =>
      CircleModel.fromJson(await _json(_client.delete(
          '/api/network/circles/$id/members/$userId',
          bearerToken: _token)) as Map<String, dynamic>);
  Future<CircleModel> promoteCircleAdmin(int id, int userId) async =>
      CircleModel.fromJson(await _json(_client.post(
          '/api/network/circles/$id/admins/$userId', const {},
          bearerToken: _token)) as Map<String, dynamic>);
  Future<CircleModel> demoteCircleAdmin(int id, int userId) async =>
      CircleModel.fromJson(await _json(_client.delete(
          '/api/network/circles/$id/admins/$userId',
          bearerToken: _token)) as Map<String, dynamic>);
  Future<List<ConversationMessage>> circleMessages(int id,
          {int? beforeId}) async =>
      (await _json(_client.get(
              '/api/network/circles/$id/posts?limit=50${beforeId == null ? '' : '&beforeId=$beforeId'}',
              bearerToken: _token)) as List)
          .map((item) =>
              ConversationMessage.fromJson(item as Map<String, dynamic>))
          .toList();
  Future<void> postCircleMessage(int id, String message,
          {int? parentMessageId}) async =>
      _json(_client.postMultipart(
          '/api/network/circles/$id/posts',
          {
            'message': message,
            if (parentMessageId != null)
              'parentPostId': parentMessageId.toString()
          },
          bearerToken: _token));
  Future<void> editCircleMessage(
          int circleId, int messageId, String message) async =>
      _json(_client.put('/api/network/circles/$circleId/posts/$messageId',
          {'message': message},
          bearerToken: _token));
  Future<void> deleteCircleMessageForMe(int circleId,int messageId) async =>
      _json(_client.delete('/api/network/circles/$circleId/posts/$messageId/for-me',bearerToken:_token));
  Future<void> deleteCircleMessage(int circleId, int messageId) async =>
      _json(_client.delete('/api/network/circles/$circleId/posts/$messageId',
          bearerToken: _token));
  Future<List<ConversationMessage>> searchCircleMessages(
          int circleId, String query) async =>
      (await _json(_client.get(
              '/api/network/circles/$circleId/posts/search?q=${Uri.encodeQueryComponent(query)}',
              bearerToken: _token)) as List)
          .map((item) =>
              ConversationMessage.fromJson(item as Map<String, dynamic>))
          .toList();
  Future<void> reactCircleMessage(
          int circleId, int messageId, String emoji) async =>
      _json(_client.post(
          '/api/network/circles/$circleId/posts/$messageId/reaction',
          {'emoji': emoji},
          bearerToken: _token));
  Future<void> postCircleAttachment(
    int id,
    String message,
    Uint8List bytes,
    String fileName, {
    int? parentMessageId,
    void Function(double progress)? onProgress,
  }) async =>
      _json(_client.postMultipart(
        '/api/network/circles/$id/posts',
        {
          'message': message,
          if (parentMessageId != null)
            'parentPostId': parentMessageId.toString()
        },
        bearerToken: _token,
        fileBytes: bytes,
        fileName: fileName,
        onProgress: onProgress,
      ));
  Future<List<ConversationMessage>> directMessages(int userId,
          {int? beforeId}) async =>
      (await _json(_client.get(
              '/api/network/messages/with/$userId?limit=50${beforeId == null ? '' : '&beforeId=$beforeId'}',
              bearerToken: _token)) as List)
          .map((item) =>
              ConversationMessage.fromJson(item as Map<String, dynamic>))
          .toList();
  Future<List<DirectConversation>> directConversations() async => (await _json(
          _client.get('/api/network/messages/conversations',
              bearerToken: _token)) as List)
      .map((item) => DirectConversation.fromJson(item as Map<String, dynamic>))
      .toList();
  Future<void> sendDirectMessage(int userId, String message,
          {int? replyToMessageId}) async =>
      _json(_client.postMultipart(
          '/api/network/messages/with/$userId',
          {
            'message': message,
            if (replyToMessageId != null)
              'replyToMessageId': '$replyToMessageId'
          },
          bearerToken: _token));
  Future<void> sendDirectAttachment(
    int userId,
    String message,
    Uint8List bytes,
    String fileName, {
    int? replyToMessageId,
    void Function(double progress)? onProgress,
  }) async =>
      _json(_client.postMultipart(
        '/api/network/messages/with/$userId',
        {
          'message': message,
          if (replyToMessageId != null) 'replyToMessageId': '$replyToMessageId'
        },
        bearerToken: _token,
        fileBytes: bytes,
        fileName: fileName,
        onProgress: onProgress,
      ));
  Future<List<ConversationMessage>> searchDirectMessages(
          int userId, String query) async =>
      (await _json(_client.get(
              '/api/network/messages/with/$userId/search?q=${Uri.encodeQueryComponent(query)}',
              bearerToken: _token)) as List)
          .map((e) => ConversationMessage.fromJson(e as Map<String, dynamic>))
          .toList();
  Future<void> editDirectMessage(
          int userId, int messageId, String message) async =>
      _json(_client.put(
          '/api/network/messages/with/$userId/$messageId', {'message': message},
          bearerToken: _token));
  Future<void> deleteDirectMessageForMe(int userId,int messageId) async =>
      _json(_client.delete('/api/network/messages/with/$userId/$messageId/for-me',bearerToken:_token));
  Future<void> deleteDirectMessage(int userId, int messageId) async =>
      _json(_client.delete('/api/network/messages/with/$userId/$messageId',
          bearerToken: _token));
  Future<void> reactDirectMessage(
          int userId, int messageId, String emoji) async =>
      _json(_client.post(
          '/api/network/messages/with/$userId/$messageId/reaction',
          {'emoji': emoji},
          bearerToken: _token));
  Future<Map<String, dynamic>> previewBroadcast(String audienceType,
      {int? anchorUserId, String? location, int? levels}) async {
    final query = <String, String>{'audienceType': audienceType};
    if(levels!=null)query['levels']='$levels';
    if (anchorUserId != null) query['anchorUserId'] = '$anchorUserId';
    if (location != null && location.trim().isNotEmpty) {
      query['location'] = location.trim();
    }
    return Map<String, dynamic>.from(await _json(_client.get(
        '/api/network/broadcasts/preview?${Uri(queryParameters: query).query}',
        bearerToken: _token)) as Map);
  }

  Future<Map<String, dynamic>> sendBroadcast(
      String audienceType, String message,
      {int? anchorUserId,
      int? levels,
      String? location,
      Uint8List? bytes,
      String? fileName,
      void Function(double progress)? onProgress}) async {
    final fields = <String, String>{
      'audienceType': audienceType,
      'message': message
    };
    if(levels!=null)fields['levels']='$levels';
    if (anchorUserId != null) fields['anchorUserId'] = '$anchorUserId';
    if (location != null && location.trim().isNotEmpty) {
      fields['location'] = location.trim();
    }
    return Map<String, dynamic>.from(await _json(_client.postMultipart(
        '/api/network/broadcasts', fields,
        bearerToken: _token,
        fileBytes: bytes,
        fileName: fileName,
        onProgress: onProgress)) as Map);
  }

  Future<Map<String,dynamic>> callIceConfiguration() async => Map<String,dynamic>.from(await _json(_client.get('/api/network/calls/ice',bearerToken:_token)) as Map);

  Future<DirectCallModel> startCall(
          int recipientId, String callType, String offerSdp) async =>
      DirectCallModel.fromJson(await _json(_client.post(
          '/api/network/calls',
          {
            'recipientId': recipientId,
            'callType': callType,
            'offerSdp': offerSdp
          },
          bearerToken: _token)) as Map<String, dynamic>);
  Future<List<DirectCallModel>> incomingCalls() async => (await _json(
              _client.get('/api/network/calls/incoming', bearerToken: _token))
          as List)
      .map((item) => DirectCallModel.fromJson(item as Map<String, dynamic>))
      .toList();
  Future<List<Map<String, dynamic>>> blockedUsers() async =>
      (await _json(_client.get('/api/privacy/blocks', bearerToken: _token))
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<void> blockUser(int userId) async => _json(_client
      .post('/api/privacy/blocks', {'userId': userId}, bearerToken: _token));
  Future<void> unblockUser(int userId) async =>
      _json(_client.delete('/api/privacy/blocks/$userId', bearerToken: _token));
  Future<DirectCallModel> call(int id) async => DirectCallModel.fromJson(
      await _json(_client.get('/api/network/calls/$id', bearerToken: _token))
          as Map<String, dynamic>);
  Future<DirectCallModel> acceptCall(int id, String answerSdp) async =>
      DirectCallModel.fromJson(await _json(_client.post(
          '/api/network/calls/$id/accept', {'answerSdp': answerSdp},
          bearerToken: _token)) as Map<String, dynamic>);
  Future<void> rejectCall(int id) async => _json(_client
      .post('/api/network/calls/$id/reject', const {}, bearerToken: _token));
  Future<void> endCall(int id) async => _json(_client
      .post('/api/network/calls/$id/end', const {}, bearerToken: _token));
  Future<Uint8List> attachment(String path) async {
    final response = await _client.get(path, bearerToken: _token);
    if (!response.isSuccess) {
      throw MyAapthaApiException(
          'Unable to load attachment (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  Future<UserProfileModel> profile() async => UserProfileModel.fromJson(
      await _json(_client.get('/api/profile/me', bearerToken: _token))
          as Map<String, dynamic>);
  static void validateProfilePhoto(Uint8List bytes,String name) {
    if(bytes.isEmpty || bytes.length>5*1024*1024) throw const FormatException('Choose a photo up to 5 MB.');
    if(!{'jpg','jpeg','png','webp'}.contains(name.split('.').last.toLowerCase())) throw const FormatException('Choose a JPG, PNG or WebP photo.');
  }
  Future<UserProfileModel> uploadProfilePhoto(Uint8List bytes,String name,{bool gallery=false}) async {
    validateProfilePhoto(bytes,name);
    return UserProfileModel.fromJson(Map<String,dynamic>.from(await _json(_client.postMultipart('/api/profile/me/${gallery?'photos':'photo'}',{},bearerToken:_token,fileBytes:bytes,fileName:name)) as Map));
  }
  Future<UserProfileModel> removeProfilePhoto({int? galleryIndex}) async => UserProfileModel.fromJson(Map<String,dynamic>.from(await _json(_client.delete(galleryIndex==null?'/api/profile/me/photo':'/api/profile/me/photos/$galleryIndex',bearerToken:_token)) as Map));
  String profilePhotoUrl(String value) {
    final uri=Uri.tryParse(value);
    // Profile media is served by the API. Use its configured host so Android emulators
    // do not resolve a server-generated localhost URL against the device itself.
    if(uri==null || !uri.path.startsWith('/api/profile/media/')) return value;
    return Uri.parse(_client.baseUrl).resolve(uri.path).toString();
  }
  Future<UserProfileModel> saveProfile(Map<String, dynamic> data) async =>
      UserProfileModel.fromJson(
          await _json(_client.put('/api/profile/me', data, bearerToken: _token))
              as Map<String, dynamic>);

  Future<List<Map<String, dynamic>>> analyzeContacts(
          List<Map<String, dynamic>> contacts) async =>
      (await _json(_client.post('/api/contact-organizer/analyze',
                  {'consent': true, 'contacts': contacts}, bearerToken: _token))
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<Map<String, dynamic>> acceptContactSuggestions(
          List<Map<String, dynamic>> suggestions) async =>
      Map<String, dynamic>.from(await _json(_client.post(
          '/api/contact-organizer/accept',
          {'consent': true, 'suggestions': suggestions},
          bearerToken: _token)) as Map);

  Future<Map<String, dynamic>> startContactOAuth(
          String email, String provider) async =>
      Map<String, dynamic>.from(await _json(_client.post(
          '/api/contact-organizer/oauth/start',
          {'email': email, 'provider': provider},
          bearerToken: _token)) as Map);

  Future<List<Map<String, dynamic>>> contactOAuthResult(String resultKey) async {
    final value = await _json(_client.get('/api/contact-organizer/oauth/results/${Uri.encodeComponent(resultKey)}', bearerToken: _token));
    if (value is Map && value['status'] == 'failed') {
      throw MyAapthaApiException('${value['message'] ?? 'Contact authorization failed. Nothing was saved.'}', statusCode: 422);
    }
    if (value is! List) throw const MyAapthaApiException('The contact provider returned an invalid result. Please try again.', statusCode: 502);
    return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> aiActivity() async =>
      (await _json(_client.get('/api/ai/activity', bearerToken: _token))
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<Map<String, dynamic>> aiPreferences() async =>
      Map<String, dynamic>.from(
          await _json(_client.get('/api/ai/preferences', bearerToken: _token))
              as Map);

  Future<Map<String, dynamic>> updateAiPreferences(
          Map<String, dynamic> preferences) async =>
      Map<String, dynamic>.from(await _json(_client.put(
          '/api/ai/preferences', preferences,
          bearerToken: _token)) as Map);

  Future<List<Map<String, dynamic>>> aiApprovals() async =>
      (await _json(_client.get('/api/ai/approvals', bearerToken: _token))
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<List<Map<String, dynamic>>> aiExecutions() async =>
      (await _json(_client.get('/api/ai/executions', bearerToken: _token))
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<Map<String, dynamic>> decideAiApproval(
          String approvalId, String decision) async =>
      Map<String, dynamic>.from(await _json(_client.put(
          '/api/ai/approvals/${Uri.encodeComponent(approvalId)}/decision',
          {'decision': decision, 'reason': null},
          bearerToken: _token)) as Map);
}

class MyAapthaApiException implements Exception {
  const MyAapthaApiException(this.message, {this.statusCode});
  final int? statusCode;
  final String message;
  @override
  String toString() => message;
}
