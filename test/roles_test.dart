import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preplay/models/game_model.dart';
import 'package:preplay/models/role_deal.dart';
import 'package:preplay/state/app_state.dart';
import 'package:preplay/ui/widgets/playing_overlay.dart';
import 'package:preplay/ui/widgets/role_deal_screen.dart';

GameModel _game(String id) => GameModel.mvpGames.firstWhere((g) => g.id == id);

void main() {
  group('dealing', () {
    test('word wolf: one wolf up to 5 players, two from 6; same pair for everyone', () {
      final g = _game('word_wolf');
      for (final (players, wolves) in [(4, 1), (5, 1), (6, 2), (8, 2)]) {
        for (var seed = 0; seed < 20; seed++) {
          final d = RoleDeal.deal(g, players, g.topics, Random(seed));
          expect(d.cards, hasLength(players));
          final words = d.cards.map((c) => c.split('\n')[1]).toList();
          final counts = <String, int>{};
          for (final w in words) {
            counts[w] = (counts[w] ?? 0) + 1;
          }
          expect(counts.length, 2, reason: '$words');
          expect(counts.values.reduce(min), wolves);
          final pair = g.topics.map(RoleDeal.splitPair).firstWhere((p) => p!.toSet().containsAll(counts.keys));
          expect(pair, isNotNull);
          expect(d.answer, contains('ウルフ：'));
        }
      }
    });

    test('word wolf uses the user\'s own pairs too', () {
      final d = RoleDeal.deal(_game('word_wolf'), 4, ['自分のお題', 'みかん 対 りんご'], Random(0));
      expect(d.cards.map((c) => c.split('\n')[1]).toSet(), {'みかん', 'りんご'});
    });

    test('splitPair', () {
      expect(RoleDeal.splitPair('うどん vs そば'), ['うどん', 'そば']);
      expect(RoleDeal.splitPair('うどんVSそば'), ['うどん', 'そば']);
      expect(RoleDeal.splitPair('うどん'), isNull);
      expect(RoleDeal.splitPair('うどん vs うどん'), isNull);
      for (final t in _game('word_wolf').topics) {
        expect(RoleDeal.splitPair(t), isNotNull, reason: t);
      }
    });

    test('insider: one master and one insider who both know the word', () {
      final g = _game('insider_game');
      for (var seed = 0; seed < 20; seed++) {
        final d = RoleDeal.deal(g, 5, g.topics, Random(seed));
        expect(d.cards.where((c) => c.contains('\nマスター\n')), hasLength(1));
        expect(d.cards.where((c) => c.contains('\nインサイダー\n')), hasLength(1));
        expect(d.cards.where((c) => c.contains('\n庶民\n')), hasLength(3));
        final word = d.answer.split('お題：').last;
        expect(d.cards.where((c) => c.contains(word)), hasLength(2));
      }
    });

    test('mafia count grows with the group', () {
      final g = _game('mafia');
      for (final (players, mafia) in [(6, 2), (8, 2), (9, 3), (11, 3), (12, 4), (15, 4)]) {
        final d = RoleDeal.deal(g, players, g.topics, Random(players));
        expect(d.cards.where((c) => c.contains('\nマフィア\n')), hasLength(mafia), reason: '$players');
      }
    });

    test('games that need a topic have enough of them', () {
      for (final id in ['gesture_game', 'word_wolf', 'insider_game', 'twenty_questions', 'daruma_san', 'intro_quiz']) {
        expect(_game(id).topics.length, greaterThanOrEqualTo(10), reason: id);
      }
    });
  });

  testWidgets('pass the phone: everyone sees only their own card, then the answer', (tester) async {
    tester.view.physicalSize = const Size(375, 667) * 2; // iPhone SE
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final g = _game('word_wolf');
    await tester.pumpWidget(CupertinoApp(home: RoleDealScreen(game: g, topics: g.topics, random: Random(3))));

    expect(find.text('4人'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('1人増やす'));
    await tester.pump();
    expect(find.text('5人'), findsOneWidget);
    expect(find.text('ウルフは1人'), findsOneWidget);

    await tester.tap(find.text('配る'));
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      expect(find.text('$i番の人'), findsOneWidget);
      expect(find.text('あなたのお題'), findsNothing); // hidden until tapped
      await tester.tap(find.text('自分の役を見る'));
      await tester.pump();
      expect(find.text('あなたのお題'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(i == 5 ? '隠して終わる' : '隠して次の人へ'));
      await tester.pump();
    }
    expect(find.text('全員に配りました'), findsOneWidget);
    await tester.tap(find.text('答えを見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('見る'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ウルフ：'), findsOneWidget);
  });

  testWidgets('mafia setup fits an iPhone SE at 15 players', (tester) async {
    tester.view.physicalSize = const Size(375, 667) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final g = _game('mafia');
    await tester.pumpWidget(CupertinoApp(home: RoleDealScreen(game: g, topics: g.topics)));
    for (var i = 0; i < 12; i++) {
      await tester.tap(find.bySemanticsLabel('1人増やす'));
      await tester.pump();
    }
    expect(find.text('15人'), findsOneWidget);
    expect(find.textContaining('マフィア4人'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('play screen: secret-role games do not show the topic to everyone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(375, 667) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final controller = PreplayController();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: controller,
      child: const CupertinoApp(home: CupertinoPageScaffold(child: PlayingOverlay())),
    ));
    await tester.pump(const Duration(seconds: 2));

    await controller.selectGame(_game('word_wolf'));
    controller.playGame();
    await tester.pump();
    expect(find.text('役とお題を配る'), findsOneWidget);
    expect(find.text(controller.currentTopic!), findsNothing);
    expect(tester.takeException(), isNull);

    await controller.selectGame(_game('gesture_game'));
    controller.playGame();
    await tester.pump();
    expect(find.text('役とお題を配る'), findsNothing);
    expect(find.text(controller.currentTopic!), findsOneWidget);
  });
}
