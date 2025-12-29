import 'package:flutter/foundation.dart';

class ShippingQuoteStore extends ChangeNotifier {
  static final ShippingQuoteStore _instance = ShippingQuoteStore._internal();
  factory ShippingQuoteStore() => _instance;
  ShippingQuoteStore._internal();

  int _lastFee = 0;
  String? _etaText;
  String? _provider;
  int _shipSupport = 0; // Tổng ship support đã được áp dụng
  Map<int, int> _shopShipSupport = {}; // Map shop_id => ship_support

  int get lastFee => _lastFee;
  String? get etaText => _etaText;
  String? get provider => _provider;
  int get shipSupport => _shipSupport;
  Map<int, int> get shopShipSupport => Map.unmodifiable(_shopShipSupport); // Read-only copy

  void setQuote({required int fee, String? etaText, String? provider, int shipSupport = 0, Map<int, int>? shopShipSupport}) {
    _lastFee = fee;
    _etaText = etaText;
    _provider = provider;
    _shipSupport = shipSupport;
    _shopShipSupport = shopShipSupport ?? {};
    notifyListeners(); // Thông báo cho các widget đang lắng nghe
  }
}



