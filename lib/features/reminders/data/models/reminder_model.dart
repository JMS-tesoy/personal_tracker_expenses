// lib/features/reminders/data/models/reminder_model.dart

class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.userId,
    required this.targetType,
    this.targetId,
    this.personId,
    required this.title,
    this.message,
    this.dueAt,
    required this.remindAt,
    required this.repeatType,
    required this.status,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String targetType; // general | bill | loan | person | payment
  final String? targetId;
  final String? personId;
  final String title;
  final String? message;
  final DateTime? dueAt;
  final DateTime remindAt;
  final String repeatType; // none | daily | weekly | monthly
  final String status; // active | completed | cancelled
  final int? notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isPast => remindAt.isBefore(DateTime.now());

  String get displayTargetType {
    return switch (targetType) {
      'bill' => 'Bill',
      'loan' => 'Loan',
      'person' => 'Person',
      'payment' => 'Payment',
      _ => 'General',
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      targetType: map['target_type'] as String,
      targetId: map['target_id'] as String?,
      personId: map['person_id'] as String?,
      title: map['title'] as String,
      message: map['message'] as String?,
      dueAt: map['due_at'] != null
          ? DateTime.parse(map['due_at'] as String).toLocal()
          : null,
      remindAt: DateTime.parse(map['remind_at'] as String).toLocal(),
      repeatType: map['repeat_type'] as String? ?? 'none',
      status: map['status'] as String? ?? 'active',
      notificationId: map['notification_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'user_id': userId,
      'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (personId != null) 'person_id': personId,
      'title': title,
      if (message != null && message!.isNotEmpty) 'message': message,
      if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
      'remind_at': remindAt.toUtc().toIso8601String(),
      'repeat_type': repeatType,
      'status': status,
      if (notificationId != null) 'notification_id': notificationId,
    };
  }

  ReminderModel copyWith({
    String? status,
    int? notificationId,
    DateTime? remindAt,
    String? targetType,
    String? targetId,
    // Use a sentinel so callers can explicitly clear personId to null.
    Object? personId = _kKeep,
  }) {
    return ReminderModel(
      id: id,
      userId: userId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      personId: personId == _kKeep
          ? this.personId
          : personId as String?,
      title: title,
      message: message,
      dueAt: dueAt,
      remindAt: remindAt ?? this.remindAt,
      repeatType: repeatType,
      status: status ?? this.status,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// Sentinel object used by copyWith to distinguish "not provided" from null.
const Object _kKeep = Object();