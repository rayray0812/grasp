import 'package:flutter/material.dart';

import '../ai/ai_byok.dart';
import '../app/app_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final secrets = const AiSecretStore();
  final fields = {
    for (final provider in AiProvider.values) provider: TextEditingController(),
  };
  Map<AiProvider, bool> configured = const {};

  @override
  void initState() {
    super.initState();
    _refreshKeys();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshKeys() async {
    final values = <AiProvider, bool>{};
    for (final provider in AiProvider.values) {
      values[provider] = await secrets.hasKey(provider);
    }
    if (mounted) setState(() => configured = values);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          '設定',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        _Heading('每日學習'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '每日新單字',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('${widget.controller.settings.dailyNewWords} 字'),
                  ],
                ),
                Slider(
                  value: widget.controller.settings.dailyNewWords.toDouble(),
                  min: 0,
                  max: 30,
                  divisions: 6,
                  label: '${widget.controller.settings.dailyNewWords}',
                  onChanged: (value) =>
                      widget.controller.setDailyNewWords(value.round()),
                ),
                Text(
                  'FSRS 目標記憶率固定為 ${(widget.controller.settings.desiredRetention * 100).round()}%。排程會在背景自動計算。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        _Heading('AI · 選用'),
        Text(
          '沒有設定 AI 時，匯入、學習、FSRS 與所有核心題型仍可完整使用。Key 只存於這台裝置的安全儲存空間；請只使用你自己的 Key。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        for (final provider in AiProvider.values) ...[
          _ProviderKeyCard(
            provider: provider,
            controller: fields[provider]!,
            isConfigured: configured[provider] ?? false,
            onSave: () => _save(provider),
            onDelete: () => _delete(provider),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Card(
          child: const ListTile(
            leading: Icon(Icons.memory_rounded),
            title: Text('Local AI'),
            subtitle: Text('平台支援且安裝本機模型時才會啟用；永遠不是核心學習依賴。'),
          ),
        ),
        const SizedBox(height: 28),
        _Heading('資料與隱私'),
        const Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.storage_rounded),
                title: Text('Local-first'),
                subtitle: Text('單字、FSRS 狀態、複習歷史與設定都保存在本機。'),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.person_off_outlined),
                title: Text('不需要帳號'),
                subtitle: Text('沒有登入、會員、訂閱、廣告或 Grasp server。'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('Grasp · Free and open source')),
      ],
    ),
  );

  Future<void> _save(AiProvider provider) async {
    final value = fields[provider]!.text;
    if (value.trim().isEmpty) return;
    await secrets.save(provider, value);
    fields[provider]!.clear();
    await _refreshKeys();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${provider.label} Key 已安全儲存在本機。')));
  }

  Future<void> _delete(AiProvider provider) async {
    await secrets.delete(provider);
    await _refreshKeys();
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _ProviderKeyCard extends StatelessWidget {
  const _ProviderKeyCard({
    required this.provider,
    required this.controller,
    required this.isConfigured,
    required this.onSave,
    required this.onDelete,
  });

  final AiProvider provider;
  final TextEditingController controller;
  final bool isConfigured;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  provider.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (isConfigured)
                const Chip(
                  avatar: Icon(Icons.check_rounded, size: 16),
                  label: Text('已設定'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: isConfigured ? '輸入新 Key 以取代目前設定' : '輸入 API Key',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isConfigured)
                TextButton(onPressed: onDelete, child: const Text('移除')),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: onSave, child: const Text('儲存')),
            ],
          ),
        ],
      ),
    ),
  );
}
