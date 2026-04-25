import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Pick image from gallery, upload to Storage, save to attachments table.
  /// Returns the saved [AttachmentModel] or throws on error.
  Future<AttachmentModel> pickAndUpload({
    required String billId,
    String? uploadedByPersonId,
  }) async {
    final String safeBillId = billId.trim();
    if (safeBillId.isEmpty) {
      throw Exception('Missing bill id.');
    }

    // 1. Pick image
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) throw const PaymentProofUploadCancelled();

    final String fileName = picked.name.trim().isEmpty
        ? picked.path.split(Platform.pathSeparator).last
        : picked.name.trim();
    final String extension = _extensionFrom(fileName);
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

    // 2. Build storage path
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String storagePath = 'bills/$safeBillId/$timestamp.jpg';

    // 3. Upload to Supabase Storage
    await _supabase.storage
        .from(_bucket)
        .upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            upsert: false,
            contentType: mimeType != null && mimeType.startsWith('image/')
                ? mimeType
                : 'image/jpeg',
          ),
        );

    // 4. Get public URL
    final String fileUrl = _supabase.storage
        .from(_bucket)
        .getPublicUrl(storagePath);

    // 5. Save record to attachments table
    final List<dynamic> result =
        await _supabase.from('attachments').insert(<String, dynamic>{
          'related_type': 'bill',
          'related_id': safeBillId,
          'file_url': fileUrl,
          'file_name': fileName,
          'uploaded_by_person_id': uploadedByPersonId,
          'notes': null,
        }).select();

    return AttachmentModel.fromMap(result.first as Map<String, dynamic>);
  }

  /// Fetch all attachments for a bill.
  Future<List<AttachmentModel>> fetchForBill(String billId) async {
    final String safeBillId = billId.trim();
    if (safeBillId.isEmpty) return <AttachmentModel>[];

    final List<dynamic> response = await _supabase
        .from('attachments')
        .select()
        .eq('related_type', 'bill')
        .eq('related_id', safeBillId)
        .order('created_at', ascending: false);

    return response
        .map((dynamic e) => AttachmentModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Delete an attachment record and its storage file.
  Future<void> delete(AttachmentModel attachment) async {
    // Extract storage path from URL
    final Uri uri = Uri.parse(attachment.fileUrl);
    final String storagePath = uri.pathSegments
        .skipWhile((String s) => s != _bucket)
        .skip(1)
        .join('/');

    await _supabase.storage.from(_bucket).remove(<String>[storagePath]);
    await _supabase.from('attachments').delete().eq('id', attachment.id);
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
