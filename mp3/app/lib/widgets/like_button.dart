import 'package:flutter/material.dart';

import '../models/post.dart';

/// 하트 + 좋아요 수. 누른 상태면 빨간 하트.
/// 누가 눌렀는지는 보여 주지 않고 숫자만 보여 준다 (GUIDELINES.md 3장)
class LikeButton extends StatelessWidget {
  final Post post;
  final VoidCallback? onPressed;

  const LikeButton({super.key, required this.post, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final liked = post.likedByMe;
    return TextButton.icon(
      key: Key('like_${post.id}'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: liked ? Colors.red : Theme.of(context).colorScheme.outline,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
      ),
      icon: Icon(liked ? Icons.favorite : Icons.favorite_border, size: 20),
      label: Text('${post.likesCount}', key: Key('likes_count_${post.id}')),
    );
  }
}
