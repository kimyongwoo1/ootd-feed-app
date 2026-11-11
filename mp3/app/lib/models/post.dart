/// 게시글 한 개 — Supabase `mini_posts` 테이블의 한 줄과 1:1로 대응
class Post {
  final String id;
  final String nickname;
  final String content;
  final DateTime createdAt;

  /// 지금 기기(익명 사용자)가 쓴 글인지
  final bool isMine;

  /// MP3: 좋아요 수 · 댓글 수 (서버 트리거가 계산한 값)
  final int likesCount;
  final int commentsCount;

  /// MP3: 내가 좋아요를 눌렀는지
  final bool likedByMe;

  const Post({
    required this.id,
    required this.nickname,
    required this.content,
    required this.createdAt,
    this.isMine = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
  });

  /// 서버에서 받은 한 줄(JSON) → Post
  /// `mini_post_likes` 에는 RLS 때문에 **내 좋아요만** 들어 있다 → 비어 있지 않으면 내가 누른 것
  factory Post.fromJson(Map<String, dynamic> json, {String? myUserId}) {
    final myLikes = json['mini_post_likes'] as List<dynamic>? ?? const [];
    return Post(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      isMine: myUserId != null && json['author_id'] == myUserId,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      likedByMe: myLikes.isNotEmpty,
    );
  }

  Post copyWith({int? likesCount, int? commentsCount, bool? likedByMe}) {
    return Post(
      id: id,
      nickname: nickname,
      content: content,
      createdAt: createdAt,
      isMine: isMine,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}
