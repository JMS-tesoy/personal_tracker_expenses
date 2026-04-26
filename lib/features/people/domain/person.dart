class Person {
  const Person({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.role,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String? role;
  final DateTime? createdAt;

  factory Person.fromMap(Map<String, dynamic> map) {
    final String? createdAtText = map['created_at']?.toString();

    return Person(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unnamed person',
      avatarUrl: _emptyToNull(map['avatar_url']),
      role: _emptyToNull(map['role']),
      createdAt: createdAtText == null
          ? null
          : DateTime.tryParse(createdAtText),
    );
  }

  static String? _emptyToNull(dynamic value) {
    final String? text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'avatar_url': avatarUrl,
      'role': role,
    };
  }
}
