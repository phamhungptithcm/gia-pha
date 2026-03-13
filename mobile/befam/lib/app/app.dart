import 'package:flutter/material.dart';

class FirebaseSetupStatus {
  const FirebaseSetupStatus._({
    required this.isReady,
    required this.projectId,
    required this.storageBucket,
    required this.enabledServices,
    this.errorMessage,
  });

  factory FirebaseSetupStatus.ready({
    required String projectId,
    required String storageBucket,
    required List<String> enabledServices,
  }) {
    return FirebaseSetupStatus._(
      isReady: true,
      projectId: projectId,
      storageBucket: storageBucket,
      enabledServices: enabledServices,
    );
  }

  factory FirebaseSetupStatus.failed({
    required String projectId,
    required String storageBucket,
    required String errorMessage,
  }) {
    return FirebaseSetupStatus._(
      isReady: false,
      projectId: projectId,
      storageBucket: storageBucket,
      enabledServices: const [],
      errorMessage: errorMessage,
    );
  }

  final bool isReady;
  final String projectId;
  final String storageBucket;
  final List<String> enabledServices;
  final String? errorMessage;
}

class BeFamApp extends StatelessWidget {
  const BeFamApp({super.key, required this.status});

  final FirebaseSetupStatus status;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeFam',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F)),
        useMaterial3: true,
      ),
      home: FirebaseSetupPage(status: status),
    );
  }
}

class FirebaseSetupPage extends StatelessWidget {
  const FirebaseSetupPage({super.key, required this.status});

  final FirebaseSetupStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('BeFam Firebase Setup')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.isReady
                      ? 'BeFam Firebase Ready'
                      : 'Firebase Needs Attention',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  status.isReady
                      ? 'The mobile app is connected to the BeFam Firebase project and ready for feature work.'
                      : 'Firebase native configuration is wired, but the project still needs cloud APIs enabled before backend deploys can succeed.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _InfoCard(
            title: 'Project',
            rows: [
              _InfoRow(label: 'Project ID', value: status.projectId),
              _InfoRow(label: 'Storage bucket', value: status.storageBucket),
              _InfoRow(label: 'Platforms', value: 'Android + iOS'),
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Configured SDKs',
            rows: [
              _InfoRow(
                label: 'Services',
                value: status.isReady
                    ? status.enabledServices.join(', ')
                    : 'Core SDK wiring pending app startup',
              ),
              const _InfoRow(
                label: 'Native config',
                value: 'google-services.json + GoogleService-Info.plist',
              ),
              const _InfoRow(
                label: 'Flutter config',
                value: 'lib/firebase_options.dart',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Backend Scaffold',
            rows: const [
              _InfoRow(
                label: 'Firestore rules',
                value: 'firebase/firestore.rules',
              ),
              _InfoRow(
                label: 'Firestore indexes',
                value: 'firebase/firestore.indexes.json',
              ),
              _InfoRow(label: 'Storage rules', value: 'firebase/storage.rules'),
              _InfoRow(
                label: 'Functions',
                value: 'firebase/functions (TypeScript v2 scaffold)',
              ),
            ],
          ),
          if (!status.isReady && status.errorMessage != null) ...[
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Initialization Error',
              rows: [_InfoRow(label: 'Details', value: status.errorMessage!)],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final row in rows) ...[
              Text(
                row.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(row.value),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;
}
