// lib/features/reminders/data/repositories/reminder_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reminder_model.dart';
import '../../services/local_notification_service.dart';

class ReminderRepository {
  ReminderRepository._();
  static final ReminderRepository instance = ReminderRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalNotificationService _notif = LocalNotificationService.instance;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<ReminderModel?> createReminder(ReminderModel reminder) async {
    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('reminders')
          .insert(reminder.toInsertMap())
          .select();

      if (rows.isEmpty) return null;
      final ReminderModel saved = ReminderModel.fromMap(rows.first);

      final int? notifId = await _notif.scheduleFromReminderModel(saved);

      if (notifId != null && notifId != saved.notificationId) {
        await _supabase
            .from('reminders')
            .update(<String, dynamic>{'notification_id': notifId})
            .eq('id', saved.id);
        return saved.copyWith(notificationId: notifId);
      }

      return saved;
    } catch (e) {
      debugPrint('ReminderRepository.createReminder error: $e');
      return null;
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  Future<ReminderModel?> updateReminder(ReminderModel reminder) async {
    try {
      if (reminder.notificationId != null) {
        await _notif.cancelReminder(reminder.notificationId!);
      }

      final List<Map<String, dynamic>> rows = await _supabase
          .from('reminders')
          .update(<String, dynamic>{
            'title': reminder.title,
            'message': reminder.message,
            'remind_at': reminder.remindAt.toUtc().toIso8601String(),
            'due_at': reminder.dueAt?.toUtc().toIso8601String(),
            'repeat_type': reminder.repeatType,
            'status': reminder.status,
          })
          .eq('id', reminder.id)
          .select();

      if (rows.isEmpty) return null;
      final ReminderModel updated = ReminderModel.fromMap(rows.first);

      final int? notifId = await _notif.scheduleFromReminderModel(updated);
      if (notifId != null) {
        await _supabase
            .from('reminders')
            .update(<String, dynamic>{'notification_id': notifId})
            .eq('id', updated.id);
        return updated.copyWith(notificationId: notifId);
      }

      return updated;
    } catch (e) {
      debugPrint('ReminderRepository.updateReminder error: $e');
      return null;
    }
  }

  // ── Status helpers ──────────────────────────────────────────────────────────

  Future<bool> markReminderCompleted(ReminderModel reminder) async =>
      _setStatus(reminder, 'completed');

  Future<bool> cancelReminder(ReminderModel reminder) async =>
      _setStatus(reminder, 'cancelled');

  Future<bool> _setStatus(ReminderModel reminder, String status) async {
    try {
      await _supabase
          .from('reminders')
          .update(<String, dynamic>{'status': status})
          .eq('id', reminder.id);

      if (reminder.notificationId != null) {
        await _notif.cancelReminder(reminder.notificationId!);
      }
      return true;
    } catch (e) {
      debugPrint('ReminderRepository._setStatus($status) error: $e');
      return false;
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<bool> deleteReminder(ReminderModel reminder) async {
    try {
      await _supabase.from('reminders').delete().eq('id', reminder.id);
      if (reminder.notificationId != null) {
        await _notif.cancelReminder(reminder.notificationId!);
      }
      return true;
    } catch (e) {
      debugPrint('ReminderRepository.deleteReminder error: $e');
      return false;
    }
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  Future<List<ReminderModel>> getActiveReminders() async =>
      _fetchByStatus('active');

  Future<List<ReminderModel>> getHistoryReminders() async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ReminderModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', uid)
          .inFilter('status', <String>['completed', 'cancelled'])
          .order('remind_at', ascending: false);

      return rows.map(ReminderModel.fromMap).toList();
    } catch (e) {
      debugPrint('ReminderRepository.getHistoryReminders error: $e');
      return <ReminderModel>[];
    }
  }

  Future<List<ReminderModel>> getUpcomingReminders() async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ReminderModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', uid)
          .eq('status', 'active')
          .gte('remind_at', DateTime.now().toUtc().toIso8601String())
          .order('remind_at');

      return rows.map(ReminderModel.fromMap).toList();
    } catch (e) {
      debugPrint('ReminderRepository.getUpcomingReminders error: $e');
      return <ReminderModel>[];
    }
  }

  Future<List<ReminderModel>> getRemindersByTarget(
    String targetType,
    String targetId,
  ) async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ReminderModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', uid)
          .eq('target_type', targetType)
          .eq('target_id', targetId)
          .order('remind_at');

      return rows.map(ReminderModel.fromMap).toList();
    } catch (e) {
      debugPrint('ReminderRepository.getRemindersByTarget error: $e');
      return <ReminderModel>[];
    }
  }

  Future<void> syncPendingLocalNotifications() async {
    try {
      final List<ReminderModel> upcoming = await getUpcomingReminders();
      for (final ReminderModel r in upcoming) {
        await _notif.scheduleFromReminderModel(r);
      }
    } catch (e) {
      debugPrint('ReminderRepository.syncPendingLocalNotifications error: $e');
    }
  }

  // ── Private helper ──────────────────────────────────────────────────────────

  Future<List<ReminderModel>> _fetchByStatus(String status) async {
    try {
      final String? uid = _userId;
      if (uid == null) return <ReminderModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('reminders')
          .select()
          .eq('user_id', uid)
          .eq('status', status)
          .order('remind_at', ascending: true);

      return rows.map(ReminderModel.fromMap).toList();
    } catch (e) {
      debugPrint('ReminderRepository._fetchByStatus($status) error: $e');
      return <ReminderModel>[];
    }
  }
}
