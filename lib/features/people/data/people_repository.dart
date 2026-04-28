// lib/features/people/data/people_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/person.dart';

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
    paidBillsCount: 0,
    remindersCount: 0,
    activityCount: 0,
    attachmentsCount: 0,
    assignedBills: <Map<String, dynamic>>[],
    paidBills: <Map<String, dynamic>>[],
    reminders: <Map<String, dynamic>>[],
    recentActivity: <Map<String, dynamic>>[],
    attachments: <Map<String, dynamic>>[],
  );
}

class PeopleRepository {
  PeopleRepository._();

  static final PeopleRepository instance = PeopleRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  static const String _billSelect =
      'id, user_id, name, amount, due_day, status, paid_on, created_at, '
      'assigned_person_id, paid_by_person_id';

  static const String _reminderSelect =
      'id, user_id, title, message, remind_at, status, person_id, created_at';

  static const String _activitySelect =
      'id, user_id, action, title, description, person_id, created_at';

  static const String _attachmentSelect =
      'id, user_id, related_type, related_id, file_name, file_url, '
      'uploaded_by_person_id, uploaded_by_device_id, created_at, '
      'user_devices:uploaded_by_device_id(device_name, platform, os_version, app_version)';

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
    } catch (error, stackTrace) {
      debugPrint('PeopleRepository.fetchAll error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <PersonModel>[];
    }
  }

  Future<PersonModel?> fetchById(String personId) async {
    try {
      final String? uid = _userId;
      if (uid == null) return null;

      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .select()
          .eq('user_id', uid)
          .eq('id', personId)
          .limit(1);

      if (rows.isEmpty) return null;
      return PersonModel.fromMap(rows.first);
    } catch (error, stackTrace) {
      debugPrint('PeopleRepository.fetchById error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<PersonModel?> create(PersonModel person) async {
    try {
      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .insert(person.toInsertMap())
          .select();

      if (rows.isEmpty) return null;
      return PersonModel.fromMap(rows.first);
    } catch (error, stackTrace) {
      debugPrint('PeopleRepository.create error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<PersonModel?> update(PersonModel person) async {
    try {
      final String? uid = _userId;
      if (uid == null) return null;

      final List<Map<String, dynamic>> rows = await _supabase
          .from('people')
          .update(<String, dynamic>{
            'name': person.name,
            'nickname': person.nickname,
            'phone': person.phone,
            'email': person.email,
            'notes': person.notes,
          })
          .eq('user_id', uid)
          .eq('id', person.id)
          .select();

      if (rows.isEmpty) return null;
      return PersonModel.fromMap(rows.first);
    } catch (error, stackTrace) {
      debugPrint('PeopleRepository.update error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> delete(String personId) async {
    try {
      final String? uid = _userId;
      if (uid == null) return false;

      await _supabase
          .from('people')
          .delete()
          .eq('user_id', uid)
          .eq('id', personId);

      return true;
    } catch (error, stackTrace) {
      debugPrint('PeopleRepository.delete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<PersonSummary> fetchSummary(String personId) async {
    final String? uid = _userId;
    if (uid == null || personId.trim().isEmpty) {
      return PersonSummary.empty;
    }

    final List<Map<String, dynamic>> assignedBills = await _safeRows(
      label: 'assignedBills',
      query: () => _supabase
          .from('bills')
          .select(_billSelect)
          .eq('user_id', uid)
          .eq('assigned_person_id', personId)
          .order('created_at', ascending: false),
    );

    final List<Map<String, dynamic>> paidBillsBySinglePayer = await _safeRows(
      label: 'paidBillsBySinglePayer',
      query: () => _supabase
          .from('bills')
          .select(_billSelect)
          .eq('user_id', uid)
          .eq('status', 'paid')
          .eq('paid_by_person_id', personId)
          .order('paid_on', ascending: false),
    );

    final List<Map<String, dynamic>> paidBillsByMultiplePayers =
        await _safeRows(
          label: 'paidBillsByMultiplePayers',
          query: () => _supabase
              .from('bills')
              .select(_billSelect)
              .eq('user_id', uid)
              .eq('status', 'paid')
              .contains('paid_by_person_ids', <String>[personId])
              .order('paid_on', ascending: false),
        );

    final List<Map<String, dynamic>> legacyPaidAssignedBills = assignedBills
        .where((Map<String, dynamic> bill) {
          final String status = _stringValue(bill['status']).toLowerCase();
          final String paidBy = _stringValue(bill['paid_by_person_id']);
          return status == 'paid' && paidBy.isEmpty;
        })
        .map(Map<String, dynamic>.from)
        .toList();

    final List<Map<String, dynamic>> paidBills =
        _mergeRowsById(<List<Map<String, dynamic>>>[
          paidBillsBySinglePayer,
          paidBillsByMultiplePayers,
          legacyPaidAssignedBills,
        ])..sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              _compareDateDesc(a, b, <String>['paid_on', 'created_at']),
        );

    final List<Map<String, dynamic>> reminders = await _safeRows(
      label: 'reminders',
      query: () => _supabase
          .from('reminders')
          .select(_reminderSelect)
          .eq('user_id', uid)
          .eq('person_id', personId)
          .order('remind_at', ascending: false),
    );

    final List<Map<String, dynamic>> recentActivity = await _safeRows(
      label: 'recentActivity',
      query: () => _supabase
          .from('activity_logs')
          .select(_activitySelect)
          .eq('user_id', uid)
          .eq('person_id', personId)
          .order('created_at', ascending: false),
    );

    final List<Map<String, dynamic>> directAttachments = await _safeRows(
      label: 'directAttachments',
      query: () => _supabase
          .from('attachments')
          .select(_attachmentSelect)
          .eq('user_id', uid)
          .eq('uploaded_by_person_id', personId)
          .order('created_at', ascending: false),
    );

    final Set<String> linkedBillIds = <String>{
      ...assignedBills.map(
        (Map<String, dynamic> bill) => bill['id'].toString(),
      ),
      ...paidBills.map((Map<String, dynamic> bill) => bill['id'].toString()),
    };

    final List<Map<String, dynamic>> allBillAttachments = await _safeRows(
      label: 'allBillAttachments',
      query: () => _supabase
          .from('attachments')
          .select(_attachmentSelect)
          .eq('user_id', uid)
          .eq('related_type', 'bill')
          .order('created_at', ascending: false),
    );

    final List<Map<String, dynamic>> fallbackAttachments = allBillAttachments
        .where((Map<String, dynamic> attachment) {
          final String uploadedBy = _stringValue(
            attachment['uploaded_by_person_id'],
          );
          final String relatedId = _stringValue(attachment['related_id']);

          return uploadedBy.isEmpty && linkedBillIds.contains(relatedId);
        })
        .map(Map<String, dynamic>.from)
        .toList();

    final List<Map<String, dynamic>> attachments =
        _mergeRowsById(<List<Map<String, dynamic>>>[
          directAttachments,
          fallbackAttachments,
        ])..sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              _compareDateDesc(a, b, <String>['created_at']),
        );

    return PersonSummary(
      assignedBillsCount: assignedBills.length,
      paidBillsCount: paidBills.length,
      remindersCount: reminders.length,
      activityCount: recentActivity.length,
      attachmentsCount: attachments.length,
      assignedBills: assignedBills,
      paidBills: paidBills,
      reminders: reminders,
      recentActivity: recentActivity,
      attachments: attachments,
    );
  }

  Future<List<Map<String, dynamic>>> _safeRows({
    required String label,
    required Future<dynamic> Function() query,
  }) async {
    try {
      final dynamic result = await query();

      if (result is List) {
        return result
            .whereType<Map>()
            .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
            .toList();
      }

      return <Map<String, dynamic>>[];
    } catch (error, stackTrace) {
      debugPrint('PeopleRepository.$label query error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _mergeRowsById(
    List<List<Map<String, dynamic>>> groups,
  ) {
    final Map<String, Map<String, dynamic>> rowsById =
        <String, Map<String, dynamic>>{};

    for (final List<Map<String, dynamic>> group in groups) {
      for (final Map<String, dynamic> row in group) {
        final String id = _stringValue(row['id']);
        if (id.isNotEmpty) {
          rowsById[id] = row;
        }
      }
    }

    return rowsById.values.toList();
  }

  int _compareDateDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    List<String> keys,
  ) {
    final DateTime? aDate = _firstDate(a, keys);
    final DateTime? bDate = _firstDate(b, keys);

    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    return bDate.compareTo(aDate);
  }

  DateTime? _firstDate(Map<String, dynamic> row, List<String> keys) {
    for (final String key in keys) {
      final DateTime? date = _tryParseDate(row[key]);
      if (date != null) return date;
    }

    return null;
  }

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    if (text.toLowerCase() == 'null') return '';
    return text;
  }
}
