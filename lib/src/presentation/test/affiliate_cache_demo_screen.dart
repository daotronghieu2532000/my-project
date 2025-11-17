import 'package:flutter/material.dart';
import '../../core/services/cached_api_service.dart';

class AffiliateCacheDemoScreen extends StatefulWidget {
  const AffiliateCacheDemoScreen({super.key});

  @override
  State<AffiliateCacheDemoScreen> createState() => _AffiliateCacheDemoScreenState();
}

class _AffiliateCacheDemoScreenState extends State<AffiliateCacheDemoScreen> {
  final CachedApiService _cachedApiService = CachedApiService();
  Map<String, dynamic>? _cacheInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  void _loadCacheInfo() {
    setState(() {
      _cacheInfo = _cachedApiService.getCacheInfo();
    });
  }

  Future<void> _testAffiliateDashboard() async {
    setState(() => _isLoading = true);
    
    try {
     
      final result = await _cachedApiService.getAffiliateDashboard(userId: 123);
    
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Affiliate dashboard cache test completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
    _loadCacheInfo();
  }

  Future<void> _testAffiliateLinks() async {
    setState(() => _isLoading = true);
    
    try {
    
      final result = await _cachedApiService.getAffiliateLinks(
        userId: 123,
        page: 1,
        limit: 10,
      );
    
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Affiliate links cache test completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
    _loadCacheInfo();
  }

  Future<void> _testAffiliateProducts() async {
    setState(() => _isLoading = true);
    
    try {
    
      final result = await _cachedApiService.getAffiliateProducts(
        userId: 123,
        page: 1,
        limit: 10,
      );
     
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Affiliate products cache test completed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
     
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
    _loadCacheInfo();
  }

  void _clearAffiliateCache() {
    _cachedApiService.clearAllAffiliateCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧹 Cleared all affiliate cache'),
        backgroundColor: Colors.orange,
      ),
    );
    _loadCacheInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Affiliate Cache Demo'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadCacheInfo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cache Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📊 Cache Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Total Entries: ${_cacheInfo?['totalEntries'] ?? 0}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Valid Entries: ${_cacheInfo?['validEntries'] ?? 0}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Expired Entries: ${_cacheInfo?['expiredEntries'] ?? 0}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Test Buttons
                  const Text(
                    '🧪 Test Affiliate Cache',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildTestButton(
                    '💰 Test Dashboard Cache',
                    Icons.dashboard,
                    _testAffiliateDashboard,
                  ),
                  const SizedBox(height: 8),
                  
                  _buildTestButton(
                    '🔗 Test Links Cache',
                    Icons.link,
                    _testAffiliateLinks,
                  ),
                  const SizedBox(height: 8),
                  
                  _buildTestButton(
                    '📦 Test Products Cache',
                    Icons.inventory,
                    _testAffiliateProducts,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Cache Management
                  const Text(
                    '🛠️ Cache Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildTestButton(
                    '🧹 Clear Affiliate Cache',
                    Icons.clear_all,
                    _clearAffiliateCache,
                    isDestructive: true,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Cache Entries Detail
                  if (_cacheInfo?['entries'] != null) ...[
                    const Text(
                      '📋 Cache Entries Detail',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    ...(_cacheInfo!['entries'] as Map<String, dynamic>).entries.map(
                      (entry) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Type: ${entry.value['type']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                'Expires in: ${entry.value['expiresInSeconds']}s',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Text(
                                'Is Expired: ${entry.value['isExpired']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: entry.value['isExpired'] ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTestButton(
    String title,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? Colors.red : Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
