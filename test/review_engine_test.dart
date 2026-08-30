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
    expect(prompt.responseMode, ReviewResponseMode.reveal);
  });

  test('first review requires typed English recall', () {
    final prompt = const ReviewEngine().buildPrompt(
      entry: entry,
      state: const LearningState(vocabularyId: 'v1', repetitions: 1),
    );
    expect(prompt.type, ReviewQuestionType.recall);
    expect(prompt.responseMode, ReviewResponseMode.typedExact);
    expect(prompt.matchesResponse(' Substantial! '), isTrue);
    expect(prompt.matchesResponse('considerable'), isFalse);
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
    expect(types, contains(ReviewQuestionType.production));
  });

  test('active use asks for a complete sentence and a concrete checklist', () {
    ReviewPrompt? prompt;
    for (var repetitions = 2; repetitions <= 12; repetitions++) {
      final candidate = const ReviewEngine().buildPrompt(
        entry: entry,
        state: LearningState(vocabularyId: 'v1', repetitions: repetitions),
      );
      if (candidate.type == ReviewQuestionType.production) {
        prompt = candidate;
        break;
      }
    }
    expect(prompt, isNotNull);
    expect(prompt!.responseMode, ReviewResponseMode.typedSelfCheck);
    expect(prompt.selfCheckItems, isNotEmpty);
    expect(prompt.answer, contains('substantial'));
  });
}
