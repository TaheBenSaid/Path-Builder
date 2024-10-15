import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

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
  File? backgroundImage; // Variable to store the background image

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
            if (backgroundImage != null) // Display background if selected
              Positioned.fill(
                child: SvgPicture.file(
                  backgroundImage!,
                  width: 50,
                  height: 50,
                ),
              ),
            GestureDetector(
              onTapDown: _handleTapDown,
              child: CustomPaint(
                painter: DrawingPainter(segments, currentSegment),
                size: Size.infinite,
              ),
            ),
            ...segments.expand((segment) => [
              _buildHandle(
                  segment.start, segment.startControl, true, segment),
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
                    onPressed: _importDrawing,
                    child: const Text('Import'),
                  ),
                  ElevatedButton(
                    onPressed: _startNewPath,
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

  Widget _buildHandle(
      Offset point, Offset control, bool isStart, SegmentElement segment) {
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

        if (isEraserActive) {
          segments.removeWhere((segment) =>
          segment.start.distanceSquared <= 100.0 ||
              segment.end.distanceSquared <= 100.0);
          isDrawing = false;
        } else {
          currentSegment = SegmentElement(
            color: currentColor,
            strokeWidth: currentStrokeWidth,
            start: startPoint!,
            end: endPoint!,
            startControl: startPoint!,
            endControl: endPoint!,
          );
          segments.add(currentSegment!);
          undoHistory.clear();

          if (segments.length > maxSegments) {
            segments.removeAt(0);
          }

          startPoint = endPoint;
          currentSegment = null;
        }
      }
    });
  }

  void _startNewPath() {
    setState(() {
      currentSegment = null;
      startPoint = null;
      endPoint = null;
      isDrawing = false;
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
      backgroundImage = null; // Clear background image when clearing canvas
    });
  }

  Future<void> _importDrawing() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['svg'], // Allow only SVG files
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        backgroundImage = File(result.files.first.path!); // Set background image
      });
    }
  }

  void _exportDrawing() async {
    final svgPath = StringBuffer();
    svgPath.write(
        '<svg xmlns="http://www.w3.org/2000/svg" width="1800" height="1600">\n');

    if (segments.isNotEmpty) {
      svgPath
          .write('<path d="M${segments[0].start.dx},${segments[0].start.dy} ');

      for (int i = 0; i < segments.length; i++) {
        if (segments[i].startControl == null) {
          if (segments[i].endControl == null) {
            svgPath.write('L${segments[i].end.dx},${segments[i].end.dy} ');
          } else {
            svgPath.write(
                'Q${segments[i].endControl.dx},${segments[i].endControl.dy},${segments[i].end.dx},${segments[i].end.dy} ');
          }
        } else {
          if (segments[i].endControl == null) {
            svgPath.write(
                'Q${segments[i].startControl.dx},${segments[i].startControl.dy},${segments[i].end.dx},${segments[i].end.dy} ');
          } else {
            svgPath.write(
                'C${segments[i].startControl.dx},${segments[i].startControl.dy},${segments[i].endControl.dx},${segments[i].endControl.dy},${segments[i].end.dx},${segments[i].end.dy} ');
          }
        }
      }

      svgPath.write('" stroke="black" fill="none" stroke-width="4"/>\n');
    }

    svgPath.write('</svg>');

    final directory = await getApplicationDocumentsDirectory();
    final svgPathFile = '${directory.path}/exported_shape.svg';
    final file = await File(svgPathFile).writeAsString(svgPath.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SVG shape exported to ${file.path}')),
    );
  }

  void _changeColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: currentColor,
            onColorChanged: (color) {
              setState(() {
                currentColor = color;
              });
            },
          ),
        ),
        actions: [
          ElevatedButton(
            child: const Text('Done'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _changeStrokeWidth() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select stroke width'),
        content: SingleChildScrollView(
          child: Slider(
            value: currentStrokeWidth,
            min: 1.0,
            max: 10.0,
            divisions: 9,
            onChanged: (value) {
              setState(() {
                currentStrokeWidth = value;
              });
            },
          ),
        ),
        actions: [
          ElevatedButton(
            child: const Text('Done'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _toggleEraser() {
    setState(() {
      isEraserActive = !isEraserActive;
    });
  }
}

class SegmentElement {
  Color color;
  double strokeWidth;
  Offset start;
  Offset end;
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
}

class DrawingPainter extends CustomPainter {
  final List<SegmentElement> segments;
  final SegmentElement? currentSegment;

  DrawingPainter(this.segments, this.currentSegment);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final segment in segments) {
      paint.color = segment.color;
      paint.strokeWidth = segment.strokeWidth;

      if (segment.startControl == segment.start &&
          segment.endControl == segment.end) {
        canvas.drawLine(segment.start, segment.end, paint);
      } else {
        final path = Path();
        path.moveTo(segment.start.dx, segment.start.dy);
        path.cubicTo(
          segment.startControl.dx,
          segment.startControl.dy,
          segment.endControl.dx,
          segment.endControl.dy,
          segment.end.dx,
          segment.end.dy,
        );
        canvas.drawPath(path, paint);
      }
    }

    if (currentSegment != null) {
      paint.color = currentSegment!.color;
      paint.strokeWidth = currentSegment!.strokeWidth;

      final path = Path();
      path.moveTo(currentSegment!.start.dx, currentSegment!.start.dy);
      path.cubicTo(
        currentSegment!.startControl.dx,
        currentSegment!.startControl.dy,
        currentSegment!.endControl.dx,
        currentSegment!.endControl.dy,
        currentSegment!.end.dx,
        currentSegment!.end.dy,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
