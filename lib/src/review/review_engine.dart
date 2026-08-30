import '../domain/models.dart';

enum ReviewResponseMode { reveal, typedExact, typedSelfCheck }

class ReviewPrompt {
  const ReviewPrompt({
    required this.vocabularyId,
    required this.type,
    required this.eyebrow,
    required this.prompt,
    required this.answer,
    this.instruction = '',
    this.context = '',
    this.supportingDetails = const [],
    this.responseMode = ReviewResponseMode.reveal,
    this.acceptedAnswers = const [],
    this.selfCheckItems = const [],
  });

  final String vocabularyId;
  final ReviewQuestionType type;
  final String eyebrow;
  final String instruction;
  final String prompt;
  final String context;
  final String answer;
  final List<String> supportingDetails;
  final ReviewResponseMode responseMode;
  final List<String> acceptedAnswers;
  final List<String> selfCheckItems;

  bool get needsTypedResponse => responseMode != ReviewResponseMode.reveal;
  bool get canCheckAutomatically =>
      responseMode == ReviewResponseMode.typedExact;

  bool matchesResponse(String response) {
    if (!canCheckAutomatically) return false;
    final normalized = _normalize(response);
    return acceptedAnswers.any((answer) => _normalize(answer) == normalized);
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
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
    final type = _selectType(state, available);
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
          instruction: primary.examples.isEmpty
              ? '先回想這個字在句子裡可能扮演的詞性與意思。'
              : '先讀例句，從語境推測意思，再顯示答案。',
          prompt: entry.word,
          context: primary.examples.firstOrNull?.sentence ?? '',
          answer: definitions,
          supportingDetails: _details(entry),
        );
      case ReviewQuestionType.recall:
        return _recallPrompt(entry, primary);
      case ReviewQuestionType.cloze:
        // Cloze is offered when *any* sense has an example, so take the sense
        // that actually has one — the primary sense often has none, and
        // reading its empty example list used to throw mid-review.
        final clozeSense = entry.senses.firstWhere(
          (sense) => sense.examples.isNotEmpty,
          orElse: () => primary,
        );
        final example = clozeSense.examples.firstOrNull;
        if (example == null) return _recallPrompt(entry, primary);
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: 'Cloze',
          instruction: '根據整句語意與文法，輸入最適合的單字。',
          prompt: _cloze(example.sentence, entry.word),
          context: clozeSense.definitionZh,
          answer: entry.word,
          supportingDetails: [
            if (example.translationZh.isNotEmpty) example.translationZh,
            ..._details(entry),
          ],
          responseMode: ReviewResponseMode.typedExact,
          acceptedAnswers: {entry.word, entry.lemma}.toList(),
        );
      case ReviewQuestionType.meaningDiscrimination:
        final sense = entry.senses[state.repetitions % entry.senses.length];
        final example = sense.examples.firstOrNull;
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: 'Meaning in context',
          instruction: '不要翻譯整句；先找出這個字在此處的語意功能。',
          prompt: example?.sentence ?? entry.word,
          context: '這裡的「${entry.word}」是什麼意思？',
          answer: _senseLabel(sense),
          supportingDetails: _details(entry),
        );
      case ReviewQuestionType.usage:
        final collocation = entry.collocations.firstOrNull;
        final synonym = entry.synonyms.firstOrNull;
        final asksCollocation = collocation != null;
        final usagePrompt = asksCollocation
            ? _cloze(collocation, entry.word)
            : '「${entry.word}」在這個語意下可替換成哪個近義字？';
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: asksCollocation ? 'Collocation' : 'Synonym / Usage',
          instruction: asksCollocation ? '完成搭配，不要只回想中文意思。' : '輸入最接近、且適合此語境的字。',
          prompt: usagePrompt,
          context: primary.definitionZh,
          answer: asksCollocation ? collocation : synonym!.word,
          supportingDetails: _details(entry),
          responseMode: ReviewResponseMode.typedExact,
          acceptedAnswers: [asksCollocation ? entry.word : synonym!.word],
        );
      case ReviewQuestionType.production:
        final example = primary.examples.firstOrNull;
        final collocation = entry.collocations.firstOrNull;
        return ReviewPrompt(
          vocabularyId: entry.id,
          type: type,
          eyebrow: 'Active Use',
          instruction: '用英文寫一句完整的句子。先寫完，再對照檢核。',
          prompt: '用「${entry.word}」表達：${primary.definitionZh}',
          context: collocation == null
              ? primary.partOfSpeech
              : '可嘗試使用：$collocation',
          answer: example?.sentence ?? '沒有唯一答案；請依下方條件誠實檢核。',
          supportingDetails: _details(entry),
          responseMode: ReviewResponseMode.typedSelfCheck,
          selfCheckItems: [
            '句意符合「${primary.definitionZh}」',
            if (primary.partOfSpeech.isNotEmpty)
              '「${entry.word}」的詞性使用正確（${primary.partOfSpeech}）',
            if (collocation != null) '搭配自然；可參考「$collocation」',
            '句子有主詞與動詞，且時態、單複數合理',
          ],
        );
    }
  }

  /// Typed English recall. Also the fallback when a context-based question
  /// cannot be built because the entry has no usable example sentence.
  ReviewPrompt _recallPrompt(VocabularyEntry entry, VocabularySense primary) =>
      ReviewPrompt(
        vocabularyId: entry.id,
        type: ReviewQuestionType.recall,
        eyebrow: 'Recall',
        instruction: '不要只在腦中想，請把英文完整輸入。',
        prompt: primary.definitionZh,
        context: primary.partOfSpeech,
        answer: entry.word,
        supportingDetails: _details(entry),
        responseMode: ReviewResponseMode.typedExact,
        acceptedAnswers: {entry.word, entry.lemma}.toList(),
      );

  ReviewQuestionType _selectType(
    LearningState state,
    List<ReviewQuestionType> available,
  ) {
    if (state.isNew) return ReviewQuestionType.recognition;
    if (state.repetitions == 1 &&
        available.contains(ReviewQuestionType.recall)) {
      return ReviewQuestionType.recall;
    }
    final applied = available
        .where((type) => type != ReviewQuestionType.recognition)
        .toList(growable: false);
    if (applied.isEmpty) return ReviewQuestionType.recognition;
    return applied[(state.repetitions - 1) % applied.length];
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
    if (entry.senses.any((sense) => sense.examples.isNotEmpty) ||
        entry.collocations.isNotEmpty)
      ReviewQuestionType.production,
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
