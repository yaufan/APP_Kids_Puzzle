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
- `app/lib/core/`：`content.dart`（讀上面的 json；`Level`、`Mode`、`Helper` 六隻小幫手）、`jigsaw.dart`（同一張圖切成 2～24 塊，凸凹用圖的名字當亂數種子；角、邊、中間的順序）、`board.dart`（拼東西的規則：磁鐵、最近的位置贏、轉對了沒、托盤一次 6 塊、點和拖分開、不會拖出畫面）、`shapes.dart`（形狀盒的形狀和六關）、`game.dart`（設定、塊數的梯子、進度、今天、休息）、存檔、聲音（拼的時候音樂小聲）、語音（每隻小幫手自己的音高）、providers（`busyProvider`：正在拼，時間到了可以拼完）。
- `app/lib/app/`：router 和休息時間（`app.dart`，`RestGuard`：家長模式和背景的時間不算、正在拼的可以再 2 分鐘）、`wood.dart`（Flutter 畫木頭：木片、洞、板子）、`widgets.dart`（`Pressable`、`HelperSays`、`DoneButtons`……）、`strings.dart`（所有的字；**APP 名稱只在 `Strings.appName`**，和 Android、iOS 的名稱一起改，`safety_test` 會檢查）、`theme.dart`。
- `app/lib/features/`：`common/board_view.dart`（**四種玩法共用的拖放引擎**：原始手指事件、只認第一隻手指、取消就放回、點一下拿起再點位置、提示、轉和翻）、`common/play_page.dart`（拼圖頁、拼好的面板、`Alive` 圖動起來、`TaiwanView` 台灣大拼圖）、`helper/`、`home/`（工坊，家長的鎖要按住）、`shapes/`（形狀盒、嵌板）、`jigsaw/`（盒子、選圖和塊數、拼圖、點台灣的塊再看一次）、`tangram/`、`blocks/`、`rest/`、`parent/`。
- 圖：`design/art/`（`kit.py` 彩繪木頭的畫法、`helpers.py`、`actors.py`、`pictures.py`、`ui.py`、`icon.py`；`build.py all`、`sheet`、`fluttercheck`），約定在 `docs/art.md`。聲音：`design/sounds/make_sounds.py`（`README.md` 有每個檔）。
- 測試：`rules_test`（切拼圖、拼東西的規則、七巧板和積木的資料、存檔）、`art_test`、`safety_test`、`version_test`、`screens_test`（兄弟 APP 檢查過的問題：玩的時間、語音、第一隻手指、取消、點和拖、開關、小手機）、`flow_test`（手機和平板，三個難度、每種玩法，截圖 37 張）、`demo/demo_video_test.dart`（`--dart-define=DEMO=true`，再 `python3 tools/demo_audio.py`）。

## 目前的狀態（2026-11-15）
- 0.1.0 做好了、還沒發布：本機測試全部通過（分析零問題、單元和畫面測試、手機和平板的完整流程、示範影片），commit 在 `claude/relaxed-albattani-6mbwpz` 分支。
- 發布前做過程式檢查（2026-11-15），修了（版本還是 0.1.0，測試在 `rules_test`、`screens_test`、`safety_test`）：
  - 拖放：先碰到螢幕、沒拿塊的手掌不會擋住別的手指；拖到一半 APP 跑到背景，回來還能拿塊；大的七巧板兩個一樣的三角形，轉對了哪一個就進哪一個；提示和爪子會找還有位置的塊（大的照著拼放了六角形以後不會沒反應）。
  - 照著拼的大：三角形給到夠用，怎麼放都拼得完（以前會留下沒有積木放得進去的洞）；托盤的點點在小手機上不會超出去。
  - 休息：APP 在背景的時間不算、也不會在背景開始休息；手機時間往回調不會多玩、也不會提早結束休息；按「下一張」「再拼一次」後新的那張也可以拼完；最後一塊放好的圖會動完才休息。
  - 語音：形狀盒和嵌板最後一塊的話不會被「拼好了」切掉；語音剛啟動時，新的一句不會被舊的一句蓋掉。
  - 選單：手指滑動捲清單不會誤開圖、台灣大拼圖的塊和家長的鎖；家長的鎖要手指停在上面按住。
  - 其他：家長只留「照著拼」又換成小小（或免費版）時，架子不會空掉（形狀洞洞會回來）；換小幫手時，還沒選新的之前舊的還在（休息畫面睡的是自己的小幫手）。
  - 示範影片沒有重做（只有大的照著拼托盤上三角形的點點多了「…」）。
- GitHub 專案 2026-11-15 建好了，工作分支已推上去；照 skill `release-kids-app` 問使用者能不能推 `main`（第一次推 main 會跑 App 和 Release；Secrets 要先放好）。
- 名稱「拼拼樂工坊」還在跟使用者確認（他打的是「拚拚樂工坊」）；要改的話改 `Strings.appName`、`AndroidManifest.xml`、`Info.plist`、`CHANGELOG.md` 和 README。
- 還沒在真手機上試過：拖拉的手感和磁鐵的強弱、24 塊在小手機上好不好拿、平行四邊形的「翻」按鈕、每隻小幫手的語音高低、TTS 念的話、聲音好不好聽（做的時候沒辦法用耳朵聽）、音樂的大小、休息時正在拼的可以拼完。
