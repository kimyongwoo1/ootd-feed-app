import 'package:flutter/material.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../services/app_exception.dart';
import '../services/post_repository.dart';
import '../utils/relative_time.dart';
import '../widgets/like_button.dart';
import '../widgets/report_sheet.dart';

/// 3. 상세 화면 – 글 전체 + 좋아요 + 댓글 목록·작성 + 신고
class DetailScreen extends StatefulWidget {
  final Post post;
  final PostRepository repository;

  /// 좋아요·댓글 수가 바뀌면 피드에 알려 줌
  final ValueChanged<Post> onChanged;

  /// 신고가 접수되면 피드에서 이 글을 빼도록 알려 줌
  final ValueChanged<String> onReported;

  const DetailScreen({
    super.key,
    required this.post,
    required this.repository,
    required this.onChanged,
    required this.onReported,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Post _post = widget.post;
  List<Comment> _comments = [];
  bool _commentsLoading = true;
  String? _commentsError;
  bool _likeBusy = false;
  bool _sending = false;
  bool _reporting = false;

  final _nickname = TextEditingController();
  final _comment = TextEditingController();

  PostRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _refresh(showErrors: false);
  }

  @override
  void dispose() {
    _nickname.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _setPost(Post p) {
    if (!mounted) return;
    setState(() => _post = p);
    widget.onChanged(p);
  }

  /// 글(좋아요·댓글 수)과 댓글 목록을 서버에서 다시 불러오기 — 당겨서 새로고침
  Future<void> _refresh({bool showErrors = true}) async {
    try {
      final results = await Future.wait([
        _repo.getPost(_post.id),
        _repo.fetchComments(_post.id),
      ]);
      if (!mounted) return;
      _setPost(results[0] as Post);
      setState(() {
        _comments = results[1] as List<Comment>;
        _commentsError = null;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      if (_comments.isEmpty) setState(() => _commentsError = e.message);
      if (showErrors) _snack('새로고침하지 못했어요. ${e.message}');
    } finally {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  /// 좋아요 토글 (낙관적 업데이트 → 실패 시 되돌림)
  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    final before = _post;
    final want = !before.likedByMe;
    setState(() => _likeBusy = true);
    _setPost(before.copyWith(
      likedByMe: want,
      likesCount: before.likesCount + (want ? 1 : -1),
    ));
    try {
      _setPost(await _repo.setLiked(before.id, liked: want));
    } on AppException catch (e) {
      _setPost(before);
      _snack('좋아요를 반영하지 못했어요. ${e.message}');
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  /// 댓글 작성 — 실패하면 입력한 내용은 그대로 두고 다시 시도 버튼
  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    final nick = _nickname.text.trim();
    setState(() => _sending = true);
    try {
      final c = await _repo.addComment(
        _post.id,
        nickname: nick.isEmpty ? '익명' : nick,
        content: text,
      );
      if (!mounted) return;
      setState(() => _comments = [..._comments, c]);
      _comment.clear();
      _setPost(_post.copyWith(commentsCount: _post.commentsCount + 1));
    } on AppException catch (e) {
      _snack('댓글을 올리지 못했어요. ${e.message}', retry: _sendComment);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 신고 — 사유 선택 → 서버 기록 → 피드로 돌아가 이 글을 숨김
  Future<void> _report() async {
    final input = await showReportSheet(context);
    if (input == null || !mounted) return;
    setState(() => _reporting = true);
    try {
      await _repo.reportPost(_post.id, reason: input.reason, detail: input.detail);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      widget.onReported(_post.id);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        key: Key('report_done'),
        content: Text('신고가 접수됐어요. 이 글은 내 피드에서 숨겨져요.'),
      ));
    } on AppException catch (e) {
      _snack('신고하지 못했어요. ${e.message}');
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  void _snack(String message, {VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: retry == null ? null : SnackBarAction(label: '다시 시도', onPressed: retry),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          // 내 글은 신고할 수 없음
          if (!_post.isMine)
            IconButton(
              key: const Key('report_button'),
              tooltip: '신고',
              onPressed: _reporting ? null : _report,
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  _header(scheme),
                  const Divider(height: 32),
                  SelectableText(
                    _post.content,
                    key: const Key('detail_content'),
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      LikeButton(post: _post, onPressed: _likeBusy ? null : _toggleLike),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('댓글 ${_post.commentsCount}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._commentList(scheme),
                ],
              ),
            ),
          ),
          _commentBar(scheme),
        ],
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: scheme.primaryContainer,
          child: Text(_post.nickname.characters.first,
              style: TextStyle(fontSize: 18, color: scheme.onPrimaryContainer)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_post.nickname,
                  key: const Key('detail_nickname'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${relativeTime(_post.createdAt)} · ${formatDateTime(_post.createdAt)}',
                  style: TextStyle(fontSize: 12, color: scheme.outline)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _commentList(ColorScheme scheme) {
    if (_commentsLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      ];
    }
    if (_commentsError != null && _comments.isEmpty) {
      return [
        Text(_commentsError!, style: TextStyle(color: scheme.error)),
        TextButton(onPressed: _refresh, child: const Text('다시 불러오기')),
      ];
    }
    if (_comments.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('첫 댓글을 남겨 보세요.', style: TextStyle(color: scheme.outline)),
        )
      ];
    }
    return [
      for (final c in _comments)
        Padding(
          key: ValueKey(c.id),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text(c.nickname.characters.first, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: c.nickname,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (c.isMine)
                        TextSpan(
                            text: '  내 댓글',
                            style: TextStyle(fontSize: 11, color: scheme.secondary)),
                      TextSpan(
                          text: '  ${relativeTime(c.createdAt)}',
                          style: TextStyle(fontSize: 11, color: scheme.outline)),
                    ])),
                    const SizedBox(height: 2),
                    Text(c.content),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _commentBar(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: TextField(
                key: const Key('comment_nickname'),
                controller: _nickname,
                enabled: !_sending,
                maxLength: 10,
                decoration: const InputDecoration(
                  hintText: '닉네임',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('comment_field'),
                controller: _comment,
                enabled: !_sending,
                maxLength: 200,
                minLines: 1,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '댓글 달기 (개인정보는 적지 마세요)',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              key: const Key('comment_send'),
              tooltip: '댓글 올리기',
              onPressed: _comment.text.trim().isEmpty || _sending ? null : _sendComment,
              icon: _sending
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
