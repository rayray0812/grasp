import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grasp_app/src/import/quizlet_importer.dart';
import 'package:grasp_app/src/import/quizlet_web_import.dart';

void main() {
  group('QuizletSetUrl', () {
    test('normalizes a Quizlet set URL to HTTPS', () {
      final uri = QuizletSetUrl.parse(
        'quizlet.com/tw/123456789/gsat-words-flash-cards/',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'quizlet.com');
      expect(uri.path, contains('123456789'));
    });

    test('rejects non-Quizlet and non-set URLs', () {
      expect(
        () => QuizletSetUrl.parse('https://evilquizlet.com/123/cards'),
        throwsFormatException,
      );
      expect(
        () => QuizletSetUrl.parse('https://quizlet.com/latest'),
        throwsFormatException,
      );
    });

    test('navigation allowlist cannot be bypassed by a lookalike host', () {
      expect(
        QuizletSetUrl.isAllowedNavigation('https://accounts.quizlet.com/login'),
        isTrue,
      );
      expect(
        QuizletSetUrl.isAllowedNavigation(
          'https://quizlet.com.attacker.example/123',
        ),
        isFalse,
      );
      expect(
        QuizletSetUrl.isAllowedNavigation(
          'https://challenges.cloudflare.com/cdn-cgi/challenge-platform/',
        ),
        isTrue,
      );
      expect(
        QuizletSetUrl.isAllowedNavigation('data:text/html,not-quizlet'),
        isFalse,
      );
    });
  });

  group('QuizletWebCapture', () {
    final payload = {
      'sourceUrl': 'https://quizlet.com/123/example-flash-cards/',
      'title': '學測核心字彙',
      'cards': [
        {'term': 'affect', 'definition': '影響'},
        {'term': 'respond', 'definition': '回應'},
        {'term': 'affect', 'definition': '影響'},
        {'term': '', 'definition': '忽略'},
      ],
    };

    test('decodes WebView output and removes duplicate cards', () {
      final encoded = Uri.encodeComponent(jsonEncode(payload));
      final capture = QuizletWebCapture.fromJavaScriptResult(
        jsonEncode(encoded),
      );

      expect(capture.title, '學測核心字彙');
      expect(capture.cards, hasLength(2));
      expect(capture.cards.first.term, 'affect');
    });

    test('feeds captured cards into the unified vocabulary importer', () {
      final capture = QuizletWebCapture.fromJavaScriptResult(
        Uri.encodeComponent(jsonEncode(payload)),
      );
      final result = const QuizletImporter().parse(
        raw: capture.toImporterJson(),
        title: capture.title,
        sourceUrl: capture.sourceUrl,
        now: DateTime.utc(2026, 9, 4),
      );

      expect(result.deck.title, '學測核心字彙');
      expect(result.entries, hasLength(2));
      expect(result.entries.first.source, 'Quizlet import');
      expect(result.deck.description, contains('quizlet.com/123'));
    });

    test('rejects captures without usable term-definition pairs', () {
      final encoded = Uri.encodeComponent(
        jsonEncode({'title': 'empty', 'cards': <Object>[]}),
      );
      expect(
        () => QuizletWebCapture.fromJavaScriptResult(encoded),
        throwsFormatException,
      );
    });
  });
}
