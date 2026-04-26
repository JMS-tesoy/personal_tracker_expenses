import 'package:flutter/material.dart';

class PersonAvatar {
  const PersonAvatar({
    required this.id,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String id;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

const List<PersonAvatar> personAvatars = <PersonAvatar>[
  PersonAvatar(
    id: 'avatar_person',
    icon: Icons.person,
    backgroundColor: Color(0xFFDDE7FF),
    foregroundColor: Color(0xFF2854A3),
  ),
  PersonAvatar(
    id: 'avatar_family',
    icon: Icons.group,
    backgroundColor: Color(0xFFE5F4E8),
    foregroundColor: Color(0xFF2F6B3E),
  ),
  PersonAvatar(
    id: 'avatar_friend',
    icon: Icons.people,
    backgroundColor: Color(0xFFFFE9D6),
    foregroundColor: Color(0xFF9A4E12),
  ),
  PersonAvatar(
    id: 'avatar_work',
    icon: Icons.work,
    backgroundColor: Color(0xFFE8E1F4),
    foregroundColor: Color(0xFF5B3E8C),
  ),
  PersonAvatar(
    id: 'avatar_home',
    icon: Icons.home,
    backgroundColor: Color(0xFFDFF3F6),
    foregroundColor: Color(0xFF226775),
  ),
  PersonAvatar(
    id: 'avatar_wallet',
    icon: Icons.account_balance_wallet,
    backgroundColor: Color(0xFFF3EAC8),
    foregroundColor: Color(0xFF755E12),
  ),
  PersonAvatar(
    id: 'avatar_star',
    icon: Icons.star,
    backgroundColor: Color(0xFFFFE2EA),
    foregroundColor: Color(0xFF9B2F52),
  ),
  PersonAvatar(
    id: 'avatar_face',
    icon: Icons.face,
    backgroundColor: Color(0xFFE3F0D8),
    foregroundColor: Color(0xFF4D7132),
  ),
];

PersonAvatar? personAvatarById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final PersonAvatar avatar in personAvatars) {
    if (avatar.id == id) return avatar;
  }
  return null;
}
