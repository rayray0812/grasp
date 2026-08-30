import '../domain/models.dart';

class ReviewPrompt {
  const ReviewPrompt({
    required this.vocabularyId,
    required this.type,
    required this.eyebrow,
    required this.prompt,
    required this.answer,
    this.context = '',
    this.supportingDetails = const [],
  });

  final String vocabularyId;
  final ReviewQuestionType type;
  final String eyebrow;
  final String prompt;
  final String context;
  final String answer;
  final List<String> supportingDetails;
}

/// Chooses how to test a word. It does not know when the word is due and it
/// never mutates FSRS state.
class ReviewEngine {
  const ReviewEngine();

  ReviewPrompt buildPrompt({
    required VocabularyEntry entry,
    required LearningState state,
  }) {
    final available = _availableTypes(entry);
    final type = state.isNew
        ? ReviewQuestionType.recognition
        : available[state.repetitions % available.length];
    final primary = entry.primarySense;
    final definitions = entry.senses
        .map((sense) => _senseLabel(sense))
        .join('；');

    switch (type) {
      case ReviewQuestionType.recognition:
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: state.isNew ? '新單字 · Recognition' : 'Recognition',
          prompt: entry.word,
          context: primary.examples.firstOrNull?.sentence ?? '',
          answer: definitions,
          supportingDetails: _details(entry),
        );
      case ReviewQuestionType.recall:
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: 'Recall',
          prompt: primary.definitionZh,
          context: primary.partOfSpeech,
          answer: entry.word,
          supportingDetails: _details(entry),
        );
      case ReviewQuestionType.cloze:
        final example = primary.examples.first;
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: 'Cloze',
          prompt: _cloze(example.sentence, entry.word),
          context: primary.definitionZh,
          answer: entry.word,
          supportingDetails: [
            if (example.translationZh.isNotEmpty) example.translationZh,
            ..._details(entry),
          ],
        );
      case ReviewQuestionType.meaningDiscrimination:
        final sense = entry.senses[state.repetitions % entry.senses.length];
        final example = sense.examples.firstOrNull;
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: 'Meaning in context',
          prompt: example?.sentence ?? entry.word,
          context: '這裡的「${entry.word}」是什麼意思？',
          answer: _senseLabel(sense),
          supportingDetails: _details(entry),
        );
      case ReviewQuestionType.usage:
        final collocation = entry.collocations.firstOrNull;
        final synonym = entry.synonyms.firstOrNull;
        final asksCollocation = collocation != null;
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: asksCollocation ? 'Collocation' : 'Synonym / Usage',
          prompt: asksCollocation
              ? '回想一個含有「${entry.word}」的常見搭配'
              : '哪個字和「${entry.word}」意思最接近？',
          context: primary.definitionZh,
          answer: asksCollocation ? collocation : synonym!.word,
          supportingDetails: _details(entry),
        );
    }
  }

  List<ReviewQuestionType> _availableTypes(VocabularyEntry entry) => [
    ReviewQuestionType.recognition,
    ReviewQuestionType.recall,
    if (entry.senses.any((sense) => sense.examples.isNotEmpty))
      ReviewQuestionType.cloze,
    if (entry.senses.length > 1 &&
        entry.senses.every((sense) => sense.examples.isNotEmpty))
      ReviewQuestionType.meaningDiscrimination,
    if (entry.collocations.isNotEmpty || entry.synonyms.isNotEmpty)
      ReviewQuestionType.usage,
  ];

  String _senseLabel(VocabularySense sense) => [
    if (sense.partOfSpeech.isNotEmpty) sense.partOfSpeech,
    sense.definitionZh,
  ].join(' ');

  String _cloze(String sentence, String word) {
    final pattern = RegExp(RegExp.escape(word), caseSensitive: false);
    if (pattern.hasMatch(sentence)) {
      return sentence.replaceFirst(pattern, '_____');
    }
    return '$sentence\n提示：填入「${word.length}」個字母的單字';
  }

  List<String> _details(VocabularyEntry entry) => [
    if (entry.collocations.isNotEmpty)
      '常見搭配：${entry.collocations.take(3).join(' · ')}',
    if (entry.synonyms.isNotEmpty)
      '近義字：${entry.synonyms.take(3).map((item) => item.word).join(' · ')}',
    if (entry.confusingWords.isNotEmpty)
      '易混淆：${entry.confusingWords.take(3).map((item) => item.word).join(' · ')}',
    if (entry.wordFamily.isNotEmpty)
      '字族：${entry.wordFamily.take(4).map((item) => item.word).join(' · ')}',
  ];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
