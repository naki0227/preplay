import 'package:shared_preferences/shared_preferences.dart';

class SavedGamesService {
  static const String _key = 'preplay_saved_games';
  
  // Singleton pattern for easy access if needed (though Provider is better)
  // For now, simple static methods or a simple class is fine.
  // Using a class to allow future dependency injection / testing.

  Future<List<String>> loadSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> saveId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(_key, list);
    }
  }

  Future<void> removeId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    if (list.contains(id)) {
      list.remove(id);
      await prefs.setStringList(_key, list);
    }
  }

  Future<bool> isSaved(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    return list.contains(id);
  }
}
