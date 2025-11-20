import 'package:flutter/material.dart';
import 'widgets/viewed_product_card.dart';
import 'models/viewed_product.dart';

class ViewedProductsScreen extends StatelessWidget {
  const ViewedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, // Đổi thành trắng để title đen hiển thị rõ
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          'Đã xem',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Stack(
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.black,
                  size: 24,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Implement reload viewed products
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: ViewedProduct.sampleProducts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final product = ViewedProduct.sampleProducts[index];
            return ViewedProductCard(product: product);
          },
        ),
      ),
    );
  }
}
