# Voice to Thino: WSLサーバー仕様書

iPhoneから音声メモを録音し、WSL上で文字起こし・校正を行い、ObsidianのThino形式でデイリーノートに記録するAPIサーバー。

## アーキテクチャ

```
iPhone (ショートカット)
    │ 音声ファイル (m4a/wav) を POST
    │ Tailscale経由
    ▼
WSL サーバー (FastAPI)
    │ 1. 音声ファイル受信・保存
    │ 2. whisper.cpp で文字起こし (日本語)
    │ 3. Gemini API で校正
    │ 4. Obsidian デイリーノートに追記
    │ 5. git commit & push
    ▼
Mac (git pull で同期)
    → Obsidian が変更を検知
```

## 技術スタック

- **Python 3.11+** / **FastAPI**
- **whisper.cpp**: WSL上にもビルドが必要
- **Gemini API** (`gemini-2.0-flash`): テキスト校正
- **Git**: Obsidian Vaultの同期

## API仕様

### `POST /voice`

音声ファイルを受け取り、文字起こし・校正・Obsidianへの保存を行う。

**Request:**
- Content-Type: `multipart/form-data`
- Body:
  - `audio`: 音声ファイル (m4a, wav, mp3 等)

**Response:**
```json
{
  "status": "ok",
  "raw_text": "元の文字起こしテキスト",
  "refined_text": "校正後のテキスト",
  "saved_to": "diary/2026-02-03.md"
}
```

**Error Response:**
```json
{
  "status": "error",
  "message": "エラーの説明"
}
```

### `GET /health`

ヘルスチェック用。

**Response:**
```json
{
  "status": "ok",
  "whisper": true,
  "vault": true
}
```

## ディレクトリ構成

```
voice-to-thino-server/
├── server.py          # FastAPI サーバー本体
├── config.py          # 設定ファイル
├── requirements.txt   # Python依存パッケージ
├── transcribe.py      # whisper.cpp 呼び出し
├── refine.py          # Gemini API 校正
├── obsidian.py        # Obsidian デイリーノート操作
├── CLAUDE.md          # このプロジェクトのコンテキスト
└── tmp/               # 一時ファイル置き場 (gitignore)
```

## 設定項目 (config.py)

```python
# whisper.cpp
WHISPER_CLI_PATH = "/path/to/whisper-cli"       # WSL上のwhisper-cliパス
WHISPER_MODEL_PATH = "/path/to/ggml-small.bin"  # モデルパス

# Gemini API
GEMINI_API_KEY = "YOUR_API_KEY"
GEMINI_MODEL = "gemini-2.0-flash"

# Obsidian Vault (WSL上のgit clone先)
VAULT_PATH = "/path/to/obsidian-vault"
DAILY_DIR = "diary"  # デイリーノートのディレクトリ

# サーバー
HOST = "0.0.0.0"
PORT = 8765
```

## 各モジュールの詳細仕様

### transcribe.py

whisper.cppのCLIを呼び出して文字起こしを行う。

```python
def transcribe(audio_path: str) -> str:
    """
    音声ファイルをwhisper.cppで文字起こしする。

    1. 入力ファイルがwav以外の場合、ffmpegで16kHz mono wavに変換
    2. whisper-cli を実行 (-l ja -otxt)
    3. 出力テキストファイルを読み込んで返す
    4. 一時ファイルを削除

    Returns: 文字起こしテキスト (str)
    Raises: TranscriptionError
    """
```

**whisper-cliコマンド例:**
```bash
whisper-cli -m /path/to/ggml-small.bin -l ja -f /tmp/recording.wav -otxt -of /tmp/transcription
```

### refine.py

Gemini APIで文字起こしテキストを校正する。

```python
async def refine(raw_text: str) -> str:
    """
    Gemini APIでテキストを校正する。

    システムプロンプト:
      あなたは日本語の専門家です。
      以下のテキストは音声認識で自動書き起こしされたものです。
      誤認識、不自然な語順、フィラーワード（「えー」「あのー」など）、
      冗長な表現が含まれている可能性があります。
      話者の意図を保ちながら、以下の修正を行ってください：
      - 誤字・脱字の修正
      - フィラーワードの削除
      - 文法的に正しい日本語への修正
      - 冗長な表現の簡潔化
      修正後のテキストのみを出力してください。説明は不要です。

    API エラー時は元のテキストをそのまま返す (校正はベストエフォート)

    Returns: 校正済みテキスト (str)
    """
```

**Gemini API:**
- エンドポイント: `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- メソッド: POST
- 認証: URLパラメータ `?key={API_KEY}`

### obsidian.py

Obsidianデイリーノートにメモを追記し、gitでcommit & pushする。

```python
def append_to_daily_note(text: str) -> str:
    """
    デイリーノートの '# 📝 Notes' セクションにメモを追記する。

    フォーマット:
      - HH:MM テキスト

    挿入位置:
      '# 📝 Notes' セクション内の、次の '---' の直前に追記する。
      '# 📝 Notes' が見つからない場合はファイル末尾に追記。

    デイリーノートが存在しない場合はエラーを返す。
    (デイリーノートはObsidian側で事前に作成されている前提)

    追記後、git add → git commit → git push を実行する。

    Returns: 保存先ファイルの相対パス (例: "diary/2026-02-03.md")
    Raises: DailyNoteNotFoundError, GitError
    """
```

**デイリーノートの構造 (参考):**
```markdown
---
created: 2026-02-03 07:40
---
tags:: [[+Daily Notes]]

# Tuesday, February 03, 2026

<< [[diary/2026-02-02|Yesterday]] | [[diary/2026-02-04|Tomorrow]] >>

---
### 📅 Daily Questions
(省略)

---
# 📝 Notes
- <% tp.file.cursor() %>
- 07:40 既存のメモ
- 16:32 ここに新しいメモが追記される  ← ★挿入位置

---
### Todo
(以下省略)
```

**挿入ロジック:**
1. ファイルを読み込む
2. `# 📝 Notes` の位置を見つける
3. そこから次の `\n---\n` を探す
4. `---` の直前に `\n- HH:MM テキスト` を挿入
5. ファイルを書き込む

**Git操作:**
```bash
cd /path/to/vault
git add diary/YYYY-MM-DD.md
git commit -m "voice memo: HH:MM"
git push
```

## iPhoneショートカットの構成

WSLサーバー側の実装が完了した後、iPhoneの「ショートカット」アプリで以下のフローを作成する:

1. **音声を録音** (「オーディオを録音」アクション)
2. **サーバーにPOST送信** (「URLの内容を取得」アクション)
   - URL: `http://<TailscaleのWSL IP>:8765/voice`
   - メソッド: POST
   - 本文: フォーム (ファイル: 録音データ, キー: `audio`)
3. **結果を通知** (「通知を表示」アクション)
   - レスポンスの `refined_text` を表示

## セキュリティ

- サーバーはTailscaleネットワーク内のみからアクセス可能（0.0.0.0でlistenするがTailscaleのファイアウォールで制限）
- 必要に応じてAPIキー認証を追加可能（ヘッダー `X-API-Key` で検証）

## WSL側の前提条件

- Python 3.11+
- whisper.cpp がビルド済み
- ffmpeg がインストール済み（m4a→wav変換用）
- Tailscale がインストール・接続済み
- Obsidian Vault が git clone 済み
- Gemini API Key を取得済み

## セットアップ手順

```bash
# 1. リポジトリをクローン
cd ~/projects
git clone <repo-url> voice-to-thino-server
cd voice-to-thino-server

# 2. Python依存パッケージをインストール
pip install -r requirements.txt

# 3. config.py を編集してパスとAPIキーを設定

# 4. whisper.cpp をビルド (まだの場合)
git clone https://github.com/ggml-org/whisper.cpp.git ~/.local/share/whisper.cpp
cd ~/.local/share/whisper.cpp
make -j small

# 5. ffmpeg をインストール
sudo apt install ffmpeg

# 6. Obsidian Vault を clone
git clone <vault-repo-url> /path/to/obsidian-vault

# 7. サーバーを起動
python server.py

# 8. (オプション) systemd でサービス化
sudo cp voice-to-thino.service /etc/systemd/system/
sudo systemctl enable --now voice-to-thino
```

## requirements.txt

```
fastapi>=0.115.0
uvicorn>=0.34.0
python-multipart>=0.0.20
httpx>=0.28.0
```

## テスト方法

```bash
# ヘルスチェック
curl http://localhost:8765/health

# 音声ファイルを送信
curl -X POST http://localhost:8765/voice \
  -F "audio=@test_recording.wav"
```
