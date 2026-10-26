import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/game_model.dart';
import '../../state/app_state.dart';

/// Group sizes offered as filters in "すべて".
enum PlayerFilter { any, two, threeToFive, sixPlus }

/// Lengths offered as filters in "すべて" (upper bound in minutes).
enum TimeFilter { any, five, ten }

/// All bundled games with a search box and people / time filters, so a known
/// game (or one that fits the group) can be picked directly.
class AllGamesList extends StatefulWidget {
  const AllGamesList({super.key});

  /// Matches title, rules and origin, ignoring case and surrounding spaces,
  /// then keeps games that suit the group size and fit in the time.
  /// Games without people / time info only show when that filter is off.
  static List<GameModel> filterGames(
    List<GameModel> games,
    String query, {
    PlayerFilter players = PlayerFilter.any,
    TimeFilter time = TimeFilter.any,
  }) {
    final q = query.trim().toLowerCase();
    return games.where((g) {
      if (q.isNotEmpty && !'${g.title}\n${g.rules}\n${g.origin}'.toLowerCase().contains(q)) return false;
      if (players != PlayerFilter.any) {
        final min = g.minPlayers, max = g.maxPlayers;
        if (min == null || max == null) return false;
        final ok = switch (players) {
          PlayerFilter.two => min <= 2 && max >= 2,
          PlayerFilter.threeToFive => min <= 5 && max >= 3,
          PlayerFilter.sixPlus => max >= 6,
          PlayerFilter.any => true,
        };
        if (!ok) return false;
      }
      if (time != TimeFilter.any) {
        final minutes = g.minutes;
        if (minutes == null) return false;
        if (minutes > (time == TimeFilter.five ? 5 : 10)) return false;
      }
      return true;
    }).toList();
  }

  @override
  State<AllGamesList> createState() => _AllGamesListState();
}

class _AllGamesListState extends State<AllGamesList> {
  String _query = '';
  PlayerFilter _players = PlayerFilter.any;
  TimeFilter _time = TimeFilter.any;

  static Widget _segment(String label) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(label, style: const TextStyle(fontSize: 13)));

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final games = AllGamesList.filterGames(GameModel.mvpGames, _query, players: _players, time: _time);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: CupertinoSearchTextField(
            placeholder: '遊びを探す（例：しりとり）',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<PlayerFilter>(
              groupValue: _players,
              children: {
                PlayerFilter.any: _segment('人数すべて'),
                PlayerFilter.two: _segment('2人'),
                PlayerFilter.threeToFive: _segment('3〜5人'),
                PlayerFilter.sixPlus: _segment('6人以上'),
              },
              onValueChanged: (value) => setState(() => _players = value ?? PlayerFilter.any),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<TimeFilter>(
              groupValue: _time,
              children: {
                TimeFilter.any: _segment('時間すべて'),
                TimeFilter.five: _segment('5分以内'),
                TimeFilter.ten: _segment('10分以内'),
              },
              onValueChanged: (value) => setState(() => _time = value ?? TimeFilter.any),
            ),
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
                        subtitle: Text(
                          [if (game.playInfo != null) game.playInfo!, game.rules.replaceAll('\n', ' ')].join('｜'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
