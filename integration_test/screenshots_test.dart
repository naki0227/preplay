// App Store screenshots, taken on a simulator by .github/workflows/screenshots.yml:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <simulator>
// Images are written by the driver to $SCREENSHOT_DIR.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preplay/main.dart';
import 'package:preplay/models/game_model.dart';
import 'package:preplay/state/app_state.dart';
import 'package:preplay/ui/home_screen.dart';

GameModel _game(String id) => GameModel.mvpGames.firstWhere((g) => g.id == id);

Future<void> _settle(WidgetTester tester) async {
  // The detecting view animates forever, so pump for a fixed time instead of pumpAndSettle.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App Store screenshots', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // first-launch state: sensing off, nothing saved

    await tester.pumpWidget(const PreplayApp());
    await _settle(tester);
    final controller = tester.element(find.byType(HomeScreen)).read<PreplayController>();

    // 1. Suggestion
    await controller.selectGame(_game('word_wolf'));
    await _settle(tester);
    await binding.takeScreenshot('1_suggestion');

    // 2. Playing with a topic and the timer buttons. Fixed topic and no running
    // timer, so the image is identical on every run (no needless re-upload).
    await controller.selectGame(_game('gesture_game'));
    controller.playGame();
    controller.debugSetTopic('サーフィン');
    await _settle(tester);
    await binding.takeScreenshot('2_playing');
    controller.stopGame();
    await _settle(tester);

    // Favorites
    for (final id in ['word_wolf', 'black_stories', 'insider_game', 'ng_word', 'first_impression']) {
      await controller.toggleSave(_game(id));
    }
    await controller.selectGame(_game('black_stories'));
    await _settle(tester);
    await tester.tap(find.byIcon(CupertinoIcons.square_favorites_alt));
    await _settle(tester);
    await binding.takeScreenshot('4_favorites');

    // 3. All games with search (taken while the sheet is open; numbered for the store order)
    await tester.tap(find.text('すべて'));
    await _settle(tester);
    await binding.takeScreenshot('3_all_games');
    Navigator.of(tester.element(find.text('お気に入り'))).pop();
    await _settle(tester);

    // 5. "その場に合わせる" explanation (no permission prompt is shown yet)
    await tester.tap(find.text('その場に合わせる：オフ'));
    await _settle(tester);
    await binding.takeScreenshot('5_context');
    await tester.tap(find.text('今はしない'));
    await _settle(tester);
  });
}
