import 'package:flutter/material.dart';
import 'action_row.dart';
import '../models/action_item.dart';

class ActionList extends StatelessWidget {
  final List<ActionItem> items;
  final Map<String, VoidCallback>? onTapCallbacks;
  const ActionList({super.key, required this.items, this.onTapCallbacks});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          for (final item in items)
            ActionRow(
              icon: item.icon, 
              imagePath: item.imagePath,
              title: item.title,
              onTap: onTapCallbacks?[item.title],
            ),
        ],
      ),
    );
  }
}
