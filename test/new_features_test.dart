import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preplay/models/game_model.dart';
import 'package:preplay/state/app_state.dart';
import 'package:preplay/ui/widgets/all_games_list.dart';
import 'package:preplay/ui/widgets/playing_overlay.dart';

Future<PreplayController> _pump(WidgetTester tester, Widget child, {Size size = const Size(375, 667)}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final controller = PreplayController();
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: controller,
    child: CupertinoApp(home: CupertinoPageScaffold(child: child)),
  ));
  await tester.pump(const Duration(seconds: 2));
  return controller;
}

void main() {
  testWidgets('"すべて" lists every game and searches by title and rules', (tester) async {
    await _pump(tester, const AllGamesList());
    expect(find.byType(CupertinoListTile), findsWidgets);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'ウルフ');
    await tester.pump();
    expect(find.text('ワードウルフ'), findsOneWidget);
    expect(find.text('連想しりとり'), findsNothing);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzzz');
    await tester.pump();
    expect(find.text('見つかりませんでした'), findsOneWidget);
  });

  testWidgets('play screen fits an iPhone SE with a topic and the timer', (tester) async {
    final controller = await _pump(tester, const PlayingOverlay());
    // The longest rules among games that have topics.
    final game = (GameModel.mvpGames.where((g) => g.topics.isNotEmpty).toList()
          ..sort((a, b) => b.rules.length.compareTo(a.rules.length)))
        .first;
    await controller.selectGame(game);
    controller.playGame();
    await tester.pump();
    expect(tester.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('3分'), findsOneWidget);
  });

  testWidgets('timer counts down and says when time is up', (tester) async {
    final controller = await _pump(tester, const PlayingOverlay());
    await controller.selectGame(GameModel.mvpGames.firstWhere((g) => g.id == 'word_wolf'));
    controller.playGame();
    await tester.pump();

    await tester.tap(find.text('1分'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:59'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.text('時間です！'), findsOneWidget);

    await tester.tap(find.text('時間です！'));
    await tester.pump();
    expect(find.text('1分'), findsOneWidget);
  });
}
