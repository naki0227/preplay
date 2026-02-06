import 'package:flutter/cupertino.dart';
import '../anims/fade_transition.dart';
import '../../theme/app_text.dart';
import '../../theme/app_colors.dart';

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

class DetectingView extends StatelessWidget {
  final String? message;
  const DetectingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransitionWidget(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '👀',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? '今の感じを見てます...',
              style: AppText.body.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
