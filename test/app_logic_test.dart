import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preplay/models/game_model.dart';
import 'package:preplay/state/app_state.dart';

import '../tool/gen_seed_sql.dart';

void main() {
  test('"次" never shows the same game twice in a row', () {
    final pool = GameModel.mvpGames.take(2).toList();
    final random = Random(1);
    var current = pool.first;
    for (var i = 0; i < 50; i++) {
      final next = PreplayController.pickNext(pool, current, random);
      expect(next.id, isNot(current.id));
      current = next;
    }
  });

  test('a single-game pool still returns that game', () {
    final pool = [GameModel.mvpGames.first];
    expect(PreplayController.pickNext(pool, pool.first, Random()).id, pool.first.id);
  });

  test('review is requested only after the 3rd, 10th and 30th finished game', () {
    final asked = [for (var i = 1; i <= 40; i++) if (PreplayController.shouldAskForReview(i)) i];
    expect(asked, [3, 10, 30]);
  });

  test('supabase/seed.sql is up to date with the bundled games', () {
    final file = File('supabase/seed.sql').readAsStringSync().trimRight();
    expect(file, seedSql().trimRight(), reason: 'run: dart run tool/gen_seed_sql.dart > supabase/seed.sql');
  });

  test('bundled games fit the database limits', () {
    for (final g in GameModel.mvpGames) {
      expect(g.title.length, inInclusiveRange(1, 60), reason: g.id);
      expect(g.rules.length, inInclusiveRange(1, 1000), reason: g.id);
      expect(g.tags.length, lessThanOrEqualTo(10), reason: g.id);
      expect(g.topics.length, lessThanOrEqualTo(50), reason: g.id);
    }
  });
}
