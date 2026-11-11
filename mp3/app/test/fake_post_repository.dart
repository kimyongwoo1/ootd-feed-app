import 'package:app/models/comment.dart';
import 'package:app/models/post.dart';
import 'package:app/models/report_reason.dart';
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
  final Set<String> likedByMe = {};
  final Map<String, List<Comment>> comments = {};
  final List<(String postId, ReportReason reason, String? detail)> reports = [];

  @override
  String? get myUserId => '1234abcd-0000-0000-0000-000000000000';

  @override
  Future<void> signIn() async {}

  Post _view(Post p) => p.copyWith(
        likedByMe: likedByMe.contains(p.id),
        likesCount: likedByMe.contains(p.id) ? 1 : 0,
        commentsCount: comments[p.id]?.length ?? 0,
      );

  @override
  Future<List<Post>> fetchPosts() async {
    if (failFetch) throw const AppException('네트워크에 연결할 수 없어요.');
    final hidden = reports.map((r) => r.$1).toSet();
    return _server.where((p) => !hidden.contains(p.id)).map(_view).toList();
  }

  @override
  Future<Post> getPost(String postId) async =>
      _view(_server.firstWhere((p) => p.id == postId));

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

  @override
  Future<Post> setLiked(String postId, {required bool liked}) async {
    liked ? likedByMe.add(postId) : likedByMe.remove(postId);
    return getPost(postId);
  }

  @override
  Future<List<Comment>> fetchComments(String postId) async =>
      List.of(comments[postId] ?? const []);

  @override
  Future<Comment> addComment(String postId,
      {required String nickname, required String content}) async {
    final c = Comment(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      nickname: nickname,
      content: content,
      createdAt: DateTime.now(),
      isMine: true,
    );
    comments.putIfAbsent(postId, () => []).add(c);
    return c;
  }

  @override
  Future<void> reportPost(String postId,
      {required ReportReason reason, String? detail}) async {
    if (reports.any((r) => r.$1 == postId)) {
      throw const AppException('이미 신고한 게시글이에요.');
    }
    reports.add((postId, reason, detail));
  }
}
