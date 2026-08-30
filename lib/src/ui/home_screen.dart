import 'package:flutter/material.dart';

import '../app/app_controller.dart';
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
              '今天要背什麼？',
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
                            label: 'Reviews',
                          ),
                        ),
                        Container(width: 1, height: 54, color: Colors.white24),
                        Expanded(
                          child: _PlanNumber(
                            value: today.newCount,
                            label: 'New Words',
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
                      child: Text(today.plannedCount == 0 ? '今天完成了' : 'Start'),
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
