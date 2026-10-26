import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/app_config.dart';
import '../../models/game_model.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import 'all_games_list.dart';

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
                  0: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('お気に入り')),
                  1: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('すべて')),
                  2: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('みんなの遊び')),
                },
                onValueChanged: (value) {
                  setState(() {
                    _groupValue = value ?? 0;
                  });
                  if (_groupValue == 2 && communityGames.isEmpty && !isLoading && communityError == null) {
                    controller.loadCommunityGames();
                  }
                },
              ),
            ),
          ),

          Expanded(
            child: switch (_groupValue) {
              0 => _buildSavedList(context, controller, savedGames),
              1 => const AllGamesList(),
              _ => _buildCommunityList(context, controller, communityGames, isLoading, communityError),
            },
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
                  child: const Icon(CupertinoIcons.share, size: 24, semanticLabel: '友達に送る'),
                  onPressed: () {
                    // Start OS Sharing
                    Share.share(
                      'この遊び知ってる？「${game.title}」\n\nルール: ${game.rules}\n\n#Preplay #暇つぶし\n\n📱 ダウンロードはこちら:\n${AppConfig.appStoreUrl}',
                      subject: game.title,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Community Upload Button (Cloud)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.cloud_upload, size: 24, semanticLabel: 'みんなの遊びに公開'),
                  onPressed: () => _confirmShare(context, controller, game),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.toggleSave(game),
                  child: const Icon(CupertinoIcons.heart_fill, color: CupertinoColors.systemPink, semanticLabel: 'お気に入りから外す'),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: CupertinoColors.secondaryLabel),
              ),
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

    final notice = controller.communityNotice;
    final list = ListView.separated(
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.toggleSave(game),
                  child: Icon(
                    isSaved ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    color: isSaved ? CupertinoColors.systemPink : CupertinoColors.systemGrey,
                    semanticLabel: isSaved ? 'お気に入りから外す' : 'お気に入りに追加',
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showCommunityActions(context, controller, game),
                  child: const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.systemGrey, semanticLabel: 'その他の操作'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (notice == null) return list;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              const Icon(CupertinoIcons.wifi_slash, size: 14, color: CupertinoColors.secondaryLabel),
              const SizedBox(width: 6),
              Expanded(
                child: Text(notice, style: const TextStyle(color: CupertinoColors.secondaryLabel, fontSize: 12)),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.all(8),
                onPressed: () => controller.loadCommunityGames(),
                child: const Text('再読み込み', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }

  void _showCommunityActions(BuildContext context, PreplayController controller, GameModel game) {
    showCupertinoModalPopup(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(game.title),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              _confirmReport(context, controller, game);
            },
            child: const Text('不適切な内容として通報'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  void _confirmReport(BuildContext context, PreplayController controller, GameModel game) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('通報しますか？'),
        content: const Text('この遊びはあなたの画面に表示されなくなります。通報が集まった遊びは、みんなの画面からも消えます。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('キャンセル'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('通報する'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await controller.reportGame(game);
              if (!context.mounted) return;
              showCupertinoDialog(
                context: context,
                builder: (c) => CupertinoAlertDialog(
                  title: const Text('通報しました'),
                  content: const Text('ご協力ありがとうございます。内容を確認して対応します。\nお問い合わせ: contact@enludus.com'),
                  actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(c))],
                ),
              );
            },
          ),
        ],
      ),
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
