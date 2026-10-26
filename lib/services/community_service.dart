import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_model.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  // Supabase is only initialized when SUPABASE_URL / SUPABASE_ANON_KEY are
  // provided at build time. Accessing Supabase.instance before that throws.
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<GameModel>?> fetchCommunityGames() async {
    final client = _client;
    if (client == null) return null;
    try {
      final response = await client
          .from('games')
          .select()
          .order('created_at', ascending: false)
          .limit(50); // Fetch top 50

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => GameModel.fromJson(json)).toList();
    } catch (e) {
      print('Community Fetch Error: $e');
      return null;
    }
  }

  Future<bool> submitGame(GameModel game) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('games').insert({
        'id': game.id,
        'title': game.title,
        'rules': game.rules,
        'origin': game.origin, // e.g. "User123" or "Anonymous"
        'tags': game.tags,
        'topics': game.topics,
      });
      return true;
    } catch (e) {
      print('Community Submit Error: $e');
      return false;
    }
  }

  /// Records a report. Games with enough reports are hidden for everyone by
  /// the select policy in supabase/migrations. Returns false on failure.
  Future<bool> reportGame(String gameId) async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('reports').insert({'game_id': gameId});
      return true;
    } catch (e) {
      print('Community Report Error: $e');
      return false;
    }
  }
}
