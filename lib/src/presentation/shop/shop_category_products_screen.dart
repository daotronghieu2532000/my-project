import 'package:flutter/material.dart';
import '../product/product_detail_screen.dart';
import 'widgets/shop_products_section.dart';

class ShopCategoryProductsScreen extends StatelessWidget {
  final int shopId;
  final int categoryId;
  final String categoryName;

  const ShopCategoryProductsScreen({
    super.key,
    required this.shopId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ShopProductsSection(
        shopId: shopId,
        categoryId: categoryId,
        onProductTap: (product) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: product.id,
                title: product.name,
                image: product.image,
                price: product.price,
                initialShopId: shopId,
              ),
            ),
          );
        },
      ),
    );
  }
}

