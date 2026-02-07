class GameModel {
  final String id;
  final String title;
  final String origin;
  final String rules;
  final List<String> tags;
  final List<String> topics; // New field for predefined topics

  const GameModel({
    required this.id,
    required this.title,
    required this.origin,
    required this.rules,
    required this.tags,
    this.topics = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'origin': origin,
      'rules': rules,
      'tags': tags,
      'topics': topics,
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
    );
  }

  static const List<GameModel> mvpGames = [
    // --- MVP Games ---
    GameModel(
      id: 'renso_shiritori', 
      title: '連想しりとり', 
      origin: '日本', 
      rules: '前の言葉から「連想するもの」で繋ぐ。\nりんご → 赤い → 郵便ポスト。\n説明できなければ負け。', 
      tags: ['all'],
      topics: ['色が赤いもの', '丸いもの', '冬にあるもの', 'コンビニで買えるもの', '3文字のもの', '空を飛ぶもの'],
    ),
    GameModel(id: 'chaichen', title: 'チャイチェン', origin: '中国', rules: '数字を言い合う反射系ゲーム。\n出した指の合計数と宣言が一致したら勝ち。\n一瞬の集中力。', tags: ['noisy', 'standing']),
    GameModel(id: 'mukuchipa', title: 'ムクチパ', origin: '韓国', rules: '進化系じゃんけん。勝った方が攻撃。\n相手の手を自分と一致させたら勝ち。\n1ゲーム約30秒。', tags: ['noisy', 'standing']),
    
    // --- New Content Injection (v1.5 Fix) ---
    // Talking & Quiet (Waiting/Cafe)
    GameModel(id: 'ato_dashi_janken', title: '後出し負けじゃんけん', origin: '日本', rules: '親が出した手に「負ける」手を素早く出す。\nつられて勝ってしまったら負け。\n脳の体操。', tags: ['quiet', 'waiting']),
    GameModel(id: 'limit_shiritori', title: '文字数制限しりとり', origin: '日本', rules: '「3文字だけ」「4文字だけ」と文字数を決めてしりとり。\n語彙力が試される。', tags: ['quiet', 'waiting'], topics: ['3文字', '4文字', '5文字', '2文字']),
    GameModel(id: 'first_impression', title: '第一印象ゲーム', origin: '合コン', rules: '「この中で一番〇〇そうな人は？」\nせーので指差す。\n自分を指差されたら負け（または勝ち）。', tags: ['noisy', 'drinking'], topics: ['モテそうな人', '金遣いが荒そうな人', '実は腹黒そうな人', '将来社長になりそうな人']),
    GameModel(id: 'amanojaku', title: 'あまのじゃくゲーム', origin: '日本', rules: '親の質問に「はい/いいえ」を逆に答える。\n「あなたは人間ですか？」→「いいえ」\nつられて正解したら負け。', tags: ['quiet', 'waiting']),
    GameModel(id: 'katakana_kinshi', title: 'カタカナ禁止ゲーム', origin: '日本', rules: '会話の中でカタカナ語を使ったらアウト。\n「コンセンサス」「ランチ」などがNG。\n自然な会話ほど難しい。', tags: ['all']),
    GameModel(id: 'double_booking', title: 'ダブルブッキング', origin: '会話', rules: '架空の「ヤバい状況」をどう切り抜けるか言い訳を考える。\n全員で採点し、一番苦しい言い訳をした人が負け。', tags: ['drinking'], topics: ['デートのダブルブッキング', '寝坊して遅刻', '親友の秘密をバラした', '借りた物を壊した']),
    GameModel(id: 'good_and_new', title: 'Good & New', origin: '米国', rules: '24時間以内にあった「良かったこと」や「新しい発見」を話す。\n拍手で称える。\nポジティブな雰囲気を作る。', tags: ['quiet', 'icebreak']),
    GameModel(id: 'two_truths_one_lie', title: '2つの真実、1つの嘘', origin: '欧米', rules: '自己紹介に嘘を1つ混ぜる。\nどれが嘘か見抜く。\n初対面同士に最適。', tags: ['icebreak']),
    
    // Action & Noisy (Park/Outdoor)
    GameModel(id: 'ninja', title: '忍者ゲーム', origin: '日本', rules: '「シュシュシュ」と言いながら手裏剣を投げる動作。\n投げられた人は避けるか防御。\nリズムに乗れないと負け。', tags: ['standing', 'noisy']),
    GameModel(id: 'zip_zap_boing', title: 'Zip Zap Boing', origin: '演劇', rules: '円になり、ポーズと共に言葉を回す。\nZip(隣へ), Zap(指差した人へ), Boing(拒否)。\n間違えたら脱落。', tags: ['standing', 'group']),
    GameModel(id: 'human_copy', title: '人間ミラー', origin: 'ワークショップ', rules: 'ペアになり、片方の動きを鏡のように真似る。\n主導権を交代しながらスムーズに動く。', tags: ['standing']),
    GameModel(id: 'daruma_san', title: 'だるまさんが転んだ (アレンジ)', origin: '日本', rules: '鬼が振り返った時、指定されたポーズ（ゴリラ、変顔など）をとる。\n笑ったらアウト。', tags: ['standing', 'noisy']),
    GameModel(id: 'hankerchief_drop', title: 'ハンカチ落とし', origin: '万国', rules: '輪になって座り、鬼が背後にハンカチを落とす。\n気づいて追いかける。', tags: ['sitting', 'park']),

    // Thinking & Logic
    GameModel(id: 'black_stories', title: 'ウミガメのスープ', origin: '水平思考', rules: '不可解な物語の結末を聞き、「はい/いいえ」で答えられる質問をして真相を暴く。', tags: ['waiting', 'quiet'], topics: ['レストランでウミガメのスープを飲んだ男が自殺した。なぜ？', '男は喉が渇いていたが、水を飲んで死んだ。なぜ？']),
    GameModel(id: 'word_chain_memory', title: '山手線ゲーム (記憶)', origin: '日本', rules: 'テーマに沿って単語を言うが、前の人が言った単語を全て繰り返してから自分の単語を言う。\n記憶力の限界に挑戦。', tags: ['noisy']),
    GameModel(id: 'estimated_number', title: 'フェルミ推定バトル', origin: 'ビジネス', rules: '「日本にある電柱の数は？」\n論理的に概算し、答えの桁数が近い人が勝ち。', tags: ['quiet', 'thinking']),
    GameModel(id: 'insider_game', title: 'インサイダー', origin: 'ボードゲーム', rules: 'お題当てクイズだが、1人だけ答えを知っている「インサイダー」がいる。\nクイズ後、誰がインサイダーか当てる。', tags: ['waiting', 'thinking']),
    
    // Traditional / Global
    GameModel(id: 'i_spy', title: 'I Spy (アイスパイ)', origin: '欧米', rules: '「私の目は〇〇色のものを見ています」\n周りのものから、それが何かを当てる。\n子供も楽しめる。', tags: ['waiting', 'kids']),
    GameModel(id: 'twenty_questions', title: '20の扉', origin: '欧米', rules: '親が思い浮かべた物を、20回以内の「はい/いいえ」質問で当てる。\n「それは生き物ですか？」「大きいですか？」', tags: ['waiting', 'quiet']),
    GameModel(id: 'mafia', title: 'マフィア (人狼)', origin: 'ロシア', rules: '市民とマフィアに分かれて議論。\n夜にマフィアが市民を襲い、昼に市民がマフィアを処刑する。', tags: ['group', 'thinking']),
    
    // Quick & Simple
    GameModel(id: 'chiyocore', title: 'バリバリ伝説', origin: '日本', rules: '「バリバリ」と言いながら特定のアクション。\nローカルルールを作って遊ぶ、即興リズムゲーム。', tags: ['noisy']),
    GameModel(id: '10_seconds', title: '体内時計10秒', origin: '万国', rules: '目を閉じて、10秒経ったと思ったら手を挙げる。\n一番近かった人が勝ち。', tags: ['quiet']),
    GameModel(id: 'eye_contact', title: 'アイコンタクト', origin: '沈黙', rules: '全員で目を合わせないようにする。\n目が合ってしまったらアウト（または何か罰ゲーム）。', tags: ['quiet', 'waiting']),
    
    // Existing MVP Games (Retained)
    GameModel(
      id: 'contact', 
      title: 'コンタクト', 
      origin: '欧州', 
      rules: '親が決めた単語を、子が推測して当てる。\n「あ」から始まると聞き、仲間と通じ合えば\n親からヒントを引き出せる。', 
      tags: ['quiet', 'waiting'],
      topics: ['学校にあるもの', '冷蔵庫の中身', '映画のタイトル', '有名人'],
    ),
    GameModel(
      id: 'word_wolf', 
      title: 'ワードウルフ', 
      origin: '日本', 
      rules: 'お題が1人だけ違う人（ウルフ）を探す。\n会話だけで「自分と違うか？」を探る。\n騙し合い。', 
      tags: ['quiet', 'waiting'],
      topics: ['スマホ vs ガラケー', 'うどん vs そば', '犬 vs 猫', 'きのこ vs たけのこ', '夏 vs 冬', '朝型 vs 夜型'],
    ),
    GameModel(id: 'ng_word', title: 'NGワードゲーム', origin: '日本', rules: '自分の頭の上の単語を言ったら負け。\n相手にその言葉を言わせるように誘導する。\n心理戦。', tags: ['all']),
    GameModel(id: 'reverse_shiritori', title: '逆しりとり', origin: '日本', rules: '「ん」から始めて、前の文字で繋ぐ。\nん → きりん → たぬき。\n脳の普段使わない部分を使う。', tags: ['quiet']),
    GameModel(id: '369', title: '3・6・9', origin: '韓国', rules: '1から順に数字を言うが、3, 6, 9がつく時は\n数字を言わずに手を叩く。\nミスしたら負け。', tags: ['noisy']),
    GameModel(id: 'silent_shiritori', title: '沈黙のしりとり', origin: '日本', rules: '声を出さず、ジェスチャーだけでしりとり。\n何と言ったか伝わらなくなったら終了。\n列待ちに最適。', tags: ['waiting']),
    GameModel(id: 'category_shiritori', title: 'カテゴリしりとり', origin: '日本', rules: '「食べ物」「動物」など縛りをつける。\n出せなくなったら負け。\n意外と難しい。', tags: ['all'], topics: ['国名', 'ポケモン', '歴史上の人物', '4文字の言葉', '赤いもの']),
    GameModel(id: 'who_am_i', title: '私は誰でしょう？', origin: '欧州', rules: '自分が「物」や「人」になりきり、\n相手からの「はい/いいえ」の質問に答える。', tags: ['quiet'], topics: ['織田信長', 'ドラえもん', 'ライオン', 'スカイツリー']),
    GameModel(id: 'yubisuma', title: '指スマ', origin: '日本', rules: '全員の親指が上がる数を予想して叫ぶ。\n当たったら片手を抜ける。\n先に両手抜けた人の勝ち。', tags: ['noisy', 'standing']),
    GameModel(id: 'drawing_message', title: 'お絵描き伝言', origin: '日本', rules: '背中に指で絵を書いて、何を描いたか当てる。\n感触だけで伝える。', tags: ['waiting'], topics: ['星', 'ハート', '魚', 'ドラえもん', '家', '木', '車']),
    GameModel(id: 'rhythm_game', title: 'リズム遊び', origin: '日本', rules: '一定のリズムで名前を呼び合う。\nテンポがずれたら負け。\n集中力勝負。', tags: ['noisy'], topics: ['野菜の名前', '国の名前', '色の名前']),
    GameModel(id: 'liar_game', title: '嘘つきは誰だ', origin: '日本', rules: '3つのエピソードを話し、1つだけ嘘を混ぜる。\nどれが嘘か見破られたら負け。', tags: ['quiet']),
    GameModel(id: 'intro_quiz', title: 'イントロクイズ', origin: '日本', rules: '鼻歌だけで曲名を当てる。\n意外と伝わらないもどかしさを楽しむ。', tags: ['all']),
    GameModel(id: 'story_relay', title: 'ストーリーリレー', origin: '日本', rules: '1人1文ずつ物語を繋いでいく。\n予想外の結末を目指す。', tags: ['waiting']),
    GameModel(id: 'mind_reading', title: 'マインドリーディング', origin: '欧米', rules: '「お互いに連想するもの」を同時に言い、\n一致するまで繰り返す。', tags: ['quiet']),
    GameModel(id: 'gesture_game', title: 'ジェスチャー', origin: '万国', rules: 'お題を身振り手振りだけで伝える。\n言葉は一切禁止。', tags: ['waiting', 'standing'], topics: ['野球', '料理', '水泳', 'ゴリラ']),
  ];
}
