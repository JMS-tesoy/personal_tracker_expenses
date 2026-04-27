// lib/features/people/data/people_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/person.dart';

/// Lightweight summary counts for a single person.
class PersonSummary {
  const PersonSummary({
    required this.assignedBillsCount,
    required this.paidBillsCount,
    required this.remindersCount,
    required this.activityCount,
    required this.attachmentsCount,
    required this.assignedBills,
    required this.paidBills,
    required this.reminders,
    required this.recentActivity,
    required this.attachments,
  });

  final int assignedBillsCount;
  final int paidBillsCount;
  final int remindersCount;
  final int activityCount;
  final int attachmentsCount;

  final List<Map<String, dynamic>> assignedBills;
  final List<Map<String, dynamic>> paidBills;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> recentActivity;
  final List<Map<String, dynamic>> attachments;

  static const PersonSummary empty = PersonSummary(
    assignedBillsCount: 0,
    paidBillsCount:     0,
    remindersCount:     0,
    activityCount:      0,
    attachmentsCount:   0,
    assignedBills:      <Map<String, dynamic>>[],
    paidBills:          <Map<String, dynamic>>[],
    reminders:          <Map<String, dynamic>>[],
    recentActivity:     <Map<String, dynamic>>[],
    attachments:        <Map<String, dynamic>>[],
  );
}

class PeopleRepository {
  PeopleRepository._();
  static final PeopleRepository instance = PeopleRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? get _userId => _supabase.auth.currentUser?.id;

  // ── Fetch all people ────────────────────────────────────────────────────────

  Future<List<PersonModel>> fetchAll() async {
    try {
      final String? uid = _userId;
      if (uid == null) return <PersonModel>[];

      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .select()
          .eq('user_id', uid)
          .order('name');

      return rows.map(PersonModel.fromMap).toList();
    } catch (e) {
      debugPrint('PeopleRepository.fetchAll error: $e');
      return <PersonModel>[];
    }
  }

  // ── Fetch one person ────────────────────────────────────────────────────────

  Future<PersonModel?> fetchById(String personId) async {
    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .select()
          .eq('id', personId)
          .limit(1);

      if (rows.isEmpty) return null;
      return PersonModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('PeopleRepository.fetchById error: $e');
      return null;
    }
  }

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<PersonModel?> create(PersonModel person) async {
    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .insert(person.toInsertMap())
          .select();

      if (rows.isEmpty) return null;
      return PersonModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('PeopleRepository.create error: $e');
      return null;
    }
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  Future<PersonModel?> update(PersonModel person) async {
    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .update(<String, dynamic>{
            'name':     person.name,
            'nickname': person.nickname,
            'phone':    person.phone,
            'email':    person.email,
            'notes':    person.notes,
          })
          .eq('id', person.id)
          .select();

      if (rows.isEmpty) return null;
      return PersonModel.fromMap(rows.first);
    } catch (e) {
      debugPrint('PeopleRepository.update error: $e');
      return null;
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<bool> delete(String personId) async {
    try {
      await _supabase.from('people').delete().eq('id', personId);
      return true;
    } catch (e) {
      debugPrint('PeopleRepository.delete error: $e');
      return false;
    }
  }

  // ── Person summary (all linked records) ────────────────────────────────────

  Future<PersonSummary> fetchSummary(String personId) async {
    final List<Map<String, dynamic>> assignedBills = await _safe(
      () => _supabase
          .from('bills')
          .select('id, name, amount, due_date, status')
          .eq('assigned_person_id', personId)
          .order('due_date', ascending: false)
          .limit(20),
    );

    final List<Map<String, dynamic>> legacyPaidBills = await _safe(
      () => _supabase
          .from('bills')
          .select('id, name, amount, due_date, status')
          .eq('paid_by_person_id', personId)
          .order('due_date', ascending: false)
          .limit(20),
    );
    final List<Map<String, dynamic>> multiplePayerPaidBills = await _safe(
      () => _supabase
          .from('bills')
          .select('id, name, amount, due_date, status')
          .contains('paid_by_person_ids', <String>[personId])
          .order('due_date', ascending: false)
          .limit(20),
    );
    final List<Map<String, dynamic>> paidBills = _mergeRowsById(
      legacyPaidBills,
      multiplePayerPaidBills,
    );

    final List<Map<String, dynamic>> reminders = await _safe(
      () => _supabase
          .from('reminders')
          .select('id, title, message, remind_at, status')
          .eq('person_id', personId)
          .order('remind_at', ascending: false)
          .limit(20),
    );

    final List<Map<String, dynamic>> recentActivity = await _safe(
      () => _supabase
          .from('activity_logs')
          .select('id, action, description, created_at')
          .eq('person_id', personId)
          .order('created_at', ascending: false)
          .limit(20),
    );

    final List<Map<String, dynamic>> attachments = await _safe(
      () => _supabase
          .from('attachments')
          .select('id, file_name, file_url, created_at')
          .eq('uploaded_by_person_id', personId)
          .order('created_at', ascending: false)
          .limit(20),
    );

    return PersonSummary(
      assignedBillsCount: assignedBills.length,
      paidBillsCount:     paidBills.length,
      remindersCount:     reminders.length,
      activityCount:      recentActivity.length,
      attachmentsCount:   attachments.length,
      assignedBills:      assignedBills,
      paidBills:          paidBills,
      reminders:          reminders,
      recentActivity:     recentActivity,
      attachments:        attachments,
    );
  }

  // ── Safe query helper ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _safe(
    Future<dynamic> Function() query,
  ) async {
    try {
      final dynamic result = await query();
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return <Map<String, dynamic>>[];
    } catch (e) {
      // Gracefully return empty — missing columns/tables won't crash the screen
      debugPrint('PeopleRepository._safe query error: $e');
      return <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _mergeRowsById(
    List<Map<String, dynamic>> first,
    List<Map<String, dynamic>> second,
  ) {
    final Map<String, Map<String, dynamic>> rowsById =
        <String, Map<String, dynamic>>{};

    for (final Map<String, dynamic> row in <Map<String, dynamic>>[
      ...first,
      ...second,
    ]) {
      rowsById[row['id'].toString()] = row;
    }

    return rowsById.values.toList();
  }
}
