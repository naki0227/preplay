# リリースの手順（CI / CD）

| ワークフロー | いつ動くか | やること |
|---|---|---|
| `CI`（`.github/workflows/ci.yml`） | PR と main への push | アプリの analyze・test、バックエンドの typecheck・test、ストア同期ツールの test |
| `iOS release`（`ios-release.yml`） | **手動のみ** | IPA をビルドする。「upload」にチェックを入れると、App Store Connect（TestFlight）へアップロードする |
| `App Store metadata`（`appstore-metadata.yml`） | `appstore/` を変える PR と、main への push、手動 | `appstore/metadata.yaml` の内容を App Store Connect に反映する。PR では差分を表示するだけ（dry run）。main に入ると反映する |

**審査への提出は自動化していません。** 最後は App Store Connect の画面で「審査へ提出」を押します。

## 最初に一度だけやること

### 1. App Store Connect の API キーを作る

1. https://appstoreconnect.apple.com/access/integrations/api を開く
2. 「Team Keys」でキーを作る。アクセス権は **Admin** にする
   - ビルドの署名（証明書とプロファイルを自動で作る）に Admin が要ります。ストア情報の更新だけなら App Manager で足ります
3. 次の 3 つを控える
   - **Key ID**
   - **Issuer ID**（キー一覧の上に表示されます）
   - **.p8 ファイル**（ダウンロードは 1 回しかできません）

### 2. GitHub の Secrets に登録する

https://github.com/naki0227/preplay/settings/secrets/actions → 「New repository secret」で、次の 3 つを登録する。

| 名前 | 値 |
|---|---|
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | .p8 ファイルの中身を全部（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで） |

.p8 ファイルとその中身は、Git やチャットに貼らないでください。登録したら、手元の .p8 は安全な場所に保管するか削除します。

## リリースの流れ

1. `pubspec.yaml` の `version` と、`appstore/metadata.yaml` の `version.versionString` を上げる（テストで一致を確認しています）
2. リリースノート（`whatsNew`）など、ストアの文面を `appstore/metadata.yaml` で直す
3. PR を作る → 「App Store metadata」のログで、何が変わるかを確認する
4. main にマージする → ストアの情報が反映される。そのバージョンがまだなければ「提出準備中」で作られる
5. Actions → 「iOS release」→ Run workflow
   - まず「upload」のチェックなしで実行して、ビルドが通るか確かめる（IPA は Artifacts に 7 日残ります）
   - 通ったら「upload」にチェックを入れて実行する。ビルド番号は実行した日時（UTC）から自動で決まります
6. App Store Connect で、アップロードしたビルドをバージョンに選び、「審査へ提出」を押す

## 補足

- **GitHub Actions の macOS ランナーは時間がかかります。** 1 回のビルドで 20〜30 分ほどです。プライベートリポジトリだと、無料枠を Linux の 10 倍の速さで使います。このリポジトリは公開なので、無料で使えます
- `appstore/metadata.yaml` に書いた項目だけを変えます。書いていない項目（キーワード、スクリーンショット、価格など）には触りません
- 公開中のバージョンの文面は Apple の仕様で編集できません。新しいバージョンを作ってから反映されます
