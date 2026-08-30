import 'package:flutter/foundation.dart';

import '../data/grasp_repository.dart';
import '../domain/models.dart';
import '../import/quizlet_importer.dart';
import '../learning/fsrs_scheduler.dart';
import '../review/review_engine.dart';

class TodaySnapshot {
  const TodaySnapshot({
    this.reviewCount = 0,
    this.newCount = 0,
    this.completedToday = 0,
    this.learnedCount = 0,
    this.retention = 0,
    this.streak = 0,
  });

  final int reviewCount;
  final int newCount;
  final int completedToday;
  final int learnedCount;
  final double retention;
  final int streak;

  int get plannedCount => reviewCount + newCount;
}

class ApplicationSnapshot {
  const ApplicationSnapshot({
    this.attempts = 0,
    this.correct = 0,
    this.averageResponseMs = 0,
    this.weakestQuestionType,
  });

  final int attempts;
  final int correct;
  final int averageResponseMs;
  final ReviewQuestionType? weakestQuestionType;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  int get averageResponseSeconds => (averageResponseMs / 1000).round();
}

class RecentMistake {
  const RecentMistake({required this.entry, required this.record});

  final VocabularyEntry entry;
  final ReviewRecord record;
}

class AppController extends ChangeNotifier {
  AppController({
    required GraspRepository repository,
    FsrsScheduler? scheduler,
    ReviewEngine? reviewEngine,
    QuizletImporter? importer,
    DateTime Function()? clock,
  }) : _repository = repository,
       _scheduler = scheduler ?? FsrsScheduler(),
       _reviewEngine = reviewEngine ?? const ReviewEngine(),
       _importer = importer ?? const QuizletImporter(),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final GraspRepository _repository;
  FsrsScheduler _scheduler;
  final ReviewEngine _reviewEngine;
  final QuizletImporter _importer;
  final DateTime Function() _clock;

  bool isLoading = true;
  String? error;
  TodaySnapshot today = const TodaySnapshot();
  ApplicationSnapshot application = const ApplicationSnapshot();
  List<RecentMistake> recentMistakes = const [];
  StudySettings settings = const StudySettings();
  List<Deck> decks = const [];
  List<VocabularyEntry> libraryResults = const [];

  List<VocabularyEntry> _queue = const [];
  int _queueIndex = 0;
  ReviewSession? _session;
  DateTime? _promptShownAt;
  bool isAnswerRevealed = false;
  String currentResponse = '';
  bool? currentResponseIsCorrect;
  String correctionResponse = '';
  bool isCorrectionComplete = false;
  int sessionAgainCount = 0;
  int sessionApplicationCount = 0;
  int sessionApplicationCorrect = 0;

  int get sessionTotal => _queue.length;
  int get sessionCompleted => _queueIndex.clamp(0, _queue.length);
  bool get hasCurrentCard => _queueIndex < _queue.length;
  bool get isSessionComplete => _queue.isNotEmpty && !hasCurrentCard;
  VocabularyEntry? get currentEntry =>
      hasCurrentCard ? _queue[_queueIndex] : null;

  LearningState? get currentLearningState {
    final entry = currentEntry;
    return entry == null ? null : _repository.getLearningState(entry.id);
  }

  ReviewPrompt? get currentPrompt {
    final entry = currentEntry;
    if (entry == null) return null;
    return _reviewEngine.buildPrompt(
      entry: entry,
      state: currentLearningState ?? LearningState(vocabularyId: entry.id),
    );
  }

  Map<ReviewRating, DateTime> get currentSchedulingPreview {
    final entry = currentEntry;
    if (entry == null) return const {};
    return _scheduler.preview(
      currentLearningState ?? LearningState(vocabularyId: entry.id),
      _clock(),
    );
  }

  Future<void> initialize() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _repository.initialize();
      await _repository.seedBuiltInCatalogIfNeeded();
      settings = _repository.getSettings();
      _scheduler = FsrsScheduler(desiredRetention: settings.desiredRetention);
      await refresh();
    } catch (exception, stackTrace) {
      debugPrint('Grasp initialization failed: $exception\n$stackTrace');
      error = '無法開啟本機學習資料。資料沒有被刪除，請重新啟動 App。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    decks = _repository.getDecks();
    settings = _repository.getSettings();
    final now = _clock();
    final states = _repository.getLearningStates();
    final records = _repository.getReviewRecords();
    final due = states.where((state) {
      if (state.isNew) return false;
      final dueAt = state.due;
      return dueAt == null || !dueAt.isAfter(now);
    }).length;
    // The home screen promises what this session will actually contain, so it
    // reports the capped figure rather than the whole backlog.
    final plannedReviews = due > settings.maxReviewsPerSession
        ? settings.maxReviewsPerSession
        : due;
    final newCount = _newCandidateIds(
      states,
    ).take(settings.dailyNewWords).length;
    final learned = states.where((state) => !state.isNew).length;
    final learnedStates = states.where(
      (state) => !state.isNew && state.stability > 0,
    );
    final retention = learnedStates.isEmpty
        ? 0.0
        : learnedStates
                  .map((state) => _scheduler.retrievability(state, now))
                  .reduce((a, b) => a + b) /
              learnedStates.length;
    final completedToday = records
        .where((record) => _sameLocalDay(record.reviewedAt, now))
        .length;
    today = TodaySnapshot(
      reviewCount: plannedReviews,
      newCount: newCount,
      completedToday: completedToday,
      learnedCount: learned,
      retention: retention,
      streak: _streak(records, now),
    );
    application = _applicationSnapshot(records);
    recentMistakes = _recentMistakes(records);
    libraryResults = _repository.searchVocabulary('', limit: 80);
    notifyListeners();
  }

  Future<void> startTodaySession() async {
    final now = _clock();
    final states = _repository.getLearningStates();
    final due =
        states
            .where(
              (state) =>
                  !state.isNew &&
                  (state.due == null || !state.due!.isAfter(now)),
            )
            .toList()
          ..sort((a, b) => (a.due ?? now).compareTo(b.due ?? now));
    // Oldest-due first, capped so the session stays finishable; the rest stay
    // due and lead the next session.
    final ids = <String>{
      ...due
          .take(settings.maxReviewsPerSession)
          .map((state) => state.vocabularyId),
    };
    ids.addAll(_newCandidateIds(states).take(settings.dailyNewWords));
    _queue = _repository.getVocabularyBatch(ids);
    _queueIndex = 0;
    isAnswerRevealed = false;
    currentResponse = '';
    currentResponseIsCorrect = null;
    correctionResponse = '';
    isCorrectionComplete = false;
    sessionAgainCount = 0;
    sessionApplicationCount = 0;
    sessionApplicationCorrect = 0;
    _promptShownAt = now;
    _session = ReviewSession(
      id: _id('session', now),
      startedAt: now,
      plannedVocabularyIds: _queue.map((entry) => entry.id).toList(),
    );
    await _repository.saveReviewSession(_session!);
    notifyListeners();
  }

  void revealAnswer() {
    isAnswerRevealed = true;
    notifyListeners();
  }

  void setCurrentResponse(String value) {
    currentResponse = value;
    notifyListeners();
  }

  void submitCurrentResponse() {
    final prompt = currentPrompt;
    if (prompt == null || currentResponse.trim().isEmpty) return;
    currentResponseIsCorrect = prompt.canCheckAutomatically
        ? prompt.matchesResponse(currentResponse)
        : null;
    isAnswerRevealed = true;
    notifyListeners();
  }

  void setCorrectionResponse(String value) {
    correctionResponse = value;
    notifyListeners();
  }

  void submitCorrection() {
    final prompt = currentPrompt;
    if (prompt == null || currentResponseIsCorrect != false) return;
    isCorrectionComplete = prompt.matchesResponse(correctionResponse);
    notifyListeners();
  }

  Future<void> rateCurrent(ReviewRating rating) async {
    final entry = currentEntry;
    final session = _session;
    if (entry == null || session == null || !isAnswerRevealed) return;
    if (currentResponseIsCorrect == false && !isCorrectionComplete) return;
    final now = _clock();
    final before =
        currentLearningState ?? LearningState(vocabularyId: entry.id);
    final effectiveRating = currentResponseIsCorrect == false
        ? ReviewRating.again
        : rating;
    final result = _scheduler.review(
      state: before,
      rating: effectiveRating,
      reviewedAt: now,
    );
    final prompt = currentPrompt!;
    final responseMs = now
        .difference(_promptShownAt ?? now)
        .inMilliseconds
        .clamp(0, 3600000);
    final record = ReviewRecord(
      id: _id('review', now),
      vocabularyId: entry.id,
      sessionId: session.id,
      reviewedAt: now,
      rating: effectiveRating,
      questionType: prompt.type,
      wasCorrect:
          currentResponseIsCorrect ?? effectiveRating != ReviewRating.again,
      responseTimeMs: responseMs,
      predictedRetrievability: result.retrievabilityBeforeReview,
      stabilityBefore: before.stability,
      stabilityAfter: result.state.stability,
      difficultyBefore: before.difficulty,
      difficultyAfter: result.state.difficulty,
      nextDue: result.state.due!,
      response: currentResponse,
      correctionCompleted: isCorrectionComplete,
    );
    await _repository.saveLearningState(result.state);
    await _repository.saveReviewRecord(record);
    if (effectiveRating == ReviewRating.again) sessionAgainCount++;
    if (prompt.type != ReviewQuestionType.recognition) {
      sessionApplicationCount++;
      if (record.wasCorrect) sessionApplicationCorrect++;
    }

    _queueIndex++;
    isAnswerRevealed = false;
    currentResponse = '';
    currentResponseIsCorrect = null;
    correctionResponse = '';
    isCorrectionComplete = false;
    _promptShownAt = now;
    final completed = session.plannedVocabularyIds.take(_queueIndex).toList();
    _session = session.copyWith(completedVocabularyIds: completed);
    if (!hasCurrentCard) {
      _session = _session!.copyWith(endedAt: now);
      await _repository.saveReviewSession(_session!);
      await refresh();
    } else {
      await _repository.saveReviewSession(_session!);
      notifyListeners();
    }
  }

  Future<int> importQuizlet({
    required String raw,
    required String title,
  }) async {
    final result = _importer.parse(raw: raw, title: title, now: _clock());
    await _repository.importDeck(result.deck, result.entries);
    await refresh();
    return result.entries.length;
  }

  Future<void> setDeckActive(String deckId, bool active) async {
    await _repository.setDeckActive(deckId, active);
    await refresh();
  }

  Future<void> setDailyNewWords(int value) async {
    settings = settings.copyWith(dailyNewWords: value.clamp(0, 50));
    await _repository.saveSettings(settings);
    await refresh();
  }

  void searchLibrary(String query) {
    libraryResults = _repository.searchVocabulary(query, limit: 100);
    notifyListeners();
  }

  Iterable<String> _newCandidateIds(List<LearningState> states) sync* {
    final introduced = states
        .where((state) => !state.isNew)
        .map((state) => state.vocabularyId)
        .toSet();
    final seen = <String>{};
    for (final deck in decks.where((deck) => deck.isActive)) {
      for (final id in deck.vocabularyIds) {
        if (!introduced.contains(id) && seen.add(id)) yield id;
      }
    }
  }

  int _streak(List<ReviewRecord> records, DateTime now) {
    final days = records.map((record) => _localDay(record.reviewedAt)).toSet();
    var cursor = _localDay(now);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  ApplicationSnapshot _applicationSnapshot(List<ReviewRecord> records) {
    final recent =
        records
            .where(
              (record) => record.questionType != ReviewQuestionType.recognition,
            )
            .toList()
          ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    final sample = recent.take(50).toList(growable: false);
    if (sample.isEmpty) return const ApplicationSnapshot();
    final correct = sample.where((record) => record.wasCorrect).length;
    final responseTotal = sample.fold<int>(
      0,
      (sum, record) => sum + record.responseTimeMs,
    );
    final byType = <ReviewQuestionType, List<ReviewRecord>>{};
    for (final record in sample) {
      byType.putIfAbsent(record.questionType, () => []).add(record);
    }
    ReviewQuestionType? weakest;
    var weakestAccuracy = 2.0;
    for (final entry in byType.entries) {
      final accuracy =
          entry.value.where((record) => record.wasCorrect).length /
          entry.value.length;
      if (accuracy < weakestAccuracy) {
        weakest = entry.key;
        weakestAccuracy = accuracy;
      }
    }
    return ApplicationSnapshot(
      attempts: sample.length,
      correct: correct,
      averageResponseMs: responseTotal ~/ sample.length,
      weakestQuestionType: weakest,
    );
  }

  List<RecentMistake> _recentMistakes(List<ReviewRecord> records) {
    final wrong = records.where((record) => !record.wasCorrect).toList()
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    final seen = <String>{};
    final result = <RecentMistake>[];
    for (final record in wrong) {
      if (!seen.add(record.vocabularyId)) continue;
      final entry = _repository.getVocabulary(record.vocabularyId);
      if (entry != null) {
        result.add(RecentMistake(entry: entry, record: record));
      }
      if (result.length == 3) break;
    }
    return result;
  }

  bool _sameLocalDay(DateTime a, DateTime b) => _localDay(a) == _localDay(b);

  DateTime _localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _id(String prefix, DateTime now) =>
      '$prefix-${now.microsecondsSinceEpoch}-${_queueIndex.toRadixString(36)}';
}
