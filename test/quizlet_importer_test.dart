import 'package:flutter_test/flutter_test.dart';
import 'package:grasp_app/src/import/quizlet_importer.dart';

void main() {
  const importer = QuizletImporter();

  test('imports Quizlet tab-separated export and groups multiple meanings', () {
    final result = importer.parse(
      raw: 'issue\t議題\nissue\t發行\nrespond\t回應',
      title: '模考單字',
      now: DateTime.utc(2026, 8, 30),
    );

    expect(result.entries, hasLength(2));
    expect(
      result.entries.firstWhere((entry) => entry.word == 'issue').senses,
      hasLength(2),
    );
    expect(result.deck.isActive, isTrue);
    expect(result.deck.vocabularyIds, hasLength(2));
  });

  test('imports legacy JSON without requiring optional fields', () {
    final result = importer.parse(
      raw: '{"cards":[{"term":"pose","definition":"造成；提出"}]}',
      title: 'Quizlet',
    );
    expect(result.entries.single.word, 'pose');
    expect(result.entries.single.primarySense.examples, isEmpty);
  });

  test('rejects rows without a term-definition separator', () {
    expect(
      () => importer.parse(raw: 'just one value', title: 'broken'),
      throwsFormatException,
    );
  });
}
