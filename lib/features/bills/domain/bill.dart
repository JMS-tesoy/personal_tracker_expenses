import '../../../core/utils/bill_due_date_helper.dart';

class BillModel {
  const BillModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    this.assignedPersonId,
    this.assignedPersonName,
    this.paidByPersonId,
    this.paidByPersonName,
    this.paidByPersonIds = const <String>[],
    this.paidByPersonNames = const <String>[],
    this.paidOn,
    required this.paymentMethod,
    required this.status,
    this.notes,
    this.remarks,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double amount;
  final int dueDay;
  final String? assignedPersonId;
  final String? assignedPersonName;
  final String? paidByPersonId;
  final String? paidByPersonName;
  final List<String> paidByPersonIds;
  final List<String> paidByPersonNames;
  final DateTime? paidOn;
  final String paymentMethod;
  final String status;
  final String? notes;
  final String? remarks;
  final DateTime createdAt;

  bool get isPaid => status.trim().toLowerCase() == 'paid';
  bool get isActive {
    final String normalized = status.trim().toLowerCase();
    return normalized == 'active' || normalized == 'unpaid';
  }

  bool get isOverdue {
    return status.trim().toLowerCase() == 'overdue' ||
        BillDueDateHelper.isOverdue(dueDay: dueDay, status: status);
  }

  bool get isUnpaid => isActive && !isOverdue;

  String? get paidByDisplayName {
    if (paidByPersonNames.isNotEmpty) return paidByPersonNames.join(', ');
    return paidByPersonName;
  }

  String get displayStatus {
    if (isPaid) return 'paid';
    if (isOverdue) return 'overdue';
    return 'active';
  }

  BillModel copyWith({
    String? status,
    DateTime? paidOn,
    String? paidByPersonId,
    String? paidByPersonName,
    List<String>? paidByPersonIds,
    List<String>? paidByPersonNames,
    String? remarks,
  }) {
    return BillModel(
      id: id,
      name: name,
      amount: amount,
      dueDay: dueDay,
      assignedPersonId: assignedPersonId,
      assignedPersonName: assignedPersonName,
      paidByPersonId: paidByPersonId ?? this.paidByPersonId,
      paidByPersonName: paidByPersonName ?? this.paidByPersonName,
      paidByPersonIds: paidByPersonIds ?? this.paidByPersonIds,
      paidByPersonNames: paidByPersonNames ?? this.paidByPersonNames,
      paidOn: paidOn ?? this.paidOn,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      notes: notes,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt,
    );
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    final String? paidByPersonId = _emptyToNull(map['paid_by_person_id']);
    final List<String> paidByPersonIds =
        _parseStringList(map['paid_by_person_ids']);
    final List<String> mergedPaidByPersonIds = paidByPersonIds.isNotEmpty
        ? paidByPersonIds
        : <String>[?paidByPersonId];

    return BillModel(
      id: map['id'].toString(),
      name: map['name'].toString(),
      amount: _parseAmount(map['amount']),
      dueDay: _parseInt(map['due_day'], fallback: 1),
      assignedPersonId: _emptyToNull(map['assigned_person_id']),
      assignedPersonName: _emptyToNull(map['assigned_person_name']),
      paidByPersonId: paidByPersonId,
      paidByPersonName: _emptyToNull(map['paid_by_person_name']),
      paidByPersonIds: mergedPaidByPersonIds,
      paidByPersonNames: _parseStringList(map['paid_by_person_names']),
      paidOn: _parseDate(map['paid_on']),
      paymentMethod: map['payment_method']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      notes: _emptyToNull(map['notes']),
      remarks: _emptyToNull(map['remarks']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(dynamic value) {
    final String? text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? _emptyToNull(dynamic value) {
    final String? text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map((dynamic item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList();
  }
}
