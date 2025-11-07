import 'package:flutter/material.dart';

class ServiceGuarantees extends StatelessWidget {
  const ServiceGuarantees({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildGuaranteeItem(
            icon: 'assets/images/icons/return.png',
            text: 'Trả hàng 15 ngày',
          ),
          _buildGuaranteeItem(
            icon: 'assets/images/icons/verified.png',
            text: 'Chính hãng 100%',
          ),
          _buildGuaranteeItem(
            icon: 'assets/images/icons/shipping1.png',
            text: 'Giao miễn phí',
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeItem({
    required String icon,
    required String text,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            icon,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.2,
              ),
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

