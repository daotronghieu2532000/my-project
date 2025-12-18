import 'package:flutter/material.dart';

class ActionItem {
  final IconData? icon;
  final String? imagePath;
  final String title;
  final Color? iconColor;
  
  // Constructor for icon-based items (backward compatible)
  const ActionItem(IconData iconData, this.title, {this.iconColor}) 
      : icon = iconData,
        imagePath = null;
  
  // Constructor for image-based items
  const ActionItem.withImage(String path, this.title, {this.iconColor})
      : icon = null,
        imagePath = path;
}
