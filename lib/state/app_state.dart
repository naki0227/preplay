import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import '../services/saved_games_service.dart';

enum PreplayState { detecting, suggested }

class PreplayController extends ChangeNotifier {
  PreplayState _state = PreplayState.detecting;
  GameModel? _currentGame;
  final SavedGamesService _savedGamesService = SavedGamesService();
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

    // 0.8秒（0.5秒より少しゆったり）かけてセンサーを模倣
    await Future.delayed(const Duration(milliseconds: 800));

    _matchGameBySituation();
  }

  void _matchGameBySituation() {
    // 【モックロジック】本来はここでGPSや時間、騒音レベルを取得
    // 例：現在は「18:00」「静かな場所」と仮定
    const mockSituation = 'quiet'; 

    final availableGames = GameModel.mvpGames.where((game) {
      // 状況タグに合致するもの、または全状況OKなものをフィルタリング
      return game.tags.contains(mockSituation) || game.tags.contains('all');
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
