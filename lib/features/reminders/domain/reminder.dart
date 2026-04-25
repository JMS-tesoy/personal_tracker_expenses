import '../../../core/utils/bill_due_date_helper.dart';
import '../../bills/domain/bill.dart';

class ReminderModel {
  const ReminderModel({
    required this.id,
    required this.billId,
    required this.billName,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.assignedPersonName,
  });

  final String id;
  final String billId;
  final String billName;
  final double amount;
  final DateTime dueDate;
  final String status;
  final String? assignedPersonName;

  bool get isOverdue => status == 'overdue';
  bool get isDueSoon => status == 'due_soon';

  int get daysUntilDue {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return dueDate.difference(today).inDays;
  }

  factory ReminderModel.fromBill(BillModel bill) {
    final DateTime dueDate = BillDueDateHelper.dueDateForMonth(
      dueDay: bill.dueDay,
    );
    final String status;
    if (bill.isOverdue) {
      status = 'overdue';
    } else if (BillDueDateHelper.isDueSoon(
      dueDay: bill.dueDay,
      status: bill.status,
    )) {
      status = 'due_soon';
    } else {
      status = 'upcoming';
    }

    return ReminderModel(
      id: bill.id,
      billId: bill.id,
      billName: bill.name,
      amount: bill.amount,
      dueDate: dueDate,
      status: status,
      assignedPersonName: bill.assignedPersonName,
    );
  }
}
