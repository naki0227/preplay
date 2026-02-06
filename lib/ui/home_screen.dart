import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'widgets/detecting_view.dart';
import 'widgets/game_suggestion_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // Ensure background color is dynamic (System Background)
      backgroundColor: CupertinoColors.systemBackground, 
      child: Container(
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
    );
  }

  Widget _buildContent(BuildContext context, PreplayController controller) {
    switch (controller.state) {
      case PreplayState.detecting:
        return const DetectingView();
      case PreplayState.thinking:
        return const DetectingView(message: 'AIが新しい遊びを生成中...\n(10秒ほどかかります)');
      case PreplayState.suggested:
        if (controller.currentGame != null) {
          return GameSuggestionView(game: controller.currentGame!, key: ValueKey(controller.currentGame!.id));
        }
        return const DetectingView();
    }
  }
}
