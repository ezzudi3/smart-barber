import 'package:flutter/material.dart';

class FullImageView extends StatefulWidget {
  final String imageUrl;

  const FullImageView({Key? key, required this.imageUrl}) : super(key: key);

  @override
  State<FullImageView> createState() => _FullImageViewState();
}

class _FullImageViewState extends State<FullImageView> {
  double _dragOffset = 0.0;
  double _opacity = 1.0;
  static const double dragDismissThreshold = 100;
  static const double velocityDismissThreshold = 700;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_opacity.clamp(0.4, 1.0)),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffset += details.delta.dy;
            _opacity = 1 - (_dragOffset / 400);
          });
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > dragDismissThreshold ||
              details.primaryVelocity != null && details.primaryVelocity! > velocityDismissThreshold) {
            Navigator.pop(context);
          } else {
            setState(() {
              _dragOffset = 0.0;
              _opacity = 1.0;
            });
          }
        },
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: widget.imageUrl,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: InteractiveViewer(
                child: Image.network(widget.imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
