import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../auth/current_user.dart';

class DeviceAuditService {
  DeviceAuditService._();

  static final DeviceAuditService instance = DeviceAuditService._();

  static const String _deviceInstanceKey = 'pte_device_instance_id';

  final SupabaseClient _supabase = Supabase.instance.client;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String?> registerCurrentDevice() async {
    try {
      final String userId = requireCurrentUserId();
      final String deviceInstanceId = await _getOrCreateDeviceInstanceId();
      final _DeviceSnapshot snapshot = await _readDeviceSnapshot();

      final Map<String, dynamic> row = await _supabase
          .from('user_devices')
          .upsert(
            <String, dynamic>{
              'user_id': userId,
              'device_instance_id': deviceInstanceId,
              'device_name': snapshot.deviceName,
              'platform': snapshot.platform,
              'os_version': snapshot.osVersion,
              'app_version': snapshot.appVersion,
              'app_build_number': snapshot.appBuildNumber,
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'user_id,device_instance_id',
          )
          .select('id')
          .single();

      final String? deviceId = row['id']?.toString();

      debugPrint('DeviceAuditService: deviceId=$deviceId');
      debugPrint('DeviceAuditService: deviceName=${snapshot.deviceName}');
      debugPrint('DeviceAuditService: platform=${snapshot.platform}');

      return deviceId;
    } catch (error, stackTrace) {
      debugPrint('DeviceAuditService: failed to register device: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<String> _getOrCreateDeviceInstanceId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? existing = prefs.getString(_deviceInstanceKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final String generated = const Uuid().v4();
    await prefs.setString(_deviceInstanceKey, generated);

    return generated;
  }

  Future<_DeviceSnapshot> _readDeviceSnapshot() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String platform = Platform.operatingSystem;
    String deviceName = Platform.localHostname;
    String osVersion = Platform.operatingSystemVersion;

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;

      platform = 'android';
      deviceName = '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
      osVersion =
          'Android ${androidInfo.version.release} / SDK ${androidInfo.version.sdkInt}';
    }

    return _DeviceSnapshot(
      deviceName: deviceName.isEmpty ? 'Unknown device' : deviceName,
      platform: platform,
      osVersion: osVersion,
      appVersion: packageInfo.version,
      appBuildNumber: packageInfo.buildNumber,
    );
  }
}

class _DeviceSnapshot {
  const _DeviceSnapshot({
    required this.deviceName,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.appBuildNumber,
  });

  final String deviceName;
  final String platform;
  final String osVersion;
  final String appVersion;
  final String appBuildNumber;
}