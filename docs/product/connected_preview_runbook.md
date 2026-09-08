# 実接続プレビュー起動手順

QST-417は、ローカルUIモックと実接続レビューを混同しないための起動契約を定義する。実接続プレビューはSupabase Auth、Data API、Storage、Edge Functionsを利用し、ArcのGemini呼び出しは認証済みユーザーからサーバー側Edge Functionを経由する。

## 設定ファイル

設定ファイルはリポジトリ外へ置く。例: `$HOME/.questra/beta-preview.env`。

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=sb_publishable_<public-client-key>
```

`sb_secret_`、`service_role`、`GEMINI_API_KEY`、`OPENAI_API_KEY`はFlutterへ渡さない。Geminiの秘密値はSupabase Edge FunctionのSecretとしてのみ管理する。

## 起動

```powershell
$env:QUESTRA_PREVIEW_CONFIG = "$HOME/.questra/beta-preview.env"
pwsh -NoProfile -File tools/qst/run_connected_preview.ps1
```

ランチャーは次を実施する。

1. URLがHosted SupabaseのHTTPS URLであることを確認する。
2. キーがpublishableまたはlegacy anonであり、secret/service roleではないことを確認する。
3. Supabase AuthとData APIへ公開範囲のprobeを実行する。
4. 一時的な`dart-define-from-file`を作り、`APP_ENVIRONMENT=production`かつmock persistence無効でWeb版を起動する。
5. Flutter終了後、一時ファイルを削除する。

設定値自体はコンソールへ表示しない。`-ValidateOnly`で起動せず検証だけを実施できる。

## Gemini確認

公開probeだけではGemini応答品質を証明しない。アプリで認証済みになった後、Arcへ短い相談を送り、固定応答ではなくEdge Function由来の応答になること、thinking表示、失敗時の非テンプレート回復を確認する。GeminiキーをブラウザのNetwork、ログ、スクリーンショットへ含めない。

## 現在の配備差分

`docs/qst/BETA_SUPABASE_PROJECT.yaml`で`migrations.status`が`applied`でない場合、ローカル最新機能の一部は未配備である。起動成功を全機能の配備完了とは扱わない。認証済みの実操作、対象row ID、Edge Function traceを別の候補証跡として記録する。
