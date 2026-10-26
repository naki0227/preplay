# Preplay (Pre-Play) 🎮

> **"遊びを選ぶ"時間を、ゼロにする。**
> A context-aware ephemeral play suggester.

Preplayは、待ち時間や隙間時間に「何して遊ぶ？」と迷うストレスを解消し、その瞬間の状況（場所、時間、人数）に最適な「遊び」を0.8秒で提案するユーティリティアプリです。

![App Screenshot](https://via.placeholder.com/800x400?text=Preplay+App+Image)
*(※ここに実際のスクリーンショットを貼ってください)*

## ✨ Key Features (MVP)

*   **Zero-UI Design**: 起動した瞬間に提案。メニューやリストを探す必要はありません。
*   **0.8s Detection**: センサー検知（MVPではモック）の待機時間を可視化し、期待感を演出。
*   **Context Matching**: 「静か」「騒がしい」「立ったまま」などのタグで遊びをフィルタリング。
*   **Warm Paper Theme**: デジタル疲れを癒やす、クリーム色と丸文字（M PLUS Rounded 1c）の優しいデザイン。
*   **Stock Function**: お気に入りの遊びをローカルに保存（`shared_preferences`）。

## 🛠 Technical Stack

*   **Framework**: Flutter 3.x (Dart)
*   **State Management**: Provider (`PreplayController`)
*   **Persistence**: shared_preferences
*   **UI Components**: Cupertino (iOS-style), AnimatedSwitcher
*   **Font**: M PLUS Rounded 1c（`assets/fonts`、SIL OFL 1.1。アプリに同梱）
*   **Target**: macOS (Desktop), iOS

## 📂 Project Structure

```
lib/
├── main.dart            # Entry point
├── models/              # Game & Tag data models
├── services/            # Storage & Sensor logic
├── state/               # AppState (Provider)
├── theme/               # Colors & Typography
└── ui/
    ├── home_screen.dart # Main orchestrator
    └── widgets/         # DetectiveView, SuggestionView, etc.
```

## 🔧 Build

APIキーはアプリに入れません。Gemini のキーはバックエンド（`backend/`、Vercel）の環境変数だけに置きます。
アプリに渡すのは公開してよい値だけです。値は `config/app_config.json` に書いてあり（Git 管理）、`--dart-define-from-file` で渡します。
**このファイルに秘密の値（Gemini キー、Supabase の service_role / secret key、DB パスワード）を書かないこと。**

```bash
flutter pub get
flutter test
flutter build ipa --dart-define-from-file=config/app_config.json
```

| キー | 内容 |
|---|---|
| `BACKEND_URL` | バックエンドのURL（省略時 `https://preplay-five.vercel.app`） |
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | 「みんなの遊び」用。anon / publishable key は公開前提の値（RLSで保護） |

リリース（CI でのビルドと App Store Connect へのアップロード、ストア情報・スクリーンショット・Supabase の自動更新）: [docs/RELEASE.md](docs/RELEASE.md)

障害の調査結果と復旧手順: [docs/MAINTENANCE_2026-10.md](docs/MAINTENANCE_2026-10.md)

## 🚀 Future Roadmap (V2.0)

*   **Sensor Fusion**: GPS/加速度/マイクによるリアルタイム状況判定。
*   **Generative AI**: Google Gemini APIを用いた、「その場だけの遊び」の無限生成。
*   **Social**: "Played This" シェア機能。

## ✍️ Author / Portfolio
Developed by **[Your Name]** as part of the **Enludus** portfolio ecosystem.
