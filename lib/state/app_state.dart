import 'dart:math';
import 'package:flutter/foundation.dart';
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

  Future<void> startDetection() async {
    _state = PreplayState.detecting;
    notifyListeners();

    final minWait = Future.delayed(const Duration(milliseconds: 800));
    final contextFuture = _situationService.determineContext();
    
    final results = await Future.wait([minWait, contextFuture]);
    final detectedTags = results[1] as List<String>;
    
    _matchGameByContext(detectedTags);
  }

  Future<void> generateWithAI() async {
    _state = PreplayState.thinking;
    notifyListeners();

    final contextTags = await _situationService.determineContext();
    final generatedGame = await _gameRepository.generateAiGame(contextTags); // Via repo

    if (generatedGame != null) {
      _currentGame = generatedGame;
      _state = PreplayState.suggested;
    } else {
      next();
    }
    notifyListeners();
  }

  void _matchGameByContext(List<String> tags) {
    final availableGames = GameModel.mvpGames.where((game) {
      if (game.tags.contains('all')) return true;
      return tags.any((t) => game.tags.contains(t));
    }).toList();

    final pool = availableGames.isNotEmpty ? availableGames : GameModel.mvpGames;
    _currentGame = pool[Random().nextInt(pool.length)];
    _state = PreplayState.suggested;
    notifyListeners();
  }

  void next() {
    startDetection();
  }
  
  List<String> _customTopics = [];

  Future<void> selectGame(GameModel game) async {
    _currentGame = game;
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

  void stopGame() {
    _state = PreplayState.suggested;
    _currentTopic = null;
    notifyListeners();
  }

  void dismiss() {
    startDetection();
  }
}
