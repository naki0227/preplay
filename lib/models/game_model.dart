/// A secret role in an AI-made game, dealt by passing the phone
/// (see lib/models/role_deal.dart). count 0 means "everyone else".
class DealRole {
  final String name;
  final int count;
  final bool seesTopic;
  final String hint;

  const DealRole({required this.name, required this.count, required this.seesTopic, required this.hint});

  Map<String, dynamic> toJson() => {'name': name, 'count': count, 'seesTopic': seesTopic, 'hint': hint};

  factory DealRole.fromJson(Map<String, dynamic> json) => DealRole(
        name: json['name'] as String,
        count: json['count'] as int,
        seesTopic: json['seesTopic'] == true,
        hint: (json['hint'] as String?) ?? '',
      );
}

class GameModel {
  final String id;
  final String title;
  final String origin;
  final String rules;
  final List<String> tags;
  final List<String> topics; // New field for predefined topics
  // How many people and roughly how many minutes. Known for the bundled
  // games only; null for AI and community games.
  final int? minPlayers;
  final int? maxPlayers;
  final int? minutes;
  // Secret roles of an AI-made game; empty for everything else.
  final List<DealRole> roles;

  const GameModel({
    required this.id,
    required this.title,
    required this.origin,
    required this.rules,
    required this.tags,
    this.topics = const [],
    this.minPlayers,
    this.maxPlayers,
    this.minutes,
    this.roles = const [],
  });

  /// "2〜8人・約5分", or null when unknown.
  String? get playInfo {
    final parts = [
      if (minPlayers != null && maxPlayers != null)
        minPlayers == maxPlayers ? '$minPlayers人' : '$minPlayers〜$maxPlayers人',
      if (minutes != null) '約$minutes分',
    ];
    return parts.isEmpty ? null : parts.join('・');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'origin': origin,
      'rules': rules,
      'tags': tags,
      'topics': topics,
      if (minPlayers != null) 'minPlayers': minPlayers,
      if (maxPlayers != null) 'maxPlayers': maxPlayers,
      if (minutes != null) 'minutes': minutes,
      if (roles.isNotEmpty) 'roles': [for (final r in roles) r.toJson()],
    };
  }

  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'],
      title: json['title'],
      origin: json['origin'],
      rules: json['rules'],
      tags: List<String>.from(json['tags']),
      topics: json['topics'] != null ? List<String>.from(json['topics']) : [],
      minPlayers: json['minPlayers'] as int?,
      maxPlayers: json['maxPlayers'] as int?,
      minutes: json['minutes'] as int?,
      roles: [
        for (final r in (json['roles'] as List?) ?? const []) DealRole.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
    );
  }

  static const List<GameModel> mvpGames = [
    // --- MVP Games ---
    GameModel(
      id: 'renso_shiritori', 
      title: '連想しりとり', 
      origin: '日本', 
      rules: '前の言葉から「連想するもの」で繋ぐ。\nりんご → 赤い → 郵便ポスト。\n説明できなければ負け。', 
      minPlayers: 2, maxPlayers: 8, minutes: 5,
      tags: ['all'],
      topics: ['色が赤いもの', '丸いもの', '冬にあるもの', 'コンビニで買えるもの', '3文字のもの', '空を飛ぶもの'],
    ),
    GameModel(id: 'chaichen', title: 'チャイチェン', origin: '中国', rules: '数字を言い合う反射系ゲーム。\n出した指の合計数と宣言が一致したら勝ち。\n一瞬の集中力。', minPlayers: 2, maxPlayers: 2, minutes: 3, tags: ['noisy', 'standing']),
    GameModel(id: 'mukuchipa', title: 'ムクチパ', origin: '韓国', rules: '進化系じゃんけん。勝った方が攻撃。\n相手の手を自分と一致させたら勝ち。\n1ゲーム約30秒。', minPlayers: 2, maxPlayers: 2, minutes: 3, tags: ['noisy', 'standing']),
    
    // --- New Content Injection (v1.5 Fix) ---
    // Talking & Quiet (Waiting/Cafe)
    GameModel(id: 'ato_dashi_janken', title: '後出し負けじゃんけん', origin: '日本', rules: '親が出した手に「負ける」手を素早く出す。\nつられて勝ってしまったら負け。\n脳の体操。', minPlayers: 2, maxPlayers: 10, minutes: 3, tags: ['quiet', 'waiting']),
    GameModel(id: 'limit_shiritori', title: '文字数制限しりとり', origin: '日本', rules: '「3文字だけ」「4文字だけ」と文字数を決めてしりとり。\n語彙力が試される。', minPlayers: 2, maxPlayers: 8, minutes: 5, tags: ['quiet', 'waiting'], topics: ['3文字', '4文字', '5文字', '2文字']),
    GameModel(id: 'first_impression', title: '第一印象ゲーム', origin: '合コン', rules: '「この中で一番〇〇そうな人は？」\nせーので指差す。\n自分を指差されたら負け（または勝ち）。', minPlayers: 4, maxPlayers: 10, minutes: 5, tags: ['noisy', 'drinking'], topics: ['モテそうな人', '金遣いが荒そうな人', '実は腹黒そうな人', '将来社長になりそうな人', '朝が弱そうな人', '料理が上手そうな人', '無人島で生き残りそうな人', '隠し事が下手そうな人']),
    GameModel(id: 'amanojaku', title: 'あまのじゃくゲーム', origin: '日本', rules: '親の質問に「はい/いいえ」を逆に答える。\n「あなたは人間ですか？」→「いいえ」\nつられて正解したら負け。', minPlayers: 2, maxPlayers: 8, minutes: 3, tags: ['quiet', 'waiting'], topics: ['あなたは人間ですか？', '今日は晴れていますか？', 'お腹は空いていますか？', '犬は好きですか？', '今は夜ですか？', '靴をはいていますか？', '日本に住んでいますか？', '眠いですか？']),
    GameModel(id: 'katakana_kinshi', title: 'カタカナ禁止ゲーム', origin: '日本', rules: '会話の中でカタカナ語を使ったらアウト。\n「コンセンサス」「ランチ」などがNG。\n自然な会話ほど難しい。', minPlayers: 2, maxPlayers: 10, minutes: 10, tags: ['all'], topics: ['好きな食べ物', '休日の予定', 'スマホの使い方', '旅行の計画', '好きなスポーツ', 'おすすめのお店']),
    GameModel(id: 'double_booking', title: 'ダブルブッキング', origin: '会話', rules: '架空の「ヤバい状況」をどう切り抜けるか言い訳を考える。\n全員で採点し、一番苦しい言い訳をした人が負け。', minPlayers: 3, maxPlayers: 8, minutes: 10, tags: ['drinking'], topics: ['デートのダブルブッキング', '寝坊して遅刻', '親友の秘密をバラした', '借りた物を壊した']),
    GameModel(id: 'good_and_new', title: 'Good & New', origin: '米国', rules: '24時間以内にあった「良かったこと」や「新しい発見」を話す。\n拍手で称える。\nポジティブな雰囲気を作る。', minPlayers: 3, maxPlayers: 20, minutes: 10, tags: ['quiet', 'icebreak']),
    GameModel(id: 'two_truths_one_lie', title: '2つの真実、1つの嘘', origin: '欧米', rules: '自己紹介に嘘を1つ混ぜる。\nどれが嘘か見抜く。\n初対面同士に最適。', minPlayers: 3, maxPlayers: 10, minutes: 10, tags: ['icebreak'], topics: ['子どものころの話', '食べ物の好き嫌い', '旅行の思い出', '特技', '最近びっくりしたこと', '家族の話']),
    
    // Action & Noisy (Park/Outdoor)
    GameModel(id: 'ninja', title: '忍者ゲーム', origin: '日本', rules: '「シュシュシュ」と言いながら手裏剣を投げる動作。\n投げられた人は避けるか防御。\nリズムに乗れないと負け。', minPlayers: 3, maxPlayers: 10, minutes: 5, tags: ['standing', 'noisy']),
    GameModel(id: 'zip_zap_boing', title: 'Zip Zap Boing', origin: '演劇', rules: '円になり、ポーズと共に言葉を回す。\nZip(隣へ), Zap(指差した人へ), Boing(拒否)。\n間違えたら脱落。', minPlayers: 5, maxPlayers: 20, minutes: 5, tags: ['standing', 'group']),
    GameModel(id: 'human_copy', title: '人間ミラー', origin: 'ワークショップ', rules: 'ペアになり、片方の動きを鏡のように真似る。\n主導権を交代しながらスムーズに動く。', minPlayers: 2, maxPlayers: 10, minutes: 3, tags: ['standing']),
    GameModel(id: 'daruma_san', title: 'だるまさんが転んだ (アレンジ)', origin: '日本', rules: '鬼が振り返った時、指定されたポーズ（ゴリラ、変顔など）をとる。\n笑ったらアウト。', minPlayers: 4, maxPlayers: 20, minutes: 10, tags: ['standing', 'noisy'], topics: ['ゴリラ', '変顔', '招き猫', 'フラミンゴ', 'ボディビルダー', '忍者', '力士', '自由の女神', 'バレリーナ', 'ロボット']),
    GameModel(id: 'hankerchief_drop', title: 'ハンカチ落とし', origin: '万国', rules: '輪になって座り、鬼が背後にハンカチを落とす。\n気づいて追いかける。', minPlayers: 6, maxPlayers: 20, minutes: 10, tags: ['sitting', 'park']),

    // Thinking & Logic
    GameModel(id: 'black_stories', title: 'ウミガメのスープ', origin: '水平思考', rules: '不可解な物語の結末を聞き、「はい/いいえ」で答えられる質問をして真相を暴く。', minPlayers: 2, maxPlayers: 8, minutes: 15, tags: ['waiting', 'quiet'], topics: ['レストランでウミガメのスープを飲んだ男が自殺した。なぜ？', '男は喉が渇いていたが、水を飲んで死んだ。なぜ？']),
    GameModel(id: 'word_chain_memory', title: '山手線ゲーム (記憶)', origin: '日本', rules: 'テーマに沿って単語を言うが、前の人が言った単語を全て繰り返してから自分の単語を言う。\n記憶力の限界に挑戦。', minPlayers: 3, maxPlayers: 8, minutes: 5, tags: ['noisy'], topics: ['果物', '国の名前', '駅の名前', '野菜', '動物', 'スポーツ', '色', '楽器', '都道府県', 'お菓子', '魚', '職業']),
    GameModel(id: 'estimated_number', title: 'フェルミ推定バトル', origin: 'ビジネス', rules: '「日本にある電柱の数は？」\n論理的に概算し、答えの桁数が近い人が勝ち。', minPlayers: 2, maxPlayers: 8, minutes: 10, tags: ['quiet', 'thinking'], topics: ['日本にある電柱の数は？', '日本にあるコンビニの数は？', '東京にあるマンホールの数は？', '1年間に日本で売れる傘の本数は？', '日本で1日に食べられるおにぎりの数は？', '日本にある信号機の数は？', '人の髪の毛の本数は？', '日本にある小学校の数は？']),
    GameModel(id: 'insider_game', title: 'インサイダー', origin: 'ボードゲーム', rules: 'お題当てクイズだが、1人だけ答えを知っている「インサイダー」がいる。\nクイズ後、誰がインサイダーか当てる。', minPlayers: 4, maxPlayers: 8, minutes: 15, tags: ['waiting', 'thinking'], topics: ['りんご', '富士山', '自転車', '冷蔵庫', '図書館', 'パンダ', '花火', '消しゴム', '新幹線', '雪だるま', 'カレーライス', '観覧車', '歯ブラシ', '傘', 'ピアノ', '宇宙', '忍者', '温泉', '信号機', 'ハンバーガー']),
    
    // Traditional / Global
    GameModel(id: 'i_spy', title: 'I Spy (アイスパイ)', origin: '欧米', rules: '「私の目は〇〇色のものを見ています」\n周りのものから、それが何かを当てる。\n子供も楽しめる。', minPlayers: 2, maxPlayers: 6, minutes: 5, tags: ['waiting', 'kids'], topics: ['赤いもの', '青いもの', '丸いもの', '四角いもの', 'やわらかそうなもの', '光っているもの', '文字が書いてあるもの']),
    GameModel(id: 'twenty_questions', title: '20の扉', origin: '欧米', rules: '親が思い浮かべた物を、20回以内の「はい/いいえ」質問で当てる。\n「それは生き物ですか？」「大きいですか？」', minPlayers: 2, maxPlayers: 8, minutes: 10, tags: ['waiting', 'quiet'], topics: ['りんご', '富士山', '自転車', '冷蔵庫', 'パンダ', '花火', '消しゴム', '新幹線', '雪だるま', '観覧車', '歯ブラシ', '傘', 'ピアノ', '忍者', '信号機', 'キリン', 'スマホ', 'お寿司', 'サンタクロース', 'ロケット']),
    GameModel(id: 'mafia', title: 'マフィア (人狼)', origin: 'ロシア', rules: '市民とマフィアに分かれて議論。\n夜にマフィアが市民を襲い、昼に市民がマフィアを処刑する。', minPlayers: 6, maxPlayers: 15, minutes: 20, tags: ['group', 'thinking']),
    
    // Quick & Simple
    GameModel(id: 'chiyocore', title: 'バリバリ伝説', origin: '日本', rules: '「バリバリ」と言いながら特定のアクション。\nローカルルールを作って遊ぶ、即興リズムゲーム。', minPlayers: 3, maxPlayers: 10, minutes: 5, tags: ['noisy']),
    GameModel(id: '10_seconds', title: '体内時計10秒', origin: '万国', rules: '目を閉じて、10秒経ったと思ったら手を挙げる。\n一番近かった人が勝ち。', minPlayers: 2, maxPlayers: 10, minutes: 3, tags: ['quiet']),
    GameModel(id: 'eye_contact', title: 'アイコンタクト', origin: '沈黙', rules: '全員で目を合わせないようにする。\n目が合ってしまったらアウト（または何か罰ゲーム）。', minPlayers: 3, maxPlayers: 10, minutes: 3, tags: ['quiet', 'waiting']),
    
    // Existing MVP Games (Retained)
    GameModel(
      id: 'contact', 
      title: 'コンタクト', 
      origin: '欧州', 
      rules: '親が決めた単語を、子が推測して当てる。\n「あ」から始まると聞き、仲間と通じ合えば\n親からヒントを引き出せる。', 
      minPlayers: 3, maxPlayers: 8, minutes: 15,
      tags: ['quiet', 'waiting'],
      topics: ['学校にあるもの', '冷蔵庫の中身', '映画のタイトル', '有名人'],
    ),
    GameModel(
      id: 'word_wolf', 
      title: 'ワードウルフ', 
      origin: '日本', 
      rules: 'お題が少しだけ違う少数派（ウルフ）を探す。\n会話だけで「自分と違うか？」を探る。\n騙し合い。', 
      minPlayers: 4, maxPlayers: 8, minutes: 10,
      tags: ['quiet', 'waiting'],
      topics: ['スマホ vs ガラケー', 'うどん vs そば', '犬 vs 猫', 'きのこ vs たけのこ', '夏 vs 冬', '朝型 vs 夜型', 'コーヒー vs 紅茶', '海 vs 山', 'ラーメン vs カレー', '電車 vs バス', '映画館 vs 遊園地', '温泉 vs プール', '焼肉 vs 寿司', '雪 vs 雨', '漫画 vs アニメ', 'ピアノ vs ギター', 'サッカー vs 野球', '図書館 vs 本屋', '誕生日 vs クリスマス', '新幹線 vs 飛行機', 'パン vs ごはん', '動物園 vs 水族館', '花火 vs お祭り', 'ハンバーガー vs ピザ'],
    ),
    GameModel(id: 'ng_word', title: 'NGワードゲーム', origin: '日本', rules: '自分の頭の上の単語を言ったら負け。\n相手にその言葉を言わせるように誘導する。\n心理戦。', minPlayers: 3, maxPlayers: 8, minutes: 15, tags: ['all']),
    GameModel(id: 'reverse_shiritori', title: '逆しりとり', origin: '日本', rules: '「ん」から始めて、前の文字で繋ぐ。\nん → きりん → たぬき。\n脳の普段使わない部分を使う。', minPlayers: 2, maxPlayers: 8, minutes: 5, tags: ['quiet']),
    GameModel(id: '369', title: '3・6・9', origin: '韓国', rules: '1から順に数字を言うが、3, 6, 9がつく時は\n数字を言わずに手を叩く。\nミスしたら負け。', minPlayers: 3, maxPlayers: 10, minutes: 3, tags: ['noisy']),
    GameModel(id: 'silent_shiritori', title: '沈黙のしりとり', origin: '日本', rules: '声を出さず、ジェスチャーだけでしりとり。\n何と言ったか伝わらなくなったら終了。\n列待ちに最適。', minPlayers: 2, maxPlayers: 6, minutes: 5, tags: ['waiting']),
    GameModel(id: 'category_shiritori', title: 'カテゴリしりとり', origin: '日本', rules: '「食べ物」「動物」など縛りをつける。\n出せなくなったら負け。\n意外と難しい。', minPlayers: 2, maxPlayers: 8, minutes: 5, tags: ['all'], topics: ['国名', 'ポケモン', '歴史上の人物', '4文字の言葉', '赤いもの']),
    GameModel(id: 'who_am_i', title: '私は誰でしょう？', origin: '欧州', rules: '自分が「物」や「人」になりきり、\n相手からの「はい/いいえ」の質問に答える。', minPlayers: 2, maxPlayers: 8, minutes: 10, tags: ['quiet'], topics: ['織田信長', 'ドラえもん', 'ライオン', 'スカイツリー', 'パンダ', '忍者', 'サンタクロース', '冷蔵庫', '富士山', '桃太郎']),
    GameModel(id: 'yubisuma', title: '指スマ', origin: '日本', rules: '全員の親指が上がる数を予想して叫ぶ。\n当たったら片手を抜ける。\n先に両手抜けた人の勝ち。', minPlayers: 2, maxPlayers: 8, minutes: 5, tags: ['noisy', 'standing']),
    GameModel(id: 'drawing_message', title: 'お絵描き伝言', origin: '日本', rules: '背中に指で絵を書いて、何を描いたか当てる。\n感触だけで伝える。', minPlayers: 2, maxPlayers: 6, minutes: 5, tags: ['waiting'], topics: ['星', 'ハート', '魚', 'ドラえもん', '家', '木', '車']),
    GameModel(id: 'rhythm_game', title: 'リズム遊び', origin: '日本', rules: '一定のリズムで名前を呼び合う。\nテンポがずれたら負け。\n集中力勝負。', minPlayers: 3, maxPlayers: 10, minutes: 5, tags: ['noisy'], topics: ['野菜の名前', '国の名前', '色の名前']),
    GameModel(id: 'liar_game', title: '嘘つきは誰だ', origin: '日本', rules: '3つのエピソードを話し、1つだけ嘘を混ぜる。\nどれが嘘か見破られたら負け。', minPlayers: 3, maxPlayers: 8, minutes: 10, tags: ['quiet'], topics: ['休日の過ごし方', '学生時代の話', '最近買ったもの', '失敗談', '好きなもの', '行ったことのある場所']),
    GameModel(id: 'intro_quiz', title: 'イントロクイズ', origin: '日本', rules: '鼻歌だけで曲名を当てる。\n意外と伝わらないもどかしさを楽しむ。', minPlayers: 2, maxPlayers: 8, minutes: 10, tags: ['all'], topics: ['かえるの合唱', 'きらきら星', 'ハッピーバースデー', 'チューリップ', 'ぶんぶんぶん', '森のくまさん', 'さくらさくら', 'どんぐりころころ', '大きな栗の木の下で', 'むすんでひらいて', 'ジングルベル', 'ふるさと']),
    GameModel(id: 'story_relay', title: 'ストーリーリレー', origin: '日本', rules: '1人1文ずつ物語を繋いでいく。\n予想外の結末を目指す。', minPlayers: 2, maxPlayers: 8, minutes: 10, tags: ['waiting'], topics: ['昔々、冷蔵庫の中に小さな王国がありました。', '朝起きたら、しっぽが生えていた。', '駅のホームで、知らないおじいさんに地図を渡された。', '宇宙人が初めてコンビニに来た。', '学校の屋上に、扉がひとつ増えていた。', '飼い猫が急にしゃべり出した。']),
    GameModel(id: 'mind_reading', title: 'マインドリーディング', origin: '欧米', rules: '「お互いに連想するもの」を同時に言い、\n一致するまで繰り返す。', minPlayers: 2, maxPlayers: 4, minutes: 5, tags: ['quiet'], topics: ['海 と 山', 'りんご と 消防車', '雪 と 砂糖', '月 と 卵', '犬 と 自転車', '夏 と 冬']),
    GameModel(id: 'gesture_game', title: 'ジェスチャー', origin: '万国', rules: 'お題を身振り手振りだけで伝える。\n言葉は一切禁止。', minPlayers: 3, maxPlayers: 10, minutes: 10, tags: ['waiting', 'standing'], topics: ['野球', '料理', '水泳', 'ゴリラ', '歯みがき', '満員電車', '雪かき', 'サーフィン', '寝坊', 'カラオケ', '洗濯物を干す', '自撮り', 'ボウリング', 'ラーメンを食べる', '犬の散歩', '綱引き', '傘をさす', '釣り', 'オーケストラの指揮者', 'ペンギン']),
  ];
}
