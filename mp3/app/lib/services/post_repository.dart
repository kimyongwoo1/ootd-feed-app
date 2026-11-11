import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../models/report_reason.dart';
import 'app_exception.dart';

/// 화면은 이 인터페이스만 사용한다. (테스트에서는 가짜 구현으로 바꿔 끼움)
abstract class PostRepository {
  /// 지금 기기의 익명 사용자 ID (로그인 전이면 null)
  String? get myUserId;

  /// 익명 로그인. 이미 로그인돼 있으면 그대로 사용
  Future<void> signIn();

  /// 최신 글부터 목록 불러오기
  Future<List<Post>> fetchPosts();

  /// 글 한 개 다시 불러오기 (좋아요·댓글 수 최신화)
  Future<Post> getPost(String postId);

  /// 글 저장 후, 서버에 저장된 글을 돌려줌
  Future<Post> createPost({required String nickname, required String content});

  /// MP3: 좋아요 켜기/끄기 → 서버 기준 최신 글을 돌려줌
  Future<Post> setLiked(String postId, {required bool liked});

  /// MP3: 댓글 목록 (오래된 순)
  Future<List<Comment>> fetchComments(String postId);

  /// MP3: 댓글 작성
  Future<Comment> addComment(String postId,
      {required String nickname, required String content});

  /// MP3: 신고 (사유 + 선택 설명)
  Future<void> reportPost(String postId,
      {required ReportReason reason, String? detail});
}

/// Supabase 구현
class SupabasePostRepository implements PostRepository {
  SupabasePostRepository(this._client);

  final SupabaseClient _client;

  static const _posts = 'mini_posts';
  static const _likes = 'mini_post_likes';
  static const _comments = 'mini_comments';
  static const _reports = 'mini_reports';

  // mini_post_likes(user_id): RLS 때문에 내 좋아요만 붙어 온다 → likedByMe 계산
  static const _postColumns =
      'id, author_id, nickname, content, created_at, likes_count, comments_count, '
      'mini_post_likes(user_id)';
  static const _commentColumns = 'id, post_id, author_id, nickname, content, created_at';
  static const _timeout = Duration(seconds: 10);

  @override
  String? get myUserId => _client.auth.currentUser?.id;

  @override
  Future<void> signIn() => _guard(() async {
        // 세션은 기기에 저장되므로, 앱을 다시 켜도 같은 익명 사용자로 유지된다
        if (_client.auth.currentSession == null) {
          await _client.auth.signInAnonymously();
        }
      });

  @override
  Future<List<Post>> fetchPosts() => _guard(() async {
        final rows = await _client
            .from(_posts)
            .select(_postColumns)
            .order('created_at', ascending: false)
            .limit(50);
        return rows.map((r) => Post.fromJson(r, myUserId: myUserId)).toList();
      });

  @override
  Future<Post> getPost(String postId) => _guard(() async {
        final row = await _client
            .from(_posts)
            .select(_postColumns)
            .eq('id', postId)
            .maybeSingle();
        if (row == null) {
          throw const AppException('삭제되었거나 숨겨진 게시글이에요.');
        }
        return Post.fromJson(row, myUserId: myUserId);
      });

  @override
  Future<Post> createPost({required String nickname, required String content}) =>
      _guard(() async {
        // author_id 는 서버가 auth.uid() 로 자동으로 채운다 (직접 보내지 않음)
        final row = await _client
            .from(_posts)
            .insert({'nickname': nickname, 'content': content})
            .select(_postColumns)
            .single();
        return Post.fromJson(row, myUserId: myUserId);
      });

  @override
  Future<Post> setLiked(String postId, {required bool liked}) async {
    await _guard(() async {
      if (liked) {
        try {
          // user_id 는 서버가 auth.uid() 로 채움. (post_id, user_id) 기본키 → 중복 불가
          await _client.from(_likes).insert({'post_id': postId});
        } on PostgrestException catch (e) {
          if (e.code != '23505') rethrow; // 이미 눌러져 있음 → 그대로 성공 처리
        }
      } else {
        // RLS 로 내 좋아요만 지울 수 있다
        await _client.from(_likes).delete().eq('post_id', postId);
      }
    });
    return getPost(postId); // 다른 기기에서 누른 것까지 반영된 최신 숫자
  }

  @override
  Future<List<Comment>> fetchComments(String postId) => _guard(() async {
        final rows = await _client
            .from(_comments)
            .select(_commentColumns)
            .eq('post_id', postId)
            .order('created_at', ascending: true)
            .limit(200);
        return rows.map((r) => Comment.fromJson(r, myUserId: myUserId)).toList();
      });

  @override
  Future<Comment> addComment(String postId,
          {required String nickname, required String content}) =>
      _guard(() async {
        final row = await _client
            .from(_comments)
            .insert({'post_id': postId, 'nickname': nickname, 'content': content})
            .select(_commentColumns)
            .single();
        return Comment.fromJson(row, myUserId: myUserId);
      });

  @override
  Future<void> reportPost(String postId,
          {required ReportReason reason, String? detail}) =>
      _guard(() async {
        final text = detail?.trim();
        await _client.from(_reports).insert({
          'post_id': postId,
          'reason': reason.code,
          if (text != null && text.isNotEmpty) 'detail': text,
        });
      });

  /// 모든 서버 호출을 감싸서, 실패하면 화면에 보여 줄 메시지로 바꾼다
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const AppException('서버 응답이 없어요. 인터넷 연결을 확인하고 다시 시도해 주세요.');
    } on AuthRetryableFetchException {
      throw const AppException('네트워크에 연결할 수 없어요. 인터넷 연결을 확인해 주세요.');
    } on AuthException catch (e) {
      throw AppException('익명 로그인에 실패했어요. (${e.message})');
    } on PostgrestException catch (e) {
      throw AppException(_dbMessage(e));
    } catch (_) {
      // 오프라인 등으로 요청 자체가 실패한 경우
      throw const AppException('네트워크에 연결할 수 없어요. 인터넷 연결을 확인해 주세요.');
    }
  }

  String _dbMessage(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return '이미 신고한 게시글이에요.'; // 좋아요 중복은 위에서 따로 처리
      case '23503':
        return '삭제되었거나 숨겨진 게시글이에요.';
      case '42501':
        return '권한이 없어요. 익명 로그인 상태를 확인해 주세요.';
      case '23514':
        return '입력 길이를 확인해 주세요. (닉네임 1~10자, 내용 1~200자)';
      case '42P01':
      case 'PGRST205':
      case 'PGRST200':
        return '서버 테이블이 준비되지 않았어요. README의 SQL을 먼저 실행해 주세요.';
      default:
        return '서버 오류가 발생했어요. (${e.message})';
    }
  }
}
