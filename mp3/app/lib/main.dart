import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/feed_screen.dart';
import 'services/post_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PostRepository? repository;
  String? configError;
  try {
    // 설정 키는 코드에 쓰지 않고 .env 에서 읽는다
    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final key = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
        dotenv.env['SUPABASE_ANON_KEY'] ??
        '';
    if (url.isEmpty || key.isEmpty || url.contains('xxxx')) {
      throw StateError('.env 에 SUPABASE_URL 과 SUPABASE_PUBLISHABLE_KEY 를 채워 주세요.');
    }
    await Supabase.initialize(url: url, publishableKey: key);
    repository = SupabasePostRepository(Supabase.instance.client);
  } catch (e) {
    configError = '서버 설정을 불러오지 못했어요.\n$e';
  }

  runApp(MiniFeedApp(repository: repository, configError: configError));
}

class MiniFeedApp extends StatelessWidget {
  final PostRepository? repository;
  final String? configError;

  const MiniFeedApp({super.key, this.repository, this.configError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '미니 피드',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      // Chrome 에서도 마우스로 끌어서 '당겨서 새로고침'이 되도록
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      home: repository != null
          ? FeedScreen(repository: repository!)
          : _ConfigErrorScreen(message: configError ?? '알 수 없는 오류'),
    );
  }
}

/// .env 가 없거나 비어 있을 때 보여 주는 화면
class _ConfigErrorScreen extends StatelessWidget {
  final String message;
  const _ConfigErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_outlined, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('README의 "백엔드 설정 절차"를 확인해 주세요.',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
