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
      paidOn: paidOn ?? this.paidOn,
      paymentMethod: paymentMethod,
      status: status ?? this.status,
      notes: notes,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt,
    );
  }

  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      id: map['id'].toString(),
      name: map['name'].toString(),
      amount: _parseAmount(map['amount']),
      dueDay: _parseInt(map['due_day'], fallback: 1),
      assignedPersonId: _emptyToNull(map['assigned_person_id']),
      assignedPersonName: _emptyToNull(map['assigned_person_name']),
      paidByPersonId: _emptyToNull(map['paid_by_person_id']),
      paidByPersonName: _emptyToNull(map['paid_by_person_name']),
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
}
