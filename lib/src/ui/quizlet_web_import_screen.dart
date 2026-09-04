import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../import/quizlet_web_import.dart';

class QuizletWebImportScreen extends StatefulWidget {
  const QuizletWebImportScreen({super.key, required this.initialUrl});

  final Uri initialUrl;

  @override
  State<QuizletWebImportScreen> createState() => _QuizletWebImportScreenState();
}

class _QuizletWebImportScreenState extends State<QuizletWebImportScreen> {
  late final WebViewController webViewController;
  bool pageLoading = true;
  bool scraping = false;
  String currentUrl = '';
  String? error;
  QuizletWebCapture? capture;

  @override
  void initState() {
    super.initState();
    currentUrl = widget.initialUrl.toString();
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (QuizletSetUrl.isAllowedNavigation(request.url)) {
              return NavigationDecision.navigate;
            }
            if (mounted) {
              setState(() => error = '為了安全，匯入視窗只允許開啟 Quizlet 與其驗證頁面。');
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              currentUrl = url;
              pageLoading = true;
              capture = null;
              error = null;
            });
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              currentUrl = url;
              pageLoading = false;
            });
          },
          onWebResourceError: (resourceError) {
            if (resourceError.isForMainFrame != true || !mounted) return;
            setState(() {
              pageLoading = false;
              error = 'Quizlet 頁面載入失敗，請檢查網路後重新載入。';
            });
          },
        ),
      )
      ..loadRequest(widget.initialUrl);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('從 Quizlet 網址匯入'),
      actions: [
        IconButton(
          onPressed: scraping ? null : webViewController.reload,
          tooltip: '重新載入',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      bottom: pageLoading
          ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(minHeight: 3),
            )
          : null,
    ),
    body: Stack(
      children: [
        Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => error = null),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            Expanded(child: WebViewWidget(controller: webViewController)),
            _BottomAction(
              capture: capture,
              busy: scraping,
              onScrape: _scrape,
              onImport: () => Navigator.of(context).pop(capture),
            ),
          ],
        ),
        if (scraping)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.18),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('正在展開並讀取單字…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _scrape() async {
    if (scraping || pageLoading) return;
    setState(() {
      scraping = true;
      error = null;
      capture = null;
    });
    try {
      await _expandLazyCards();
      final raw = await webViewController.runJavaScriptReturningResult(
        quizletScrapeScript,
      );
      final result = QuizletWebCapture.fromJavaScriptResult(raw);
      if (!mounted) return;
      setState(() => capture = result);
    } on FormatException catch (exception) {
      if (!mounted) return;
      setState(() => error = exception.message.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Quizlet 頁面讀取失敗。請確認頁面已載入，或稍後再試。';
      });
    } finally {
      if (mounted) setState(() => scraping = false);
    }
  }

  Future<void> _expandLazyCards() async {
    var previousVisible = -1;
    var stableRounds = 0;
    for (var round = 0; round < 12 && stableRounds < 3; round++) {
      final raw = await webViewController.runJavaScriptReturningResult(
        quizletExpandCardsScript,
      );
      final values = raw
          .toString()
          .replaceAll('"', '')
          .split('|')
          .map((value) => int.tryParse(value.trim()) ?? 0)
          .toList(growable: false);
      final clicked = values.isEmpty ? 0 : values.first;
      final visible = values.length < 2 ? 0 : values[1];
      if (visible == previousVisible && clicked == 0) {
        stableRounds++;
      } else {
        stableRounds = 0;
      }
      previousVisible = visible;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.capture,
    required this.busy,
    required this.onScrape,
    required this.onImport,
  });

  final QuizletWebCapture? capture;
  final bool busy;
  final VoidCallback onScrape;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: capture == null
          ? FilledButton.icon(
              onPressed: busy ? null : onScrape,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('抓取這個單字集'),
            )
          : Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      capture!.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('找到 ${capture!.cards.length} 個單字，確認後交給 FSRS 排程。'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onImport,
                      icon: const Icon(Icons.file_download_done_rounded),
                      label: Text('匯入 ${capture!.cards.length} 個單字'),
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}
