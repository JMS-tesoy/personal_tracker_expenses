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
    this.personName,
    this.targetName,
    this.deviceName,
    this.devicePlatform,
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

  /// UI enrichment fields. These are not inserted into activity_logs.
  final String? personName;
  final String? targetName;
  final String? deviceName;
  final String? devicePlatform;

  factory ActivityLogModel.fromMap(Map<String, dynamic> map) {
    final Object? metadataRaw = map['metadata'];
    final Map<String, dynamic> metadataMap = metadataRaw is Map
        ? Map<String, dynamic>.from(metadataRaw)
        : <String, dynamic>{};

    return ActivityLogModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      actorId: _emptyToNull(map['actor_id']),
      targetType: map['target_type']?.toString() ?? 'activity',
      targetId: _emptyToNull(map['target_id']),
      personId: _emptyToNull(map['person_id']),
      action: map['action']?.toString() ?? 'created',
      title: map['title']?.toString() ?? 'Activity',
      description: _emptyToNull(map['description']),
      metadata: metadataMap,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
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

  ActivityLogModel copyWith({
    String? personName,
    String? targetName,
    String? deviceName,
    String? devicePlatform,
  }) {
    return ActivityLogModel(
      id: id,
      userId: userId,
      actorId: actorId,
      targetType: targetType,
      targetId: targetId,
      personId: personId,
      action: action,
      title: title,
      description: description,
      metadata: metadata,
      createdAt: createdAt,
      personName: personName ?? this.personName,
      targetName: targetName ?? this.targetName,
      deviceName: deviceName ?? this.deviceName,
      devicePlatform: devicePlatform ?? this.devicePlatform,
    );
  }

  String? get uploadedByDeviceId {
    final Object? value = metadata['uploaded_by_device_id'];
    return _emptyToNull(value);
  }

  String? get billIdFromMetadata {
    final Object? value = metadata['bill_id'];
    return _emptyToNull(value);
  }

  String? get fileNameFromMetadata {
    final Object? value = metadata['file_name'];
    return _emptyToNull(value);
  }

  String? get amountFromMetadata {
    final Object? value = metadata['amount'];
    return _emptyToNull(value);
  }

  bool get hasPerson => personId != null && personId!.isNotEmpty;
  bool get hasDevice => deviceName != null && deviceName!.isNotEmpty;
  bool get hasTargetName => targetName != null && targetName!.isNotEmpty;
}

String? _emptyToNull(Object? value) {
  if (value == null) return null;

  final String text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;

  return text;
}