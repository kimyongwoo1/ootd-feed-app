/// 화면에 그대로 보여 줄 수 있는 한국어 오류 메시지를 담는 예외
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}
