# Voice to Thino

音声メモをObsidianのThinoフォーマットで自動記録するHammerspoon設定。

Cmd + Shift + Z を長押しして話すだけで、音声が自動的に文字起こしされ、Obsidianのデイリーノートに記録されます。

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
brew install cmake
```

### 2. whisper.cpp のビルド

```bash
# ~/.local/share 以下にクローン
git clone https://github.com/ggml-org/whisper.cpp.git ~/.local/share/whisper.cpp
cd ~/.local/share/whisper.cpp

# ビルド (smallモデルを使用)
make -j small
```

### 3. Gemini API Key の設定 (オプション)

1. [Google AI Studio](https://aistudio.google.com/) にアクセス
2. API Keyを作成
3. `~/.zshenv` に環境変数を追加:

```bash
export REC2THINO_GEMINI_API_KEY="your-api-key-here"
```

### 4. init.lua の設定

`init.lua` ファイルを開き、以下の設定を環境に合わせて編集してください:

```lua
-- ツールのパス (デフォルトは ~/.local/share/whisper.cpp)
local WHISPER_PATH = os.getenv("HOME") .. "/.local/share/whisper.cpp/build/bin/whisper-cli"
local WHISPER_MODEL = os.getenv("HOME") .. "/.local/share/whisper.cpp/models/ggml-small.bin"

-- Obsidian設定
local OBSIDIAN_VAULT_PATH = os.getenv("HOME") .. "/Documents/Obsidian2"  -- Vaultのパス
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
dofile(os.getenv("HOME") .. "/Documents/workspace/voice-to-thino/init.lua")
```

### 6. Hammerspoon を再起動

環境変数を反映するため、Hammerspoonを **Quit → 再起動** してください。

## 使い方

1. **Cmd + Shift + Z** を長押し（0.5秒以上）→ 録音開始（音が鳴ります）
2. 話し終わったらキーを離す → 録音停止
3. 自動的に文字起こし → 校正 → Obsidianに保存

保存先: `{Vault}/{DAILY_DIR}/YYYY-MM-DD.md` の `# 📝 Notes` セクション

デイリーノートが存在しない場合は自動的に作成されます。

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
local HOTKEY_KEY = "z"  -- メインキー
local LONGPRESS_SEC = 0.5  -- 長押し判定の秒数
```

### Whisperモデルの変更

`small` モデルは精度とパフォーマンスのバランスが良いですが、より高精度な `medium` や `large` も使用できます:

```bash
cd ~/.local/share/whisper.cpp
./models/download-ggml-model.sh medium
```

### Gemini校正の無効化

Gemini APIを使用しない場合は、`processRecording` 関数内の `refineWithGemini` の呼び出しをコメントアウトしてください。

## トラブルシューティング

### 録音が開始されない

- Hammerspoonに「アクセシビリティ」と「マイク」の権限があるか確認
- システム設定 → プライバシーとセキュリティ → アクセシビリティ / マイク

### 文字起こしが失敗する

- Whisperのパスが正しいか確認
- Hammerspoonコンソールでエラーメッセージを確認

### Gemini校正が動かない

- 環境変数 `REC2THINO_GEMINI_API_KEY` が設定されているか確認
- Hammerspoonを **Quit → 再起動** して環境変数を再読み込み

### ログの確認

Hammerspoonコンソール（メニューバーアイコン → Console）でログを確認できます。

## 参考

- [【Obsidian × Whisper】音声メモ自動化システム](https://zenn.dev/ryosuke_kawata/articles/6d36289552039e)
- [Hammerspoon Documentation](https://www.hammerspoon.org/docs/)
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp)

## ライセンス

MIT
