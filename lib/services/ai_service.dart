import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/game_model.dart';
import 'situation_service.dart';

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  GenerativeModel? _model;

  void init() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey != null && apiKey != 'YOUR_API_KEY_HERE') {
      _model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
    } else {
      print('Gemini API Key missing or invalid.');
    }
  }

  Future<GameModel?> generateGame(List<String> contextTags) async {
    if (_model == null) {
      print('AI Model not initialized.');
      return null;
    }

    final prompt = '''
    Create a unique, short, equipment-free game logic for a group of people in this context: ${contextTags.join(', ')}.
    Output strictly in this JSON format (no markdown):
    {
      "title": "Game Title (Japanese)",
      "origin": "AI Generated",
      "rules": "3 lines of rules in Japanese. Short and punchy.",
      "tags": ["${contextTags.join('", "')}"]
    }
    ''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      final text = response.text;
      
      if (text == null) return null;

      // Simple parsing (robustness would need JSON parser, but for MVP/V2 prototype we do manual extraction or assume structure)
      // Since response might contain Markdown ```json ... ```, we clean it.
      final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      
      // We need a proper JSON parser, but let's try to pass it to a helper or just regex it for simplicity in prototype
      // Or simply return a GameModel with raw text if JSON fails.
      // For this "SpeedRun", let's use a regex to extract fields.
      
      final titleMatch = RegExp(r'"title":\s*"(.*?)"').firstMatch(cleanText);
      final rulesMatch = RegExp(r'"rules":\s*"(.*?)"').firstMatch(cleanText);
      
      if (titleMatch != null && rulesMatch != null) {
         return GameModel(
           id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
           title: titleMatch.group(1) ?? 'Unknown',
           origin: 'AI (${contextTags.join(',')})',
           rules: rulesMatch.group(1)?.replaceAll(r'\n', '\n') ?? '...',
           tags: contextTags,
         );
      }
      return null;
    } catch (e) {
      print('AI Gen Error: $e');
      return null;
    }
  }
}
