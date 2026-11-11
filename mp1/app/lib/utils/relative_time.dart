/// 작성 시각을 '방금 전', '5분 전', '2시간 전', '3일 전' 처럼 표시한다.
/// 7일이 넘으면 날짜(2026.11.03)로 표시한다.
String relativeTime(DateTime time, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(time);
  if (d.inMinutes < 1) return '방금 전';
  if (d.inHours < 1) return '${d.inMinutes}분 전';
  if (d.inDays < 1) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return formatDate(time);
}

/// 상세 화면에 보여줄 정확한 작성 시각 (2026.11.03 14:05)
String formatDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${formatDate(t)} ${two(t.hour)}:${two(t.minute)}';
}

String formatDate(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}.${two(t.month)}.${two(t.day)}';
}
