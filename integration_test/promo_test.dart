// Promotion video for social media, recorded on a simulator by
// .github/workflows/promo-video.yml while this test plays the app in real time.
// Scene starts and taps are printed as "PREVIEW <epoch ms> <name>" so
// tool/make_promo.py can cut the recording, add captions and put the sound
// effects on the taps.
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

void _scene(String name) => print('PREVIEW ${DateTime.now().millisecondsSinceEpoch} $name');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Draw every frame as on a real phone, so the recording is smooth.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('promotion video', (tester) async {
    Future<void> hold(int ms) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      await tester.pump();
    }

    Future<void> tap(Finder finder, [int then = 700]) async {
      _scene('tap');
      await tester.tap(finder.first);
      await hold(then);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // first launch: sensing off, nothing saved
    await tester.pumpWidget(const PreplayApp());
    await hold(2500); // detecting animation, then the first suggestion
    final controller = tester.element(find.byType(HomeScreen)).read<PreplayController>();
    await controller.selectGame(_game('word_wolf'));
    await hold(1500); // let the recorder settle before the first scene

    // 1. A game right away; "次" shows another one.
    _scene('intro');
    await hold(1500);
    // "次" would show the short detecting screen; switch cards directly so
    // the opening keeps moving (with the tap sound on each change).
    for (final id in ['first_impression', 'black_stories', 'gesture_game']) {
      _scene('tap');
      await controller.selectGame(_game(id));
      await hold(850);
    }

    // 2. Word wolf: deal roles and topics by passing the phone.
    _scene('deal');
    await controller.selectGame(_game('word_wolf'));
    await hold(700);
    await tap(find.text('やる'), 1000);
    await tap(find.text('役とお題を配る'), 900);
    await tap(find.byIcon(CupertinoIcons.plus_circle), 600);
    await tap(find.text('配る'), 800);
    await tap(find.text('自分の役を見る'), 1500);
    await tap(find.text('隠して次の人へ'), 600);
    await tap(find.text('自分の役を見る'), 1300);
    await tap(find.text('閉じる'), 500);
    controller.stopGame();
    await hold(400);

    // 3. Find a game by group size and time.
    _scene('filter');
    await tap(find.byIcon(CupertinoIcons.square_favorites_alt), 450);
    await tap(find.text('すべて'), 800);
    await tap(find.text('3〜5人'), 800);
    await tap(find.text('5分以内'), 1000);
    await tester.drag(find.byType(CupertinoListTile).first, const Offset(0, -500));
    await hold(900);
    Navigator.of(tester.element(find.text('お気に入り'))).pop();
    await hold(500);

    // 4. Topics and the timer.
    _scene('topics');
    await controller.selectGame(_game('gesture_game'));
    await hold(500);
    await tap(find.text('やる'), 1100);
    await tap(find.byIcon(CupertinoIcons.refresh), 900);
    await tap(find.byIcon(CupertinoIcons.refresh), 900);
    await tap(find.text('1分'), 1500);

    // 5. End card.
    _scene('end');
    controller.stopGame();
    await controller.selectGame(_game('black_stories'));
    await hold(2600);
    _scene('done');
  });
}
