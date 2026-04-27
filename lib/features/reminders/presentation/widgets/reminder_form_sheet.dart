import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../../people/domain/person.dart';
import '../../data/models/reminder_model.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../services/local_notification_service.dart';

class ReminderFormSheet extends StatefulWidget {
  const ReminderFormSheet({
    super.key,
    this.targetType = 'general',
    this.targetId,
    this.personId,
    this.prefillTitle,
    this.prefillDueAt,
    this.existingReminder,
  });

  final String targetType;
  final String? targetId;
  final String? personId;
  final String? prefillTitle;
  final DateTime? prefillDueAt;
  final ReminderModel? existingReminder;

  @override
  State<ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends State<ReminderFormSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  late DateTime _remindAt;
  String _repeatType = 'none';
  bool _isSaving = false;

  // People picker state
  List<PersonModel> _people = <PersonModel>[];
  String? _selectedPersonId;
  bool _loadingPeople = true;

  final List<String> _repeatOptions = <String>[
    'none',
    'daily',
    'weekly',
    'monthly',
  ];

  @override
  void initState() {
    super.initState();
    final ReminderModel? existing = widget.existingReminder;

    if (existing != null) {
      _titleController.text = existing.title;
      _messageController.text = existing.message ?? '';
      _remindAt = existing.remindAt;
      _repeatType = existing.repeatType;
      _selectedPersonId = existing.personId;
    } else {
      _titleController.text = widget.prefillTitle ?? '';
      _selectedPersonId = widget.personId;
      final DateTime base = widget.prefillDueAt ?? DateTime.now();
      _remindAt = DateTime(base.year, base.month, base.day, 9, 0);
      if (_remindAt.isBefore(DateTime.now())) {
        final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
        _remindAt =
            DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
      }
    }

    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final String userId = requireCurrentUserId();
      final List<dynamic> response = await _supabase
          .from('people')
          .select()
          .eq('user_id', userId)
          .order('name', ascending: true);

      if (!mounted) return;
      setState(() {
        _people = response
            .map((dynamic e) =>
                PersonModel.fromMap(e as Map<String, dynamic>))
            .toList();
        _loadingPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPeople = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _remindAt,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _remindAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('Enter a reminder title.');
      return;
    }

    final String? uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      _showSnack('You must be logged in.');
      return;
    }

    setState(() => _isSaving = true);

    // Determine effective targetType and targetId
    // If a person is selected and target is general, upgrade to person
    String effectiveTargetType = widget.targetType;
    String? effectiveTargetId = widget.targetId;
    if (_selectedPersonId != null &&
        effectiveTargetType == 'general' &&
        effectiveTargetId == null) {
      effectiveTargetType = 'person';
      effectiveTargetId = _selectedPersonId;
    }

    final ReminderModel model = ReminderModel(
      id: widget.existingReminder?.id ?? '',
      userId: uid,
      targetType: effectiveTargetType,
      targetId: effectiveTargetId,
      personId: _selectedPersonId,
      title: title,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
      dueAt: widget.prefillDueAt,
      remindAt: _remindAt,
      repeatType: _repeatType,
      status: 'active',
      notificationId: widget.existingReminder?.notificationId,
      createdAt: widget.existingReminder?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ReminderModel? saved;

    if (widget.existingReminder != null) {
      saved = await ReminderRepository.instance.updateReminder(model);
    } else {
      saved = await ReminderRepository.instance.createReminder(model);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved == null) {
      _showSnack('Could not save reminder.');
      return;
    }

    final bool hasPermission =
        await LocalNotificationService.instance.requestPermission();

    if (!mounted) return;

    final String successMsg = hasPermission
        ? 'Reminder saved.'
        : 'Reminder saved, but phone notifications are disabled.';

    _showSnack(successMsg);
    Navigator.pop(context, saved);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDateTime(DateTime dt) {
    final String mo = dt.month.toString().padLeft(2, '0');
    final String da = dt.day.toString().padLeft(2, '0');
    final int hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final String min = dt.minute.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$mo/$da/${dt.year}  $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.existingReminder != null
                      ? 'Edit Reminder'
                      : 'Add Reminder',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),

          // Message
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),

          // Person picker
          _loadingPeople
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _people.isEmpty
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<String?>(
                      initialValue: _selectedPersonId,
                      decoration: InputDecoration(
                        labelText: 'Person (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No person'),
                        ),
                        ..._people.map(
                          (PersonModel p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (String? val) {
                        setState(() => _selectedPersonId = val);
                      },
                    ),
          if (!_loadingPeople && _people.isNotEmpty)
            const SizedBox(height: 12),

          // Remind at
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.notifications_outlined,
                      color: colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Remind at:  ${_formatDateTime(_remindAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.edit_calendar_outlined,
                      color: colorScheme.onSurfaceVariant, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Repeat
          DropdownButtonFormField<String>(
            initialValue: _repeatType,
            decoration: InputDecoration(
              labelText: 'Repeat',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            items: _repeatOptions
                .map(
                  (String v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(v[0].toUpperCase() + v.substring(1)),
                  ),
                )
                .toList(),
            onChanged: (String? val) {
              if (val != null) setState(() => _repeatType = val);
            },
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _isSaving ? 'Saving...' : 'Save Reminder',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience function — call this from any screen.
Future<ReminderModel?> showReminderFormSheet(
  BuildContext context, {
  String targetType = 'general',
  String? targetId,
  String? personId,
  String? prefillTitle,
  DateTime? prefillDueAt,
  ReminderModel? existingReminder,
}) async {
  return showModalBottomSheet<ReminderModel>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReminderFormSheet(
      targetType: targetType,
      targetId: targetId,
      personId: personId,
      prefillTitle: prefillTitle,
      prefillDueAt: prefillDueAt,
      existingReminder: existingReminder,
    ),
  );
}