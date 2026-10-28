import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../core/supabase_config.dart';
import '../models/clothing_tag.dart';
import '../models/feed_event.dart';
import '../models/feed_post.dart';
import 'auth_repository.dart';

/// [B1~B5, D1, E2, F1] 게시글
class PostRepository {
  static const pageSize = 20;

  final SupabaseClient _db;
  final AuthRepository _auth;
  PostRepository({SupabaseClient? client, AuthRepository? auth})
      : _db = client ?? SupabaseConfig.client,
        _auth = auth ?? AuthRepository(client);

  String imageUrlOf(String path) => _db.storage.from(SupabaseConfig.imageBucket).getPublicUrl(path);
  FeedPost _toPost(Map<String, dynamic> row) => FeedPost.fromJson(row, imageUrlOf);

  // ------------------------------------------------------------------
  // 조회
  // ------------------------------------------------------------------

  /// [B1] 최신순 피드. 다음 페이지는 마지막 글의 createdAt 을 [before] 로 넘긴다.
  ///   첫 페이지 / 당겨서 새로고침: fetchFeed()
  ///   무한 스크롤:                fetchFeed(before: posts.last.createdAt)
  Future<List<FeedPost>> fetchFeed({DateTime? before, int limit = pageSize}) => guard(() async {
        var query = _db.from('post_feed').select();
        if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
        final rows = await query.order('created_at', ascending: false).order('id', ascending: false).limit(limit);
        return rows.map(_toPost).toList();
      });

  /// [B3] 게시글 상세
  Future<FeedPost> getPost(int postId) => guard(() async {
        final row = await _db.from('post_feed').select().eq('id', postId).single();
        return _toPost(row);
      });

  /// [E2] 인기 게시물 랭킹 (최근 [days]일, 좋아요 순)
  Future<List<FeedPost>> fetchPopular({int days = 7, int limit = 20}) => guard(() async {
        final rows = await _db.rpc('get_popular_posts', params: {'p_days': days, 'p_limit': limit});
        return (rows as List).cast<Map<String, dynamic>>().map(_toPost).toList();
      });

  /// [F1] 태그로 검색 (예: '#화이트셔츠')
  Future<List<FeedPost>> fetchByTag(String tag, {DateTime? before, int limit = pageSize}) => guard(() async {
        final normalized = normalizeTags([tag]);
        if (normalized.isEmpty) return <FeedPost>[];
        var query = _db.from('post_feed').select().contains('tags', normalized);
        if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
        final rows = await query.order('created_at', ascending: false).limit(limit);
        return rows.map(_toPost).toList();
      });

  /// 내가 쓴 글
  Future<List<FeedPost>> fetchMyPosts() => guard(() async {
        final uid = _auth.requireUserId();
        final rows = await _db.from('post_feed').select().eq('author_id', uid).order('created_at', ascending: false);
        return rows.map(_toPost).toList();
      });

  // ------------------------------------------------------------------
  // 작성 · 수정 · 삭제
  // ------------------------------------------------------------------

  /// [B2] 게시글 작성
  ///   imageBytes  : 선택한 사진 (JPEG 권장, 5MB 이하)
  ///   tags        : [F1] AI가 추천한 태그 중 사용자가 고른 것
  ///   purchaseUrl : [B5] 구매 링크 (선택)
  ///   clothingTags: [C5] 사진 위 옷 태그 (선택)
  /// 반환된 FeedPost 를 피드 맨 위에 넣으면 작성 즉시 최상단에 표시된다.
  Future<FeedPost> createPost({
    required Uint8List imageBytes,
    String content = '',
    List<String> tags = const [],
    String? purchaseUrl,
    List<ClothingTag> clothingTags = const [],
    String contentType = 'image/jpeg',
  }) =>
      guard(() async {
        final uid = _auth.requireUserId();
        final ext = switch (contentType) { 'image/png' => 'png', 'image/webp' => 'webp', _ => 'jpg' };
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

        // 1) 사진 업로드
        await _db.storage.from(SupabaseConfig.imageBucket).uploadBinary(
              path,
              imageBytes,
              fileOptions: FileOptions(contentType: contentType, upsert: false),
            );

        int? postId;
        try {
          // 2) 게시글 저장 (작성자 UID·작성 시간은 DB 기본값으로 자동 입력)
          final inserted = await _db
              .from('posts')
              .insert({
                'image_path': path,
                'content': content.trim(),
                'tags': normalizeTags(tags),
                'purchase_url': _blankToNull(purchaseUrl),
              })
              .select('id')
              .single();
          postId = (inserted['id'] as num).toInt();

          // 3) 옷 태그 저장
          if (clothingTags.isNotEmpty) {
            await _db.from('clothing_tags').insert(clothingTags.map((t) => t.toInsert(postId!)).toList());
          }
        } catch (_) {
          // 중간에 실패하면 만들어진 글과 올려둔 사진을 지워 반쪽짜리 게시글이 남지 않게 한다.
          try {
            if (postId != null) await _db.from('posts').delete().eq('id', postId);
            await _db.storage.from(SupabaseConfig.imageBucket).remove([path]);
          } catch (_) {
            // 정리 실패는 무시하고 원래 오류를 전달
          }
          rethrow;
        }

        // 4) 저장된 글을 닉네임 등과 함께 다시 읽어 반환
        return getPost(postId!);
      });

  /// 게시글 수정 (본인 글만 가능 — RLS 가 보장). null 인 항목은 바꾸지 않는다.
  Future<FeedPost> updatePost(int postId, {String? content, List<String>? tags, String? purchaseUrl, bool clearPurchaseUrl = false}) =>
      guard(() async {
        final changes = <String, dynamic>{
          if (content != null) 'content': content.trim(),
          if (tags != null) 'tags': normalizeTags(tags),
          if (purchaseUrl != null || clearPurchaseUrl) 'purchase_url': clearPurchaseUrl ? null : _blankToNull(purchaseUrl),
        };
        if (changes.isNotEmpty) {
          final updated = await _db.from('posts').update(changes).eq('id', postId).select('id');
          if (updated.isEmpty) {
            throw const AppException(AppErrorType.forbidden, '본인이 작성한 글만 수정할 수 있어요.');
          }
        }
        return getPost(postId);
      });

  /// 게시글 삭제 (본인 글만). 좋아요·댓글·옷 태그·신고는 DB 에서 함께 삭제되고, 사진도 지운다.
  Future<void> deletePost(FeedPost post) => guard(() async {
        final deleted = await _db.from('posts').delete().eq('id', post.id).select('id');
        if (deleted.isEmpty) {
          throw const AppException(AppErrorType.forbidden, '본인이 작성한 글만 삭제할 수 있어요.');
        }
        await _db.storage.from(SupabaseConfig.imageBucket).remove([post.imagePath]);
      });

  // ------------------------------------------------------------------
  // [D1] 실시간 동기화
  // ------------------------------------------------------------------

  /// 다른 기기에서 생긴 글 추가·수정·삭제를 받는다. 좋아요·댓글 수 변화도 PostUpdated 로 들어온다.
  /// 화면이 닫힐 때 StreamSubscription.cancel() 을 호출하면 구독도 함께 해제된다.
  Stream<FeedEvent> watchFeed() {
    late final RealtimeChannel channel;
    late final StreamController<FeedEvent> controller;

    Future<void> handle(PostgresChangePayload payload) async {
      try {
        switch (payload.eventType) {
          case PostgresChangeEvent.insert:
            final id = (payload.newRecord['id'] as num).toInt();
            controller.add(PostInserted(await getPost(id)));
          case PostgresChangeEvent.update:
            final id = (payload.newRecord['id'] as num).toInt();
            controller.add(PostUpdated(await getPost(id)));
          case PostgresChangeEvent.delete:
            final id = payload.oldRecord['id'];
            if (id != null) controller.add(PostDeleted((id as num).toInt()));
          default:
            break;
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<FeedEvent>(
      onListen: () {
        channel = _db
            .channel('public:posts:${DateTime.now().microsecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'posts',
              callback: handle,
            )
            .subscribe();
      },
      onCancel: () async {
        await _db.removeChannel(channel);
        await controller.close();
      },
    );
    return controller.stream;
  }

  // ------------------------------------------------------------------
  // 유틸
  // ------------------------------------------------------------------

  /// [F1] 태그 정리: 앞뒤 공백 제거, '#' 붙이기, 공백 제거, 중복 제거, 최대 10개
  static List<String> normalizeTags(Iterable<String> raw) {
    final result = <String>[];
    for (final t in raw) {
      var tag = t.trim().replaceAll(RegExp(r'\s+'), '');
      if (tag.isEmpty || tag == '#') continue;
      if (!tag.startsWith('#')) tag = '#$tag';
      if (tag.length > 21) tag = tag.substring(0, 21);
      if (!result.contains(tag)) result.add(tag);
      if (result.length == 10) break;
    }
    return result;
  }

  static String? _blankToNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}
