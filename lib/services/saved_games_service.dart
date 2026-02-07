import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';

class SavedGamesService {
  static const String _key = 'preplay_saved_games_v2';
  
  Future<List<GameModel>> loadSavedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.map((item) => GameModel.fromJson(jsonDecode(item))).toList();
  }

  Future<void> saveGame(GameModel game) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    
    bool exists = list.any((item) {
      final decoded = jsonDecode(item);
      return decoded['id'] == game.id;
    });

    if (!exists) {
      list.add(jsonEncode(game.toJson()));
      await prefs.setStringList(_key, list);
    }
  }

  Future<void> removeGame(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    
    list.removeWhere((item) {
      final decoded = jsonDecode(item);
      return decoded['id'] == gameId;
    });
    
    await prefs.setStringList(_key, list);
  }

  Future<bool> isSaved(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.any((item) => jsonDecode(item)['id'] == gameId);
  }
  
  // Custom Topics Logic
  Future<List<String>> loadCustomTopics(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('custom_topics_$gameId') ?? [];
  }

  Future<void> addCustomTopic(String gameId, String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'custom_topics_$gameId';
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(topic)) {
      list.add(topic);
      await prefs.setStringList(key, list);
    }
  }
}
