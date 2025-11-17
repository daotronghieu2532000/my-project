import 'package:flutter/material.dart';
import '../core/services/cached_api_service.dart';

/// Demo screen để test hệ thống cache
class CacheDemoScreen extends StatefulWidget {
  const CacheDemoScreen({super.key});

  @override
  State<CacheDemoScreen> createState() => _CacheDemoScreenState();
}

class _CacheDemoScreenState extends State<CacheDemoScreen> {
  final CachedApiService _cachedApiService = CachedApiService();
  Map<String, dynamic>? _cacheInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _updateCacheInfo();
  }

  void _updateCacheInfo() {
    setState(() {
      _cacheInfo = _cachedApiService.getCacheInfo();
    });
  }

  Future<void> _testHomeCache() async {
    setState(() {
      _isLoading = true;
    });

    try {
     
      
      // Test banners
      final banners = await _cachedApiService.getHomeBanners();
     
      // Test flash sale
      final flashSale = await _cachedApiService.getHomeFlashSale();
     
      
      // Test partner banners
      final partnerBanners = await _cachedApiService.getHomePartnerBanners();
     
      // Test suggestions
      final suggestions = await _cachedApiService.getHomeSuggestions(limit: 20);
     
      
      _updateCacheInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cache test completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
     
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Cache test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHomeCache() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _cachedApiService.refreshHomeCache();
      _updateCacheInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔄 Home cache refreshed successfully!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
     
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Refresh failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearAllCache() {
    _cachedApiService.clearAllCache();
    _updateCacheInfo();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧹 All cache cleared!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Demo'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cache Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cache Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_cacheInfo != null) ...[
                      Text('Total Entries: ${_cacheInfo!['totalEntries']}'),
                      Text('Valid Entries: ${_cacheInfo!['validEntries']}'),
                      Text('Expired Entries: ${_cacheInfo!['expiredEntries']}'),
                    ] else
                      const Text('No cache info available'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testHomeCache,
              icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Testing...' : 'Test Home Cache'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _refreshHomeCache,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Home Cache'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _clearAllCache,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All Cache'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Cache Entries Detail
            if (_cacheInfo != null && _cacheInfo!['entries'] != null)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cache Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _cacheInfo!['entries'].length,
                            itemBuilder: (context, index) {
                              final entry = _cacheInfo!['entries'].entries.elementAt(index);
                              final key = entry.key;
                              final value = entry.value;
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(
                                    key,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Created: ${value['createdAt']}'),
                                      Text('Expires: ${value['expiresAt']}'),
                                      Text('Time to expire: ${value['timeToExpire']} minutes'),
                                      Text('Expired: ${value['isExpired']}'),
                                    ],
                                  ),
                                  trailing: Icon(
                                    value['isExpired'] ? Icons.error : Icons.check_circle,
                                    color: value['isExpired'] ? Colors.red : Colors.green,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
