import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../import/quizlet_web_import.dart';
import 'quizlet_web_import_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final urlController = TextEditingController();
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  bool importing = false;
  bool urlImporting = false;

  bool get supportsWebView =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    urlController.dispose();
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
    children: [
      Text(
        'Quizlet Import',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        '貼上 Quizlet 單字集網址，Grasp 會開啟該頁並抓取單字。匯入後直接交給 FSRS 排程，不需要 AI 補完。',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '從 Quizlet 網址匯入',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                supportsWebView
                    ? '支援公開單字集；若頁面要求驗證，可在下一頁自行完成後再抓取。'
                    : '網址抓取目前支援 Android、iPhone 與 iPad App；此平台仍可使用下方文字匯入。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlController,
                enabled: !urlImporting,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Quizlet 單字集網址',
                  hintText: 'https://quizlet.com/123456789/...',
                  suffixIcon: IconButton(
                    onPressed: urlImporting ? null : _pasteUrl,
                    tooltip: '從剪貼簿貼上',
                    icon: const Icon(Icons.content_paste_rounded),
                  ),
                ),
                onSubmitted: (_) => _openUrlImporter(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: urlImporting ? null : _openUrlImporter,
                icon: urlImporting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_browser_rounded),
                label: const Text('開啟並抓取單字'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 26),
      Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '或貼上匯出內容',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: 22),
      TextField(
        controller: titleController,
        decoration: const InputDecoration(
          labelText: '單字集名稱',
          hintText: '例如：高三第一次模考',
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: contentController,
        minLines: 10,
        maxLines: 18,
        decoration: const InputDecoration(
          alignLabelWithHint: true,
          labelText: 'Quizlet 匯出內容',
          hintText: 'substantial\t大量的；可觀的\nrespond\t回應',
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (!mounted || data?.text == null) return;
            contentController.text = data!.text!;
          },
          icon: const Icon(Icons.content_paste_rounded),
          label: const Text('從剪貼簿貼上'),
        ),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: importing ? null : _import,
        icon: importing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.file_download_done_rounded),
        label: const Text('匯入單字集'),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '也支援舊版 Grasp importer JSON。缺少例句、詞性或搭配時會保持空白，不會強迫呼叫 AI。',
                  style: TextStyle(height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    urlController.text = data!.text!.trim();
  }

  Future<void> _openUrlImporter() async {
    if (urlImporting) return;
    Uri uri;
    try {
      uri = QuizletSetUrl.parse(urlController.text);
    } on FormatException catch (exception) {
      _showMessage(exception.message.toString());
      return;
    }
    if (!supportsWebView) {
      _showMessage('網址抓取目前支援 Android、iPhone 與 iPad App。');
      return;
    }

    setState(() => urlImporting = true);
    try {
      final capture = await Navigator.of(context).push<QuizletWebCapture>(
        MaterialPageRoute(
          builder: (_) => QuizletWebImportScreen(initialUrl: uri),
        ),
      );
      if (capture == null) return;
      final count = await widget.controller.importQuizlet(
        raw: capture.toImporterJson(),
        title: capture.title,
        sourceUrl: capture.sourceUrl,
      );
      if (!mounted) return;
      urlController.clear();
      _showMessage('已從 Quizlet 匯入 $count 個單字，並啟用這個單字集。');
    } on FormatException catch (exception) {
      if (!mounted) return;
      _showMessage(exception.message.toString());
    } finally {
      if (mounted) setState(() => urlImporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => importing = true);
    try {
      final count = await widget.controller.importQuizlet(
        raw: contentController.text,
        title: titleController.text,
      );
      if (!mounted) return;
      _showMessage('已匯入 $count 個單字，並啟用這個單字集。');
      titleController.clear();
      contentController.clear();
    } on FormatException catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
