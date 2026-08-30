import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const applicationContentPath =
      'assets/exam/gsat_application_content.json';
  final AssetBundle? bundle;

  /// Parses ~2.6MB of seed JSON into 6k+ entries. That is far too much work
  /// for the first frame, so it runs on a background isolate; only the finished
  /// plain-data objects come back.
  Future<BuiltInCatalog> load() async {
    final assetBundle = bundle ?? rootBundle;
    final values = await Future.wait([
      assetBundle.loadString(assetPath),
      assetBundle.loadString(applicationContentPath),
    ]);
    return compute(_parseCatalog, (
      vocabulary: values[0],
      application: values[1],
    ), debugLabel: 'grasp:parseBuiltInCatalog');
  }

  @visibleForTesting
  BuiltInCatalog parse({
    required String vocabularyJson,
    required String applicationJson,
  }) =>
      _parseCatalog((vocabulary: vocabularyJson, application: applicationJson));
}

BuiltInCatalog _parseCatalog(({String vocabulary, String application}) source) {
  final json = jsonDecode(source.vocabulary) as Map<String, dynamic>;
  final applicationJson =
      jsonDecode(source.application) as Map<String, dynamic>;
  if (applicationJson['schemaVersion'] != 1) {
    throw const FormatException('Unsupported application content schema.');
  }
  final overlays = <String, Map<String, dynamic>>{};
  for (final rawOverlay in _mapList(applicationJson['entries'])) {
    final lemma = _text(rawOverlay['lemma']).toLowerCase();
    if (lemma.isEmpty || overlays.containsKey(lemma)) {
      throw FormatException('Invalid or duplicate application lemma: $lemma');
    }
    overlays[lemma] = rawOverlay;
  }
  final words = (json['words'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((item) {
        final raw = Map<String, dynamic>.from(item);
        return _entry(raw, overlays[_catalogLemma(raw)]);
      })
      .toList(growable: false);
  final catalogLemmas = words.map((entry) => entry.lemma).toSet();
  final unknown = overlays.keys.where(
    (lemma) => !catalogLemmas.contains(lemma),
  );
  if (unknown.isNotEmpty) {
    throw FormatException(
      'Application content references unknown words: ${unknown.join(', ')}',
    );
  }
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

VocabularyEntry _entry(
  Map<String, dynamic> json,
  Map<String, dynamic>? overlay,
) {
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
  return overlay == null ? base : _applyOverlay(base, overlay);
}

String _catalogLemma(Map<String, dynamic> json) {
  final lemma = _text(json['lemma']);
  return (lemma.isEmpty ? _text(json['word']) : lemma).toLowerCase();
}

VocabularyEntry _applyOverlay(
  VocabularyEntry base,
  Map<String, dynamic> overlay,
) {
  final primary = base.primarySense;
  final overlaySenses = _mapList(overlay['senses']);
  final extraExamples = _mapList(
    overlay['examples'],
  ).map(VocabularyExample.fromJson).toList(growable: false);
  final senses = overlaySenses.isNotEmpty
      ? overlaySenses.map(VocabularySense.fromJson).toList(growable: false)
      : [
          VocabularySense(
            definitionZh: primary.definitionZh,
            definitionEn: primary.definitionEn,
            partOfSpeech: primary.partOfSpeech,
            isExamPriority: primary.isExamPriority,
            examples: _uniqueExamples([...primary.examples, ...extraExamples]),
          ),
          ...base.senses.skip(1),
        ];
  final collocations = _stringList(overlay['collocations']);
  final entry = VocabularyEntry(
    id: base.id,
    word: base.word,
    lemma: base.lemma,
    senses: senses,
    synonyms: _relations(overlay['synonyms'], base.synonyms),
    confusingWords: _relations(overlay['confusingWords'], base.confusingWords),
    collocations: collocations.isEmpty ? base.collocations : collocations,
    wordFamily: _wordFamily(overlay['wordFamily'], base.wordFamily),
    notes: _text(overlay['notes']).isEmpty
        ? base.notes
        : _text(overlay['notes']),
    level: base.level,
    tags: base.tags,
    source: base.source,
  );
  _validateApplicationContent(entry);
  return entry;
}

List<VocabularyExample> _uniqueExamples(List<VocabularyExample> examples) {
  final seen = <String>{};
  return examples
      .where((example) => seen.add(example.sentence.toLowerCase()))
      .toList(growable: false);
}

List<LexicalRelation> _relations(Object? raw, List<LexicalRelation> fallback) {
  final values = _mapList(raw);
  return values.isEmpty
      ? fallback
      : values.map(LexicalRelation.fromJson).toList(growable: false);
}

List<WordFamilyMember> _wordFamily(
  Object? raw,
  List<WordFamilyMember> fallback,
) {
  final values = _mapList(raw);
  return values.isEmpty
      ? fallback
      : values.map(WordFamilyMember.fromJson).toList(growable: false);
}

void _validateApplicationContent(VocabularyEntry entry) {
  final examples = entry.senses.expand((sense) => sense.examples);
  for (final example in examples) {
    if (example.sentence.trim().split(RegExp(r'\s+')).length < 4) {
      throw FormatException('Example is too short for ${entry.lemma}.');
    }
    final target = example.targetText.trim();
    final containsTarget = target.isEmpty
        ? _containsWordForm(example.sentence, entry.lemma)
        : RegExp(
            '(^|[^a-z])${RegExp.escape(target)}([^a-z]|\$)',
            caseSensitive: false,
          ).hasMatch(example.sentence);
    if (!containsTarget) {
      throw FormatException('Example does not use ${entry.lemma}.');
    }
  }
  for (final collocation in entry.collocations) {
    if (!_containsWordForm(collocation, entry.lemma)) {
      throw FormatException('Collocation does not use ${entry.lemma}.');
    }
  }
}

bool _containsWordForm(String text, String lemma) {
  final lower = text.toLowerCase();
  final forms = <String>{
    lemma,
    '${lemma}s',
    '${lemma}es',
    '${lemma}ed',
    '${lemma}ing',
    if (lemma.endsWith('e')) '${lemma.substring(0, lemma.length - 1)}ed',
    if (lemma.endsWith('e')) '${lemma.substring(0, lemma.length - 1)}ing',
    if (lemma.endsWith('y')) '${lemma.substring(0, lemma.length - 1)}ies',
    if (lemma.endsWith('y')) '${lemma.substring(0, lemma.length - 1)}ied',
  };
  return forms.any(
    (form) =>
        RegExp('(^|[^a-z])${RegExp.escape(form)}([^a-z]|\$)').hasMatch(lower),
  );
}

List<Map<String, dynamic>> _mapList(Object? raw) => raw is List
    ? raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];

List<String> _stringList(Object? raw) => raw is List
    ? raw.map(_text).where((value) => value.isNotEmpty).toList(growable: false)
    : const [];

String _text(Object? value) => value?.toString().trim() ?? '';

int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
