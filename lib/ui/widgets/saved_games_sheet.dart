import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../state/app_state.dart';

class SavedGamesSheet extends StatelessWidget {
  const SavedGamesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final savedGames = GameModel.mvpGames.where((g) => controller.savedIds.contains(g.id)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3.resolveFrom(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'お気に入り',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
          ),
          Expanded(
            child: savedGames.isEmpty
                ? const Center(
                    child: Text(
                      'まだ保存された遊びはありません',
                      style: TextStyle(color: CupertinoColors.secondaryLabel),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: savedGames.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final game = savedGames[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CupertinoListTile(
                          title: Text(
                            game.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(game.origin),
                          trailing: CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => controller.toggleSave(game.id),
                            child: const Icon(CupertinoIcons.heart_fill, color: CupertinoColors.systemPink),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
