import 'package:app/main.dart';
import 'package:app/models/post.dart';
import 'package:app/utils/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_post_repository.dart';

void main() {
  group('상대 시간', () {
    final now = DateTime(2026, 11, 3, 12, 0);
    test('30초 전 → 방금 전', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 30)), now: now), '방금 전');
    });
    test('5분 전', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5분 전');
    });
    test('2시간 전', () {
      expect(relativeTime(now.subtract(const Duration(hours: 2)), now: now), '2시간 전');
    });
    test('3일 전', () {
      expect(relativeTime(now.subtract(const Duration(days: 3)), now: now), '3일 전');
    });
    test('7일 이상은 날짜로 표시', () {
      expect(relativeTime(DateTime(2026, 10, 20, 9), now: now), '2026.10.20');
    });
  });

  test('서버 JSON → Post 변환, 내 글 구분', () {
    final json = {
      'id': 'a1',
      'author_id': 'me',
      'nickname': '초록고래',
      'content': '안녕',
      'created_at': '2026-11-03T03:00:00+00:00',
    };
    expect(Post.fromJson(json, myUserId: 'me').isMine, isTrue);
    expect(Post.fromJson(json, myUserId: 'other').isMine, isFalse);
    expect(Post.fromJson(json).createdAt.isUtc, isFalse); // 기기 시간대로 변환
  });

  testWidgets('서버에서 불러온 글이 피드에 표시된다', (tester) async {
    await tester.pumpWidget(MiniFeedApp(repository: FakePostRepository()));
    await tester.pumpAndSettle();
    expect(find.text('초록고래'), findsOneWidget);
    expect(find.text('3분 전'), findsOneWidget);
    expect(find.byKey(const Key('anon_id')), findsOneWidget);
  });

  testWidgets('글쓰기 → 서버 저장 → 피드 맨 위에 추가', (tester) async {
    await tester.pumpWidget(MiniFeedApp(repository: FakePostRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('compose_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('content_field')), '새 글 테스트');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('새 글 테스트'), findsOneWidget);
    expect(find.text('내 글'), findsOneWidget);
    final newTop = tester.getTopLeft(find.text('새 글 테스트')).dy;
    final oldTop = tester.getTopLeft(find.text('초록고래')).dy;
    expect(newTop, lessThan(oldTop));
  });

  testWidgets('내용이 비어 있으면 [게시] 버튼이 비활성화된다', (tester) async {
    await tester.pumpWidget(MiniFeedApp(repository: FakePostRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose_button')));
    await tester.pumpAndSettle();

    final button = tester.widget<TextButton>(find.byKey(const Key('submit_button')));
    expect(button.onPressed, isNull);
  });

  testWidgets('작성 실패 시 안내가 뜨고 입력 내용은 남아 있다', (tester) async {
    final repo = FakePostRepository(failCreate: true);
    await tester.pumpWidget(MiniFeedApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('compose_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('content_field')), '실패할 글');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pump(); // 스낵바 표시 시작
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('게시하지 못했어요'), findsOneWidget);
    expect(find.text('실패할 글'), findsOneWidget); // 글쓰기 화면에 그대로
    await tester.pump(const Duration(seconds: 5)); // 스낵바가 사라질 때까지
    await tester.pumpAndSettle();
  });

  testWidgets('처음 불러오기 실패 → 오류 화면 → 다시 시도로 복구', (tester) async {
    final repo = FakePostRepository(failFetch: true);
    await tester.pumpWidget(MiniFeedApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error_message')), findsOneWidget);

    repo.failFetch = false;
    await tester.tap(find.byKey(const Key('retry_button')));
    await tester.pumpAndSettle();
    expect(find.text('초록고래'), findsOneWidget);
  });

  test('서버 JSON의 좋아요·댓글 수와 내 좋아요 여부', () {
    final json = {
      'id': 'a1',
      'author_id': 'x',
      'nickname': '초록고래',
      'content': '안녕',
      'created_at': '2026-11-03T03:00:00+00:00',
      'likes_count': 5,
      'comments_count': 2,
      'mini_post_likes': [
        {'user_id': 'me'}
      ],
    };
    final p = Post.fromJson(json, myUserId: 'me');
    expect(p.likesCount, 5);
    expect(p.commentsCount, 2);
    expect(p.likedByMe, isTrue);
    expect(Post.fromJson({...json, 'mini_post_likes': []}).likedByMe, isFalse);
  });

  testWidgets('MP3 좋아요: 누르면 1, 다시 누르면 0 (중복 없음)', (tester) async {
    final repo = FakePostRepository();
    await tester.pumpWidget(MiniFeedApp(repository: repo));
    await tester.pumpAndSettle();

    Text count() => tester.widget<Text>(find.byKey(const Key('likes_count_p0')));
    expect(count().data, '0');

    await tester.tap(find.byKey(const Key('like_p0')));
    await tester.pumpAndSettle();
    expect(count().data, '1');
    expect(repo.likedByMe, {'p0'});

    await tester.tap(find.byKey(const Key('like_p0')));
    await tester.pumpAndSettle();
    expect(count().data, '0');
    expect(repo.likedByMe, isEmpty);
  });

  testWidgets('MP3 댓글: 상세에서 작성하면 목록과 피드 댓글 수에 반영', (tester) async {
    final repo = FakePostRepository();
    await tester.pumpWidget(MiniFeedApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('초록고래'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('comment_nickname')), '기기B');
    await tester.enterText(find.byKey(const Key('comment_field')), '좋은 코디네요');
    await tester.pump();
    await tester.tap(find.byKey(const Key('comment_send')));
    await tester.pumpAndSettle();

    expect(find.text('좋은 코디네요'), findsOneWidget);
    expect(find.text('댓글 1'), findsOneWidget);
    expect(repo.comments['p0']!.single.nickname, '기기B');

    await tester.pageBack();
    await tester.pumpAndSettle();
    final c = tester.widget<Text>(find.byKey(const Key('comments_count_p0')));
    expect(c.data, '1');
  });

  testWidgets('MP3 신고: 사유 선택 → 서버 기록 → 내 피드에서 숨김', (tester) async {
    final repo = FakePostRepository();
    await tester.pumpWidget(MiniFeedApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('새벽코더'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_button')));
    await tester.pumpAndSettle();

    // 사유를 고르기 전에는 [신고하기] 비활성
    expect(tester.widget<FilledButton>(find.byKey(const Key('report_submit'))).onPressed,
        isNull);
    await tester.ensureVisible(find.byKey(const Key('reason_spam')));
    await tester.tap(find.byKey(const Key('reason_spam')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('report_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_submit')));
    await tester.pumpAndSettle();

    expect(repo.reports.single.$1, 'p1');
    expect(repo.reports.single.$2.code, 'spam');
    expect(find.text('새벽코더'), findsNothing); // 피드에서 빠짐
    expect(find.byKey(const Key('report_done')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('게시글을 탭하면 상세 화면이 열린다', (tester) async {
    await tester.pumpWidget(MiniFeedApp(repository: FakePostRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('초록고래'));
    await tester.pumpAndSettle();
    expect(find.text('게시글'), findsOneWidget);
  });
}
