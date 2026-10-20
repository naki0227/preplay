import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/game_model.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final String _backendUrl = AppConfig.backendUrl;

  Future<GameModel?> generateGame(List<String> contextTags) async {
    if (_backendUrl.isEmpty) {
      print('Backend URL not configured.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tags': contextTags,
          'groupSize': 2, // Default group size
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        print('Backend error: ${response.statusCode} - ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final gameText = data['game'] as String?;

      if (gameText == null) return null;

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
    } catch (e) {
      print('AI Gen Error: $e');
      return null;
    }
  }
}
