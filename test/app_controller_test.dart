import 'package:flutter_test/flutter_test.dart';
import 'package:grasp_app/src/app/app_controller.dart';
import 'package:grasp_app/src/data/grasp_repository.dart';
import 'package:grasp_app/src/domain/models.dart';

void main() {
  test('today queue contains due reviews before bounded new words', () async {
    final now = DateTime.utc(2026, 8, 30, 8);
    final repository = _MemoryRepository(now);
    final controller = AppController(repository: repository, clock: () => now);

    await controller.initialize();
    expect(controller.today.reviewCount, 1);
    expect(controller.today.newCount, 1);

    await controller.startTodaySession();
    expect(controller.sessionTotal, 2);
    expect(controller.currentEntry!.id, 'due');

    controller.revealAnswer();
    await controller.rateCurrent(ReviewRating.good);
    controller.revealAnswer();
    await controller.rateCurrent(ReviewRating.easy);

    expect(controller.isSessionComplete, isTrue);
    expect(repository.states['due']!.repetitions, 2);
    expect(repository.states['new']!.repetitions, 1);
    expect(repository.records, hasLength(2));
    expect(repository.sessions.values.single.endedAt, isNotNull);
  });

  test('a large backlog is capped so one session stays finishable', () async {
    final now = DateTime.utc(2026, 8, 30, 8);
    final repository = _MemoryRepository(now);
    // 200 overdue words: without a ceiling every one of them lands in a single
    // session, which is how returning users get buried and quit.
    for (var i = 0; i < 200; i++) {
      final id = 'backlog-$i';
      repository.entries[id] = VocabularyEntry(
        id: id,
        word: 'word$i',
        lemma: 'word$i',
        senses: const [VocabularySense(definitionZh: '意思')],
      );
      repository.states[id] = LearningState(
        vocabularyId: id,
        stability: 2,
        difficulty: 5,
        repetitions: 1,
        fsrsState: 2,
        lastReview: now.subtract(const Duration(days: 5)),
        due: now.subtract(Duration(days: 2, minutes: i)),
      );
    }
    final controller = AppController(repository: repository, clock: () => now);

    await controller.initialize();
    const cap = StudySettings.defaultMaxReviewsPerSession;
    expect(controller.today.reviewCount, cap);

    await controller.startTodaySession();
    expect(controller.sessionTotal, lessThanOrEqualTo(cap + 10));
  });
}

class _MemoryRepository implements GraspRepository {
  _MemoryRepository(this.now) {
    entries.addAll({
      'due': const VocabularyEntry(
        id: 'due',
        word: 'affect',
        lemma: 'affect',
        senses: [VocabularySense(definitionZh: '影響')],
      ),
      'new': const VocabularyEntry(
        id: 'new',
        word: 'respond',
        lemma: 'respond',
        senses: [VocabularySense(definitionZh: '回應')],
      ),
    });
    decks.add(
      Deck(
        id: 'deck',
        title: '學測',
        vocabularyIds: const ['new', 'due'],
        source: DeckSource.builtIn,
        createdAt: now,
        isActive: true,
      ),
    );
    states['due'] = LearningState(
      vocabularyId: 'due',
      stability: 2,
      difficulty: 5,
      repetitions: 1,
      fsrsState: 2,
      lastReview: now.subtract(const Duration(days: 3)),
      due: now.subtract(const Duration(days: 1)),
    );
  }

  final DateTime now;
  final Map<String, VocabularyEntry> entries = {};
  final Map<String, LearningState> states = {};
  final List<ReviewRecord> records = [];
  final Map<String, ReviewSession> sessions = {};
  final List<Deck> decks = [];
  StudySettings settings = const StudySettings(dailyNewWords: 1);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> seedBuiltInCatalogIfNeeded() async {}

  @override
  List<Deck> getDecks() => List.of(decks);

  @override
  VocabularyEntry? getVocabulary(String id) => entries[id];

  @override
  List<VocabularyEntry> getVocabularyBatch(Iterable<String> ids) =>
      ids.map((id) => entries[id]).whereType<VocabularyEntry>().toList();

  @override
  List<VocabularyEntry> searchVocabulary(String query, {int limit = 100}) =>
      entries.values.take(limit).toList();

  @override
  LearningState? getLearningState(String vocabularyId) => states[vocabularyId];

  @override
  List<LearningState> getLearningStates() => states.values.toList();

  @override
  Future<void> saveLearningState(LearningState state) async {
    states[state.vocabularyId] = state;
  }

  @override
  List<ReviewRecord> getReviewRecords() => List.of(records);

  @override
  Future<void> saveReviewRecord(ReviewRecord record) async {
    records.add(record);
  }

  @override
  Future<void> saveReviewSession(ReviewSession session) async {
    sessions[session.id] = session;
  }

  @override
  StudySettings getSettings() => settings;

  @override
  Future<void> saveSettings(StudySettings value) async {
    settings = value;
  }

  @override
  Future<void> setDeckActive(String deckId, bool active) async {
    final index = decks.indexWhere((deck) => deck.id == deckId);
    decks[index] = decks[index].copyWith(isActive: active);
  }

  @override
  Future<void> importDeck(Deck deck, List<VocabularyEntry> values) async {
    decks.add(deck);
    entries.addAll({for (final entry in values) entry.id: entry});
  }
}
