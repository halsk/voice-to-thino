# Voice to Thino

音声メモをObsidianのThinoフォーマットで自動記録するHammerspoon設定。

## プロジェクト構成

```
voice-to-thino/
├── init.lua              # Hammerspoon設定ファイル（~/.hammerspoonにコピーまたはリンク）
├── SPEC-wsl-server.md    # WSLサーバー版の仕様書
├── CLAUDE.md             # このファイル
└── README.md             # セットアップ手順
```

## 技術スタック

- **Hammerspoon**: macOSオートメーション
- **SoX**: 音声録音
- **whisper.cpp**: ローカル文字起こし（日本語、`~/.local/share/whisper.cpp`）
- **Gemini API**: テキスト校正（誤字修正、フィラー除去）
- **Obsidian**: ノート保存先（Thinoプラグイン形式）

## 動作フロー

1. `Cmd+Ctrl+Z` 長押し → 録音開始
2. キーを離す → 録音停止
3. Whisperで文字起こし
4. Gemini APIで校正（オプション）
5. Obsidianデイリーノートの `# 📝 Notes` セクションに追記
6. デイリーノートが未作成の場合は自動生成

## 設定項目（init.lua）

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `HOTKEY_MODS` | 修飾キー | `{"cmd", "ctrl"}` |
| `HOTKEY_KEY` | メインキー | `"z"` |
| `LONGPRESS_SEC` | 長押し判定秒数 | `0.5` |
| `SOX_PATH` | SoXのパス | `/opt/homebrew/bin/sox` |
| `WHISPER_PATH` | whisper-cliのパス | `~/.local/share/whisper.cpp/build/bin/whisper-cli` |
| `WHISPER_MODEL` | Whisperモデルのパス | `~/.local/share/whisper.cpp/models/ggml-small.bin` |
| `GEMINI_API_KEY` | Gemini APIキー | 環境変数 `REC2THINO_GEMINI_API_KEY` から取得 |
| `OBSIDIAN_VAULT_PATH` | Obsidian Vaultのパス | `~/Documents/Obsidian2` |
| `OBSIDIAN_DAILY_DIR` | デイリーノートのディレクトリ | `diary` |

## 開発時の注意

- Hammerspoonのコンソール（`Cmd+Option+Ctrl+H`）でログ確認
- 設定変更後は `hs.reload()` で再読み込み
- 環境変数の変更後はHammerspoonの **Quit → 再起動** が必要
- Gemini API Keyは環境変数 `REC2THINO_GEMINI_API_KEY` で管理（`~/.zshenv` に設定）

## Obsidian Thino形式

デイリーノートの `# 📝 Notes` セクションに以下の形式で追記:

```markdown
- HH:MM メモ内容
```

例:
```markdown
# 📝 Notes
- 10:30 朝のミーティングでプロジェクトの進捗を確認した
- 14:15 新しいアイデアを思いついた。UIの改善について検討する
```
