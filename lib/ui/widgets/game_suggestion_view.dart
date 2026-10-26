import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../state/app_state.dart';
import 'saved_games_sheet.dart';

class GameSuggestionView extends StatelessWidget {
  final GameModel game;
  const GameSuggestionView({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                  // Keep the card readable on iPad.
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60), // Top spacing instead of Spacer
                      // Game Card
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: double.infinity, // same width as the buttons (iPad)
                            padding: const EdgeInsets.all(32.0),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground.resolveFrom(context),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.systemGrey.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(game.title, style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle),
                                const SizedBox(height: 4),
                                Text(
                                  [game.origin, if (game.playInfo != null) game.playInfo!].join('・'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13),
                                ),
                                const SizedBox(height: 24),
                                Text(game.rules, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.5)),
                              ],
                            ),
                          ),
                          // Save Button (Heart)
                          Positioned(
                            top: -12,
                            right: -12,
                            child: _SaveButton(game: game),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32), // Spacing between card and buttons
                      // Action Buttons
                      Column(
                        children: [
                          _ActionButton(
                            label: 'やる',
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              context.read<PreplayController>().playGame();
                            },
                            isPrimary: true,
                          ),
                          const SizedBox(height: 12),
                          _ActionButton(
                            label: '次',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.read<PreplayController>().next();
                            },
                            isPrimary: false,
                          ),
                          // AI Generation Button
                          if (!game.id.startsWith('ai_'))
                            CupertinoButton(
                              minSize: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.sparkles, size: 14, color: CupertinoColors.systemIndigo),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AIでこの場の遊びを作る',
                                    style: TextStyle(
                                      color: CupertinoColors.systemIndigo.resolveFrom(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                context.read<PreplayController>().generateWithAI();
                              },
                            ),
                          if (game.id.startsWith('ai_')) _AiFeedback(game: game),
                          if (context.watch<PreplayController>().aiError case final error?)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                error,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context), fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const _SensingToggle(),
                        ],
                      ),
                      const SizedBox(height: 24), // Bottom spacing
                    ],
                  ),
                ),
                ),
                ),
              ),
            );
          },
        ),
        // Library Button
        Positioned(
          top: 24,
          left: 24,
          child: SafeArea(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => const SavedGamesSheet(),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context).withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.square_favorites_alt,
                  color: CupertinoColors.label,
                  size: 24,
                  semanticLabel: 'お気に入りと遊びの一覧',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({required this.label, required this.onPressed, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: isPrimary ? CupertinoColors.systemBlue : null,
            borderRadius: BorderRadius.circular(16),
            border: isPrimary ? null : Border.all(color: CupertinoColors.separator.resolveFrom(context)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final GameModel game;
  const _SaveButton({required this.game});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final isSaved = controller.isSaved(game.id);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        controller.toggleSave(game);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          color: isSaved ? CupertinoColors.systemPink : CupertinoColors.systemGrey,
          size: 24,
          semanticLabel: isSaved ? 'お気に入りから外す' : 'お気に入りに追加',
        ),
      ),
    );
  }
}

/// "その場に合わせる" switch. Explains what the sensors are used for before
/// iOS asks for location / microphone permission.
class _SensingToggle extends StatelessWidget {
  const _SensingToggle();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final on = controller.contextSensing;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onPressed: () => on ? controller.setContextSensing(false) : _confirmEnable(context, controller),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? CupertinoIcons.location_fill : CupertinoIcons.location,
            size: 14,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(width: 4),
          Text(
            on ? 'その場に合わせる：オン' : 'その場に合わせる：オフ',
            style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context), fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _confirmEnable(BuildContext context, PreplayController controller) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('その場に合った遊びを出す'),
        content: const Text(
          '周りの音の大きさ、動き、移動の速さから、今できる遊びを選びます。\n'
          '使うのは端末の中だけで、録音や位置情報の送信はしません。\n\n'
          'このあと、位置情報とマイクの許可を聞かれます。',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('今はしない'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('オンにする'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final enabled = await controller.setContextSensing(true);
              if (!enabled && context.mounted) {
                showCupertinoDialog(
                  context: context,
                  builder: (c) => CupertinoAlertDialog(
                    title: const Text('許可がありません'),
                    content: const Text('設定アプリの「Preplay」で、位置情報かマイクを許可するとオンにできます。'),
                    actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(c))],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 👍 / 👎 for an AI-made game. Good ones can be published to "みんなの遊び";
/// the ratings also show which kinds of prompts work.
class _AiFeedback extends StatelessWidget {
  final GameModel game;
  const _AiFeedback({required this.game});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    if (controller.isAiGameRated(game.id)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('評価ありがとうございます', style: TextStyle(color: secondary, fontSize: 12)),
      );
    }
    Widget button(bool good) => CupertinoButton(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onPressed: () {
            HapticFeedback.selectionClick();
            controller.rateAiGame(game, good: good);
          },
          child: Icon(
            good ? CupertinoIcons.hand_thumbsup : CupertinoIcons.hand_thumbsdown,
            size: 20,
            color: secondary,
            semanticLabel: good ? 'この遊びは良かった' : 'この遊びはいまいち',
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('この遊びはどうでしたか？', style: TextStyle(color: secondary, fontSize: 12)),
        button(true),
        button(false),
      ],
    );
  }
}
