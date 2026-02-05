import 'dart:math';

enum UserSituation {
  waitingInLine, // Default: Standing, specific location
  seatedCafe,    // Seated, quiet
  walking,       // Moving (should probably suggest "nothing" or simple verbal)
  boringHome,    // Home, seated/lying
}

class SituationService {
  // In a real app, this would use geolocator, sensors_plus, and record.
  
  Future<UserSituation> detect() async {
    // 擬似的な遅延（センサー読み込み風）
    // UI側の0.5秒と合わせる必要はないが、非同期であることを保つ
    await Future.delayed(const Duration(milliseconds: 200));

    // MVPではランダム、または時間帯によって「それっぽい」判定を返す
    final hour = DateTime.now().hour;
    
    // デモ用ロジック:
    // 1. 昼間 (10:00 - 18:00) -> 列待ち or カフェ
    // 2. 夜 (18:00 - 22:00) -> カフェ or 家
    // 3. その他 -> 家

    if (hour >= 10 && hour < 18) {
      return Random().nextBool() ? UserSituation.waitingInLine : UserSituation.seatedCafe;
    } else if (hour >= 18 && hour < 22) {
      return UserSituation.seatedCafe;
    } else {
      return UserSituation.boringHome;
    }
  }

  List<String> getTagsForSituation(UserSituation situation) {
    switch (situation) {
      case UserSituation.waitingInLine:
        return ['standing', 'noisy', 'short_time'];
      case UserSituation.seatedCafe:
        return ['seated', 'table', 'quiet', 'conversation'];
      case UserSituation.walking:
        return ['walking', 'verbal_only']; // Very restricted
      case UserSituation.boringHome:
        return ['seated', 'lying', 'long_time'];
    }
  }
}
