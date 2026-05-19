// ========== lib/presentation/profile_screen.dart ==========
import 'package:appforhumman/presentation/shop_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../domain/profile_logic.dart';
import '../../data/profile_data.dart';

import 'analysis_screen.dart';
import 'garden_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'widgets/main_top_app_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final ProfileLogic _logic = ProfileLogic();
  final ProfileData _data = ProfileData();

  int _selectedIndex = 4;

  String uid = "";
  String userName = "";
  String userEmail = "";
  DateTime birthDate = DateTime.now();
  double weight = 0.0;
  double height = 0.0;
  String gender = "";
  int totalPoints = 0;
  int userRank = 0;
  int totalUsers = 0;
  Timestamp? createdAt;
  String? selectedProfileImageBase64;
  List<String> _availableProfileImages = <String>[];

  Map<String, dynamic> seedsInventory = {};

  bool isLoading = true;
  bool isEditing = false;
  bool _isUploadingProfileImage = false;
  late final AnimationController _shimmerController;

  String? _nameError;
  String? _emailError;
  String? _birthDateError;
  String? _weightError;
  String? _heightError;
  String? _genderError;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _birthDateController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  final List<String> genderOptions = ["Male", "Female"];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _initializeControllers();
    _loadAvailableProfileImages();
    _loadUserData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _birthDateController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final userData = await _data.loadUserData();
      if (userData != null) {
        setState(() {
          uid = userData['uid'] ?? "";
          userName = userData['name'] ?? "";
          userEmail = userData['email'] ?? "";
          selectedProfileImageBase64 = userData['profileImageBase64'] as String?;
          createdAt = userData['createdAt'];
          birthDate = userData['birthDate'] ?? DateTime.now();
          weight = userData['weight'] ?? 0.0;
          height = userData['height'] ?? 0.0;
          gender = userData['gender'] ?? "";
          totalPoints = userData['points'] ?? 0;
          seedsInventory = userData['seedsInventory'] ?? {};
          userRank = userData['rank'] ?? 0;
          totalUsers = userData['totalUsers'] ?? 0;
          _updateControllers();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load profile data');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAvailableProfileImages() async {
    try {
      final String rawManifest = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(rawManifest) as Map<String, dynamic>;
      final List<String> images = manifestMap.keys
          .where((String path) =>
              path.startsWith('assets/images/profile/') &&
              (path.endsWith('.png') ||
                  path.endsWith('.jpg') ||
                  path.endsWith('.jpeg') ||
                  path.endsWith('.webp')))
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _availableProfileImages = images;
      });
    } catch (_) {}
  }

  void _updateControllers() {
    _nameController.text = userName;
    _emailController.text = userEmail;
    _birthDateController.text = _logic.formatDate(birthDate);
    _weightController.text = weight.toString();
    _heightController.text = height.toString();
  }

  void _onNameChanged(String value) {
    setState(() => _nameError = _logic.validateName(value));
  }

  void _onEmailChanged(String value) {
    setState(() => _emailError = _logic.validateEmail(value));
  }

  void _onWeightChanged(String value) {
    setState(() => _weightError = _logic.validateWeight(value));
  }

  void _onHeightChanged(String value) {
    setState(() => _heightError = _logic.validateHeight(value));
  }

  bool _validateAllInputs() {
    setState(() {
      _nameError = _logic.validateName(_nameController.text);
      _emailError = _logic.validateEmail(_emailController.text);
      _birthDateError = _logic.validateBirthDate(_birthDateController.text);
      _weightError = _logic.validateWeight(_weightController.text);
      _heightError = _logic.validateHeight(_heightController.text);
      _genderError = _logic.validateGender(gender);
    });
    return _nameError == null && _emailError == null && _birthDateError == null && _weightError == null && _heightError == null && _genderError == null;
  }

  Future<void> _updateUserData() async {
    if (!_validateAllInputs()) {
      _showErrorSnackBar('Please fix the errors before saving');
      return;
    }
    setState(() => isLoading = true);
    final userData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'gender': gender,
      'dateOfBirth': _birthDateController.text,
      'weight': double.parse(_weightController.text.trim()),
      'height': double.parse(_heightController.text.trim()),
    };
    final success = await _data.updateUserData(uid, userData);
    if (success) {
      setState(() {
        isEditing = false;
        _nameError = null;
        _emailError = null;
        _birthDateError = null;
        _weightError = null;
        _heightError = null;
        _genderError = null;
      });
      await _loadUserData();
      _showSuccessSnackBar('Profile updated successfully');
    } else {
      _showErrorSnackBar('Failed to update profile');
      setState(() => isEditing = false);
    }
    setState(() => isLoading = false);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff7f9461),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Uint8List? _profileImageBytes() {
    final String? raw = selectedProfileImageBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _onPickProfileImage(String assetPath) async {
    final String currentUid = uid;
    if (currentUid.isEmpty) {
      _showErrorSnackBar('Please wait until profile data is loaded');
      return;
    }
    setState(() => _isUploadingProfileImage = true);
    String base64Image;
    try {
      final ByteData data = await rootBundle.load(assetPath);
      base64Image = base64Encode(data.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _isUploadingProfileImage = false);
      _showErrorSnackBar('Failed to read selected image');
      return;
    }
    final bool updated = await _data.updateUserData(currentUid, <String, dynamic>{
      'profileImageBase64': base64Image,
    });
    if (!mounted) return;
    if (updated) {
      setState(() {
        selectedProfileImageBase64 = base64Image;
        _isUploadingProfileImage = false;
      });
      _showSuccessSnackBar('Profile image updated');
    } else {
      setState(() => _isUploadingProfileImage = false);
      _showErrorSnackBar('Failed to update profile image');
    }
  }

  void _showProfileImagePicker() {
    if (_availableProfileImages.isEmpty) {
      _showErrorSnackBar('No profile images found in assets/images/profile/');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Choose Profile Image',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff5f7744),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: GridView.builder(
                    itemCount: _availableProfileImages.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final String assetPath = _availableProfileImages[index];
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          await _onPickProfileImage(assetPath);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFC1CFA1),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFEDE8DC),
                                child: const Icon(Icons.person, color: Color(0xff7f9461)),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: birthDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xff7f9461),
              onPrimary: Colors.white,
              surface: Color(0xFFEDE8DC),
              onSurface: Color(0xff7f9461),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        birthDate = picked;
        _birthDateController.text = _logic.formatDate(picked);
        _birthDateError = _logic.validateBirthDate(_birthDateController.text);
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      isEditing = !isEditing;
      if (isEditing) {
        _updateControllers();
        _nameError = null;
        _emailError = null;
        _birthDateError = null;
        _weightError = null;
        _heightError = null;
        _genderError = null;
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      _updateControllers();
      gender = gender;
      _nameError = null;
      _emailError = null;
      _birthDateError = null;
      _weightError = null;
      _heightError = null;
      _genderError = null;
    });
  }

  void _changePassword() {
    _showInfoDialog('Change Password', 'Password change feature will be available soon');
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.98),
                const Color(0xffeef5e3).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xff7f9461).withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff7f9461).withOpacity(0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xff7f9461).withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Color(0xff5f7744), size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'Confirm Logout',
                style: TextStyle(
                  color: Color(0xff5f7744),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can sign in again anytime to continue your progress.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xff5f7744).withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xff7f9461).withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xff5f7744), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        setState(() => isLoading = true);
                        await _data.logout();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const Login()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff7f9461),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.98),
                const Color(0xFFFFEDEE).withOpacity(0.96),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.red.withOpacity(0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 31),
              ),
              const SizedBox(height: 12),
              const Text(
                'Delete Account?',
                style: TextStyle(
                  color: Color(0xff5f7744),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will permanently remove your profile data and cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff6f6f6f),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.withOpacity(0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Keep Account',
                        style: TextStyle(color: Color(0xff5f7744), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        setState(() => isLoading = true);
                        final bool deleted = await _data.deleteAccount();
                        if (!mounted) return;
                        if (deleted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const Login()),
                            (route) => false,
                          );
                        } else {
                          setState(() => isLoading = false);
                          _showErrorSnackBar(
                            'Unable to delete account now. Please re-login and try again.',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade500,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onLogoClick() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
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
    } else {
      switch (index) {
        case 0:
          Navigator.push(context, MaterialPageRoute(builder: (_) => GardenPage()));
          break;
        case 1:
          Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage()));
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: isLoading
              ? _buildLoadingShimmer()
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildAppBar(),
                if (createdAt != null) _buildCreatedAtBanner(),
                const SizedBox(height: 24),
                _buildProfileHeader(),
                const SizedBox(height: 24),
                _buildRankingCard(),
                const SizedBox(height: 24),
                _buildPersonalInfoCard(),
                const SizedBox(height: 24),
                _buildSeedsInventoryCard(),
                const SizedBox(height: 24),
                _buildLogoutButton(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFloatingHomeButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildShimmerLine(
            height: 64,
            borderRadius: 18,
            baseColor: const Color(0xffd9e7c8),
            highlightColor: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 20),
          _buildShimmerLine(
            height: 140,
            borderRadius: 20,
            baseColor: const Color(0xffe6f1f8),
            highlightColor: Colors.white.withValues(alpha: 0.84),
          ),
          const SizedBox(height: 16),
          _buildShimmerLine(
            height: 170,
            borderRadius: 20,
            baseColor: const Color(0xfff3e7de),
            highlightColor: Colors.white.withValues(alpha: 0.82),
          ),
          const SizedBox(height: 16),
          _buildShimmerLine(
            height: 210,
            borderRadius: 20,
            baseColor: const Color(0xffedf4e5),
            highlightColor: Colors.white.withValues(alpha: 0.82),
          ),
          const SizedBox(height: 16),
          _buildShimmerLine(
            height: 170,
            borderRadius: 20,
            baseColor: const Color(0xffe9e3f4),
            highlightColor: Colors.white.withValues(alpha: 0.82),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLine({
    required double height,
    required double borderRadius,
    required Color baseColor,
    required Color highlightColor,
  }) {
    return Container(
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

  Widget _buildAppBar() {
    return Column(
      children: [
        MainTopAppBar(title: 'Profile', coins: totalPoints),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                "Your profile",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _logic.colorBrown,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isEditing)
              IconButton(
                icon: Icon(Icons.edit_outlined, color: _logic.colorBrown),
                onPressed: _toggleEditMode,
                tooltip: 'Edit Profile',
              ),
            if (isEditing) ...[
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: _cancelEdit,
                tooltip: 'Cancel',
              ),
              IconButton(
                icon: Icon(Icons.save, color: _logic.colorBrown),
                onPressed: _updateUserData,
                tooltip: 'Save',
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCreatedAtBanner() {
    DateTime dateTime = createdAt!.toDate();
    String formattedDate = "${_logic.getMonthName(dateTime.month)} ${dateTime.day}, ${dateTime.year} at ${_logic.formatTime(dateTime)}";
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _logic.colorBrown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _logic.colorBrown.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: _logic.colorBrown, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Member since: $formattedDate",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _logic.colorBrown,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7f9461).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFC1CFA1),
                      border: Border.all(color: const Color(0xff7f9461), width: 2),
                    ),
                      child: ClipOval(
                      child: _profileImageBytes() != null
                          ? Image.memory(
                              _profileImageBytes()!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 50,
                                color: Color(0xff7f9461),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 50,
                              color: Color(0xff7f9461),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _isUploadingProfileImage ? null : _showProfileImagePicker,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xff7f9461),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ),
                if (_isUploadingProfileImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isEditing
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      onChanged: _onNameChanged,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        labelStyle: const TextStyle(color: Color(0xff7f9461), fontWeight: FontWeight.bold),
                        errorText: _nameError,
                        errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xff7f9461), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff7f9461),
                      ),
                    ),
                  ],
                )
                    : Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff7f9461),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                isEditing
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _emailController,
                      onChanged: _onEmailChanged,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Color(0xff7f9461), fontWeight: FontWeight.bold),
                        errorText: _emailError,
                        errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xff7f9461), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff7f9461),
                      ),
                    ),
                  ],
                )
                    : Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff7f9461).withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isUploadingProfileImage)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Uploading profile image...',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff7f9461),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.star, color: const Color(0xff7f9461), size: 20),
                    const SizedBox(width: 6),
                    Text(
                      "$totalPoints Points",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff7f9461),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7f9461).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard, color: const Color(0xff7f9461), size: 24),
              const SizedBox(width: 10),
              Text(
                "Global Ranking",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff7f9461),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xff7f9461), width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "#$userRank",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff7f9461),
                        ),
                      ),
                      Text(
                        "Rank",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff7f9461).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  totalUsers > 0
                      ? "You are in the top ${((userRank / totalUsers) * 100).toStringAsFixed(1)}%"
                      : "Ranking available soon",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xff7f9461)),
                ),
                const SizedBox(height: 8),
                Text(
                  totalUsers > 0
                      ? "Out of $totalUsers total users"
                      : "Loading total users...",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff7f9461).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7f9461).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: const Color(0xff7f9461), size: 24),
              const SizedBox(width: 10),
              Text(
                "Personal Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff7f9461),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _birthDateController,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff7f9461)),
                    decoration: InputDecoration(
                      labelText: 'Birth Date (DD/MM/YYYY)',
                      labelStyle: const TextStyle(color: Color(0xff7f9461), fontWeight: FontWeight.bold),
                      prefixIcon: Icon(Icons.cake, color: const Color(0xff7f9461)),
                      helperText: 'You must be at least 18 years old',
                      helperStyle: TextStyle(color: const Color(0xff7f9461).withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
                      errorText: _birthDateError,
                      errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xff7f9461), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
              : _buildInfoItem("Birth Date", _logic.formatDate(birthDate), Icons.cake),
          const Divider(color: Color(0xFFC1CFA1), height: 20),
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: gender.isEmpty ? null : gender,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: const TextStyle(color: Color(0xff7f9461), fontWeight: FontWeight.bold),
                  prefixIcon: Icon(Icons.transgender, color: const Color(0xff7f9461)),
                  errorText: _genderError,
                  errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xff7f9461), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                items: genderOptions.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, style: const TextStyle(color: Color(0xff7f9461), fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      gender = newValue;
                      _genderError = _logic.validateGender(gender);
                    });
                  }
                },
              ),
            ],
          )
              : _buildInfoItem("Gender", gender, Icons.transgender),
          const Divider(color: Color(0xFFC1CFA1), height: 20),
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onHeightChanged,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff7f9461)),
                decoration: InputDecoration(
                  labelText: 'Height (cm)',
                  labelStyle: const TextStyle(color: Color(0xff7f9461), fontWeight: FontWeight.bold),
                  prefixIcon: Icon(Icons.height, color: const Color(0xff7f9461)),
                  helperText: 'Valid range: 50 - 250 cm',
                  helperStyle: TextStyle(color: const Color(0xff7f9461).withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
                  errorText: _heightError,
                  errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xff7f9461), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
            ],
          )
              : _buildInfoItem("Height", "${height.toStringAsFixed(1)} cm", Icons.height),
          const Divider(color: Color(0xFFC1CFA1), height: 20),
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onWeightChanged,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff7f9461)),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  labelStyle: const TextStyle(color: Color(0xff7f9461), fontWeight: FontWeight.bold),
                  prefixIcon: Icon(Icons.monitor_weight, color: const Color(0xff7f9461)),
                  helperText: 'Valid range: 20 - 300 kg',
                  helperStyle: TextStyle(color: const Color(0xff7f9461).withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
                  errorText: _weightError,
                  errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xff7f9461), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
            ],
          )
              : _buildInfoItem("Weight", "${weight.toStringAsFixed(1)} kg", Icons.monitor_weight),
          const Divider(color: Color(0xFFC1CFA1), height: 20),
          _buildInfoItem("Password", "••••••••", Icons.lock, onTap: _changePassword),
        ],
      ),
    );
  }

  Widget _buildSeedsInventoryCard() {
    if (seedsInventory.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7f9461).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.agriculture, color: const Color(0xff7f9461), size: 24),
              const SizedBox(width: 10),
              Text(
                "Seeds Inventory",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff7f9461),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...seedsInventory.entries.map((entry) {
            return Column(
              children: [
                _buildInfoItem(entry.key, entry.value.toString(), Icons.grass),
                const Divider(color: Color(0xFFC1CFA1), height: 20),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
            label: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff7f9461),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _confirmDeleteAccount,
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
            label: const Text(
              "Delete Account",
              style: TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.red.withOpacity(0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingHomeButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      },
      backgroundColor: const Color(0xFFC1CFA1),
      shape: const CircleBorder(),
      child: const Icon(Icons.home, color: Colors.white, size: 28),
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xff7f9461), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff7f9461).withOpacity(0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff7f9461),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: const Color(0xff7f9461), size: 20),
            ],
          ],
        ),
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