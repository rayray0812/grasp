import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  bool importing = false;

  @override
  void dispose() {
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
        '在 Quizlet 選擇「匯出」，用 Tab 分隔單字與定義，再把內容貼到這裡。匯入後會直接交給 FSRS 排程，不需要 AI 補完。',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
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

  Future<void> _import() async {
    setState(() => importing = true);
    try {
      final count = await widget.controller.importQuizlet(
        raw: contentController.text,
        title: titleController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已匯入 $count 個單字，並啟用這個單字集。')));
      titleController.clear();
      contentController.clear();
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }
}
