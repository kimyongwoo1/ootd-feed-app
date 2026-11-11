import 'package:flutter/material.dart';

import '../models/post.dart';
import '../utils/relative_time.dart';

/// 피드의 게시글 카드 (닉네임 · 작성 시각 · 내용)
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 프로필 사진 대신 기본 아이콘(닉네임 첫 글자)
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(post.nickname.characters.first,
                        style: TextStyle(color: scheme.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(post.nickname,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(relativeTime(post.createdAt),
                      style: TextStyle(fontSize: 12, color: scheme.outline)),
                ],
              ),
              const SizedBox(height: 12),
              Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
