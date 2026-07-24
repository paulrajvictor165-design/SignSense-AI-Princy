import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../providers/voice_provider.dart';
import '../models/detection_result.dart';
import '../utils/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceProvider>().speak(
        'Detection history screen. Showing past detections.',
      );
    });
  }

  Future<void> _loadHistory() async {
    final history = await _dbService.getDetectionHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await _dbService.clearHistory();
    setState(() => _history = []);
    context.read<VoiceProvider>().speak('History cleared.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection History'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text('Delete all detection history?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearHistory();
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: AppTheme.ibmRed),
                      ),
                    ),
                  ],
                ),
              ),
              tooltip: 'Clear history',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.ibmBlue))
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history_outlined,
                        size: 64,
                        color: AppTheme.ibmCoolGray,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No history yet.',
                        style: TextStyle(
                          color: AppTheme.ibmCoolGray,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use the camera features to start detecting.',
                        style: TextStyle(
                          color: AppTheme.ibmCoolGray,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.ibmBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.center_focus_strong_outlined,
                          color: AppTheme.ibmBlue,
                        ),
                      ),
                      title: Text(
                        item['label'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${item['type'] ?? ''} · ${item['timestamp'] ?? ''}',
                        style: const TextStyle(
                          color: AppTheme.ibmCoolGray,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.volume_up_outlined,
                            color: AppTheme.ibmBlue),
                        onPressed: () => context
                            .read<VoiceProvider>()
                            .speak(item['label'] ?? ''),
                        tooltip: 'Read aloud',
                      ),
                    );
                  },
                ),
    );
  }
}
