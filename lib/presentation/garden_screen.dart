// ========== lib/presentation/garden_screen.dart ==========
import 'package:appforhumman/presentation/shop_screen.dart';
import 'package:appforhumman/presentation/watering_flowers_screen.dart';
import 'package:flutter/material.dart';

import '../../domain/garden_logic.dart';
import '../../data/garden_data.dart';
import 'apple_picking_screen.dart';
import 'garden_seed_farm_screen.dart';
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
  String gardenName = 'My Secret Garden';
  bool isEditingName = false;
  late TextEditingController _nameController;
  String currentSeason = 'Spring';

  String _userId = '';
  int points = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: gardenName);
    _getCurrentUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null) {
      setState(() => _userId = user['uid'] ?? '');
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    final data = await _data.loadUserData(_userId);
    if (data != null && mounted) {
      setState(() {
        points = data['points'] ?? 0;
      });
    }
  }

  Future<void> _openSeedFarmGame() async {
    if (_userId.isEmpty) {
      _showSnackBar('Please log in first', Colors.red);
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GardenSeedFarmScreen(initialSeason: currentSeason),
      ),
    );
    if (mounted) await _loadUserData();
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
    final Color seasonColor = _logic.getSeasonIconColor(currentSeason);
    final List<Color> sky = _logic.seasonalFarmGradient(currentSeason);
    final String? heroImage = _logic.seasonalBackgroundAsset(currentSeason);
    final String farmThumb =
        heroImage ?? 'assets/images/watering/watering_bg_spring.png';

    return Scaffold(
      extendBody: true,
      backgroundColor: sky.last,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: sky,
                ),
              ),
            ),
          ),
          if (heroImage != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.28,
                  child: Image.asset(heroImage, fit: BoxFit.cover),
                ),
              ),
            ),
          _farmSilhouetteLayer(),
          SafeArea(
            child: _userId.isEmpty
                ? _buildNoUserWidget()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildHeader(seasonColor, farmThumb),
                        const SizedBox(height: 14),
                        _buildSeasonBanner(seasonColor),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                          child: Text(
                            _logic.seasonalRitualLine(currentSeason),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3D2914).withValues(alpha: 0.78),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSeasonPicker(),
                        const SizedBox(height: 18),
                        _buildSeedFarmEntryCard(seasonColor),
                        const SizedBox(height: 22),
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
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        ),
        backgroundColor: const Color(0xFFC1CFA1),
        shape: const CircleBorder(),
        child: const Icon(Icons.home, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// Trees + leaf accents for a light “Happy Farm” vibe.
  Widget _farmSilhouetteLayer() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: -6,
              bottom: 120,
              child: Opacity(
                opacity: 0.55,
                child: Image.asset(
                  'assets/images/tree_1.png',
                  width: 118,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              right: -16,
              bottom: 108,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/tree_2.png',
                  width: 132,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              right: 48,
              bottom: 132,
              child: Opacity(
                opacity: 0.38,
                child: Image.asset(
                  'assets/images/tree_3.png',
                  width: 72,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              top: 52,
              right: 20,
              child: Opacity(
                opacity: 0.22,
                child: Transform.rotate(
                  angle: -0.18,
                  child: Image.asset(
                    'assets/images/leaf_main.png',
                    width: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: 12,
              child: Icon(
                Icons.cloud_outlined,
                size: 56,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            Positioned(
              top: 140,
              right: 100,
              child: Icon(
                Icons.cloud_outlined,
                size: 40,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUserWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 80, color: const Color(0xff7f9461).withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No user logged in',
            style: TextStyle(color: Color(0xff7f9461), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Please log in to access your garden',
              style: TextStyle(color: const Color(0xff7f9461).withValues(alpha: 0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color accent, String farmThumbAsset) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            height: 88,
            width: 88,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF8B6914), width: 2.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  farmThumbAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFFC1CFA1)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.12),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Icon(Icons.eco_rounded, size: 48, color: Colors.white.withValues(alpha: 0.95)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4A574)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.stars_rounded, color: accent, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        '$points',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF5C4018),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Farm coins',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.brown.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10),
                    ],
                  ),
                  child: isEditingName
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter farm name',
                                ),
                                onSubmitted: (_) => _editGardenName(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Color(0xff7f9461)),
                              onPressed: _editGardenName,
                            ),
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
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4A3728),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.edit_rounded, size: 18, color: Colors.brown.shade400),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonBanner(Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.35),
            accent,
            accent.withValues(alpha: 0.35),
          ],
        ),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
    );
  }

  Widget _buildSeasonPicker() {
    const seasons = ['Spring', 'Summer', 'Autumn', 'Winter'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: seasons.map((season) {
          final bool isSelected = currentSeason == season;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Material(
              color: isSelected ? _logic.getSeasonIconColor(season) : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
              elevation: isSelected ? 4 : 0,
              child: InkWell(
                onTap: () => setState(() => currentSeason = season),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        _logic.getSeasonIconForPicker(season),
                        color: isSelected ? Colors.white : _logic.getSeasonIconColor(season),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        season,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeedFarmEntryCard(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 8,
        shadowColor: const Color(0xFF2D5016).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: _openSeedFarmGame,
          borderRadius: BorderRadius.circular(26),
          child: Ink(
            height: 152,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF8B6914), width: 2.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2D5016),
                  const Color(0xFF52734D),
                  accent.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                Positioned(
                  right: -20,
                  bottom: -24,
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.asset(
                      'assets/images/leaf_main.png',
                      width: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                        ),
                        child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 34),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Seed & harvest plots',
                              style: TextStyle(
                                color: Color(0xFFFFFDF5),
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                shadows: [
                                  Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Plant from your shed, grow in the field, tap ripe crops to collect coins.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_fill_rounded, color: Colors.amber.shade200, size: 46),
                          const SizedBox(height: 4),
                          Text(
                            'Play',
                            style: TextStyle(
                              color: Colors.amber.shade100,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniGamesCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F9461).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF7F9461).withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFF4A5C38),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Garden mini-games',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A3728),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Each game has its own style — tap a card to play and earn points.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: const Color(0xFF795548).withValues(alpha: 0.88),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                _buildDistinctGameCard(
                  gradient: const <Color>[
                    Color(0xFFB4232E),
                    Color(0xFFE85D04),
                  ],
                  borderGlow: const Color(0xFFFFB86C),
                  icon: Icons.shopping_basket_rounded,
                  emoji: '🍎',
                  title: 'Apple Picking',
                  tagline: 'Catch apples, build combos, beat the clock.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const ApplePickingScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _buildDistinctGameCard(
                  gradient: const <Color>[
                    Color(0xFF1B4332),
                    Color(0xFF52734D),
                  ],
                  borderGlow: const Color(0xFFB7E4C7),
                  icon: Icons.agriculture_rounded,
                  emoji: '🧺',
                  title: 'Harvest Run',
                  tagline: 'Fill basket orders from the field before time runs out.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const HarvestRunScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _buildDistinctGameCard(
                  gradient: const <Color>[
                    Color(0xFF0C4A6E),
                    Color(0xFF0891B2),
                  ],
                  borderGlow: const Color(0xFFBAE6FD),
                  icon: Icons.water_drop_rounded,
                  emoji: '💧',
                  title: 'Watering Flowers',
                  tagline: 'Water, feed, and care for every plant on time.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const WateringFlowersScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistinctGameCard({
    required List<Color> gradient,
    required Color borderGlow,
    required IconData icon,
    required String emoji,
    required String title,
    required String tagline,
    required VoidCallback onTap,
  }) {
    const double cardW = 118;
    const double cardH = 148;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: borderGlow.withValues(alpha: 0.35),
        highlightColor: borderGlow.withValues(alpha: 0.12),
        child: Ink(
          width: cardW,
          height: cardH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            border: Border.all(
              color: borderGlow.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      emoji,
                      style: const TextStyle(fontSize: 26, height: 1),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFFDF8),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.2,
                    shadows: <Shadow>[
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Text(
                      'Play',
                      style: TextStyle(
                        color: borderGlow.withValues(alpha: 0.98),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: borderGlow.withValues(alpha: 0.95),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
            _navItem(Icons.local_florist_outlined, 'Garden', 0),
            _navItem(Icons.storefront, 'Shop', 1),
            const SizedBox(width: 40),
            _navItem(Icons.bar_chart, 'Analytics', 3),
            _navItem(Icons.person_outline, 'Profile', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
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
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
