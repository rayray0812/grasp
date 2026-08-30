import 'package:fsrs/fsrs.dart' as fsrs;

import '../domain/models.dart';

class SchedulingResult {
  const SchedulingResult({
    required this.state,
    required this.retrievabilityBeforeReview,
  });

  final LearningState state;
  final double retrievabilityBeforeReview;
}

/// The only module that knows about the FSRS package.
///
/// Review screens report a four-grade recall result. This adapter converts it
/// into an FSRS state transition; it never decides which question to show.
class FsrsScheduler {
  FsrsScheduler({double desiredRetention = 0.9, bool enableFuzzing = true})
    : _scheduler = fsrs.Scheduler(
        desiredRetention: desiredRetention,
        enableFuzzing: enableFuzzing,
      );

  final fsrs.Scheduler _scheduler;

  SchedulingResult review({
    required LearningState state,
    required ReviewRating rating,
    required DateTime reviewedAt,
  }) {
    final now = reviewedAt.toUtc();
    final card = _toCard(state, now);
    final retrievability = state.isNew
        ? 0.0
        : _scheduler.getCardRetrievability(card, currentDateTime: now);
    final result = _scheduler.reviewCard(
      card,
      fsrs.Rating.fromValue(rating.value),
      reviewDateTime: now,
    );
    final updated = result.card;
    return SchedulingResult(
      state: LearningState(
        vocabularyId: state.vocabularyId,
        stability: updated.stability ?? 0,
        difficulty: updated.difficulty ?? 0,
        repetitions: state.repetitions + 1,
        lapses: state.lapses + (rating == ReviewRating.again ? 1 : 0),
        fsrsState: updated.state.value,
        step: updated.step,
        lastReview: now,
        due: updated.due,
      ),
      retrievabilityBeforeReview: retrievability.clamp(0, 1),
    );
  }

  double retrievability(LearningState state, DateTime now) {
    if (state.isNew || state.lastReview == null || state.stability <= 0) {
      return 0;
    }
    return _scheduler
        .getCardRetrievability(
          _toCard(state, now.toUtc()),
          currentDateTime: now.toUtc(),
        )
        .clamp(0, 1);
  }

  Map<ReviewRating, DateTime> preview(
    LearningState state,
    DateTime reviewedAt,
  ) {
    final now = reviewedAt.toUtc();
    return {
      for (final rating in ReviewRating.values)
        rating: _scheduler
            .reviewCard(
              _toCard(state, now),
              fsrs.Rating.fromValue(rating.value),
              reviewDateTime: now,
            )
            .card
            .due,
    };
  }

  fsrs.Card _toCard(LearningState state, DateTime now) {
    if (state.isNew || state.fsrsState == 0 || state.lastReview == null) {
      return fsrs.Card(
        cardId: stableCardId(state.vocabularyId),
        state: fsrs.State.learning,
        step: 0,
        due: now,
      );
    }
    final packageState = fsrs.State.fromValue(state.fsrsState);
    return fsrs.Card(
      cardId: stableCardId(state.vocabularyId),
      state: packageState,
      step: packageState == fsrs.State.review ? null : (state.step ?? 0),
      stability: state.stability,
      difficulty: state.difficulty,
      due: state.due ?? now,
      lastReview: state.lastReview,
    );
  }

  /// Stable 31-bit FNV-1a hash. Dart's String.hashCode is not stable across
  /// platforms and must not be persisted as an FSRS card identifier.
  static int stableCardId(String value) {
    const offsetBasis = 0x811C9DC5;
    const fnvPrime = 0x01000193;
    var hash = offsetBasis;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
