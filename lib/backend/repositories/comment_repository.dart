import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../core/supabase_config.dart';
import '../models/comment.dart';
import 'auth_repository.dart';

/// [C2] 댓글 (작성, 목록, 실시간 반영)
class CommentRepository {
  static const _columns = 'id, post_id, author_id, content, created_at, profiles(nickname)';

  final SupabaseClient _db;
  final AuthRepository _auth;
  CommentRepository({SupabaseClient? client, AuthRepository? auth})
      : _db = client ?? SupabaseConfig.client,
        _auth = auth ?? AuthRepository(client);

  /// 게시글의 댓글 목록 (오래된 순)
  Future<List<Comment>> fetchComments(int postId) => guard(() async {
        final rows = await _db
            .from('comments')
            .select(_columns)
            .eq('post_id', postId)
            .order('created_at', ascending: true);
        return rows.map(Comment.fromJson).toList();
      });

  /// 댓글 작성 (1~300자). 댓글 수(comments_count)는 DB 트리거가 자동으로 올린다.
  Future<Comment> addComment(int postId, String content) => guard(() async {
        final uid = _auth.requireUserId();
        final text = content.trim();
        if (text.isEmpty || text.length > 300) {
          throw const AppException(AppErrorType.invalidInput, '댓글은 1~300자로 입력해주세요.');
        }
        final row = await _db
            .from('comments')
            .insert({'post_id': postId, 'author_id': uid, 'content': text})
            .select(_columns)
            .single();
        return Comment.fromJson(row);
      });

  /// 본인 댓글 삭제
  Future<void> deleteComment(int commentId) => guard(() async {
        final deleted = await _db.from('comments').delete().eq('id', commentId).select('id');
        if (deleted.isEmpty) {
          throw const AppException(AppErrorType.forbidden, '본인이 작성한 댓글만 삭제할 수 있어요.');
        }
      });

  /// 게시글의 댓글 목록을 실시간으로 받는다 (여러 기기 간 실시간 반영).
  /// 처음에 전체 목록을 한 번 보내고, 이후 댓글이 추가·삭제될 때마다 최신 목록을 다시 보낸다.
  /// 화면이 닫힐 때 StreamSubscription.cancel() 을 호출하면 구독도 해제된다.
  Stream<List<Comment>> watchComments(int postId) {
    late final RealtimeChannel channel;
    late final StreamController<List<Comment>> controller;
    var comments = <Comment>[];

    void emit() {
      if (!controller.isClosed) controller.add(List.unmodifiable(comments));
    }

    Future<void> onChange(PostgresChangePayload payload) async {
      try {
        if (payload.eventType == PostgresChangeEvent.insert) {
          final id = (payload.newRecord['id'] as num).toInt();
          if (comments.any((c) => c.id == id)) return;
          final row = await _db.from('comments').select(_columns).eq('id', id).single();
          comments = [...comments, Comment.fromJson(row)];
          emit();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final id = payload.oldRecord['id'];
          if (id == null) return;
          comments = comments.where((c) => c.id != (id as num).toInt()).toList();
          emit();
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<Comment>>(
      onListen: () async {
        channel = _db
            .channel('public:comments:$postId:${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'comments',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'post_id',
                value: postId,
              ),
              callback: onChange,
            )
            .subscribe();
        try {
          comments = await fetchComments(postId);
          emit();
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        }
      },
      onCancel: () async {
        await _db.removeChannel(channel);
        await controller.close();
      },
    );
    return controller.stream;
  }
}
