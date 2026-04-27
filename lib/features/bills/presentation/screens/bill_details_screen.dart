import 'package:flutter/material.dart';

import '../../../../core/utils/bill_due_date_helper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../activity/data/repositories/activity_log_repository.dart';
import '../../../attachments/data/attachment_service.dart';
import '../../../attachments/domain/attachment.dart';
import '../../../attachments/presentation/widgets/proof_upload_box.dart';
import '../../../reminders/presentation/widgets/reminder_form_sheet.dart';
import '../../domain/bill.dart';

class BillDetailsScreen extends StatefulWidget {
  const BillDetailsScreen({super.key, required this.bill, this.onBack});

  final BillModel bill;
  final VoidCallback? onBack;

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  final AttachmentService _service = AttachmentService();

  List<AttachmentModel> _attachments = <AttachmentModel>[];
  bool _loadingAttachments = true;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    setState(() => _loadingAttachments = true);
    try {
      final List<AttachmentModel> result = await _service.fetchForBill(
        widget.bill.id,
      );
      if (!mounted) return;
      setState(() => _attachments = result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load attachments.')),
      );
    } finally {
      if (mounted) setState(() => _loadingAttachments = false);
    }
  }

  Future<void> _handleProofUploaded(AttachmentModel attachment) async {
    await _loadAttachments();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Payment proof uploaded')));
  }

  Widget _buildUploadBox(BillModel bill) {
    return ProofUploadBox(
      billId: bill.id,
      uploadedByPersonId: bill.paidByPersonId,
      onUploaded: _handleProofUploaded,
    );
  }

  DateTime _nextBillDueDate(BillModel bill) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dueDate = BillDueDateHelper.dueDateForMonth(
      dueDay: bill.dueDay,
      fromDate: today,
    );

    if (!dueDate.isBefore(today)) return dueDate;

    return BillDueDateHelper.dueDateForMonth(
      dueDay: bill.dueDay,
      fromDate: DateTime(today.year, today.month + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BillModel bill = widget.bill;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
        title: Text(bill.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: 'Add reminder',
            onPressed: () async {
              final result = await showReminderFormSheet(
                context,
                targetType: 'bill',
                targetId: bill.id,
                prefillTitle: '${bill.name} bill',
                prefillDueAt: _nextBillDueDate(bill),
              );
              if (result == null) return;
              await ActivityLogRepository.instance.createLog(
                targetType: result.targetType,
                action: 'reminder_created',
                title: 'Reminder created',
                targetId: result.targetId,
                personId: result.personId,
                description: '${result.title} was scheduled.',
                metadata: <String, dynamic>{
                  'reminder_title': result.title,
                  'remind_at': result.remindAt.toIso8601String(),
                },
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: <Widget>[
          // ── Bill Info ─────────────────────────────────────────────────
          _SectionHeader(title: 'Bill Details'),
          const SizedBox(height: 12),
          _DetailRow(label: 'Name', value: bill.name),
          _DetailRow(
            label: 'Amount',
            value: CurrencyFormatter.format(bill.amount),
          ),
          _DetailRow(
            label: 'Due day',
            value: '${bill.dueDay.toString().padLeft(2, '0')} of every month',
          ),
          _DetailRow(
            label: 'Payment method',
            value: bill.paymentMethod.isEmpty ? '—' : bill.paymentMethod,
          ),
          _DetailRow(label: 'Status', value: bill.displayStatus.toUpperCase()),
          if (bill.assignedPersonName != null)
            _DetailRow(label: 'Assigned to', value: bill.assignedPersonName!),
          if (bill.paidByDisplayName != null)
            _DetailRow(label: 'Paid by', value: bill.paidByDisplayName!),
          if (bill.paidOn != null)
            _DetailRow(label: 'Paid on', value: _formatDate(bill.paidOn!)),
          _DetailRow(label: 'Notes', value: _textOrDash(bill.notes)),
          _DetailRow(label: 'Remarks', value: _textOrDash(bill.remarks)),

          const SizedBox(height: 28),

          // ── Payment Proof ─────────────────────────────────────────────
          _SectionHeader(title: 'Payment Proof'),
          const SizedBox(height: 12),

          if (_loadingAttachments)
            const Center(child: CircularProgressIndicator())
          else if (_attachments.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _EmptyProofBox(),
                const SizedBox(height: 12),
                _buildUploadBox(bill),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ..._attachments.map(
                  (AttachmentModel a) => _ProofTile(attachment: a),
                ),
                const SizedBox(height: 12),
                _buildUploadBox(bill),
              ],
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$m/$d/${date.year}';
  }

  String _textOrDash(String? value) {
    final String? text = value?.trim();
    return text == null || text.isEmpty ? '—' : text;
  }
}

// ── Proof tile ────────────────────────────────────────────────────────────────

class _ProofTile extends StatelessWidget {
  const _ProofTile({required this.attachment});

  final AttachmentModel attachment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String fileUrl = attachment.fileUrl.trim();
    final bool hasFileUrl =
        fileUrl.isNotEmpty && fileUrl.toLowerCase() != 'null';
    final String? fileName = attachment.fileName?.trim();
    final String? notes = attachment.notes?.trim();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasFileUrl)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Image.network(
                fileUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder:
                    (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  color: colors.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fileName != null && fileName.isNotEmpty
                      ? fileName
                      : 'Payment proof',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  attachment.createdAt != null
                      ? 'Uploaded: ${_formatDate(attachment.createdAt!)}'
                      : 'Uploaded date unavailable',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(notes, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$m/$d/${date.year}';
  }
}

class _EmptyProofBox extends StatelessWidget {
  const _EmptyProofBox();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant, width: 1.5),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.upload_file_outlined,
            size: 40,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No payment proof uploaded yet',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Reusable detail widgets ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
