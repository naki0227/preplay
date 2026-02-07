import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For Icons
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text('Preplayについて', style: AppText.heading.copyWith(fontSize: 24)),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildSection(
                    icon: Icons.access_time_filled, 
                    title: '待ち時間を「遊び」に',
                    description: 'Preplayは、ちょっとした空き時間や退屈な時間を、クリエイティブな遊びに変えるアプリです。',
                  ),
                  _buildSection(
                    icon: Icons.sensors, 
                    title: '空気を読みます',
                    description: '歩いているか、静かか、うるさいか。センサーが周囲の状況を察知して、今できる最適な遊びを提案します。',
                  ),
                  _buildSection(
                    icon: Icons.people, 
                    title: 'みんなの遊び',
                    description: '誰かが考えた新しい遊びを試したり、あなたが考案した遊びを世界にシェアすることもできます。',
                  ),
                  
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  
                  Text('開発者より', style: AppText.bodyBold),
                  const SizedBox(height: 8),
                  Text(
                    'このアプリは「スマホを見る時間を、顔を合わせる時間に変える」ことを目指して作られました。\n\n面白い遊びは、道具がなくても生まれます。\nぜひ、周りの人と笑い合ってください。',
                    style: AppText.body,
                  ),
                  
                  const SizedBox(height: 48),
                  Center(
                    child: Text('Version 1.5.0', style: AppText.caption),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyBold),
                const SizedBox(height: 4),
                Text(description, style: AppText.body.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
