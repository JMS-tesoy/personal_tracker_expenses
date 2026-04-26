class ActivityLogModel {
  const ActivityLogModel({
    required this.id,
    required this.userId,
    this.actorId,
    required this.targetType,
    this.targetId,
    this.personId,
    required this.action,
    required this.title,
    this.description,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? actorId;
  final String targetType;
  final String? targetId;
  final String? personId;
  final String action;
  final String title;
  final String? description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    return ActivityLogModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      actorId: map['actor_id'] as String?,
      targetType: map['target_type'] as String,
      targetId: map['target_id'] as String?,
      personId: map['person_id'] as String?,
      action: map['action'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      metadata:
          (map['metadata'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'user_id': userId,
      if (actorId != null) 'actor_id': actorId,
      'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (personId != null) 'person_id': personId,
      'action': action,
      'title': title,
      if (description != null) 'description': description,
      'metadata': metadata,
    };
  }
}
