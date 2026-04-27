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

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) {
      throw const PaymentProofUploadCancelled();
    }

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

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String safeExt = extension.isEmpty ? 'jpg' : extension;
    final String safeFileName = _sanitizeFileName(rawName, safeExt);

    final String storagePath =
        '$userId/bills/$safeBillId/${timestamp}_$safeFileName';

    debugPrint('AttachmentService: bucket=$_bucket');
    debugPrint('AttachmentService: storagePath=$storagePath');
    debugPrint('AttachmentService: mimeType=$mimeType');
    debugPrint('AttachmentService: size=$size');

    try {
      await _supabase.storage.from(_bucket).upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              upsert: false,
              contentType: _safeContentType(mimeType, safeExt),
            ),
          );
    } on StorageException catch (error, stackTrace) {
      debugPrint('AttachmentService: StorageException');
      debugPrint('message=${error.message}');
      debugPrint('statusCode=${error.statusCode}');
      debugPrint('error=${error.error}');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('AttachmentService: Storage upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    final String fileUrl =
        _supabase.storage.from(_bucket).getPublicUrl(storagePath);

    debugPrint('AttachmentService: publicUrl=$fileUrl');

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
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('AttachmentService: PostgrestException during DB insert');
      debugPrint('message=${error.message}');
      debugPrint('code=${error.code}');
      debugPrint('details=${error.details}');
      debugPrint('hint=${error.hint}');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('AttachmentService: DB insert failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    if (result.isEmpty) {
      throw Exception('Attachment insert returned no record.');
    }

    final AttachmentModel attachment =
        AttachmentModel.fromMap(result.first as Map<String, dynamic>);

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
        'storage_path': storagePath,
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
        .map(
          (dynamic e) => AttachmentModel.fromMap(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> delete(AttachmentModel attachment) async {
    final String userId = requireCurrentUserId();
    final String? storagePath = _storagePathFromPublicUrl(attachment.fileUrl);

    if (storagePath != null && storagePath.isNotEmpty) {
      debugPrint('AttachmentService: deleting $_bucket/$storagePath');

      try {
        await _supabase.storage.from(_bucket).remove(<String>[storagePath]);
      } catch (error, stackTrace) {
        debugPrint('AttachmentService: Storage delete failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
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

  String _sanitizeFileName(String fileName, String fallbackExtension) {
    String cleaned = fileName.trim().toLowerCase();

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9._-]'), '');

    if (cleaned.isEmpty || !cleaned.contains('.')) {
      cleaned = 'payment_proof.$fallbackExtension';
    }

    return cleaned;
  }

  String _safeContentType(String? mimeType, String extension) {
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }

    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String? _storagePathFromPublicUrl(String fileUrl) {
    final Uri uri = Uri.tryParse(fileUrl) ?? Uri();
    final List<String> segments = uri.pathSegments;

    final int bucketIndex = segments.indexOf(_bucket);
    if (bucketIndex == -1 || bucketIndex == segments.length - 1) {
      return null;
    }

    return segments.sublist(bucketIndex + 1).join('/');
  }
}