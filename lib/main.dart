import 'package:flutter/material.dart';

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// [Widget] building the [MaterialApp].
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock<IconData>(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (icon) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color:
                      Colors.primaries[icon.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(icon, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dock of the reorderable [items].
class Dock<T extends Object> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  final List<T> items;
  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T extends Object> extends State<Dock<T>> {
  late final List<T> _items = List.from(widget.items);
  int? _draggedIndex;
  GlobalKey key = GlobalKey();
  bool addGap = false;
  double containerVerticalAxis = 0.0;
  double draggingVerticalAxis = 0.0;
  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_items.length, (index) {
          return DraggableItem<T>(
            item: _items[index],
            addGap: addGap,
            isBeingDragged: index == _draggedIndex,
            onDragUpdated: (v) {
              draggingVerticalAxis = v.globalPosition.dy;
              if (draggingVerticalAxis < containerVerticalAxis + 50 &&
                  draggingVerticalAxis > containerVerticalAxis - 20) {
                setState(() {
                  addGap = true;
                });
              } else {
                setState(() {
                  addGap = false;
                });
              }
            },
            onDragStarted: () {
              setState(() {
                final RenderBox renderBox =
                    key.currentContext!.findRenderObject() as RenderBox;
                final position = renderBox.localToGlobal(Offset.zero);
                containerVerticalAxis = position.dy;
              });
            },
            onDragEnd: () => setState(() {
              setState(() {
                addGap = false;
              });
            }),
            onAccept: (data) {
              setState(() {
                final oldIndex = _items.indexOf(data);
                _items.removeAt(oldIndex);
                _items.insert(index, data);
                _draggedIndex = null;
              });
            },
            builder: widget.builder,
          );
        }),
      ),
    );
  }
}

/// Draggable item widget that encapsulates the [DraggableItems].
class DraggableItem<T extends Object> extends StatefulWidget {
  const DraggableItem({
    super.key,
    required this.item,
    required this.isBeingDragged,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAccept,
    required this.onDragUpdated,
    required this.addGap,
    required this.builder,
  });
  final bool addGap;
  final T item;
  final bool isBeingDragged;
  final VoidCallback onDragStarted;

  final Function(DragUpdateDetails) onDragUpdated;
  final VoidCallback onDragEnd;
  final Function(T) onAccept;
  final Widget Function(T) builder;

  @override
  _DraggableItemState<T> createState() => _DraggableItemState<T>();
}

///State used to update the dragging logic
class _DraggableItemState<T extends Object> extends State<DraggableItem<T>>
    with TickerProviderStateMixin {
  bool isDragEnding = false;
  late Animation<double> verticalAxis;

  late Animation<double> horizontalAxis;
  late AnimationController animationController;
  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    verticalAxis = Tween<double>(begin: 0, end: 0).animate(animationController);
    horizontalAxis =
        Tween<double>(begin: 0, end: 0).animate(animationController);
  }

  @override
  void dispose() {
    super.dispose();
    animationController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(horizontalAxis.value, verticalAxis.value),
      child: Draggable<T>(
        data: widget.item,
        onDragUpdate: (v) {
          widget.onDragUpdated(v);
        },
        onDraggableCanceled: (v, o) async {
          animationController.reset();
          animationController.forward();
          verticalAxis = Tween<double>(
                  begin: o.dy < 50
                      ? 10 * -o.dy
                      : o.dy < 100
                          ? 5 * -o.dy
                          : o.dy < 200
                              ? 2 * -o.dy
                              : o.dy < 300
                                  ? -o.dy
                                  : o.dy,
                  end: 0)
              .animate(animationController)
            ..addListener(() {
              setState(() {});
            });
          horizontalAxis = Tween<double>(
                  begin: o.dx > 100
                      ? o.dx / 4
                      : o.dx > 50
                          ? -o.dx / 2
                          : o.dx < 1
                              ? o.dx
                              : o.dx < 50
                                  ? -o.dx * 5
                                  : 0,
                  end: 0)
              .animate(animationController)
            ..addListener(() {
              setState(() {});
            });
        },
        onDragStarted: widget.onDragStarted,
        onDragEnd: handleDragEnd,
        feedback: Opacity(
          opacity: 0.7,
          child: widget.builder(widget.item),
        ),
        childWhenDragging:widget.addGap != true
            ? SizedBox.shrink()
            : SizedBox.fromSize(
                size: Size(80, 44),
              ),
        child: DragTarget<T>(
          onAcceptWithDetails: (data) => widget.onAccept(data.data),
          builder: (context, candidateData, rejectedData) {
            bool isCandidate = candidateData.isNotEmpty;
            return AnimatedDraggableItem(
              isBeingDragged: widget.isBeingDragged,
              isDragEnding: isDragEnding,
              item: widget.item,
              builder: widget.builder,
              isCandidate: isCandidate,
            );
          },
        ),
      ),
    );
  }

  void handleDragEnd(_) {
    setState(() {
      isDragEnding = true;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        isDragEnding = false;
      });
    });
    widget.onDragEnd();
  }
}

/// An animated widget that represents the [DraggableItem], handling scaling and opacity changes.
class AnimatedDraggableItem<T extends Object> extends StatelessWidget {
  const AnimatedDraggableItem({
    super.key,
    required this.isBeingDragged,
    required this.isDragEnding,
    required this.item,
    required this.builder,
    required this.isCandidate,
  });

  final bool isBeingDragged;
  final bool isDragEnding;
  final T item;
  final Widget Function(T) builder;
  final bool isCandidate; // Indicates if the item is a candidate for drop

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;

    if (isCandidate) {
      scale = 1.1;
    } else if (isDragEnding) {
      scale = 1.1;
    }

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isBeingDragged ? 0.2 : 1.0,
        child: builder(item),
      ),
    );
  }
}
