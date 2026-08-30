import '../domain/models.dart';

abstract class GraspRepository {
  Future<void> initialize();
  Future<void> seedBuiltInCatalogIfNeeded();

  List<Deck> getDecks();
  VocabularyEntry? getVocabulary(String id);
  List<VocabularyEntry> getVocabularyBatch(Iterable<String> ids);
  List<VocabularyEntry> searchVocabulary(String query, {int limit = 100});

  LearningState? getLearningState(String vocabularyId);
  List<LearningState> getLearningStates();
  Future<void> saveLearningState(LearningState state);

  List<ReviewRecord> getReviewRecords();
  Future<void> saveReviewRecord(ReviewRecord record);
  Future<void> saveReviewSession(ReviewSession session);

  StudySettings getSettings();
  Future<void> saveSettings(StudySettings settings);
  Future<void> setDeckActive(String deckId, bool active);
  Future<void> importDeck(Deck deck, List<VocabularyEntry> entries);
}
