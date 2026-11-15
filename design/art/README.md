# 拼拼樂工坊的圖（design/art）

全部用 Python 畫成 SVG（彩繪木頭風，約定在 `docs/art.md`）。

```
python3 design/art/build.py all                 # 全部重畫並檢查
python3 design/art/build.py actors              # 只畫一部分（helpers、actors、pictures、ui）
python3 design/art/build.py check               # flutter_svg 的規則
python3 design/art/build.py sheet OUT.png [dir] # 一張看全部（或一個資料夾）
python3 design/art/build.py fluttercheck        # 用真的 flutter_svg 畫，和 Chromium 比對
python3 design/art/icon.py preview OUT.png      # APP 圖示
python3 design/art/icon.py export               # 寫進 Android 和 iOS
```

- `kit.py`：畫法（`paint` 上漆、`slab` 木片、`hole` 洞、`grain` 木紋、`bevel` 圓邊、`silhouette` 外框）和檢查。
- `helpers.py`：六隻小幫手 × 三個姿勢。
- `actors.py`：會動的東西和嵌板的木片、洞。加新的東西：寫一個函式、放進 `ACTORS`，在 `design/content.py` 用它。
- `pictures.py`：場景（`SCENES`）和 48 張圖。加新的圖：在 `design/content.py` 的 `PICTURES` 加一行（場景、東西、框、怎麼動、聲音、說的話），再跑 `build.py all`。
- `ui.py`：玩具盒、地板、休息畫面。
- `icon.py`：APP 圖示（四塊木頭拼圖和探出頭的甲甲）。
- 七巧板、照著拼和台灣大拼圖的形狀在 `design/puzzles.py`（寫成 `app/assets/*.json`），APP 自己畫。
