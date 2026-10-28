/// [C4] 신고 사유 (DB 의 report_reason 제약과 같은 값)
enum ReportReason {
  sexual('sexual', '선정적인 내용'),
  violence('violence', '폭력적인 내용'),
  spam('spam', '스팸·광고'),
  privacy('privacy', '개인정보 노출'),
  hate('hate', '혐오·비하 표현'),
  other('other', '기타');

  final String code;
  final String label;   // 화면에 보여줄 문구
  const ReportReason(this.code, this.label);
}
