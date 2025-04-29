import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class RemoteScreenPage extends StatefulWidget {
  final String serverUrl;
  final int fps;

  const RemoteScreenPage({Key? key, required this.serverUrl, required this.fps}) : super(key: key);

  @override
  _RemoteScreenPageState createState() => _RemoteScreenPageState();
}

class _RemoteScreenPageState extends State<RemoteScreenPage> {
  Uint8List? imageBytes;
  Size? imageRealSize;
  Size? imageDisplaySize;
  double scaleFactor = 1.0;
  Offset imageOffset = Offset.zero;
  bool showKeyboard = false;

  @override
  void initState() {
    super.initState();
    fetchScreenshot();
  }

  Future<void> fetchScreenshot() async {
    try {
      final response = await http.get(Uri.parse('${widget.serverUrl}/screenshot'));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          imageBytes = response.bodyBytes;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error: $e');
    }
    
    final delay = Duration(milliseconds: (1000 / widget.fps).round());
    Future.delayed(delay, fetchScreenshot);
  }

  Future<void> sendTouch(Offset localPosition) async {
    if (imageBytes == null || imageDisplaySize == null || imageRealSize == null) return;

    final dx = (localPosition.dx - imageOffset.dx) / scaleFactor;
    final dy = (localPosition.dy - imageOffset.dy) / scaleFactor;

    final x = dx.clamp(0, imageRealSize!.width);
    final y = dy.clamp(0, imageRealSize!.height);

    try {
      await http.post(
        Uri.parse('${widget.serverUrl}/touch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'x': x.toInt(), 'y': y.toInt()}),
      );
    } catch (e) {
      if (kDebugMode) print('Error sending touch: $e');
    }
  }

  Future<void> sendKeyPress(String key, {String action = 'press'}) async {
    try {
      await http.post(
        Uri.parse('${widget.serverUrl}/keypress'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'key': key, 'action': action}),
      );
    } catch (e) {
      if (kDebugMode) print('Error sending key press: $e');
    }
  }

  void _updateImageParams(Size realSize, Size displaySize) {
    scaleFactor = displaySize.width / realSize.width;
    imageOffset = Offset(
      (MediaQuery.of(context).size.width - displaySize.width) / 2,
      (MediaQuery.of(context).size.height - displaySize.height) / 2,
    );
    imageRealSize = realSize;
    imageDisplaySize = displaySize;
  }

  Widget _buildVirtualKeyboard() {
  return Container(
    color: Colors.grey[800],
    padding: EdgeInsets.all(8),
    child: Column(
      children: [
        // Перший рядок (цифри)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'].map((key) {
            return ElevatedButton(
              onPressed: () => sendKeyPress(key),
              child: Text(key),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        // Другий рядок (букви)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'].map((key) {
            return ElevatedButton(
              onPressed: () => sendKeyPress(key),
              child: Text(key),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        // Третій рядок (букви)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'].map((key) {
            return ElevatedButton(
              onPressed: () => sendKeyPress(key),
              child: Text(key),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        // Четвертий рядок (букви)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['z', 'x', 'c', 'v', 'b', 'n', 'm'].map((key) {
            return ElevatedButton(
              onPressed: () => sendKeyPress(key),
              child: Text(key),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        // Спеціальні клавіші
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => sendKeyPress(' '),  // Пробіл
              child: Text('Space'),
            ),
            ElevatedButton(
              onPressed: () => sendKeyPress('\n'),  // Enter
              child: Text('Enter'),
            ),
            ElevatedButton(
              onPressed: () => sendKeyPress('\b'),  // Backspace
              child: Text('Backspace'),
            ),
            ElevatedButton(
              onPressed: () => setState(() => showKeyboard = false),
              child: Icon(Icons.keyboard_hide),
            ),
          ],
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => showKeyboard = !showKeyboard),
        child: Icon(Icons.keyboard),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTapDown: (details) => sendTouch(details.localPosition),
              onPanUpdate: (details) => sendTouch(details.localPosition),
              child: Container(
                color: Colors.grey[300],
                child: Center(
                  child: imageBytes != null
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return Image.memory(
                              imageBytes!,
                              fit: BoxFit.contain,
                              frameBuilder: (context, child, frame, _) {
                                if (frame == null) return child;
                                
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  final renderBox = context.findRenderObject() as RenderBox?;
                                  if (renderBox != null && mounted) {
                                    final imageInfo = Image.memory(imageBytes!).image;
                                    imageInfo.resolve(ImageConfiguration()).addListener(
                                      ImageStreamListener((info, _) {
                                        if (mounted) {
                                          _updateImageParams(
                                            Size(
                                              info.image.width.toDouble(),
                                              info.image.height.toDouble(),
                                            ),
                                            renderBox.size,
                                          );
                                        }
                                      }),
                                    );
                                  }
                                });
                                return child;
                              },
                            );
                          },
                        )
                      : CircularProgressIndicator(),
                ),
              ),
            ),
          ),
          if (showKeyboard) _buildVirtualKeyboard(),
        ],
      ),
    );
  }
}



