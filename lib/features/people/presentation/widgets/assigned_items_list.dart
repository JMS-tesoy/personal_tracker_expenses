// lib/features/people/presentation/widgets/assigned_items_list.dart

import 'package:flutter/material.dart';

import '../../data/people_repository.dart';

class AssignedItemsList extends StatelessWidget {
  const AssignedItemsList({super.key, required this.summary});

  final PersonSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Section(
          icon: Icons.receipt_long_outlined,
          title: 'Assigned Bills',
          items: summary.assignedBills,
          emptyMessage: 'No assigned bills yet.',
          itemBuilder: (Map<String, dynamic> item) => _BillTile(bill: item),
        ),
        _Section(
          icon: Icons.check_circle_outline,
          title: 'Paid Bills',
          items: summary.paidBills,
          emptyMessage: 'No bills paid by this person yet.',
          itemBuilder: (Map<String, dynamic> item) => _BillTile(bill: item),
        ),
        _Section(
          icon: Icons.notifications_outlined,
          title: 'Reminders',
          items: summary.reminders,
          emptyMessage: 'No reminders for this person.',
          itemBuilder: (Map<String, dynamic> item) =>
              _ReminderTile(reminder: item),
        ),
        _Section(
          icon: Icons.history_outlined,
          title: 'Recent Activity',
          items: summary.recentActivity,
          emptyMessage: 'No recent activity.',
          itemBuilder: (Map<String, dynamic> item) =>
              _ActivityTile(activity: item),
        ),
        _Section(
          icon: Icons.attach_file_outlined,
          title: 'Proof Uploads',
          items: summary.attachments,
          emptyMessage: 'No proof uploads.',
          itemBuilder: (Map<String, dynamic> item) =>
              _AttachmentTile(attachment: item),
        ),
      ],
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatefulWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final IconData icon;
  final String title;
  final List<Map<String, dynamic>> items;
  final String emptyMessage;
  final Widget Function(Map<String, dynamic>) itemBuilder;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Header row
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(widget.icon, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...<Widget>[
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 12),
              child: Text(
                widget.emptyMessage,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            )
          else
            ...widget.items.map(widget.itemBuilder),
          const SizedBox(height: 4),
        ],

        Divider(
          height: 1,
          color: cs.outlineVariant.withValues(alpha: 0.50),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Tile widgets ──────────────────────────────────────────────────────────────

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill});
  final Map<String, dynamic> bill;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String name = bill['name'] as String? ?? 'Bill';
    final dynamic amount = bill['amount'];
    final String status = bill['status'] as String? ?? '';
    final String? dueDate = bill['due_date'] as String?;

    return _ItemRow(
      leading: Icons.receipt_outlined,
      title: name,
      subtitle: dueDate != null ? 'Due: ${_fmtDate(dueDate)}' : null,
      trailing: amount != null ? '₱${_fmtNum(amount)}' : null,
      trailingColor: status == 'paid' ? const Color(0xFF2E7D52) : cs.primary,
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder});
  final Map<String, dynamic> reminder;

  @override
  Widget build(BuildContext context) {
    final String title = reminder['title'] as String? ?? 'Reminder';
    final String? message = reminder['message'] as String?;
    final String? remindAt = reminder['remind_at'] as String?;
    final String status = reminder['status'] as String? ?? 'active';

    return _ItemRow(
      leading: Icons.notifications_outlined,
      title: title,
      subtitle: message?.isNotEmpty == true ? message : null,
      trailing: remindAt != null ? _fmtDate(remindAt) : null,
      trailingColor: status == 'active'
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});
  final Map<String, dynamic> activity;

  @override
  Widget build(BuildContext context) {
    final String action = activity['action'] as String? ?? 'Activity';
    final String? description = activity['description'] as String?;
    final String? createdAt = activity['created_at'] as String?;

    return _ItemRow(
      leading: Icons.history_outlined,
      title: action,
      subtitle: description,
      trailing: createdAt != null ? _fmtDate(createdAt) : null,
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});
  final Map<String, dynamic> attachment;

  @override
  Widget build(BuildContext context) {
    final String name = attachment['file_name'] as String? ?? 'File';
    final String? createdAt = attachment['created_at'] as String?;

    return _ItemRow(
      leading: Icons.attach_file_outlined,
      title: name,
      trailing: createdAt != null ? _fmtDate(createdAt) : null,
    );
  }
}

// ── Shared row ────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingColor,
  });

  final IconData leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(leading, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: trailingColor ?? cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

String _fmtDate(String iso) {
  try {
    final DateTime dt = DateTime.parse(iso).toLocal();
    final String m = dt.month.toString().padLeft(2, '0');
    final String d = dt.day.toString().padLeft(2, '0');
    return '$m/$d/${dt.year}';
  } catch (_) {
    return iso;
  }
}

String _fmtNum(dynamic value) {
  try {
    final double d = double.parse(value.toString());
    return d.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.)'),
          (Match m) => '${m[1]},',
        );
  } catch (_) {
    return value.toString();
  }
}
