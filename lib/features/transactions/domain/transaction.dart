class TransactionModel {
  final String id;
  final double amount;
  final String type; // income or expense
  final String category;
  final String paymentMethod;
  final DateTime date;
  final String? note;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.paymentMethod,
    required this.date,
    this.note,
  });
}