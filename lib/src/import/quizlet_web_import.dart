import 'dart:convert';

class QuizletWebCard {
  const QuizletWebCard({required this.term, required this.definition});

  final String term;
  final String definition;
}

class QuizletWebCapture {
  const QuizletWebCapture({
    required this.sourceUrl,
    required this.title,
    required this.cards,
  });

  final String sourceUrl;
  final String title;
  final List<QuizletWebCard> cards;

  factory QuizletWebCapture.fromJavaScriptResult(Object result) {
    var encoded = result is String ? result : result.toString();
    if (encoded.startsWith('"') && encoded.endsWith('"')) {
      try {
        final outer = jsonDecode(encoded);
        if (outer is String) encoded = outer;
      } catch (_) {
        // Some WebView implementations already return an unquoted String.
      }
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(Uri.decodeComponent(encoded));
      if (decoded is! Map) throw const FormatException();
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw const FormatException('無法讀取 Quizlet 頁面資料，請重新載入後再試。');
    }

    final seen = <String>{};
    final cards = <QuizletWebCard>[];
    final rawCards = payload['cards'];
    if (rawCards is List) {
      for (final raw in rawCards.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final term = item['term']?.toString().trim() ?? '';
        final definition = item['definition']?.toString().trim() ?? '';
        final key = '${term.toLowerCase()}\n${definition.toLowerCase()}';
        if (term.isEmpty || definition.isEmpty || !seen.add(key)) continue;
        cards.add(QuizletWebCard(term: term, definition: definition));
      }
    }
    if (cards.isEmpty) {
      throw const FormatException('這個頁面沒有找到可匯入的單字。請確認單字集已完整載入並展開。');
    }

    final title = payload['title']?.toString().trim() ?? '';
    return QuizletWebCapture(
      sourceUrl: payload['sourceUrl']?.toString().trim() ?? '',
      title: title.isEmpty ? 'Quizlet 單字集' : title,
      cards: cards,
    );
  }

  String toImporterJson() => jsonEncode({
    'cards': cards
        .map((card) => {'term': card.term, 'definition': card.definition})
        .toList(growable: false),
  });
}

class QuizletSetUrl {
  const QuizletSetUrl._();

  static Uri parse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      throw const FormatException('請貼上 Quizlet 單字集網址。');
    }
    if (!value.contains('://')) value = 'https://$value';
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        parsed.host.isEmpty ||
        !_isQuizletHost(parsed.host) ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasPort) {
      throw const FormatException('只支援 quizlet.com 的單字集網址。');
    }
    if (!parsed.pathSegments.any(
      (segment) => RegExp(r'^\d+$').hasMatch(segment),
    )) {
      throw const FormatException('這看起來不是 Quizlet 單字集網址。');
    }
    return parsed.replace(scheme: 'https');
  }

  static bool isAllowedNavigation(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    if (raw == 'about:blank') return true;
    return uri.scheme == 'https' &&
        (_isQuizletHost(uri.host) ||
            uri.host.toLowerCase() == 'challenges.cloudflare.com');
  }

  static bool _isQuizletHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'quizlet.com' || normalized.endsWith('.quizlet.com');
  }
}

/// Runs inside the user-visible Quizlet WebView after the page has loaded.
/// It reads page state or visible cards only; it does not bypass authentication
/// or make requests to a private Quizlet API.
const quizletScrapeScript = r'''
(function() {
  var cards = [];
  var seen = {};
  var title = '';

  function text(value) {
    if (value == null) return '';
    if (typeof value === 'string' || typeof value === 'number') {
      return String(value).trim();
    }
    if (Array.isArray(value)) {
      return value.map(text).filter(Boolean).join(' ').trim();
    }
    if (typeof value === 'object') {
      var keys = ['plainText', 'text', 'word', 'value', 'label', 'name'];
      for (var i = 0; i < keys.length; i++) {
        if (value[keys[i]] != null) {
          var result = text(value[keys[i]]);
          if (result) return result;
        }
      }
      if (value.richText != null) return text(value.richText);
    }
    return '';
  }

  function add(term, definition) {
    term = text(term);
    definition = text(definition);
    if (!term || !definition) return;
    var key = term.toLowerCase() + '\n' + definition.toLowerCase();
    if (seen[key]) return;
    seen[key] = true;
    cards.push({term: term, definition: definition});
  }

  function readCard(item) {
    if (!item || typeof item !== 'object') return;
    var term = text(item.termText || item.term || item.word || item.left);
    var definition = text(
      item.definitionText || item.definition || item.meaning || item.right
    );
    if ((!term || !definition) && Array.isArray(item.cardSides) && item.cardSides.length >= 2) {
      term = term || text(item.cardSides[0]);
      definition = definition || text(item.cardSides[1]);
    }
    if ((!term || !definition) && Array.isArray(item.sides) && item.sides.length >= 2) {
      term = term || text(item.sides[0]);
      definition = definition || text(item.sides[1]);
    }
    add(term, definition);
  }

  function walk(value, depth) {
    if (depth > 9 || value == null || typeof value !== 'object') return;
    if (Array.isArray(value)) {
      value.forEach(function(item) {
        readCard(item);
        walk(item, depth + 1);
      });
      return;
    }
    readCard(value);
    Object.keys(value).forEach(function(key) {
      walk(value[key], depth + 1);
    });
  }

  try {
    var nextData = document.getElementById('__NEXT_DATA__');
    if (nextData && nextData.textContent) {
      var parsed = JSON.parse(nextData.textContent);
      var pageProps = parsed.props && parsed.props.pageProps;
      if (pageProps && pageProps.dehydratedReduxStateKey) {
        var state = JSON.parse(pageProps.dehydratedReduxStateKey);
        if (state.setPage && state.setPage.set && state.setPage.set.title) {
          title = text(state.setPage.set.title);
        }
        var setPage = state.setPage;
        var terms = setPage && setPage.set && Array.isArray(setPage.set.terms)
          ? setPage.set.terms
          : (setPage && Array.isArray(setPage.terms) ? setPage.terms : []);
        walk(terms, 0);
        if (!cards.length) walk(state.cards, 0);
        if (!cards.length) walk(state.studiableData, 0);
      } else {
        var source = pageProps && (
          pageProps.studySet || pageProps.set || pageProps.terms || pageProps.studiableData
        );
        walk(source, 0);
      }
    }
  } catch (_) {}

  if (!cards.length) {
    var containers = document.querySelectorAll(
      '[class*="SetPageTerm"], .SetPageTerms-term, .SetPageTerm-content'
    );
    containers.forEach(function(container) {
      var nodes = container.querySelectorAll('.TermText, [data-testid="TextContent"]');
      if (nodes.length >= 2) add(nodes[0].innerText, nodes[1].innerText);
    });
  }

  if (!cards.length) {
    var nodes = document.querySelectorAll('.TermText, [data-testid="TextContent"]');
    for (var index = 0; index + 1 < nodes.length; index += 2) {
      add(nodes[index].innerText, nodes[index + 1].innerText);
    }
  }

  if (!title) {
    var heading = document.querySelector(
      '.SetPage-titleWrapper h1, [data-testid="set-title"], .UIHeading--one, h1'
    );
    title = heading ? heading.innerText.trim() : document.title.replace(/ Flashcards.*$/i, '').trim();
  }

  return encodeURIComponent(JSON.stringify({
    sourceUrl: location.href,
    title: title,
    cards: cards
  }));
})();
''';

const quizletExpandCardsScript = r'''
(function() {
  var clicked = 0;
  var patterns = ['顯示更多', '載入更多', 'show more', 'see more', 'load more'];
  document.querySelectorAll('button, [role="button"]').forEach(function(node) {
    var label = (node.innerText || node.textContent || '').trim().toLowerCase();
    if (patterns.some(function(pattern) { return label.indexOf(pattern) !== -1; })) {
      try { node.click(); clicked++; } catch (_) {}
    }
  });
  var height = Math.max(
    document.body ? document.body.scrollHeight : 0,
    document.documentElement ? document.documentElement.scrollHeight : 0
  );
  window.scrollTo(0, height);
  var visible = document.querySelectorAll(
    '.TermText, [data-testid="TextContent"], [class*="SetPageTerm"]'
  ).length;
  return String(clicked) + '|' + String(visible);
})();
''';
