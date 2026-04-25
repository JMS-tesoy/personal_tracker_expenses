import 'package:flutter/material.dart';

import '../../data/attachment_service.dart';
import '../../domain/attachment.dart';

class ProofUploadBox extends StatefulWidget {
  const ProofUploadBox({
    super.key,
    required this.billId,
    this.uploadedByPersonId,
    required this.onUploaded,
  });

  final String billId;
  final String? uploadedByPersonId;
  final Future<void> Function(AttachmentModel attachment) onUploaded;

  @override
  State<ProofUploadBox> createState() => _ProofUploadBoxState();
}

class _ProofUploadBoxState extends State<ProofUploadBox> {
  final AttachmentService _service = AttachmentService();
  bool _uploading = false;

  Future<void> _upload() async {
    if (widget.billId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload payment proof')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final AttachmentModel attachment = await _service.pickAndUpload(
        billId: widget.billId,
        uploadedByPersonId: widget.uploadedByPersonId,
      );
      if (!mounted) return;
      await widget.onUploaded(attachment);
    } on PaymentProofUploadCancelled {
      return;
    } catch (error, stackTrace) {
      debugPrint('Failed to upload payment proof: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload payment proof')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file_outlined, size: 18),
        label: Text(_uploading ? 'Uploading...' : 'Upload Payment Proof'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );
  }
}
