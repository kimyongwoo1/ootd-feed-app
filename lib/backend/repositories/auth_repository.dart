import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../core/supabase_config.dart';

/// [A1] 익명 로그인
class AuthRepository {
  final SupabaseClient _db;
  AuthRepository([SupabaseClient? client]) : _db = client ?? SupabaseConfig.client;

  /// 현재 로그인한 사용자의 익명 UID (로그인 전이면 null)
  String? get currentUserId => _db.auth.currentUser?.id;

  /// 앱 시작 시 호출. 이미 세션이 있으면 그대로 쓰고, 없으면 익명 로그인한다.
  /// 이메일·전화번호 등 개인정보는 받지 않는다.
  Future<String> ensureSignedIn() => guard(() async {
        final existing = _db.auth.currentUser;
        if (existing != null) return existing.id;
        final res = await _db.auth.signInAnonymously();
        final user = res.user;
        if (user == null) {
          throw const AppException(AppErrorType.notSignedIn, '로그인에 실패했어요. 잠시 후 다시 시도해주세요.');
        }
        return user.id;
      });

  /// 다른 화면에서 로그인 상태가 필요할 때 사용
  String requireUserId() {
    final id = currentUserId;
    if (id == null) {
      throw const AppException(AppErrorType.notSignedIn, '로그인이 필요해요. 앱을 다시 실행해주세요.');
    }
    return id;
  }
}
