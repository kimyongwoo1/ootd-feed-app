import 'dart:async';

import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/app_exception.dart';
import '../services/post_repository.dart';
import '../widgets/post_card.dart';
import 'compose_screen.dart';
import 'detail_screen.dart';

/// 1. 피드 화면 – Supabase 에서 글 목록을 불러와 카드로 표시
class FeedScreen extends StatefulWidget {
  final PostRepository repository;

  const FeedScreen({super.key, required this.repository});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _loading = true; // 처음 불러오는 중
  String? _error; // 처음 불러오기 실패 메시지
  Timer? _ticker;

  PostRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _start();
    // 화면을 켜 둔 동안에도 '방금 전' → '1분 전'처럼 시간이 갱신되도록 1분마다 다시 그림
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// 익명 로그인 → 첫 목록 불러오기
  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.signIn();
      final posts = await _repo.fetchPosts();
      if (!mounted) return;
      setState(() => _posts = posts);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 당겨서 새로고침 — 실패해도 지금 보이는 목록은 그대로 두고 안내만 띄움
  Future<void> _refresh() async {
    try {
      final posts = await _repo.fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _error = null;
      });
    } on AppException catch (e) {
      _showSnack('새로고침하지 못했어요. ${e.message}');
    }
  }

  /// 2. 글쓰기 화면에서 서버에 저장된 글을 받아 피드 최상단에 추가
  Future<void> _openCompose() async {
    final post = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => ComposeScreen(repository: _repo)),
    );
    if (post != null) setState(() => _posts.insert(0, post));
  }

  /// 3. 게시글을 탭하면 상세 화면으로 이동
  void _openDetail(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(post: post)),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final uid = _repo.myUserId;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('미니 피드'),
            // 기기마다 다른 익명 ID — 두 기기 동기화 스크린샷에서 구분용
            if (uid != null)
              Text('익명 ID ${uid.substring(0, 8)}',
                  key: const Key('anon_id'),
                  style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _error == null && !_loading
          ? FloatingActionButton(
              key: const Key('compose_button'),
              tooltip: '글쓰기',
              onPressed: _openCompose,
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _start);
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('아직 글이 없어요. 첫 글을 남겨 보세요!')),
              ],
            )
          : ListView.builder(
              key: const Key('feed_list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              itemCount: _posts.length,
              itemBuilder: (context, i) => PostCard(
                key: ValueKey(_posts[i].id),
                post: _posts[i],
                onTap: () => _openDetail(_posts[i]),
              ),
            ),
    );
  }
}

/// 처음 불러오기에 실패했을 때 (오프라인, 설정 오류 등)
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 16),
            Text(message, key: const Key('error_message'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('retry_button'),
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
