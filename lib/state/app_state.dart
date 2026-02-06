import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import '../services/saved_games_service.dart';
import '../services/situation_service.dart';
import '../services/ai_service.dart';

enum PreplayState { detecting, suggested, thinking } // Added "thinking"

class PreplayController extends ChangeNotifier {
  PreplayState _state = PreplayState.detecting;
  GameModel? _currentGame;
  final SavedGamesService _savedGamesService = SavedGamesService();
  final SituationService _situationService = SituationService();
  final AiService _aiService = AiService();
  List<String> _savedIds = [];
  
  PreplayState get state => _state;
  GameModel? get currentGame => _currentGame;
  List<String> get savedIds => _savedIds;

  PreplayController() {
    _loadSavedGames();
    startDetection();
  }

  Future<void> _loadSavedGames() async {
    _savedIds = await _savedGamesService.loadSavedIds();
    notifyListeners();
  }

  Future<void> toggleSave(String gameId) async {
    if (_savedIds.contains(gameId)) {
      await _savedGamesService.removeId(gameId);
      _savedIds.remove(gameId);
    } else {
      await _savedGamesService.saveId(gameId);
      _savedIds.add(gameId);
    }
    notifyListeners();
  }

  bool isSaved(String gameId) {
    return _savedIds.contains(gameId);
  }

  // 起動時や「次」の時にセンサー検知を走らせる
  Future<void> startDetection() async {
    _state = PreplayState.detecting;
    notifyListeners();

    // 0.8秒（0.5秒より少しゆったり）かけてセンサーを模倣... ではなく本当に取得！
    // 演出のための最低0.8秒 + 実際の処理時間
    final minWait = Future.delayed(const Duration(milliseconds: 800));
    final contextFuture = _situationService.determineContext();
    
    // 両方終わるのを待つ
    final results = await Future.wait([minWait, contextFuture]);
    final detectedTags = results[1] as List<String>;
    
    _matchGameByContext(detectedTags);
  }

  // AI Generation
  Future<void> generateWithAI() async {
    _state = PreplayState.thinking;
    notifyListeners();

    // Get real context again or use cached? Let's get fresh.
    final contextTags = await _situationService.determineContext();
    final generatedGame = await _aiService.generateGame(contextTags);

    if (generatedGame != null) {
      _currentGame = generatedGame;
      _state = PreplayState.suggested;
    } else {
      // Fallback if AI fails: just pick random
      next();
    }
    notifyListeners();
  }

  void _matchGameByContext(List<String> tags) {
    // タグにマッチするゲームをフィルタリング
    // tagsリストのいずれか1つでも持っていれば候補とする（OR条件）
    // ただし 'all' は常に許可
    final availableGames = GameModel.mvpGames.where((game) {
      if (game.tags.contains('all')) return true;
      return tags.any((t) => game.tags.contains(t));
    }).toList();

    // availableGamesが空の場合は全件から選ぶ安全策
    final pool = availableGames.isNotEmpty ? availableGames : GameModel.mvpGames;

    _currentGame = pool[Random().nextInt(pool.length)];
    _state = PreplayState.suggested;
    notifyListeners();
  }

  void next() {
    // 「次」も再度検知から始めることで、場所が変わった感を出せる
    startDetection();
  }
  
  void dismiss() {
    // 閉じる時も再度検知待機状態に戻す（アプリが眠るイメージ）
    startDetection();
  }
}
