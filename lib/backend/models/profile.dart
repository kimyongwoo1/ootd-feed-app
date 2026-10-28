/// [A2] 사용자 프로필
class Profile {
  final String id;          // 익명 UID
  final String nickname;
  final DateTime createdAt;

  const Profile({required this.id, required this.nickname, required this.createdAt});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        nickname: j['nickname'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
