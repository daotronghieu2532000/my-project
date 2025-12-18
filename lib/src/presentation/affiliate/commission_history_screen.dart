import 'package:flutter/material.dart';
import '../../core/services/affiliate_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/commission_history.dart';

class CommissionHistoryScreen extends StatefulWidget {
  const CommissionHistoryScreen({super.key});

  @override
  State<CommissionHistoryScreen> createState() => _CommissionHistoryScreenState();
}

class _CommissionHistoryScreenState extends State<CommissionHistoryScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  final AuthService _authService = AuthService();
  List<CommissionHistory> _commissions = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreData = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUserId = user?.userId;
    });
    _loadCommissions();
  }

  Future<void> _loadCommissions({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _commissions.clear();
      });
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _affiliateService.getCommissionHistory(
        userId: _currentUserId,
        page: _currentPage,
        limit: 20,
      );
      
      if (mounted) {
        setState(() {
          if (result != null) {
            final newCommissions = result['commissions'] as List<CommissionHistory>;
            if (refresh) {
              _commissions = newCommissions;
            } else {
              _commissions.addAll(newCommissions);
            }
            final pagination = result['pagination'];
            _hasMoreData = _currentPage < pagination['total_pages'];
            _currentPage++;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi khi tải dữ liệu: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử hoa hồng',
        style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _loadCommissions(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading && _commissions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _commissions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadCommissions(refresh: true),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _commissions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có lịch sử hoa hồng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Hoa hồng sẽ hiển thị ở đây khi có giao dịch',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadCommissions(refresh: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _commissions.length + (_hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _commissions.length) {
                            if (_hasMoreData && !_isLoading) {
                              _loadCommissions();
                            }
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final commission = _commissions[index];
                          return _buildCommissionCard(commission);
                        },
                      ),
                    ),
    );
  }

  Widget _buildCommissionCard(CommissionHistory commission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with amount and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commission.description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        commission.createdAt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: commission.isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    commission.isPositive ? '+${commission.amountFormatted}' : commission.amountFormatted,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: commission.isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Balance info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE9ECEF))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Số dư trước:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                      Text(
                        commission.balanceBeforeFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Số dư sau:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                      Text(
                        commission.balanceAfterFormatted,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Transfer status
            if (commission.transferredToWithdrawable == 1) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF1976D2)),
                    SizedBox(width: 4),
                    Text('Đã chuyển vào số dư có thể rút', style: TextStyle(fontSize: 10, color: Color(0xFF1976D2), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
