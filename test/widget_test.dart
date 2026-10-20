import 'package:flutter_test/flutter_test.dart';

import 'package:preplay/config/app_config.dart';
import 'package:preplay/models/game_model.dart';

void main() {
  test('backend URL points at the production backend by default', () {
    expect(AppConfig.backendUrl, startsWith('https://'));
    expect(AppConfig.backendUrl, isNot(contains('enludus.vercel.app')));
  });

  test('Supabase is disabled when no config is passed at build time', () {
    expect(AppConfig.hasSupabase, isFalse);
  });

  test('share link is the App Store page, not a placeholder', () {
    expect(AppConfig.appStoreUrl, startsWith('https://apps.apple.com/'));
  });

  test('bundled games have unique ids and non-empty rules', () {
    final ids = GameModel.mvpGames.map((g) => g.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final game in GameModel.mvpGames) {
      expect(game.title, isNotEmpty);
      expect(game.rules, isNotEmpty);
      expect(game.tags, isNotEmpty);
    }
  });

  test('GameModel survives a JSON round trip', () {
    final game = GameModel.mvpGames.first;
    final restored = GameModel.fromJson(game.toJson());
    expect(restored.id, game.id);
    expect(restored.topics, game.topics);
  });
}
