# Preplay 障害調査と復旧（2026-10）

調査日: 2026-10-20 / 対象: App Store 公開版 1.0（bundle id `com.preplay.preplay`、2026-03-20 公開）
連絡先: contact@enludus.com

## 調べたこと

- App Store の公開情報: `https://itunes.apple.com/lookup?bundleId=com.preplay.preplay&country=jp`
  - version `1.0`、sellerUrl `https://enludus.vercel.app`
- バックエンド（Vercel プロジェクト `preplay`、本番 `https://preplay-five.vercel.app`）
  - `GET /api/health` → 200（キーは設定済み）
  - `POST /api/generate` → **500**、`GET /api/games` → **500**
  - ランタイムログ: どちらも `@upstash/redis` の `internal error`
  - 連携ストア `preplay-kv`（Upstash for Redis）: **「Archived due to inactivity」**
  - 環境変数 `GEMINI_API_KEY` は 2026-02-06 に作られてから変わっていない（値は見ていない）
- Supabase: アクセスできる組織に Preplay 用のプロジェクトが見つからない（他アプリのプロジェクトだけ）
- ビルド: Flutter 3.47.7 / Dart 3.13.5（2026-10 時点の stable）、Node 22
  - 修正前: `flutter test` が失敗（`.env` アセットがないとビルドできない、テストが存在しない `MyApp` を参照）
- Git 履歴: キーの値はコミットされていない。ただし 2026-02-06 の `908d305` より前は、アプリが同梱 `.env` から `GEMINI_API_KEY` を読んでいた

## 壊れているところ一覧

| # | 症状 | 原因 | 直し方 | 状態 |
|---|---|---|---|---|
| 1 | 「AIで生成」が必ず失敗し、普通の提案に戻る | Upstash Redis（レート制限用）が非アクティブでアーカイブされた。レート制限の呼び出しが例外を投げ、Gemini を呼ぶ前に 500 になる | Redis に繋がらないときは、インスタンス内メモリのレート制限に切り替えて処理を続ける（`backend/api/index.ts`） | **直した**（要再デプロイ → A） |
| 2 | Redis を戻さないとレート制限が弱い | #1 と同じ | Upstash DB の復元または作り直し | **オーナーの作業待ち → B** |
| 3 | Redis が直っても AI 生成が失敗する | モデル `gemini-1.5-flash` は提供終了 | Gemini REST API を直接呼ぶ形にし、モデルを `gemini-3.1-flash-lite` に変更。`GEMINI_MODEL` 環境変数で変えられるようにした。非推奨の `@google/generative-ai` SDK を外した | **直した**（要再デプロイ → A） |
| 4 | Gemini キーが失効している可能性が高い | 流出したキーは無効化済み。Vercel の `GEMINI_API_KEY` は 2026-02-06 から更新されていない | 新しいキーを発行し、Vercel だけに設定する | **オーナーの作業待ち → C** |
| 5 | キーの流出経路 | 2026-02-06 以前、アプリは `.env` をアセットとして同梱し、そこから `GEMINI_API_KEY` を読んでいた。同梱した `.env` は IPA から誰でも取り出せる。公開版 1.0 も `.env` を同梱している | `.env` の同梱と `flutter_dotenv` をやめた。アプリには `--dart-define-from-file` で公開してよい値（バックエンド URL、Supabase URL/anon key）だけを渡す。Gemini キーはバックエンドだけに置く | **直した** |
| 6 | `/api/health` がキーの先頭 10 文字を公開している | `keyPreview` を返していた | 削除。`hasApiKey` と `model` だけを返す | **直した**（要再デプロイ → A） |
| 7 | アプリが `API_SECRET` を送っている | バックエンドは検証しておらず、アプリに入れた値は秘密にならない | アプリから削除。README と `.env.example` からも削除 | **直した** |
| 8 | 「みんなの遊び」が読み込めない（「読み込みに失敗しました」） | Supabase の Preplay 用プロジェクトが、アクセスできる組織に見つからない（削除、一時停止、または別アカウントにある可能性） | アプリ側: Supabase の設定がないときや初期化に失敗したときでも落ちないようにした（下の #9） | **オーナーの作業待ち → D** |
| 9 | Supabase の設定がないとアプリが起動直後に落ちる | `CommunityService` が、初期化されていない `Supabase.instance.client` に触れていた | 初期化されていないときは `null` として扱い、機能を無効にする | **直した** |
| 10 | ビルドとテストが通らない | `.env` が必須のアセット。テストがテンプレートのまま（`MyApp`） | #5 の対応で `.env` が不要になった。テストを書き直した | **直した** |
| 11 | 共有テキストのリンクが `https://example.com/preplay (仮)` | 仮の値が残っていた | App Store の URL `https://apps.apple.com/jp/app/preplay/id6758872014` にした | **直した** |
| 12 | 「Preplayについて」の表示が `Version 1.5.0` | 固定の文字列が古かった | `Version 2.0.1` にした | **直した** |
| 13 | AI の応答に Markdown が入ると、タイトルの読み取りが崩れる | 新しいモデルは `**ゲーム名:**` のように太字を付けることがある | バックエンドで `* # `` ` を取り除き、プロンプトでもプレーンテキストを指定した | **直した** |
| 14 | App Store の販売元 URL が旧サイト | sellerUrl が `https://enludus.vercel.app` | App Store Connect で `https://enludus.com` に変える | **オーナーの作業待ち → E** |
| 15 | Preplay 専用のプライバシーポリシーページがない | `https://enludus.com/privacy` はサイト全体のポリシーで、各アプリのポリシーは「当該製品のポリシー」を見るよう書かれている。`/preplay` は 404 | `PRIVACY_POLICY.md` を更新した（連絡先をメールに変更、Gemini への送信を明記）。公開とURL設定は E | **オーナーの作業待ち → E** |
| 16 | 開発環境のメモ | iOS の IPA は Linux ではビルドできない | macOS と最新の Xcode でビルドする | **オーナーの作業待ち → F** |

`/api/games`（Redis に保存するコミュニティ API）は、アプリからは使われていません（アプリは Supabase を使っています）。Redis が戻るまで 500 を返しますが、今回は触っていません。

## オーナーの作業手順

### A. バックエンドの再デプロイ（この PR をマージした後）

```bash
cd backend
npm ci
npm run typecheck && npm test
vercel --prod          # Vercel プロジェクト "preplay"
```

確認:

```bash
curl https://preplay-five.vercel.app/api/health
# => {"status":"ok","hasApiKey":true,"model":"gemini-3.1-flash-lite"}   ← keyPreview が出ないこと
curl -X POST https://preplay-five.vercel.app/api/generate \
  -H 'Content-Type: application/json' -d '{"tags":["quiet"],"groupSize":2}'
# => {"game":"ゲーム名: ...\n遊び方: ..."}
```

公開中の 1.0 も同じ `/api/generate` を呼んでいます。そのため A と C が済めば、アプリを更新していない人の AI 生成も直ります。

### B. Upstash Redis（レート制限）を戻す

1. Vercel ダッシュボード → Storage → `preplay-kv` を開く（状態: Archived due to inactivity）
2. Vercel の表示どおり、Upstash Redis の DB を新しく作る（Vercel ダッシュボードから）。そのあと Upstash コンソールの inactive databases で旧 DB を **Restore** する。または、新しい DB を `preplay` プロジェクトにつなぎ直す
3. `KV_REST_API_URL` / `KV_REST_API_TOKEN` が `preplay` に入っていることを確認し、再デプロイする
4. 無料プランの DB は、使われないと再びアーカイブされます。今回の修正で、アーカイブされても AI 生成は止まりません（インスタンスごとの簡易制限で動きます）

### C. Gemini API キーを作り直す（重要）

1. Google AI Studio（https://aistudio.google.com/apikey）で、古い Preplay 用キーがあれば **削除** する。そのうえで新しいキーを発行する。キーの制限は「Generative Language API のみ」にする
2. Vercel → `preplay` → Settings → Environment Variables で `GEMINI_API_KEY` を新しい値に置き換える（Production / Preview）。値はチャットやリポジトリに貼らない
3. 必要なら `GEMINI_MODEL` を設定する（既定値は `gemini-3.1-flash-lite`）。使えるモデルは https://ai.google.dev/gemini-api/docs/models で確認する。提供終了の予定は https://ai.google.dev/gemini-api/docs/deprecations で確認する
4. A を実行して、`/api/generate` が 200 を返すことを確かめる
5. 手元の Flutter プロジェクト直下に古い `.env` が残っていれば削除する。今後のビルドでは使いません。中に Gemini キーがあれば、それも失効させる

### D. Supabase（「みんなの遊び」）

1. Supabase ダッシュボードで、Preplay 用プロジェクトがどのアカウント・組織にあるかを確認する。公開版の `.env` にあった `SUPABASE_URL` のプロジェクトです
   - **一時停止中**なら Restore する
   - **削除済み**なら新しいプロジェクトを作り、`supabase_schema.sql` を SQL Editor で実行する
2. Project Settings → API で URL と anon (public) key を確認し、`config/app_config.json` に書く（このファイルは Git に入りません）
3. 無料プランは 7 日間使われないと一時停止します。公開を続けるなら、有料プランにするか定期的にアクセスするなどの対策を検討する
4. Supabase を用意できないまま提出しても、アプリは落ちません。「みんなの遊び」だけが「読み込みに失敗しました」と表示されます

### E. App Store Connect の情報

1. App 情報 → 販売元の Web サイト / サポート URL を `https://enludus.com` に変える
2. `PRIVACY_POLICY.md` の内容を公開する。たとえば `https://enludus.com/preplay/privacy` として公開し、App 情報の「プライバシーポリシー URL」に設定する
3. App のプライバシー（データの収集）の申告に、ユーザーが投稿するコンテンツと、AI 生成で状況タグを送ることが反映されているか確認する

### F. ビルドと提出

```bash
cp config/app_config.example.json config/app_config.json   # D で確認した値を入れる
flutter pub get
flutter test
cd ios && pod install && cd ..
flutter build ipa --dart-define-from-file=config/app_config.json
```

- macOS と最新の Xcode でビルドする（App Store は最新の SDK でのビルドを求めます）
- バージョンは **2.0.1 (10)**。公開版の 1.0 より大きくしてあります。以前に 2.0.0 のビルドをアップロードしていても重なりません。App Store Connect で新しいバージョン「2.0.1」を作ってから提出する
- `build/ios/ipa/*.ipa` を Transporter か Xcode Organizer でアップロードし、App Store Connect で提出する

## リリースノート案（日本語）

```
いくつかの不具合を修正しました。

・「AIで生成」が使えなくなっていた問題を修正しました
・安定性を改善しました
・遊びを共有するときのリンクを、App Store のページに変更しました
・アプリ内のバージョン表示を修正しました
```
