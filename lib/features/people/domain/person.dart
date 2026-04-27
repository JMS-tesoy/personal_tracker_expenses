// lib/features/people/domain/person.dart

class PersonModel {
  const PersonModel({
    required this.id,
    required this.userId,
    required this.name,
    this.nickname,
    this.phone,
    this.email,
    this.notes,
    this.avatarUrl,
    this.role,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? nickname;
  final String? phone;
  final String? email;
  final String? notes;
  final String? avatarUrl;
  final String? role;
  final DateTime createdAt;

  String get displayName => nickname?.isNotEmpty == true ? nickname! : name;

  String get initials {
    final List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory PersonModel.fromMap(Map<String, dynamic> map) {
    return PersonModel(
      id:        map['id'] as String,
      userId:    map['user_id'] as String,
      name:      map['name'] as String,
      nickname:  map['nickname'] as String?,
      phone:     map['phone'] as String?,
      email:     map['email'] as String?,
      notes:     map['notes'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role:      map['role'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return <String, dynamic>{
      'user_id': userId,
      'name':    name,
      if (nickname != null && nickname!.isNotEmpty) 'nickname': nickname,
      if (phone != null && phone!.isNotEmpty)       'phone':    phone,
      if (email != null && email!.isNotEmpty)       'email':    email,
      if (notes != null && notes!.isNotEmpty)       'notes':    notes,
      if (role != null && role!.isNotEmpty)         'role':     role,
    };
  }
}

typedef Person = PersonModel;
