import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 앱 시작 시 한 번 호출: `await SupabaseConfig.init();`
/// URL과 키는 .env 에서 읽는다 (비기능 요구사항: API 키 하드코딩 금지).
class SupabaseConfig {
  static const imageBucket = 'ootd-images';

  static Future<void> init() async {
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'];
    // 대시보드의 publishable 키(sb_publishable_...) 또는 예전 anon 키 둘 다 사용 가능
    final key = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];
    if (url == null || url.isEmpty || key == null || key.isEmpty) {
      throw StateError('.env 에 SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY 가 없습니다.');
    }
    await Supabase.initialize(url: url, publishableKey: key);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
