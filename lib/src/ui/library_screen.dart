import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../domain/models.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '單字庫',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '只啟用你現在要學的單字集。FSRS 會跨單字集管理同一個單字的記憶狀態。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: controller.searchLibrary,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: '搜尋英文或中文意思',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '單字集',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverList.builder(
          itemCount: controller.decks.length,
          itemBuilder: (context, index) {
            final deck = controller.decks[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Card(
                child: SwitchListTile(
                  value: deck.isActive,
                  onChanged: (value) =>
                      controller.setDeckActive(deck.id, value),
                  title: Text(
                    deck.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${deck.vocabularyIds.length} 字 · ${_source(deck.source)}',
                  ),
                  secondary: Icon(
                    deck.source == DeckSource.builtIn
                        ? Icons.school_outlined
                        : Icons.file_download_outlined,
                  ),
                ),
              ),
            );
          },
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          sliver: SliverToBoxAdapter(
            child: Text(
              '單字',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: controller.libraryResults.length,
          itemBuilder: (context, index) {
            final entry = controller.libraryResults[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(
                entry.word,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(entry.primarySense.definitionZh),
              trailing: entry.level == null
                  ? null
                  : Text(
                      'L${entry.level}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => _WordDetails(entry: entry),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    ),
  );
}

class _WordDetails extends StatelessWidget {
  const _WordDetails({required this.entry});
  final VocabularyEntry entry;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.65,
    maxChildSize: 0.9,
    builder: (context, scrollController) => ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(
          entry.word,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (entry.lemma != entry.word.toLowerCase()) Text(entry.lemma),
        const SizedBox(height: 18),
        for (final sense in entry.senses) ...[
          Text(
            [
              sense.partOfSpeech,
              sense.definitionZh,
            ].where((item) => item.isNotEmpty).join(' '),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          for (final example in sense.examples) ...[
            const SizedBox(height: 8),
            Text(
              example.sentence,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            if (example.translationZh.isNotEmpty) Text(example.translationZh),
          ],
          const SizedBox(height: 14),
        ],
        if (entry.collocations.isNotEmpty)
          _DetailSection(title: '常見搭配', body: entry.collocations.join(' · ')),
        if (entry.synonyms.isNotEmpty)
          _DetailSection(
            title: '近義字',
            body: entry.synonyms
                .map(
                  (item) => item.noteZh.isEmpty
                      ? item.word
                      : '${item.word}：${item.noteZh}',
                )
                .join('\n'),
          ),
        if (entry.confusingWords.isNotEmpty)
          _DetailSection(
            title: '易混淆',
            body: entry.confusingWords
                .map((item) => '${item.word}：${item.noteZh}')
                .join('\n'),
          ),
        if (entry.wordFamily.isNotEmpty)
          _DetailSection(
            title: 'Word family',
            body: entry.wordFamily
                .map(
                  (item) =>
                      '${item.word} (${item.partOfSpeech}) ${item.meaningZh}',
                )
                .join('\n'),
          ),
      ],
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        Text(body, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}

String _source(DeckSource source) => switch (source) {
  DeckSource.builtIn => '內建學測字庫',
  DeckSource.quizlet => 'Quizlet',
  DeckSource.custom => '自訂',
};
