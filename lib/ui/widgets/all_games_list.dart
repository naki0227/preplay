import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../state/app_state.dart';

/// All bundled games with a search box, so a known game can be picked directly.
class AllGamesList extends StatefulWidget {
  const AllGamesList({super.key});

  @override
  State<AllGamesList> createState() => _AllGamesListState();
}

class _AllGamesListState extends State<AllGamesList> {
  String _query = '';

  /// Matches title, rules and origin, ignoring case and surrounding spaces.
  static List<GameModel> filter(List<GameModel> games, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return games;
    return games
        .where((g) => '${g.title}\n${g.rules}\n${g.origin}'.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final games = filter(GameModel.mvpGames, _query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: CupertinoSearchTextField(
            placeholder: '遊びを探す（例：しりとり）',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: games.isEmpty
              ? const Center(
                  child: Text('見つかりませんでした', style: TextStyle(color: CupertinoColors.secondaryLabel)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: games.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final game = games[index];
                    final isSaved = controller.isSaved(game.id);
                    return Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CupertinoListTile(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () {
                          controller.selectGame(game);
                          Navigator.pop(context);
                        },
                        title: Text(game.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(game.rules.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => controller.toggleSave(game),
                          child: Icon(
                            isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                            color: isSaved ? CupertinoColors.systemPink : CupertinoColors.systemGrey,
                            semanticLabel: isSaved ? 'お気に入りから外す' : 'お気に入りに追加',
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
