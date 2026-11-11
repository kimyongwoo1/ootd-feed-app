import 'package:flutter/material.dart';

import '../models/post.dart';
import '../utils/relative_time.dart';

/// 3. 상세 화면 – 탭한 게시글의 전체 내용을 보여준다
class DetailScreen extends StatelessWidget {
  final Post post;

  const DetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('게시글')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                child: Text(post.nickname.characters.first,
                    style: TextStyle(fontSize: 18, color: scheme.onPrimaryContainer)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.nickname,
                        key: const Key('detail_nickname'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${relativeTime(post.createdAt)} · ${formatDateTime(post.createdAt)}',
                        style: TextStyle(fontSize: 12, color: scheme.outline)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          SelectableText(
            post.content,
            key: const Key('detail_content'),
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
        ],
      ),
    );
  }
}
