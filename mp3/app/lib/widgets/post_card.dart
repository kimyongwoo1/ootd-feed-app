import 'package:flutter/material.dart';

import '../models/post.dart';
import '../utils/relative_time.dart';
import 'like_button.dart';

/// 피드의 게시글 카드 (닉네임 · 작성 시각 · 내용 · 좋아요 · 댓글 수)
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLike;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
  });

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
                  Flexible(
                    child: Text(post.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  // 이 기기(익명 사용자)가 쓴 글 표시
                  if (post.isMine) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('내 글',
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSecondaryContainer)),
                    ),
                  ],
                  const Spacer(),
                  Text(relativeTime(post.createdAt),
                      style: TextStyle(fontSize: 12, color: scheme.outline)),
                ],
              ),
              const SizedBox(height: 12),
              Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              // MP3: 좋아요 · 댓글 수
              Row(
                children: [
                  LikeButton(post: post, onPressed: onLike),
                  const SizedBox(width: 8),
                  Icon(Icons.chat_bubble_outline, size: 20, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text('${post.commentsCount}',
                      key: Key('comments_count_${post.id}'),
                      style: TextStyle(color: scheme.outline)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
