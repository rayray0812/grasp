import 'package:flutter_test/flutter_test.dart';
import 'package:grasp_app/src/domain/models.dart';

void main() {
  test('vocabulary content round-trips independently from learning state', () {
    const entry = VocabularyEntry(
      id: 'affect',
      word: 'affect',
      lemma: 'affect',
      senses: [VocabularySense(definitionZh: '影響', partOfSpeech: 'v.')],
      confusingWords: [LexicalRelation(word: 'effect', noteZh: '通常作名詞')],
      collocations: ['adversely affect'],
    );
    final restored = VocabularyEntry.fromJson(entry.toJson());
    expect(restored.word, 'affect');
    expect(restored.confusingWords.single.word, 'effect');
    expect(restored.collocations, ['adversely affect']);

    final state = LearningState(vocabularyId: restored.id);
    expect(state.isNew, isTrue);
    expect(entry.toJson(), isNot(contains('stability')));
  });
}
