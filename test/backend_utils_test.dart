// test/backend_utils_test.dart  –  실행: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:ootd_feed/backend/backend.dart';

void main() {
  group('T6 상대 시간 표시 (B4)', () {
    final now = DateTime(2026, 11, 2, 12, 0);
    test('30초 전 → 방금 전', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 30)), now: now), '방금 전');
    });
    test('5분 전', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5분 전');
    });
    test('10일 전 → 날짜로 표시', () {
      expect(relativeTime(DateTime(2026, 10, 23, 12), now: now), '2026.10.23');
    });
  });

  group('T17 AI 추천 태그 정리 (F1)', () {
    test('# 자동 추가, 공백·중복 제거', () {
      expect(PostRepository.normalizeTags([' 화이트셔츠', '#화이트셔츠', '#블루 데님']),
          ['#화이트셔츠', '#블루데님']);
    });
    test('태그는 최대 10개까지만 저장', () {
      final tags = List.generate(11, (i) => '태그$i');
      expect(PostRepository.normalizeTags(tags).length, 10);
    });
  });
}
