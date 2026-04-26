import 'package:flutter/material.dart';

import '../../../../features/reminders/presentation/widgets/reminder_form_sheet.dart';
import '../../domain/person.dart';
import '../../domain/person_avatar.dart';

class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.person, this.onLongPress});

  final Person person;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? role = person.role?.trim();
    final PersonAvatar? avatar = personAvatarById(person.avatarUrl);
    final String initials = person.name.isNotEmpty
        ? person.name
              .trim()
              .split(' ')
              .map((String w) => w[0])
              .take(2)
              .join()
              .toUpperCase()
        : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onLongPress: onLongPress,
        leading: CircleAvatar(
          backgroundColor: avatar?.backgroundColor ?? colors.primaryContainer,
          child: avatar == null
              ? Text(
                  initials,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Icon(avatar.icon, color: avatar.foregroundColor),
        ),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: role != null && role.isNotEmpty
            ? Text(role, style: TextStyle(color: colors.outline))
            : null,
        trailing: IconButton(
          icon: Icon(Icons.add_alert_outlined, color: colors.primary),
          tooltip: 'Add Reminder',
          onPressed: () => showReminderFormSheet(
            context,
            targetType: 'person',
            targetId: person.id,
            personId: person.id,
            prefillTitle: 'Reminder for ${person.name}',
          ),
        ),
      ),
    );
  }
}
