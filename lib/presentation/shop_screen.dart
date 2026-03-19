// ========== lib/presentation/shop_screen.dart ==========
import 'package:flutter/material.dart';
import '../../domain/shop_logic.dart';
import '../../data/shop_data.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';
import 'garden_screen.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final ShopLogic _logic = ShopLogic();
  final ShopData _data = ShopData();

  String _userId = '';
  int _userPoints = 0;
  bool _isLoading = true;

  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null) {
      setState(() => _userId = user['uid'] ?? '');
      _loadUserPoints();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserPoints() async {
    final points = await _data.loadUserPoints(_userId);
    if (mounted) {
      setState(() {
        _userPoints = points;
        _isLoading = false;
      });
    }
  }

  Future<void> _buyItem(ShopItem item) async {
    if (_userId.isEmpty) {
      _showSnackBar('Please log in first', Colors.red);
      return;
    }

    if (_userPoints < item.price) {
      _showSnackBar('Insufficient points to buy this item', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final success = await _data.buyItem(_userId, item, _userPoints);

    if (success && mounted) {
      setState(() {
        _userPoints -= item.price;
        _isLoading = false;
      });
      _showSnackBar('Purchase complete successfully', const Color(0xff7f9461));
    } else if (mounted) {
      setState(() => _isLoading = false);
      _showSnackBar('Error completing purchase', Colors.red);
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

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else if (index == 3) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AnalyticsPage()));
    } else if (index == 4) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    } else if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GardenPage()));
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xff7f9461)))
                : _userId.isEmpty
                ? _buildNoUserWidget()
                : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  _buildHeader(),
                  Container(
                    height: 40,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xffce7d88),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(50),
                        bottomRight: Radius.circular(50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xffce7d88).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCoinIcon(),
                            const SizedBox(width: 10),
                            Text(
                              "$_userPoints",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ..._logic.shopItems.map((item) => _buildShopItem(item)),
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
        elevation: 2,
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
              'Please log in to access the shop',
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
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFC1CFA1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.eco, size: 60, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Center(
                child: Text(
                  "Welcome to Shop!",
                  style: TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem(ShopItem item) {
    bool canAfford = _userPoints >= item.price;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffe89fa8).withOpacity(canAfford ? 1.0 : 0.5),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, 4), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.brown.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_logic.getItemIcon(item.name), color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildCoinIcon(size: 35),
              const SizedBox(width: 5),
              Text(
                '${item.price}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 18),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: canAfford ? () => _buyItem(item) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: canAfford ? const Color(0xff7f9461) : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('BUY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinIcon({double size = 24}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.orangeAccent,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: Colors.orange, width: 2)),
      ),
      child: Center(
        child: Icon(Icons.favorite, color: Colors.white, size: size * 0.6),
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
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xff7f9461) : Colors.grey,
              fontSize: isSelected ? 11 : 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

