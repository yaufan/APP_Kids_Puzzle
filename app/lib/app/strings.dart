import '../core/board.dart';
import '../core/content.dart';
import '../core/jigsaw.dart';

/// Every word the app shows or says (Traditional Chinese, for Taiwan).
abstract final class Strings {
  /// The app's name: the only place to change it (and android:label in AndroidManifest.xml,
  /// CFBundleDisplayName and CFBundleName in ios/Runner/Info.plist; test/safety_test.dart checks
  /// they agree).
  static const appName = '拼拼樂工坊';

  // ---- buttons and titles
  static const home = '回工坊';
  static const again = '再聽一次';
  static const back = '回去';
  static const parent = '家長';
  static const cancel = '取消';
  static const backspace = '刪掉';
  static const taiwan = '台灣大拼圖';
  static const playAgain = '再拼一次';
  static const next = '下一張';
  static const nextOne = '下一個';
  static const change = '換小幫手';
  static const flip = '翻過來';
  static const help = '提示';
  static const pickBox = '選一盒拼圖';
  static const shapeBox = '形狀盒';
  static const insetBoards = '嵌板';
  static const locked = '完整版';

  static String taiwanCount(int n, int all) => '$n / $all';
  static String pieces(int n) => '$n 塊';

  // ---- the helper
  static const pickTitle = '選一個工坊小幫手';
  static const pickLine = '選一個小幫手，和你一起拼拼看！';

  static String hello(Helper h) => switch (h) {
        Helper.pangolin => '我是甲甲，我身上的鱗片，像一片一片小拼圖喔！',
        Helper.leopardCat => '我是石石，我的額頭有白白的線！',
        Helper.bear => '我是熊熊，我的胸口有白色的 V！',
        Helper.magpie => '我是藍藍，我的尾巴好長好長！',
        Helper.deer => '我是花花，我身上有白點點！',
        Helper.macaque => '我是猴猴，我最會爬樹了！',
      };

  static String welcome(Helper h) => '${h.call}我是${h.zh}。今天想拼什麼呀？';
  static const whatNow = '今天想拼什麼呀？';

  /// Little cheers, a different one each time.
  static List<String> cheers(Helper h) => switch (h) {
        Helper.pangolin => ['嗅嗅～好棒！', '甲甲好開心！', '放好了！'],
        Helper.leopardCat => ['喵～好棒！', '石石跳起來了！', '放好了！'],
        Helper.bear => ['嗯～好棒！', '熊熊拍拍手！', '放好了！'],
        Helper.magpie => ['啾啾！好棒！', '藍藍飛一圈！', '放好了！'],
        Helper.deer => ['呦～好棒！', '花花跳一下！', '放好了！'],
        Helper.macaque => ['嗚嗚！好棒！', '猴猴翻跟斗！', '放好了！'],
      };

  static String helpTurn(Helper h) => '${h.call}我幫你轉一下！';
  static const turnIt = '轉一轉，再試試看！';
  static const flipIt = '翻過來，再試試看！';
  static const tryAgain = '再試一次就好！';
  static const lookHere = '看，放這裡！';

  // ---- the workshop
  static const taiwanNote = '拼好一張圖，這裡就多一塊';
  static String fullOnly(String what) => '$what在完整版裡，請爸爸媽媽看看。';
  static const fullOnlyShort = '完整版才有喔，請爸爸媽媽看看。';

  // ---- 形狀洞洞
  static const shapesTitle = '形狀洞洞';
  static const shapesPick = '要玩形狀盒，還是嵌板？';
  static String shapeIn(String look, String zh) => '$look$zh，咚！掉進去了！';
  static String shapeAsk(String zh) => '$zh放在哪裡？';
  static const shapesDone = '全部放進去了！盒子打開囉！';
  static String insetDone(String zh) => '$zh拼好了！';

  // ---- 拼圖
  static const jigsawTitle = '拼圖';
  static const pickPicture = '選一張圖，要拼幾塊？';
  static String partLine(JigsawPiece p, Cut c) {
    final left = p.col == 0, top = p.row == 0, bottom = p.row == c.rows - 1;
    if (p.part == Part.corner) return '${top ? '上' : '下'}面的${left ? '左' : '右'}邊，角角放好了！';
    if (p.part == Part.edge) {
      if (top) return '上面的邊邊！';
      if (bottom) return '下面的邊邊！';
      return left ? '左邊的邊邊！' : '右邊的邊邊！';
    }
    return '放在中間！';
  }

  static String rectLine(JigsawPiece p, Cut c) {
    if (c.rows == 1) return p.col == 0 ? '放在左邊！' : (p.col == c.cols - 1 ? '放在右邊！' : '放在中間！');
    return '${p.row == 0 ? '上' : '下'}面的${p.col == 0 ? '左' : (p.col == c.cols - 1 ? '右' : '中間')}${p.col == 0 || p.col == c.cols - 1 ? '邊' : ''}！';
  }

  static const taiwanPlus = '台灣大拼圖多一塊！';
  static String bigger(int n) => '可以拼 $n 塊了！';

  // ---- 七巧板
  static const tangramTitle = '七巧板';
  static String tanPlaced(String zh) => '$zh，放好了！';
  static String tanDone(String zh) => '拼好了！是$zh！';
  static const tanHowTo = '點一下，它會轉一轉；平行四邊形要翻過來！';
  static const tanHowToAuto = '放到影子旁邊，它會自己轉正喔！';

  // ---- 照著拼
  static const blocksTitle = '照著拼';
  static const blocksAsk = '看小卡片，拼出一樣的！';
  static const blocksAskFill = '把影子填滿，怎麼拼都可以！';
  static String blockPlaced(String zh) => '$zh！';
  static String blocksDone(String zh) => '拼好了！是$zh！';
  static const blocksOther = '你用了不一樣的積木，也拼出來了耶！';
  static String left(int n) => '還有 $n 個';

  // ---- rest
  static const restTitle = '換你去做了！';
  static const restLine = '去收玩具、拼真的拼圖吧！';
  static const restNote = '爸爸媽媽可以解開';

  // ---- parent gate
  static const callParent = '請爸爸媽媽來';
  static const parentGateTitle = '家長關卡';
  static String gateQuestion(String a, String b) => '$a加$b等於多少？';
  static const gateRules = '用下面的數字回答';
  static const wrongAnswer = '不對喔，換一題';
  static String gateWait(int s) => '答錯三次，請等 $s 秒';

  // ---- parent mode
  static const parentTitle = '家長模式';
  static const levelTitle = '難度';
  static String levelLine(Level l) => '${l.zh}（${l.ages}）';
  static const levelNote = '小小：形狀洞洞、拼圖 2～4 塊、七巧板 2～3 塊（不用轉）。\n中：拼圖到 12 塊、七巧板 4～5 塊（放近了自己轉正）、照著拼有線。\n大：拼圖 9～24 塊、七巧板 7 塊（點一下轉）、照著拼只有外框。';
  static const playTime = '每次玩多久';
  static String minutes(int m) => '$m 分鐘';
  static const playTimeNote = '時間到了，正在拼的那張可以拼完（最多再 2 分鐘），然後休息一小時，或由家長解開。家長模式和 APP 在背景的時間不算。';
  static const resting = '現在是休息時間。';
  static const playOn = '讓小朋友繼續玩';
  static const turnTitle = '轉動和翻面';
  static const tapTurn = '大：七巧板點一下轉 45 度';
  static const tapTurnNote = '關掉的話，大的七巧板也會放近了自己轉正。';
  static const helpTitle = '幫忙';
  static const faint = '拼圖底下淡淡的圖';
  static const faintNote = '小小和中：拼的地方看得到整張圖淡淡的（中 9 塊以上只有虛線）。';
  static const magnet = '磁鐵（多近會被吸進去）';
  static const hints = '一陣子沒放好，位置會發亮';
  static const edgesFirst = '12 塊以上先給角和邊';
  static const talk = '說出「上面、旁邊、轉一轉」';
  static const talkNote = '研究發現常聽到這些空間的話的小朋友，空間能力比較好。';
  static const voiceTitle = '聲音';
  static const voice = '小幫手說話';
  static const slow = '說慢一點';
  static const music = '音樂';
  static const effects = '音效';
  static const modesTitle = '玩具盒';
  static const modesNote = '要出現在工坊架子上的玩具盒（照著拼從「中」開始）。';
  static const boxesTitle = '拼圖盒';
  static const progressTitle = '進度（小朋友看不到）';
  static String progress(int pictures, int insets, int tangrams, int cards) => '拼好 $pictures 張圖、$insets 塊嵌板、$tangrams 個七巧板、$cards 張照著拼';
  static String cutNow(Level l, Cut c) => '${l.zh}：現在拼到 ${c.count} 塊${c.tabs ? '（有凸凸的）' : '（長方形）'}';
  static String today(int minutes, int done) => '今天玩了 $minutes 分鐘，拼好 $done 個';
  static const together = '一起玩的小提醒';
  static const togetherNote = '多說「上面、旁邊、角角、邊邊、轉一轉、翻過來」；拼完了問問小朋友「熊的頭在哪裡？」。休息的時候，一起拼一個真的拼圖，或把玩具收回盒子裡（收玩具也是一種拼拼看）。';
  static const otherTitle = '其他';
  static const changeHelper = '換小幫手';
  static const fullVersion = '完整版';
  static const fullNote = '測試期間全部打開。關掉可以看免費版：形狀洞洞全部、拼圖的水果盒和動物盒、七巧板小小組。';
  static const fullSwitch = '完整版（測試中）';
  static const about = '關於';
  static const privacy = '不連網、不定位、沒有廣告、沒有帳號，也不要任何權限（不用相機、不用麥克風）。所有紀錄只存在這支手機裡。';
  static String version(String v) => '$appName $v';
  static String magnetLine(Magnet m) => m.zh;
}
