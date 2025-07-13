import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/enhanced_cache_service.dart';
import '../offline/offline_video_gallery_screen.dart';

class EnhancedCacheSettingsScreen extends ConsumerStatefulWidget {
  const EnhancedCacheSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EnhancedCacheSettingsScreen> createState() => _EnhancedCacheSettingsScreenState();
}

class _EnhancedCacheSettingsScreenState extends ConsumerState<EnhancedCacheSettingsScreen> {
  final EnhancedCacheService _cacheService = EnhancedCacheService();
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _stats = {};
  String _selectedQuality = 'auto';
  bool _batterySaver = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _cacheService.getCacheSettings();
      final stats = await _cacheService.getEnhancedCacheStats();
      final quality = await _cacheService.getUserQualityPreference();
      final batterySaver = await _cacheService.isBatterySaverEnabled();

      setState(() {
        _settings = settings;
        _stats = stats;
        _selectedQuality = quality;
        _batterySaver = batterySaver;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final newSettings = Map<String, dynamic>.from(_settings);
    newSettings[key] = value;
    
    await _cacheService.updateCacheSettings(newSettings);
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
        title: const Text('Enhanced Cache Settings'),
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

          // Video Quality Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.high_quality, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Video Quality',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose your preferred video quality:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...EnhancedCacheService.qualityLevels.entries.map((entry) => 
                    RadioListTile<String>(
                      title: Text(entry.value.toUpperCase()),
                      subtitle: Text(_getQualityDescription(entry.key)),
                      value: entry.key,
                      groupValue: _selectedQuality,
                      onChanged: (value) async {
                        if (value != null) {
                          await _cacheService.setUserQualityPreference(value);
                          setState(() {
                            _selectedQuality = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Battery Saver Mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.battery_saver, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Battery Saver Mode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Enable Battery Saver'),
                    subtitle: const Text('Disables preloading and reduces video quality to save battery'),
                    value: _batterySaver,
                    onChanged: (value) async {
                      await _cacheService.setBatterySaverMode(value);
                      setState(() {
                        _batterySaver = value;
                      });
                    },
                  ),
                  if (_batterySaver)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Battery saver mode is active. Video preloading is disabled.',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Offline Videos Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.download_done, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Offline Videos',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_stats['totalVideos'] ?? 0} cached videos',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              '${_stats['manualDownloadsCount'] ?? 0} manually downloaded',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const OfflineVideoGalleryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.video_library),
                        label: const Text('View All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
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
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Clear Video History'),
                    subtitle: const Text('Remove all watched video history'),
                    onTap: () => _showClearHistoryDialog(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getQualityDescription(String quality) {
    switch (quality) {
      case 'low':
        return '480p - Saves data and battery';
      case 'medium':
        return '720p - Balanced quality and performance';
      case 'high':
        return '1080p - Best quality, uses more data';
      case 'auto':
        return 'Automatically adjusts based on network';
      default:
        return '';
    }
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

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Video History'),
        content: const Text('This will remove all watched video history. This action cannot be undone. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearHistory();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache({bool keepImportant = false, bool keepHighScore = false}) async {
    await _cacheService.clearCache(keepImportant: keepImportant, keepHighScore: keepHighScore);
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

  Future<void> _clearHistory() async {
    await _cacheService.clearVideoHistory();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video history cleared'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
} 