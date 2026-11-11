/// 게시글 한 개 — Supabase `mini_posts` 테이블의 한 줄과 1:1로 대응
class Post {
  final String id;
  final String nickname;
  final String content;
  final DateTime createdAt;

  /// 지금 기기(익명 사용자)가 쓴 글인지
  final bool isMine;

  const Post({
    required this.id,
    required this.nickname,
    required this.content,
    required this.createdAt,
    this.isMine = false,
  });

  /// 서버에서 받은 한 줄(JSON) → Post
  factory Post.fromJson(Map<String, dynamic> json, {String? myUserId}) {
    return Post(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      isMine: myUserId != null && json['author_id'] == myUserId,
    );
  }
}
