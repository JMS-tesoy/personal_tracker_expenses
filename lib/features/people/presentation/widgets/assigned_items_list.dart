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
          count: summary.assignedBillsCount,
          items: summary.assignedBills,
          emptyMessage: 'No assigned bills yet.',
          itemBuilder: (Map<String, dynamic> item) => _BillTile(bill: item),
        ),
        _Section(
          icon: Icons.check_circle_outline,
          title: 'Paid Bills',
          count: summary.paidBillsCount,
          items: summary.paidBills,
          emptyMessage: 'No bills paid by this person yet.',
          itemBuilder: (Map<String, dynamic> item) => _BillTile(bill: item),
        ),
        _Section(
          icon: Icons.notifications_outlined,
          title: 'Reminders',
          count: summary.remindersCount,
          items: summary.reminders,
          emptyMessage: 'No reminders for this person.',
          itemBuilder: (Map<String, dynamic> item) =>
              _ReminderTile(reminder: item),
        ),
        _Section(
          icon: Icons.history_outlined,
          title: 'Recent Activity',
          count: summary.activityCount,
          items: summary.recentActivity,
          emptyMessage: 'No recent activity.',
          itemBuilder: (Map<String, dynamic> item) =>
              _ActivityTile(activity: item),
        ),
        _Section(
          icon: Icons.attach_file_outlined,
          title: 'Proof Uploads',
          count: summary.attachmentsCount,
          items: summary.attachments,
          emptyMessage: 'No proof uploads.',
          itemBuilder: (Map<String, dynamic> item) =>
              _AttachmentTile(attachment: item),
        ),
      ],
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.count,
    required this.items,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final IconData icon;
  final String title;
  final int count;
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
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.count}',
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
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            )
          else
            ...widget.items.map(widget.itemBuilder),
          const SizedBox(height: 4),
        ],
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.50)),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill});

  final Map<String, dynamic> bill;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String name = _stringValue(bill['name'], fallback: 'Bill');
    final dynamic amount = bill['amount'];
    final String status = _stringValue(bill['status']);
    final String dueText = _billDueText(bill);
    final String paidText = _billPaidText(bill);

    return _ItemRow(
      leading: Icons.receipt_outlined,
      title: name,
      subtitle: <String>[
        if (dueText.isNotEmpty) dueText,
        if (paidText.isNotEmpty) paidText,
        if (status.isNotEmpty) status.toUpperCase(),
      ].join(' • '),
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
    final String title = _stringValue(reminder['title'], fallback: 'Reminder');
    final String message = _stringValue(reminder['message']);
    final String remindAt = _stringValue(reminder['remind_at']);
    final String status = _stringValue(reminder['status'], fallback: 'active');

    return _ItemRow(
      leading: Icons.notifications_outlined,
      title: title,
      subtitle: message.isNotEmpty ? message : null,
      trailing: remindAt.isNotEmpty ? _fmtDate(remindAt) : null,
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
    final String title = _stringValue(
      activity['title'],
      fallback: _stringValue(activity['action'], fallback: 'Activity'),
    );
    final String description = _stringValue(activity['description']);
    final String createdAt = _stringValue(activity['created_at']);

    return _ItemRow(
      leading: Icons.history_outlined,
      title: title,
      subtitle: description.isNotEmpty ? description : null,
      trailing: createdAt.isNotEmpty ? _fmtDate(createdAt) : null,
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment});

  final Map<String, dynamic> attachment;

  @override
  Widget build(BuildContext context) {
    final String name = _stringValue(attachment['file_name'], fallback: 'File');
    final String createdAt = _stringValue(attachment['created_at']);
    final Map<String, dynamic>? device = _deviceMap(attachment['user_devices']);
    final String deviceName = _stringValue(device?['device_name']);
    final String platform = _stringValue(device?['platform']);

    return _ItemRow(
      leading: Icons.attach_file_outlined,
      title: name,
      subtitle: deviceName.isNotEmpty
          ? platform.isNotEmpty
                ? 'Device: $deviceName • $platform'
                : 'Device: $deviceName'
          : null,
      trailing: createdAt.isNotEmpty ? _fmtDate(createdAt) : null,
    );
  }

  Map<String, dynamic>? _deviceMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return null;
  }
}

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
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
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
    return d
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+\.)'),
          (Match m) => '${m[1]},',
        );
  } catch (_) {
    return value.toString();
  }
}

String _stringValue(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final String text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;

  return text;
}

String _billDueText(Map<String, dynamic> bill) {
  final String dueDate = _stringValue(bill['due_date']);
  if (dueDate.isNotEmpty) return 'Due ${_fmtDate(dueDate)}';

  final String dueDay = _stringValue(bill['due_day']);
  if (dueDay.isNotEmpty) return 'Due day $dueDay';

  return '';
}

String _billPaidText(Map<String, dynamic> bill) {
  final String paidOn = _stringValue(bill['paid_on']);
  if (paidOn.isEmpty) return '';

  return 'Paid ${_fmtDate(paidOn)}';
}
