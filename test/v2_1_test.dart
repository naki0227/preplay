import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:preplay/data/game_repository.dart';
import 'package:preplay/models/game_model.dart';
import 'package:preplay/services/ai_service.dart';
import 'package:preplay/state/app_state.dart';
import 'package:preplay/ui/widgets/all_games_list.dart';
import 'package:preplay/ui/widgets/game_suggestion_view.dart';

GameModel _game(String id) => GameModel.mvpGames.firstWhere((g) => g.id == id);

void main() {
  group('people / time', () {
    test('every bundled game has sensible people and time', () {
      for (final g in GameModel.mvpGames) {
        expect(g.minPlayers, isNotNull, reason: g.id);
        expect(g.minPlayers! >= 1 && g.minPlayers! <= g.maxPlayers!, isTrue, reason: g.id);
        expect(g.minutes! > 0, isTrue, reason: g.id);
      }
    });

    test('playInfo text', () {
      expect(_game('chaichen').playInfo, '2人・約3分');
      expect(_game('mafia').playInfo, '6〜15人・約20分');
      expect(GameModel.fromJson({'id': 'x', 'title': 't', 'origin': 'o', 'rules': 'r', 'tags': []}).playInfo, isNull);
    });

    test('filters by group size and time', () {
      final games = GameModel.mvpGames;
      final two = AllGamesList.filterGames(games, '', players: PlayerFilter.two);
      expect(two.map((g) => g.id), containsAll(['chaichen', 'renso_shiritori']));
      expect(two.map((g) => g.id), isNot(contains('mafia')));

      final six = AllGamesList.filterGames(games, '', players: PlayerFilter.sixPlus);
      expect(six.map((g) => g.id), contains('mafia'));
      expect(six.map((g) => g.id), isNot(contains('chaichen')));

      final quick = AllGamesList.filterGames(games, '', time: TimeFilter.five);
      expect(quick.every((g) => g.minutes! <= 5), isTrue);
      expect(quick.map((g) => g.id), isNot(contains('mafia')));

      final both = AllGamesList.filterGames(games, 'しりとり', players: PlayerFilter.threeToFive, time: TimeFilter.ten);
      expect(both, isNotEmpty);
      expect(both.every((g) => g.title.contains('しりとり') || g.rules.contains('しりとり')), isTrue);
    });

    test('old favorites get people / time from the bundled copy', () async {
      final old = Map.of(_game('word_wolf').toJson())
        ..remove('minPlayers')
        ..remove('maxPlayers')
        ..remove('minutes');
      SharedPreferences.setMockInitialValues({'preplay_saved_games_v2': [jsonEncode(old)]});
      final repo = GameRepository();
      await repo.loadSavedGames();
      expect(repo.savedGames.single.playInfo, '4〜8人・約10分');
    });
  });

  group('AI errors', () {
    Future<Object?> run(MockClient client) async {
      try {
        return await AiService().generateGame(['all'], client: client);
      } catch (e) {
        return e;
      }
    }

    test('no network → offline', () async {
      final r = await run(MockClient((_) async => throw http.ClientException('Failed host lookup')));
      expect((r as AiException).reason, AiFailure.offline);
    });

    test('429 → busy, 500 → other', () async {
      expect(((await run(MockClient((_) async => http.Response('', 429)))) as AiException).reason, AiFailure.busy);
      expect(((await run(MockClient((_) async => http.Response('', 500)))) as AiException).reason, AiFailure.other);
    });

    test('200 → game', () async {
      final r = await run(MockClient((_) async => http.Response(
            jsonEncode({'game': 'ゲーム名: テスト\n遊び方: ルール'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )));
      expect((r as GameModel).title, 'テスト');
      expect(r.rules, 'ルール');
    });

    test('messages say what to do', () {
      expect(PreplayController.aiErrorMessage(AiFailure.offline), contains('インターネット'));
      expect(PreplayController.aiErrorMessage(AiFailure.busy), contains('1分'));
    });
  });

  group('offline community list', () {
    test('shows the saved copy when loading fails', () async {
      final cached = jsonEncode([
        {'id': 'c1', 'title': '保存済み', 'origin': 'AI', 'rules': 'r', 'tags': ['all']},
      ]);
      SharedPreferences.setMockInitialValues({'preplay_community_cache': cached});
      final repo = GameRepository();
      await repo.loadCommunityGames(); // Supabase is not set up in tests → fails
      expect(repo.communityError, isNull);
      expect(repo.communityNotice, isNotNull);
      expect(repo.communityGames.single.title, '保存済み');
    });

    test('says so when there is nothing saved', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = GameRepository();
      await repo.loadCommunityGames();
      expect(repo.communityError, contains('インターネット'));
    });
  });

  testWidgets('AI games can be rated once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(375, 812) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final controller = PreplayController();
    const ai = GameModel(id: 'ai_1', title: 'AIの遊び', origin: 'AI (all)', rules: 'ルール', tags: ['all']);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: controller,
      child: const CupertinoApp(home: CupertinoPageScaffold(child: GameSuggestionView(game: ai))),
    ));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('この遊びはどうでしたか？'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('この遊びは良かった'));
    await tester.pump();
    expect(find.text('評価ありがとうございます'), findsOneWidget);
    expect(controller.isAiGameRated('ai_1'), isTrue);

    // Bundled games have no rating row.
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: controller,
      child: CupertinoApp(home: CupertinoPageScaffold(child: GameSuggestionView(game: _game('word_wolf')))),
    ));
    expect(find.text('この遊びはどうでしたか？'), findsNothing);
    expect(find.text('ワードウルフ'), findsOneWidget);
    expect(find.textContaining('4〜8人・約10分'), findsOneWidget);
  });
}
