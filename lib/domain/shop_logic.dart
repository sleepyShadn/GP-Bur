// ========== lib/domain/shop_logic.dart ==========
import 'package:flutter/material.dart';

class ShopItem {
  final String name;
  final String description;
  final int price;
  final String inventoryKey;

  ShopItem({
    required this.name,
    required this.description,
    required this.price,
    required this.inventoryKey,
  });
}

class ShopLogic {
  final Color colorPinkish = const Color(0xFFE7CCCC);
  final Color colorCream = const Color(0xFFEDE8DC);
  final Color colorGreenDark = const Color(0xff7f9461);
  final Color colorGreenLight = const Color(0xFFC1CFA1);

  final List<ShopItem> shopItems = [
    ShopItem(
      name: 'Regular Seeds',
      description: 'Green in color; takes one minute to grow.',
      price: 7,
      inventoryKey: 'Regular Seeds',
    ),
    ShopItem(
      name: 'Rare Seeds',
      description: 'Blue in color; takes six minutes to grow.',
      price: 12,
      inventoryKey: 'Rare Seeds',
    ),
    ShopItem(
      name: 'Legendary Seeds',
      description: 'Purple in color; takes 15 minutes to grow.',
      price: 20,
      inventoryKey: 'Legendary Seeds',
    ),
    ShopItem(
      name: 'Growth Accelerator',
      description: 'Reduced speed immediately.',
      price: 35,
      inventoryKey: 'Growth Accelerator',
    ),
  ];

  IconData getItemIcon(String itemName) {
    switch (itemName) {
      case 'Regular Seeds':
        return Icons.grass;
      case 'Rare Seeds':
        return Icons.eco;
      case 'Legendary Seeds':
        return Icons.auto_awesome;
      case 'Growth Accelerator':
        return Icons.speed;
      default:
        return Icons.inventory_2;
    }
  }
}
