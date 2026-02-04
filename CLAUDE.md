# Voice to Thino

音声メモをObsidianのThinoフォーマットで自動記録するHammerspoon設定。

## プロジェクト構成

```
voice-to-thino/
├── init.lua          # Hammerspoon設定ファイル（~/.hammerspoonにコピーまたはリンク）
├── CLAUDE.md         # このファイル
└── README.md         # セットアップ手順
```

## 技術スタック

- **Hammerspoon**: macOSオートメーション
- **SoX**: 音声録音
- **whisper.cpp**: ローカル文字起こし（日本語）
- **Gemini API**: テキスト校正（誤字修正、フィラー除去）
- **Obsidian**: ノート保存先（Thinoプラグイン形式）

## 動作フロー

1. `Cmd+Shift+A` 長押し → 録音開始
2. キーを離す → 録音停止
3. Whisperで文字起こし
4. Gemini APIで校正（オプション）
5. Obsidianデイリーノートの `# 📝 Notes` セクションに追記

## 設定項目（init.lua）

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `HOTKEY_MODS` | 修飾キー | `{"cmd", "shift"}` |
| `HOTKEY_KEY` | メインキー | `"a"` |
| `LONGPRESS_SEC` | 長押し判定秒数 | `0.5` |
| `SOX_PATH` | SoXのパス | `/opt/homebrew/bin/sox` |
| `WHISPER_PATH` | whisper-cliのパス | 要設定 |
| `WHISPER_MODEL` | Whisperモデルのパス | 要設定 |
| `GEMINI_API_KEY` | Gemini APIキー | 要設定 |
| `OBSIDIAN_VAULT_PATH` | Obsidian Vaultのパス | 要設定 |
| `OBSIDIAN_DAILY_DIR` | デイリーノートのディレクトリ | `diary` |

## 開発時の注意

- Hammerspoonのコンソール（`Cmd+Option+Ctrl+H`）でログ確認
- 設定変更後は `hs.reload()` で再読み込み
- デイリーノートは事前に作成されている必要あり（Obsidianのデイリーノート機能を使用推奨）

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
