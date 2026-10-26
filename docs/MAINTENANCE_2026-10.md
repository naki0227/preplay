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
| 2 | Redis を戻さないとレート制限が弱い | #1 と同じ | Upstash DB の復元または作り直し | **直した**（2026-10-25: Redis をやめた。下の B） |
| 3 | Redis が直っても AI 生成が失敗する | モデル `gemini-1.5-flash` は提供終了 | Gemini REST API を直接呼ぶ形にし、モデルを `gemini-3.1-flash-lite` に変更。`GEMINI_MODEL` 環境変数で変えられるようにした。非推奨の `@google/generative-ai` SDK を外した | **直した**（要再デプロイ → A） |
| 4 | Redis を迂回しても AI 生成が 500 | 再デプロイ後の確認で、Gemini API が **402 RESOURCE_EXHAUSTED「prepayment credits are depleted」** を返した。キーは認証を通り、モデル名も通っている。止まっている原因はキーの失効ではなく、前払いクレジットの残高切れ | AI Studio でクレジットを補充する。キーは 2026-02-06 から変わっていないので、作り直しも勧める | **直した**（2026-10-25: 新しいキーを Secret で登録し直し、クレジットを補充。本番の `/api/generate` が 200 を返し、アプリと同じ書式で読み取れることを確認） |
| 5 | キーの流出経路 | 2026-02-06 以前、アプリは `.env` をアセットとして同梱し、そこから `GEMINI_API_KEY` を読んでいた。同梱した `.env` は IPA から誰でも取り出せる。公開版 1.0 も `.env` を同梱している | `.env` の同梱と `flutter_dotenv` をやめた。アプリには `--dart-define-from-file` で公開してよい値（バックエンド URL、Supabase URL/anon key）だけを渡す。Gemini キーはバックエンドだけに置く | **直した** |
| 6 | `/api/health` がキーの先頭 10 文字を公開している | `keyPreview` を返していた | 削除。`hasApiKey` と `model` だけを返す | **直した**（要再デプロイ → A） |
| 7 | アプリが `API_SECRET` を送っている | バックエンドは検証しておらず、アプリに入れた値は秘密にならない | アプリから削除。README と `.env.example` からも削除 | **直した** |
| 8 | 「みんなの遊び」が読み込めない（「読み込みに失敗しました」） | Supabase の Preplay 用プロジェクトが、アクセスできる組織に見つからない（削除、一時停止、または別アカウントにある可能性） | アプリ側: Supabase の設定がないときや初期化に失敗したときでも落ちないようにした（下の #9）。2026-10-25: 会社用アカウントで新しいプロジェクトを作り直し、当時の `supabase_schema.sql`（今の `supabase/migrations/20261025000000_initial.sql`）を適用した。公開キーで読み込み（200）と投稿の権限を確認済み | **直した**（新しい値で 2.0.1 をビルドする → F） |
| 9 | Supabase の設定がないとアプリが起動直後に落ちる | `CommunityService` が、初期化されていない `Supabase.instance.client` に触れていた | 初期化されていないときは `null` として扱い、機能を無効にする | **直した** |
| 10 | ビルドとテストが通らない | `.env` が必須のアセット。テストがテンプレートのまま（`MyApp`） | #5 の対応で `.env` が不要になった。テストを書き直した | **直した** |
| 11 | 共有テキストのリンクが `https://example.com/preplay (仮)` | 仮の値が残っていた | App Store の URL `https://apps.apple.com/jp/app/preplay/id6758872014` にした | **直した** |
| 12 | 「Preplayについて」の表示が `Version 1.5.0` | 固定の文字列が古かった | `Version 2.0.1` にした | **直した** |
| 13 | AI の応答に Markdown が入ると、タイトルの読み取りが崩れる | 新しいモデルは `**ゲーム名:**` のように太字を付けることがある | バックエンドで `* # `` ` を取り除き、プロンプトでもプレーンテキストを指定した | **直した** |
| 14 | App Store の販売元 URL が旧サイト | sellerUrl が `https://enludus.vercel.app` | App Store Connect で `https://enludus.com` に変える | **オーナーの作業待ち → E** |
| 15 | Preplay 専用のプライバシーポリシーページがない | `https://enludus.com/privacy` はサイト全体のポリシーで、各アプリのポリシーは「当該製品のポリシー」を見るよう書かれている。`/preplay` は 404 | `PRIVACY_POLICY.md` を更新した（連絡先をメールに変更、Gemini への送信を明記）。公開とURL設定は E | **オーナーの作業待ち → E** |
| 16 | 開発環境のメモ | iOS の IPA は Linux ではビルドできない | macOS と最新の Xcode でビルドする | **オーナーの作業待ち → F** |
| 17 | 「その場に合わせる」（状況検知）が動いていなかった | `permission_handler` は Podfile で使う権限を宣言しないと、iOS では常に「拒否」を返す。宣言がなく、位置情報とマイクが一度も使えていなかった | `ios/Podfile` に `PERMISSION_LOCATION_WHENINUSE` / `PERMISSION_MICROPHONE` を追加 | **直した** |
| 18 | 初回起動でいきなり位置情報とマイクの許可を聞かれる | 起動時のセンサー確認で許可を要求していた | 状況検知はオフで始め、「その場に合わせる」をオンにしたときに説明してから許可を求める（設定は保存） | **直した** |
| 19 | 「閉じる」ボタンが反応しない | iOS ではアプリが自分で終了できない（`SystemNavigator.pop` は無視される） | ボタンを外した | **直した** |
| 20 | 「次」で待たされることがある | GPS の取得に時間の上限がなかった | 1.5 秒で打ち切る | **直した** |
| 21 | 「次」で同じ遊びが続けて出る | 今の遊びを候補から外していなかった | 直前と同じ遊びは選ばない | **直した** |
| 22 | AI 生成の失敗に気づけない | 失敗すると黙って別の提案に変わっていた。待ち時間の表示も「10秒」と実際とずれていた | 失敗をその場で表示。表示は「数秒」に | **直した** |
| 23 | 起動のたびに公式の遊び 42 件を書き込もうとしていた | アプリから毎回 upsert（2 回目以降は権限エラー） | アプリからの書き込みをやめ、`supabase/seed.sql` で 1 回だけ入れる | **直した**（CI が自動で反映。Secret の登録 → D） |
| 24 | 「みんなの遊び」に何でも書き込める・通報できない | 公開キーで直接書き込めて、長さの制限も通報の仕組みもなかった（App Store ガイドライン 1.2） | 文字数の制限、通報（「…」→ 通報）、通報 3 件で全員の画面から非表示、通報した遊びは自分の画面から即非表示 | **直した**（CI が自動で反映。Secret の登録 → D） |
| 25 | iPad で横に間延びする | 幅の上限がなかった | カードの幅を最大 560 にした | **直した** |
| 26 | 評価が集まりにくい | レビューをお願いする導線がない | 遊びを 3・10・30 回終えたときに iOS 標準のレビュー依頼（表示回数は iOS が制限） | **直した** |
| 27 | ストアのスクリーンショットが古く、必須の 6.9 インチがない | 2 月に手で撮ったもののみ | CI（`App Store screenshots`）でシミュレーターから自動で撮る（iPhone 6.9 インチ・iPad 13 インチ） | **直した** |
| 28 | 知っている遊びを選べない | ランダムに出るのを待つしかなかった | 「すべて」タブで 42 種類を一覧・検索できるようにした | **直した** |
| 29 | 時間を区切る遊び（ワードウルフなど）で別のタイマーが要る | 遊び中の画面にタイマーがなかった | 1・3・5 分のタイマー（終わるとバイブで知らせる） | **直した** |
| 30 | VoiceOver でボタンの意味が読まれない | アイコンだけのボタンに名前がなかった | お気に入り・共有・公開・その他・やめる・別のお題などに読み上げ名を付けた | **直した** |
| 31 | Supabase の SQL を手で実行する必要があった | 仕組みがなかった | `supabase/migrations` を CI で自動適用（PR では使い捨て Postgres でテスト＋本番は dry run） | **直した**（Secret `SUPABASE_DB_URL` の登録 → D） |
| 32 | 起動のたびにフォントを Google からダウンロードしていた | `google_fonts` が実行時にフォントを取りに行く。オフラインだと別のフォントになり、通信に失敗すると例外も出る（スクリーンショットの CI もこれで落ちた）。プライバシーポリシーにも書かれていない通信だった | フォント（Medium・Bold・ExtraBold、約 10 MB）をアプリに同梱し、`google_fonts` を外した。ライセンス（OFL）も同梱 | **直した** |

`/api/games`（Redis に保存するコミュニティ API）は、アプリからは使われていなかったので、2026-10-25 に Redis と一緒に削除しました（アプリは Supabase を使っています）。

## オーナーの作業手順

### A. バックエンドの再デプロイ

**2026-10-20 実施済み**: この PR のブランチ（`67c888e`）の `backend/` を、本番（`preplay-five.vercel.app`、デプロイ `dpl_73psZ38RdxpuJM8zYJ38XpxTssPL`）に出した。確認した結果:
- `/api/health` → 200 `{"status":"ok","hasApiKey":true,"model":"gemini-3.1-flash-lite"}`（`keyPreview` は出なくなった）
- `/api/generate` → Redis の障害は迂回して Gemini まで届いた。Gemini が 402（クレジット切れ）を返すため、まだ 500（→ C）
- `/api/games` → 500（Redis がアーカイブされたまま → B。アプリからは使われていない）

PR をマージした後に出し直す場合の手順:

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

### B. Redis（レート制限）

**2026-10-25: Redis を使うのをやめた。** Vercel Marketplace 経由で作った Upstash は、普段の Upstash アカウントからは見えず、管理しにくいため。

- レート制限は、各インスタンスのメモリ上で行う（IP ごとに 60 秒 10 回まで）
- インスタンスをまたいだ制限ではないので、**費用の上限は AI Studio の「Monthly spend cap」で守る**（C を参照）
- Redis を使っていた `/api/games` も削除した（アプリからは使われていなかった）
- Vercel の Storage にある古い `preplay-kv` は、もう使わないので削除してよい: https://vercel.com/nakis-projects-d1ae2531/preplay/stores

### API の保護（2026-10-25）

`/api/generate` は認証なしで誰でも呼べる。アプリに入れた秘密は取り出せるので、アプリと共有する鍵では守れない。代わりに次の 3 つで、使われ方と費用を絞っている。

1. **入力を固定の値だけにする**: `tags` はアプリが送る 7 語（all / active / noisy / quiet / standing / waiting / walking）だけ、`groupSize` は 1〜20 だけ受け付ける。自由な文章はプロンプトに入らないので、汎用の AI として使うことはできない（それ以外は 400）
2. **回数の制限**: IP ごとに 60 秒 10 回まで（インスタンスごと）
3. **費用の上限**: AI Studio の Monthly spend cap（$5）。超えるとその月は AI 生成が止まるだけで、請求は増えない

もっと強く守りたい場合は、iOS の App Attest で「本物のアプリからのリクエストか」を確かめる方法がある。アプリとバックエンドの両方に手を入れる必要があり、公開中の 1.0 からは AI 生成が使えなくなる。

### C. Gemini のクレジット補充とキーの作り直し（重要）

0. **月の上限（Monthly spend cap）を設定する**: AI Studio の Spend ページ →「Monthly spend cap」→「Edit spend cap」で **$5** などにする。Redis をやめたので、これが費用の上限になる
0. **まずクレジットを補充する**: https://ai.studio/projects で、Preplay のキーが属しているプロジェクトの Billing を開き、前払いクレジットを追加する（または支払い方法を見直す）。補充すれば、今のキーのままでも AI 生成が動きます。予算アラートを設定しておくと安心です
   - クレジットが想定より早く減っていたら、キーが不正に使われた可能性があります。同じ画面の使用量を確認し、下の手順でキーを作り直してください

1. Google AI Studio（https://aistudio.google.com/apikey）で、古い Preplay 用キーがあれば **削除** する。そのうえで新しいキーを発行する。キーの制限は「Generative Language API のみ」にする
2. Vercel → `preplay` → Settings → Environment Variables で `GEMINI_API_KEY` を新しい値に置き換える（Production / Preview）。値はチャットやリポジトリに貼らない
3. 必要なら `GEMINI_MODEL` を設定する（既定値は `gemini-3.1-flash-lite`）。使えるモデルは https://ai.google.dev/gemini-api/docs/models で確認する。提供終了の予定は https://ai.google.dev/gemini-api/docs/deprecations で確認する
4. A を実行して、`/api/generate` が 200 を返すことを確かめる
5. 手元の Flutter プロジェクト直下に古い `.env` が残っていれば削除する。今後のビルドでは使いません。中に Gemini キーがあれば、それも失効させる

### D. Supabase（「みんなの遊び」）

**マイグレーションは CI（`Supabase` ワークフロー）が自動で当てる。** 手で SQL を実行する必要はない。

- `supabase/migrations/*.sql` のうち、まだ当てていないものを名前順に 1 つずつ（それぞれトランザクションで）当て、最後に `supabase/seed.sql`（公式の遊び 42 件）を入れる。当てた記録は `preplay_meta.applied_migrations` に残る（API からは見えない）
- PR では、まず使い捨ての Postgres で全部当てて、もう一度当てても何も起きないこと、権限のルール（`supabase/tests/policies.sql`）が守られていることを確認する。そのあと本番 DB に対して dry run（何が当たるかの表示だけ）
- main に入ると本番 DB に当てる

**最初に一度だけ: GitHub Secrets に `SUPABASE_DB_URL` を登録する**
1. Supabase のダッシュボードで Preplay のプロジェクトを開き、上部の「Connect」を押す
2. 「**Session pooler**」の接続文字列（`postgresql://postgres.<ref>:[YOUR-PASSWORD]@aws-...pooler.supabase.com:5432/postgres`）をコピーし、`[YOUR-PASSWORD]` をプロジェクト作成時のデータベースのパスワードに置き換える（GitHub Actions は IPv6 の Direct connection に繋がらないので、Session pooler を使う）
3. https://github.com/naki0227/preplay/settings/secrets/actions の「Repository secrets」に、名前 `SUPABASE_DB_URL` で登録する。チャットには貼らない

確認: アプリの「みんなの遊び」に公式の遊びが並び、「…」→「不適切な内容として通報」ができること。
通報の確認は SQL Editor で `select game_id, count(*) from reports group by 1 order by 2 desc;`。

### E. App Store Connect の情報

`appstore/metadata.yaml` で管理し、CD（`App Store metadata` ワークフロー）で反映する形にした。中身:

- サポート URL・マーケティング URL → `https://enludus.com`（旧 `enludus.vercel.app` から変更）
- プライバシーポリシー URL → `https://enludus.com/products/preplay-privacy`（2026-10-26 に GitHub のページから移した）
- 2.0.1 のリリースノート、説明文（公開中と同じ文面）

オーナーの作業: [docs/RELEASE.md](RELEASE.md) の「最初に一度だけやること」（API キーを作り、GitHub Secrets に登録する）。そのあと、この PR をマージすれば反映される。

- App のプライバシー（データの収集）の申告は API で管理していないので、App Store Connect の画面で確認する。ユーザー投稿と、AI 生成で状況タグを送ることが入っているか

### F. ビルドと提出

GitHub Actions の「iOS release」でビルドし、App Store Connect にアップロードできるようにした。手順は [docs/RELEASE.md](RELEASE.md)。

- バージョンは **2.0.1**。ビルド番号は実行日時から自動で決まる
- 審査への提出は App Store Connect の画面で行う

手元の Mac でビルドする場合:

```bash
flutter pub get && flutter test
flutter build ipa --dart-define-from-file=config/app_config.json
```

## リリースノート

`appstore/metadata.yaml` の `whatsNew` が正です（main に入ると App Store Connect に反映されます）。
