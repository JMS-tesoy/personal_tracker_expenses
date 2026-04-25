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
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      avatarUrl: map['avatar_url'] as String?,
      role: map['role'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'avatar_url': avatarUrl,
      'role': role,
    };
  }
}
