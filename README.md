# 拼拼樂工坊

給 **2 歲半～5 歲**的小朋友，在台灣，國語為主：拼圖 APP，練「空間」（看形狀、找位置、在腦子裡轉一轉）。一群台灣小動物開了拼圖工坊，小朋友把一塊一塊放回去，放對了「咔」一聲吸進去，整張拼好圖就動起來，變成牆上「台灣大拼圖」的一塊。

- 設計：[docs/design.md](docs/design.md)，草圖在 `docs/mockups/`。
- 和「畫畫小鎮」「字母寵物」「動物小餐廳」「小卡認天下」「想一想樂園」「眼尖尖大挑戰」「迷宮小冒險」「小小生活家」「小小音樂家」「心情小屋」「晚安小鎮」「安全小隊」「ㄅㄆㄇ小火車」是兄弟 APP：同一個作者、同一套技術、不同畫風。
- 不連網、不定位、沒有廣告、沒有帳號。

## 下載（Android）
- 最新版：[Releases](https://github.com/yaufan/APP_Kids_Puzzle/releases/latest)，一般手機下載 `puzzle-workshop-版本-arm64.apk`。
- 用手機掃描 [docs/download-qr.png](docs/download-qr.png)。

## 目前進度
- 0.1.0（測試版）：工坊和台灣大拼圖（48 塊）、六隻小幫手（自己選）、形狀洞洞（形狀盒 6 關和六塊嵌板）、拼圖六盒 48 張（2～24 塊）、七巧板 24 個、照著拼 12 張、拼好了圖會動、休息時間、家長關卡和家長模式、音樂和音效、APP 圖示。彩繪木頭風。版本紀錄在 [CHANGELOG.md](CHANGELOG.md)。

## 程式和素材在哪裡
- `app/`：Flutter 程式。`lib/core/` 是內容（`content.dart`）、切拼圖（`jigsaw.dart`）、拼東西的規則（`board.dart`）、形狀盒（`shapes.dart`）、存檔和規則（`game.dart`）、聲音和語音；`lib/app/` 是路由、休息時間、木頭的畫法和共用的元件；`lib/features/` 是選小幫手、工坊、形狀洞洞、拼圖、七巧板、照著拼、休息、家長模式，四種玩法共用 `features/common/board_view.dart` 的拖放。
- `design/content.py`：48 張拼圖和 6 塊嵌板；`design/puzzles.py`：七巧板、照著拼、台灣大拼圖的形狀（shapely 檢查）。
- `design/art/`：用 Python 畫的圖（彩繪木頭風），`python3 build.py all` 全部重畫，`fluttercheck` 用真的 flutter_svg 比對；`icon.py` 是 APP 圖示。
- `design/sounds/make_sounds.py`：合成全部的音樂和聲音。
- 測試：在 `app/` 裡 `flutter test`；完整流程 `flutter test test/flow_test.dart`，截圖在 `app/build/screenshots/`；示範影片 `flutter test test/demo/demo_video_test.dart --dart-define=DEMO=true`，再 `python3 tools/demo_audio.py`。

## 授權
- 非商業使用授權：自己、家人使用，或學校、非營利團體的教學，都可以免費使用、修改、分享，要註明出處。
- 商業用途（販賣、收費、廣告、上架）要先取得作者書面同意。也不可以拿來訓練 AI。
- 細節見 [LICENSE](LICENSE)；別人做的部分（字型）見 [NOTICE.md](NOTICE.md)。
