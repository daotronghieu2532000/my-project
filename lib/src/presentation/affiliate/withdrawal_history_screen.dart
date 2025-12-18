import 'package:flutter/material.dart';
import '../../core/services/affiliate_service.dart';
import '../../core/services/auth_service.dart';
import 'affiliate_withdraw_screen.dart';
import '../../core/models/withdrawal_history.dart';

class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() => _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  final AuthService _authService = AuthService();
  List<WithdrawalHistory> _withdrawals = [];
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
    _loadWithdrawals();
  }

  Future<void> _loadWithdrawals({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _withdrawals.clear();
      });
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _affiliateService.getWithdrawalHistory(
        userId: _currentUserId,
        page: _currentPage,
        limit: 20,
      );
      
      if (mounted) {
        setState(() {
          if (result != null) {
            if (refresh) {
              _withdrawals = result;
            } else {
              _withdrawals.addAll(result);
            }
            _hasMoreData = result.length >= 20;
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
        title: const Text('Lịch sử rút tiền',
        style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _loadWithdrawals(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading && _withdrawals.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _withdrawals.isEmpty
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
                        onPressed: () => _loadWithdrawals(refresh: true),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _withdrawals.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Chưa có lịch sử rút tiền',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Yêu cầu rút tiền sẽ hiển thị ở đây',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadWithdrawals(refresh: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _withdrawals.length + (_hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _withdrawals.length) {
                            if (_hasMoreData && !_isLoading) {
                              _loadWithdrawals();
                            }
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final withdrawal = _withdrawals[index];
                          return _buildWithdrawalCard(withdrawal);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AffiliateWithdrawScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Rút tiền'),
      ),
    );
  }

  Widget _buildWithdrawalCard(WithdrawalHistory withdrawal) {
    Color statusColor;
    IconData statusIcon;
    
    switch (withdrawal.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rút tiền',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      withdrawal.createdAt,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      withdrawal.statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Amount + date right
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.south_west, size: 16, color: Color(0xFFD32F2F)),
                    const SizedBox(width: 6),
                    Text(
                      '-${withdrawal.amountFormatted}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                withdrawal.createdAt,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Bank info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance, size: 16, color: Color(0xFF6C757D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ngân hàng',
                            style: TextStyle(fontSize: 11, color: Color(0xFF6C757D)),
                          ),
                          Text(
                            withdrawal.bankName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            withdrawal.bankAccount,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Color(0xFF6C757D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        withdrawal.accountHolder,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Processed date if available
          if (withdrawal.processedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: Color(0xFF6C757D)),
                const SizedBox(width: 4),
                Text(
                  'Xử lý lúc: ${withdrawal.processedAt}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                ),
              ],
            ),
          ],
          
          // Notes if available
          if (withdrawal.notes != null && withdrawal.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note, size: 14, color: Color(0xFF1976D2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      withdrawal.notes!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1976D2)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
