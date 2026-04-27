import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/current_user.dart';
import '../../activity/data/repositories/activity_log_repository.dart';
import '../domain/attachment.dart';

class PaymentProofUploadCancelled implements Exception {
  const PaymentProofUploadCancelled();
}

class AttachmentService {
  AttachmentService() : _supabase = Supabase.instance.client;

  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  // IMPORTANT: bucket name must match exactly what was created in Supabase Storage
  static const String _bucket = 'payment-proofs';
  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB

  Future<AttachmentModel> pickAndUpload({
    required String billId,
    String? uploadedByPersonId,
  }) async {
    final String safeBillId = billId.trim();
    final String userId = requireCurrentUserId();

    if (safeBillId.isEmpty) {
      throw Exception('Missing bill id.');
    }

    // 1. Pick image
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) throw const PaymentProofUploadCancelled();

    final String rawName = picked.name.trim().isEmpty
        ? picked.path.split(Platform.pathSeparator).last
        : picked.name.trim();

    final String extension = _extensionFrom(rawName);
    final String? mimeType = picked.mimeType;
    final bool isImage =
        (mimeType != null && mimeType.startsWith('image/')) ||
        _allowedImageExtensions.contains(extension);

    if (!isImage) {
      throw Exception('Selected file is not an image.');
    }

    final File file = File(picked.path);
    final int size = await file.length();
    if (size > _maxBytes) {
      throw Exception('Image exceeds 5 MB limit.');
    }

    // 2. Build a safe unique storage path (no subfolder nesting issues)
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String safeExt = extension.isEmpty ? 'jpg' : extension;
    final String storagePath = '$safeBillId-$timestamp.$safeExt';

    debugPrint('AttachmentService: uploading to $_bucket/$storagePath');

    // 3. Upload to Supabase Storage
    try {
      await _supabase.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: (mimeType != null && mimeType.startsWith('image/'))
                  ? mimeType
                  : 'image/jpeg',
            ),
          );
    } catch (e) {
      debugPrint('AttachmentService: Supabase Storage upload error: $e');
      rethrow;
    }

    // 4. Get public URL
    final String fileUrl =
        _supabase.storage.from(_bucket).getPublicUrl(storagePath);

    debugPrint('AttachmentService: file uploaded, public URL: $fileUrl');

    // 5. Save record to attachments table
    final List<dynamic> result;
    try {
      result = await _supabase
          .from('attachments')
          .insert(<String, dynamic>{
            'user_id': userId,
            'related_type': 'bill',
            'related_id': safeBillId,
            'file_url': fileUrl,
            'file_name': rawName,
            'uploaded_by_person_id': uploadedByPersonId,
            'notes': null,
          })
          .select();
    } catch (e) {
      debugPrint('AttachmentService: DB insert error: $e');
      rethrow;
    }

    final AttachmentModel attachment =
        AttachmentModel.fromMap(result.first as Map<String, dynamic>);

    // 6. Log activity
    await ActivityLogRepository.instance.createLog(
      targetType: 'payment_proof',
      action: 'proof_uploaded',
      title: 'Payment proof uploaded',
      targetId: safeBillId,
      personId: uploadedByPersonId,
      description: 'Proof uploaded for bill.',
      metadata: <String, dynamic>{
        'file_name': rawName,
        'file_url': fileUrl,
        'bill_id': safeBillId,
      },
    );

    return attachment;
  }

  Future<List<AttachmentModel>> fetchForBill(String billId) async {
    final String safeBillId = billId.trim();
    final String userId = requireCurrentUserId();
    if (safeBillId.isEmpty) return <AttachmentModel>[];

    final List<dynamic> response = await _supabase
        .from('attachments')
        .select()
        .eq('user_id', userId)
        .eq('related_type', 'bill')
        .eq('related_id', safeBillId)
        .order('created_at', ascending: false);

    return response
        .map((dynamic e) =>
            AttachmentModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete(AttachmentModel attachment) async {
    final String userId = requireCurrentUserId();
    final Uri uri = Uri.parse(attachment.fileUrl);

    // Extract just the filename from the URL (flat path, no subfolders)
    final String storagePath = uri.pathSegments.last;

    debugPrint('AttachmentService: deleting $_bucket/$storagePath');

    try {
      await _supabase.storage
          .from(_bucket)
          .remove(<String>[storagePath]);
    } catch (e) {
      debugPrint('AttachmentService: Storage delete error: $e');
    }

    await _supabase
        .from('attachments')
        .delete()
        .eq('id', attachment.id)
        .eq('user_id', userId);

    await ActivityLogRepository.instance.createLog(
      targetType: 'payment_proof',
      action: 'deleted',
      title: 'Payment proof deleted',
      targetId: attachment.relatedId,
      personId: attachment.uploadedByPersonId,
      description: 'Proof was deleted.',
      metadata: <String, dynamic>{
        'attachment_id': attachment.id,
        'file_name': attachment.fileName ?? '',
        'file_url': attachment.fileUrl,
      },
    );
  }

  static const Set<String> _allowedImageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  String _extensionFrom(String fileName) {
    final int dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}