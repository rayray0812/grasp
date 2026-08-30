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

  test(
    'cloze survives a multi-sense word whose primary sense has no example',
    () {
      // The catalogue enriches some words with extra senses; the first sense
      // often carries no example sentence. Reading it unguarded used to throw
      // "Bad state: No element" in the middle of a review session.
      final entry = VocabularyEntry(
        id: 'bank',
        word: 'bank',
        lemma: 'bank',
        senses: const [
          VocabularySense(definitionZh: '銀行', partOfSpeech: 'n.'),
          VocabularySense(
            definitionZh: '河岸',
            partOfSpeech: 'n.',
            examples: [VocabularyExample(sentence: 'We sat on the bank.')],
          ),
        ],
      );

      for (var repetitions = 1; repetitions < 12; repetitions++) {
        final prompt = const ReviewEngine().buildPrompt(
          entry: entry,
          state: LearningState(
            vocabularyId: 'bank',
            repetitions: repetitions,
            lastReview: DateTime.utc(2026, 1, 1),
            due: DateTime.utc(2026, 1, 2),
            stability: 3,
            difficulty: 5,
            fsrsState: 2,
          ),
        );
        expect(prompt.prompt, isNotEmpty, reason: 'repetitions=$repetitions');
      }
    },
  );

  test('cloze falls back to typed recall when no sense has an example', () {
    const entry = VocabularyEntry(
      id: 'plain',
      word: 'plain',
      lemma: 'plain',
      senses: [VocabularySense(definitionZh: '平原', partOfSpeech: 'n.')],
    );
    final prompt = const ReviewEngine().buildPrompt(
      entry: entry,
      state: const LearningState(vocabularyId: 'plain', repetitions: 3),
    );
    expect(prompt.prompt, isNotEmpty);
    expect(prompt.responseMode, isNot(ReviewResponseMode.reveal));
  });
}
