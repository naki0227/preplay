import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:preplay/models/game_model.dart';
import 'package:preplay/models/role_deal.dart';
import 'package:preplay/services/ai_service.dart';
import 'package:preplay/ui/widgets/role_deal_screen.dart';

const _detective = GameModel(
  id: 'ai_1',
  title: '秘密の探偵',
  origin: 'AI (all)',
  rules: '探偵が犯人を探す。',
  tags: ['all'],
  topics: ['りんご', 'みかん'],
  roles: [
    DealRole(name: '探偵', count: 1, seesTopic: true, hint: '質問して犯人を探す'),
    DealRole(name: '犯人', count: 1, seesTopic: false, hint: 'ばれないように話を合わせる'),
    DealRole(name: '市民', count: 0, seesTopic: true, hint: '探偵を助ける'),
  ],
);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('AI game with topics and roles from the backend', () async {
    final game = await AiService().generateGame(['quiet'], client: MockClient((_) async => _json({
          'game': 'ゲーム名: 秘密の探偵\n遊び方: 探偵が犯人を探す。',
          'title': '秘密の探偵',
          'rules': '探偵が犯人を探す。',
          'topics': ['りんご', 'みかん'],
          'roles': [for (final r in _detective.roles) r.toJson()],
        })));
    expect(game.title, '秘密の探偵');
    expect(game.topics, ['りんご', 'みかん']);
    expect(game.roles.map((r) => r.name), ['探偵', '犯人', '市民']);
    expect(RoleDeal.supports(game), isTrue);
  });

  test('broken roles from the backend: the game is still played, without roles', () async {
    final game = await AiService().generateGame(['quiet'], client: MockClient((_) async => _json({
          'title': 't', 'rules': 'r', 'topics': [], 'roles': [{'name': 1}],
        })));
    expect(game.roles, isEmpty);
    expect(RoleDeal.supports(game), isFalse);
  });

  test('roles survive saving to favorites', () {
    final back = GameModel.fromJson(jsonDecode(jsonEncode(_detective.toJson())) as Map<String, dynamic>);
    expect(back.roles.map((r) => r.toJson()), _detective.roles.map((r) => r.toJson()));
    expect(GameModel.fromJson({'id': 'x', 'title': 't', 'origin': 'o', 'rules': 'r', 'tags': []}).roles, isEmpty);
  });

  test('dealing AI roles: fixed roles once, everyone else the rest; topic only for roles that see it', () {
    expect(RoleDeal.playerRange(_detective), (3, 12));
    expect(RoleDeal.describe(_detective, 5), '探偵1人・犯人1人・市民3人');
    for (var seed = 0; seed < 20; seed++) {
      final d = RoleDeal.deal(_detective, 5, _detective.topics, Random(seed));
      expect(d.cards.where((c) => c.startsWith('あなたは\n探偵\n')), hasLength(1));
      expect(d.cards.where((c) => c.startsWith('あなたは\n犯人\n')), hasLength(1));
      expect(d.cards.where((c) => c.startsWith('あなたは\n市民\n')), hasLength(3));
      final topic = d.answer.split('お題：').last;
      expect(d.cards.firstWhere((c) => c.contains('\n犯人\n')), isNot(contains(topic)));
      expect(d.cards.where((c) => c.contains('お題：$topic')), hasLength(4));
      expect(d.answer, contains('探偵：'));
      expect(d.answer, contains('犯人：'));
    }
  });

  group('more topics', () {
    test('sends the game and existing topics; word wolf asks for pairs', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        expect(req.url.path, '/api/topics');
        return _json({'topics': ['うどん vs そば', '海 vs 山']});
      });
      final wolf = GameModel.mvpGames.firstWhere((g) => g.id == 'word_wolf');
      final got = await AiService().moreTopics(wolf, ['うどん vs そば'], client: client);
      expect(sent['pair'], isTrue);
      expect(sent['title'], 'ワードウルフ');
      expect(got, ['海 vs 山']); // nothing the user already has
    });

    test('errors say what happened', () async {
      final g = GameModel.mvpGames.firstWhere((g) => g.id == 'gesture_game');
      Future<AiFailure> failureOf(MockClient c) async {
        try {
          await AiService().moreTopics(g, g.topics, client: c);
        } on AiException catch (e) {
          return e.reason;
        }
        throw StateError('no error');
      }
      expect(await failureOf(MockClient((_) async => http.Response('', 429))), AiFailure.busy);
      expect(await failureOf(MockClient((_) async => throw http.ClientException('offline'))), AiFailure.offline);
      expect(await failureOf(MockClient((_) async => _json({'topics': g.topics}))), AiFailure.other); // nothing new
    });
  });

  testWidgets('AI roles can be dealt on an iPhone SE', (tester) async {
    tester.view.physicalSize = const Size(375, 667) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(CupertinoApp(home: RoleDealScreen(game: _detective, topics: _detective.topics)));
    expect(find.text('4人'), findsOneWidget);
    expect(find.text('探偵1人・犯人1人・市民2人'), findsOneWidget);
    await tester.tap(find.text('配る'));
    await tester.pump();
    await tester.tap(find.text('自分の役を見る'));
    await tester.pump();
    expect(find.text('あなたは'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
