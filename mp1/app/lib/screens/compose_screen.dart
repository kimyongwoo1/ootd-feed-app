import 'package:flutter/material.dart';

import '../models/post.dart';

/// 2. 글쓰기 화면 – [게시]를 누르면 작성한 글을 피드로 돌려준다
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const _defaultNickname = '익명';

  final _nickname = TextEditingController();
  final _content = TextEditingController();

  bool get _canPost => _content.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nickname.dispose();
    _content.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canPost) return;
    final nickname = _nickname.text.trim();
    Navigator.pop(
      context,
      Post(
        id: 'post-${DateTime.now().microsecondsSinceEpoch}',
        nickname: nickname.isEmpty ? _defaultNickname : nickname,
        content: _content.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        actions: [
          TextButton(
            key: const Key('submit_button'),
            onPressed: _canPost ? _submit : null,
            child: const Text('게시'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('nickname_field'),
            controller: _nickname,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: '닉네임 (선택)',
              hintText: '비우면 "$_defaultNickname"으로 올라가요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('content_field'),
            controller: _content,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            maxLength: 200,
            onChanged: (_) => setState(() {}), // [게시] 버튼 활성화 갱신
            decoration: const InputDecoration(
              labelText: '내용',
              hintText: '오늘의 코디를 소개해 주세요',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
