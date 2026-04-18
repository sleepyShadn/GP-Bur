// ========== lib/presentation/garden_screen.dart ==========
import 'package:appforhumman/presentation/shop_screen.dart';
import 'package:appforhumman/presentation/watering_flowers_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../domain/garden_logic.dart';
import '../../data/garden_data.dart';
import 'apple_picking_screen.dart';
import 'harvest_run_screen.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';


class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  final GardenLogic _logic = GardenLogic();
  final GardenData _data = GardenData();

  int _selectedIndex = 0;
  String gardenName = "My Secret Garden";
  bool isEditingName = false;
  late TextEditingController _nameController;
  String currentSeason = 'Spring';

  String _userId = '';
  int points = 0;

  Map<String, int> seedsInventory = {
    'Regular Seeds': 2,
    'Rare Seeds': 2,
    'Legendary Seeds': 2,
    'Growth Accelerator': 1,
  };

  List<PlantedItem> plantedItems = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: gardenName);
    _getCurrentUser();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdowns();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _updateCountdowns() {
    setState(() {
      for (var item in plantedItems) {
        if (!item.isFullyGrown && item.plantTime != null) {
          item.updateRemainingTime();
        }
      }
    });
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null) {
      setState(() => _userId = user['uid'] ?? '');
      _loadUserData();
      _loadGardenData();
    }
  }

  Future<void> _loadUserData() async {
    final data = await _data.loadUserData(_userId);
    if (data != null && mounted) {
      setState(() {
        points = data['points'] ?? 0;
        seedsInventory = data['seedsInventory'] ?? {};
      });
    }
  }

  Future<void> _loadGardenData() async {
    final items = await _data.loadGardenData(_userId, _logic.getSeedColor);
    if (items != null && mounted) {
      setState(() => plantedItems = items);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editGardenName() {
    final result = _logic.validateGardenName(_nameController.text.trim());
    if (result != null) {
      _showSnackBar(result, Colors.red);
      return;
    }

    setState(() {
      gardenName = _nameController.text.trim();
      isEditingName = false;
    });

    _showSnackBar('Garden Name updated successfully', const Color(0xff7f9461));
    _data.updateGardenName(_userId, gardenName);
  }

  Future<void> useSeed(String seedType) async {
    if (_userId.isEmpty) {
      _showSnackBar('Please log in first', Colors.red);
      return;
    }

    if (seedsInventory[seedType]! <= 0) {
      _showSnackBar('You don\'t have this item in your inventory', Colors.orange);
      return;
    }

    if (seedType == 'Growth Accelerator') {
      await _useGrowthAccelerator();
    } else {
      await _plantSeed(seedType);
    }
  }

  Future<void> _plantSeed(String seedType) async {
    try {
      final posX = 30 + (plantedItems.length % 5) * 50.0;
      final posY = 30 + ((plantedItems.length ~/ 5) % 3) * 50.0;
      final durationSeconds = _logic.getSeedDuration(seedType);
      final plantTime = DateTime.now();

      final docId = await _data.plantSeed(
        _userId,
        seedType,
        plantTime,
        durationSeconds,
        posX,
        posY,
      );

      if (docId != null && mounted) {
        setState(() {
          seedsInventory[seedType] = seedsInventory[seedType]! - 1;
          plantedItems.add(PlantedItem(
            id: docId,
            seedType: seedType,
            color: _logic.getSeedColor(seedType),
            icon: Icons.spa,
            position: Offset(posX, posY),
            isAccelerated: false,
            plantTime: plantTime,
            durationSeconds: durationSeconds,
            remainingSeconds: durationSeconds,
            isFullyGrown: false,
            docId: docId,
          ));
        });

        await _data.updateSeedsInventory(_userId, seedType, seedsInventory[seedType]!);
      }
    } catch (e) {
      print('Error planting seed: $e');
      _showSnackBar('Error planting seed', Colors.red);
    }
  }

  Future<void> _useGrowthAccelerator() async {
    if (plantedItems.isEmpty) {
      _showSnackBar('No plants to accelerate', Colors.orange);
      return;
    }

    try {
      setState(() {
        seedsInventory['Growth Accelerator'] = seedsInventory['Growth Accelerator']! - 1;
      });

      for (var item in plantedItems) {
        if (!item.isFullyGrown) {
          await _data.acceleratePlant(_userId, item.docId);
          item.applyAccelerator();
        }
      }

      await _data.updateSeedsInventory(_userId, 'Growth Accelerator', seedsInventory['Growth Accelerator']!);
      _showSnackBar('Growth Accelerator applied successfully!', const Color(0xff7f9461));
    } catch (e) {
      print('Error using accelerator: $e');
      _showSnackBar('Error using accelerator', Colors.red);
    }
  }

  Future<void> _harvestPlant(PlantedItem item) async {
    if (!item.isFullyGrown) return;

    try {
      final harvestPoints = _logic.getHarvestPoints(item.seedType);

      await _data.harvestPlant(_userId, item.docId, harvestPoints);

      if (mounted) {
        setState(() {
          points += harvestPoints;
          plantedItems.remove(item);
        });
        _showSnackBar('Harvested! +$harvestPoints points', const Color(0xff7f9461));
      }
    } catch (e) {
      print('Error harvesting: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else if (index == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AnalyticsPage()));
    } else if (index == 4) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ShopPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFEDE8DC),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE7CCCC), Color(0xfff5d5d5), Color(0xFFEDE8DC)],
              ),
            ),
          ),
          SafeArea(
            child: _userId.isEmpty
                ? _buildNoUserWidget()
                : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildHeader(),
                  Container(
                    height: 30,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _logic.getSeasonIconColor(currentSeason),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(50)),
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
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
        backgroundColor: const Color(0xFFC1CFA1),
        shape: const CircleBorder(),
        child: const Icon(Icons.home, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNoUserWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 80, color: const Color(0xff7f9461).withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No user logged in', style: TextStyle(color: Color(0xff7f9461), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Please log in to access your garden',
              style: TextStyle(color: const Color(0xff7f9461).withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
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
              color: const Color(0xFFC1CFA1),
              borderRadius: BorderRadius.circular(45),
              border: Border.all(color: const Color(0xff7f9461), width: 3),
            ),
            child: const Icon(Icons.eco, size: 60, color: Colors.white),
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
                  ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter garden name'),
                      onSubmitted: (_) => _editGardenName(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.check, color: Color(0xff7f9461)), onPressed: _editGardenName),
                ],
              )
                  : InkWell(
                onTap: () {
                  _nameController.text = gardenName;
                  setState(() => isEditingName = true);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        gardenName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                color: isSelected ? _logic.getSeasonIconColor(season) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? _logic.getSeasonIconColor(season) : Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    _logic.getSeasonIconForPicker(season),
                    color: isSelected ? Colors.white : _logic.getSeasonIconColor(season),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    season,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black54,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildGardenBoard() {
    return Container(
      width: 320,
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _logic.getBoardColor(currentSeason),
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
              _logic.getSeasonIcon(currentSeason),
              size: 120,
              color: _logic.getSeasonIconColor(currentSeason).withOpacity(0.7),
            ),
          ),
          ...plantedItems.map((item) {
            return Positioned(
              left: item.position.dx,
              top: item.position.dy,
              child: GestureDetector(
                onTap: () {
                  if (item.isFullyGrown) _harvestPlant(item);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.isFullyGrown ? item.color.withOpacity(0.9) : item.color.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: item.isFullyGrown ? Colors.yellow : Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: item.color.withOpacity(0.5), blurRadius: 8)],
                      ),
                      child: Icon(item.isFullyGrown ? Icons.spa : item.icon, color: Colors.white, size: 24),
                    ),
                    if (!item.isFullyGrown)
                      Positioned(
                        bottom: -15,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            _logic.formatTime(item.remainingSeconds),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    if (item.isAccelerated)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(Icons.bolt, color: Colors.white, size: 10),
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
                Icon(_logic.getSeasonIcon(currentSeason), size: 60, color: _logic.getSeasonIconColor(currentSeason)),
                const SizedBox(height: 10),
                Text("Plant seeds from inventory", style: TextStyle(color: _logic.getSeasonIconColor(currentSeason), fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSeedsPanel() {
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
          const Text("Seeds Inventory", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff7f9461))),
          const SizedBox(height: 15),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: seedsInventory.entries.map((entry) => _buildSeedCard(entry.key, entry.value)).toList(),
          ),
          const SizedBox(height: 15),
          Text(
            "Tap seeds to plant. Growth Accelerator speeds up all plants.",
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSeedCard(String seedType, int quantity) {
    final seedInfo = _logic.getSeedInfo(seedType);
    bool hasItem = quantity > 0;

    return GestureDetector(
      onTap: () => useSeed(seedType),
      child: Opacity(
        opacity: hasItem ? 1.0 : 0.4,
        child: Container(
          width: 85,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: seedInfo['color'].withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: seedInfo['color'].withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(seedInfo['icon'], color: seedInfo['color'], size: 26),
              const SizedBox(height: 6),
              Text(seedInfo['displayName'], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: seedInfo['color']), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                '$quantity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: hasItem ? seedInfo['color'] : Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              Text("Mini Games", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xffce7d88))),
            ],
          ),
          const SizedBox(height: 15),
          const Text("Play games to earn points!", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplePickingScreen())),
                  child: _buildGameButton("Apple\nPicking 🍎", Icons.shopping_basket),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HarvestRunScreen())),
                  child: _buildGameButton("Harvest\nRun 🧺", Icons.shopping_basket_outlined),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WateringFlowersScreen())),
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

  Widget _buildGameButton(String label, IconData icon) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC1CFA1), Color(0xff7f9461)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
          Icon(icon, color: isSelected ? const Color(0xff7f9461) : Colors.grey, size: isSelected ? 24 : 22),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                color: isSelected ? const Color(0xff7f9461) : Colors.grey,
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1),
        ],
      ),
    );
  }
}

class PlantedItem {
  final String id;
  final String seedType;
  final Color color;
  final IconData icon;
  final Offset position;
  bool isAccelerated;
  DateTime? plantTime;
  int durationSeconds;
  int remainingSeconds;
  bool isFullyGrown;
  final String docId;

  PlantedItem({
    required this.id,
    required this.seedType,
    required this.color,
    required this.icon,
    required this.position,
    required this.isAccelerated,
    this.plantTime,
    required this.durationSeconds,
    required this.remainingSeconds,
    required this.isFullyGrown,
    required this.docId,
  });

  void updateRemainingTime() {
    if (plantTime != null && !isFullyGrown) {
      DateTime finishTime = plantTime!.add(Duration(seconds: durationSeconds));
      DateTime now = DateTime.now();
      if (now.isAfter(finishTime)) {
        isFullyGrown = true;
        remainingSeconds = 0;
      } else {
        remainingSeconds = finishTime.difference(now).inSeconds;
      }
    }
  }

  void applyAccelerator() {
    isAccelerated = true;
    isFullyGrown = true;
    remainingSeconds = 0;
  }
}

