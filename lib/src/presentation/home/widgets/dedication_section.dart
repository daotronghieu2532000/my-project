import 'package:flutter/material.dart';

class DedicationSection extends StatelessWidget {
  const DedicationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDedicationItem(
            icon: 'assets/images/icons/fire.png',
            text: 'Tận tâm',
          ),
          _buildDedicationItem(
            icon: 'assets/images/icons/handshake.png',
            text: 'Tận tình',
          ),
          _buildDedicationItem(
            icon: 'assets/images/icons/heart.png',
            text: 'Tận tụy',
          ),
        ],
      ),
    );
  }

  Widget _buildDedicationItem({
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

