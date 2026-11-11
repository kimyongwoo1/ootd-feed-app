import 'dart:async';

import 'package:flutter/material.dart';

import '../data/dummy_posts.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'compose_screen.dart';
import 'detail_screen.dart';

/// 1. 피드 화면 – 더미 게시글 10개를 카드로 스크롤 표시
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Post> _posts = createDummyPosts();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
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

  /// 2. 글쓰기 화면에서 [게시]한 글을 받아 피드 최상단에 추가
  Future<void> _openCompose() async {
    final post = await Navigator.push<Post>(
      context,
      MaterialPageRoute(builder: (_) => const ComposeScreen()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('미니 피드')),
      body: ListView.builder(
        key: const Key('feed_list'),
        padding: const EdgeInsets.only(top: 8, bottom: 88),
        itemCount: _posts.length,
        itemBuilder: (context, i) => PostCard(
          key: ValueKey(_posts[i].id),
          post: _posts[i],
          onTap: () => _openDetail(_posts[i]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('compose_button'),
        tooltip: '글쓰기',
        onPressed: _openCompose,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
