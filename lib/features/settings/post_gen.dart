import 'dart:math';

import '../../models/author.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../models/tag.dart';

/// Качественный псевдо-свалочный генератор постов.
///
/// Главная идея: не склеивать "кто + что сделал + объект", а сначала выбрать
/// сцену, затем собрать маленький сюжет с причинно-следственной связью.
/// Поэтому посты отличаются длиной, интонацией, структурой и логикой.
///
/// Использование:
///   final post = generatePreviewPost();
///   final comments = generateCommentsForPost(post, 12);
final _rnd = Random();

T _pick<T>(List<T> list) => list[_rnd.nextInt(list.length)];

T _pickOther<T>(List<T> list, T except) {
  final variants = list.where((item) => item != except).toList();
  return _pick(variants.isEmpty ? list : variants);
}

T _weighted<T>(List<Weighted<T>> items) {
  final total = items.fold<int>(0, (sum, item) => sum + item.weight);
  var roll = _rnd.nextInt(total);
  for (final item in items) {
    roll -= item.weight;
    if (roll < 0) return item.value;
  }
  return items.last.value;
}

List<T> _takeSome<T>(List<T> source, {int min = 1, int max = 3}) {
  final copy = List<T>.of(source)..shuffle(_rnd);
  final count = min + _rnd.nextInt(max - min + 1);
  return copy.take(count.clamp(0, copy.length)).toList();
}

bool _chance(double p) => _rnd.nextDouble() < p;

String _sentence(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  if ('.!?…'.contains(trimmed[trimmed.length - 1])) return trimmed;
  return '$trimmed.';
}

String _joinSentences(Iterable<String> parts) =>
    parts.where((p) => p.trim().isNotEmpty).map(_sentence).join(' ');

String _paragraphs(Iterable<String> parts) =>
    parts.where((p) => p.trim().isNotEmpty).join('\n\n');

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _postNumber() => (12000 + _rnd.nextInt(998000)).toString();

String _percent() {
  final head = 17 + _rnd.nextInt(82);
  final tail = _rnd.nextInt(100000).toString().padLeft(5, '0');
  return '$head,$tail%';
}

class Weighted<T> {
  const Weighted(this.value, this.weight);
  final T value;
  final int weight;
}

class GeneratedPostDraft {
  const GeneratedPostDraft({
    required this.text,
    required this.tags,
    required this.mood,
    required this.entities,
    required this.commentHooks,
  });

  final String text;
  final List<String> tags;
  final String mood;
  final List<String> entities;
  final List<String> commentHooks;
}

class GeneratedSettingsPreview {
  const GeneratedSettingsPreview({required this.post, required this.comments});

  final Post post;
  final List<Comment> comments;
}

// ---------------------------------------------------------------------------
// Лексикон
// ---------------------------------------------------------------------------

const _authors = [
  'дыкъ',
  'Унваитер',
  'Физкелла',
  'бздно',
  'Рвун Чехлов',
  'чпок',
  'кек',
  'ннн',
  'Митхун',
  'Философ66',
  'petruha',
  'МНС',
  'Клюкед',
  'АлкоЛис',
  'Медведъ',
  'Свирепь',
  'е2-е2',
  'Ящетаю',
  'Свидетель',
  'Наум Приходящий',
  'ХнЗ кто',
  'Тарас Кулакевич',
  'Зупазоид',
  'Зупимадзе',
  'Жирокожа',
  'Бурехобой',
  'Ябаблот',
  'Щычъ',
  'Ева Куатор',
  'Мебиус',
  'Пака-сан',
  'Дублизад',
  'на блюдатель',
  'Огурбуэ',
  'Фу Боян',
  'сбюфемхел',
  'Formulaehr X',
  'Пурист',
  'Обрезани',
  'Д-р. кот',
  'дъд',
  'погромист',
];

const _characters = [
  'ипшайтег',
  'Свинодемон',
  'карлег в табках',
  'Оля',
  'Иван Семёныч',
  'Альберт А. Мейер',
  'предсказательница Мария',
  'Тарас Кулакевич',
  'невидимый Гитлер',
  'кошка туркале',
  'синеокая Лазуля',
  'увгн из премода',
  'сосед с дрелью',
  'дежурный бухгалтер',
  'оператор',
  'младший научный сотрудник',
  'офисный программиот',
  'отставной моряк',
  'психиатр на полставки',
  'завсегдатай тёмной стороны',
  'свалконавт без регистрации',
  'человек с авоськой',
  'Ольга Викторовна',
  'карстон-свалкер',
  'модератор, которого удалили',
];

const _things = [
  'невидимая тележка',
  'стриказа',
  'птааг «скотобаза»',
  'птааг «я дебилен»',
  'синий скин',
  'камень',
  'запретное слово',
  'псто десятилетней выдержки',
  'квитанция из ЖЭКа',
  'совесть в хорошем состоянии',
  'остатки здравого смысла',
  'баян с родословной',
  'гудок неизвестной конструкции',
  'непоказанная золевалка',
  'качественно отрисованный уд',
  'пакет зерна или цемента',
  'таблица признаков дъда',
  'ссылка на корованы',
  'саквояж с пропан-бутаном',
  'позитронный пряник',
  'счётчик затаившихся людей',
  'кнопка RELAX',
  'самоопрув в состоянии аффекта',
  'график, который понял только Свинодемон',
  'розовая жопа ноосферы',
  'рубашка Куртки Бейна',
  'квитанция на четыре зелёных органа',
];

const _places = [
  'у катализатора',
  'на глагне',
  'в премоде',
  'на тёмной стороне',
  'в каментах',
  'в маршрутке',
  'в ЖЭКе',
  'на кухне у Оли',
  'на замёрзшем аэродроме',
  'в зоне трезвости',
  'под столом у модератора',
  'возле непоказанной золевалки',
  'на странице 2441',
  'в старом псто',
  'в RSS-Last',
  'на кнопке «Что попало»',
  'между баянометром и скотобазой',
  'в скайпочате, который всё ещё где-то жив',
  'на станции Дно',
  'в комментарии, удалённом комментарием',
];

const _smallFacts = [
  'горизонт завален на два пальца',
  'в отражении видна вторая тележка',
  'на табличке осталось только «здесь запрещено»',
  'номерные знаки складываются в подозрительное слово',
  'оператор стоит слишком близко',
  'все улыбаются, но это не точно',
  'кто-то уже поставил птааг, хотя псто ещё не опрувили',
  'слева виден негр, но только если знать, куда смотреть',
  'на заднем плане происходит чудовищный сука хаос',
  'картинка сделана синим карандашом и потому непререкаема',
  'видно, что люди, но всё равно сомнительно',
  'кнопка гудка есть, но жать в неё морально нельзя',
  'автозамена решила вопрос раньше экспертов',
  'пять квадратов на пять внезапно сошлись',
  'комментарии уже ушли на соседний пост и оттуда машут',
  'счётчик показывает людей, но пахнет ноосферой',
  'плитку, кажется, ложил тоджик',
  'на третьем куплете всё мимо',
  'в правом верхнем углу просматривается старый аппрув',
];

const _verdicts = [
  'Прикол, разумеется, оказался не там.',
  'Свинодемон промолчал, что само по себе подозрительно.',
  'Тарас Кулакевич ответил первым и снова был прав.',
  'Клюкед не опрувил, но это только усилило доказательную базу.',
  'Спасибо Татьяне за синий скин, без него экспертиза была бы невозможна.',
  'Свалка уже не та, но каменты всё ещё держатся за сук.',
  'Оператору, по предварительным данным, песда.',
  'Если вчитаться, это не боян, а археологический слой.',
  'Ответ — камень, но вопрос пока уточняется.',
  'Нобелевкой пахнет только при выключенном фонтане.',
  'Всё это могло не случиться, но тогда было бы совсем скучно.',
  'Четыре китайца сделали бы быстрее, зато без тележки.',
  'Методика спорная, но завсигдатаи уже упали пацтул.',
  'Свинодемон унёс протокол на тёмную сторону и там его полюбил.',
  'Если получится — вы просто молодчина.',
];

const _openers = [
  'Увгны, у меня тут маленькое наблюдение.',
  'Сначала хотел пройти мимо, но потом увидел детали.',
  'Не знаю, кто это опрувил, но теперь нам с этим жить.',
  'Докладываю по результатам свалконаучного осмотра.',
  'Псто вроде простое, но чем дольше смотришь, тем хуже.',
  'Всё началось с того, что я полез искать гудок.',
  'Свинодемон, конечно, опять сделал вид, что он просто машина.',
  'Пишу сюда, потому что нормальные люди такое слушать отказались.',
  'Сделяль увидеть золевалку, но увидел будущее.',
  'Устроил сегодня маленькую свалкоэкспедицию.',
  'Сразу говорю: не фотошоп, просто пикча не смогла.',
  'По многочисленным просьбам полутора свалкоюзеров.',
  'Пока все искали смысл, я нашёл хуже.',
  'Из премода доносится слабое «кто туд?».',
];

const _tagPool = [
  'картинки',
  'штуки',
  'сервис',
  'засропсто',
  'животни чочо',
  'ниибу',
  'кто туд?',
  'я дебилен',
  'ЕБЛОВВЕЩАХ',
  'упячка мозга',
  'чочо',
  'ватаку!',
  'норкотеки',
  'тупня',
  'нейропсто',
  'сакирмахрепяка',
  'мегадизайн',
  'знаки',
  'нанотехнологии',
  'опасносте!',
  'основы',
  'познавательно',
  'флэшмоб',
  'робаты',
  'Сделай сам',
  'ЖЗЛ',
  'суперЪгерои',
  'монобровь',
  'йазь',
  'нас читают дети!',
  'синий скин',
  'скотобаза',
  'свалко',
  'ТАГИ-ПТААГИ',
  'чудовищный сука хаос',
];

const _buttons = [
  'зачот',
  '?я чото п',
  'КГ/АМ',
  'борода!',
  'МЕГАборода!',
  'я знаю :(',
  'гетшеет',
];

const _swinodemonLines = [
  'КТО ТУД?!!!',
  '-? Я ЧОТО П',
  'Оператору песда.',
  'Камень.',
  'Блять! Не получилось.',
  'Математики поймут.',
  'Не смог различить пикчу.',
  'Чудовищный сука хаос!',
  'Вижу тележку!',
  'Прикол в цифрах?',
  'Нишатол...',
  'Прямо сейчас стоит у катализатора.',
  'Судоходна ли река?',
  'КТО ТУД?!!!',
];

const _spamPeople = [
  'Ольга',
  'Олбга',
  'менеджер по взаимовыгоде',
  'чел на связзи',
  'известный телеведущий',
  'штабс-капитан',
  'Оксана из тёмного парка',
];

const _rhymeJunk = [
  'орган',
  'экран',
  'баян',
  'пропан-бутан',
  'вагон-ресторан',
  'Вассерман',
  'шарлатан',
  'полукафтан',
  'турбофортран',
  'наркоманчик',
  'маленький каштанчик',
];

List<String> _tagMix(List<String> seeds, {int min = 1, int max = 4}) {
  final result = <String>{};
  for (final seed in seeds) {
    if (seed.trim().isNotEmpty && (_chance(0.86) || result.isEmpty)) {
      result.add(seed);
    }
  }

  final target = min + _rnd.nextInt(max - min + 1);
  final pool = List<String>.of(_tagPool)..shuffle(_rnd);
  for (final tag in pool) {
    if (result.length >= target) break;
    result.add(tag);
  }

  final tags = result.toList()..shuffle(_rnd);
  return tags.take(max).toList();
}

List<Tag> _tagsFromStrings(List<String> names) => names
    .asMap()
    .entries
    .map((e) => Tag(id: e.key + 1, name: e.value))
    .toList();

// ---------------------------------------------------------------------------
// Генераторы сцен
// ---------------------------------------------------------------------------

GeneratedPostDraft _sceneInvestigation() {
  final hero = _pick(_characters);
  final thing = _pick(_things);
  final place = _pick(_places);
  final clues = _takeSome(_smallFacts, min: 2, max: 4);
  final ending = _pick(_verdicts);

  final text = _joinSentences([
    _pick(_openers),
    'На фотографии $place обнаружен $thing',
    'Сначала все решили, что это просто $hero, но экспертиза показала обратное',
    ...clues,
    ending,
  ]);

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['ниибу', 'ЕБЛОВВЕЩАХ', 'штуки'], min: 2, max: 4),
    mood: 'investigation',
    entities: [hero, thing, place],
    commentHooks: ['прикол', 'тележка', 'катализатор', 'камень'],
  );
}

GeneratedPostDraft _sceneMicroStory() {
  final a = _pick(_characters);
  final b = _pickOther(_characters, a);
  final thing = _pick(_things);
  final place = _pick(_places);

  final twist = _pick([
    'после чего оба сделали вид, что так и было задумано',
    'и только потом выяснилось, что это была инструкция к пылесосу',
    'но пришёл Иван Семёныч и перевёл разговор в диетологию',
    'а предсказательница Мария сказала «я знаю» и ушла',
    'и тут из-за угла выехала невидимая тележка, что многое объяснило',
    'после чего Свинодемон перенёс всё на тёмную сторону без права переписки',
    'а внизу мелким шрифтом было написано «спасибо Татьяне»',
  ]);

  final text = _joinSentences([
    'Короткая история из жизни.',
    '$a $place нашёл $thing',
    '$b попытался объяснить, почему это не боян',
    'Объяснение заняло сорок два камента, три птаага и одну субботу',
    twist,
    _pick(_verdicts),
  ]);

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['сказка', 'скотобаза', 'засропсто'], min: 2, max: 4),
    mood: 'story',
    entities: [a, b, thing, place],
    commentHooks: ['боян', 'суббота', 'Свинодемон'],
  );
}

GeneratedPostDraft _sceneComplaint() {
  final subject = _pick([
    'отсутствие опрувов после обеда',
    'птааг, поставленный не по феншую',
    'боян, который уже видел даже карлег',
    'поведение %username% в каментах',
    'автозамену, которая снова заменила не то',
    'модераторский произвол в отношении стриказ',
    'дрель соседа, звучащую как наркотическая GIF-анимация',
    'непоказанную золевалку в самый ответственный момент',
  ]);

  final demands = _takeSome(
    [
      'вернуть гудок туда, где его можно жать',
      'провести повторную экспертизу у катализатора',
      'выдать всем пострадавшим по синему карандашу',
      'обязать Свинодемона объяснять свои действия человеческим языком',
      'запретить запрещать слово, которое нельзя произносить',
      'признать камень официальным ответом до выяснения обстоятельств',
    ],
    min: 2,
    max: 3,
  );

  final text = [
    'Уважаемая уютненькая.',
    'Пишу уже не первый раз про $subject.',
    'Ситуация вышла из-под контроля: ${_pick(_smallFacts)}.',
    'Требую:',
    for (var i = 0; i < demands.length; i++) '${i + 1}) ${demands[i]};',
    _pick([
      'Клюкед, опрувь.',
      'Прошу разобраться.',
      'Свалка уже не та.',
      'Камень.',
    ]),
  ].join('\n');

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['свалко', 'ТАГИ-ПТААГИ', 'опасносте!'], min: 2, max: 4),
    mood: 'complaint',
    entities: [subject],
    commentHooks: ['жалоба', 'опрув', 'птааг'],
  );
}

GeneratedPostDraft _sceneManual() {
  final target = _pick([
    'найти невидимую тележку',
    'не стать первонахом',
    'понять, где прикол',
    'пережить добросвалку',
    'правильно поставить птааг',
    'выяснить, зерно это или цемент',
    'доказать, что не фотошоп',
    'дожить до субботы',
  ]);

  final steps = _takeSome(
    [
      'Открыть псто и не читать заголовок.',
      'Посмотреть в левый нижний угол.',
      'Ничего не найти и записать это как улику.',
      'Спросить у Тараса Кулакевича.',
      'Получить ответ «камень» и временно успокоиться.',
      'Проверить, не стоит ли всё это у катализатора.',
      'Поблагодарить Татьяну за синий скин.',
      'Написать в каменты, что прикол в буквах.',
      'Дождаться, пока придёт Иван Семёныч и всё испортит.',
    ],
    min: 5,
    max: 7,
  );

  final text = [
    'Памятка начинающему свалкеру: как $target.',
    for (var i = 0; i < steps.length; i++) '${i + 1}. ${steps[i]}',
    _pick([
      'Работает в 76,273% случаев.',
      'Метод не научный, зато сбруслый.',
      'За последствия отвечает оператор.',
      'Если не помогло — значит, тележка была невидимая.',
    ]),
  ].join('\n');

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['основы', 'свалко', 'опасносте!'], min: 2, max: 4),
    mood: 'manual',
    entities: [target],
    commentHooks: ['инструкция', 'камень', 'тележка'],
  );
}

GeneratedPostDraft _sceneClassified() {
  final action = _pick([
    'Продам',
    'Отдам',
    'Меняю',
    'Ищу',
    'Сниму на выходные',
    'Возьму под честное слово',
  ]);
  final item = _pick([
    'птааг «скотобаза», почти новый, один хозяин',
    'невидимую тележку, цвет не указан',
    'совесть, мешает опрувить',
    'здравый смысл, состояние после каментов',
    'камень, отвечает на большинство вопросов',
    'синий карандаш для качественной отрисовки',
    'боян с документами и родословной',
    'гудок, жать некуда, но звучит уверенно',
  ]);
  final conditions = _takeSome(
    [
      'самовывоз от катализатора',
      'в субботу не звонить',
      'обмен на зерно или цемент',
      'фото пришлю после аппрува',
      'торг уместен только в каментах',
      'Свинодемону не показывать',
      'первонахам скидки нет',
    ],
    min: 2,
    max: 4,
  );

  final text = _joinSentences([
    '$action: $item',
    conditions.join(', '),
    _pick([
      'Не фотошоп.',
      'Спасибо Татьяне.',
      'Камень в подарок.',
      'Оператору самовывоз.',
    ]),
  ]);

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['скотобаза', 'штуки', 'ниибу'], min: 2, max: 4),
    mood: 'classified',
    entities: [item],
    commentHooks: ['продам', 'катализатор', 'самовывоз'],
  );
}

GeneratedPostDraft _scenePseudoScience() {
  final phenomenon = _pick([
    'невидимой тележки',
    'камня как универсального ответа',
    'птааговой неопределённости',
    'заваленного горизонта',
    'кошки туркале',
    'постепенной скотобазификации каментов',
    'гудка без места приложения',
    'тёмной стороны премода',
  ]);

  final terms = _takeSome(
    [
      'полевые измерения у катализатора',
      'контрольная группа из трёх карлегов',
      'двойное слепое перечитывание каментов',
      'спектральный анализ синего скина',
      'проверка на баянность по методу Рвуна',
      'опрос предсказательницы Марии',
      'тест Тараса Кулакевича',
    ],
    min: 3,
    max: 5,
  );

  final conclusion = _pick([
    'гипотеза подтвердилась, но никто не понял какая',
    'результаты статистически значимы только в субботу',
    'модель объясняет всё, кроме самого псто',
    'прикол оказался в цифрах с вероятностью 3.14 лица ипшайтега',
    'дальнейшие исследования будут перенесены на тёмную сторону',
  ]);

  final text = [
    'Свалконаучный отчёт о природе $phenomenon.',
    'Методика: ${terms.join('; ')}.',
    'Промежуточное наблюдение: ${_pick(_smallFacts)}.',
    'Вывод: $conclusion.',
    _pick(_verdicts),
  ].join('\n');

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['ниибу', 'упячка мозга', 'основы'], min: 2, max: 4),
    mood: 'science',
    entities: [phenomenon],
    commentHooks: ['наука', 'цифры', 'ипшайтег'],
  );
}

GeneratedPostDraft _sceneCaptionOnly() {
  final subject = _pick([
    'дядька смотрит на дискету',
    'мельницы мелют зерно или цемент',
    'та самая кнопка, в которую неясно куда жать',
    'карта местности, где никто не знает, где находится Свалка',
    'Куртка Бейн в неправильной рубашке',
    'плитка, которую ложил тоджик',
    'человек, внезапно ставший дъдом',
    'шляпа, которая ему как раз',
  ]);

  final caption = _pick([
    'ну вот собственно',
    'А это на среду.',
    'не смог пройти мимо, потому что оно пищит',
    'если вы понимаете, то объясните остальным',
    'сделайте креатив, а мы потом всё испортим',
    'видно плохо, зато подозрительно',
    'все есть дъд, вопрос только в квадрате',
  ]);

  final text = _paragraphs([
    caption,
    _chance(0.64) ? subject : '',
    _chance(0.42) ? _pick(_swinodemonLines) : '',
  ]);

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['картинки', 'штуки', 'ниибу'], min: 2, max: 5),
    mood: 'caption',
    entities: [subject],
    commentHooks: ['картинка', 'гудок', 'дъд', 'среда'],
  );
}

GeneratedPostDraft _sceneLinkFound() {
  final domain = _pick([
    'korovany.example',
    'retroweb.fun',
    'facts.museum',
    'skotobaza.invalid',
    'sait-for-biznes.example',
    'dark-side.local',
  ]);
  final subject = _pick([
    'джвадцать лет такого написать обещале',
    'генератор фэнтези-карт для тех, кто пропустил золевалку',
    'архив кнопки RELAX до вебдванолизации',
    'сервис, который определяет, кто ты сегодня',
    'методичка по различению зерна и цемента',
    'схема, где у ноосферы гудок',
  ]);
  final url = 'https://$domain/${_postNumber()}.html';

  final text = _paragraphs([
    '$subject. ну иле нет.',
    url,
    _chance(0.38) ? '<i>${_pick(_authors)}: ${_pick(_verdicts)}</i>' : '',
  ]);

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['сервис', 'Сделай сам', 'ниибу'], min: 2, max: 5),
    mood: 'link',
    entities: [subject, url],
    commentHooks: ['ссылка', 'сервис', 'корованы'],
  );
}

GeneratedPostDraft _sceneSpamLetter() {
  final person = _pick(_spamPeople);
  final target = _pick([
    'Ваш сайт',
    'тёмная сторона',
    'кнопка «Что попало»',
    'синий скин',
    'уютненькая',
    'раздел ТАГИ-ПТААГИ',
  ]);
  final offer = _pick([
    'разместить новость про наш сайт',
    'поработать на взаимовыгодных условиях',
    'опубликовать материал про здоровое жывотновоцво',
    'провести интеграцию с ноосферой',
    'поставить у вас ссылку, которая сама себя опрувит',
    'поменять статью на пакет зерна или цемента',
  ]);

  final text = _joinSentences([
    'Добрый день, меня зовут $person',
    'Нас заинтересовал $target',
    'Мы хотели бы $offer',
    _pick([
      'Скажите, возможно ли это и какие ещё варианты у вас есть',
      'Оплата позитивными пряниками, документы после аппрува',
      'Если письмо попало не туда, значит туда',
      'Прошу ответить до субботы, потом я буду дъд',
    ]),
  ]);

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['ниибу', 'сервис', 'засропсто'], min: 1, max: 4),
    mood: 'spam',
    entities: [person, target, offer],
    commentHooks: ['Ольга', 'спам', 'взаимовыгода'],
  );
}

GeneratedPostDraft _scenePremodProtocol() {
  final item = _pick(_things);
  final accused = _pick(_characters);
  final actions = _takeSome(
    [
      'перечитать псто в темноте',
      'спросить у баянометра, зачем он вообще',
      'проверить, стоит ли объект у катализатора',
      'позвать Свинодемона и отойти на безопасное расстояние',
      'поставить птааг «я дебилен» до выяснения',
      'выключить запрещённое слово',
      'найти, где в это гудок жать',
    ],
    min: 3,
    max: 5,
  );

  final text = [
    'Протокол премода №${_postNumber()}.',
    'Объект: $item.',
    'Подозреваемый: $accused.',
    'Версия: ${_pick(_smallFacts)}.',
    'Порядок работ:',
    for (var i = 0; i < actions.length; i++) '${i + 1}. ${actions[i]}',
    'Решение: ${_pick(_buttons)}.',
  ].join('\n');

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['свалко', 'ТАГИ-ПТААГИ', 'опасносте!'], min: 2, max: 5),
    mood: 'premod',
    entities: [item, accused],
    commentHooks: ['премод', 'опрув', 'баянометр'],
  );
}

GeneratedPostDraft _sceneSwinodemonDigest() {
  final lines = _takeSome(_swinodemonLines, min: 4, max: 7);
  final object = _pick(_things);
  final text = [
    'Еженедельная свалкоаналитическая сводка.',
    'Плебеи поняли ${_percent()}, остальное унесено в тёмную сторону.',
    'Свинодемон обработал $object и сказал:',
    ...lines.map((line) => '* $line'),
    _pick([
      'График прилагается, но не различается.',
      'Если кому-то кажется, что Свалка уже не та, это статистически шум.',
      'Дальше будет хуже, зато с кнопкой RELAX.',
    ]),
  ].join('\n');

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(
      ['свалко', 'упячка мозга', 'чудовищный сука хаос'],
      min: 2,
      max: 5,
    ),
    mood: 'digest',
    entities: ['Свинодемон', object],
    commentHooks: ['Свинодемон', 'сводка', 'график'],
  );
}

GeneratedPostDraft _sceneArchiveArchaeology() {
  final oldPost = _postNumber();
  final artifact = _pick([
    'первый комментарий про тележку',
    'недоаппрувленный баян с родословной',
    'следы древнего самоопрува',
    'копипаста, которая сама стала источником',
    'коммент, где всё ещё ищут золевалку',
    'неудачная попытка объяснить, что такое туркале',
  ]);
  final facts = _takeSome(_smallFacts, min: 2, max: 3);

  final text = _paragraphs([
    'Раскопал псто $oldPost.',
    'Внутри обнаружены: $artifact, ${facts.join(', ')}.',
    _pick([
      'Слой датируется временем, когда комментарии ещё пахли синим карандашом.',
      'Сохранность средняя: кнопки работают, смысл местами отвалился.',
      'Археологи спорят, был ли это баян или просто ранний интернет.',
    ]),
  ]);

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['познавательно', 'свалко', 'основы'], min: 2, max: 5),
    mood: 'archive',
    entities: [artifact, 'псто $oldPost'],
    commentHooks: ['архив', 'боян', 'старое псто'],
  );
}

GeneratedPostDraft _sceneRhymeMutation() {
  final place = _pick(_places);
  final who = _pick(_characters);
  final cargo = _takeSome(_rhymeJunk, min: 4, max: 7);

  final text = [
    'Перед ${_pick(_spamPeople)} $place',
    '$who вдруг распахнул премод.',
    'Под ним:',
    ...cargo.map((word) => '- $word'),
    _pick([
      'а тележка могла подрасти.',
      'а гудок, как обычно, не туда.',
      'а $who сказал «я знаю» и закрыл вкладку.',
      'а Свинодемон всё это съел, но подавился тегами.',
    ]),
  ].join('\n');

  return GeneratedPostDraft(
    text: text,
    tags: _tagMix(['упячка мозга', 'флэшмоб', 'засропсто'], min: 2, max: 5),
    mood: 'rhyme',
    entities: [who, place],
    commentHooks: ['рифма', 'багаж', 'тележка'],
  );
}

GeneratedPostDraft _withAftertaste(GeneratedPostDraft draft) {
  if (!_chance(0.34)) return draft;

  final extra = _pick([
    'Свалко уже не та, но это тоже часть протокола.',
    'Кнопку «я знаю» нажимать после полного остывания.',
    'Если не загрузилось — значит, загрузилось на тёмной стороне.',
    'Пожалуйста, не орите, оно само.',
    'Обычно компании за это берут деньги.',
    'Наркотики? Жду.',
  ]);

  return GeneratedPostDraft(
    text: _paragraphs([draft.text, extra]),
    tags: draft.tags,
    mood: draft.mood,
    entities: draft.entities,
    commentHooks: draft.commentHooks,
  );
}

GeneratedPostDraft generatePostDraft() {
  final draft = _weighted<GeneratedPostDraft Function()>(const [
    Weighted(_sceneInvestigation, 23),
    Weighted(_sceneMicroStory, 22),
    Weighted(_sceneComplaint, 14),
    Weighted(_sceneManual, 14),
    Weighted(_sceneClassified, 11),
    Weighted(_scenePseudoScience, 16),
    Weighted(_sceneCaptionOnly, 18),
    Weighted(_sceneLinkFound, 12),
    Weighted(_sceneSpamLetter, 10),
    Weighted(_scenePremodProtocol, 13),
    Weighted(_sceneSwinodemonDigest, 10),
    Weighted(_sceneArchiveArchaeology, 12),
    Weighted(_sceneRhymeMutation, 8),
  ])();
  return _withAftertaste(draft);
}

String generatePost() => generatePostDraft().text;

// ---------------------------------------------------------------------------
// Комментарии
// ---------------------------------------------------------------------------

const _commentOpeners = [
  'прочитал, понел',
  'три раза перечитал',
  'это уже было',
  'всё не так просто',
  'я, конечно, не эксперт',
  'извините, нет возможности качественно отрисовать',
  'если вдумацо',
  'а ведь предупреждали',
  'ну вот опять',
  'па пуквам:',
  'щас полуркал',
  'если смотреть поверхностно',
  'согласно багажной квитанции',
  'как человек с воспитанием',
  'мне кажется, тут надо не спешить',
  'по линии свалконауки',
];

const _commentBodies = [
  'прикал в цифрах, но буквы тоже подозрительные',
  'тележка есть, просто она невидимая',
  'у катализатора сейчас ровно то же самое стоит',
  'Свинодемон давно всё знает, но делает вид',
  'Тарас Кулакевич бы ответил быстрее',
  'оператор зря подошёл так близко',
  'птааг поставлен правильно, но не туда',
  'это не боян, это культурный слой',
  'кошку туркале видно только после чирка-свистунка',
  'воспитание не позволяет Лене Анциферовой такое комментировать',
  'надо было сразу благодарить Татьяну',
  'я бы поменял на зерно, цемент уже есть',
  'если не видно, значит пикча работает штатно',
  'всё равно заметно, что люди',
  'пахнет нобелевкой, но только возле катализатора',
  'баянометр сказал «мне в бассейн»',
  'золевалка на самом видном месте, поэтому её нет',
  'Свинодемон уже расширил словарный запас и теперь опасен',
  'это такой жыр, если попытаться понять',
  'в третьем куплете опять мимо',
];

const _commentEndings = [
  'зачот',
  'кг/ам',
  'камень',
  'Клюкед, опрувь!',
  'спасибо Татьяне за синий скин',
  'Свалка уже не та',
  'если вы понимаете о чём я',
  '? я чото п',
  'не фотошоп',
  'оператору песда',
  'гуси-хуюси',
  'борода!',
  'МЕГАборода!',
  'я знаю :(',
  'гетшеет',
  'нишатол',
  'кто туд?',
  'чолузь',
];

const _commentShorties = [
  'первонах',
  'зобаньте Девура',
  'камень',
  'зачот',
  '?я чото п',
  'я знаю :(',
  'не ходи по рыбе',
  'КТО ТУД?!!!',
  '*оглушительный треск*',
  'Спасибо, полегчало.',
  'А Бялорусь?',
  'Я покакал',
];

const _deletedCommentTexts = [
  'Комментарий удален модератором.',
  'модератор удален комментарием.',
  'Комментатор модерирован удалением.',
  'удалятор комментирован модерением.',
  'Модетарий ударат лентором.',
];

String _rhymeComment() {
  final words = _takeSome(_rhymeJunk, min: 3, max: 5);
  return [
    'Перед ${_pick(_spamPeople)} в тёмном премоде',
    '${_pick(_characters)} вдруг нашёл ${_pick(_things)}.',
    'Под ним ${words.join(', ')}.',
    _pick([
      'Собственно, всё могло подрасти.',
      'В третьем куплете мимо.',
      'Несите уже его.',
    ]),
  ].join('\n');
}

String _generateCommentText(GeneratedPostDraft draft, int index) {
  if (index == 0 && _chance(0.45)) {
    return _pick(_commentShorties);
  }

  if (_chance(0.16)) {
    return _pick(_commentEndings);
  }

  if (_chance(0.07)) {
    return _pick(_deletedCommentTexts);
  }

  final hook = draft.commentHooks.isEmpty
      ? _pick(['камень', 'тележка'])
      : _pick(draft.commentHooks);
  final entity = draft.entities.isEmpty ? hook : _pick(draft.entities);

  final pattern = _rnd.nextInt(11);
  switch (pattern) {
    case 0:
      return '${_pick(_commentOpeners)}. ${_cap(_pick(_commentBodies))}. ${_pick(_commentEndings)}.';
    case 1:
      return 'про $hook уже писали в ${2004 + _rnd.nextInt(18)}, но тогда никто не понял. теперь тоже никто не понял.';
    case 2:
      return '$entity — это, конечно, сильно. но где гудок жать?';
    case 3:
      return '${_pick(_commentBodies)}. а если не видно — блюра долбануть.';
    case 4:
      return '> $hook\n${_pick(['а может лучше Настя?', 'не $hook, а ${_pick(_things)}', 'это же ${_percent()} лица ипшайтега', 'прямо сейчас стоит у катализатора'])}';
    case 5:
      return _rhymeComment();
    case 6:
      return '${_pick(_swinodemonLines)}\n\n${_pick(_commentEndings)}.';
    case 7:
      return 'я ${_pick(_authors)}. перечитал, понял что $hook. перечитал ещё раз, понял что не понял.';
    case 8:
      return 'Сделайте креатив. Потом мы его постмодернистски спиздим и иронично обделаем.';
    case 9:
      return '${_pick(_commentOpeners)}: ${_pick(_commentBodies)}. ${_pick(['ну или нет', 'чяднт?', 'если вы понимаете о чём я'])}.';
    default:
      return '${_pick(_commentOpeners)}: ${_pick(_commentBodies)}, ${_pick(_commentEndings)}.';
  }
}

List<Comment> generateCommentsForPost(
  Post post,
  int count, {
  GeneratedPostDraft? draft,
}) {
  final d =
      draft ??
      GeneratedPostDraft(
        text: (post.textHtml ?? '').replaceAll('<br>', '\n'),
        tags: post.tags.map((t) => t.name).toList(),
        mood: 'unknown',
        entities: const [],
        commentHooks: const [],
      );

  final authors = List<String>.of(_authors)..shuffle(_rnd);
  final base = post.publishedAt;

  return List.generate(count, (i) {
    final minutes = 3 + i * (4 + _rnd.nextInt(13));
    return Comment(
      id: i + 1,
      postId: post.id,
      author: Author(name: authors[i % authors.length], profileUrl: ''),
      publishedAt: base.add(Duration(minutes: minutes)),
      text: _generateCommentText(d, i),
      imageUrls: const [],
      videoUrls: const [],
    );
  });
}

/// Обратная совместимость со старым API.
List<Comment> generateComments(int count) {
  final draft = generatePostDraft();
  final fakePost = Post(
    id: 0,
    author: Author(name: generateAuthor(), profileUrl: ''),
    publishedAt: DateTime(2026, 6, 1, 14, 37),
    textHtml: draft.text.replaceAll('\n', '<br>'),
    imageUrls: const [],
    videoUrls: const [],
    externalLinks: const [],
    tags: _tagsFromStrings(draft.tags),
    commentCount: count,
    rating: const PostRating(plus: 0, neutral: 0, minus: 0, percentage: 0),
    approvedBy: null,
  );

  return generateCommentsForPost(fakePost, count, draft: draft);
}

String generateAuthor() => _pick(_authors);

// ---------------------------------------------------------------------------
// Full Post
// ---------------------------------------------------------------------------

Post _buildPreviewPost(GeneratedPostDraft draft, {int? commentCount}) {
  final authorName = generateAuthor();

  final plus = 1 + _rnd.nextInt(_chance(0.82) ? 45 : 120);
  final neutral = _rnd.nextInt(9);
  final minus = _rnd.nextInt(_chance(0.84) ? 12 : 55);
  final total = plus + neutral + minus;
  final pct = total == 0 ? 0 : ((plus - minus) * 100 / total).round();
  final borodaCount = _chance(0.62) ? _rnd.nextInt(7) : null;

  final approvedByPool = List<String>.of(_authors)
    ..remove(authorName)
    ..shuffle(_rnd);

  final approvedBy = _chance(0.78) ? approvedByPool.first : null;
  final safeCommentCount = commentCount ?? (1 + _rnd.nextInt(6));

  return Post(
    id: 900000 + _rnd.nextInt(99999),
    author: Author(name: authorName, profileUrl: ''),
    publishedAt: DateTime.now().subtract(
      Duration(minutes: 7 + _rnd.nextInt(60 * 24 * 18)),
    ),
    textHtml: draft.text.replaceAll('\n', '<br>'),
    imageUrls: const [],
    videoUrls: const [],
    externalLinks: const [],
    tags: _tagsFromStrings(draft.tags),
    commentCount: safeCommentCount,
    rating: PostRating(
      plus: plus,
      neutral: neutral,
      minus: minus,
      percentage: pct,
    ),
    borodaCount: borodaCount,
    approvedBy: approvedBy,
  );
}

Post generatePreviewPost() => _buildPreviewPost(generatePostDraft());

GeneratedSettingsPreview generateSettingsPreview({int commentCount = 2}) {
  final safeCount = commentCount.clamp(0, 3).toInt();
  final draft = generatePostDraft();
  final post = _buildPreviewPost(draft, commentCount: safeCount);

  return GeneratedSettingsPreview(
    post: post,
    comments: generateCommentsForPost(post, safeCount, draft: draft),
  );
}
