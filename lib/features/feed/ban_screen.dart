import 'package:flutter/material.dart';
import '../../core/open_url.dart';
import '../../models/ban_page_data.dart';

class BanScreen extends StatefulWidget {
  const BanScreen({
    super.key,
    required this.banData,
    required this.isLoading,
    required this.onSubmit,
  });

  final BanPageData banData;
  final bool isLoading;
  final void Function(int riddleId, String answer) onSubmit;

  @override
  State<BanScreen> createState() => _BanScreenState();
}

class _BanScreenState extends State<BanScreen> {
  final _controller = TextEditingController();

  static const _telegramUrl = 'https://t.me/joinchat/BoLYVBPZCBF4-vUiwIWYzQ';
  static const _lurk1 =
      'http://lurkmore.to/%D0%A1%D0%B2%D0%B0%D0%BB%D0%BA%D0%BE';
  static const _lurk2 =
      'http://lurkmore.to/%D0%9E%D0%B1%D1%81%D1%83%D0%B6%D0%B4%D0%B5%D0%BD%D0%B8%D0%B5:%D0%A1%D0%B2%D0%B0%D0%BB%D0%BA%D0%BE';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final answer = _controller.text.trim();
    if (answer.isEmpty) return;
    widget.onSubmit(widget.banData.riddleId, answer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ban = widget.banData;

    return Scaffold(
      body: SafeArea(
        child: widget.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, size: 56, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'БЕЗ ПАНИКИ, ТОВАРИЩ!',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ban.ipAddress.isNotEmpty
                          ? 'Ваш ip(ойпи) адрес (${ban.ipAddress}) забанен.'
                          : 'Ваш ip(ойпи) адрес забанен.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Вы были пожраны свинодемоном! Чтобы разбанить себя '
                      'самостоятельно, отгадайте загадку. Загадки простые и не '
                      'должны вызывать затруднений у обычных свалкоёбов. '
                      'Подсказки можно налуркать:',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => openInBrowser(context, _lurk1),
                          child: const Text('тут'),
                        ),
                        TextButton(
                          onPressed: () => openInBrowser(context, _lurk2),
                          child: const Text('и тут'),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    if (ban.riddleQuestion.isNotEmpty) ...[
                      Text(
                        ban.riddleQuestion,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'ответ',
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('ок'),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('специальный секретный канал в телеге'),
                      onPressed: () => openInBrowser(context, _telegramUrl),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
