import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../models/game_model.dart';
import '../../models/role_deal.dart';
import '../../theme/app_colors.dart';

/// Pass-the-phone dealing: choose the number of players, then each player in
/// turn looks at their own card and hides it before passing the phone on.
class RoleDealScreen extends StatefulWidget {
  final GameModel game;
  final List<String> topics;
  final Random? random; // fixed in tests

  const RoleDealScreen({super.key, required this.game, required this.topics, this.random});

  @override
  State<RoleDealScreen> createState() => _RoleDealScreenState();
}

class _RoleDealScreenState extends State<RoleDealScreen> {
  late final Random _random = widget.random ?? Random();
  late int _players = _clamp(widget.game.minPlayers == null ? 4 : max(widget.game.minPlayers!, 4));
  RoleDeal? _deal;
  int _index = 0;
  bool _revealed = false;
  bool _showAnswer = false;

  int get _min => widget.game.minPlayers ?? 3;
  int get _max => widget.game.maxPlayers ?? 10;
  int _clamp(int n) => n.clamp(_min, _max);

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _deal = RoleDeal.deal(widget.game, _players, widget.topics, _random);
      _index = 0;
      _revealed = false;
      _showAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deal = _deal;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.game.title),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: deal == null
                  ? _setup(context)
                  : _index < deal.cards.length
                      ? _passing(context, deal)
                      : _done(context, deal),
            ),
          ),
        ),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    Widget step(IconData icon, String label, int delta) => CupertinoButton(
          onPressed: _clamp(_players + delta) == _players
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _players = _clamp(_players + delta));
                },
          child: Icon(icon, size: 40, semanticLabel: label),
        );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('何人で遊びますか？', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            step(CupertinoIcons.minus_circle, '1人減らす', -1),
            SizedBox(
              width: 120,
              child: Text('$_players人',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700)),
            ),
            step(CupertinoIcons.plus_circle, '1人増やす', 1),
          ],
        ),
        const SizedBox(height: 8),
        Text(RoleDeal.describe(widget.game, _players),
            textAlign: TextAlign.center, style: const TextStyle(color: CupertinoColors.secondaryLabel)),
        const SizedBox(height: 32),
        const Text(
          'スマホを順番に回して、1人ずつ自分の画面だけを見ます。\n誰が何かは、スマホにしかわかりません。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(onPressed: _start, child: const Text('配る')),
        ),
      ],
    );
  }

  Widget _passing(BuildContext context, RoleDeal deal) {
    final last = _index == deal.cards.length - 1;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${_index + 1}番の人', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
        Text('（${deal.cards.length}人中）', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
        const SizedBox(height: 32),
        if (!_revealed) ...[
          const Text('ほかの人に見えないようにして、押してください',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() => _revealed = true);
              },
              child: const Text('自分の役を見る'),
            ),
          ),
        ] else ...[
          _Card(text: deal.cards[_index]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _revealed = false;
                  _index++;
                });
              },
              child: Text(last ? '隠して終わる' : '隠して次の人へ'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _done(BuildContext context, RoleDeal deal) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('全員に配りました', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('話し合いを始めましょう。\n終わったら「答えを見る」で答え合わせ。',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5)),
        const SizedBox(height: 32),
        if (_showAnswer)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(deal.answer, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, height: 1.6)),
          )
        else
          CupertinoButton(
            onPressed: () => showCupertinoDialog(
              context: context,
              builder: (c) => CupertinoAlertDialog(
                title: const Text('答えを見ますか？'),
                content: const Text('全員の役とお題が表示されます。'),
                actions: [
                  CupertinoDialogAction(child: const Text('まだ'), onPressed: () => Navigator.pop(c)),
                  CupertinoDialogAction(
                    isDefaultAction: true,
                    child: const Text('見る'),
                    onPressed: () {
                      Navigator.pop(c);
                      setState(() => _showAnswer = true);
                    },
                  ),
                ],
              ),
            ),
            child: const Text('答えを見る'),
          ),
        const SizedBox(height: 16),
        CupertinoButton(onPressed: _start, child: const Text('もう一度配る')),
        CupertinoButton(
          onPressed: () => setState(() => _deal = null),
          child: const Text('人数を変える'),
        ),
      ],
    );
  }
}

/// First line: label, second: the word or role (large), rest: what to do.
class _Card extends StatelessWidget {
  final String text;
  const _Card({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(lines.first, style: const TextStyle(fontSize: 17, color: CupertinoColors.secondaryLabel)),
          if (lines.length > 1) ...[
            const SizedBox(height: 12),
            Text(lines[1],
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
          ],
          for (final l in lines.skip(2)) ...[
            const SizedBox(height: 12),
            Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
