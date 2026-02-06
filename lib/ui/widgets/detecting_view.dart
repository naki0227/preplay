import 'package:flutter/cupertino.dart';
import '../anims/fade_transition.dart';
import '../../theme/app_text.dart';
import '../../theme/app_colors.dart';

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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
