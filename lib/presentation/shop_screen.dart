// ========== lib/presentation/shop_screen.dart ==========
import 'package:flutter/material.dart';
import '../../domain/shop_logic.dart';
import '../../data/shop_data.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'profile_screen.dart';
import 'garden_screen.dart';
import 'widgets/main_top_app_bar.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with SingleTickerProviderStateMixin {
  final ShopLogic _logic = ShopLogic();
  final ShopData _data = ShopData();

  String _userId = '';
  int _userPoints = 0;
  bool _isLoading = true;
  String? _buyingItemKey;
  Map<String, int> _inventoryCounts = <String, int>{};

  int _selectedIndex = 1;

  static const List<List<Color>> _shopCardPalettes = <List<Color>>[
    <Color>[Color(0xFFFFE6D7), Color(0xFFFFB88C)],
    <Color>[Color(0xFFE5EEFF), Color(0xFF9DBDFF)],
    <Color>[Color(0xFFEAF9E7), Color(0xFFA7DE96)],
    <Color>[Color(0xFFF5E8FF), Color(0xFFCDA8FF)],
    <Color>[Color(0xFFFFEAF2), Color(0xFFFFA4C7)],
  ];
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _getCurrentUser();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
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
    final inventory = await _data.loadUserInventory(_userId);
    if (mounted) {
      setState(() {
        _userPoints = points;
        _inventoryCounts = inventory;
        _isLoading = false;
      });
    }
  }

  Future<void> _buyItem(ShopItem item) async {
    if (_buyingItemKey != null) return;
    if (_userId.isEmpty) {
      _showSnackBar('Please log in first', Colors.red);
      return;
    }

    if (_userPoints < item.price) {
      _showSnackBar('Insufficient points to buy this item', Colors.orange);
      return;
    }

    setState(() => _buyingItemKey = item.inventoryKey);

    final success = await _data.buyItem(_userId, item, _userPoints);

    if (success && mounted) {
      setState(() {
        _userPoints -= item.price;
        _inventoryCounts[item.inventoryKey] = (_inventoryCounts[item.inventoryKey] ?? 0) + 1;
        _buyingItemKey = null;
      });
      _showSnackBar('Purchase complete successfully', const Color(0xff7f9461));
    } else if (mounted) {
      setState(() => _buyingItemKey = null);
      _showSnackBar('Error completing purchase', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                colors: [
                  Color(0xFFEBD9DC),
                  Color(0xFFF2E5D9),
                  Color(0xFFE8F2E3),
                  Color(0xFFD1E2CF),
                ],
                stops: [0.0, 0.32, 0.7, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? _buildLoadingShimmer()
                : _userId.isEmpty
                ? _buildNoUserWidget()
                : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: MainTopAppBar(title: 'Shop', coins: _userPoints),
                  ),
                  const SizedBox(height: 12),
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildInventorySummaryCard(),
                  const SizedBox(height: 20),
                  ..._logic.shopItems
                      .asMap()
                      .entries
                      .map((entry) => _buildShopItem(entry.value, entry.key)),
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xff7f9461).withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff7f9461).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.storefront_rounded, size: 30, color: Color(0xff5f7744)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Grow your garden with new seeds and tools.",
                style: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xff5f7744),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySummaryCard() {
    final int totalOwned = _logic.shopItems.fold<int>(
      0,
      (int sum, ShopItem item) => sum + (_inventoryCounts[item.inventoryKey] ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFF4DE),
              Color(0xFFFDE2C2),
              Color(0xFFE6F3D8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xffC9872F).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffD08E3A).withValues(alpha: 0.2),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffC9872F).withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: Color(0xffB06B1E), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Your Inventory',
                    style: TextStyle(
                      color: Color(0xff9A5A16),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xffC9872F),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$totalOwned items',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Track how many seeds and tools you currently own.',
              style: TextStyle(
                color: const Color(0xff8A622E).withValues(alpha: 0.86),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _logic.shopItems.map((ShopItem item) {
                final int count = _inventoryCounts[item.inventoryKey] ?? 0;
                final bool hasAny = count > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: hasAny
                        ? Colors.white.withValues(alpha: 0.95)
                        : const Color(0xffF7E8D0).withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasAny
                          ? const Color(0xffC9872F).withValues(alpha: 0.4)
                          : const Color(0xffB88138).withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 22,
                        width: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xffFFF1DE),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          _logic.getItemIcon(item.name),
                          size: 13,
                          color: const Color(0xffA9651D),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        item.name,
                        style: TextStyle(
                          color: const Color(0xff8C5314).withValues(alpha: hasAny ? 1 : 0.78),
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasAny
                              ? const Color(0xffC9872F).withValues(alpha: 0.23)
                              : const Color(0xffC9872F).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'x$count',
                          style: TextStyle(
                            color: const Color(0xff8B4E0D).withValues(alpha: hasAny ? 1 : 0.82),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopItem(ShopItem item, int index) {
    final bool canAfford = _userPoints >= item.price;
    final int missingCoins = canAfford ? 0 : (item.price - _userPoints);
    final bool isBuyingThisItem = _buyingItemKey == item.inventoryKey;
    final List<Color> palette = _shopCardPalettes[index % _shopCardPalettes.length];
    final Color accent = Color.lerp(palette.last, const Color(0xff2e2e2e), 0.4)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: canAfford
              ? <Color>[
                  palette.first.withValues(alpha: 0.98),
                  palette.last.withValues(alpha: 0.95),
                ]
              : <Color>[
                  palette.first.withValues(alpha: 0.6),
                  palette.last.withValues(alpha: 0.56),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canAfford
              ? accent.withValues(alpha: 0.32)
              : Colors.grey.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Icon(
                  _logic.getItemIcon(item.name),
                  color: accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xff5f7744),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: const Color(0xff5f7744).withOpacity(0.84),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCoinIcon(size: 28),
              const SizedBox(width: 6),
              Text(
                '${item.price}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xff5f7744),
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (isBuyingThisItem) {
                    return;
                  }
                  if (!canAfford) {
                    _showSnackBar(
                      'You need $missingCoins more points to buy ${item.name}.',
                      Colors.orange,
                    );
                    return;
                  }
                  _buyItem(item);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAfford ? const Color(0xff7f9461) : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 0,
                ),
                child: Text(
                  isBuyingThisItem
                      ? ''
                      : (canAfford ? 'BUY' : 'LOCKED'),
                  style: isBuyingThisItem
                      ? null
                      : const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                ),
              ),
            ],
          ),
          if (isBuyingThisItem) ...[
            const SizedBox(height: 8),
            _buildShimmerLine(
              height: 10,
              borderRadius: 99,
              baseColor: const Color(0xffd9e7c8),
              highlightColor: Colors.white.withValues(alpha: 0.85),
            ),
          ],
          if (!canAfford) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.28)),
              ),
              child: Text(
                'Need $missingCoins more points to unlock this item.',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          
        ],
        ])
    );
  }

  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildShimmerLine(
            height: 68,
            horizontalMargin: 20,
            borderRadius: 22,
            baseColor: const Color(0xffd9e7c8),
            highlightColor: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          _buildShimmerLine(
            height: 82,
            horizontalMargin: 20,
            borderRadius: 22,
            baseColor: const Color(0xffe4edd8),
            highlightColor: Colors.white.withValues(alpha: 0.82),
          ),
          const SizedBox(height: 14),
          ...List<Widget>.generate(4, (int i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              child: _buildShimmerLine(
                height: 132,
                borderRadius: 18,
                baseColor: i.isEven
                    ? const Color(0xffe6f1f8)
                    : const Color(0xfff3e7de),
                highlightColor: Colors.white.withValues(alpha: 0.82),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShimmerLine({
    required double height,
    double horizontalMargin = 0,
    required double borderRadius,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: baseColor,
      ),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (BuildContext context, Widget? child) {
          final double t = _shimmerController.value;
          final double beginX = -1.2 + (2.4 * t);
          final double endX = beginX + 0.9;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment(beginX, -0.3),
                end: Alignment(endX, 0.3),
                colors: <Color>[
                  baseColor.withValues(alpha: 0.65),
                  highlightColor,
                  baseColor.withValues(alpha: 0.65),
                ],
                stops: const <double>[0.2, 0.5, 0.8],
              ),
            ),
          );
        },
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
      notchMargin: 6,
      child: SizedBox(
        height: 58,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.local_florist_outlined, "Garden", 0),
            _navItem(Icons.storefront_outlined, "Shop", 1),
            const SizedBox(width: 36),
            _navItem(Icons.bar_chart_rounded, "Analytics", 3),
            _navItem(Icons.person_outline_rounded, "Profile", 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
        mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xff7f9461) : Colors.grey,
              size: isSelected ? 22 : 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? const Color(0xff7f9461) : Colors.grey,
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

