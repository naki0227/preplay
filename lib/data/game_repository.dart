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
  
  Future<void> loadSavedGames() async {
    _savedGames = await _savedGamesService.loadSavedGames();
  }

  Future<void> loadCommunityGames() async {
    _communityError = null;
    final result = await _communityService.fetchCommunityGames();
    if (result == null) {
      _communityError = '読み込みに失敗しました';
    } else {
      _communityGames = result;
    }
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
  
  Future<GameModel?> generateAiGame(List<String> tags) async {
    return await _aiService.generateGame(tags);
  }
}
