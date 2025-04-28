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

  void _updateImageParams(Size realSize, Size displaySize) {
    scaleFactor = displaySize.width / realSize.width;
    imageOffset = Offset(
      (MediaQuery.of(context).size.width - displaySize.width) / 2,
      (MediaQuery.of(context).size.height - displaySize.height) / 2,
    );
    imageRealSize = realSize;
    imageDisplaySize = displaySize;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Видалено AppBar
      body: GestureDetector(
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
    );
  }
}