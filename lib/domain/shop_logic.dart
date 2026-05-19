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
      description:
          'Green in color; grows over about a day — daily activities keep the garden strong.',
      price: 7,
      inventoryKey: 'Regular Seeds',
    ),
    ShopItem(
      name: 'Rare Seeds',
      description:
          'Blue in color; needs a few days — skip today’s care and blooms fade faster.',
      price: 12,
      inventoryKey: 'Rare Seeds',
    ),
    ShopItem(
      name: 'Legendary Seeds',
      description:
          'Purple in color; a full week to mature — worth steady daily habits.',
      price: 20,
      inventoryKey: 'Legendary Seeds',
    ),
    ShopItem(
      name: 'Fertilizer',
      description:
          'Organic boost: each plant skips forward about one day of real grow time (not instant). Daily activities still shape garden vitality.',
      price: 35,
      inventoryKey: 'Fertilizer',
    ),
  ];

  IconData getItemIcon(String itemName) {
    switch (itemName) {
      case 'Regular Seeds':
        return Icons.grass;
      case 'Rare Seeds':
        return Icons.eco;
      case 'Legendary Seeds':
        return Icons.diamond_rounded;
      case 'Fertilizer':
        return Icons.eco_outlined;
      default:
        return Icons.inventory_2;
    }
  }
}
