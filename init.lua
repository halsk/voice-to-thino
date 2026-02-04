-- Voice to Thino - Hammerspoon configuration
-- 音声メモをObsidianのThinoフォーマットで自動記録するシステム
--
-- 使い方:
--   1. ホットキー（デフォルト: Cmd+Ctrl+Z）を長押しで録音開始
--   2. キーを離すと録音停止
--   3. Whisperで文字起こし → Geminiで校正 → Obsidianに追記

--------------------------------------------------------------------------------
-- 設定 (ユーザーが編集する部分)
--------------------------------------------------------------------------------

-- ホットキー設定
local HOTKEY_MODS = {"cmd", "ctrl"}
local HOTKEY_KEY = "z"
local LONGPRESS_SEC = 0.5  -- 長押し判定の秒数

-- ツールのパス
local SOX_PATH = "/opt/homebrew/bin/sox"
local WHISPER_PATH = os.getenv("HOME") .. "/.local/share/whisper.cpp/build/bin/whisper-cli"
local WHISPER_MODEL = os.getenv("HOME") .. "/.local/share/whisper.cpp/models/ggml-small.bin"

-- Gemini API設定
local GEMINI_API_KEY = os.getenv("REC2THINO_GEMINI_API_KEY")  -- 環境変数から取得
local GEMINI_MODEL = "gemini-2.0-flash"

-- Obsidian設定
local OBSIDIAN_VAULT_PATH = os.getenv("HOME") .. "/Documents/Obsidian2"
local OBSIDIAN_DAILY_DIR = "diary"  -- デイリーノートのディレクトリ

-- 一時ファイル
local TEMP_DIR = os.getenv("HOME") .. "/.voice-to-thino"
local AUDIO_FILE = TEMP_DIR .. "/recording.wav"

--------------------------------------------------------------------------------
-- 内部変数
--------------------------------------------------------------------------------

local isRecording = false
local recordingTask = nil
local keyDownTime = nil
local longPressTimer = nil
local processRecording  -- 前方宣言

--------------------------------------------------------------------------------
-- ユーティリティ関数
--------------------------------------------------------------------------------

-- ディレクトリ作成
local function ensureDir(path)
    os.execute("mkdir -p " .. path)
end

-- 現在の日付を取得 (YYYY-MM-DD形式)
local function getCurrentDate()
    return os.date("%Y-%m-%d")
end

-- 現在の時刻を取得 (HH:MM形式)
local function getCurrentTime()
    return os.date("%H:%M")
end

-- デイリーノートのパスを取得
local function getDailyNotePath()
    return OBSIDIAN_VAULT_PATH .. "/" .. OBSIDIAN_DAILY_DIR .. "/" .. getCurrentDate() .. ".md"
end

-- ファイルの存在確認
local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- ファイル内容を読み込む
local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

-- ファイルに書き込む
local function writeFile(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

-- 曜日名を取得 (英語)
local function getDayOfWeek()
    local days = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
    return days[tonumber(os.date("%w")) + 1]
end

-- 月名を取得 (英語)
local function getMonthName()
    local months = {"January", "February", "March", "April", "May", "June",
                    "July", "August", "September", "October", "November", "December"}
    return months[tonumber(os.date("%m"))]
end

-- デイリーノートを新規作成
local function createDailyNote()
    local today = getCurrentDate()
    local createdTime = os.date("%Y-%m-%d %H:%M")
    local dayOfWeek = getDayOfWeek()
    local monthName = getMonthName()
    local day = os.date("%d")
    local year = os.date("%Y")

    -- 前日・翌日の日付
    local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
    local tomorrow = os.date("%Y-%m-%d", os.time() + 86400)

    -- 日末の時刻 (tasks done クエリ用)
    local endOfDay = today .. " 23:59"

    local template = string.format([=[---
created: %s
---
tags:: [[+Daily Notes]]

# %s, %s %s, %s

<< [[diary/%s|Yesterday]] | [[diary/%s|Tomorrow]] >>

---
### 📅 Daily Questions
##### 🌜 Last night, after work, I...
-

##### 🙌 One thing I'm excited about right now is...
-

##### 🚀 One+ thing I plan to accomplish today is...


##### 👎 One thing I'm struggling with today is...
-

---
# 📝 Notes
-

---
### Todo
```tasks
not done
sort by priority
sort by due
```
### 🎉Done
```tasks
done on %s
```


---
### Notes created today
```dataview
List FROM "" WHERE file.cday = date("%s") SORT file.ctime asc
```

### Notes last touched today
```dataview
List FROM "" WHERE file.mday = date("%s") SORT file.mtime asc
```
]=], createdTime, dayOfWeek, monthName, day, year, yesterday, tomorrow, endOfDay, today, today)

    local path = getDailyNotePath()
    if writeFile(path, template) then
        print("[Voice to Thino] Created daily note: " .. path)
        return true
    else
        print("[Voice to Thino] Failed to create daily note: " .. path)
        return false
    end
end

-- 通知を表示
local function notify(title, message)
    hs.notify.new({title = title, informativeText = message}):send()
end

-- アラート音を再生
local function playSound(soundName)
    local sound = hs.sound.getByName(soundName)
    if sound then sound:play() end
end

--------------------------------------------------------------------------------
-- 録音機能
--------------------------------------------------------------------------------

-- 録音開始
local function startRecording()
    if isRecording then return end

    ensureDir(TEMP_DIR)

    -- 既存の録音ファイルを削除
    os.remove(AUDIO_FILE)

    -- SoXで録音開始 (16kHz, mono, WAV形式)
    local cmd = string.format(
        '"%s" -d -r 16000 -c 1 -b 16 "%s"',
        SOX_PATH, AUDIO_FILE
    )

    recordingTask = hs.task.new("/bin/bash", nil, {"-c", cmd})
    recordingTask:start()

    isRecording = true
    playSound("Morse")
    notify("Voice to Thino", "録音中...")
    print("[Voice to Thino] Recording started")
end

-- 録音停止
local function stopRecording()
    if not isRecording then return end

    if recordingTask then
        recordingTask:terminate()
        recordingTask = nil
    end

    isRecording = false
    playSound("Submarine")
    notify("Voice to Thino", "録音停止、処理中...")
    print("[Voice to Thino] Recording stopped")

    -- 少し待ってから処理を開始（ファイル書き込み完了を待つ）
    hs.timer.doAfter(0.5, function()
        processRecording()
    end)
end

--------------------------------------------------------------------------------
-- 文字起こし (Whisper)
--------------------------------------------------------------------------------

local function transcribe()
    if not fileExists(AUDIO_FILE) then
        print("[Voice to Thino] Audio file not found")
        return nil
    end

    local outputFile = TEMP_DIR .. "/transcription.txt"

    -- Whisperで文字起こし
    local cmd = string.format(
        '"%s" -m "%s" -l ja -f "%s" -otxt -of "%s" 2>/dev/null',
        WHISPER_PATH, WHISPER_MODEL, AUDIO_FILE, TEMP_DIR .. "/transcription"
    )

    print("[Voice to Thino] Running Whisper: " .. cmd)
    local ok = os.execute(cmd)

    if not ok then
        print("[Voice to Thino] Whisper failed")
        return nil
    end

    local text = readFile(outputFile)
    if text then
        text = text:gsub("^%s+", ""):gsub("%s+$", "")  -- trim
    end

    print("[Voice to Thino] Transcription: " .. (text or "nil"))
    return text
end

--------------------------------------------------------------------------------
-- Gemini APIで校正
--------------------------------------------------------------------------------

local function refineWithGemini(rawText, callback)
    if not rawText or rawText == "" then
        callback(nil)
        return
    end

    local systemPrompt = [[
あなたは日本語の専門家です。
以下のテキストは音声認識で自動書き起こしされたものです。
誤認識、不自然な語順、フィラーワード（「えー」「あのー」など）、冗長な表現が含まれている可能性があります。
話者の意図を保ちながら、以下の修正を行ってください：
- 誤字・脱字の修正
- フィラーワードの削除
- 文法的に正しい日本語への修正
- 冗長な表現の簡潔化

修正後のテキストのみを出力してください。説明は不要です。
]]

    local requestBody = hs.json.encode({
        contents = {
            {
                parts = {
                    { text = systemPrompt .. "\n\n入力テキスト:\n" .. rawText }
                }
            }
        }
    })

    local url = string.format(
        "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s",
        GEMINI_MODEL, GEMINI_API_KEY
    )

    hs.http.asyncPost(url, requestBody, {["Content-Type"] = "application/json"}, function(status, body, headers)
        if status ~= 200 then
            print("[Voice to Thino] Gemini API error: " .. tostring(status))
            callback(rawText)  -- エラー時は元のテキストを使用
            return
        end

        local response = hs.json.decode(body)
        local refinedText = rawText

        if response and response.candidates and response.candidates[1] and
           response.candidates[1].content and response.candidates[1].content.parts and
           response.candidates[1].content.parts[1] then
            refinedText = response.candidates[1].content.parts[1].text
            refinedText = refinedText:gsub("^%s+", ""):gsub("%s+$", "")  -- trim
        end

        print("[Voice to Thino] Refined text: " .. refinedText)
        callback(refinedText)
    end)
end

--------------------------------------------------------------------------------
-- Obsidianに追記
--------------------------------------------------------------------------------

local function appendToObsidian(text)
    if not text or text == "" then
        notify("Voice to Thino", "テキストが空のため保存をスキップしました")
        return false
    end

    local dailyNotePath = getDailyNotePath()
    local currentTime = getCurrentTime()
    local entry = string.format("- %s %s", currentTime, text)

    if not fileExists(dailyNotePath) then
        print("[Voice to Thino] Daily note not found, creating: " .. getCurrentDate() .. ".md")
        if not createDailyNote() then
            notify("Voice to Thino", "デイリーノートの作成に失敗しました")
            return false
        end
        notify("Voice to Thino", "デイリーノートを作成しました: " .. getCurrentDate() .. ".md")
    end

    local content = readFile(dailyNotePath)
    if not content then
        notify("Voice to Thino", "ファイルの読み込みに失敗しました")
        return false
    end

    -- "# 📝 Notes" セクションを見つけて、その次の "- " で始まる行の後に追記
    -- または、セクション内の最後の "- " 行の後に追記
    local pattern = "(# 📝 Notes\n)"
    local notesSection = content:find(pattern)

    if notesSection then
        -- "# 📝 Notes" の後にエントリを追加
        -- 既存のエントリがある場合はその後に追加
        local insertPos = content:find("\n---\n", notesSection)
        if insertPos then
            -- "---" の前に挿入
            local beforeSection = content:sub(1, insertPos - 1)
            local afterSection = content:sub(insertPos)
            content = beforeSection .. "\n" .. entry .. afterSection
        else
            -- セクションの後にそのまま追加
            content = content:gsub(pattern, "%1" .. entry .. "\n")
        end
    else
        -- セクションが見つからない場合は末尾に追加
        content = content .. "\n" .. entry
    end

    if writeFile(dailyNotePath, content) then
        notify("Voice to Thino", "保存しました: " .. text:sub(1, 30) .. (text:len() > 30 and "..." or ""))
        print("[Voice to Thino] Saved to Obsidian: " .. entry)
        return true
    else
        notify("Voice to Thino", "ファイルの書き込みに失敗しました")
        return false
    end
end

--------------------------------------------------------------------------------
-- メイン処理フロー
--------------------------------------------------------------------------------

processRecording = function()
    notify("Voice to Thino", "文字起こし中...")

    -- 1. Whisperで文字起こし
    local rawText = transcribe()

    if not rawText or rawText == "" then
        notify("Voice to Thino", "文字起こしに失敗しました")
        return
    end

    notify("Voice to Thino", "校正中...")

    -- 2. Gemini APIで校正
    refineWithGemini(rawText, function(refinedText)
        -- 3. Obsidianに追記
        appendToObsidian(refinedText or rawText)

        -- 一時ファイルを削除
        os.remove(AUDIO_FILE)
        os.remove(TEMP_DIR .. "/transcription.txt")
    end)
end

--------------------------------------------------------------------------------
-- ホットキーハンドラ
--------------------------------------------------------------------------------

-- キー押下時
local function onKeyDown()
    keyDownTime = hs.timer.secondsSinceEpoch()

    -- 長押しタイマーを開始
    if longPressTimer then
        longPressTimer:stop()
    end

    longPressTimer = hs.timer.doAfter(LONGPRESS_SEC, function()
        startRecording()
    end)
end

-- キー解放時
local function onKeyUp()
    if longPressTimer then
        longPressTimer:stop()
        longPressTimer = nil
    end

    if isRecording then
        stopRecording()
    end

    keyDownTime = nil
end

--------------------------------------------------------------------------------
-- ホットキーの登録
--------------------------------------------------------------------------------

-- 修飾キーの厳密チェック (指定した修飾キーが全て押されているか)
local function checkMods(flags)
    for _, mod in ipairs(HOTKEY_MODS) do
        if not flags[mod] then
            return false
        end
    end
    return true
end

-- キーイベントタップ (keyDown / keyUp)
local keyEventTap = hs.eventtap.new({hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp}, function(event)
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()
    local eventType = event:getType()
    local targetKeyCode = hs.keycodes.map[HOTKEY_KEY]

    if keyCode == targetKeyCode then
        if eventType == hs.eventtap.event.types.keyDown and checkMods(flags) then
            if not keyDownTime then  -- 重複呼び出し防止
                onKeyDown()
            end
            return true  -- イベントを消費
        elseif eventType == hs.eventtap.event.types.keyUp then
            -- keyUp時は修飾キーの状態に関係なく処理する
            -- (Zを離す前にCmd/Ctrlが離されることがある)
            if keyDownTime then
                onKeyUp()
            end
            return true  -- イベントを消費
        end
    end

    return false
end)

-- 修飾キー変化タップ (録音中または長押し待機中に修飾キーが離された場合の安全策)
local flagsEventTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    if keyDownTime then
        local flags = event:getFlags()
        if not checkMods(flags) then
            -- 修飾キーが離された → 録音停止 or 長押しキャンセル
            print("[Voice to Thino] Modifier key released, cancelling/stopping")
            onKeyUp()
        end
    end
    return false
end)

keyEventTap:start()
flagsEventTap:start()

--------------------------------------------------------------------------------
-- eventtap 生存監視 & 自動復旧
--------------------------------------------------------------------------------

local watchdogTimer = hs.timer.doEvery(30, function()
    local keyTapRunning = keyEventTap:isEnabled()
    local flagsTapRunning = flagsEventTap:isEnabled()

    if not keyTapRunning or not flagsTapRunning then
        print("[Voice to Thino] ⚠ eventtap stopped! Restarting...")
        print("[Voice to Thino]   keyEventTap: " .. tostring(keyTapRunning) .. ", flagsEventTap: " .. tostring(flagsTapRunning))

        if not keyTapRunning then
            keyEventTap:start()
        end
        if not flagsTapRunning then
            flagsEventTap:start()
        end

        -- 状態もリセット
        isRecording = false
        keyDownTime = nil
        if longPressTimer then
            longPressTimer:stop()
            longPressTimer = nil
        end
        if recordingTask then
            recordingTask:terminate()
            recordingTask = nil
        end

        notify("Voice to Thino", "ホットキーを再起動しました")
    end
end)

-- 状態スタック防止: 60秒以上 keyDownTime がセットされたままなら強制リセット
local stateResetTimer = hs.timer.doEvery(10, function()
    if keyDownTime then
        local elapsed = hs.timer.secondsSinceEpoch() - keyDownTime
        if elapsed > 60 then
            print("[Voice to Thino] ⚠ State stuck for " .. math.floor(elapsed) .. "s, force resetting")
            keyDownTime = nil
            if longPressTimer then
                longPressTimer:stop()
                longPressTimer = nil
            end
            if isRecording and recordingTask then
                recordingTask:terminate()
                recordingTask = nil
                isRecording = false
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 初期化完了メッセージ
--------------------------------------------------------------------------------

print("[Voice to Thino] Loaded successfully")
print("[Voice to Thino] Press " .. table.concat(HOTKEY_MODS, "+") .. "+" .. HOTKEY_KEY .. " (hold) to start recording")
print("[Voice to Thino] Watchdog timer: every 30s, state reset timer: every 10s")
notify("Voice to Thino", "起動しました。" .. table.concat(HOTKEY_MODS, "+") .. "+" .. string.upper(HOTKEY_KEY) .. " を長押しで録音開始")
