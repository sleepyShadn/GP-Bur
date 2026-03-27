// ========== lib/presentation/profile_screen.dart ==========
import 'package:appforhumman/presentation/shop_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../domain/profile_logic.dart';
import '../../data/profile_data.dart';

import 'analysis_screen.dart';
import 'garden_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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

  Map<String, dynamic> seedsInventory = {};

  bool isLoading = true;
  bool isEditing = false;

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
    _initializeControllers();
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
      builder: (context) => AlertDialog(
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
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
            child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
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
            colors: [Color(0xFFE7CCCC), Color(0xFFEDE8DC), Color(0xFFC1CFA1)],
            stops: [0.1, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff7f9461)),
            ),
          )
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

  Widget _buildAppBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _onLogoClick,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFC1CFA1).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: const Color(0xff7f9461), size: 20),
                const SizedBox(width: 4),
                Text(
                  "Login",
                  style: TextStyle(
                    color: const Color(0xff7f9461),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Profile",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xff7f9461),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!isEditing)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xff7f9461)),
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
            icon: const Icon(Icons.save, color: Color(0xff7f9461)),
            onPressed: _updateUserData,
            tooltip: 'Save',
          ),
        ],
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
        color: const Color(0xFFEDE8DC).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: const Color(0xff7f9461), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Member since: $formattedDate",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xff7f9461),
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
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC1CFA1),
              border: Border.all(color: const Color(0xff7f9461), width: 2),
            ),
            child: const Icon(
              Icons.person,
              size: 50,
              color: Color(0xff7f9461),
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
    return SizedBox(
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
          backgroundColor: Colors.red.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 3,
        ),
      ),
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
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.local_florist_outlined, "Garden", 0),
            _navItem(Icons.storefront, "Shop", 1),
            const SizedBox(width: 36),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xff7f9461) : Colors.grey,
              size: isSelected ? 22 : 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xff7f9461) : Colors.grey,
                fontSize: isSelected ? 10 : 9,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}