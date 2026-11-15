# 拼拼樂工坊的聲音

全部用 `make_sounds.py` 從正弦波和雜訊合成（沒有錄音、沒有下載），每次跑出來都一樣。

```
python3 design/sounds/make_sounds.py               # 寫進 app/assets/sounds/
python3 design/sounds/make_sounds.py snap drop      # 只做這幾個
python3 design/sounds/make_sounds.py preview OUT.m4a  # 全部接起來聽
```

## 音樂（16,000 Hz，無縫循環 15～20 秒）
| 檔案 | 在哪裡 | 聽起來 |
|---|---|---|
| `music_workshop` | 工坊、選小幫手、選拼圖盒 | 木琴加烏克麗麗 |
| `music_shapes` | 形狀洞洞 | 拇指琴 |
| `music_fruit` | 水果盒 | 輕快的木琴、小鼓 |
| `music_animals` | 動物盒 | 口琴加撥弦 |
| `music_night` | 夜市盒 | 熱鬧一點，有拍手 |
| `music_ride` | 捷運和車車盒 | 火車的「噗噗」節奏 |
| `music_temple` | 廟會盒 | 小鼓和小小聲的鑼 |
| `music_city` | 城市盒 | 輕快的鋼琴 |
| `music_tangram` | 七巧板 | 慢慢的拇指琴 |
| `music_blocks` | 照著拼 | 木琴加撥弦 |
| `music_rest` | 休息 | 音樂盒搖籃曲 |

拼的時候音樂比較小聲（`Music.quiet`），讓「咔」聽得清楚。

## 木頭塊的聲音
| 檔案 | 什麼時候 |
|---|---|
| `tap` | 按按鈕 |
| `pick` | 拿起一塊「啵」 |
| `near` | 靠近對的位置「叮」 |
| `snap` | 吸進去「咻—咔」 |
| `back` | 放錯了飄回托盤，柔柔的「咻」（沒有「嗶」） |
| `turn` | 點一下轉「喀」 |
| `flip` | 平行四邊形翻面「啪啦」 |
| `drop` | 形狀掉進形狀盒「咚」 |
| `done` | 拼好了 |
| `star` | 台灣大拼圖多一塊 |
| `open` | 打開玩具盒 |
| `night` | 休息 |
| `pop`、`sparkle` | 小小的啵啵、亮晶晶 |

## 每張圖自己的聲音（動起來的時候，嵌板放好一塊也會響）
`munch`（吃東西）、`boing`（彈跳）、`ding`、`chime`（叮咚）、`waves`（海浪）、`splash`（水花）、`sizzle`（烤東西）、`bapu`（叭噗）、`mrt`（捷運叮咚和開門）、`whoosh`（高鐵咻）、`toot`（火車）、`bell`（腳踏車鈴）、`garbage`（垃圾車的〈給愛麗絲〉）、`cymbal`（舞獅的鈸，小小聲）、`drum`（廟口的鼓，小小聲）、`wind`（天燈的風）、`spin`（陀螺）、`fireworks`（小小的煙火，沒有爆炸聲）。

不放鞭炮、救護車、打雷這些會嚇到的聲音。

## 小幫手的聲音
| 檔案 | 誰 |
|---|---|
| `sniff` | 甲甲（穿山甲）嗅嗅 |
| `mew` | 石石（石虎）喵 |
| `grunt` | 熊熊（台灣黑熊）嗯～ |
| `chirp` | 藍藍（台灣藍鵲）啾啾 |
| `bleat` | 花花（梅花鹿）呦 |
| `ooh` | 猴猴（台灣獼猴）嗚嗚 |

還沒用耳朵聽過（做的時候沒辦法聽），要在手機上聽一次。
