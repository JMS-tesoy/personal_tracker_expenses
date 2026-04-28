import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/current_user.dart';
import '../../activity/data/repositories/activity_log_repository.dart';
import '../../people/data/people_repository.dart';
import '../../people/domain/person.dart';
import '../domain/bill_comment.dart';

class BillCommentsRepository {
  BillCommentsRepository._();

  static final BillCommentsRepository instance = BillCommentsRepository._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<BillCommentModel>> fetchForBill(String billId) async {
    final String safeBillId = billId.trim();
    final String userId = requireCurrentUserId();

    if (safeBillId.isEmpty) return <BillCommentModel>[];

    try {
      final List<dynamic> rows = await _supabase
          .from('bill_comments')
          .select()
          .eq('user_id', userId)
          .eq('bill_id', safeBillId)
          .order('created_at', ascending: true);

      final List<BillCommentModel> comments = rows
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> row) => BillCommentModel.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();

      return _attachPersonNames(comments);
    } catch (error, stackTrace) {
      debugPrint('BillCommentsRepository.fetchForBill error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return <BillCommentModel>[];
    }
  }

  Future<BillCommentModel?> addComment({
    required String billId,
    required String billName,
    required String message,
    String? personId,
  }) async {
    final String safeBillId = billId.trim();
    final String safeMessage = message.trim();
    final String userId = requireCurrentUserId();

    if (safeBillId.isEmpty || safeMessage.isEmpty) {
      return null;
    }

    try {
      final List<dynamic> rows = await _supabase
          .from('bill_comments')
          .insert(<String, dynamic>{
            'user_id': userId,
            'bill_id': safeBillId,
            'person_id': _emptyToNull(personId),
            'message': safeMessage,
          })
          .select();

      if (rows.isEmpty || rows.first is! Map) {
        return null;
      }

      final BillCommentModel comment = BillCommentModel.fromMap(
        Map<String, dynamic>.from(rows.first as Map),
      );

      await ActivityLogRepository.instance.createLog(
        targetType: 'bill',
        targetId: safeBillId,
        personId: _emptyToNull(personId),
        action: 'bill_comment_added',
        title: 'Bill comment added',
        description: billName.trim().isEmpty
            ? 'A comment was added to a bill.'
            : 'A comment was added to $billName.',
        metadata: <String, dynamic>{
          'bill_id': safeBillId,
          'bill_name': billName,
          'comment_id': comment.id,
          'comment_preview': _preview(safeMessage),
          if (_emptyToNull(personId) != null) 'person_id': personId,
        },
      );

      final List<BillCommentModel> enriched =
          await _attachPersonNames(<BillCommentModel>[comment]);

      return enriched.isEmpty ? comment : enriched.first;
    } catch (error, stackTrace) {
      debugPrint('BillCommentsRepository.addComment error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<List<BillCommentModel>> _attachPersonNames(
    List<BillCommentModel> comments,
  ) async {
    if (comments.isEmpty) return comments;

    final Set<String> personIds = comments
        .map((BillCommentModel c) => c.personId)
        .whereType<String>()
        .where((String id) => id.trim().isNotEmpty)
        .toSet();

    if (personIds.isEmpty) return comments;

    try {
      final List<PersonModel> people = await PeopleRepository.instance.fetchAll();

      final Map<String, String> namesById = <String, String>{
        for (final PersonModel person in people)
          person.id: _personDisplayName(person),
      };

      return comments
          .map(
            (BillCommentModel comment) => comment.copyWith(
              personName: comment.personId == null
                  ? null
                  : namesById[comment.personId],
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      debugPrint('BillCommentsRepository._attachPersonNames error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return comments;
    }
  }

  String _personDisplayName(PersonModel person) {
    final String nickname = person.nickname?.trim() ?? '';

    if (nickname.isNotEmpty) {
      return '${person.name} ($nickname)';
    }

    return person.name;
  }

  String _preview(String message) {
    final String clean = message.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (clean.length <= 80) return clean;

    return '${clean.substring(0, 80)}...';
  }

  String? _emptyToNull(String? value) {
    if (value == null) return null;

    final String text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    return text;
  }
}