import 'package:flutter_test/flutter_test.dart';
import 'package:grasp_app/src/domain/models.dart';
import 'package:grasp_app/src/learning/fsrs_scheduler.dart';

void main() {
  group('FsrsScheduler', () {
    final now = DateTime.utc(2026, 8, 30, 8);

    test('schedules a new word and persists FSRS fields', () {
      final scheduler = FsrsScheduler(enableFuzzing: false);
      final result = scheduler.review(
        state: const LearningState(vocabularyId: 'substantial'),
        rating: ReviewRating.good,
        reviewedAt: now,
      );

      expect(result.state.repetitions, 1);
      expect(result.state.stability, greaterThan(0));
      expect(result.state.difficulty, greaterThan(0));
      expect(result.state.lastReview, now);
      expect(result.state.due!.isAfter(now), isTrue);
      expect(result.retrievabilityBeforeReview, 0);
    });

    test('again records a lapse without resetting content identity', () {
      final scheduler = FsrsScheduler(enableFuzzing: false);
      final first = scheduler.review(
        state: const LearningState(vocabularyId: 'respond'),
        rating: ReviewRating.easy,
        reviewedAt: now,
      );
      final second = scheduler.review(
        state: first.state,
        rating: ReviewRating.again,
        reviewedAt: first.state.due!,
      );

      expect(second.state.vocabularyId, 'respond');
      expect(second.state.repetitions, 2);
      expect(second.state.lapses, 1);
      expect(second.retrievabilityBeforeReview, inInclusiveRange(0, 1));
    });

    test('stable card ids do not depend on runtime hashCode', () {
      expect(
        FsrsScheduler.stableCardId('gsat-word-affect'),
        FsrsScheduler.stableCardId('gsat-word-affect'),
      );
      expect(
        FsrsScheduler.stableCardId('gsat-word-affect'),
        isNot(FsrsScheduler.stableCardId('gsat-word-effect')),
      );
    });
  });
}
