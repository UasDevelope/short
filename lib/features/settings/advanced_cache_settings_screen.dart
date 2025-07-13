import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/advanced_cache_service.dart';

class AdvancedCacheSettingsScreen extends ConsumerStatefulWidget {
  const AdvancedCacheSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdvancedCacheSettingsScreen> createState() => _AdvancedCacheSettingsScreenState();
}

class _AdvancedCacheSettingsScreenState extends ConsumerState<AdvancedCacheSettingsScreen> {
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final cacheService = AdvancedCacheService();
    final settings = await cacheService.getCacheSettings();
    final stats = await cacheService.getCacheStats();
    
    setState(() {
      _settings = settings;
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final cacheService = AdvancedCacheService();
    final newSettings = Map<String, dynamic>.from(_settings);
    newSettings[key] = value;
    
    await cacheService.updateCacheSettings(newSettings);
    setState(() {
      _settings = newSettings;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Color _getHealthColor(String status) {
    switch (status) {
      case 'Excellent': return Colors.green;
      case 'Good': return Colors.blue;
      case 'Warning': return Colors.orange;
      case 'Critical': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Cache Settings'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cache Health Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.health_and_safety, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text(
                        'Cache Health',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getHealthColor(_stats['healthStatus']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _stats['healthStatus'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (_stats['usagePercent'] ?? 0) / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getHealthColor(_stats['healthStatus']),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_stats['usagePercent']?.toStringAsFixed(1)}% used (${_stats['totalVideos']}/${_stats['maxCache']} videos)',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AI Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'AI Cache Intelligence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Avg Importance Score',
                          '${(_stats['avgImportanceScore'] ?? 0.0).toStringAsFixed(2)}',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Important Videos',
                          '${_stats['importantVideos']}',
                          Icons.star,
                          Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Total Size',
                          _formatBytes(_stats['totalSize'] ?? 0),
                          Icons.storage,
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Chunked Videos',
                          '${_stats['chunkedVideos'] ?? 0}',
                          Icons.video_library,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Advanced Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advanced Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Adaptive Quality'),
                    subtitle: const Text('Automatically adjust video quality based on network'),
                    value: _settings['adaptiveQuality'] ?? true,
                    onChanged: (value) {
                      _updateSetting('adaptiveQuality', value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Auto Cleanup'),
                    subtitle: const Text('Automatically clean old temporary files'),
                    value: _settings['autoCleanup'] ?? true,
                    onChanged: (value) {
                      _updateSetting('autoCleanup', value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Preload on Mobile'),
                    subtitle: const Text('Cache videos on mobile data (uses more data)'),
                    value: _settings['preloadOnMobile'] ?? false,
                    onChanged: (value) {
                      _updateSetting('preloadOnMobile', value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cache Size Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cache Size',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Max Cache Size: '),
                      Expanded(
                        child: Slider(
                          value: (_settings['maxCacheSize'] ?? 50).toDouble(),
                          min: 10,
                          max: 100,
                          divisions: 9,
                          label: '${_settings['maxCacheSize'] ?? 50}',
                          onChanged: (value) {
                            _updateSetting('maxCacheSize', value.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Preloading Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Smart Preloading',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Preload on Wi-Fi'),
                    subtitle: const Text('Automatically cache videos when on Wi-Fi'),
                    value: _settings['preloadOnWifi'] ?? true,
                    onChanged: (value) {
                      _updateSetting('preloadOnWifi', value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Preload when charging'),
                    subtitle: const Text('Cache videos when device is charging'),
                    value: _settings['preloadOnCharging'] ?? true,
                    onChanged: (value) {
                      _updateSetting('preloadOnCharging', value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Preload on low battery'),
                    subtitle: const Text('Cache videos even when battery is low'),
                    value: _settings['preloadOnLowBattery'] ?? false,
                    onChanged: (value) {
                      _updateSetting('preloadOnLowBattery', value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Advanced Cache Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advanced Cache Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.clear_all),
                    title: const Text('Clear Cache (Keep Important)'),
                    subtitle: const Text('Remove all cached videos except important ones'),
                    onTap: () => _showClearCacheDialog(true, false),
                  ),
                  ListTile(
                    leading: const Icon(Icons.psychology),
                    title: const Text('Clear Cache (Keep High Score)'),
                    subtitle: const Text('Remove videos with low AI importance scores'),
                    onTap: () => _showClearCacheDialog(false, true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever),
                    title: const Text('Clear All Cache'),
                    subtitle: const Text('Remove all cached videos including important ones'),
                    onTap: () => _showClearCacheDialog(false, false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showClearCacheDialog(bool keepImportant, bool keepHighScore) {
    String title, content;
    
    if (keepImportant) {
      title = 'Clear Cache (Keep Important)';
      content = 'This will remove all cached videos except those marked as important. Continue?';
    } else if (keepHighScore) {
      title = 'Clear Cache (Keep High Score)';
      content = 'This will remove videos with low AI importance scores. Continue?';
    } else {
      title = 'Clear All Cache';
      content = 'This will remove ALL cached videos including important ones. This action cannot be undone. Continue?';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearCache(keepImportant: keepImportant, keepHighScore: keepHighScore);
            },
            child: Text(keepImportant || keepHighScore ? 'Clear' : 'Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache({bool keepImportant = false, bool keepHighScore = false}) async {
    final cacheService = AdvancedCacheService();
    await cacheService.clearCache(keepImportant: keepImportant, keepHighScore: keepHighScore);
    await _loadSettings();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepImportant 
            ? 'Cache cleared (important videos kept)'
            : keepHighScore
              ? 'Cache cleared (high-score videos kept)'
              : 'Cache cleared completely'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
} 