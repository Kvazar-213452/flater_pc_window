import 'package:flutter/material.dart';
import 'remote_screen_page.dart'; // імпортуй свій екран

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RemoteScreenPage(), // тут твій екран
    );
  }
}
