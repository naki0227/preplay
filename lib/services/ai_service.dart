import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/game_model.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  String? _backendUrl;
  String? _apiSecret;

  void init() {
    _backendUrl = dotenv.env['BACKEND_URL'];
    _apiSecret = dotenv.env['API_SECRET'];
    
    if (_backendUrl == null || _backendUrl!.isEmpty) {
      print('BACKEND_URL is not set in .env');
    }
  }

  Future<GameModel?> generateGame(List<String> contextTags) async {
    if (_backendUrl == null || _backendUrl!.isEmpty) {
      print('Backend URL not configured.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/generate'),
        headers: {
          'Content-Type': 'application/json',
          if (_apiSecret != null && _apiSecret!.isNotEmpty)
            'Authorization': 'Bearer $_apiSecret',
        },
        body: jsonEncode({
          'tags': contextTags,
          'groupSize': 2, // Default group size
        }),
      );

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
