import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';

class RemoteScreenPage extends StatefulWidget {
  final String serverUrl;
  final int fps;

  const RemoteScreenPage({Key? key, required this.serverUrl, required this.fps}) : super(key: key);

  @override
  _RemoteScreenPageState createState() => _RemoteScreenPageState();
}

class _RemoteScreenPageState extends State<RemoteScreenPage> {
  Uint8List? _currentImage;
  Size? _imageRealSize;
  Size? _imageDisplaySize;
  bool _isFirstLoad = true;
  Timer? _updateTimer;
  final _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startImageUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startImageUpdates() {
    // Перше завантаження зображення
    _fetchImage().then((_) {
      if (mounted) setState(() => _isFirstLoad = false);
    });

    // Періодичне оновлення
    _updateTimer = Timer.periodic(
      Duration(milliseconds: (1000 / widget.fps).round()),
      (_) => _fetchImage(),
    );
  }

  Future<void> _fetchImage() async {
    try {
      final response = await http.get(Uri.parse('${widget.serverUrl}/screenshot'));
      if (response.statusCode == 200 && mounted) {
        setState(() => _currentImage = response.bodyBytes);
      }
    } catch (e) {
      if (kDebugMode) print('Image fetch error: $e');
    }
  }

  Future<void> _sendTouch(Offset localPosition) async {
    if (_currentImage == null || _imageDisplaySize == null || _imageRealSize == null) return;

    // Отримуємо розмір фактично відображеного зображення
    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final imagePosition = renderBox.localToGlobal(Offset.zero);
    final imageSize = renderBox.size;

    // Обчислюємо відносні координати всередині зображення
    final relativeX = (localPosition.dx - imagePosition.dx).clamp(0, imageSize.width);
    final relativeY = (localPosition.dy - imagePosition.dy).clamp(0, imageSize.height);

    // Масштабуємо до реального розміру екрана ПК
    final scaleX = _imageRealSize!.width / imageSize.width;
    final scaleY = _imageRealSize!.height / imageSize.height;
    
    final x = (relativeX * scaleX).toInt().clamp(0, _imageRealSize!.width.toInt());
    final y = (relativeY * scaleY).toInt().clamp(0, _imageRealSize!.height.toInt());

    if (kDebugMode) {
      print('Local: ${localPosition.dx}, ${localPosition.dy}');
      print('Image pos: ${imagePosition.dx}, ${imagePosition.dy}');
      print('Image size: ${imageSize.width}x${imageSize.height}');
      print('Scaled: $x, $y');
    }

    try {
      await http.post(
        Uri.parse('${widget.serverUrl}/touch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'x': x, 'y': y}),
      );
    } catch (e) {
      if (kDebugMode) print('Touch error: $e');
    }
  }

 // У файлі remote_screen_page.dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[900],
    body: GestureDetector(
      onTapDown: (details) => _sendTouch(details.globalPosition),
      onPanUpdate: (details) => _sendTouch(details.globalPosition),
      child: Container(
        color: Colors.grey[900],
        child: Center(
          child: _isFirstLoad
              ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey),
                )
              : _currentImage != null
                  ? _buildImageWidget()
                  : Text(
                      'No image available',
                      style: TextStyle(color: Colors.white70),
                    ),
        ),
      ),
    ),
  );
}

  Widget _buildImageWidget() {
    return LayoutBuilder(
      key: _imageKey,
      builder: (context, constraints) {
        return Image.memory(
          _currentImage!,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, _) {
            if (frame == null) return child;
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox != null && mounted) {
                final imageInfo = Image.memory(_currentImage!).image;
                imageInfo.resolve(ImageConfiguration()).addListener(
                  ImageStreamListener((info, _) {
                    if (mounted) {
                      setState(() {
                        _imageRealSize = Size(
                          info.image.width.toDouble(),
                          info.image.height.toDouble(),
                        );
                        _imageDisplaySize = renderBox.size;
                      });
                    }
                  }),
                );
              }
            });
            return child;
          },
        );
      },
    );
  }
}