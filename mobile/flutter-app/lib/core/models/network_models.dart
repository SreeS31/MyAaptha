class Person {
  Person(
      {required this.id,
      required this.displayName,
      required this.accountStatus,
      this.profilePhoto,
      this.location,
      this.identityType,
      this.gender});
  final int id;
  final String displayName;
  final String accountStatus;
  final String? profilePhoto;
  final String? location;
  final String? identityType;
  final String? gender;
  bool get canConnect => accountStatus == 'ACTIVE' && identityType != 'MANAGED';
  factory Person.fromJson(Map<String, dynamic> json) => Person(
      id: (json['id'] as num).toInt(),
      displayName: json['displayName'] as String? ?? 'Unknown',
      accountStatus: json['accountStatus'] as String? ?? 'INVITED',
      profilePhoto: json['profilePhoto'] as String?,
      location: json['location'] as String?,
      identityType: json['identityType'] as String?,
      gender: json['gender'] as String?);
}

class Relationship {
  Relationship(
      {required this.id,
      required this.type,
      required this.person,
      required this.visibilityScope,
      this.relativeToUserId,
      this.contactPhone,
      this.contactEmail,
      this.visibilityCompany});
  final int id;
  final String type;
  final Person person;
  final String visibilityScope;
  final int? relativeToUserId;
  final String? contactPhone, contactEmail, visibilityCompany;
  factory Relationship.fromJson(Map<String, dynamic> json) => Relationship(
      id: (json['id'] as num).toInt(),
      type: json['type'] as String? ?? 'Relation',
      person: Person.fromJson(json['person'] as Map<String, dynamic>),
      visibilityScope: json['visibilityScope'] as String? ?? 'FRIENDS',
      relativeToUserId: (json['relativeToUserId'] as num?)?.toInt(),
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      visibilityCompany: json['visibilityCompany'] as String?);
}

class CircleMember {
  CircleMember(
      {required this.person, required this.admin, required this.creator});
  final Person person;
  final bool admin;
  final bool creator;
  factory CircleMember.fromJson(Map<String, dynamic> json) => CircleMember(
      person: Person.fromJson(json['person'] as Map<String, dynamic>),
      admin: json['admin'] == true,
      creator: json['creator'] == true);
}

class CircleModel {
  CircleModel(
      {required this.id,
      required this.name,
      required this.description,
      required this.ownerName,
      required this.members,
      required this.currentUserAdmin,
      required this.currentUserCanPost,
      required this.postingPermission});
  final int id;
  final String name;
  final String description;
  final String ownerName;
  final List<CircleMember> members;
  final bool currentUserAdmin;
  final bool currentUserCanPost;
  final String postingPermission;
  factory CircleModel.fromJson(Map<String, dynamic> json) => CircleModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Circle',
      description: json['description'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      members: (json['members'] as List? ?? [])
          .map((item) => CircleMember.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentUserAdmin: json['currentUserAdmin'] == true,
      currentUserCanPost: json['currentUserCanPost'] == true,
      postingPermission: json['postingPermission'] as String? ?? 'ALL_MEMBERS');
}

class DirectConversation {
  DirectConversation(
      {required this.userId,
      required this.displayName,
      required this.lastMessage,
      required this.lastMessageAt,
      required this.unreadCount,
      this.profilePhoto, this.pinned = false, this.archived=false, this.muted=false, this.markedUnread=false});
  final int userId, unreadCount;
  final bool pinned, archived, muted, markedUnread;
  final String displayName, lastMessage;
  final String? profilePhoto;
  final DateTime lastMessageAt;
  Person get person => Person(
      id: userId,
      displayName: displayName,
      accountStatus: 'ACTIVE',
      profilePhoto: profilePhoto,
      identityType: 'ACCOUNT');
  factory DirectConversation.fromJson(Map<String, dynamic> json) =>
      DirectConversation(
          userId: (json['userId'] as num).toInt(),
          displayName: json['displayName'] as String? ?? 'Unknown',
          profilePhoto: json['profilePhoto'] as String?,
          lastMessage: json['lastMessage'] as String? ?? '',
          lastMessageAt:
              DateTime.tryParse(json['lastMessageAt'] as String? ?? '') ??
                  DateTime.now(),
          unreadCount: (json['unreadCount'] as num? ?? 0).toInt(), pinned:json['pinned']==true, archived:json['archived']==true, muted:json['muted']==true, markedUnread:json['markedUnread']==true);
}

class ConversationMessage {
  ConversationMessage(
      {required this.id,
      required this.authorName,
      required this.message,
      required this.createdAt,
      required this.mine,
      this.authorPhoto,
      this.attachmentUrl,
      this.attachmentName,
      this.attachmentType,
      this.attachmentSize,
      this.parentMessageId,
      this.deliveredAt,
      this.readAt,
      this.readCount = 0, this.starred=false, this.pinned=false, this.forwarded=false,this.canDeleteForAll=false,this.hiddenForMe=false});
  final int id;
  final String authorName;
  final String message;
  final DateTime createdAt;
  final bool mine;
  final String? authorPhoto;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;
  final int? attachmentSize;
  final int? parentMessageId;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final int readCount;
  final bool starred,pinned,forwarded,canDeleteForAll,hiddenForMe;
  bool get deleted => deletedAt != null;
  late final DateTime? editedAt;
  late final DateTime? deletedAt;
  late final Map<String, int> reactions;
  late final String? myReaction;
  bool get hasAttachment => attachmentUrl?.isNotEmpty == true;
  factory ConversationMessage.fromJson(Map<String, dynamic> json) =>
      ConversationMessage(
          id: (json['id'] as num).toInt(),
          authorName:
              (json['authorName'] ?? json['senderName'] ?? 'Member') as String,
          message: json['message'] as String? ?? '',
          createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
          mine: json['currentUserAuthor'] == true,
          authorPhoto: (json['authorPhoto'] ?? json['senderPhoto']) as String?,
          attachmentUrl: json['attachmentUrl'] as String?,
          attachmentName: json['attachmentName'] as String?,
          attachmentType: json['attachmentType'] as String?,
          attachmentSize: (json['attachmentSize'] as num?)?.toInt(),
          parentMessageId:
              ((json['parentPostId'] ?? json['replyToMessageId']) as num?)
                  ?.toInt(),
          deliveredAt: DateTime.tryParse(json['deliveredAt'] as String? ?? ''),
          readAt: DateTime.tryParse(json['readAt'] as String? ?? ''),
          readCount: (json['readCount'] as num? ?? 0).toInt(),starred:json['starred']==true,pinned:json['pinned']==true,forwarded:json['forwarded']==true,canDeleteForAll:json['canDeleteForAll']==true,hiddenForMe:json['hiddenForMe']==true)
        ..editedAt = DateTime.tryParse(json['editedAt'] as String? ?? '')
        ..deletedAt = DateTime.tryParse(json['deletedAt'] as String? ?? '')
        ..reactions = Map<String, int>.from(
            (json['reactions'] as Map? ?? const {})
                .map((k, v) => MapEntry(k.toString(), (v as num).toInt())))
        ..myReaction = json['myReaction'] as String?;
}

class UserProfileModel {
  UserProfileModel(this.data);
  final Map<String, dynamic> data;
  String value(String key) => data[key]?.toString() ?? '';
  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(Map<String, dynamic>.from(json));
}

class DirectCallModel {
  DirectCallModel({
    required this.id,
    required this.callerId,
    required this.recipientId,
    required this.callerName,
    required this.recipientName,
    required this.callType,
    required this.status,
    required this.offerSdp,
    required this.currentUserCaller,
    this.answerSdp,
    this.callerPhoto,
    this.recipientPhoto,
  });
  final int id, callerId, recipientId;
  final String callerName, recipientName, callType, status, offerSdp;
  final String? answerSdp, callerPhoto, recipientPhoto;
  final bool currentUserCaller;
  factory DirectCallModel.fromJson(Map<String, dynamic> json) =>
      DirectCallModel(
          id: (json['id'] as num).toInt(),
          callerId: (json['callerId'] as num).toInt(),
          recipientId: (json['recipientId'] as num).toInt(),
          callerName: json['callerName'] as String? ?? 'Caller',
          recipientName: json['recipientName'] as String? ?? 'Recipient',
          callType: json['callType'] as String? ?? 'AUDIO',
          status: json['status'] as String? ?? 'RINGING',
          offerSdp: json['offerSdp'] as String? ?? '',
          answerSdp: json['answerSdp'] as String?,
          callerPhoto: json['callerPhoto'] as String?,
          recipientPhoto: json['recipientPhoto'] as String?,
          currentUserCaller: json['currentUserCaller'] == true);
}

class SharedConnection {
  SharedConnection(this.userId,this.displayName,this.yourRelationship,this.sharedRelationship);
  final int userId;
  final String displayName,yourRelationship,sharedRelationship;
  factory SharedConnection.fromJson(Map<String,dynamic> j)=>SharedConnection((j['userId'] as num).toInt(),j['displayName'] as String,j['yourRelationship'] as String,j['sharedRelationship'] as String);
}
class PeopleMatch {
  PeopleMatch(this.person,this.alreadyConnected,this.mutualConnections,this.sharedInterests,this.sharedEmployer,this.reasons);
  final Person person;
  final bool alreadyConnected;
  final List<SharedConnection> mutualConnections;
  final List<String> sharedInterests,reasons;
  final String? sharedEmployer;
  factory PeopleMatch.fromJson(Map<String,dynamic> j)=>PeopleMatch(Person.fromJson(Map<String,dynamic>.from(j['person'] as Map)),j['alreadyConnected']==true,
    (j['mutualConnections'] as List).map((v)=>SharedConnection.fromJson(Map<String,dynamic>.from(v as Map))).toList(),List<String>.from(j['sharedInterests'] as List),j['sharedEmployer'] as String?,List<String>.from(j['reasons'] as List));
}
class PeopleDiscovery {
  PeopleDiscovery(this.people,this.rankingMode,this.limited,this.explanation);
  final List<PeopleMatch> people;
  final String rankingMode,explanation;
  final bool limited;
  factory PeopleDiscovery.fromJson(Map<String,dynamic> j)=>PeopleDiscovery((j['people'] as List).map((v)=>PeopleMatch.fromJson(Map<String,dynamic>.from(v as Map))).toList(),j['rankingMode'] as String,j['limited']==true,j['explanation'] as String);
}

class ChatTarget {
  const ChatTarget({required this.type,required this.id,required this.name});
  final String type,name; final int id;
  String get key=>'$type:$id';
  Map<String,dynamic> toJson()=>{'type':type,'id':id};
}
class CircleConversation {
  CircleConversation.fromJson(Map<String,dynamic> json):id=(json['circleId'] as num).toInt(),name=json['displayName'] as String,lastMessage=json['lastMessage'] as String,unreadCount=(json['unreadCount'] as num).toInt(),lastMessageAt=DateTime.tryParse(json['lastMessageAt'] as String? ?? '');
  final int id,unreadCount;final String name,lastMessage;final DateTime? lastMessageAt;
}
