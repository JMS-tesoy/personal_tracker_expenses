class AttachmentModel {
  const AttachmentModel({
    required this.id,
    required this.relatedType,
    required this.relatedId,
    required this.fileUrl,
    this.fileName,
    this.uploadedByPersonId,
    this.uploadedByDeviceId,
    this.deviceName,
    this.devicePlatform,
    this.deviceOsVersion,
    this.deviceAppVersion,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String relatedType;
  final String relatedId;
  final String fileUrl;
  final String? fileName;
  final String? uploadedByPersonId;
  final String? uploadedByDeviceId;
  final String? deviceName;
  final String? devicePlatform;
  final String? deviceOsVersion;
  final String? deviceAppVersion;
  final String? notes;
  final DateTime? createdAt;

  factory AttachmentModel.fromMap(Map<String, dynamic> map) {
    final Object? deviceRaw = map['user_devices'];
    final Map<String, dynamic>? device = deviceRaw is Map<String, dynamic>
        ? deviceRaw
        : null;

    return AttachmentModel(
      id: map['id'].toString(),
      relatedType: map['related_type'].toString(),
      relatedId: map['related_id'].toString(),
      fileUrl: map['file_url'].toString(),
      fileName: map['file_name']?.toString(),
      uploadedByPersonId: map['uploaded_by_person_id']?.toString(),
      uploadedByDeviceId: map['uploaded_by_device_id']?.toString(),
      deviceName: device?['device_name']?.toString(),
      devicePlatform: device?['platform']?.toString(),
      deviceOsVersion: device?['os_version']?.toString(),
      deviceAppVersion: device?['app_version']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())?.toLocal()
          : null,
    );
  }
}