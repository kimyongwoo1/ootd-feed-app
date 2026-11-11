/// 댓글 한 개 — Supabase `mini_comments` 테이블의 한 줄
class Comment {
  final String id;
  final String postId;
  final String nickname;
  final String content;
  final DateTime createdAt;
  final bool isMine;

  const Comment({
    required this.id,
    required this.postId,
    required this.nickname,
    required this.content,
    required this.createdAt,
    this.isMine = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json, {String? myUserId}) {
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      nickname: json['nickname'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      isMine: myUserId != null && json['author_id'] == myUserId,
    );
  }
}
