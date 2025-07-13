import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/video_cache_service.dart';

class CacheSettingsScreen extends ConsumerStatefulWidget {
  const CacheSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CacheSettingsScreen> createState() => _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends ConsumerState<CacheSettingsScreen> {
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final cacheService = VideoCacheService();
    final settings = await cacheService.getCacheSettings();
    final stats = await cacheService.getCacheStats();
    
    setState(() {
      _settings = settings;
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final cacheService = VideoCacheService();
    final newSettings = Map<String, dynamic>.from(_settings);
    newSettings[key] = value;
    
    await cacheService.updateCacheSettings(newSettings);
    setState(() {
      _settings = newSettings;
    });
  }

  Future<void> _clearCache({bool keepImportant = false}) async {
    final cacheService = VideoCacheService();
    await cacheService.clearCache(keepImportant: keepImportant);
    await _loadSettings();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keepImportant 
            ? 'Cache cleared (important videos kept)'
            : 'Cache cleared completely'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
        title: const Text('Cache Settings'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cache Statistics Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cache Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Total Videos',
                          '${_stats['totalVideos']}',
                          Icons.video_library,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Important Videos',
                          '${_stats['importantVideos']}',
                          Icons.star,
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
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Max Cache',
                          '${_stats['maxCache']}',
                          Icons.settings,
                        ),
                      ),
                    ],
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
                    'Preloading Settings',
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

          // Cache Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cache Management',
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
                    onTap: () => _showClearCacheDialog(true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever),
                    title: const Text('Clear All Cache'),
                    subtitle: const Text('Remove all cached videos including important ones'),
                    onTap: () => _showClearCacheDialog(false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple),
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
        ),
      ],
    );
  }

  void _showClearCacheDialog(bool keepImportant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(keepImportant ? 'Clear Cache' : 'Clear All Cache'),
        content: Text(keepImportant
            ? 'This will remove all cached videos except those marked as important. Continue?'
            : 'This will remove ALL cached videos including important ones. This action cannot be undone. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearCache(keepImportant: keepImportant);
            },
            child: Text(keepImportant ? 'Clear' : 'Clear All'),
          ),
        ],
      ),
    );
  }
} 