import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../core/supabase_config.dart';
import '../models/liker.dart';
import 'auth_repository.dart';

/// [C1] 좋아요, [C3] 좋아요한 사람 확인
///
/// 낙관적 업데이트(비기능 요구사항) 사용 예 – 화면을 먼저 바꾸고 실패하면 되돌린다:
///   final before = post;
///   setState(() => post = post.copyWith(likedByMe: !post.likedByMe,
///       likesCount: post.likesCount + (post.likedByMe ? -1 : 1)));
///   try { await likes.setLiked(post.id, !before.likedByMe); }
///   on AppException catch (e) { setState(() => post = before); showSnackBar(e.message); }
class LikeRepository {
  final SupabaseClient _db;
  final AuthRepository _auth;
  LikeRepository({SupabaseClient? client, AuthRepository? auth})
      : _db = client ?? SupabaseConfig.client,
        _auth = auth ?? AuthRepository(client);

  /// 좋아요 상태를 [liked] 로 맞춘다. 이미 그 상태면 아무 일도 하지 않는다(중복 좋아요 안전).
  /// 좋아요 수(likes_count)는 DB 트리거가 자동으로 바꾼다.
  Future<void> setLiked(int postId, bool liked) => guard(() async {
        final uid = _auth.requireUserId();
        if (liked) {
          try {
            await _db.from('post_likes').insert({'post_id': postId, 'user_id': uid});
          } on PostgrestException catch (e) {
            if (e.code != '23505') rethrow; // 이미 좋아요 → 성공으로 처리
          }
        } else {
          await _db.from('post_likes').delete().match({'post_id': postId, 'user_id': uid});
        }
      });

  /// [C3] 이 게시글에 좋아요를 누른 사람 목록 (최근 순)
  Future<List<Liker>> fetchLikers(int postId, {int limit = 100}) => guard(() async {
        final rows = await _db
            .from('post_likes')
            .select('user_id, created_at, profiles(nickname)')
            .eq('post_id', postId)
            .order('created_at', ascending: false)
            .limit(limit);
        return rows.map(Liker.fromJson).toList();
      });
}
