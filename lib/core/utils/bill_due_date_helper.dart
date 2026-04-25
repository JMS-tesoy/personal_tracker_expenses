class BillDueDateHelper {
  const BillDueDateHelper._();

  static DateTime dueDateForMonth({required int dueDay, DateTime? fromDate}) {
    final DateTime baseDate = _dateOnly(fromDate ?? DateTime.now());
    final int lastDay = _daysInMonth(baseDate.year, baseDate.month);
    final int safeDay = dueDay.clamp(1, lastDay).toInt();
    return DateTime(baseDate.year, baseDate.month, safeDay);
  }

  static bool isOverdue({
    required int dueDay,
    required String status,
    DateTime? today,
  }) {
    if (_isPaid(status)) return false;
    final DateTime currentDate = _dateOnly(today ?? DateTime.now());
    final DateTime dueDate = dueDateForMonth(
      dueDay: dueDay,
      fromDate: currentDate,
    );
    return currentDate.isAfter(dueDate);
  }

  static bool isDueSoon({
    required int dueDay,
    required String status,
    DateTime? today,
  }) {
    if (_isPaid(status)) return false;
    final int days = daysUntilDue(dueDay: dueDay, fromDate: today);
    return days >= 0 && days <= 3;
  }

  static int daysUntilDue({required int dueDay, DateTime? fromDate}) {
    final DateTime currentDate = _dateOnly(fromDate ?? DateTime.now());
    final DateTime dueDate = dueDateForMonth(
      dueDay: dueDay,
      fromDate: currentDate,
    );
    return dueDate.difference(currentDate).inDays;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _isPaid(String status) {
    return status.trim().toLowerCase() == 'paid';
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}
