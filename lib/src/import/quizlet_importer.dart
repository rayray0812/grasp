import 'dart:convert';

import '../domain/models.dart';

class QuizletImportResult {
  const QuizletImportResult({required this.deck, required this.entries});

  final Deck deck;
  final List<VocabularyEntry> entries;
}

/// Parses Quizlet's copy/export format (`term<TAB>definition`), CSV-like rows,
/// and the legacy Grasp/Quizlet importer JSON format without network access.
class QuizletImporter {
  const QuizletImporter();

  QuizletImportResult parse({
    required String raw,
    required String title,
    String sourceUrl = '',
    DateTime? now,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const FormatException('請輸入單字集名稱。');
    }
    final rows = _parseRows(raw.trim());
    if (rows.isEmpty) {
      throw const FormatException('找不到可匯入的單字。請貼上 Quizlet 匯出內容。');
    }

    final grouped = <String, List<_ImportRow>>{};
    for (final row in rows) {
      final key = row.term.toLowerCase();
      final senses = grouped.putIfAbsent(key, () => []);
      if (!senses.any(
        (existing) =>
            existing.definition.toLowerCase() == row.definition.toLowerCase(),
      )) {
        senses.add(row);
      }
    }

    final timestamp = (now ?? DateTime.now().toUtc()).toUtc();
    final deckId =
        'quizlet-${_slug(cleanTitle)}-${timestamp.millisecondsSinceEpoch}';
    final entries = grouped.entries
        .map((group) {
          final first = group.value.first;
          return VocabularyEntry(
            id: '$deckId-${_stableHash(group.key)}',
            word: first.term,
            lemma: group.key,
            senses: group.value
                .map(
                  (row) => VocabularySense(
                    definitionZh: row.definition,
                    partOfSpeech: row.partOfSpeech,
                    examples: [
                      if (row.example.isNotEmpty)
                        VocabularyExample(sentence: row.example),
                    ],
                  ),
                )
                .toList(growable: false),
            notes: first.notes,
            source: 'Quizlet import',
          );
        })
        .toList(growable: false);

    return QuizletImportResult(
      deck: Deck(
        id: deckId,
        title: cleanTitle,
        description: sourceUrl.trim().isEmpty
            ? 'Quizlet 匯入 · ${entries.length} 個單字'
            : 'Quizlet 匯入 · ${entries.length} 個單字\n${sourceUrl.trim()}',
        vocabularyIds: entries.map((entry) => entry.id).toList(growable: false),
        source: DeckSource.quizlet,
        createdAt: timestamp,
        isActive: true,
      ),
      entries: entries,
    );
  }

  List<_ImportRow> _parseRows(String raw) {
    if (raw.isEmpty) return const [];
    if (raw.startsWith('{') || raw.startsWith('[')) {
      try {
        return _parseJson(jsonDecode(raw));
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException('JSON 格式不正確。');
      }
    }
    final rows = <_ImportRow>[];
    for (final line in const LineSplitter().convert(raw)) {
      final clean = line.trim();
      if (clean.isEmpty) continue;
      final pair = _splitLine(clean);
      if (pair != null) rows.add(pair);
    }
    return rows;
  }

  List<_ImportRow> _parseJson(Object? decoded) {
    Iterable<dynamic> candidates;
    if (decoded is List) {
      candidates = decoded;
    } else if (decoded is Map) {
      candidates =
          (decoded['cards'] ?? decoded['terms'] ?? decoded['words'])
              as List<dynamic>? ??
          const [];
    } else {
      candidates = const [];
    }
    return candidates
        .whereType<Map>()
        .map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final term = _first(item, const ['term', 'word', 'front', 'prompt']);
          final definition = _first(item, const [
            'definition',
            'translation',
            'meaning',
            'back',
            'answer',
          ]);
          return _ImportRow(
            term: term,
            definition: definition,
            partOfSpeech: _first(item, const ['partOfSpeech', 'pos']),
            example: _first(item, const ['example', 'exampleSentence']),
            notes: _first(item, const ['notes', 'note']),
          );
        })
        .where((row) => row.isValid)
        .toList(growable: false);
  }

  _ImportRow? _splitLine(String line) {
    for (final separator in const ['\t', ' :: ', ' - ', ',']) {
      final index = line.indexOf(separator);
      if (index <= 0 || index >= line.length - separator.length) continue;
      final row = _ImportRow(
        term: line.substring(0, index).trim(),
        definition: line.substring(index + separator.length).trim(),
      );
      return row.isValid ? row : null;
    }
    return null;
  }

  String _first(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

class _ImportRow {
  const _ImportRow({
    required this.term,
    required this.definition,
    this.partOfSpeech = '',
    this.example = '',
    this.notes = '',
  });

  final String term;
  final String definition;
  final String partOfSpeech;
  final String example;
  final String notes;

  bool get isValid => term.isNotEmpty && definition.isNotEmpty;
}

String _slug(String value) {
  final slug = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'deck' : slug;
}

int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
