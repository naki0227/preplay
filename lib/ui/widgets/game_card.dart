import 'package:flutter/cupertino.dart';
import '../../models/game_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class GameCard extends StatelessWidget {
  final GameModel game;

  const GameCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground, 
        borderRadius: BorderRadius.circular(20), // Softer corners
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            offset: Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            game.title,
            style: AppText.title,
            softWrap: true,
          ),
          const SizedBox(height: 8),
          Text(
            game.origin,
            style: AppText.caption,
          ),
          const SizedBox(height: 24),
          Text(
            game.rules,
            style: AppText.body,
            softWrap: true,
          ),
        ],
      ),
    );
  }
}
