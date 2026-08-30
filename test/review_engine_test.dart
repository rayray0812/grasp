import 'package:flutter_test/flutter_test.dart';
import 'package:grasp_app/src/domain/models.dart';
import 'package:grasp_app/src/review/review_engine.dart';

void main() {
  const entry = VocabularyEntry(
    id: 'v1',
    word: 'substantial',
    lemma: 'substantial',
    senses: [
      VocabularySense(
        definitionZh: '大量的；可觀的',
        partOfSpeech: 'adj.',
        examples: [
          VocabularyExample(
            sentence: 'The project requires a substantial amount of money.',
          ),
        ],
      ),
      VocabularySense(
        definitionZh: '實質的',
        partOfSpeech: 'adj.',
        examples: [
          VocabularyExample(sentence: 'We need substantial evidence.'),
        ],
      ),
    ],
    synonyms: [LexicalRelation(word: 'considerable')],
    collocations: ['a substantial amount of'],
  );

  test('new words always start with recognition', () {
    final prompt = const ReviewEngine().buildPrompt(
      entry: entry,
      state: const LearningState(vocabularyId: 'v1'),
    );
    expect(prompt.type, ReviewQuestionType.recognition);
    expect(prompt.answer, contains('大量'));
  });

  test('review mode rotates through available contextual question types', () {
    final types = <ReviewQuestionType>{};
    for (var repetitions = 1; repetitions <= 10; repetitions++) {
      types.add(
        const ReviewEngine()
            .buildPrompt(
              entry: entry,
              state: LearningState(
                vocabularyId: 'v1',
                repetitions: repetitions,
              ),
            )
            .type,
      );
    }
    expect(types, contains(ReviewQuestionType.cloze));
    expect(types, contains(ReviewQuestionType.meaningDiscrimination));
    expect(types, contains(ReviewQuestionType.usage));
  });
}
