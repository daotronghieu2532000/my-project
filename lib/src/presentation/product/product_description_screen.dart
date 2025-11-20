import 'package:flutter/material.dart';

class ProductDescriptionScreen extends StatelessWidget {
  final String productName;
  final String productImage;
  
  const ProductDescriptionScreen({
    super.key,
    required this.productName,
    required this.productImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          productName,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Viên uống hỗ trợ trắng da Transino White C Clear 120 viên',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Viên uống Transino White C là viên uống giúp đẹp da, hỗ trợ cải thiện thâm nám, tàn nhang với các thành phần dưỡng da nổi bật như L-Cysteine - 240mg, vitamin C, vitamin E... Viên uống hỗ trợ trắng da Transino White C Nhật Bản là một trong những sản phẩm nổi bật, góp phần làm lên tên tuổi của Transino, nhãn hiệu chăm sóc da nổi tiếng của hãng Daiichi Sankyo – Nhật Bản.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Product Image
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: AssetImage(productImage),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Viên uống hỗ trợ trắng da của Nhật Transino White C Clear 120 viên',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Ưu điểm nổi bật của viên uống Transino White C Clear',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Transino White C Clear với các thành phần tự nhiên, được chứng nhận về chất lượng cho người sử dụng, hỗ trợ chị em trong quá trình làm đẹp tại nhà đơn giản và hiệu quả với những tác động như:',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _BenefitsList(),
                  const SizedBox(height: 24),
                  // Before/After Image
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                    ),
                    child: const Center(
                      child: Text(
                        'BEFORE / AFTER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Trước và sau khi sử dụng viên uống Transino white C',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Thành phần viên uống hỗ trợ trắng da Transino White C Clear',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _IngredientsList(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList();

  @override
  Widget build(BuildContext context) {
    final benefits = [
      'Hỗ trợ làm đẹp da, sáng da',
      'Hỗ trợ cải thiện nám, tàn nhang, làm mờ vết thâm, giúp da đều màu hơn',
      'Hỗ trợ làm chậm quá trình thay đổi da tự nhiên, ngăn ngừa và cải thiện các dấu hiệu nám trên da.',
      'Nuôi dưỡng làn da sáng hồng và mịn màng từ sâu bên trong.',
      'Ngoài ra, các thành phần dưỡng chất, vitamin có trong sản phẩm còn góp phần tăng cường sức khỏe, nâng cao sức đề kháng cho người sử dụng.',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: benefits.map((benefit) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 14, color: Colors.black87)),
              Expanded(
                child: Text(
                  benefit,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _IngredientsList extends StatelessWidget {
  const _IngredientsList();

  @override
  Widget build(BuildContext context) {
    final ingredients = [
      'L-Cysteine: 240mg',
      'Vitamin C: 1000mg', 
      'Vitamin E',
      'Vitamin B2, B6',
      'Niacin',
      'Pantothenic acid',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: ingredients.map((ingredient) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 14, color: Colors.black87)),
              Expanded(
                child: Text(
                  ingredient,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
