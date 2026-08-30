import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/models.dart';
import 'review_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final today = controller.today;
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text('Grasp', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              '今天要練什麼？',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'TODAY',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _PlanNumber(
                            value: today.reviewCount,
                            label: '到期複習',
                          ),
                        ),
                        Container(width: 1, height: 54, color: Colors.white24),
                        Expanded(
                          child: _PlanNumber(
                            value: today.newCount,
                            label: '新單字',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: today.plannedCount == 0
                          ? null
                          : () async {
                              await controller.startTodaySession();
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ReviewScreen(controller: controller),
                                ),
                              );
                              await controller.refresh();
                            },
                      child: Text(today.plannedCount == 0 ? '今天完成了' : '開始應用複習'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '記住，還要用得出來',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '複習會從字義辨認，逐步進到英文回想、語境填空、搭配與造句。'
                      'FSRS 決定何時複習，題型則確認你能不能在句子裡真正使用。',
                      style: TextStyle(
                        height: 1.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '學習進度',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _Metric(
                          value: '${today.completedToday}',
                          label: '今日完成',
                        ),
                        _Metric(value: '${today.learnedCount}', label: '已學單字'),
                        _Metric(
                          value: today.learnedCount == 0
                              ? '—'
                              : '${(today.retention * 100).round()}%',
                          label: '預估記憶率',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (controller.application.attempts > 0) ...[
              const SizedBox(height: 16),
              _ApplicationFeedback(
                snapshot: controller.application,
                mistakes: controller.recentMistakes,
              ),
            ],
            if (today.streak > 0) ...[
              const SizedBox(height: 12),
              Text(
                '連續 ${today.streak} 天 · 保持規律就好，不必追求使用時數。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ApplicationFeedback extends StatelessWidget {
  const _ApplicationFeedback({required this.snapshot, required this.mistakes});

  final ApplicationSnapshot snapshot;
  final List<RecentMistake> mistakes;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近 50 題應用表現',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric(
                value: '${(snapshot.accuracy * 100).round()}%',
                label: '第一次答對',
              ),
              _Metric(
                value: '${snapshot.averageResponseSeconds}s',
                label: '平均反應',
              ),
              _Metric(
                value: _questionLabel(snapshot.weakestQuestionType),
                label: '優先加強',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '只計第一次作答；看完答案才想起來，不會算答對。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (mistakes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              '最近需要再整理',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final mistake in mistakes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        mistake.entry.word,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        mistake.record.response.isEmpty
                            ? _questionLabel(mistake.record.questionType)
                            : '第一次：${mistake.record.response}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class _PlanNumber extends StatelessWidget {
  const _PlanNumber({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$value',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70)),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

String _questionLabel(ReviewQuestionType? type) => switch (type) {
  ReviewQuestionType.recall => '回想',
  ReviewQuestionType.cloze => '語境',
  ReviewQuestionType.meaningDiscrimination => '詞義',
  ReviewQuestionType.usage => '搭配',
  ReviewQuestionType.production => '造句',
  ReviewQuestionType.recognition || null => '—',
};
