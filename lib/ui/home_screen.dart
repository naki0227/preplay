import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Required for showModalBottomSheet and Colors
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'widgets/detecting_view.dart';
import 'widgets/game_suggestion_view.dart';
import 'widgets/playing_overlay.dart';
import 'widgets/about_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // Ensure background color is dynamic (System Background)
      backgroundColor: CupertinoColors.systemBackground, 
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.bgStart, AppColors.bgEnd],
              ),
            ),
            child: Consumer<PreplayController>(
              builder: (context, controller, child) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: _buildContent(context, controller),
                );
              },
            ),
          ),
          
          // About Button (same position and look as the library button;
          // hidden while playing, where the header has its own controls)
          Consumer<PreplayController>(
            builder: (context, controller, _) => controller.state == PreplayState.playing
                ? const SizedBox.shrink()
                : Positioned(
                    top: 24,
                    right: 24,
                    child: SafeArea(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const AboutSheet(),
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
                          child: const Icon(CupertinoIcons.info, color: AppColors.textMain, size: 24, semanticLabel: 'Preplayについて'),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, PreplayController controller) {
    switch (controller.state) {
      case PreplayState.detecting:
        return const DetectingView();
      case PreplayState.thinking:
        return const DetectingView(message: 'AIが新しい遊びを考えています...\n(数秒かかります)');
      case PreplayState.suggested:
        if (controller.currentGame != null) {
          return GameSuggestionView(game: controller.currentGame!, key: ValueKey(controller.currentGame!.id));
        }
        return const DetectingView();
      case PreplayState.playing:
        return const PlayingOverlay();
    }
  }
}
