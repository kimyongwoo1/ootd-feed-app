/// [B4] 서버 시간(created_at)을 '방금 전', '5분 전', '2시간 전' 등으로 변환
String relativeTime(DateTime createdAt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(createdAt.toLocal());
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  final t = createdAt.toLocal();
  return '${t.year}.${t.month}.${t.day}';
}
