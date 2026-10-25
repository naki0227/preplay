import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_model.dart';
import '../data/game_repository.dart';
import '../services/situation_service.dart';

enum PreplayState { detecting, suggested, thinking, playing }

class PreplayController extends ChangeNotifier {
  PreplayState _state = PreplayState.detecting;
  GameModel? _currentGame;
  String? _currentTopic;
  
  final GameRepository _gameRepository = GameRepository();
  final SituationService _situationService = SituationService();
  
  bool _isCommunityLoading = false;

  // Context sensing (location / microphone / motion) is opt-in, so the first
  // launch shows a game right away instead of a row of permission prompts.
  static const _sensingKey = 'preplay_context_sensing';
  static const _playsKey = 'preplay_completed_plays';
  bool _contextSensing = false;
  bool get contextSensing => _contextSensing;

  // Shown under the suggestion when AI generation fails; cleared on the next action.
  String? _aiError;
  String? get aiError => _aiError;
  
  PreplayState get state => _state;
  GameModel? get currentGame => _currentGame;
  String? get currentTopic => _currentTopic;
  
  // Delegate to Repository
  List<GameModel> get savedGames => _gameRepository.savedGames;
  List<GameModel> get communityGames => _gameRepository.communityGames;
  String? get communityError => _gameRepository.communityError;
  bool get isCommunityLoading => _isCommunityLoading;

  PreplayController() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _contextSensing = prefs.getBool(_sensingKey) ?? false;
    } catch (_) {}
    await _gameRepository.loadSavedGames();
    loadCommunityGames();
    startDetection();
  }

  Future<void> loadCommunityGames() async {
    _isCommunityLoading = true;
    notifyListeners();
    await _gameRepository.loadCommunityGames();
    _isCommunityLoading = false;
    notifyListeners();
  }

  Future<bool> shareGame(GameModel game) async {
    final success = await _gameRepository.shareGame(game);
    notifyListeners();
    return success;
  }

  Future<void> reportGame(GameModel game) async {
    await _gameRepository.reportGame(game);
    notifyListeners();
  }

  bool isGameShared(GameModel game) {
    return _gameRepository.isGameShared(game);
  }

  Future<void> toggleSave(GameModel game) async {
    await _gameRepository.toggleSave(game);
    notifyListeners();
  }

  bool isSaved(String gameId) {
    return _gameRepository.isSaved(gameId);
  }

  // --- Core Game Logic ---

  /// Turns context sensing on (asking for permissions after the user agreed)
  /// or off. Returns the resulting state.
  Future<bool> setContextSensing(bool enabled) async {
    if (enabled) {
      enabled = await _situationService.requestPermissions();
    }
    _contextSensing = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sensingKey, enabled);
    } catch (_) {}
    notifyListeners();
    startDetection();
    return enabled;
  }

  Future<List<String>> _currentTags() async {
    if (!_contextSensing) return ['all'];
    return _situationService.determineContext();
  }

  Future<void> startDetection() async {
    _state = PreplayState.detecting;
    _aiError = null;
    notifyListeners();

    final minWait = Future.delayed(const Duration(milliseconds: 800));
    final contextFuture = _currentTags();
    
    final results = await Future.wait([minWait, contextFuture]);
    final detectedTags = results[1] as List<String>;
    
    _matchGameByContext(detectedTags);
  }

  Future<void> generateWithAI() async {
    _state = PreplayState.thinking;
    _aiError = null;
    notifyListeners();

    final contextTags = await _currentTags();
    final generatedGame = await _gameRepository.generateAiGame(contextTags); // Via repo

    if (generatedGame != null) {
      _currentGame = generatedGame;
    } else {
      // Keep the current game and say why nothing changed.
      _aiError = 'AIがうまく遊びを作れませんでした。少し待ってからもう一度試してください。';
    }
    _state = PreplayState.suggested;
    notifyListeners();
  }

  void _matchGameByContext(List<String> tags) {
    // Without sensing (or with only the neutral tag) every game is a candidate.
    final neutral = tags.every((t) => t == 'all');
    final availableGames = neutral
        ? GameModel.mvpGames
        : GameModel.mvpGames.where((game) {
            if (game.tags.contains('all')) return true;
            return tags.any((t) => game.tags.contains(t));
          }).toList();

    _currentGame = pickNext(
      availableGames.isNotEmpty ? availableGames : GameModel.mvpGames,
      _currentGame,
      Random(),
    );
    _state = PreplayState.suggested;
    notifyListeners();
  }

  /// Picks a random game, never the one currently shown (unless it is the only one).
  @visibleForTesting
  static GameModel pickNext(List<GameModel> pool, GameModel? current, Random random) {
    final candidates = pool.length > 1 ? pool.where((g) => g.id != current?.id).toList() : pool;
    return candidates[random.nextInt(candidates.length)];
  }

  void next() {
    startDetection();
  }
  
  List<String> _customTopics = [];

  Future<void> selectGame(GameModel game) async {
    _currentGame = game;
    _aiError = null;
    _state = PreplayState.suggested;
    _currentTopic = null;
    
    _customTopics = await _gameRepository.loadCustomTopics(game.id); // Via repo
    notifyListeners();
  }

  Future<void> addTopic(String topic) async {
    if (_currentGame == null) return;
    await _gameRepository.addCustomTopic(_currentGame!.id, topic); // Via repo
    _customTopics.add(topic);
    _currentTopic = topic;
    notifyListeners();
  }

  void playGame() {
    if (_currentGame == null) return;
    _pickRandomTopic();
    _state = PreplayState.playing;
    notifyListeners();
  }

  void rerollTopic() {
    if (_currentGame == null) return;
    _pickRandomTopic();
    notifyListeners();
  }
  
  void _pickRandomTopic() {
    if (_currentGame == null) return;
    final allTopics = [...(_currentGame!.topics), ..._customTopics];
    
    if (allTopics.isEmpty) {
      _currentTopic = null;
      return;
    }
    
    String newTopic;
    int retry = 0;
    do {
      newTopic = allTopics[Random().nextInt(allTopics.length)];
      retry++;
    } while (newTopic == _currentTopic && allTopics.length > 1 && retry < 3);
    
    _currentTopic = newTopic;
  }

  /// "終わり": counts finished games and asks for a review now and then.
  /// iOS decides whether the prompt is actually shown (at most 3 times a year).
  Future<void> finishGame() async {
    stopGame();
    try {
      final prefs = await SharedPreferences.getInstance();
      final plays = (prefs.getInt(_playsKey) ?? 0) + 1;
      await prefs.setInt(_playsKey, plays);
      if (shouldAskForReview(plays)) {
        final review = InAppReview.instance;
        if (await review.isAvailable()) await review.requestReview();
      }
    } catch (_) {}
  }

  /// Ask after the 3rd, 10th and 30th finished game: people who keep playing.
  @visibleForTesting
  static bool shouldAskForReview(int completedPlays) => const {3, 10, 30}.contains(completedPlays);

  void stopGame() {
    _state = PreplayState.suggested;
    _currentTopic = null;
    notifyListeners();
  }

  void dismiss() {
    startDetection();
  }
}
