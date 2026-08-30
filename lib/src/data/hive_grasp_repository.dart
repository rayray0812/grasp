import 'package:hive_flutter/hive_flutter.dart';

import '../domain/models.dart';
import 'builtin_catalog_loader.dart';
import 'grasp_repository.dart';

class HiveGraspRepository implements GraspRepository {
  HiveGraspRepository({BuiltInCatalogLoader? catalogLoader})
    : _catalogLoader = catalogLoader ?? const BuiltInCatalogLoader();

  static const _vocabularyBoxName = 'grasp_v2_vocabulary';
  static const _learningBoxName = 'grasp_v2_learning_states';
  static const _reviewBoxName = 'grasp_v2_review_records';
  static const _deckBoxName = 'grasp_v2_decks';
  static const _sessionBoxName = 'grasp_v2_review_sessions';
  static const _settingsBoxName = 'grasp_v2_settings';

  final BuiltInCatalogLoader _catalogLoader;
  late Box<dynamic> _vocabulary;
  late Box<dynamic> _learning;
  late Box<dynamic> _reviews;
  late Box<dynamic> _decks;
  late Box<dynamic> _sessions;
  late Box<dynamic> _settings;

  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
    _vocabulary = await Hive.openBox<dynamic>(_vocabularyBoxName);
    _learning = await Hive.openBox<dynamic>(_learningBoxName);
    _reviews = await Hive.openBox<dynamic>(_reviewBoxName);
    _decks = await Hive.openBox<dynamic>(_deckBoxName);
    _sessions = await Hive.openBox<dynamic>(_sessionBoxName);
    _settings = await Hive.openBox<dynamic>(_settingsBoxName);
  }

  @override
  Future<void> seedBuiltInCatalogIfNeeded() async {
    if (_settings.get('builtinCatalogVersion') == 3) return;
    final catalog = await _catalogLoader.load();
    await _vocabulary.putAll({
      for (final entry in catalog.entries) entry.id: entry.toJson(),
    });
    for (final deck in catalog.decks) {
      final existing = _decks.get(deck.id);
      if (existing is Map) {
        final current = Deck.fromJson(Map<String, dynamic>.from(existing));
        await _decks.put(
          deck.id,
          deck.copyWith(isActive: current.isActive).toJson(),
        );
      } else {
        await _decks.put(deck.id, deck.toJson());
      }
    }
    await _settings.put('builtinCatalogVersion', 3);
  }

  @override
  List<Deck> getDecks() =>
      _decks.values
          .whereType<Map>()
          .map((raw) => Deck.fromJson(Map<String, dynamic>.from(raw)))
          .toList(growable: false)
        ..sort((a, b) {
          if (a.source != b.source) {
            return a.source.index.compareTo(b.source.index);
          }
          return a.createdAt.compareTo(b.createdAt);
        });

  @override
  VocabularyEntry? getVocabulary(String id) {
    final raw = _vocabulary.get(id);
    return raw is Map
        ? VocabularyEntry.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  @override
  List<VocabularyEntry> getVocabularyBatch(Iterable<String> ids) => ids
      .map(getVocabulary)
      .whereType<VocabularyEntry>()
      .toList(growable: false);

  @override
  List<VocabularyEntry> searchVocabulary(String query, {int limit = 100}) {
    final needle = query.trim().toLowerCase();
    final results = <VocabularyEntry>[];
    for (final raw in _vocabulary.values.whereType<Map>()) {
      final entry = VocabularyEntry.fromJson(Map<String, dynamic>.from(raw));
      if (needle.isEmpty ||
          entry.word.toLowerCase().contains(needle) ||
          entry.senses.any((sense) => sense.definitionZh.contains(needle))) {
        results.add(entry);
      }
      if (results.length >= limit) break;
    }
    return results;
  }

  @override
  LearningState? getLearningState(String vocabularyId) {
    final raw = _learning.get(vocabularyId);
    return raw is Map
        ? LearningState.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  @override
  List<LearningState> getLearningStates() => _learning.values
      .whereType<Map>()
      .map((raw) => LearningState.fromJson(Map<String, dynamic>.from(raw)))
      .toList(growable: false);

  @override
  Future<void> saveLearningState(LearningState state) =>
      _learning.put(state.vocabularyId, state.toJson());

  @override
  List<ReviewRecord> getReviewRecords() => _reviews.values
      .whereType<Map>()
      .map((raw) => ReviewRecord.fromJson(Map<String, dynamic>.from(raw)))
      .toList(growable: false);

  @override
  Future<void> saveReviewRecord(ReviewRecord record) =>
      _reviews.put(record.id, record.toJson());

  @override
  Future<void> saveReviewSession(ReviewSession session) =>
      _sessions.put(session.id, session.toJson());

  @override
  StudySettings getSettings() {
    final raw = _settings.get('studySettings');
    return raw is Map
        ? StudySettings.fromJson(Map<String, dynamic>.from(raw))
        : const StudySettings();
  }

  @override
  Future<void> saveSettings(StudySettings settings) =>
      _settings.put('studySettings', settings.toJson());

  @override
  Future<void> setDeckActive(String deckId, bool active) async {
    final raw = _decks.get(deckId);
    if (raw is! Map) return;
    final deck = Deck.fromJson(Map<String, dynamic>.from(raw));
    await _decks.put(deckId, deck.copyWith(isActive: active).toJson());
  }

  @override
  Future<void> importDeck(Deck deck, List<VocabularyEntry> entries) async {
    await _vocabulary.putAll({
      for (final entry in entries) entry.id: entry.toJson(),
    });
    await _decks.put(deck.id, deck.toJson());
  }
}
