# 給 Claude 的專案規則（拼拼樂工坊）

這份是這個專案的「記憶」。每個在這個專案裡工作的 Claude 都要照著做。它是「畫畫小鎮」（https://github.com/yaufan/APP_Kids_Paint）、「字母寵物」（https://github.com/yaufan/APP_Kids_Paint_for_learning_writing）、「動物小餐廳」（https://github.com/yaufan/APP_Kids_Cook）、「小卡認天下」（https://github.com/yaufan/APP_Kids_Card_Game）、「想一想樂園」（https://github.com/yaufan/APP_Kids_Brainstorming）、「眼尖尖大挑戰」（https://github.com/yaufan/APP_Kids_FalseCharge）、「迷宮小冒險」（https://github.com/yaufan/APP_Kids_maze）、「小小生活家」（https://github.com/yaufan/APP_Kids_live_circ）、「小小音樂家」（https://github.com/yaufan/APP_Kids_Music）、「心情小屋」（https://github.com/yaufan/APP_Kids_Feelings）、「晚安小鎮」（https://github.com/yaufan/APP_Kids_Goodnight）、「安全小隊」（https://github.com/yaufan/APP_Kids_Safety）和「ㄅㄆㄇ小火車」（https://github.com/yaufan/APP_Kids_Bopomofo）的兄弟 APP，技術和流程照那邊（畫風不同），這裡寫這個專案自己的事。程式的架構最接近ㄅㄆㄇ小火車和安全小隊（Python 畫 SVG、ParentPass、休息時間、拖東西用原始的手指事件），有疑問先看那邊怎麼做。

## 和使用者合作
- **一律用繁體中文回覆**，用白話說明，少用技術名詞；要用的話順便解釋。
- 使用者用手機上的 Claude App 看對話，**打不開 artifact 連結**。圖片、影片、聲音、QR code 都用傳檔案的方式（SendUserFile）給。
- 設計階段：每個想法都畫成草圖（`docs/mockups/`）傳給使用者看，再問。
- 之後每做完一版：給示範影片片段、手機截圖、下載 QR code（和畫畫小鎮一樣）。
- 有要使用者決定的事，列出選項和我的建議，再問。
- 不要開 pull request，除非使用者要求。用了網路搜尋，回覆最後附「Sources:」和連結。

## 這個 APP
- 給 **2 歲半～5 歲**的小朋友，在台灣，國語為主：拼圖 APP，練「空間」（看形狀、找位置、在腦子裡轉一轉）。一群台灣小動物開了拼圖工坊，小朋友把一塊一塊放回去，放對了「咔」一聲吸進去，整張拼好圖就動起來，變成牆上「台灣大拼圖」的一塊。
- 四種玩法：形狀洞洞（形狀盒＋六塊嵌板）、拼圖（六盒 48 張，同一張圖程式切成 2～24 塊）、七巧板（24 個影子）、照著拼（12 張形狀積木卡）。0.1 每種都比原本的計畫多（使用者說「全都要多一點」）。
- 工坊小幫手：小朋友第一次打開時從六隻台灣動物選一隻（甲甲穿山甲、石石石虎、熊熊黑熊、藍藍藍鵲、花花梅花鹿、猴猴獼猴），之後可以換；每隻有自己的話、小聲音、語音高低和睡覺姿勢。
- 三個難度：小小（2 歲半～3 歲）、中（3～4 歲）、大（4～5 歲）。小小不用轉；中的七巧板放近了自己轉正；大點一下轉 45 度、平行四邊形有「翻」的按鈕。
- 拼圖的托盤一次 6 塊，放好一塊補一塊；12 塊以上先給角和邊。放錯了塊只會輕輕飄回去。
- 設計在 [docs/design.md](docs/design.md)，改設計時一起改它；草圖在 `docs/mockups/`。
- 畫風：**彩繪木頭風**，只做一種（霧面漆的木片：淡淡的漸層、細細的木紋、磨圓的邊、看得到厚度，洞是挖下去的）。要和兄弟 APP 的畫風**不一樣**。
- 不會失敗：沒有倒數、分數、星星和排名；放錯沒有「嗶」。
- 每次玩多久由家長設定（預設 15 分鐘），正在拼的那張可以拼完（最多再 2 分鐘），然後小幫手睡覺，說「換你去做了！去收玩具、拼真的拼圖吧！」。
- 免費版：形狀洞洞全部、拼圖的水果盒和動物盒、七巧板小小組；完整版：其他四盒拼圖、七巧板中組和大組、照著拼。購買只在家長模式。
- 技術名稱：Flutter 專案 `puzzle_workshop`、applicationId `com.yaufan.puzzleworkshop`、APK `puzzle-workshop-版本-arm64.apk`、簽章環境變數 `PUZZLE_WORKSHOP_KEYSTORE`。
- 資安：不接受別的 APP 傳來的頁面（`flutter_deeplinking_enabled` 關掉、`overridePlatformDefaultLocation`），家長模式只能從家長關卡進去（`ParentPass`），不要任何權限。
- 不連網、不定位、沒有廣告、沒有帳號。以後上架要收費：免費下載一部分，一次買斷完整版，購買只在家長模式（要過家長關卡）。
- 每個動作都要有音效，全部用程式合成。
- 授權：非商業使用（`LICENSE`），中英文版本；別人做的部分（字型）在 `NOTICE.md`。
- 名稱：拼拼樂工坊。GitHub：https://github.com/yaufan/APP_Kids_Puzzle

## GitHub Actions
- 工作流程（照小小生活家；第一次放上 main 前要先問）：
  - `app.yml`（App）：推到 `main` 而且改到 `app/**` 時跑分析、全部測試（含完整流程）、打包 APK，約 15～20 分鐘。
  - `release.yml`（Release）：推到 `main` 而且改到 `app/pubspec.yaml`、`CHANGELOG.md` 或它自己時，版本還沒發布過就打包三個 APK 放上 Releases，約 20 分鐘；版本沒變約 1 分鐘。
  - `cleanup.yml`：手動，刪舊的建置檔案，約 1 分鐘。
- 推工作分支（`claude/...`）不會啟動任何工作流程。
- 簽章：和畫畫小鎮用**同一把測試金鑰**（別名 `kidspaint`），Secrets 名稱一樣：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`，要放在這個專案的 Actions → Secrets → Repository secrets。指紋 `TEST_KEY_SHA256` 寫在工作流程裡。以後上架要換成正式的上傳金鑰。
- 發新版本：`app/pubspec.yaml` 的 `version`、`app/lib/app/version.dart` 的預設值、`CHANGELOG.md` 最上面一段（`## 版本 …`）三個要一致（`test/version_test.dart` 檢查）。
- **任何會啟動 Actions 的動作，都要先問使用者，等使用者同意才做**，問的時候說清楚四件事：
  1. 會跑哪些工作流程。
  2. 這次大約用掉幾分鐘。
  3. 這個月目前用了多少。
  4. 跑完大約還剩多少。

  規則和畫畫小鎮的 `CLAUDE.md` 一樣；那個帳號每月 2,000 分鐘是所有私有專案共用的，Mac 主機的 1 分鐘算 10 分鐘。

## Git
- **發布新版本、做成可以安裝的 APK、給下載 QR code**：照 skill `release-kids-app`（`.claude/skills/release-kids-app/SKILL.md`），兄弟 APP 共用同一份。
- 在系統指定的 `claude/...` 工作分支上開發，commit 完就推這個分支。
- commit 訊息用英文寫清楚改了什麼和為什麼，結尾加系統要求的署名行。不要寫模型名稱。
- 不能 commit：金鑰、密碼、不公開的文件、`__pycache__`。

## 和畫畫小鎮共用的做法（開始寫程式時照著做）
- Flutter 3.47.8、Riverpod、flutter_svg、audioplayers、flutter_tts。存檔是一個 JSON 檔（`app/lib/core/store.dart`），沒有用 drift，所以本機跑測試**不用** sqlite 那段，直接 `flutter test`。
- 觸控：用原始的手指事件（`Listener`），手指一碰就畫。不要用拖曳手勢，它要移動 36 點才開始，小朋友短短的一筆會不見。
- 圖和聲音都用程式產生（SVG 用 Python 畫；聲音用 numpy 合成），不用別人的素材。
- 本機測試：在 `app/` 裡 `flutter test`（不含 `test/flow_test.dart`），`flutter analyze` 要零問題。以後加了 drift，才照畫畫小鎮的 `tools/run_tests.sh`（pubspec 的 sqlite 那段不能 commit）。
- 完整流程和截圖：`flutter test test/flow_test.dart`，截圖在 `app/build/screenshots/`。
- 示範影片（每一版都要給使用者）：在 `app/` 裡 `flutter test test/demo/demo_video_test.dart --dart-define=DEMO=true`（約 5～10 分鐘，要 ffmpeg），再在專案根目錄 `python3 tools/demo_audio.py` 把背景音樂和音效混進去。輸出 `app/build/demo/demo.mp4`；`chapters.txt` 是每一段開始的格數（每秒 10 格），用來剪新功能的片段。

## 程式在哪裡
- `design/content.py`：六盒 48 張拼圖（場景、會動的東西和它的框、怎麼動、聲音、小幫手說的空間的話）和六塊嵌板，寫成 `app/assets/content.json`。
- `design/puzzles.py`：七巧板 24 個（小小和中一塊一塊寫好；大的七塊用小小的「拼法搜尋」從外框算出來，一定拼得出來）、照著拼 12 張（三角形格子；大的「其他拼法」也算好）、台灣大拼圖 48 塊，用 shapely 檢查，寫成 `tangram.json`、`blocks.json`、`taiwan.json`；`preview` 畫出來看。
- `app/lib/core/`：`content.dart`（讀上面的 json；`Level`、`Mode`、`Helper` 六隻小幫手）、`jigsaw.dart`（同一張圖切成 2～24 塊，凸凹用圖的名字當亂數種子；角、邊、中間的順序）、`board.dart`（拼東西的規則：磁鐵、最近的位置贏、轉對了沒、托盤一次 6 塊、點和拖分開、不會拖出畫面）、`shapes.dart`（形狀盒的形狀和六關）、`game.dart`（設定、塊數的梯子、進度、今天、休息）、存檔（`game.dart` 也存這次玩了多久 `Sitting`：關掉 10 分鐘內再打開接著算；家長關卡連錯的等待 `GateLock`）、聲音（拼的時候音樂小聲；`soundContext` 走媒體音量，`_switching` 讓音樂一個一個換）、語音（每隻小幫手自己的音高；APP 在背景時不說）、providers（`busyProvider`：正在拼，時間到了可以拼完；`keptProvider`：拼到一半離開的拼圖、七巧板、照著拼，回來時塊還在）。
- `app/lib/app/`：router 和休息時間（`app.dart`，`RestGuard`：家長模式、家長關卡和背景的時間不算、正在拼的可以再 2 分鐘、家長模式留在背景就回工坊；每個畫面包 `BackKey`，手機的返回鍵不會關掉 APP，`TopBar` 讓返回鍵和小房子一樣）、`wood.dart`（Flutter 畫木頭：木片、洞、板子）、`widgets.dart`（`Pressable`、`HelperSays`、`DoneButtons`……）、`strings.dart`（所有的字；**APP 名稱只在 `Strings.appName`**，和 Android、iOS 的名稱一起改，`safety_test` 會檢查）、`theme.dart`。
- `app/lib/features/`：`common/board_view.dart`（**四種玩法共用的拖放引擎**：原始手指事件、只認第一隻手指、取消就放回、點一下拿起再點位置、提示、轉和翻）、`common/play_page.dart`（拼圖頁、拼好的面板、`Alive` 圖動起來、`TaiwanView` 台灣大拼圖）、`helper/`、`home/`（工坊，家長的鎖要按住）、`shapes/`（形狀盒、嵌板）、`jigsaw/`（盒子、選圖和塊數、拼圖、點台灣的塊再看一次）、`tangram/`、`blocks/`、`rest/`、`parent/`。
- 圖：`design/art/`（`kit.py` 彩繪木頭的畫法、`helpers.py`、`actors.py`、`pictures.py`、`ui.py`、`icon.py`；`build.py all`、`sheet`、`fluttercheck`），約定在 `docs/art.md`。聲音：`design/sounds/make_sounds.py`（`README.md` 有每個檔）。
- 測試：`rules_test`（切拼圖、拼東西的規則、七巧板和積木的資料、存檔）、`art_test`、`safety_test`、`version_test`、`screens_test`（兄弟 APP 檢查過的問題：玩的時間、語音、第一隻手指、取消、點和拖、開關、小手機；0.1.1 加的：返回鍵、拼到一半回來還在、關掉再打開接著算、家長模式和關卡自己關上、關卡等待變長、音樂排隊）、`flow_test`（手機和平板，三個難度、每種玩法，截圖 37 張）、`demo/demo_video_test.dart`（`--dart-define=DEMO=true`，再 `python3 tools/demo_audio.py`）。

## 目前的狀態（2026-11-26）
- 0.1.0 已發布（2026-11-16）：Releases 有三個 APK，App 和 Release 都成功；Secrets 加好了。發布前做過一次程式檢查（拖放、照著拼的大、休息、語音、選單、架子、換小幫手）。
- **0.1.1 做好了、還沒發布**（在 `claude/relaxed-albattani-6mbwpz` 分支，推 `main` 要先問使用者）：2026-11-26 兄弟 APP 一起檢查後修的——
  - APP 關掉 10 分鐘內再打開接著算玩的時間（存在手機裡）；家長關卡上的時間不算。
  - 手機的返回鍵不會關掉 APP，和畫面上的小房子一樣；工坊和休息畫面沒反應。
  - 拼圖、七巧板、照著拼拼到一半離開（小房子、返回、休息），回到同一張時塊還在（只記在記憶體，APP 關掉就沒有）。形狀洞洞很短，沒有記。
  - 家長模式和家長關卡切到背景或 5 分鐘沒碰會自己關上；休息畫面解開後不會留著進家長模式的門。
  - 家長關卡連錯等 1、5、15 分鐘，存在手機裡，時鐘調回去不會鎖住。
  - 聲音走媒體音量（震動和靜音也聽得到）、音樂換畫面時排隊（不會放錯）、APP 在背景時小幫手不說話、Android 11 以上找得到語音（`TTS_SERVICE`）。
  - 不跟 Google 備份（`allowBackup`、`data_extraction_rules.xml`）；打包時多檢查相機、麥克風、聯絡人、相片的權限。
- 名稱用「拼拼樂工坊」（拼圖的「拼」），使用者 2026-11-16 確認；要改的話改 `Strings.appName`、`AndroidManifest.xml`、`Info.plist`、`CHANGELOG.md` 和 README。
- 還沒在真手機上試過：拖拉的手感和磁鐵的強弱、24 塊在小手機上好不好拿、平行四邊形的「翻」按鈕、每隻小幫手的語音高低、TTS 念的話、聲音好不好聽（做的時候沒辦法用耳朵聽）、震動模式下有沒有「咔」和音樂、音樂的大小、休息時正在拼的可以拼完、托盤最邊邊的塊拖的時候會不會被手機當成返回（現在只會回到盒子，拼圖還在）。
