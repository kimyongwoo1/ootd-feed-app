/// 신고 사유 — 서버 `mini_reports.reason` 의 허용 값과 같아야 한다 (GUIDELINES.md 1장)
enum ReportReason {
  spam('spam', '스팸·광고', '홍보 글, 같은 내용 반복, 외부 링크 유도'),
  abuse('abuse', '욕설·혐오·괴롭힘', '특정인·집단을 비하하거나 공격하는 표현'),
  sexual('sexual', '음란·선정적인 내용', '성적인 사진·표현'),
  privacy('privacy', '개인정보 노출', '실명, 연락처, 얼굴, 학교·주소 등'),
  other('other', '기타', '위에 없는 가이드라인 위반');

  const ReportReason(this.code, this.label, this.description);

  /// 서버에 저장하는 값
  final String code;

  /// 화면에 보여 줄 이름
  final String label;
  final String description;
}
