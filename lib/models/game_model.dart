class GameModel {
  final String id;
  final String title;
  final String origin;
  final String rules;
  final List<String> tags;

  const GameModel({
    required this.id,
    required this.title,
    required this.origin,
    required this.rules,
    required this.tags,
  });

  static const List<GameModel> mvpGames = [
    GameModel(id: 'renso_shiritori', title: '連想しりとり', origin: '日本', rules: '前の言葉から「連想するもの」で繋ぐ。\nりんご → 赤い → 郵便ポスト。\n説明できなければ負け。', tags: ['all']),
    GameModel(id: 'chaichen', title: 'チャイチェン', origin: '中国', rules: '数字を言い合う反射系ゲーム。\n出した指の合計数と宣言が一致したら勝ち。\n一瞬の集中力。', tags: ['noisy', 'standing']),
    GameModel(id: 'mukuchipa', title: 'ムクチパ', origin: '韓国', rules: '進化系じゃんけん。勝った方が攻撃。\n相手の手を自分と一致させたら勝ち。\n1ゲーム約30秒。', tags: ['noisy', 'standing']),
    GameModel(id: 'thumb_war', title: 'サムウォー', origin: 'イギリス', rules: '親指を組み、相手の指を10秒押さえる。\n先に3回押さえ込んだ方の勝ち。\n1ゲーム約1分。', tags: ['standing']),
    GameModel(id: 'contact', title: 'コンタクト', origin: '欧州', rules: '親が決めた単語を、子が推測して当てる。\n「あ」から始まると聞き、仲間と通じ合えば\n親からヒントを引き出せる。', tags: ['quiet', 'waiting']),
    GameModel(id: 'word_wolf', title: 'ワードウルフ', origin: '日本', rules: 'お題が1人だけ違う人（ウルフ）を探す。\n会話だけで「自分と違うか？」を探る。\n騙し合い。', tags: ['quiet', 'waiting']),
    GameModel(id: 'ng_word', title: 'NGワードゲーム', origin: '日本', rules: '自分の頭の上の単語を言ったら負け。\n相手にその言葉を言わせるように誘導する。\n心理戦。', tags: ['all']),
    GameModel(id: 'reverse_shiritori', title: '逆しりとり', origin: '日本', rules: '「ん」から始めて、前の文字で繋ぐ。\nん → きりん → たぬき。\n脳の普段使わない部分を使う。', tags: ['quiet']),
    GameModel(id: '369', title: '3・6・9', origin: '韓国', rules: '1から順に数字を言うが、3, 6, 9がつく時は\n数字を言わずに手を叩く。\nミスしたら負け。', tags: ['noisy']),
    GameModel(id: 'silent_shiritori', title: '沈黙のしりとり', origin: '日本', rules: '声を出さず、ジェスチャーだけでしりとり。\n何と言ったか伝わらなくなったら終了。\n列待ちに最適。', tags: ['waiting']),
    GameModel(id: 'category_shiritori', title: 'カテゴリしりとり', origin: '日本', rules: '「食べ物」「動物」など縛りをつける。\n出せなくなったら負け。\n意外と難しい。', tags: ['all']),
    GameModel(id: 'who_am_i', title: '私は誰でしょう？', origin: '欧州', rules: '自分が「物」や「人」になりきり、\n相手からの「はい/いいえ」の質問に答える。\n20問以内に当てさせる。', tags: ['quiet']),
    GameModel(id: 'yubisuma', title: '指スマ', origin: '日本', rules: '全員の親指が上がる数を予想して叫ぶ。\n当たったら片手を抜ける。\n先に両手抜けた人の勝ち。', tags: ['noisy', 'standing']),
    GameModel(id: 'drawing_message', title: 'お絵描き伝言', origin: '日本', rules: '背中に指で絵を書いて、何を描いたか当てる。\n感触だけで伝える。', tags: ['waiting']),
    GameModel(id: 'rhythm_game', title: 'リズム遊び', origin: '日本', rules: '一定のリズムで名前を呼び合う。\nテンポがずれたら負け。\n集中力勝負。', tags: ['noisy']),
    GameModel(id: 'liar_game', title: '嘘つきは誰だ', origin: '日本', rules: '3つのエピソードを話し、1つだけ嘘を混ぜる。\nどれが嘘か見破られたら負け。', tags: ['quiet']),
    GameModel(id: 'intro_quiz', title: 'イントロクイズ', origin: '日本', rules: '鼻歌だけで曲名を当てる。\n意外と伝わらないもどかしさを楽しむ。', tags: ['all']),
    GameModel(id: 'story_relay', title: 'ストーリーリレー', origin: '日本', rules: '1人1文ずつ物語を繋いでいく。\n予想外の結末を目指す。', tags: ['waiting']),
    GameModel(id: 'mind_reading', title: 'マインドリーディング', origin: '欧米', rules: '「お互いに連想するもの」を同時に言い、\n一致するまで繰り返す。', tags: ['quiet']),
    GameModel(id: 'gesture_game', title: 'ジェスチャー', origin: '万国', rules: 'お題を身振り手振りだけで伝える。\n言葉は一切禁止。', tags: ['waiting', 'standing']),
  ];
}
