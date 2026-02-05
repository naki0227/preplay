import 'package:flutter/cupertino.dart';

class DetectingView extends StatefulWidget {
  const DetectingView({super.key});

  @override
  State<DetectingView> createState() => _DetectingViewState();
}

class _DetectingViewState extends State<DetectingView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true); // ゆるやかなパルス

    _opacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _opacity,
        child: const Text(
          '今の感じを見てます',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
