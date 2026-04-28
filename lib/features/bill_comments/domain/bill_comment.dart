class BillCommentModel {
  const BillCommentModel({
    required this.id,
    required this.userId,
    required this.billId,
    this.personId,
    this.personName,
    required this.message,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String billId;
  final String? personId;
  final String? personName;
  final String message;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory BillCommentModel.fromMap(
    Map<String, dynamic> map, {
    String? personName,
  }) {
    return BillCommentModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      billId: map['bill_id']?.toString() ?? '',
      personId: _emptyToNull(map['person_id']),
      personName: personName,
      message: map['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())?.toLocal()
          : null,
    );
  }

  BillCommentModel copyWith({String? personName}) {
    return BillCommentModel(
      id: id,
      userId: userId,
      billId: billId,
      personId: personId,
      personName: personName ?? this.personName,
      message: message,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

String? _emptyToNull(Object? value) {
  if (value == null) return null;

  final String text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;

  return text;
}
