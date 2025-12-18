import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/affiliate_service.dart';
import '../../core/services/auth_service.dart';
import 'withdrawal_history_screen.dart';
import '../../core/models/balance_info.dart';
import '../../core/models/bank_account.dart';
import '../../core/utils/format_utils.dart';

class AffiliateWithdrawScreen extends StatefulWidget {
  const AffiliateWithdrawScreen({super.key});

  @override
  State<AffiliateWithdrawScreen> createState() => _AffiliateWithdrawScreenState();
}

class _AffiliateWithdrawScreenState extends State<AffiliateWithdrawScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  final AuthService _authService = AuthService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountHolderController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();

  BalanceInfo? _balanceInfo;
  ClaimInfo? _claimInfo;
  List<BankAccount> _bankAccounts = [];
  List<Bank> _banks = [];
  BankAccount? _selectedAccount;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
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
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _affiliateService.getBalanceInfo(userId: _currentUserId),
        _affiliateService.getBankAccounts(userId: _currentUserId),
        _affiliateService.getBanksList(),
      ]);

      if (mounted) {
        setState(() {
          if (results[0] != null) {
            final balanceData = results[0] as Map<String, dynamic>;
            _balanceInfo = balanceData['balanceInfo'] as BalanceInfo;
            _claimInfo = balanceData['claimInfo'] as ClaimInfo;
          }
          if (results[1] != null) {
            _bankAccounts = results[1] as List<BankAccount>;
            _selectedAccount = _bankAccounts.isNotEmpty ? _bankAccounts.first : null;
          }
          if (results[2] != null) {
            _banks = results[2] as List<Bank>;
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

  Future<void> _claimCommission() async {
    if (_claimInfo == null || !_claimInfo!.canClaim) return;

    try {
      final result = await _affiliateService.claimCommission(userId: _currentUserId ?? 0);
      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Đã lấy hoa hồng thành công'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Reload balance info
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi lấy hoa hồng: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitWithdrawal() async {
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn tài khoản ngân hàng'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Remove all non-numeric characters except decimal point
    String cleanText = _amountController.text.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll(',', '');
    final amount = double.tryParse(cleanText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập số tiền hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (amount > (_balanceInfo?.withdrawableBalance ?? 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số tiền rút không được vượt quá số dư có thể rút'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _affiliateService.requestWithdraw(
        userId: _currentUserId ?? 0,
        amount: amount,
        bankAccount: _selectedAccount!.accountNumber,
        bankName: _selectedAccount!.bankName,
        accountHolder: _selectedAccount!.accountHolder,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (result != null && result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gửi yêu cầu rút tiền thành công'),
              backgroundColor: Colors.green,
            ),
          );
          _amountController.clear();
          _loadData(); // Reload balance info
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['message'] ?? 'Gửi yêu cầu rút tiền thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi yêu cầu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBankAccountDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => BankAccountDialog(
        bankAccounts: _bankAccounts,
        banks: _banks,
        selectedAccount: _selectedAccount,
        onAccountSelected: (account) {
          setState(() {
            _selectedAccount = account;
          });
          Navigator.pop(context);
        },
        onAddAccount: () {
          Navigator.pop(context);
          _showAddAccountDialog();
        },
      ),
    );
  }

  void _showAddAccountDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddBankAccountDialog(
        banks: _banks,
        userId: _currentUserId ?? 0,
        onAccountAdded: () {
          Navigator.pop(context);
          _loadData(); // Reload bank accounts
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rút tiền về tài khoản',
        style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Lịch sử rút tiền',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WithdrawalHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance cards
                      if (_balanceInfo != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildBalanceCard(
                                'Tổng số dư',
                                _balanceInfo!.totalBalanceFormatted,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildBalanceCard(
                                'Số dư có thể rút',
                                _balanceInfo!.withdrawableBalanceFormatted,
                                Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildBalanceCard(
                                'Số dư đang chờ',
                                _balanceInfo!.pendingBalanceFormatted,
                                Colors.orange,
                              ),
                            ),
                            if (_claimInfo != null && _claimInfo!.canClaim) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Có thể lấy',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _claimInfo!.claimableAmountFormatted,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ElevatedButton(
                                        onPressed: _claimCommission,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.yellow[600],
                                          foregroundColor: Colors.black,
                                          minimumSize: const Size(80, 24),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        child: const Text(
                                          'Lấy hoa hồng',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Bank account selection
                      GestureDetector(
                        onTap: _showBankAccountDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                          child: Row(
                            children: [
                              const Icon(Icons.credit_card, color: Color(0xFF6C757D)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Chọn tài khoản',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_selectedAccount != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_selectedAccount!.bankName} - ${_selectedAccount!.accountNumber}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                                      ),
                                      Text(
                                        _selectedAccount!.accountHolder,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFADB5BD)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Withdrawal form
                      const Text(
                        'Thông tin rút tiền',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Amount input
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Số hoa hồng *',
                          hintText: 'Nhập số hoa hồng cần rút...',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF6C757D)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6C757D)),
                          ),
                          helperText: _balanceInfo?.withdrawableBalanceFormatted == null
                              ? null
                              : 'Tối đa: ${_balanceInfo!.withdrawableBalanceFormatted}',
                          helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF6C757D)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitWithdrawal,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBalanceCard(String title, String amount, Color color) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.wallet, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF6C757D))),
                const SizedBox(height: 4),
                Text(amount, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BankAccountDialog extends StatelessWidget {
  final List<BankAccount> bankAccounts;
  final List<Bank> banks;
  final BankAccount? selectedAccount;
  final Function(BankAccount) onAccountSelected;
  final VoidCallback onAddAccount;

  const BankAccountDialog({
    super.key,
    required this.bankAccounts,
    required this.banks,
    required this.selectedAccount,
    required this.onAccountSelected,
    required this.onAddAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECEF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chọn tài khoản ngân hàng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          if (bankAccounts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Chưa có tài khoản nào')),
            )
          else
            ...bankAccounts.map((account) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(Icons.account_balance, color: Colors.blue),
                    ),
                    title: Text(account.bankName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${account.accountNumber} • ${account.accountHolder}'),
                    trailing: selectedAccount?.id == account.id
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.chevron_right, color: Color(0xFFADB5BD)),
                    onTap: () => onAccountSelected(account),
                  ),
                )),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('Thêm tài khoản mới', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFADB5BD)),
              onTap: onAddAccount,
            ),
          ),
        ],
      ),
    );
  }
}

class AddBankAccountDialog extends StatefulWidget {
  final List<Bank> banks;
  final VoidCallback onAccountAdded;
  final int userId;

  const AddBankAccountDialog({
    super.key,
    required this.banks,
    required this.onAccountAdded,
    required this.userId,
  });

  @override
  State<AddBankAccountDialog> createState() => _AddBankAccountDialogState();
}

class _AddBankAccountDialogState extends State<AddBankAccountDialog> {
  final TextEditingController _accountHolderController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final AffiliateService _affiliateService = AffiliateService();
  Bank? _selectedBank;
  bool _isDefault = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _addAccount() async {
    if (_selectedBank == null || _accountHolderController.text.isEmpty || _accountNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _affiliateService.addBankAccount(
        userId: widget.userId,
        accountHolder: _accountHolderController.text,
        accountNumber: _accountNumberController.text,
        bankId: _selectedBank!.id,
        isDefault: _isDefault,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (result != null && result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Thêm tài khoản thành công'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onAccountAdded();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result?['message'] ?? 'Thêm tài khoản thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thêm tài khoản: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thêm tài khoản ngân hàng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bank selection
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => BankSelectionDialog(
                            banks: widget.banks,
                            selectedBank: _selectedBank,
                            onBankSelected: (bank) {
                              setState(() {
                                _selectedBank = bank;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance, color: Color(0xFF6C757D)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedBank?.name ?? 'Chọn ngân hàng',
                                style: TextStyle(
                                  color: _selectedBank != null ? const Color(0xFF212529) : const Color(0xFF6C757D),
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFFADB5BD)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account holder
                    TextField(
                      controller: _accountHolderController,
                      decoration: InputDecoration(
                        labelText: 'Chủ tài khoản *',
                        hintText: 'Nhập tên chủ tài khoản ngân hàng...',
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE9ECEF))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE9ECEF))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C757D))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account number
                    TextField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Số tài khoản *',
                        hintText: 'Nhập số tài khoản ngân hàng...',
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE9ECEF))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE9ECEF))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6C757D))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Set as default
                    const Text('Đặt làm mặc định', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isDefault = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isDefault ? Colors.white : const Color(0xFFFFEBEE),
                                border: Border.all(color: _isDefault ? const Color(0xFFE9ECEF) : const Color(0xFFFFCDD2)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Không',
                                style: TextStyle(
                                  color: _isDefault ? const Color(0xFF6C757D) : const Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isDefault = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isDefault ? const Color(0xFFE8F5E9) : Colors.white,
                                border: Border.all(color: _isDefault ? const Color(0xFFC8E6C9) : const Color(0xFFE9ECEF)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Có',
                                style: TextStyle(
                                  color: _isDefault ? const Color(0xFF2E7D32) : const Color(0xFF6C757D),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Add button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _addAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Thêm tài khoản'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BankSelectionDialog extends StatelessWidget {
  final List<Bank> banks;
  final Bank? selectedBank;
  final Function(Bank) onBankSelected;

  const BankSelectionDialog({
    super.key,
    required this.banks,
    required this.selectedBank,
    required this.onBankSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE9ECEF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Chọn ngân hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: banks.length,
              itemBuilder: (context, index) {
                final bank = banks[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(Icons.account_balance, color: Colors.blue),
                    ),
                    title: Text(bank.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(bank.code),
                    trailing: selectedBank?.id == bank.id
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.chevron_right, color: Color(0xFFADB5BD)),
                    onTap: () => onBankSelected(bank),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final number = int.tryParse(newValue.text);
    if (number == null) {
      return oldValue;
    }

    final formatted = FormatUtils.formatCurrency(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}