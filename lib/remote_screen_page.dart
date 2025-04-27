import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';

class RemoteScreenPage extends StatefulWidget {
  @override
  _RemoteScreenPageState createState() => _RemoteScreenPageState();
}

class _RemoteScreenPageState extends State<RemoteScreenPage> {
  Uint8List? imageBytes;
  final String serverUrl = 'http://192.168.0.101:5000'; // <-- заміни на свою IP адресу
  double screenWidth = 0;
  double screenHeight = 0;
  double serverScreenWidth = 1920; // Наприклад, екран комп'ютера (можна змінити)
  double serverScreenHeight = 1080; // Наприклад, екран комп'ютера (можна змінити)

  @override
  void initState() {
    super.initState();
    fetchScreenshot();
  }

  // Оновлюємо кадри кожні 33 мс (30 FPS)
  void fetchScreenshot() async {
    while (true) {
      try {
        final response = await http.get(Uri.parse('$serverUrl/screenshot'));
        if (response.statusCode == 200) {
          setState(() {
            imageBytes = response.bodyBytes;
          });
        }
      } catch (e) {
        print('Error: $e');
      }
      await Future.delayed(Duration(milliseconds: 33)); // 30 fps
    }
  }

  // Обробка кліків з масштабуванням
  void sendTouch(Offset position, String action) async {
    if (imageBytes == null) return;

    // Визначаємо розміри екрана на мобільному пристрої
    double screenWidthPhone = MediaQuery.of(context).size.width;
    double screenHeightPhone = MediaQuery.of(context).size.height;

    // Розміри зображення на екрані телефону
    double imgWidth = screenWidth;
    double imgHeight = screenHeight;

    // Масштабування координат для кліка на екрані
    double scaleX = imgWidth / screenWidthPhone;
    double scaleY = imgHeight / screenHeightPhone;

    // Масштабування для екрану сервера
    double serverScaleX = serverScreenWidth / imgWidth;
    double serverScaleY = serverScreenHeight / imgHeight;

    // Коригуємо координати для видалення відступу
    final adjustedX = position.dx - 50; // Віднімаємо 50px від лівого відступу
    final adjustedY = position.dy - 50; // Віднімаємо 50px від верхнього відступу

    // Обчислюємо масштабовані координати для сервера
    final dx = ((adjustedX * scaleX) * serverScaleX).toInt();
    final dy = ((adjustedY * scaleY) * serverScaleY).toInt();

    print("Original: (${position.dx}, ${position.dy})");
    print("Adjusted: ($adjustedX, $adjustedY)");
    print("Scaled: ($dx, $dy)");

    // Відправка запиту на сервер для обробки кліка
    await http.post(
      Uri.parse('$serverUrl/touch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'x': dx,
        'y': dy,
        'action': action
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          sendTouch(details.localPosition, 'move');
        },
        onTapDown: (details) {
          sendTouch(details.localPosition, 'click');
        },
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Оновлюємо розміри екрана телефону
              screenWidth = constraints.maxWidth;
              screenHeight = constraints.maxHeight;

              return imageBytes != null
                  ? Image.memory(imageBytes!)
                  : Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }
}
