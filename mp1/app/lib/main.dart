import 'package:flutter/material.dart';

import 'screens/feed_screen.dart';

void main() {
  runApp(const MiniFeedApp());
}

class MiniFeedApp extends StatelessWidget {
  const MiniFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '미니 피드',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const FeedScreen(),
    );
  }
}
