import 'package:app/data/dummy_posts.dart';
import 'package:app/main.dart';
import 'package:app/utils/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('4. 상대 시간', () {
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

  test('더미 게시글은 10개이고 id가 모두 다르다', () {
    final posts = createDummyPosts();
    expect(posts.length, 10);
    expect(posts.map((p) => p.id).toSet().length, 10);
  });

  testWidgets('1. 피드에 더미 게시글 카드가 표시된다', (tester) async {
    await tester.pumpWidget(const MiniFeedApp());
    expect(find.text('초록고래'), findsOneWidget);
    expect(find.text('3분 전'), findsOneWidget);
  });

  testWidgets('2. 글쓰기에서 게시하면 피드 맨 위에 추가된다', (tester) async {
    await tester.pumpWidget(const MiniFeedApp());

    await tester.tap(find.byKey(const Key('compose_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nickname_field')), '테스트곰');
    await tester.enterText(find.byKey(const Key('content_field')), '새 글 테스트');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('새 글 테스트'), findsOneWidget);
    expect(find.text('방금 전'), findsOneWidget);
    final newTop = tester.getTopLeft(find.text('새 글 테스트')).dy;
    final oldTop = tester.getTopLeft(find.text('초록고래')).dy;
    expect(newTop, lessThan(oldTop)); // 기존 첫 글보다 위에 있다
  });

  testWidgets('글쓰기에서 내용이 비어 있으면 [게시] 버튼이 비활성화된다', (tester) async {
    await tester.pumpWidget(const MiniFeedApp());
    await tester.tap(find.byKey(const Key('compose_button')));
    await tester.pumpAndSettle();

    final button = tester.widget<TextButton>(find.byKey(const Key('submit_button')));
    expect(button.onPressed, isNull);
  });

  testWidgets('3. 게시글을 탭하면 상세 화면에 내용이 나온다', (tester) async {
    await tester.pumpWidget(const MiniFeedApp());
    final first = createDummyPosts().first;

    await tester.tap(find.text('초록고래'));
    await tester.pumpAndSettle();

    expect(find.text('게시글'), findsOneWidget); // 상세 화면 제목
    final content = tester.widget<SelectableText>(find.byKey(const Key('detail_content')));
    expect(content.data, first.content);
  });
}
