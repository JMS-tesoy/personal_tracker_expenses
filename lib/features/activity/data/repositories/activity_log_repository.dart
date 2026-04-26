import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_log_model.dart';

class ActivityLogRepository {
  ActivityLogRepository._();
  static final ActivityLogRepository instance = ActivityLogRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Safe log — never throws. Logging failure never breaks main action.
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
    } catch (e) {
      debugPrint('ActivityLogRepository.createLog error: $e');
    }
  }

  Future<List<ActivityLogModel>> getRecentLogs({int limit = 50}) async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ActivityLogModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      return rows.map(ActivityLogModel.fromMap).toList();
    } catch (e) {
      debugPrint('ActivityLogRepository.getRecentLogs error: $e');
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

      return rows.map(ActivityLogModel.fromMap).toList();
    } catch (e) {
      debugPrint('ActivityLogRepository.getLogsByTarget error: $e');
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

      return rows.map(ActivityLogModel.fromMap).toList();
    } catch (e) {
      debugPrint('ActivityLogRepository.getLogsByPerson error: $e');
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

      return rows.map(ActivityLogModel.fromMap).toList();
    } catch (e) {
      debugPrint('ActivityLogRepository.getLogsByAction error: $e');
      return <ActivityLogModel>[];
    }
  }
}
