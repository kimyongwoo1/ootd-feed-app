import 'package:flutter/material.dart';

import '../services/app_exception.dart';
import '../services/post_repository.dart';

/// 2. 글쓰기 화면 – [게시]하면 서버에 저장하고, 저장된 글을 피드로 돌려준다
class ComposeScreen extends StatefulWidget {
  final PostRepository repository;

  const ComposeScreen({super.key, required this.repository});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  static const _defaultNickname = '익명';

  final _nickname = TextEditingController();
  final _content = TextEditingController();
  bool _sending = false; // 저장 중에는 버튼을 막아 중복 게시 방지

  bool get _canPost => _content.text.trim().isNotEmpty && !_sending;

  @override
  void dispose() {
    _nickname.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canPost) return;
    setState(() => _sending = true);
    final nickname = _nickname.text.trim();
    try {
      final saved = await widget.repository.createPost(
        nickname: nickname.isEmpty ? _defaultNickname : nickname,
        content: _content.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } on AppException catch (e) {
      // 작성 실패: 입력한 내용은 그대로 두고 안내 + 다시 시도 버튼
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          key: const Key('post_error'),
          content: Text('게시하지 못했어요. ${e.message}'),
          action: SnackBarAction(label: '다시 시도', onPressed: _submit),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('글쓰기'),
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
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
            enabled: !_sending,
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
            enabled: !_sending,
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
          const SizedBox(height: 8),
          Text(
            '이메일·전화번호 같은 개인정보는 적지 마세요. 글은 익명으로 저장돼요.',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
