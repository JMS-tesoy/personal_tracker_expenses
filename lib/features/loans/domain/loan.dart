class LoanModel {
  const LoanModel({
    required this.id,
    required this.name,
    this.lender,
    required this.originalAmount,
    required this.remainingBalance,
    required this.monthlyInstallment,
    required this.dueDay,
    required this.status,
    required this.totalCycles,
    required this.paidCycles,
    required this.totalPaydays,
    required this.paidPaydays,
    this.startDate,
    this.nextDueDate,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? lender;
  final double originalAmount;
  final double remainingBalance;
  final double monthlyInstallment;
  final int dueDay;
  final String status;
  final int totalCycles;
  final int paidCycles;
  final int totalPaydays;
  final int paidPaydays;
  final DateTime? startDate;
  final DateTime? nextDueDate;
  final String? notes;
  final DateTime createdAt;

  double get perPaydayAllocation => monthlyInstallment / 2;

  int get remainingPaydays {
    final int remaining = totalPaydays - paidPaydays;
    return remaining < 0 ? 0 : remaining;
  }

  // Kept internally for legacy compatibility; not shown in UI.
  int get remainingCycles {
    final int remaining = totalCycles - paidCycles;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isPaid => status.toLowerCase() == 'paid';

  bool get isOverdue {
    if (isPaid) return false;
    if (nextDueDate != null) {
      final DateTime today = DateTime.now();
      final DateTime todayOnly = DateTime(today.year, today.month, today.day);
      final DateTime dueOnly = DateTime(
        nextDueDate!.year,
        nextDueDate!.month,
        nextDueDate!.day,
      );
      return todayOnly.isAfter(dueOnly);
    }
    return DateTime.now().day > dueDay;
  }

  String get displayStatus {
    if (isPaid) return 'paid';
    if (isOverdue || status.toLowerCase() == 'overdue') return 'overdue';
    return 'active';
  }

  LoanModel copyWith({
    double? remainingBalance,
    String? status,
    int? totalCycles,
    int? paidCycles,
    int? totalPaydays,
    int? paidPaydays,
    DateTime? startDate,
    DateTime? nextDueDate,
  }) {
    return LoanModel(
      id: id,
      name: name,
      lender: lender,
      originalAmount: originalAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      monthlyInstallment: monthlyInstallment,
      dueDay: dueDay,
      status: status ?? this.status,
      totalCycles: totalCycles ?? this.totalCycles,
      paidCycles: paidCycles ?? this.paidCycles,
      totalPaydays: totalPaydays ?? this.totalPaydays,
      paidPaydays: paidPaydays ?? this.paidPaydays,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      notes: notes,
      createdAt: createdAt,
    );
  }

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    final int parsedTotalCycles = parseInt(map['total_cycles'], fallback: 1);
    return LoanModel(
      id: map['id'].toString(),
      name: map['name'].toString(),
      lender: emptyToNull(map['lender']),
      originalAmount: parseAmount(map['original_amount']),
      remainingBalance: parseAmount(map['remaining_balance']),
      monthlyInstallment: parseAmount(map['monthly_installment']),
      dueDay: int.tryParse(map['due_day'].toString()) ?? 1,
      status: map['status']?.toString() ?? 'active',
      totalCycles: parsedTotalCycles,
      paidCycles: parseInt(map['paid_cycles']),
      totalPaydays: parseInt(
        map['total_paydays'],
        fallback: parsedTotalCycles * 2,
      ),
      paidPaydays: parseInt(map['paid_paydays']),
      startDate: parseDate(map['start_date']),
      nextDueDate: parseDate(map['next_due_date']),
      notes: emptyToNull(map['notes']),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static double parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? parseDate(dynamic value) {
    final String? text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? emptyToNull(dynamic value) {
    final String? text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
