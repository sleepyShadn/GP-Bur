import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'analysis_screen.dart';
import 'shop_screen.dart';
import 'garden_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xff7f9461);
  static const Color colorGreenLight = Color(0xFFC1CFA1);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _selectedIndex = 4;

  // User data from Firebase
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
  String createdAt = "";

  // Seeds inventory data
  Map<String, dynamic> seedsInventory = {};

  bool isLoading = true;
  bool isEditing = false;

  // Validation errors
  String? _nameError;
  String? _emailError;
  String? _birthDateError;
  String? _weightError;
  String? _heightError;
  String? _genderError;

  // Controllers for editable fields
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _birthDateController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  // Gender options
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
    setState(() {
      isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        uid = currentUser.uid;
        userEmail = currentUser.email ?? "";

        // Get user data from users collection
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          setState(() {
            // Map all fields from the database exactly as they are
            userName = userData['name'] ?? "";
            userEmail = userData['email'] ?? userEmail;

            // Handle createdAt
            if (userData['createdAt'] != null) {
              if (userData['createdAt'] is Timestamp) {
                Timestamp timestamp = userData['createdAt'];
                createdAt = _formatTimestamp(timestamp);
              } else {
                createdAt = userData['createdAt'].toString();
              }
            }

            // Handle dateOfBirth
            if (userData['dateOfBirth'] != null) {
              String dateStr = userData['dateOfBirth'].toString();
              try {
                birthDate = DateTime.parse(dateStr);
              } catch (e) {
                birthDate = DateTime.now();
              }
            }

            weight = (userData['weight'] is int)
                ? (userData['weight'] as int).toDouble()
                : (userData['weight'] ?? 0.0).toDouble();

            height = (userData['height'] is int)
                ? (userData['height'] as int).toDouble()
                : (userData['height'] ?? 0.0).toDouble();

            gender = userData['gender'] ?? "";
            totalPoints = userData['points'] ?? 0;

            // Load seeds inventory map
            if (userData['seedsInventory'] != null) {
              seedsInventory = Map<String, dynamic>.from(userData['seedsInventory']);
            }

            // Update controllers with current values
            _updateControllers();
          });

          // Calculate rank based on points
          await _calculateUserRank(uid, totalPoints);

          // Get total users count
          await _getTotalUsersCount();
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
      _showErrorSnackBar('Failed to load profile data');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateControllers() {
    _nameController.text = userName;
    _emailController.text = userEmail;
    _birthDateController.text = _formatDate(birthDate);
    _weightController.text = weight.toString();
    _heightController.text = height.toString();
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return "${_getMonthName(dateTime.month)} ${dateTime.day}, ${dateTime.year} at ${_formatTime(dateTime)}";
  }

  String _getMonthName(int month) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime dateTime) {
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String second = dateTime.second.toString().padLeft(2, '0');
    return "$hour:$minute:$second";
  }

  Future<void> _calculateUserRank(String currentUid, int currentPoints) async {
    try {
      QuerySnapshot usersSnapshot = await _firestore
          .collection('users')
          .orderBy('points', descending: true)
          .get();

      int rank = 1;
      for (var doc in usersSnapshot.docs) {
        if (doc.id == currentUid) {
          break;
        }
        rank++;
      }

      setState(() {
        userRank = rank;
      });
    } catch (e) {
      print("Error calculating rank: $e");
    }
  }

  Future<void> _getTotalUsersCount() async {
    try {
      AggregateQuerySnapshot totalUsersSnapshot = await _firestore
          .collection('users')
          .count()
          .get();

      setState(() {
        totalUsers = totalUsersSnapshot.count ?? 0;
      });
    } catch (e) {
      print("Error getting total users: $e");
    }
  }

  // Validation methods for each field
  String? _validateName(String value) {
    if (value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    return null;
  }

  String? _validateEmail(String value) {
    if (value.trim().isEmpty) {
      return 'Email cannot be empty';
    }

    // Email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validateBirthDate(String value) {
    if (value.trim().isEmpty) {
      return 'Birth date cannot be empty';
    }

    // Check date format (DD/MM/YYYY)
    final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dateRegex.hasMatch(value.trim())) {
      return 'Please enter date in DD/MM/YYYY format';
    }

    // Parse and validate date
    try {
      List<String> parts = value.trim().split('/');
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);

      DateTime date = DateTime(year, month, day);
      DateTime now = DateTime.now();

      if (date.isAfter(now)) {
        return 'Birth date cannot be in the future';
      }

      if (year < 1900) {
        return 'Year must be 1900 or later';
      }

      if (date.isBefore(DateTime(1900, 1, 1))) {
        return 'Date must be after 01/01/1900';
      }
    } catch (e) {
      return 'Invalid date';
    }

    return null;
  }

  String? _validateWeight(String value) {
    if (value.trim().isEmpty) {
      return 'Weight cannot be empty';
    }

    try {
      double weightValue = double.parse(value.trim());
      if (weightValue <= 0) {
        return 'Weight must be greater than 0';
      }
      if (weightValue > 500) {
        return 'Weight must be less than 500 kg';
      }
      if (weightValue < 20) {
        return 'Weight must be at least 20 kg';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }

    return null;
  }

  String? _validateHeight(String value) {
    if (value.trim().isEmpty) {
      return 'Height cannot be empty';
    }

    try {
      double heightValue = double.parse(value.trim());
      if (heightValue <= 0) {
        return 'Height must be greater than 0';
      }
      if (heightValue > 300) {
        return 'Height must be less than 300 cm';
      }
      if (heightValue < 50) {
        return 'Height must be at least 50 cm';
      }
    } catch (e) {
      return 'Please enter a valid number';
    }

    return null;
  }

  String? _validateGender(String value) {
    if (value.isEmpty) {
      return 'Please select your gender';
    }
    return null;
  }

  // Real-time validation on change
  void _onNameChanged(String value) {
    setState(() {
      _nameError = _validateName(value);
    });
  }

  void _onEmailChanged(String value) {
    setState(() {
      _emailError = _validateEmail(value);
    });
  }

  void _onWeightChanged(String value) {
    setState(() {
      _weightError = _validateWeight(value);
    });
  }

  void _onHeightChanged(String value) {
    setState(() {
      _heightError = _validateHeight(value);
    });
  }

  bool _validateAllInputs() {
    setState(() {
      _nameError = _validateName(_nameController.text);
      _emailError = _validateEmail(_emailController.text);
      _birthDateError = _validateBirthDate(_birthDateController.text);
      _weightError = _validateWeight(_weightController.text);
      _heightError = _validateHeight(_heightController.text);
      _genderError = _validateGender(gender);
    });

    return _nameError == null &&
        _emailError == null &&
        _birthDateError == null &&
        _weightError == null &&
        _heightError == null &&
        _genderError == null;
  }

  Future<void> _updateUserData() async {
    // Validate all inputs
    if (!_validateAllInputs()) {
      _showErrorSnackBar('Please fix the errors before saving');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        // Prepare the updated data with correct types for Firestore
        Map<String, dynamic> updatedData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'gender': gender,
          'dateOfBirth': _birthDateController.text, // Store as string as per your schema
          'weight': double.parse(_weightController.text.trim()),
          'height': double.parse(_heightController.text.trim()),
        };

        print("Updating user with data: $updatedData"); // Debug print

        // Update the document
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .update(updatedData);

        // Verify the update by fetching the document again
        DocumentSnapshot updatedDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (updatedDoc.exists) {
          print("Update successful: ${updatedDoc.data()}"); // Debug print

          setState(() {
            isEditing = false;
            // Clear all errors
            _nameError = null;
            _emailError = null;
            _birthDateError = null;
            _weightError = null;
            _heightError = null;
            _genderError = null;
          });

          // Refresh local data
          await _loadUserData();

          _showSuccessSnackBar('Profile updated successfully');
        } else {
          throw Exception('Document not found after update');
        }
      }
    } catch (e) {
      print("Error updating user data: $e");
      _showErrorSnackBar('Failed to update profile: ${e.toString()}');

      // Revert to view mode but keep data as is
      setState(() {
        isEditing = false;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorGreenDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
            colorScheme: ColorScheme.light(
              primary: colorGreenDark,
              onPrimary: Colors.white,
              surface: colorCream,
              onSurface: colorGreenDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        birthDate = picked;
        _birthDateController.text = _formatDate(picked);
        _birthDateError = _validateBirthDate(_birthDateController.text);
      });
    }
  }

  void _toggleEditMode() {
    setState(() {
      isEditing = !isEditing;
      if (isEditing) {
        // Refresh controllers with current values when entering edit mode
        _updateControllers();
        // Clear any previous errors
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
      // Reset controllers to original values
      _updateControllers();
      gender = gender; // Reset gender to original
      // Clear errors
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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                isLoading = true;
              });
              await _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      print('Already on Profile Page');
    } else {
      switch (index) {
        case 0:
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => GardenPage()));
          break;
        case 1:
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => ShopPage()));
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
            colors: [colorPinkish, colorCream, colorGreenLight],
            stops: [0.1, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorGreenDark),
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildAppBar(),

                if (createdAt.isNotEmpty) _buildCreatedAtBanner(),

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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Profile",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorGreenDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!isEditing)
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: colorGreenDark),
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
            icon: const Icon(Icons.save, color: colorGreenDark),
            onPressed: _updateUserData,
            tooltip: 'Save',
          ),
        ],
      ],
    );
  }

  Widget _buildCreatedAtBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorCream.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: colorGreenDark, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Member since: $createdAt",
              style: TextStyle(
                fontSize: 12,
                color: colorGreenDark,
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
            color: colorGreenDark.withOpacity(0.1),
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
              color: colorGreenLight,
              border: Border.all(color: colorGreenDark, width: 2),
            ),
            child: const Icon(
              Icons.person,
              size: 50,
              color: colorGreenDark,
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
                        labelStyle: TextStyle(color: colorGreenDark),
                        errorText: _nameError,
                        errorStyle: const TextStyle(color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colorGreenDark, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorGreenDark,
                      ),
                    ),
                  ],
                )
                    : Text(
                  userName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorGreenDark,
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
                        labelStyle: TextStyle(color: colorGreenDark),
                        errorText: _emailError,
                        errorStyle: const TextStyle(color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colorGreenDark, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorGreenDark,
                      ),
                    ),
                  ],
                )
                    : Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorGreenDark.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.star, color: colorGreenDark, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      "$totalPoints Points",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorGreenDark,
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
            color: colorGreenDark.withOpacity(0.1),
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
              Icon(Icons.leaderboard, color: colorGreenDark, size: 24),
              const SizedBox(width: 10),
              Text(
                "Global Ranking",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorGreenDark,
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
                    border: Border.all(color: colorGreenDark, width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "#$userRank",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: colorGreenDark,
                        ),
                      ),
                      Text(
                        "Rank",
                        style: TextStyle(
                          fontSize: 14,
                          color: colorGreenDark.withOpacity(0.8),
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
                  style: TextStyle(fontSize: 14, color: colorGreenDark),
                ),
                const SizedBox(height: 8),
                Text(
                  totalUsers > 0
                      ? "Out of $totalUsers total users"
                      : "Loading total users...",
                  style: TextStyle(
                    fontSize: 12,
                    color: colorGreenDark.withOpacity(0.6),
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
            color: colorGreenDark.withOpacity(0.1),
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
              Icon(Icons.person_outline, color: colorGreenDark, size: 24),
              const SizedBox(width: 10),
              Text(
                "Personal Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorGreenDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Birth Date
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _birthDateController,
                    decoration: InputDecoration(
                      labelText: 'Birth Date',
                      labelStyle: TextStyle(color: colorGreenDark),
                      prefixIcon: Icon(Icons.cake, color: colorGreenDark),
                      errorText: _birthDateError,
                      errorStyle: const TextStyle(color: Colors.red),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colorGreenDark, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
              : _buildInfoItem("Birth Date", _formatDate(birthDate), Icons.cake),

          const Divider(color: colorGreenLight, height: 20),

          // Gender
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: gender.isEmpty ? null : gender,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: TextStyle(color: colorGreenDark),
                  prefixIcon: Icon(Icons.transgender, color: colorGreenDark),
                  errorText: _genderError,
                  errorStyle: const TextStyle(color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorGreenDark, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                items: genderOptions.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, style: TextStyle(color: colorGreenDark)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      gender = newValue;
                      _genderError = _validateGender(gender);
                    });
                  }
                },
              ),
            ],
          )
              : _buildInfoItem("Gender", gender, Icons.transgender),

          const Divider(color: colorGreenLight, height: 20),

          // Height
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                onChanged: _onHeightChanged,
                decoration: InputDecoration(
                  labelText: 'Height (cm)',
                  labelStyle: TextStyle(color: colorGreenDark),
                  prefixIcon: Icon(Icons.height, color: colorGreenDark),
                  errorText: _heightError,
                  errorStyle: const TextStyle(color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorGreenDark, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
            ],
          )
              : _buildInfoItem("Height", "${height.toStringAsFixed(1)} cm", Icons.height),

          const Divider(color: colorGreenLight, height: 20),

          // Weight
          isEditing
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                onChanged: _onWeightChanged,
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  labelStyle: TextStyle(color: colorGreenDark),
                  prefixIcon: Icon(Icons.monitor_weight, color: colorGreenDark),
                  errorText: _weightError,
                  errorStyle: const TextStyle(color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colorGreenDark, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red, width: 1),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
            ],
          )
              : _buildInfoItem("Weight", "${weight.toStringAsFixed(1)} kg", Icons.monitor_weight),

          const Divider(color: colorGreenLight, height: 20),

          // Password
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
            color: colorGreenDark.withOpacity(0.1),
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
              Icon(Icons.agriculture, color: colorGreenDark, size: 24),
              const SizedBox(width: 10),
              Text(
                "Seeds Inventory",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorGreenDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...seedsInventory.entries.map((entry) {
            return Column(
              children: [
                _buildInfoItem(
                    entry.key,
                    entry.value.toString(),
                    Icons.grass),
                const Divider(color: colorGreenLight, height: 20),
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
      backgroundColor: colorGreenLight,
      shape: const CircleBorder(),
      child: const Icon(Icons.home, color: Colors.white, size: 28),
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: colorGreenDark, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: colorGreenDark.withOpacity(0.8),
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
                  fontWeight: FontWeight.w600,
                  color: colorGreenDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colorGreenDark, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
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
              color: isSelected ? colorGreenDark : Colors.grey,
              size: isSelected ? 22 : 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorGreenDark : Colors.grey,
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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