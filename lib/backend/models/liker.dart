/// [C3] 좋아요를 누른 사람
class Liker {
  final String userId;
  final String nickname;
  final DateTime likedAt;

  const Liker({required this.userId, required this.nickname, required this.likedAt});

  factory Liker.fromJson(Map<String, dynamic> j) => Liker(
        userId: j['user_id'] as String,
        nickname: (j['profiles'] as Map<String, dynamic>?)?['nickname'] as String? ?? '알 수 없음',
        likedAt: DateTime.parse(j['created_at'] as String),
      );
}
