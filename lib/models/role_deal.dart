import 'dart:math';
import 'game_model.dart';

/// Secret roles and words for games where each player must see only their own
/// (ワードウルフ, インサイダー, マフィア). The phone is passed around and each
/// player looks at their card in turn.
class RoleDeal {
  /// What each player sees, in passing order.
  final List<String> cards;

  /// Shown at the end when the group asks for the answer.
  final String answer;

  const RoleDeal({required this.cards, required this.answer});

  static const _supported = {'word_wolf', 'insider_game', 'mafia'};

  static bool supports(GameModel game) => _supported.contains(game.id);

  /// Shown on the setup screen, e.g. "ウルフは1人".
  static String describe(GameModel game, int players) => switch (game.id) {
        'word_wolf' => 'ウルフは${wolfCount(players)}人',
        'insider_game' => 'マスター1人・インサイダー1人・庶民${players - 2}人',
        'mafia' => 'マフィア${mafiaCount(players)}人・市民${players - mafiaCount(players)}人（進行役は人数に入れません）',
        _ => '',
      };

  static int wolfCount(int players) => players >= 6 ? 2 : 1;
  static int mafiaCount(int players) => players <= 8 ? 2 : (players <= 11 ? 3 : 4);

  /// [topics] are the game's topics plus the user's own. For ワードウルフ only
  /// "A vs B" topics are used.
  static RoleDeal deal(GameModel game, int players, List<String> topics, Random random) {
    switch (game.id) {
      case 'word_wolf':
        final pairs = [
          for (final t in topics)
            if (splitPair(t) case final pair?) pair,
        ];
        final words = [...pairs[random.nextInt(pairs.length)]]..shuffle(random);
        final majority = words[0], wolf = words[1];
        final wolves = _pick(players, wolfCount(players), random);
        return RoleDeal(
          cards: [for (var i = 0; i < players; i++) 'あなたのお題\n${wolves.contains(i) ? wolf : majority}'],
          answer: 'ウルフ：${_numbers(wolves)}\n'
              'みんなのお題：$majority\nウルフのお題：$wolf',
        );
      case 'insider_game':
        final word = topics[random.nextInt(topics.length)];
        final picked = _pick(players, 2, random).toList()..shuffle(random);
        final master = picked[0], insider = picked[1];
        return RoleDeal(
          cards: [
            for (var i = 0; i < players; i++)
              if (i == master)
                'あなたは\nマスター\nお題：$word\nみんなに名乗り出て、質問に「はい／いいえ」で答えます'
              else if (i == insider)
                'あなたは\nインサイダー\nお題：$word\n正体がばれないように、みんなを答えに導きます'
              else
                'あなたは\n庶民\nマスターに質問して、お題を当てましょう',
          ],
          answer: 'インサイダー：${_numbers({insider})}\n'
              'マスター：${_numbers({master})}\nお題：$word',
        );
      case 'mafia':
        final mafia = _pick(players, mafiaCount(players), random);
        return RoleDeal(
          cards: [
            for (var i = 0; i < players; i++)
              mafia.contains(i)
                  ? 'あなたは\nマフィア\n市民にばれないように、仲間と協力します'
                  : 'あなたは\n市民\n話し合いで、マフィアを見つけ出します',
          ],
          answer: 'マフィア：${_numbers(mafia)}',
        );
    }
    throw ArgumentError('No roles for ${game.id}');
  }

  /// "うどん vs そば" (also "VS" or "対") → [うどん, そば]; null if not a pair.
  static List<String>? splitPair(String topic) {
    final parts = topic.split(RegExp(r'\s*(?:vs|VS|Vs|ｖｓ|対)\s*')).map((w) => w.trim()).toList();
    return parts.length == 2 && parts.every((w) => w.isNotEmpty) && parts[0] != parts[1] ? parts : null;
  }

  static Set<int> _pick(int players, int count, Random random) =>
      (List.generate(players, (i) => i)..shuffle(random)).take(count).toSet();

  static String _numbers(Set<int> players) => (players.toList()..sort()).map((i) => '${i + 1}番').join('、');
}
