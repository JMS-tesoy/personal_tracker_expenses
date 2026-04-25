import 'package:supabase_flutter/supabase_flutter.dart';

String requireCurrentUserId() {
  final String? userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null || userId.isEmpty) {
    throw StateError('User must be signed in.');
  }
  return userId;
}
