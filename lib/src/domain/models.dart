enum DeckSource { builtIn, quizlet, custom }

enum ReviewRating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const ReviewRating(this.value);
  final int value;
}

enum ReviewQuestionType {
  recognition,
  recall,
  cloze,
  meaningDiscrimination,
  usage,
  production,
}

class VocabularyExample {
  const VocabularyExample({
    required this.sentence,
    this.translationZh = '',
    this.source = '',
    this.targetText = '',
  });

  final String sentence;
  final String translationZh;
  final String source;
  final String targetText;

  Map<String, dynamic> toJson() => {
    'sentence': sentence,
    'translationZh': translationZh,
    'source': source,
    'targetText': targetText,
  };

  factory VocabularyExample.fromJson(Map<String, dynamic> json) =>
      VocabularyExample(
        sentence: _string(json['sentence']),
        translationZh: _string(json['translationZh']),
        source: _string(json['source']),
        targetText: _string(json['targetText']),
      );
}

class VocabularySense {
  const VocabularySense({
    required this.definitionZh,
    this.definitionEn = '',
    this.partOfSpeech = '',
    this.isExamPriority = false,
    this.examples = const [],
  });

  final String definitionZh;
  final String definitionEn;
  final String partOfSpeech;
  final bool isExamPriority;
  final List<VocabularyExample> examples;

  Map<String, dynamic> toJson() => {
    'definitionZh': definitionZh,
    'definitionEn': definitionEn,
    'partOfSpeech': partOfSpeech,
    'isExamPriority': isExamPriority,
    'examples': examples.map((item) => item.toJson()).toList(),
  };

  factory VocabularySense.fromJson(Map<String, dynamic> json) =>
      VocabularySense(
        definitionZh: _string(json['definitionZh']),
        definitionEn: _string(json['definitionEn']),
        partOfSpeech: _string(json['partOfSpeech']),
        isExamPriority: json['isExamPriority'] == true,
        examples: _mapList(
          json['examples'],
        ).map(VocabularyExample.fromJson).toList(growable: false),
      );
}

class LexicalRelation {
  const LexicalRelation({required this.word, this.noteZh = ''});

  final String word;
  final String noteZh;

  Map<String, dynamic> toJson() => {'word': word, 'noteZh': noteZh};

  factory LexicalRelation.fromJson(Map<String, dynamic> json) =>
      LexicalRelation(
        word: _string(json['word']),
        noteZh: _string(json['noteZh']),
      );
}

class WordFamilyMember {
  const WordFamilyMember({
    required this.word,
    this.partOfSpeech = '',
    this.meaningZh = '',
  });

  final String word;
  final String partOfSpeech;
  final String meaningZh;

  Map<String, dynamic> toJson() => {
    'word': word,
    'partOfSpeech': partOfSpeech,
    'meaningZh': meaningZh,
  };

  factory WordFamilyMember.fromJson(Map<String, dynamic> json) =>
      WordFamilyMember(
        word: _string(json['word']),
        partOfSpeech: _string(json['partOfSpeech']),
        meaningZh: _string(json['meaningZh']),
      );
}

/// Language content only. Scheduling and review history live in separate
/// models, so content can be corrected or re-imported without resetting memory.
class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.word,
    required this.lemma,
    required this.senses,
    this.synonyms = const [],
    this.confusingWords = const [],
    this.collocations = const [],
    this.wordFamily = const [],
    this.notes = '',
    this.level,
    this.tags = const [],
    this.source = 'custom',
  });

  final String id;
  final String word;
  final String lemma;
  final List<VocabularySense> senses;
  final List<LexicalRelation> synonyms;
  final List<LexicalRelation> confusingWords;
  final List<String> collocations;
  final List<WordFamilyMember> wordFamily;
  final String notes;
  final int? level;
  final List<String> tags;
  final String source;

  VocabularySense get primarySense => senses.first;

  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'lemma': lemma,
    'senses': senses.map((item) => item.toJson()).toList(),
    'synonyms': synonyms.map((item) => item.toJson()).toList(),
    'confusingWords': confusingWords.map((item) => item.toJson()).toList(),
    'collocations': collocations,
    'wordFamily': wordFamily.map((item) => item.toJson()).toList(),
    'notes': notes,
    'level': level,
    'tags': tags,
    'source': source,
  };

  factory VocabularyEntry.fromJson(Map<String, dynamic> json) {
    final senses = _mapList(json['senses'])
        .map(VocabularySense.fromJson)
        .where((sense) => sense.definitionZh.isNotEmpty)
        .toList(growable: false);
    if (senses.isEmpty) {
      throw const FormatException('Vocabulary entry needs at least one sense.');
    }
    return VocabularyEntry(
      id: _string(json['id']),
      word: _string(json['word']),
      lemma: _string(json['lemma']),
      senses: senses,
      synonyms: _mapList(
        json['synonyms'],
      ).map(LexicalRelation.fromJson).toList(growable: false),
      confusingWords: _mapList(
        json['confusingWords'],
      ).map(LexicalRelation.fromJson).toList(growable: false),
      collocations: _stringList(json['collocations']),
      wordFamily: _mapList(
        json['wordFamily'],
      ).map(WordFamilyMember.fromJson).toList(growable: false),
      notes: _string(json['notes']),
      level: (json['level'] as num?)?.toInt(),
      tags: _stringList(json['tags']),
      source: _string(json['source']).isEmpty
          ? 'custom'
          : _string(json['source']),
    );
  }
}

/// A user's FSRS state for one vocabulary entry.
class LearningState {
  const LearningState({
    required this.vocabularyId,
    this.stability = 0,
    this.difficulty = 0,
    this.repetitions = 0,
    this.lapses = 0,
    this.fsrsState = 0,
    this.step = 0,
    this.lastReview,
    this.due,
  });

  final String vocabularyId;
  final double stability;
  final double difficulty;
  final int repetitions;
  final int lapses;
  final int fsrsState; // 0=new, 1=learning, 2=review, 3=relearning
  final int? step;
  final DateTime? lastReview;
  final DateTime? due;

  bool get isNew => repetitions == 0;

  Map<String, dynamic> toJson() => {
    'vocabularyId': vocabularyId,
    'stability': stability,
    'difficulty': difficulty,
    'repetitions': repetitions,
    'lapses': lapses,
    'fsrsState': fsrsState,
    'step': step,
    'lastReview': lastReview?.toIso8601String(),
    'due': due?.toIso8601String(),
  };

  factory LearningState.fromJson(Map<String, dynamic> json) => LearningState(
    vocabularyId: _string(json['vocabularyId']),
    stability: (json['stability'] as num?)?.toDouble() ?? 0,
    difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0,
    repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
    lapses: (json['lapses'] as num?)?.toInt() ?? 0,
    fsrsState: (json['fsrsState'] as num?)?.toInt() ?? 0,
    step: (json['step'] as num?)?.toInt(),
    lastReview: _date(json['lastReview']),
    due: _date(json['due']),
  );
}

class ReviewRecord {
  const ReviewRecord({
    required this.id,
    required this.vocabularyId,
    required this.sessionId,
    required this.reviewedAt,
    required this.rating,
    required this.questionType,
    required this.wasCorrect,
    required this.responseTimeMs,
    required this.predictedRetrievability,
    required this.stabilityBefore,
    required this.stabilityAfter,
    required this.difficultyBefore,
    required this.difficultyAfter,
    required this.nextDue,
    this.response = '',
    this.correctionCompleted = false,
  });

  final String id;
  final String vocabularyId;
  final String sessionId;
  final DateTime reviewedAt;
  final ReviewRating rating;
  final ReviewQuestionType questionType;
  final bool wasCorrect;
  final int responseTimeMs;
  final double predictedRetrievability;
  final double stabilityBefore;
  final double stabilityAfter;
  final double difficultyBefore;
  final double difficultyAfter;
  final DateTime nextDue;
  final String response;
  final bool correctionCompleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'vocabularyId': vocabularyId,
    'sessionId': sessionId,
    'reviewedAt': reviewedAt.toIso8601String(),
    'rating': rating.value,
    'questionType': questionType.name,
    'wasCorrect': wasCorrect,
    'responseTimeMs': responseTimeMs,
    'predictedRetrievability': predictedRetrievability,
    'stabilityBefore': stabilityBefore,
    'stabilityAfter': stabilityAfter,
    'difficultyBefore': difficultyBefore,
    'difficultyAfter': difficultyAfter,
    'nextDue': nextDue.toIso8601String(),
    'response': response,
    'correctionCompleted': correctionCompleted,
  };

  factory ReviewRecord.fromJson(Map<String, dynamic> json) => ReviewRecord(
    id: _string(json['id']),
    vocabularyId: _string(json['vocabularyId']),
    sessionId: _string(json['sessionId']),
    reviewedAt: _date(json['reviewedAt']) ?? DateTime.now().toUtc(),
    rating: ReviewRating.values.firstWhere(
      (value) => value.value == json['rating'],
      orElse: () => ReviewRating.good,
    ),
    questionType: ReviewQuestionType.values.firstWhere(
      (value) => value.name == json['questionType'],
      orElse: () => ReviewQuestionType.recognition,
    ),
    wasCorrect: json['wasCorrect'] == true,
    responseTimeMs: (json['responseTimeMs'] as num?)?.toInt() ?? 0,
    predictedRetrievability:
        (json['predictedRetrievability'] as num?)?.toDouble() ?? 0,
    stabilityBefore: (json['stabilityBefore'] as num?)?.toDouble() ?? 0,
    stabilityAfter: (json['stabilityAfter'] as num?)?.toDouble() ?? 0,
    difficultyBefore: (json['difficultyBefore'] as num?)?.toDouble() ?? 0,
    difficultyAfter: (json['difficultyAfter'] as num?)?.toDouble() ?? 0,
    nextDue: _date(json['nextDue']) ?? DateTime.now().toUtc(),
    response: _string(json['response']),
    correctionCompleted: json['correctionCompleted'] == true,
  );
}

class Deck {
  const Deck({
    required this.id,
    required this.title,
    required this.vocabularyIds,
    required this.source,
    required this.createdAt,
    this.description = '',
    this.isActive = false,
  });

  final String id;
  final String title;
  final String description;
  final List<String> vocabularyIds;
  final DeckSource source;
  final DateTime createdAt;
  final bool isActive;

  Deck copyWith({bool? isActive}) => Deck(
    id: id,
    title: title,
    description: description,
    vocabularyIds: vocabularyIds,
    source: source,
    createdAt: createdAt,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'vocabularyIds': vocabularyIds,
    'source': source.name,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory Deck.fromJson(Map<String, dynamic> json) => Deck(
    id: _string(json['id']),
    title: _string(json['title']),
    description: _string(json['description']),
    vocabularyIds: _stringList(json['vocabularyIds']),
    source: DeckSource.values.firstWhere(
      (value) => value.name == json['source'],
      orElse: () => DeckSource.custom,
    ),
    createdAt: _date(json['createdAt']) ?? DateTime.now().toUtc(),
    isActive: json['isActive'] == true,
  );
}

class ReviewSession {
  const ReviewSession({
    required this.id,
    required this.startedAt,
    required this.plannedVocabularyIds,
    this.completedVocabularyIds = const [],
    this.endedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> plannedVocabularyIds;
  final List<String> completedVocabularyIds;

  ReviewSession copyWith({
    DateTime? endedAt,
    List<String>? completedVocabularyIds,
  }) => ReviewSession(
    id: id,
    startedAt: startedAt,
    endedAt: endedAt ?? this.endedAt,
    plannedVocabularyIds: plannedVocabularyIds,
    completedVocabularyIds:
        completedVocabularyIds ?? this.completedVocabularyIds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'plannedVocabularyIds': plannedVocabularyIds,
    'completedVocabularyIds': completedVocabularyIds,
  };

  factory ReviewSession.fromJson(Map<String, dynamic> json) => ReviewSession(
    id: _string(json['id']),
    startedAt: _date(json['startedAt']) ?? DateTime.now().toUtc(),
    endedAt: _date(json['endedAt']),
    plannedVocabularyIds: _stringList(json['plannedVocabularyIds']),
    completedVocabularyIds: _stringList(json['completedVocabularyIds']),
  );
}

class StudySettings {
  const StudySettings({
    this.dailyNewWords = 10,
    this.desiredRetention = 0.9,
    this.maxReviewsPerSession = defaultMaxReviewsPerSession,
  });

  /// A session has to stay finishable. Without a ceiling, a user returning
  /// after a break is handed every overdue card at once, which is the usual
  /// reason people abandon an SRS app.
  static const defaultMaxReviewsPerSession = 60;

  final int dailyNewWords;
  final double desiredRetention;
  final int maxReviewsPerSession;

  StudySettings copyWith({int? dailyNewWords, int? maxReviewsPerSession}) =>
      StudySettings(
        dailyNewWords: dailyNewWords ?? this.dailyNewWords,
        desiredRetention: desiredRetention,
        maxReviewsPerSession: maxReviewsPerSession ?? this.maxReviewsPerSession,
      );

  Map<String, dynamic> toJson() => {
    'dailyNewWords': dailyNewWords,
    'desiredRetention': desiredRetention,
    'maxReviewsPerSession': maxReviewsPerSession,
  };

  factory StudySettings.fromJson(Map<String, dynamic> json) => StudySettings(
    dailyNewWords: (json['dailyNewWords'] as num?)?.toInt() ?? 10,
    desiredRetention: (json['desiredRetention'] as num?)?.toDouble() ?? 0.9,
    maxReviewsPerSession:
        (json['maxReviewsPerSession'] as num?)?.toInt() ??
        defaultMaxReviewsPerSession,
  );
}

String _string(Object? value) => value?.toString().trim() ?? '';

DateTime? _date(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : DateTime.tryParse(text)?.toUtc();
}

List<String> _stringList(Object? value) => value is List
    ? value
          .map(_string)
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
    : const [];
