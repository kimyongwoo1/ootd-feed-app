import 'feed_post.dart';

/// [D1] 다른 기기에서 생긴 피드 변경 사항
sealed class FeedEvent {
  const FeedEvent();
}

/// 새 글이 올라옴 → 목록 맨 위에 추가
class PostInserted extends FeedEvent {
  final FeedPost post;
  const PostInserted(this.post);
}

/// 글 내용·좋아요 수·댓글 수가 바뀜 → 해당 글 교체
class PostUpdated extends FeedEvent {
  final FeedPost post;
  const PostUpdated(this.post);
}

/// 글이 삭제됨 → 목록에서 제거
class PostDeleted extends FeedEvent {
  final int postId;
  const PostDeleted(this.postId);
}
