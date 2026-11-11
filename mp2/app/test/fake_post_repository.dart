import 'package:app/models/post.dart';
import 'package:app/services/app_exception.dart';
import 'package:app/services/post_repository.dart';

/// 테스트용 가짜 서버 — 실제 Supabase 없이 화면 동작만 확인한다
class FakePostRepository implements PostRepository {
  FakePostRepository({this.failFetch = false, this.failCreate = false});

  bool failFetch;
  bool failCreate;

  final List<Post> _server = [
    for (var i = 0; i < 3; i++)
      Post(
        id: 'p$i',
        nickname: ['초록고래', '새벽코더', '라떼한잔'][i],
        content: '더미 게시글 ${i + 1}번입니다.',
        createdAt: DateTime.now().subtract(Duration(minutes: [3, 18, 47][i])),
      ),
  ];

  @override
  String? get myUserId => '1234abcd-0000-0000-0000-000000000000';

  @override
  Future<void> signIn() async {}

  @override
  Future<List<Post>> fetchPosts() async {
    if (failFetch) throw const AppException('네트워크에 연결할 수 없어요.');
    return List.of(_server);
  }

  @override
  Future<Post> createPost({required String nickname, required String content}) async {
    if (failCreate) throw const AppException('네트워크에 연결할 수 없어요.');
    final post = Post(
      id: 'new${_server.length}',
      nickname: nickname,
      content: content,
      createdAt: DateTime.now(),
      isMine: true,
    );
    _server.insert(0, post);
    return post;
  }
}
