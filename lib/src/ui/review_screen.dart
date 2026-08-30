import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/models.dart';
import '../review/review_engine.dart';

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
                          if (prompt.instruction.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              prompt.instruction,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                          ],
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
                          if (prompt.needsTypedResponse &&
                              !controller.isAnswerRevealed) ...[
                            const SizedBox(height: 24),
                            TextField(
                              key: ValueKey(
                                '${prompt.vocabularyId}-${prompt.type.name}',
                              ),
                              minLines:
                                  prompt.responseMode ==
                                      ReviewResponseMode.typedSelfCheck
                                  ? 3
                                  : 1,
                              maxLines:
                                  prompt.responseMode ==
                                      ReviewResponseMode.typedSelfCheck
                                  ? 5
                                  : 1,
                              autocorrect: false,
                              textInputAction:
                                  prompt.responseMode ==
                                      ReviewResponseMode.typedSelfCheck
                                  ? TextInputAction.newline
                                  : TextInputAction.done,
                              decoration: InputDecoration(
                                labelText:
                                    prompt.responseMode ==
                                        ReviewResponseMode.typedSelfCheck
                                    ? '你的英文句子'
                                    : '輸入英文答案',
                                hintText:
                                    prompt.responseMode ==
                                        ReviewResponseMode.typedSelfCheck
                                    ? 'Write one complete sentence.'
                                    : null,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: controller.setCurrentResponse,
                              onSubmitted:
                                  prompt.responseMode ==
                                      ReviewResponseMode.typedExact
                                  ? (_) => controller.submitCurrentResponse()
                                  : null,
                            ),
                          ],
                          if (controller.isAnswerRevealed) ...[
                            const SizedBox(height: 28),
                            const Divider(),
                            const SizedBox(height: 22),
                            if (prompt.needsTypedResponse) ...[
                              _ResponseResult(
                                response: controller.currentResponse,
                                correct: controller.currentResponseIsCorrect,
                              ),
                              const SizedBox(height: 18),
                            ],
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
                            if (prompt.selfCheckItems.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                '請依第一次寫出的句子檢核：',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              for (final item in prompt.selfCheckItems)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('□  '),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: const TextStyle(height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
                if (!controller.isAnswerRevealed && !prompt.needsTypedResponse)
                  FilledButton(
                    onPressed: controller.revealAnswer,
                    child: const Text('顯示答案'),
                  )
                else if (!controller.isAnswerRevealed)
                  FilledButton(
                    onPressed: controller.currentResponse.trim().isEmpty
                        ? null
                        : controller.submitCurrentResponse,
                    child: Text(
                      prompt.responseMode == ReviewResponseMode.typedSelfCheck
                          ? '完成，開始檢核'
                          : '檢查答案',
                    ),
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

class _ResponseResult extends StatelessWidget {
  const _ResponseResult({required this.response, required this.correct});

  final String response;
  final bool? correct;

  @override
  Widget build(BuildContext context) {
    final color = switch (correct) {
      true => Colors.green.shade700,
      false => Theme.of(context).colorScheme.error,
      null => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    final label = switch (correct) {
      true => '第一次作答正確',
      false => '第一次作答不正確',
      null => '你的第一次作答',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(response, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
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
          '依照第一次作答評分，不要看完答案後改分。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        Row(
          children: ReviewRating.values.map((rating) {
            final label = switch (rating) {
              ReviewRating.again => '答錯',
              ReviewRating.hard => '勉強',
              ReviewRating.good => '正確',
              ReviewRating.easy => '秒答',
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
