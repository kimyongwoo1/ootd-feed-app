import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../core/supabase_config.dart';
import '../models/report_reason.dart';
import 'auth_repository.dart';

/// [C4] 게시글 신고 (신고 사유·기록은 서버에 저장, 같은 글은 한 번만 신고 가능)
class ReportRepository {
  final SupabaseClient _db;
  final AuthRepository _auth;
  ReportRepository({SupabaseClient? client, AuthRepository? auth})
      : _db = client ?? SupabaseConfig.client,
        _auth = auth ?? AuthRepository(client);

  Future<void> reportPost(int postId, ReportReason reason, {String? detail}) => guard(() async {
        final uid = _auth.requireUserId();
        final text = detail?.trim();
        await _db.from('reports').insert({
          'post_id': postId,
          'reporter_id': uid,
          'reason': reason.code,
          'detail': (text == null || text.isEmpty) ? null : text,
        });
      }, duplicateMessage: '이미 신고한 게시글이에요.');

  /// 내가 이미 신고한 글인지 (신고 버튼 비활성화 등에 사용)
  Future<bool> hasReported(int postId) => guard(() async {
        final uid = _auth.requireUserId();
        final row = await _db
            .from('reports')
            .select('id')
            .eq('post_id', postId)
            .eq('reporter_id', uid)
            .maybeSingle();
        return row != null;
      });
}
