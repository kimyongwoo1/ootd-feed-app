import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_exception.dart';
import '../core/supabase_config.dart';
import '../models/profile.dart';
import 'auth_repository.dart';

/// [A2] 닉네임 설정
class ProfileRepository {
  final SupabaseClient _db;
  final AuthRepository _auth;
  ProfileRepository({SupabaseClient? client, AuthRepository? auth})
      : _db = client ?? SupabaseConfig.client,
        _auth = auth ?? AuthRepository(client);

  /// 내 프로필. 닉네임을 아직 설정하지 않았으면 null → 닉네임 설정 화면으로 이동
  Future<Profile?> getMyProfile() => guard(() async {
        final uid = _auth.requireUserId();
        final row = await _db.from('profiles').select().eq('id', uid).maybeSingle();
        return row == null ? null : Profile.fromJson(row);
      });

  /// 닉네임 사용 가능 여부 (입력 중 미리 확인용, 대소문자 구분 없음)
  Future<bool> isNicknameAvailable(String nickname) => guard(() async {
        final result = await _db.rpc('is_nickname_available', params: {'p_nickname': nickname.trim()});
        return result == true;
      });

  /// 닉네임 설정 또는 변경 (1~10자, 중복 불가는 DB 제약조건이 보장)
  Future<Profile> setNickname(String nickname) => guard(() async {
        final uid = _auth.requireUserId();
        final name = nickname.trim();
        if (name.isEmpty || name.length > 10) {
          throw const AppException(AppErrorType.invalidInput, '닉네임은 1~10자로 입력해주세요.');
        }
        final exists = await _db.from('profiles').select('id').eq('id', uid).maybeSingle();
        final row = exists == null
            ? await _db.from('profiles').insert({'id': uid, 'nickname': name}).select().single()
            : await _db.from('profiles').update({'nickname': name}).eq('id', uid).select().single();
        return Profile.fromJson(row);
      }, duplicateMessage: '이미 사용 중인 닉네임이에요.');
}
