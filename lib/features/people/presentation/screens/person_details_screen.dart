// lib/features/people/presentation/screens/person_details_screen.dart

import 'package:flutter/material.dart';

import '../../../../shared/widgets/floating_action_surface.dart';
import '../../../reminders/presentation/widgets/reminder_form_sheet.dart';
import '../../data/people_repository.dart';
import '../../domain/person.dart';
import '../widgets/assigned_items_list.dart';

class PersonDetailsScreen extends StatefulWidget {
  const PersonDetailsScreen({
    super.key,
    required this.person,
    this.onBack,
  });

  final PersonModel person;
  final VoidCallback? onBack;

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  PersonSummary _summary = PersonSummary.empty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final PersonSummary summary =
        await PeopleRepository.instance.fetchSummary(widget.person.id);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _isLoading = false;
    });
  }

  void _pop() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _showAssignedBillsDialog() async {
    await _showLinkedItemsDialog(
      title: '${widget.person.displayName} assigned bills',
      items: _summary.assignedBills,
      emptyMessage: 'No assigned bills yet.',
      itemBuilder: (Map<String, dynamic> bill) => _buildBillDialogTile(
        bill,
        Icons.receipt_long_outlined,
      ),
    );
  }

  Future<void> _showPaidBillsDialog() async {
    await _showLinkedItemsDialog(
      title: '${widget.person.displayName} paid bills',
      items: _summary.paidBills,
      emptyMessage: 'No bills paid by this person yet.',
      itemBuilder: (Map<String, dynamic> bill) => _buildBillDialogTile(
        bill,
        Icons.check_circle_outline,
      ),
    );
  }

  Future<void> _showRemindersDialog() async {
    await _showLinkedItemsDialog(
      title: '${widget.person.displayName} reminders',
      items: _summary.reminders,
      emptyMessage: 'No reminders for this person.',
      itemBuilder: _buildReminderDialogTile,
    );
  }

  Future<void> _showProofsDialog() async {
    await _showLinkedItemsDialog(
      title: '${widget.person.displayName} proofs',
      items: _summary.attachments,
      emptyMessage: 'No proof uploads for this person.',
      itemBuilder: _buildProofDialogTile,
    );
  }

  Future<void> _showLinkedItemsDialog({
    required String title,
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.55,
              ),
              child: items.isEmpty
                  ? Text(emptyMessage)
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(height: 18),
                      itemBuilder: (BuildContext context, int index) =>
                          itemBuilder(items[index]),
                    ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBillDialogTile(Map<String, dynamic> bill, IconData icon) {
    final String name = bill['name'] as String? ?? 'Bill';
    final dynamic amount = bill['amount'];
    final String? dueDate = bill['due_date'] as String?;
    final String status = bill['status'] as String? ?? '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(name),
      subtitle: dueDate == null
          ? null
          : Text('Due ${_formatDialogDate(dueDate)}'),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (amount != null) Text('₱${_formatDialogAmount(amount)}'),
          if (status.isNotEmpty) Text(status.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildReminderDialogTile(Map<String, dynamic> reminder) {
    final String title = reminder['title'] as String? ?? 'Reminder';
    final String? message = reminder['message'] as String?;
    final String? remindAt = reminder['remind_at'] as String?;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.notifications_outlined),
      title: Text(title),
      subtitle: message != null && message.isNotEmpty ? Text(message) : null,
      trailing: remindAt == null ? null : Text(_formatDialogDate(remindAt)),
    );
  }

  Widget _buildProofDialogTile(Map<String, dynamic> attachment) {
    final String fileName = attachment['file_name'] as String? ?? 'Proof';
    final String? createdAt = attachment['created_at'] as String?;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.attach_file_outlined),
      title: Text(fileName),
      trailing: createdAt == null ? null : Text(_formatDialogDate(createdAt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PersonModel person = widget.person;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _pop,
              ),
        title: Text(person.displayName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: 'Add reminder',
            onPressed: () async {
              final dynamic result = await showReminderFormSheet(
                context,
                targetType:   'person',
                personId:     person.id,
                prefillTitle: '${person.displayName} responsibility',
              );
              // Reload summary so the Reminders count chip updates immediately.
              if (result != null && mounted) {
                _load();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ── Avatar + profile card ──────────────────────────
                        _ProfileCard(person: person, cs: cs),
                        const SizedBox(height: 8),

                        // ── Stats row ──────────────────────────────────────
                        _StatsRow(
                          summary: _summary,
                          cs: cs,
                          onAssignedTap: _showAssignedBillsDialog,
                          onPaidTap: _showPaidBillsDialog,
                          onRemindersTap: _showRemindersDialog,
                          onProofsTap: _showProofsDialog,
                        ),
                        const SizedBox(height: 20),

                        // ── Assigned items sections ────────────────────────
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: AssignedItemsList(summary: _summary),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.person, required this.cs});
  final PersonModel person;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: cs.primaryContainer,
            backgroundImage: person.avatarUrl != null
                ? NetworkImage(person.avatarUrl!)
                : null,
            child: person.avatarUrl == null
                ? Text(
                    person.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  person.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (person.nickname != null &&
                    person.nickname!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '"${person.nickname}"',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (person.phone != null &&
                    person.phone!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Icon(Icons.phone_outlined,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        person.phone!,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                if (person.email != null &&
                    person.email!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Icon(Icons.email_outlined,
                          size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          person.email!,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (person.notes != null &&
                    person.notes!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    person.notes!,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.summary,
    required this.cs,
    required this.onAssignedTap,
    required this.onPaidTap,
    required this.onRemindersTap,
    required this.onProofsTap,
  });

  final PersonSummary summary;
  final ColorScheme cs;
  final VoidCallback onAssignedTap;
  final VoidCallback onPaidTap;
  final VoidCallback onRemindersTap;
  final VoidCallback onProofsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          _StatChip(
            icon: Icons.receipt_long_outlined,
            label: 'Assigned',
            count: summary.assignedBillsCount,
            cs: cs,
            onTap: onAssignedTap,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.check_circle_outline,
            label: 'Paid',
            count: summary.paidBillsCount,
            cs: cs,
            onTap: onPaidTap,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.notifications_outlined,
            label: 'Reminders',
            count: summary.remindersCount,
            cs: cs,
            onTap: onRemindersTap,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.attach_file_outlined,
            label: 'Proofs',
            count: summary.attachmentsCount,
            cs: cs,
            onTap: onProofsTap,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.cs,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FloatingActionSurface(
        onTap: onTap,
        minHeight: 76,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: cs.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDialogDate(String iso) {
  try {
    final DateTime dt = DateTime.parse(iso).toLocal();
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    return '$m/$d/${dt.year}';
  } catch (_) {
    return iso;
  }
}

String _formatDialogAmount(dynamic value) {
  try {
    final double amount = double.parse(value.toString());
    return amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.)'),
          (Match match) => '${match[1]},',
        );
  } catch (_) {
    return value.toString();
  }
}