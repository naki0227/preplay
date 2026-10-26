import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class PlayingOverlay extends StatelessWidget {
  const PlayingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final game = controller.currentGame;
    final topic = controller.currentTopic;

    if (game == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.background, // Fill screen
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.clear, color: CupertinoColors.secondaryLabel, semanticLabel: 'やめる'),
                  onPressed: () => controller.stopGame(),
                ),
                Text(
                  game.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label,
                  ),
                ),
                const SizedBox(width: 44), // Spacer for balance
              ],
            ),
            
            const Spacer(),
            
            // Rules Display (Compact)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context).withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                game.rules,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.label,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Topic Display
            if (topic != null) ...[
              const Text(
                'お題',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 12),
              
              // Topic + Reroll Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 44), // Balancer
                  Expanded(
                    child: Text(
                      topic,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label,
                        height: 1.2,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      controller.rerollTopic();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.refresh, size: 20, color: AppColors.tintColor, semanticLabel: '別のお題'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Let\'s Start!',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label,
                ),
              ),
            ],

            const Spacer(),
            
            // "Next Topic" if available? (Future enhancement)
            // For now just "Done"
            
            // Add Topic Button
            const PlayTimer(),
            const SizedBox(height: 8),
            CupertinoButton(
              child: const Text('お題を追加', style: TextStyle(color: AppColors.tintColor)),
              onPressed: () => _showAddTopicDialog(context),
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(12),
                child: const Text('終わり', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.finishGame();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddTopicDialog(BuildContext context) {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('お題を追加'),
        content: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: '新しいお題を入力...',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('追加'),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<PreplayController>().addTopic(controller.text);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Optional countdown for games played in rounds (ワードウルフ etc.).
class PlayTimer extends StatefulWidget {
  const PlayTimer({super.key});

  @override
  State<PlayTimer> createState() => _PlayTimerState();
}

class _PlayTimerState extends State<PlayTimer> {
  static const _choices = [1, 3, 5]; // minutes
  Timer? _timer;
  int _remaining = 0; // seconds
  bool _finished = false;

  void _start(int minutes) {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _remaining = minutes * 60;
      _finished = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        setState(() => _finished = true);
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _remaining = 0;
      _finished = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String format(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return CupertinoButton(
        onPressed: _stop,
        child: Text('時間です！', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CupertinoColors.systemRed.resolveFrom(context))),
      );
    }
    if (_remaining > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.timer, size: 20, color: AppColors.tintColor),
          const SizedBox(width: 6),
          Text(format(_remaining), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _stop,
            child: const Text('止める', style: TextStyle(fontSize: 14)),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.timer, size: 16, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
        const SizedBox(width: 4),
        for (final m in _choices)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(44, 44),
            onPressed: () => _start(m),
            child: Text('$m分', style: const TextStyle(fontSize: 15)),
          ),
      ],
    );
  }
}
