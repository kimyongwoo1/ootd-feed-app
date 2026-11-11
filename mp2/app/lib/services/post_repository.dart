import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post.dart';
import 'app_exception.dart';

/// 화면은 이 인터페이스만 사용한다. (테스트에서는 가짜 구현으로 바꿔 끼움)
abstract class PostRepository {
  /// 지금 기기의 익명 사용자 ID (로그인 전이면 null)
  String? get myUserId;

  /// 익명 로그인. 이미 로그인돼 있으면 그대로 사용
  Future<void> signIn();

  /// 최신 글부터 목록 불러오기
  Future<List<Post>> fetchPosts();

  /// 글 저장 후, 서버에 저장된 글을 돌려줌
  Future<Post> createPost({required String nickname, required String content});
}

/// Supabase 구현
class SupabasePostRepository implements PostRepository {
  SupabasePostRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'mini_posts';
  static const _columns = 'id, author_id, nickname, content, created_at';
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
            .from(_table)
            .select(_columns)
            .order('created_at', ascending: false)
            .limit(50);
        return rows.map((r) => Post.fromJson(r, myUserId: myUserId)).toList();
      });

  @override
  Future<Post> createPost({required String nickname, required String content}) =>
      _guard(() async {
        // author_id 는 서버가 auth.uid() 로 자동으로 채운다 (직접 보내지 않음)
        final row = await _client
            .from(_table)
            .insert({'nickname': nickname, 'content': content})
            .select(_columns)
            .single();
        return Post.fromJson(row, myUserId: myUserId);
      });

  /// 모든 서버 호출을 감싸서, 실패하면 화면에 보여 줄 메시지로 바꾼다
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
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
      case '42501':
        return '권한이 없어요. 익명 로그인 상태를 확인해 주세요.';
      case '23514':
        return '닉네임은 1~10자, 내용은 1~200자로 입력해 주세요.';
      case '42P01':
      case 'PGRST205':
        return '서버에 mini_posts 테이블이 없어요. README의 SQL을 먼저 실행해 주세요.';
      default:
        return '서버 오류가 발생했어요. (${e.message})';
    }
  }
}
