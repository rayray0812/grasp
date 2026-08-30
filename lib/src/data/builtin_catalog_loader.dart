import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models.dart';

class BuiltInCatalog {
  const BuiltInCatalog({required this.entries, required this.decks});

  final List<VocabularyEntry> entries;
  final List<Deck> decks;
}

class BuiltInCatalogLoader {
  const BuiltInCatalogLoader({this.bundle});

  static const assetPath = 'assets/exam/gsat_builtin_words_seed.json';
  final AssetBundle? bundle;

  Future<BuiltInCatalog> load() async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final words = (json['words'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => _entry(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    final now = DateTime.utc(2026, 1, 1);
    final decks = (json['decks'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((rawDeck) {
          final deck = Map<String, dynamic>.from(rawDeck);
          final id = deck['id']?.toString() ?? '';
          return Deck(
            id: 'builtin-$id',
            title: deck['title']?.toString() ?? '學測單字',
            description: deck['description']?.toString() ?? '大考中心詞彙表',
            vocabularyIds: (deck['wordIds'] as List<dynamic>? ?? const [])
                .map((value) => value.toString())
                .toList(growable: false),
            source: DeckSource.builtIn,
            createdAt: now,
            isActive: id == 'gsat-level-1',
          );
        })
        .toList(growable: false);
    return BuiltInCatalog(entries: words, decks: decks);
  }

  VocabularyEntry _entry(Map<String, dynamic> json) {
    final word = json['word']?.toString().trim() ?? '';
    final lemma = json['lemma']?.toString().trim() ?? word.toLowerCase();
    final definition = json['definitionZh']?.toString().trim() ?? '';
    final partOfSpeech = json['partOfSpeech']?.toString().trim() ?? '';
    final example = json['exampleSentence']?.toString().trim() ?? '';
    final base = VocabularyEntry(
      id: json['id']?.toString() ?? 'gsat-${_stableHash('$word|$definition')}',
      word: word,
      lemma: lemma,
      senses: [
        VocabularySense(
          definitionZh: definition,
          definitionEn: json['definitionEn']?.toString().trim() ?? '',
          partOfSpeech: partOfSpeech,
          isExamPriority: true,
          examples: [
            if (example.isNotEmpty) VocabularyExample(sentence: example),
          ],
        ),
      ],
      level: (json['level'] as num?)?.toInt(),
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(growable: false),
      source: '大考中心詞彙表',
    );
    return _examEnrichment[lemma]?.call(base) ?? base;
  }
}

typedef _Enricher = VocabularyEntry Function(VocabularyEntry base);

final Map<String, _Enricher> _examEnrichment = {
  'substantial': (base) => _replace(
    base,
    senses: const [
      VocabularySense(
        definitionZh: '大量的；可觀的',
        partOfSpeech: 'adj.',
        isExamPriority: true,
        examples: [
          VocabularyExample(
            sentence: 'The project requires a substantial amount of money.',
            translationZh: '這項計畫需要一筆可觀的資金。',
          ),
        ],
      ),
      VocabularySense(
        definitionZh: '重要的；實質的',
        partOfSpeech: 'adj.',
        examples: [
          VocabularyExample(
            sentence: 'There is substantial evidence to support the claim.',
            translationZh: '有實質證據支持這項主張。',
          ),
        ],
      ),
    ],
    synonyms: const [
      LexicalRelation(word: 'considerable', noteZh: '強調數量或程度可觀'),
      LexicalRelation(word: 'significant', noteZh: '也可強調重要性'),
    ],
    collocations: const [
      'a substantial amount of',
      'substantial evidence',
      'substantial change',
    ],
  ),
  'affect': (base) => _replace(
    base,
    synonyms: const [
      LexicalRelation(word: 'influence', noteZh: '影響的過程較中性'),
      LexicalRelation(word: 'impact', noteZh: '常暗示較強烈的影響'),
    ],
    confusingWords: const [
      LexicalRelation(word: 'effect', noteZh: '通常作名詞，表示結果或影響'),
    ],
    collocations: const ['directly affect', 'adversely affect'],
    wordFamily: const [
      WordFamilyMember(word: 'effect', partOfSpeech: 'n.', meaningZh: '影響；結果'),
      WordFamilyMember(
        word: 'effective',
        partOfSpeech: 'adj.',
        meaningZh: '有效的',
      ),
    ],
  ),
  'respond': (base) => _replace(
    base,
    collocations: const ['respond to', 'respond quickly'],
    wordFamily: const [
      WordFamilyMember(word: 'response', partOfSpeech: 'n.', meaningZh: '回應'),
      WordFamilyMember(
        word: 'responsive',
        partOfSpeech: 'adj.',
        meaningZh: '反應靈敏的',
      ),
    ],
  ),
  'economic': (base) => _replace(
    base,
    confusingWords: const [
      LexicalRelation(word: 'economical', noteZh: '節省的；經濟實惠的'),
    ],
    collocations: const ['economic growth', 'economic development'],
  ),
  'historic': (base) => _replace(
    base,
    confusingWords: const [
      LexicalRelation(word: 'historical', noteZh: '與歷史有關的；historic 指具歷史重要性'),
    ],
  ),
  'expose': (base) =>
      _replace(base, collocations: const ['be exposed to', 'expose a problem']),
  'advantage': (base) => _replace(
    base,
    collocations: const ['take advantage of', 'have an advantage over'],
  ),
};

VocabularyEntry _replace(
  VocabularyEntry base, {
  List<VocabularySense>? senses,
  List<LexicalRelation>? synonyms,
  List<LexicalRelation>? confusingWords,
  List<String>? collocations,
  List<WordFamilyMember>? wordFamily,
}) => VocabularyEntry(
  id: base.id,
  word: base.word,
  lemma: base.lemma,
  senses: senses ?? base.senses,
  synonyms: synonyms ?? base.synonyms,
  confusingWords: confusingWords ?? base.confusingWords,
  collocations: collocations ?? base.collocations,
  wordFamily: wordFamily ?? base.wordFamily,
  notes: base.notes,
  level: base.level,
  tags: base.tags,
  source: base.source,
);

int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
