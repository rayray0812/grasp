import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/models.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.isSessionComplete) {
        return _SessionComplete(controller: controller);
      }
      final prompt = controller.currentPrompt;
      if (prompt == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('今天沒有需要複習的單字。')),
        );
      }
      final progress = controller.sessionTotal == 0
          ? 0.0
          : controller.sessionCompleted / controller.sessionTotal;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '${controller.sessionCompleted + 1} / ${controller.sessionTotal}',
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: progress),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Card(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prompt.eyebrow.toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            prompt.prompt,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                          ),
                          if (prompt.context.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              prompt.context,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                          if (controller.isAnswerRevealed) ...[
                            const SizedBox(height: 28),
                            const Divider(),
                            const SizedBox(height: 22),
                            Text(
                              prompt.answer,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            for (final detail in prompt.supportingDetails) ...[
                              const SizedBox(height: 12),
                              Text(
                                detail,
                                style: const TextStyle(height: 1.45),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!controller.isAnswerRevealed)
                  FilledButton(
                    onPressed: controller.revealAnswer,
                    child: const Text('顯示答案'),
                  )
                else
                  _RatingBar(controller: controller),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.currentSchedulingPreview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '你剛才回想得如何？',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        Row(
          children: ReviewRating.values.map((rating) {
            final label = switch (rating) {
              ReviewRating.again => '忘記',
              ReviewRating.hard => '困難',
              ReviewRating.good => '記得',
              ReviewRating.easy => '簡單',
            };
            final due = preview[rating];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OutlinedButton(
                  onPressed: () => controller.rateCurrent(rating),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: rating == ReviewRating.again
                          ? Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.5)
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        due == null
                            ? ''
                            : _interval(due.difference(DateTime.now().toUtc())),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SessionComplete extends StatelessWidget {
  const _SessionComplete({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 68,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                '今天的學習完成',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '完成 ${controller.sessionTotal} 個單字 · '
                '${controller.sessionAgainCount} 個需要再加強',
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('回到 Today'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _interval(Duration duration) {
  if (duration.inDays >= 1) return '${duration.inDays}天';
  if (duration.inHours >= 1) return '${duration.inHours}小時';
  final minutes = duration.inMinutes.clamp(1, 59);
  return '$minutes分';
}
