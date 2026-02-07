import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/game_model.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class SavedGamesSheet extends StatefulWidget {
  const SavedGamesSheet({super.key});

  @override
  State<SavedGamesSheet> createState() => _SavedGamesSheetState();
}

class _SavedGamesSheetState extends State<SavedGamesSheet> {
  int _groupValue = 0;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PreplayController>();
    final savedGames = controller.savedGames;
    final communityGames = controller.communityGames;
    final isLoading = controller.isCommunityLoading;
    final communityError = controller.communityError;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
          
          // Header & Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _groupValue,
                children: const {
                  0: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('お気に入り')),
                  1: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('みんなの遊び')),
                },
                onValueChanged: (value) {
                  setState(() {
                    _groupValue = value ?? 0;
                  });
                  if (_groupValue == 1 && communityGames.isEmpty && !isLoading && communityError == null) {
                    controller.loadCommunityGames();
                  }
                },
              ),
            ),
          ),

          Expanded(
            child: _groupValue == 0
                ? _buildSavedList(context, controller, savedGames)
                : _buildCommunityList(context, controller, communityGames, isLoading, communityError),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList(BuildContext context, PreplayController controller, List<GameModel> games) {
    if (games.isEmpty) {
      return const Center(
        child: Text(
          'まだ保存された遊びはありません',
          style: TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: games.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final game = games[index];
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
            subtitle: Text(game.origin),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // OS Share Button (Viral)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.share, size: 24),
                  onPressed: () {
                    // Start OS Sharing
                    Share.share(
                      'この遊び知ってる？「${game.title}」\n\nルール: ${game.rules}\n\n#Preplay #暇つぶし\n\n📱 ダウンロードはこちら:\nhttps://example.com/preplay (仮)',
                      subject: game.title,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Community Upload Button (Cloud)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.cloud_upload, size: 24),
                  onPressed: () => _confirmShare(context, controller, game),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.toggleSave(game),
                  child: const Icon(CupertinoIcons.heart_fill, color: CupertinoColors.systemPink),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommunityList(BuildContext context, PreplayController controller, List<GameModel> games, bool isLoading, String? error) {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle, color: CupertinoColors.systemRed, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              child: const Text('再試行'),
              onPressed: () => controller.loadCommunityGames(),
            ),
          ],
        ),
      );
    }

    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'まだ投稿がありません',
              style: TextStyle(color: CupertinoColors.secondaryLabel),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              child: const Text('再読み込み'),
              onPressed: () => controller.loadCommunityGames(),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
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
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmShare(BuildContext context, PreplayController controller, GameModel game) {
    if (controller.isGameShared(game)) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('公開済み'),
          content: const Text('この遊びは既にみんなの遊びに公開されています。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('遊びをシェア'),
        content: Text('「${game.title}」をみんなに公開しますか？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('公開する'),
            onPressed: () async {
              Navigator.pop(context);
              // Show loading or toast?
              final success = await controller.shareGame(game);
              if (context.mounted) {
                if (success) {
                   showCupertinoDialog(context: context, builder: (c) => CupertinoAlertDialog(
                     title: const Text('公開しました！'),
                     actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(c))],
                   ));
                } else {
                   // Error handling
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
