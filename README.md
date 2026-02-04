# Voice to Thino

音声メモをObsidianのThinoフォーマットで自動記録するHammerspoon設定。

Shift + Command + A を長押しして話すだけで、音声が自動的に文字起こしされ、Obsidianのデイリーノートに記録されます。

## 必要なもの

- macOS (Apple Silicon推奨)
- [Hammerspoon](https://www.hammerspoon.org/)
- [SoX](http://sox.sourceforge.net/)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
- [Gemini API Key](https://aistudio.google.com/) (オプション、テキスト校正用)
- [Obsidian](https://obsidian.md/) + デイリーノート設定

## セットアップ

### 1. 依存ツールのインストール

```bash
# Hammerspoon と SoX をインストール
brew install --cask hammerspoon
brew install sox
```

### 2. whisper.cpp のビルド

```bash
# リポジトリをクローン
git clone https://github.com/ggml-org/whisper.cpp.git
cd whisper.cpp

# ビルド (smallモデルを使用)
make -j small

# モデルをダウンロード
./models/download-ggml-model.sh small
```

ビルド後、以下のパスをメモしておいてください:
- `whisper.cpp/build/bin/whisper-cli` (または `whisper.cpp/main`)
- `whisper.cpp/models/ggml-small.bin`

### 3. Gemini API Key の取得 (オプション)

1. [Google AI Studio](https://aistudio.google.com/) にアクセス
2. API Keyを作成
3. キーをメモしておく

### 4. init.lua の設定

`init.lua` ファイルを開き、以下の設定を編集してください:

```lua
-- ツールのパス
local WHISPER_PATH = "/path/to/whisper.cpp/build/bin/whisper-cli"  -- whisper-cliのパス
local WHISPER_MODEL = "/path/to/whisper.cpp/models/ggml-small.bin"  -- モデルのパス

-- Gemini API設定
local GEMINI_API_KEY = "YOUR_GEMINI_API_KEY"  -- Gemini APIキー

-- Obsidian設定
local OBSIDIAN_VAULT_PATH = "/path/to/your/obsidian/vault"  -- Vaultのパス
local OBSIDIAN_DAILY_DIR = "diary"  -- デイリーノートのディレクトリ
```

### 5. Hammerspoon に配置

```bash
# 既存の設定をバックアップ
cp ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.backup

# 新しい設定をコピー
cp init.lua ~/.hammerspoon/init.lua
```

または、既存の `~/.hammerspoon/init.lua` に追記:

```lua
-- Voice to Thino を読み込み
dofile("/Users/hal/Documents/workspace/voice-to-thino/init.lua")
```

### 6. Hammerspoon を再読み込み

Hammerspoonのメニューバーアイコンをクリック → "Reload Config"

または、Hammerspoonコンソールで:
```lua
hs.reload()
```

## 使い方

1. **Cmd + Shift + A** を長押し（0.5秒以上）→ 録音開始（音が鳴ります）
2. 話し終わったらキーを離す → 録音停止
3. 自動的に文字起こし → 校正 → Obsidianに保存

保存先: `{Vault}/{DAILY_DIR}/YYYY-MM-DD.md` の `# 📝 Notes` セクション

## 出力形式

デイリーノートに以下の形式で追記されます:

```markdown
# 📝 Notes
- 10:30 朝のミーティングでプロジェクトの進捗を確認した
- 14:15 新しいアイデアを思いついた
```

## カスタマイズ

### ホットキーの変更

```lua
local HOTKEY_MODS = {"cmd", "shift"}  -- 修飾キー
local HOTKEY_KEY = "a"  -- メインキー
local LONGPRESS_SEC = 0.5  -- 長押し判定の秒数
```

### Whisperモデルの変更

`small` モデルは精度とパフォーマンスのバランスが良いですが、より高精度な `medium` や `large` も使用できます:

```bash
# mediumモデルをダウンロード
cd whisper.cpp
./models/download-ggml-model.sh medium
```

### Gemini校正の無効化

Gemini APIを使用しない場合は、`processRecording` 関数内の `refineWithGemini` の呼び出しをコメントアウトしてください。

## トラブルシューティング

### 録音が開始されない

- Hammerspoonに「アクセシビリティ」と「マイク」の権限があるか確認
- システム環境設定 → セキュリティとプライバシー → プライバシー

### 文字起こしが失敗する

- Whisperのパスが正しいか確認
- Hammerspoonコンソールでエラーメッセージを確認

### Obsidianに保存されない

- デイリーノートが存在するか確認（事前に作成が必要）
- `# 📝 Notes` セクションがあるか確認
- パスが正しいか確認

### ログの確認

Hammerspoonコンソール（メニューバーアイコン → Console）でログを確認できます。

## 参考

- [【Obsidian × Whisper】音声メモ自動化システム](https://zenn.dev/ryosuke_kawata/articles/6d36289552039e)
- [Hammerspoon Documentation](https://www.hammerspoon.org/docs/)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)

## ライセンス

MIT
