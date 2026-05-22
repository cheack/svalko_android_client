import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          // Логотип
          Image.asset(
            'assets/splash.png',
            height: 72,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),

          // Название + версия
          Center(
            child: Text(
              'Свалко',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_version.isNotEmpty)
            Center(
              child: Text(
                'Версия $_version',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Описание
          Text(
            'СВАЛКА! СВАЛКО!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Неофициальный мобильный клиент для svalko.org.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Автор: bzdno',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'А НЕЧИСТЫМ ПРОГРАММИСТАМ ТРАМПАМПАМ ТРАМПАМПАМ!!!1 ОППА!111АДИНАДИН',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outlineVariant,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Ссылка на сайт
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language_outlined),
            title: const Text('svalko.org'),
            subtitle: const Text('Открыть сайт'),
            onTap: () => launchUrl(
              Uri.parse('https://svalko.org'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}
