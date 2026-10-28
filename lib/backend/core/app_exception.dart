import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// [D2] 화면에 그대로 보여줄 수 있는 한국어 메시지를 담은 예외.
/// 프론트엔드는 `on AppException catch (e)` 로 받아 `e.message` 를 SnackBar 등에 표시하면 된다.
class AppException implements Exception {
  final AppErrorType type;
  final String message;
  final Object? cause;

  const AppException(this.type, this.message, [this.cause]);

  @override
  String toString() => 'AppException($type): $message';
}

enum AppErrorType {
  network,        // 네트워크 연결 문제
  notSignedIn,    // 로그인(익명) 전
  noProfile,      // 닉네임 설정 전
  duplicate,      // 중복 (닉네임, 좋아요, 신고)
  invalidInput,   // 글자 수 초과, 잘못된 링크 등
  forbidden,      // 권한 없음 (남의 글 수정 등)
  notFound,       // 삭제된 글 등
  unknown,
}

/// 모든 백엔드 호출을 감싸서 예외를 AppException 으로 바꿔준다.
Future<T> guard<T>(Future<T> Function() action, {String? duplicateMessage}) async {
  try {
    return await action().timeout(const Duration(seconds: 15));
  } on AppException {
    rethrow;
  } on SocketException catch (e) {
    throw AppException(AppErrorType.network, '네트워크에 연결할 수 없어요. 연결을 확인한 뒤 다시 시도해주세요.', e);
  } on TimeoutException catch (e) {
    throw AppException(AppErrorType.network, '응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요.', e);
  } on PostgrestException catch (e) {
    throw _fromPostgrest(e, duplicateMessage);
  } on StorageException catch (e) {
    throw AppException(AppErrorType.unknown, '사진을 처리하지 못했어요. (${e.message})', e);
  } on AuthException catch (e) {
    throw AppException(AppErrorType.notSignedIn, '로그인에 실패했어요. 잠시 후 다시 시도해주세요.', e);
  } catch (e) {
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('ClientException') || text.contains('Failed host lookup')) {
      throw AppException(AppErrorType.network, '네트워크에 연결할 수 없어요. 연결을 확인한 뒤 다시 시도해주세요.', e);
    }
    throw AppException(AppErrorType.unknown, '요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.', e);
  }
}

AppException _fromPostgrest(PostgrestException e, String? duplicateMessage) {
  switch (e.code) {
    case '23505': // unique 위반
      return AppException(AppErrorType.duplicate, duplicateMessage ?? '이미 처리된 요청이에요.', e);
    case '23503': // FK 위반 → 프로필(닉네임) 없음 또는 삭제된 글
      if (e.message.contains('profiles')) {
        return AppException(AppErrorType.noProfile, '닉네임을 먼저 설정해주세요.', e);
      }
      return AppException(AppErrorType.notFound, '삭제되었거나 존재하지 않는 게시글이에요.', e);
    case '23514': // check 제약 위반
    case '22001': // 글자 수 초과
      return AppException(AppErrorType.invalidInput, _checkMessage(e.message), e);
    case '42501': // RLS / 권한
      return AppException(AppErrorType.forbidden, '이 작업을 할 권한이 없어요.', e);
    case 'PGRST116': // single() 결과 없음
      return AppException(AppErrorType.notFound, '삭제되었거나 존재하지 않는 게시글이에요.', e);
    default:
      return AppException(AppErrorType.unknown, '요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.', e);
  }
}

String _checkMessage(String raw) {
  if (raw.contains('nickname') || raw.contains('character varying(10)')) return '닉네임은 1~10자로 입력해주세요.';
  if (raw.contains('content_length')) return '게시글 내용은 200자 이내로 입력해주세요.';
  if (raw.contains('purchase_url')) return '구매 링크는 http:// 또는 https:// 로 시작해야 해요.';
  if (raw.contains('tags_max')) return '태그는 최대 10개까지 넣을 수 있어요.';
  if (raw.contains('comment_length')) return '댓글은 1~300자로 입력해주세요.';
  if (raw.contains('report')) return '신고 사유를 확인해주세요.';
  if (raw.contains('tag_')) return '옷 태그 정보를 확인해주세요.';
  return '입력한 내용을 확인해주세요.';
}
