class AttachmentModel {
  const AttachmentModel({
    required this.id,
    required this.relatedType,
    required this.relatedId,
    required this.fileUrl,
    this.fileName,
    this.uploadedByPersonId,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String relatedType;
  final String relatedId;
  final String fileUrl;
  final String? fileName;
  final String? uploadedByPersonId;
  final String? notes;
  final DateTime? createdAt;

  factory AttachmentModel.fromMap(Map<String, dynamic> map) {
    return AttachmentModel(
      id: map['id'].toString(),
      relatedType: map['related_type'].toString(),
      relatedId: map['related_id'].toString(),
      fileUrl: map['file_url'].toString(),
      fileName: map['file_name']?.toString(),
      uploadedByPersonId: map['uploaded_by_person_id']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}