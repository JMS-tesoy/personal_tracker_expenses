// lib/features/people/presentation/widgets/person_card.dart
//
// Minimal update: added optional onTap parameter.
// All existing onLongPress behaviour preserved.

import 'package:flutter/material.dart';

import '../../domain/person.dart';

class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.person,
    this.onTap, // ← ADDED: opens PersonDetailsScreen
    this.onLongPress, // existing: opens delete dialog
  });

  final Person person;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              // Avatar circle
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  _initials(person.name),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      person.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (person.role != null && person.role!.isNotEmpty)
                      Text(
                        person.role!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // Chevron hint that card is tappable
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.60),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
