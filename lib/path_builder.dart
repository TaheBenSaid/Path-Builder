import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
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
  bool isEraserActive = false; // Flag for eraser tool
  final int maxSegments = 100; // Limit on the number of segments

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
          IconButton(
            icon: Icon(
              isEraserActive ? Icons.brush : Icons.delete,
              color: isEraserActive ? Colors.red : null,
            ),
            onPressed: _toggleEraser,
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
                  ElevatedButton(
                    onPressed: _startNewPath, // New button for starting a new path
                    child: const Text('New Path'),
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

        // Check if eraser is active
        if (isEraserActive) {
          segments.removeWhere((segment) =>
          segment.start.distanceSquared <= 100.0 || segment.end.distanceSquared <= 100.0);
          isDrawing = false; // Reset drawing state after erasing
        } else {
          currentSegment = SegmentElement(
            color: currentColor,
            strokeWidth: currentStrokeWidth,
            start: startPoint!,
            end: endPoint!,
            // Initialize control points to be equal to start and end points for a straight line
            startControl: startPoint!,
            endControl: endPoint!,
          );
          segments.add(currentSegment!);
          undoHistory.clear();

          // Limit the number of segments
          if (segments.length > maxSegments) {
            segments.removeAt(0); // Remove the oldest segment
          }

          startPoint = endPoint;
          currentSegment = null; // Reset the current segment
        }
      }
    });
  }

  void _startNewPath() {
    setState(() {
      currentSegment = null; // Clear the current segment
      startPoint = null; // Reset starting point
      endPoint = null; // Reset ending point
      isDrawing = false; // Reset drawing state
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
    try {
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
        const SnackBar(content: Text('Drawing saved to gallery')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving drawing')),
      );
    }
  }

  void _changeColor() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: currentColor,
              onColorChanged: (Color color) {
                setState(() {
                  currentColor = color;
                });
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ),
        );
      },
    );
  }

  void _changeStrokeWidth() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Stroke Width'),
          content: SingleChildScrollView(
            child: Slider(
              value: currentStrokeWidth,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              label: currentStrokeWidth.toString(),
              onChanged: (double value) {
                setState(() {
                  currentStrokeWidth = value;
                });
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _toggleEraser() {
    setState(() {
      isEraserActive = !isEraserActive;
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
