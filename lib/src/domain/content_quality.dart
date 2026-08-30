import 'models.dart';

enum ApplicationContentDepth { recallOnly, context, usage, fullApplication }

class VocabularyContentQuality {
  const VocabularyContentQuality({
    required this.depth,
    required this.hasExample,
    required this.hasMultipleMeanings,
    required this.hasCollocation,
    required this.hasLexicalRelations,
    required this.hasWordFamily,
  });

  final ApplicationContentDepth depth;
  final bool hasExample;
  final bool hasMultipleMeanings;
  final bool hasCollocation;
  final bool hasLexicalRelations;
  final bool hasWordFamily;

  bool get isApplicationReady =>
      depth == ApplicationContentDepth.fullApplication;

  List<String> get labels => [
    if (hasExample) '語境',
    if (hasMultipleMeanings) '多義',
    if (hasCollocation) '搭配',
    if (hasLexicalRelations) '辨析',
    if (hasWordFamily) '字族',
  ];
}

extension VocabularyContentQualityX on VocabularyEntry {
  VocabularyContentQuality get contentQuality {
    final hasExample = senses.any((sense) => sense.examples.isNotEmpty);
    final hasMultipleMeanings = senses.length > 1;
    final hasCollocation = collocations.isNotEmpty;
    final hasLexicalRelations =
        synonyms.isNotEmpty || confusingWords.isNotEmpty;
    final hasWordFamily = wordFamily.isNotEmpty;
    final hasUsage = hasCollocation || hasLexicalRelations || hasWordFamily;
    final depth = switch ((hasExample || hasMultipleMeanings, hasUsage)) {
      (true, true) => ApplicationContentDepth.fullApplication,
      (true, false) => ApplicationContentDepth.context,
      (false, true) => ApplicationContentDepth.usage,
      (false, false) => ApplicationContentDepth.recallOnly,
    };
    return VocabularyContentQuality(
      depth: depth,
      hasExample: hasExample,
      hasMultipleMeanings: hasMultipleMeanings,
      hasCollocation: hasCollocation,
      hasLexicalRelations: hasLexicalRelations,
      hasWordFamily: hasWordFamily,
    );
  }
}
