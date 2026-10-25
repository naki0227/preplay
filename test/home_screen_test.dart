import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preplay/models/game_model.dart';
import 'package:preplay/state/app_state.dart';
import 'package:preplay/ui/home_screen.dart';

void main() {
  testWidgets('first launch shows a game right away, without sensors or a close button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = PreplayController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const CupertinoApp(home: HomeScreen()),
      ),
    );
    // Detection waits at least 0.8 s; sensing is off, so nothing else is awaited.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(controller.state, PreplayState.suggested);
    expect(controller.contextSensing, isFalse);
    expect(GameModel.mvpGames.map((g) => g.id), contains(controller.currentGame!.id));
    expect(find.text(controller.currentGame!.title), findsOneWidget);
    expect(find.text('やる'), findsOneWidget);
    expect(find.text('閉じる'), findsNothing);
    expect(find.text('その場に合わせる：オフ'), findsOneWidget);
    expect(find.bySemanticsLabel('Preplayについて'), findsOneWidget);

    // While playing, the header has its own controls; the info button is hidden.
    controller.playGame();
    await tester.pump(const Duration(seconds: 1));
    expect(find.bySemanticsLabel('Preplayについて'), findsNothing);
    expect(find.text('終わり'), findsOneWidget);
  });
}
