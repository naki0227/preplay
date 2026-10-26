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
          'groupSize': 2, // Default group size
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

    final String? gameText;
    try {
      gameText = jsonDecode(response.body)['game'] as String?;
    } catch (_) {
      throw const AiException(AiFailure.other);
    }
    if (gameText == null) throw const AiException(AiFailure.other);

    // Parse the game text (format: "ゲーム名: ...\n---\n遊び方: ...")
    final titleMatch = RegExp(r'ゲーム名:\s*(.+)').firstMatch(gameText);
    final rulesMatch = RegExp(r'遊び方:\s*([\s\S]+?)(?:---|ポイント:|$)').firstMatch(gameText);

    return GameModel(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      title: titleMatch?.group(1)?.trim() ?? 'AIゲーム',
      origin: 'AI (${contextTags.join(',')})',
      rules: rulesMatch?.group(1)?.trim() ?? gameText,
      tags: contextTags,
    );
  }
}
