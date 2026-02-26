import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'apple_picking_screen.dart';
import 'cutting_leaves_screen.dart';
import 'watering_flowers_screen.dart';



class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xff7f9461);
  static const Color colorGreenLight = Color(0xFFC1CFA1);
  static const Color colorAccentPink = Color(0xFFF2A6A6);

  int _selectedIndex = 0;
  String gardenName = "My Secret Garden";
  bool isEditingName = false;
  late TextEditingController _nameController;
  String currentSeason = 'Spring';

  Map<String, int> seedsInventory = {
    'Regular Seeds': 5,
    'Rare Seeds': 2,
    'Legendary Seeds': 1,
    'Growth Accelerator': 1,
  };

  int points = 0;

  List<PlantedItem> plantedItems = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: gardenName);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AnalyticsPage()),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ShopPage()),
      );
    }
  }

  void useSeed(String seedType) {
    if (seedsInventory[seedType]! > 0) {
      setState(() {
        seedsInventory[seedType] = seedsInventory[seedType]! - 1;

        if (seedType != 'Growth Accelerator') {
          Color seedColor = Colors.green;
          IconData seedIcon = Icons.spa;

          if (seedType == 'Regular Seeds') {
            seedColor = Colors.green;
          } else if (seedType == 'Rare Seeds') {
            seedColor = Colors.blue;
          } else if (seedType == 'Legendary Seeds') {
            seedColor = Colors.purple;
          }

          plantedItems.add(PlantedItem(
            seedType: seedType,
            color: seedColor,
            icon: seedIcon,
            position: Offset(
              (plantedItems.length % 5) * 50.0 + 30.0,
              ((plantedItems.length ~/ 5) % 3) * 50.0 + 30.0,
            ),
          ));
        } else {
          for (var item in plantedItems) {
            item.isAccelerated = true;
          }
        }
      });
    }
  }

  void playMiniGame() {
    setState(() {
      points += 10;
    });
  }

  Color getBoardColor() {
    switch (currentSeason) {
      case 'Spring':
        return Colors.green.shade100;
      case 'Summer':
        return Colors.yellow.shade100;
      case 'Autumn':
        return Colors.orange.shade100;
      case 'Winter':
        return Colors.blue.shade100;
      default:
        return Colors.green.shade100;
    }
  }

  IconData getSeasonIcon() {
    switch (currentSeason) {
      case 'Spring':
        return Icons.grass;
      case 'Summer':
        return Icons.wb_sunny;
      case 'Autumn':
        return Icons.eco;
      case 'Winter':
        return Icons.ac_unit;
      default:
        return Icons.grass;
    }
  }

  Color getSeasonIconColor() {
    switch (currentSeason) {
      case 'Spring':
        return Colors.green;
      case 'Summer':
        return Colors.yellow;
      case 'Autumn':
        return Colors.orange;
      case 'Winter':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: colorCream,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colorPinkish, Color(0xfff5d5d5), colorCream],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildHeader(),
                  Container(
                    height: 30,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: getSeasonIconColor(),
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(50)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSeasonPicker(),
                  const SizedBox(height: 15),
                  _buildGardenBoard(),
                  const SizedBox(height: 20),
                  _buildSeedsPanel(),
                  const SizedBox(height: 30),
                  _buildMiniGamesCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        backgroundColor: colorGreenLight,
        shape: const CircleBorder(),
        child: const Icon(Icons.home, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            height: 90,
            width: 90,
            decoration: BoxDecoration(
              color: colorGreenLight,
              borderRadius: BorderRadius.circular(45),
              border: Border.all(color: colorGreenDark, width: 3),
            ),
            child: const Icon(
              Icons.eco,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: isEditingName
                  ? TextField(
                      controller: _nameController,
                      autofocus: true,
                      onSubmitted: (val) {
                        setState(() {
                          gardenName = val;
                          isEditingName = false;
                        });
                      },
                      decoration:
                          const InputDecoration(border: InputBorder.none),
                    )
                  : InkWell(
                      onTap: () => setState(() => isEditingName = true),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              gardenName,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown),
                              maxLines: 1,
                            ),
                          ),
                          const Icon(Icons.edit, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonPicker() {
    List<String> seasons = ['Spring', 'Summer', 'Autumn', 'Winter'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: seasons.map((season) {
          bool isSelected = currentSeason == season;
          return GestureDetector(
            onTap: () => setState(() => currentSeason = season),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? getSeasonIconColor()
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        isSelected ? getSeasonIconColor() : Colors.transparent,
                    width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    _getSeasonIconForPicker(season),
                    color: isSelected ? Colors.white : getSeasonIconColor(),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    season,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black54,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getSeasonIconForPicker(String season) {
    switch (season) {
      case 'Spring':
        return Icons.grass;
      case 'Summer':
        return Icons.wb_sunny;
      case 'Autumn':
        return Icons.eco;
      case 'Winter':
        return Icons.ac_unit;
      default:
        return Icons.grass;
    }
  }

  Widget _buildGardenBoard() {
    return Container(
      width: 320,
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: getBoardColor(),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.3,
            child: Icon(
              getSeasonIcon(),
              size: 120,
              color: getSeasonIconColor().withOpacity(0.7),
            ),
          ),
          ...plantedItems.map((item) {
            return Positioned(
              left: item.position.dx,
              top: item.position.dy,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    plantedItems.remove(item);
                  });
                },
                child: Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: item.color.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        item.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (item.isAccelerated)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(
                            Icons.bolt,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (plantedItems.isEmpty)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  getSeasonIcon(),
                  size: 60,
                  color: getSeasonIconColor(),
                ),
                const SizedBox(height: 10),
                Text(
                  "Plant seeds from inventory",
                  style: TextStyle(
                    color: getSeasonIconColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSeedsPanel() {
    List<MapEntry<String, int>> seedEntries = seedsInventory.entries.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Seeds Inventory",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorGreenDark,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: seedEntries.map((entry) {
              return _buildSeedCard(entry.key, entry.value);
            }).toList(),
          ),
          const SizedBox(height: 15),
          Text(
            "Tap seeds to plant on board. Growth Accelerator speeds up all planted seeds.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSeedCard(String seedType, int quantity) {
    IconData seedIcon = Icons.spa;
    Color seedColor = Colors.green;

    if (seedType == 'Rare Seeds') {
      seedColor = Colors.blue;
    } else if (seedType == 'Legendary Seeds') {
      seedColor = Colors.purple;
    } else if (seedType == 'Growth Accelerator') {
      seedIcon = Icons.bolt;
      seedColor = Colors.orange;
    }

    return GestureDetector(
      onTap: quantity > 0 ? () => useSeed(seedType) : null,
      child: Opacity(
        opacity: quantity > 0 ? 1.0 : 0.4,
        child: Container(
          width: 85,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: seedColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: seedColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                seedIcon,
                color: seedColor,
                size: 26,
              ),
              const SizedBox(height: 6),
              Text(
                _getShortName(seedType),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: seedColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$quantity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: quantity > 0 ? seedColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getShortName(String fullName) {
    if (fullName == 'Growth Accelerator') return 'Accelerator';
    if (fullName == 'Legendary Seeds') return 'Legendary';
    if (fullName == 'Regular Seeds') return 'Regular';
    if (fullName == 'Rare Seeds') return 'Rare';
    return fullName;
  }

  // lib/screens/garden_page.dart (الجزء المعدل فقط)

  Widget _buildMiniGamesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.games, color: Color(0xffce7d88)),
              SizedBox(width: 8),
              Text(
                "Mini Games",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffce7d88),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            "Play games to earn points!",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Apple Picking Game Button - المعدل
                GestureDetector(
                  onTap: () {
                    // فقط يوجه إلى صفحة اللعبة بدون إضافة نقاط
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ApplePickingScreen()),
                    );
                  },
                  child: _buildGameButton("Apple\nPicking 🍎", Icons.apple),
                ),
                const SizedBox(width: 12),

                // Leaves Cutting Game Button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CuttingLeavesScreen()),
                    );
                  },
                  child: _buildGameButton("Leaves\nCutting 🍃", Icons.forest),
                ),
                const SizedBox(width: 12),

                // Watering Flowers Game Button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WateringFlowersScreen()),
                    );
                  },
                  child: _buildGameButton("Watering\nFlowers 💦", Icons.water_drop),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

        ],
      ),
    );
  }

// تعديل دالة _buildGameButton لإزالة playMiniGame منها
  Widget _buildGameButton(String label, IconData icon) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorGreenLight, colorGreenDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.local_florist_outlined, "Garden", 0),
            _navItem(Icons.storefront, "Shop", 1),
            const SizedBox(width: 40),
            _navItem(Icons.bar_chart, "Analytics", 3),
            _navItem(Icons.person_outline, "Profile", 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isSelected ? colorGreenDark : Colors.grey,
              size: isSelected ? 24 : 22),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: isSelected ? colorGreenDark : Colors.grey,
                  fontSize: isSelected ? 11 : 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
              maxLines: 1),
        ],
      ),
    );
  }
}

class PlantedItem {
  final String seedType;
  final Color color;
  final IconData icon;
  final Offset position;
  bool isAccelerated;

  PlantedItem({
    required this.seedType,
    required this.color,
    required this.icon,
    required this.position,
    this.isAccelerated = false,
  });
}
