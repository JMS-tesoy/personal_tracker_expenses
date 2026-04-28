import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_log_model.dart';

class ActivityLogRepository {
  ActivityLogRepository._();

  static final ActivityLogRepository instance = ActivityLogRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Safe log — never throws. Logging failure must never break the main action.
  Future<void> createLog({
    required String targetType,
    required String action,
    required String title,
    String? targetId,
    String? personId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final String? uid = _userId;
      if (uid == null) return;

      final ActivityLogModel log = ActivityLogModel(
        id: '',
        userId: uid,
        actorId: uid,
        targetType: targetType,
        targetId: targetId,
        personId: personId,
        action: action,
        title: title,
        description: description,
        metadata: metadata ?? <String, dynamic>{},
        createdAt: DateTime.now(),
      );

      await _supabase.from('activity_logs').insert(log.toInsertMap());
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository.createLog error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<ActivityLogModel>> getRecentLogs({int limit = 100}) async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ActivityLogModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final List<ActivityLogModel> logs =
          rows.map(ActivityLogModel.fromMap).toList();

      return _enrichLogs(logs);
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository.getRecentLogs error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <ActivityLogModel>[];
    }
  }

  Future<List<ActivityLogModel>> getLogsByTarget(
    String targetType,
    String targetId,
  ) async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ActivityLogModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', uid)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .order('created_at', ascending: false);

      final List<ActivityLogModel> logs =
          rows.map(ActivityLogModel.fromMap).toList();

      return _enrichLogs(logs);
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository.getLogsByTarget error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <ActivityLogModel>[];
    }
  }

  Future<List<ActivityLogModel>> getLogsByPerson(String personId) async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ActivityLogModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', uid)
          .eq('person_id', personId)
          .order('created_at', ascending: false);

      final List<ActivityLogModel> logs =
          rows.map(ActivityLogModel.fromMap).toList();

      return _enrichLogs(logs);
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository.getLogsByPerson error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <ActivityLogModel>[];
    }
  }

  Future<List<ActivityLogModel>> getLogsByAction(String action) async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ActivityLogModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', uid)
          .eq('action', action)
          .order('created_at', ascending: false);

      final List<ActivityLogModel> logs =
          rows.map(ActivityLogModel.fromMap).toList();

      return _enrichLogs(logs);
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository.getLogsByAction error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <ActivityLogModel>[];
    }
  }

  Future<List<ActivityLogModel>> _enrichLogs(
    List<ActivityLogModel> logs,
  ) async {
    if (logs.isEmpty) return logs;

    final Map<String, String> personNames = await _loadPersonNames(logs);
    final Map<String, _DeviceAuditInfo> devices = await _loadDevices(logs);
    final Map<String, String> billNames = await _loadBillNames(logs);
    final Map<String, String> loanNames = await _loadLoanNames(logs);

    return logs.map((ActivityLogModel log) {
      final String? personName =
          log.personId == null ? null : personNames[log.personId];

      final _DeviceAuditInfo? device = log.uploadedByDeviceId == null
          ? null
          : devices[log.uploadedByDeviceId];

      final String? targetName = _resolveTargetName(
        log: log,
        billNames: billNames,
        loanNames: loanNames,
      );

      return log.copyWith(
        personName: personName,
        targetName: targetName,
        deviceName: device?.deviceName,
        devicePlatform: device?.platform,
      );
    }).toList();
  }

  Future<Map<String, String>> _loadPersonNames(
    List<ActivityLogModel> logs,
  ) async {
    final String? uid = _userId;
    if (uid == null) return <String, String>{};

    final List<String> personIds = logs
        .map((ActivityLogModel log) => log.personId)
        .whereType<String>()
        .where((String id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    if (personIds.isEmpty) return <String, String>{};

    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .select('id, name, nickname')
          .eq('user_id', uid)
          .inFilter('id', personIds);

      return <String, String>{
        for (final Map<String, dynamic> row in rows)
          row['id'].toString(): _personDisplayName(row),
      };
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository._loadPersonNames error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <String, String>{};
    }
  }

  Future<Map<String, _DeviceAuditInfo>> _loadDevices(
    List<ActivityLogModel> logs,
  ) async {
    final String? uid = _userId;
    if (uid == null) return <String, _DeviceAuditInfo>{};

    final List<String> deviceIds = logs
        .map((ActivityLogModel log) => log.uploadedByDeviceId)
        .whereType<String>()
        .where((String id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    if (deviceIds.isEmpty) return <String, _DeviceAuditInfo>{};

    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('user_devices')
          .select('id, device_name, platform')
          .eq('user_id', uid)
          .inFilter('id', deviceIds);

      return <String, _DeviceAuditInfo>{
        for (final Map<String, dynamic> row in rows)
          row['id'].toString(): _DeviceAuditInfo(
            deviceName: _stringValue(row['device_name']),
            platform: _stringValue(row['platform']),
          ),
      };
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository._loadDevices error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <String, _DeviceAuditInfo>{};
    }
  }

  Future<Map<String, String>> _loadBillNames(
    List<ActivityLogModel> logs,
  ) async {
    final String? uid = _userId;
    if (uid == null) return <String, String>{};

    final Set<String> billIds = <String>{};

    for (final ActivityLogModel log in logs) {
      if (log.targetType == 'bill' && log.targetId != null) {
        billIds.add(log.targetId!);
      }

      if (log.targetType == 'payment_proof') {
        if (log.billIdFromMetadata != null) {
          billIds.add(log.billIdFromMetadata!);
        } else if (log.targetId != null) {
          billIds.add(log.targetId!);
        }
      }
    }

    if (billIds.isEmpty) return <String, String>{};

    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('bills')
          .select('id, name')
          .eq('user_id', uid)
          .inFilter('id', billIds.toList());

      return <String, String>{
        for (final Map<String, dynamic> row in rows)
          row['id'].toString(): _stringValue(row['name'], fallback: 'Bill'),
      };
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository._loadBillNames error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <String, String>{};
    }
  }

  Future<Map<String, String>> _loadLoanNames(
    List<ActivityLogModel> logs,
  ) async {
    final String? uid = _userId;
    if (uid == null) return <String, String>{};

    final List<String> loanIds = logs
        .where((ActivityLogModel log) => log.targetType == 'loan')
        .map((ActivityLogModel log) => log.targetId)
        .whereType<String>()
        .where((String id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    if (loanIds.isEmpty) return <String, String>{};

    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('loans')
          .select('id, name, title')
          .eq('user_id', uid)
          .inFilter('id', loanIds);

      return <String, String>{
        for (final Map<String, dynamic> row in rows)
          row['id'].toString(): _stringValue(
            row['name'],
            fallback: _stringValue(row['title'], fallback: 'Loan'),
          ),
      };
    } catch (error, stackTrace) {
      debugPrint('ActivityLogRepository._loadLoanNames error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <String, String>{};
    }
  }

  String? _resolveTargetName({
    required ActivityLogModel log,
    required Map<String, String> billNames,
    required Map<String, String> loanNames,
  }) {
    if (log.targetType == 'bill' && log.targetId != null) {
      return billNames[log.targetId];
    }

    if (log.targetType == 'payment_proof') {
      final String? billId = log.billIdFromMetadata ?? log.targetId;
      if (billId != null) return billNames[billId];
    }

    if (log.targetType == 'loan' && log.targetId != null) {
      return loanNames[log.targetId];
    }

    return null;
  }

  String _personDisplayName(Map<String, dynamic> row) {
    final String name = _stringValue(row['name']);
    final String nickname = _stringValue(row['nickname']);

    if (nickname.isNotEmpty) return '$name ($nickname)';
    if (name.isNotEmpty) return name;

    return 'Unknown person';
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;

    return text;
  }
}

class _DeviceAuditInfo {
  const _DeviceAuditInfo({
    required this.deviceName,
    required this.platform,
  });

  final String deviceName;
  final String platform;
}