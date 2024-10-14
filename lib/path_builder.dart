import 'package:flutter/material.dart';



class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({super.key});

  @override
  _DrawingCanvasState createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<List<Offset>> strokes = [];
  List<Offset> currentStroke = [];
  List<List<Offset>> undoHistory = [];
  Color currentColor = Colors.black;
  double currentStrokeWidth = 3.0;
  final FocusNode _focusNode = FocusNode();

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
              onPanStart: (details) {
                setState(() {
                  currentStroke = [details.localPosition];
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  currentStroke.add(details.localPosition);
                });
              },
              onPanEnd: (details) {
                setState(() {
                  strokes.add(List.from(currentStroke));
                  currentStroke.clear();
                  undoHistory.clear();
                });
              },
              child: CustomPaint(
                painter: DrawingPainter(strokes, currentStroke, currentColor, currentStrokeWidth),
                size: Size.infinite,
              ),
            ),
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

  void _undo() {
    setState(() {
      if (strokes.isNotEmpty) {
        undoHistory.add(strokes.removeLast());
      }
    });
  }

  void _redo() {
    setState(() {
      if (undoHistory.isNotEmpty) {
        strokes.add(undoHistory.removeLast());
      }
    });
  }

  void _clearCanvas() {
    setState(() {
      strokes.clear();
      undoHistory.clear();
    });
  }

  void _exportDrawing() {
    // Implement export functionality here
    // For now, we'll just print a message
    print('Exporting drawing...');
  }

  void _changeColor() {
    // For simplicity, we'll just cycle through a few colors
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
    // Cycle through a few stroke widths
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

class DrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final double strokeWidth;

  DrawingPainter(this.strokes, this.currentStroke, this.strokeColor, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }

    for (int i = 0; i < currentStroke.length - 1; i++) {
      canvas.drawLine(currentStroke[i], currentStroke[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}