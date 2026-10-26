import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../services/saved_games_service.dart';
import '../services/community_service.dart';
import '../services/ai_service.dart';

class GameRepository {
  final SavedGamesService _savedGamesService = SavedGamesService();
  final CommunityService _communityService = CommunityService();
  final AiService _aiService = AiService();
  
  List<GameModel> _savedGames = [];
  List<GameModel> _communityGames = [];
  
  List<GameModel> get savedGames => _savedGames;
  List<GameModel> get communityGames => _communityGames;
  
  String? _communityError;
  String? get communityError => _communityError;

  // Set when the list shown is the copy saved on the device (e.g. offline).
  String? _communityNotice;
  String? get communityNotice => _communityNotice;

  Future<void> loadSavedGames() async {
    // Favorites saved by older versions lack people / time; use the bundled copy.
    final bundled = {for (final g in GameModel.mvpGames) g.id: g};
    _savedGames = [
      for (final g in await _savedGamesService.loadSavedGames()) bundled[g.id] ?? g,
    ];
  }

  static const _communityCacheKey = 'preplay_community_cache';

  static const _hiddenKey = 'preplay_hidden_community_games';

  Future<Set<String>> _hiddenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_hiddenKey) ?? []).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Loads "みんなの遊び". When the network fails, shows the list saved on
  /// the device last time instead of an empty screen.
  Future<void> loadCommunityGames() async {
    _communityError = null;
    _communityNotice = null;
    var result = await _communityService.fetchCommunityGames();
    if (result != null) {
      await _saveCommunityCache(result);
    } else {
      result = await _loadCommunityCache();
      if (result == null) {
        _communityError = '読み込めませんでした。インターネットにつながっているか確かめてください。';
        return;
      }
      _communityNotice = '読み込めなかったため、前回読み込んだ内容を表示しています';
    }
    final hidden = await _hiddenIds();
    _communityGames = result.where((g) => !hidden.contains(g.id)).toList();
  }

  Future<void> _saveCommunityCache(List<GameModel> games) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_communityCacheKey, jsonEncode([for (final g in games) g.toJson()]));
    } catch (_) {}
  }

  Future<List<GameModel>?> _loadCommunityCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_communityCacheKey);
      if (raw == null) return null;
      return [for (final j in jsonDecode(raw) as List) GameModel.fromJson(j as Map<String, dynamic>)];
    } catch (_) {
      return null;
    }
  }

  /// Reports a community game and hides it on this device right away,
  /// even if the report could not be sent.
  Future<void> reportGame(GameModel game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hidden = await _hiddenIds()..add(game.id);
      await prefs.setStringList(_hiddenKey, hidden.toList());
    } catch (_) {}
    _communityGames = _communityGames.where((g) => g.id != game.id).toList();
    await _communityService.reportGame(game.id);
  }

  Future<bool> shareGame(GameModel game) async {
    final success = await _communityService.submitGame(game);
    if (success) {
      await loadCommunityGames();
    }
    return success;
  }
  
  Future<void> toggleSave(GameModel game) async {
    final isAlreadySaved = _savedGames.any((g) => g.id == game.id);
    if (isAlreadySaved) {
      await _savedGamesService.removeGame(game.id);
      _savedGames.removeWhere((g) => g.id == game.id);
    } else {
      await _savedGamesService.saveGame(game);
      _savedGames.add(game);
    }
  }

  bool isSaved(String gameId) {
    return _savedGames.any((g) => g.id == gameId);
  }
  
  bool isGameShared(GameModel game) {
    return _communityGames.any((g) => g.title == game.title && g.rules == game.rules);
  }
  
  Future<List<String>> loadCustomTopics(String gameId) async {
    return await _savedGamesService.loadCustomTopics(gameId);
  }
  
  Future<void> addCustomTopic(String gameId, String topic) async {
    await _savedGamesService.addCustomTopic(gameId, topic);
  }
  
  /// Throws [AiException] when no game could be made.
  Future<GameModel> generateAiGame(List<String> tags) {
    return _aiService.generateGame(tags);
  }

  Future<bool> rateAiGame(GameModel game, {required bool good}) {
    return _communityService.sendAiFeedback(game, good: good);
  }
}
