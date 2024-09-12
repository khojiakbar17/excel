part of excel;

class Drawing {
  final Excel _excel;
  final String _drawingId;
  List<DrawingElement> _elements = [];

  Drawing._(this._excel, this._drawingId, {List<DrawingElement>? elements}) {
    if (elements != null) {
      _elements = List<DrawingElement>.from(elements);
    }
  }

  Drawing._clone(Excel excel, String drawingId, Drawing oldDrawing)
      : this._(excel, drawingId, elements: oldDrawing._elements);

  /// Adds an element (e.g., shape, picture, chart) to the drawing.
  void addElement(DrawingElement element) {
    _elements.add(element);
  }

  /// Removes an element from the drawing by its index.
  void removeElement(int index) {
    if (index >= 0 && index < _elements.length) {
      _elements.removeAt(index);
    }
  }

  /// Retrieves an element from the drawing by its index.
  DrawingElement? getElement(int index) {
    if (index >= 0 && index < _elements.length) {
      return _elements[index];
    }
    return null;
  }

  /// Returns all elements in the drawing.
  List<DrawingElement> get allElements => _elements;
}

abstract class DrawingElement {
  final String id;
  final String name;
  final int x;
  final int y;
  final double width;
  final double height;

  DrawingElement({
    required this.id,
    required this.name,
    this.x = 0,
    this.y = 0,
    this.width = 100.0,
    this.height = 100.0,
  });
}

class ShapeElement extends DrawingElement {
  final ShapeType shapeType;
  final Color color;
  final AnchorType anchorType;

  ShapeElement({
    required String id,
    required String name,
    int x = 0,
    int y = 0,
    double width = 100.0,
    double height = 100.0,
    required this.shapeType,
    required this.color,
    this.anchorType = AnchorType.moveAndResize,
  }) : super(id: id, name: name, x: x, y: y, width: width, height: height);
}

class ChartElement extends DrawingElement {
  final Chart chart;

  ChartElement({
    required String id,
    required String name,
    int x = 0,
    int y = 0,
    double width = 500.0,
    double height = 300.0,
    required this.chart,
  }) : super(id: id, name: name, x: x, y: y, width: width, height: height);
}

enum ShapeType {
  rectangle,
  oval,
  line,
  arrow,
  textBox,
  picture,
}

enum Color {
  blue,
  red,
  green,
  yellow,
  black,
  white,
  gray,
  orange,
  purple,
}

enum AnchorType {
  moveAndResize,
  moveAndNoResize,
  absolute,
}
