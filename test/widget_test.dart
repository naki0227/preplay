import 'package:flutter_test/flutter_test.dart';

import 'package:preplay/config/app_config.dart';
import 'package:preplay/models/game_model.dart';

void main() {
  test('backend URL points at the production backend by default', () {
    expect(AppConfig.backendUrl, startsWith('https://'));
    expect(AppConfig.backendUrl, isNot(contains('enludus.vercel.app')));
  });

  test('Supabase is enabled only when both values are passed at build time', () {
    expect(
      AppConfig.hasSupabase,
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty,
    );
    if (AppConfig.hasSupabase) {
      expect(AppConfig.supabaseUrl, startsWith('https://'));
    }
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
