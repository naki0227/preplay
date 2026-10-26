import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/game_model.dart';

/// Why AI generation failed, so the app can say what to do next.
enum AiFailure { offline, busy, other }

class AiException implements Exception {
  final AiFailure reason;
  const AiException(this.reason);

  @override
  String toString() => 'AiException($reason)';
}

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final String _backendUrl = AppConfig.backendUrl;

  /// Throws [AiException] when no game could be made.
  Future<GameModel> generateGame(List<String> contextTags, {http.Client? client}) async {
    if (_backendUrl.isEmpty) {
      print('Backend URL not configured.');
      throw const AiException(AiFailure.other);
    }

    final http.Response response;
    try {
      final post = client?.post ?? http.post;
      response = await post(
        Uri.parse('$_backendUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tags': contextTags,
          'groupSize': 3, // roles need at least 3; the dealing screen asks the real number
        }),
      ).timeout(const Duration(seconds: 20));
    } on SocketException catch (e) {
      print('AI Gen Error: $e');
      throw const AiException(AiFailure.offline);
    } on http.ClientException catch (e) {
      // The default client wraps connection errors (no network, DNS) in ClientException.
      print('AI Gen Error: $e');
      throw const AiException(AiFailure.offline);
    } on TimeoutException catch (e) {
      print('AI Gen Error: $e');
      throw const AiException(AiFailure.other);
    }

    if (response.statusCode == 429) throw const AiException(AiFailure.busy);
    if (response.statusCode != 200) {
      print('Backend error: ${response.statusCode} - ${response.body}');
      throw const AiException(AiFailure.other);
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(AiFailure.other);
    }
    final id = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    final origin = 'AI (${contextTags.join(',')})';

    // 2.0.1+ backend: structured game with optional topics and roles.
    if (data['title'] is String && data['rules'] is String) {
      List<DealRole> roles;
      try {
        roles = [for (final r in (data['roles'] as List?) ?? const []) DealRole.fromJson(r as Map<String, dynamic>)];
      } catch (_) {
        roles = const []; // play it without roles rather than not at all
      }
      return GameModel(
        id: id,
        title: data['title'] as String,
        origin: origin,
        rules: data['rules'] as String,
        tags: contextTags,
        topics: [for (final t in (data['topics'] as List?) ?? const []) if (t is String) t],
        roles: roles,
      );
    }

    final gameText = data['game'] as String?;
    if (gameText == null) throw const AiException(AiFailure.other);

    // Parse the game text (format: "ゲーム名: ...\n---\n遊び方: ...")
    final titleMatch = RegExp(r'ゲーム名:\s*(.+)').firstMatch(gameText);
    final rulesMatch = RegExp(r'遊び方:\s*([\s\S]+?)(?:---|ポイント:|$)').firstMatch(gameText);

    return GameModel(
      id: id,
      title: titleMatch?.group(1)?.trim() ?? 'AIゲーム',
      origin: origin,
      rules: rulesMatch?.group(1)?.trim() ?? gameText,
      tags: contextTags,
    );
  }

  /// New topics for [game] that are not in [existing]. Throws [AiException].
  Future<List<String>> moreTopics(GameModel game, List<String> existing, {http.Client? client}) async {
    if (_backendUrl.isEmpty) throw const AiException(AiFailure.other);
    String clip(String s, int max) => s.length <= max ? s : s.substring(0, max);
    final http.Response response;
    try {
      final post = client?.post ?? http.post;
      response = await post(
        Uri.parse('$_backendUrl/api/topics'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': clip(game.title, 60),
          'rules': clip(game.rules, 1000),
          'topics': [for (final t in existing.take(80)) clip(t, 60)],
          'pair': game.id == 'word_wolf',
        }),
      ).timeout(const Duration(seconds: 20));
    } on SocketException {
      throw const AiException(AiFailure.offline);
    } on http.ClientException {
      throw const AiException(AiFailure.offline);
    } on TimeoutException {
      throw const AiException(AiFailure.other);
    }
    if (response.statusCode == 429) throw const AiException(AiFailure.busy);
    if (response.statusCode != 200) throw const AiException(AiFailure.other);
    try {
      final list = (jsonDecode(response.body) as Map<String, dynamic>)['topics'] as List;
      final out = [for (final t in list) if (t is String && !existing.contains(t)) t];
      if (out.isEmpty) throw const AiException(AiFailure.other);
      return out;
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException(AiFailure.other);
    }
  }
}
