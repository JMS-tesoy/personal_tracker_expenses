class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String type;
  final DateTime createdAt;

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'].toString(),
      name: map['name'].toString(),
      type: map['type'].toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
