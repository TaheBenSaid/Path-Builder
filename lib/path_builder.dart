import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Custom Drawing App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DrawingCanvas(),
    );
  }
}

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key});

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<SegmentElement> segments = [];
  SegmentElement? currentSegment;
  List<SegmentElement> undoHistory = [];
  Color currentColor = Colors.black;
  double currentStrokeWidth = 3.0;
  final FocusNode _focusNode = FocusNode();
  Offset? startPoint;
  Offset? endPoint;
  bool isDrawing = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Custom Drawing App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: _changeColor,
          ),
          IconButton(
            icon: const Icon(Icons.line_weight),
            onPressed: _changeStrokeWidth,
          ),
        ],
      ),
      body: Focus(
        focusNode: _focusNode,
        child: Stack(
          children: [
            GestureDetector(
              onTapDown: _handleTapDown,
              child: CustomPaint(
                painter: DrawingPainter(segments, currentSegment),
                size: Size.infinite,
              ),
            ),
            ...segments.expand((segment) => [
              _buildHandle(segment.start, segment.startControl, true, segment),
              _buildHandle(segment.end, segment.endControl, false, segment),
            ]),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _undo,
                    child: const Text('Undo'),
                  ),
                  ElevatedButton(
                    onPressed: _redo,
                    child: const Text('Redo'),
                  ),
                  ElevatedButton(
                    onPressed: _clearCanvas,
                    child: const Text('Clear'),
                  ),
                  ElevatedButton(
                    onPressed: _exportDrawing,
                    child: const Text('Export'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(Offset point, Offset control, bool isStart, SegmentElement segment) {
    return Positioned(
      left: control.dx - 5,
      top: control.dy - 5,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            if (isStart) {
              segment.startControl = segment.startControl + details.delta;
            } else {
              segment.endControl = segment.endControl + details.delta;
            }
          });
        },
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      if (!isDrawing) {
        startPoint = details.localPosition;
        isDrawing = true;
      } else {
        endPoint = details.localPosition;
        currentSegment = SegmentElement(
          color: currentColor,
          strokeWidth: currentStrokeWidth,
          start: startPoint!,
          end: endPoint!,
          startControl: startPoint! + const Offset(50, -50),
          endControl: endPoint! + const Offset(-50, -50),
        );
        segments.add(currentSegment!);
        undoHistory.clear();
        startPoint = endPoint;
        currentSegment = null;
      }
    });
  }

  void _undo() {
    setState(() {
      if (segments.isNotEmpty) {
        undoHistory.add(segments.removeLast());
      }
      if (segments.isEmpty) {
        isDrawing = false;
        startPoint = null;
      } else {
        startPoint = segments.last.end;
      }
    });
  }

  void _redo() {
    setState(() {
      if (undoHistory.isNotEmpty) {
        segments.add(undoHistory.removeLast());
        startPoint = segments.last.end;
        isDrawing = true;
      }
    });
  }

  void _clearCanvas() {
    setState(() {
      segments.clear();
      undoHistory.clear();
      currentSegment = null;
      startPoint = null;
      endPoint = null;
      isDrawing = false;
    });
  }

  void _exportDrawing() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = MediaQuery.of(context).size;

    final painter = DrawingPainter(segments, null);
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/drawing.png');
    await file.writeAsBytes(pngBytes!.buffer.asUint8List());

    await GallerySaver.saveImage(file.path);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Drawing saved to gallery')),
    );
  }

  void _changeColor() {
    setState(() {
      if (currentColor == Colors.black) {
        currentColor = Colors.red;
      } else if (currentColor == Colors.red) {
        currentColor = Colors.blue;
      } else if (currentColor == Colors.blue) {
        currentColor = Colors.green;
      } else {
        currentColor = Colors.black;
      }
    });
  }

  void _changeStrokeWidth() {
    setState(() {
      if (currentStrokeWidth == 3.0) {
        currentStrokeWidth = 5.0;
      } else if (currentStrokeWidth == 5.0) {
        currentStrokeWidth = 8.0;
      } else {
        currentStrokeWidth = 3.0;
      }
    });
  }
}

class SegmentElement {
  final Color color;
  final double strokeWidth;
  final Offset start;
  final Offset end;
  Offset startControl;
  Offset endControl;

  SegmentElement({
    required this.color,
    required this.strokeWidth,
    required this.start,
    required this.end,
    required this.startControl,
    required this.endControl,
  });

  void draw(Canvas canvas) {
    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    Path path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        startControl.dx, startControl.dy,
        endControl.dx, endControl.dy,
        end.dx, end.dy,
      );

    canvas.drawPath(path, paint);

    // Draw control points and handles for visualization
    Paint controlPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1;
    canvas.drawCircle(startControl, 4, controlPaint);
    canvas.drawCircle(endControl, 4, controlPaint);
    canvas.drawLine(start, startControl, controlPaint);
    canvas.drawLine(end, endControl, controlPaint);
  }
}

class DrawingPainter extends CustomPainter {
  final List<SegmentElement> segments;
  final SegmentElement? currentSegment;

  DrawingPainter(this.segments, this.currentSegment);

  @override
  void paint(Canvas canvas, Size size) {
    for (var segment in segments) {
      segment.draw(canvas);
    }
    if (currentSegment != null) {
      currentSegment!.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}