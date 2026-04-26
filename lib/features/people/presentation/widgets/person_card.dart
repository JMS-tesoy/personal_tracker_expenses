import 'package:flutter/material.dart';

import '../../../../features/reminders/presentation/widgets/reminder_form_sheet.dart';
import '../../domain/person.dart';

class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
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
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Text(
            initials,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: person.role != null && person.role!.isNotEmpty
            ? Text(person.role!, style: TextStyle(color: colors.outline))
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
