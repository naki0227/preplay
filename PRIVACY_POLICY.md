# プライバシーポリシー / Privacy Policy

**最終更新日 / Last Updated: 2026-10-26**

> 公開版は https://enludus.com/products/preplay-privacy です（App Store に載せている URL）。内容を変えるときは、両方を同じにしてください。
> The published version is https://enludus.com/products/preplay-privacy. Keep both in sync.

---

## 日本語版

### 1. はじめに
Preplay（以下「本アプリ」）は、ユーザーのプライバシーを尊重し、個人情報の保護に努めています。本プライバシーポリシーでは、本アプリがどのような情報を収集し、どのように使用するかについて説明します。

### 2. 収集する情報

位置情報・モーション・音声レベルは、アプリ内の「その場に合わせる」をオンにしたときだけ使います（初期状態はオフ）。

#### 2.1 位置情報（任意）
- **目的**: 移動速度を検知し、状況に合った遊びを提案するため
- **収集方法**: デバイスのGPSセンサー
- **保存**: サーバーには送信・保存されません（端末内のみで処理）

#### 2.2 モーションデータ（任意）
- **目的**: 歩行状態を検知して、立ち止まっているか歩いているかを判断するため
- **収集方法**: デバイスの加速度センサー
- **保存**: サーバーには送信・保存されません

#### 2.3 音声レベル（任意）
- **目的**: 周囲の騒音レベルを検知して、静かな場所か賑やかな場所かを判断するため
- **収集方法**: デバイスのマイク（音声は録音されません）
- **保存**: サーバーには送信・保存されません

#### 2.4 ユーザー投稿コンテンツ
- **目的**: 「みんなの遊び」機能でゲームを共有するため
- **収集方法**: ユーザーが自発的に投稿
- **保存**: Supabase（クラウドデータベース）に保存
- **通報**: 不適切な投稿を通報すると、対象の遊びの ID と日時だけを保存します（通報した人の情報は保存しません）

#### 2.5 AIによる遊びの生成
- **目的**: 「AIで生成」を使ったときに、状況に合った遊びを作るため
- **送信する情報**: 状況タグ（例:「静か」「歩いている」）と人数のみ。位置情報・音声そのものは送信しません
- **送信先**: 本アプリのサーバーを経由して Google Gemini API に送信されます
- **集計**: サーバーは、AI で遊びを作った回数を、日付と結果（成功・失敗など）ごとの数だけ記録します。誰が使ったかは記録しません

#### 2.6 AIが作った遊びの評価（任意）
- **目的**: AI が作る遊びを良くするため。評価の高い遊びは「みんなの遊び」に載せることがあります
- **送信する情報**: 👍 / 👎 を押したときに、その遊びの名前・遊び方・状況タグと評価のみ。端末やユーザーを特定する情報は送信しません
- **保存**: Supabase（クラウドデータベース）に保存

### 3. 情報の第三者提供
本アプリは、法令に基づく場合を除き、ユーザーの個人情報を第三者に提供しません。

### 4. データの保護
収集したデータは、業界標準の暗号化技術により保護されています。

### 5. お問い合わせ
プライバシーに関するご質問は、以下までご連絡ください：
- メール: contact@enludus.com

---

## English Version

### 1. Introduction
Preplay ("the App") respects user privacy and is committed to protecting personal information. This Privacy Policy explains what information we collect and how we use it.

### 2. Information We Collect

Location, motion and audio level are used only when "その場に合わせる" (match the situation) is turned on in the App. It is off by default.

#### 2.1 Location Data (Optional)
- **Purpose**: To detect movement speed and suggest appropriate games
- **Method**: Device GPS sensor
- **Storage**: Not sent or stored on servers (processed locally only)

#### 2.2 Motion Data (Optional)
- **Purpose**: To detect walking state (standing vs. walking)
- **Method**: Device accelerometer
- **Storage**: Not sent or stored on servers

#### 2.3 Audio Level (Optional)
- **Purpose**: To detect ambient noise level (quiet vs. noisy environment)
- **Method**: Device microphone (no audio is recorded)
- **Storage**: Not sent or stored on servers

#### 2.4 User-Generated Content
- **Purpose**: To share games via the "Community Games" feature
- **Method**: Voluntarily submitted by users
- **Storage**: Stored in Supabase (cloud database)
- **Reports**: When you report a post, only the game's ID and the time are stored (nothing about the reporter)

#### 2.5 AI Game Generation
- **Purpose**: To generate a game when you use the AI generation feature
- **Data sent**: Context tags only (e.g. "quiet", "walking") and group size. Raw location and audio are never sent
- **Recipient**: Sent via the App's server to the Google Gemini API
- **Counts**: The server records only how many generations succeeded or failed per day. Nothing about who used it is recorded

#### 2.6 Ratings of AI-made Games (Optional)
- **Purpose**: To improve the games the AI makes. Highly rated games may be added to "Community Games"
- **Data sent**: When you tap 👍 / 👎, only that game's name, rules, context tags and the rating. Nothing that identifies you or your device
- **Storage**: Stored in Supabase (cloud database)

### 3. Third-Party Sharing
We do not share personal information with third parties except as required by law.

### 4. Data Protection
Collected data is protected using industry-standard encryption.

### 5. Contact
For privacy-related inquiries, please contact us at:
- Email: contact@enludus.com

---

© 2026 Preplay. All rights reserved.
