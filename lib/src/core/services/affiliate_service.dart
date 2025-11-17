import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/affiliate_dashboard.dart';
import '../models/affiliate_product.dart';
import '../models/affiliate_link.dart';
import '../models/commission_history.dart';
import '../models/withdrawal_history.dart';
import '../models/balance_info.dart';
import '../models/bank_account.dart';
import 'api_service.dart';

class AffiliateService {
  final ApiService _apiService = ApiService();

  /// Register user for affiliate program
  Future<Map<String, dynamic>?> registerAffiliate({required int userId}) async {
    try {
      final result = await _apiService.registerAffiliate(userId: userId);
     
      return result;
    } catch (e) {
     
      return null;
    }
  }

  /// Get user affiliate status (dk_aff field)
  Future<bool?> getUserAffiliateStatus({required int userId}) async {
    try {
      final profile = await _apiService.getUserProfile(userId: userId);
      if (profile != null && profile['user'] != null) {
        final user = profile['user'] as Map<String, dynamic>;
        final dkAff = user['dk_aff'];
       
        return dkAff == 1;
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  /// Get affiliate dashboard statistics
  Future<AffiliateDashboard?> getDashboard({int? userId}) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_dashboard';
      if (userId != null) {
        url += '?user_id=$userId';
      }

    
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      );
      
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
      
        
        if (data['success'] == true && data['data'] != null) {
          return AffiliateDashboard.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  /// Follow / Unfollow product
  Future<Map<String, dynamic>?> toggleFollow({
    required int userId,
    required int spId,
    required int shopId,
    required bool follow,
  }) async {
    try {
      final url = 'https://api.socdo.vn/v1/affiliate_follow_product';
      final payload = jsonEncode({
        'user_id': userId,
        'sp_id': spId,
        'shop': shopId,
        'action': follow ? 'follow' : 'unfollow',
      });
    
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
     
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
    
      return null;
    }
  }

  /// Get list of affiliate products
  Future<Map<String, dynamic>?> getProducts({
    int? userId,
    int page = 1,
    int limit = 50, // Tăng từ 20 lên 50
    String? search,
    String? sortBy,
    bool onlyFollowing = false,
  }) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_products?page=$page&limit=$limit';
      if (userId != null) url += '&user_id=$userId';
      if (search != null && search.isNotEmpty) url += '&search=${Uri.encodeComponent(search)}';
      if (sortBy != null && sortBy.isNotEmpty) url += '&sort_by=$sortBy';
      if (onlyFollowing) url += '&only_following=1';

 
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final productsData = data['data']['products'] as List? ?? [];
          final products = productsData
              .map((item) => AffiliateProduct.fromJson(item as Map<String, dynamic>))
              .toList();
          
          return {
            'products': products,
            'pagination': data['data']['pagination'],
          };
        }
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  /// Create affiliate link for a product
  Future<Map<String, dynamic>?> createLink({
    required int userId,
    required int spId,
    String? fullLink, // optional: long URL with utm_source_shop built on client
  }) async {
    try {
      final url = 'https://api.socdo.vn/v1/affiliate_create_link';
      final Map<String, dynamic> body = {
        'user_id': userId,
        'sp_id': spId,
      };
      if (fullLink != null && fullLink.isNotEmpty) {
        body['full_link'] = fullLink;
      }
      final payload = jsonEncode(body);
   
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      
    
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
      
        
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
    
      return null;
    }
  }


  /// Get affiliate orders
  Future<Map<String, dynamic>?> getOrders({
int? userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_orders?page=$page&limit=$limit';
      if (userId != null) url += '&user_id=$userId';

     
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
    
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          // Return raw data instead of parsed objects
          return data;
        }
      }
      return null;
    } catch (e) {
    
      return null;
    }
  }

  /// Claim commission (after 7 days)
  Future<Map<String, dynamic>?> claimCommission({required int userId}) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.socdo.vn/v1/affiliate_claim_commission'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Claim failed',
          };
        }
      }
      return null;
    } catch (e) {
 
      return null;
    }
  }

  /// Get my affiliate links
  Future<Map<String, dynamic>?> getMyLinks({
    int? userId,
    int page = 1,
    int limit = 20,
    String? search,
    String? sortBy,
    bool onlyHasLink = false,
  }) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_my_links?page=$page&limit=$limit';
      if (userId != null) url += '&user_id=$userId';
      if (search != null && search.isNotEmpty) url += '&search=${Uri.encodeComponent(search)}';
      if (sortBy != null && sortBy.isNotEmpty) url += '&sort_by=$sortBy';
      if (onlyHasLink) url += '&only_has_link=1';

    
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // New API returns followed_products array
          final linksData = (data['data']['followed_products'] as List?) ?? [];
          final links = linksData
              .map((item) => AffiliateLink.fromJson(item as Map<String, dynamic>))
              .toList();

          return {
            'links': links,
            'pagination': data['data']['pagination'],
          };
        }
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  /// Request withdrawal
  Future<Map<String, dynamic>?> requestWithdraw({
    required int userId,
    required double amount,
    required String bankAccount,
    required String bankName,
    required String accountHolder,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.socdo.vn/v1/affiliate_withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'amount': amount,
          'bank_account': bankAccount,
          'bank_name': bankName,
          'account_holder': accountHolder,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Withdraw failed',
          };
        }
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  /// Get commission history
  Future<Map<String, dynamic>?> getCommissionHistory({
    int? userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_commission_history?page=$page&limit=$limit';
      if (userId != null) url += '&user_id=$userId';

     
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final commissionsData = data['data']['commissions'] as List? ?? [];
          final commissions = commissionsData
              .map((item) => CommissionHistory.fromJson(item as Map<String, dynamic>))
              .toList();

          return {
            'commissions': commissions,
            'pagination': data['data']['pagination'],
          };
        }
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  /// Get withdrawal history
  Future<List<WithdrawalHistory>?> getWithdrawalHistory({
    int? userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_withdrawal_history?page=$page&limit=$limit';
      if (userId != null) url += '&user_id=$userId';

     
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final withdrawalsData = data['data']['withdrawals'] as List? ?? [];
          return withdrawalsData
              .map((item) => WithdrawalHistory.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return null;
    } catch (e) {
   
      return null;
    }
  }

  /// Get balance information
  Future<Map<String, dynamic>?> getBalanceInfo({int? userId}) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_balance_info';
      if (userId != null) url += '?user_id=$userId';

     
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final balanceInfo = BalanceInfo.fromJson(data['data']['balances']);
          final claimInfo = ClaimInfo.fromJson(data['data']['claim_info']);

          return {
            'balanceInfo': balanceInfo,
            'claimInfo': claimInfo,
          };
        }
      }
      return null;
    } catch (e) {
  
      return null;
    }
  }

  /// Get bank accounts
  Future<List<BankAccount>?> getBankAccounts({int? userId}) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_bank_accounts';
      if (userId != null) url += '?user_id=$userId';

     
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );


      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final accountsData = data['data']['bank_accounts'] as List? ?? [];
          return accountsData
              .map((item) => BankAccount.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  /// Get banks list
  Future<List<Bank>?> getBanksList() async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_banks_list';

     
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final banksData = data['data']['banks'] as List? ?? [];
          return banksData
              .map((item) => Bank.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return null;
    } catch (e) {
    
      return null;
    }
  }


  /// Add bank account
  Future<Map<String, dynamic>?> addBankAccount({
    required int userId,
    required String accountHolder,
    required String accountNumber,
    required int bankId,
    required bool isDefault,
  }) async {
    try {
      String url = 'https://api.socdo.vn/v1/affiliate_bank_accounts?user_id=$userId';
   
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'account_holder': accountHolder,
          'account_number': accountNumber,
          'bank_id': bankId,
          'is_default': isDefault,
        }),
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? '',
          'data': data['data'],
        };
      }
      return null;
    } catch (e) {
   
      return null;
    }
  }
}

