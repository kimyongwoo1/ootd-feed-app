// =====================================================================
// 백엔드 동작 확인용 화면 (개발용 – 실제 앱 화면 아님)
//   실행: flutter run -d chrome -t lib/dev/backend_check.dart
//   실제 Supabase 서버에 테스트 데이터를 만들고, 마지막에 게시글을 삭제한다.
// =====================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../backend/backend.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BackendCheckPage(),
  ));
}

class CheckResult {
  final String name;
  final bool ok;
  final String detail;
  const CheckResult(this.name, this.ok, this.detail);
}

class BackendCheckPage extends StatefulWidget {
  const BackendCheckPage({super.key});

  @override
  State<BackendCheckPage> createState() => _BackendCheckPageState();
}

class _BackendCheckPageState extends State<BackendCheckPage> {
  // 1x1 크기 PNG 이미지 (사진 업로드 테스트용)
  static const _pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  final _results = <CheckResult>[];
  bool _running = false;
  bool _initialized = false;

  void _add(CheckResult r) {
    debugPrint('${r.ok ? '✅' : '❌'} ${r.name} — ${r.detail}');
    if (mounted) setState(() => _results.add(r));
  }

  /// 성공해야 정상인 검사
  Future<void> _check(String name, Future<String> Function() body) async {
    try {
      _add(CheckResult(name, true, await body()));
    } on AppException catch (e) {
      _add(CheckResult(name, false, '${e.type.name}: ${e.message} / ${e.cause}'));
    } catch (e) {
      _add(CheckResult(name, false, e.toString()));
    }
  }

  /// 오류가 나야 정상인 검사
  Future<void> _expectError(String name, AppErrorType expected, Future<void> Function() body) async {
    try {
      await body();
      _add(CheckResult(name, false, '오류가 나야 하는데 성공했어요'));
    } on AppException catch (e) {
      _add(CheckResult(name, e.type == expected, '${e.type.name}: ${e.message}'));
    } catch (e) {
      _add(CheckResult(name, false, e.toString()));
    }
  }

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    final auth = AuthRepository.new;
    final profiles = ProfileRepository.new;
    final posts = PostRepository.new;
    final likes = LikeRepository.new;
    final comments = CommentRepository.new;
    final reports = ReportRepository.new;
    final clothingTags = ClothingTagRepository.new;
    final image = base64Decode(_pngBase64);
    FeedPost? post;
    String nickname = '';

    // ---------------- 연결 · 인증 ----------------
    await _check('0. Supabase 연결 (.env)', () async {
      if (!_initialized) {
        await SupabaseConfig.init();
        _initialized = true;
      }
      return '연결 설정 완료';
    });

    await _check('A1 익명 로그인', () async {
      final uid = await auth().ensureSignedIn();
      return 'UID: $uid';
    });

    await _check('A2 닉네임 설정', () async {
      final mine = await profiles().getMyProfile();
      if (mine != null) {
        nickname = mine.nickname;
        return '이미 설정됨: $nickname';
      }
      final saved = await profiles().setNickname('check${Random().nextInt(9000) + 1000}');
      nickname = saved.nickname;
      return '새로 저장: $nickname';
    });

    await _check('A2 내 닉네임 사용 가능 여부', () async {
      final ok = await profiles().isNicknameAvailable(nickname);
      if (!ok) throw StateError('내 닉네임인데 사용 불가로 나옴');
      return '사용 가능 (본인 닉네임)';
    });

    await _expectError('A2 닉네임 11자 차단', AppErrorType.invalidInput,
        () => profiles().setNickname('가나다라마바사아자차카'));

    // ---------------- 게시글 ----------------
    await _check('B2 게시글 작성 (사진 업로드 포함)', () async {
      post = await posts().createPost(
        imageBytes: image,
        contentType: 'image/png',
        content: '백엔드 확인용 게시글',
        tags: ['화이트셔츠', '#블루 데님'],
        purchaseUrl: 'https://example.com/item/1',
      );
      final p = post!;
      return 'id=${p.id}, 작성자=${p.nickname}, 태그=${p.tags}\n사진 URL: ${p.imageUrl}';
    });

    await _expectError('B5 잘못된 구매 링크 차단', AppErrorType.invalidInput,
        () => posts().createPost(imageBytes: image, contentType: 'image/png', purchaseUrl: 'shop.example.com'));

    await _expectError('B2 내용 201자 차단', AppErrorType.invalidInput,
        () => posts().createPost(imageBytes: image, contentType: 'image/png', content: 'a' * 201));

    await _check('B1 피드 조회 (최신순)', () async {
      final feed = await posts().fetchFeed();
      if (feed.isEmpty || feed.first.id != post!.id) throw StateError('방금 쓴 글이 맨 위에 없음');
      return '${feed.length}개 조회, 방금 쓴 글이 맨 위';
    });

    await _check('B3 게시글 상세 + B4 상대 시간', () async {
      final p = await posts().getPost(post!.id);
      return '닉네임=${p.nickname}, 내 글=${p.isMine}, 작성=${relativeTime(p.createdAt)}';
    });

    // ---------------- 실시간 ----------------
    await _check('D1 실시간 동기화 (글 수정 이벤트)', () async {
      final got = Completer<String>();
      final sub = posts().watchFeed().listen((e) {
        if (e is PostUpdated && e.post.id == post!.id && !got.isCompleted) {
          got.complete('수정 이벤트 수신: "${e.post.content}"');
        }
      });
      try {
        await Future<void>.delayed(const Duration(seconds: 3)); // 구독 연결 대기
        await posts().updatePost(post!.id, content: '수정된 내용');
        return await got.future.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        throw StateError('10초 안에 실시간 이벤트가 오지 않음 (Realtime 설정 확인)');
      } finally {
        await sub.cancel();
      }
    });

    // ---------------- 좋아요 ----------------
    await _check('C1 좋아요 / 중복 방지 / 취소', () async {
      final id = post!.id;
      await likes().setLiked(id, true);
      final a = await posts().getPost(id);
      await likes().setLiked(id, true); // 중복 → 그대로 1개
      final b = await posts().getPost(id);
      await likes().setLiked(id, false);
      final c = await posts().getPost(id);
      if (a.likesCount != 1 || !a.likedByMe || b.likesCount != 1 || c.likesCount != 0) {
        throw StateError('좋아요 수: ${a.likesCount} → ${b.likesCount} → ${c.likesCount}');
      }
      return '좋아요 1 → 중복 눌러도 1 → 취소 0';
    });

    await _check('C3 좋아요한 사람', () async {
      await likes().setLiked(post!.id, true);
      final likers = await likes().fetchLikers(post!.id);
      if (likers.isEmpty || likers.first.nickname != nickname) throw StateError('목록에 내 닉네임 없음');
      return likers.map((l) => l.nickname).join(', ');
    });

    // ---------------- 댓글 ----------------
    await _check('C2 댓글 작성 + 실시간 목록', () async {
      final got = Completer<String>();
      final sub = comments().watchComments(post!.id).listen((list) {
        if (list.any((c) => c.content == '셔츠 어디 거예요?') && !got.isCompleted) {
          got.complete('실시간 목록 ${list.length}개');
        }
      });
      try {
        await Future<void>.delayed(const Duration(seconds: 3));
        await comments().addComment(post!.id, '셔츠 어디 거예요?');
        final live = await got.future.timeout(const Duration(seconds: 10));
        final p = await posts().getPost(post!.id);
        return '$live, 댓글 수=${p.commentsCount}';
      } on TimeoutException {
        throw StateError('10초 안에 댓글이 실시간으로 오지 않음');
      } finally {
        await sub.cancel();
      }
    });

    await _expectError('C2 빈 댓글 차단', AppErrorType.invalidInput,
        () => comments().addComment(post!.id, '   '));

    // ---------------- 신고 · 옷 태그 ----------------
    await _check('C4 신고', () async {
      await reports().reportPost(post!.id, ReportReason.spam);
      final done = await reports().hasReported(post!.id);
      return '신고 저장됨=$done';
    });

    await _expectError('C4 중복 신고 차단', AppErrorType.duplicate,
        () => reports().reportPost(post!.id, ReportReason.spam));

    await _check('C5 옷 태그', () async {
      await clothingTags().replaceTags(post!.id, const [
        ClothingTag(name: '옥스포드 셔츠', brand: '무지', x: 0.5, y: 0.3),
      ]);
      final list = await clothingTags().fetchTags(post!.id);
      return '${list.length}개: ${list.map((t) => t.name).join(', ')}';
    });

    // ---------------- 랭킹 · 태그 검색 ----------------
    await _check('E2 인기 게시물 랭킹', () async {
      final list = await posts().fetchPopular(days: 7);
      if (!list.any((p) => p.id == post!.id)) throw StateError('랭킹에 내 글 없음');
      return '${list.length}개 조회';
    });

    await _check('F1 태그 검색 (#화이트셔츠)', () async {
      final list = await posts().fetchByTag('#화이트셔츠');
      if (!list.any((p) => p.id == post!.id)) throw StateError('검색 결과에 내 글 없음');
      return '${list.length}개 조회';
    });

    // ---------------- 정리 ----------------
    await _check('정리: 게시글 삭제 (사진·댓글·좋아요 함께)', () async {
      await posts().deletePost(post!);
      return '삭제 완료';
    });

    await _expectError('삭제된 글 조회 시 안내', AppErrorType.notFound,
        () => posts().getPost(post!.id));

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.where((r) => r.ok).length;
    return Scaffold(
      appBar: AppBar(title: const Text('백엔드 동작 확인')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _running ? null : _runAll,
                  child: Text(_running ? '확인 중...' : '전체 확인 실행'),
                ),
                const SizedBox(width: 16),
                if (_results.isNotEmpty) Text('통과 $passed / ${_results.length}'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = _results[i];
                return ListTile(
                  leading: Icon(r.ok ? Icons.check_circle : Icons.cancel,
                      color: r.ok ? Colors.green : Colors.red),
                  title: Text(r.name),
                  subtitle: SelectableText(r.detail),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
