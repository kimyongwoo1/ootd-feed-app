/// 게시글 한 개 (더미 데이터 구조: id, nickname, content, createdAt)
class Post {
  final String id;
  final String nickname;
  final String content;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.nickname,
    required this.content,
    required this.createdAt,
  });
}
