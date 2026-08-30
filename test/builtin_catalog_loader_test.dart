import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grasp_app/src/data/builtin_catalog_loader.dart';
import 'package:grasp_app/src/domain/content_quality.dart';

void main() {
  const vocabulary = {
    'words': [
      {
        'id': 'word-accomplish',
        'word': 'accomplish',
        'lemma': 'accomplish',
        'definitionZh': '完成；達成',
        'partOfSpeech': 'v.',
        'level': 3,
      },
    ],
    'decks': [
      {
        'id': 'gsat-level-3',
        'title': 'Level 3',
        'wordIds': ['word-accomplish'],
      },
    ],
  };

  test(
    'application overlay enriches content without changing word identity',
    () {
      final catalog = const BuiltInCatalogLoader().parse(
        vocabularyJson: jsonEncode(vocabulary),
        applicationJson: jsonEncode({
          'schemaVersion': 1,
          'entries': [
            {
              'lemma': 'accomplish',
              'examples': [
                {
                  'sentence': 'He accomplished the task ahead of schedule.',
                  'source': 'test',
                },
              ],
              'collocations': ['accomplish a task'],
            },
          ],
        }),
      );

      final entry = catalog.entries.single;
      expect(entry.id, 'word-accomplish');
      expect(
        entry.primarySense.examples.single.sentence,
        contains('accomplished'),
      );
      expect(entry.collocations, ['accomplish a task']);
      expect(entry.contentQuality.isApplicationReady, isTrue);
    },
  );

  test('overlay fails fast when a lemma is not in the exam catalog', () {
    expect(
      () => const BuiltInCatalogLoader().parse(
        vocabularyJson: jsonEncode(vocabulary),
        applicationJson: jsonEncode({
          'schemaVersion': 1,
          'entries': [
            {'lemma': 'not-in-catalog'},
          ],
        }),
      ),
      throwsFormatException,
    );
  });

  test(
    'the complete bundled catalog and application overlay are valid',
    () async {
      final catalog = const BuiltInCatalogLoader().parse(
        vocabularyJson: await File(
          BuiltInCatalogLoader.assetPath,
        ).readAsString(),
        applicationJson: await File(
          BuiltInCatalogLoader.applicationContentPath,
        ).readAsString(),
      );
      expect(catalog.entries, hasLength(6392));
      expect(
        catalog.entries.where(
          (entry) => entry.contentQuality.isApplicationReady,
        ),
        isNotEmpty,
      );
    },
  );
}
