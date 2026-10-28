/// [C2] 댓글
class Comment {
  final int id;
  final int postId;
  final String authorId;
  final String nickname;
  final String content;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.nickname,
    required this.content,
    required this.createdAt,
  });

  /// comments 테이블 + profiles(nickname) 조인 결과
  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: (j['id'] as num).toInt(),
        postId: (j['post_id'] as num).toInt(),
        authorId: j['author_id'] as String,
        nickname: (j['profiles'] as Map<String, dynamic>?)?['nickname'] as String? ?? '알 수 없음',
        content: j['content'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
