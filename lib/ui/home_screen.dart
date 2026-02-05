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
        child: ListenableBuilder(
          listenable: context.read<PreplayController>(),
          builder: (context, _) {
            final controller = context.read<PreplayController>();
            
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: controller.state == PreplayState.detecting
                  ? const DetectingView(key: ValueKey('detecting'))
                  : GameSuggestionView(
                      key: const ValueKey('suggested'),
                      game: controller.currentGame!,
                    ),
            );
          },
        ),
      ),
    );
  }
}
