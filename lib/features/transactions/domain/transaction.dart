class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String? categoryId;
  final String categoryName;
  final String paymentMethod;
  final String? note;
  final DateTime transactionDate;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    this.categoryId,
    required this.categoryName,
    required this.paymentMethod,
    this.note,
    required this.transactionDate,
    required this.createdAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      categoryId: map['category_id']?.toString(),
      categoryName: map['category_name']?.toString() ?? '',
      paymentMethod: map['payment_method'] as String,
      note: map['note'] as String?,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
