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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Game Card
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
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
                        Text(game.origin, style: const TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 13)),
                        const SizedBox(height: 24),
                        Text(game.rules, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.5)),
                      ],
                    ),
                  ),
                  // Save Button (Heart)
                  Positioned(
                    top: -12,
                    right: -12,
                    child: _SaveButton(gameId: game.id),
                  ),
                ],
              ),
              const Spacer(flex: 2),
              // Action Buttons
              Column(
                children: [
                  _ActionButton(
                    label: 'やる',
                    onPressed: () => HapticFeedback.mediumImpact(),
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
                  CupertinoButton(
                    child: const Text('閉じる', style: TextStyle(color: CupertinoColors.secondaryLabel)),
                    onPressed: () => SystemNavigator.pop(),
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
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
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
  final String gameId;
  const _SaveButton({required this.gameId});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final isSaved = controller.isSaved(gameId);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        controller.toggleSave(gameId);
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
        ),
      ),
    );
  }
}
