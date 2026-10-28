/// [B1, B3] 피드·상세 화면에서 쓰는 게시글 (post_feed 뷰 한 줄)
class FeedPost {
  final int id;
  final String authorId;
  final String nickname;
  final String imagePath;   // Storage 경로
  final String imageUrl;    // 화면에 바로 쓰는 공개 URL
  final String content;
  final String? purchaseUrl;   // [B5]
  final List<String> tags;     // [F1]
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;    // [B4] 서버 시간
  final DateTime updatedAt;
  final bool likedByMe;        // [C1]
  final bool isMine;

  const FeedPost({
    required this.id,
    required this.authorId,
    required this.nickname,
    required this.imagePath,
    required this.imageUrl,
    required this.content,
    required this.purchaseUrl,
    required this.tags,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.updatedAt,
    required this.likedByMe,
    required this.isMine,
  });

  factory FeedPost.fromJson(Map<String, dynamic> j, String Function(String path) toUrl) => FeedPost(
        id: (j['id'] as num).toInt(),
        authorId: j['author_id'] as String,
        nickname: j['nickname'] as String,
        imagePath: j['image_path'] as String,
        imageUrl: toUrl(j['image_path'] as String),
        content: (j['content'] as String?) ?? '',
        purchaseUrl: j['purchase_url'] as String?,
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
        likesCount: (j['likes_count'] as num).toInt(),
        commentsCount: (j['comments_count'] as num).toInt(),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        likedByMe: (j['liked_by_me'] as bool?) ?? false,
        isMine: (j['is_mine'] as bool?) ?? false,
      );

  /// 낙관적 업데이트(좋아요 즉시 반영)에 쓰는 복사 함수
  FeedPost copyWith({bool? likedByMe, int? likesCount, int? commentsCount}) => FeedPost(
        id: id,
        authorId: authorId,
        nickname: nickname,
        imagePath: imagePath,
        imageUrl: imageUrl,
        content: content,
        purchaseUrl: purchaseUrl,
        tags: tags,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
        likedByMe: likedByMe ?? this.likedByMe,
        isMine: isMine,
      );
}
