import 'package:myaaptha_mobile/core/config/app_config.dart';
import 'package:myaaptha_mobile/core/models/network_models.dart';
import 'package:myaaptha_mobile/core/network/api_client.dart';
import 'package:myaaptha_mobile/features/auth/models/auth_models.dart';
import 'dart:typed_data';

class MyAapthaApi {
  MyAapthaApi(this.session, {ApiClient? client})
      : _client = client ?? ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final AuthTokenBundle session;
  final ApiClient _client;
  String get _token => session.accessToken;
  Future<Map<String, dynamic>> healthDashboard() async =>
      Map<String, dynamic>.from(await _json(
          _client.get('/api/health/dashboard', bearerToken: _token)) as Map);
  Future<void> addHealthReport(Map<String, dynamic> value) async =>
      _json(_client.post('/api/health/reports', value, bearerToken: _token));
  Future<void> deleteHealthReport(int id) async =>
      _json(_client.delete('/api/health/reports/$id', bearerToken: _token));
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
      throw MyAapthaApiException(message);
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
  Future<List<ConversationMessage>> circleMessages(int id) async =>
      (await _json(_client.get('/api/network/circles/$id/posts',
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
  Future<List<ConversationMessage>> directMessages(int userId) async =>
      (await _json(_client.get('/api/network/messages/with/$userId',
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
      {int? anchorUserId, String? location}) async {
    final query = <String, String>{'audienceType': audienceType};
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
      String? location,
      Uint8List? bytes,
      String? fileName,
      void Function(double progress)? onProgress}) async {
    final fields = <String, String>{
      'audienceType': audienceType,
      'message': message
    };
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

  Future<List<Map<String, dynamic>>> contactOAuthResult(
          String resultKey) async =>
      (await _json(_client.get(
              '/api/contact-organizer/oauth/results/${Uri.encodeComponent(resultKey)}',
              bearerToken: _token)) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<List<Map<String, dynamic>>> aiActivity() async =>
      (await _json(_client.get('/api/ai/activity', bearerToken: _token))
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
}

class MyAapthaApiException implements Exception {
  const MyAapthaApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
