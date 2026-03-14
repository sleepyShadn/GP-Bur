import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xFFA5B68D);
  static const Color colorGreenLight = Color(0xFFC1CFA1);
  static const Color colorPlaceholder = Color(0xFF362427);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  String _gender = 'Female';
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Error message states
  String? _emailError;
  String? _passwordError;
  String? _dobError;

  // Password requirement states
  bool _hasMinLength = false;
  bool _hasLowercase = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  // Email validation
  bool _isEmailValid = false;

  // Selected date for DOB
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _emailController.addListener(_validateEmailFormat);

    // Add listeners for weight and height to ensure only numbers
    _weightController.addListener(_validateWeightInput);
    _heightController.addListener(_validateHeightInput);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
    _emailController.removeListener(_validateEmailFormat);
    _weightController.removeListener(_validateWeightInput);
    _heightController.removeListener(_validateHeightInput);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    String password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 6;
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  void _validateEmailFormat() {
    String email = _emailController.text.trim();

    // Basic format validation
    bool hasAtSymbol = email.contains('@');
    bool validFormat = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);

    if (email.isNotEmpty && (!hasAtSymbol || !validFormat)) {
      setState(() {
        _emailError = "Email must contain '@' and be in valid format";
        _isEmailValid = false;
      });
    } else if (email.isNotEmpty && hasAtSymbol && validFormat) {
      setState(() {
        _emailError = null;
        _isEmailValid = true;
      });
    } else {
      setState(() {
        _emailError = null;
        _isEmailValid = false;
      });
    }
  }

  void _validateWeightInput() {
    String text = _weightController.text;
    if (text.isNotEmpty) {
      // Remove any non-numeric characters except decimal point
      String filtered = text.replaceAll(RegExp(r'[^0-9.]'), '');

      // Ensure only one decimal point
      if (filtered.indexOf('.') != filtered.lastIndexOf('.')) {
        filtered = filtered.substring(0, filtered.lastIndexOf('.'));
      }

      if (filtered != text) {
        _weightController.value = TextEditingValue(
          text: filtered,
          selection: TextSelection.collapsed(offset: filtered.length),
        );
      }
    }
  }

  void _validateHeightInput() {
    String text = _heightController.text;
    if (text.isNotEmpty) {
      // Remove any non-numeric characters (no decimals for height)
      String filtered = text.replaceAll(RegExp(r'[^0-9]'), '');

      if (filtered != text) {
        _heightController.value = TextEditingValue(
          text: filtered,
          selection: TextSelection.collapsed(offset: filtered.length),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime.now().subtract(const Duration(days: 6570)), // ~18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
        _selectedDate = picked;
        _dobController.text =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _dobError = null; // Clear any previous error
      });
    }
  }

  bool _validateForm() {
    bool isValid = true;

    // Check if all fields are filled
    if (_nameController.text.isEmpty) {
      _showErrorDialog('Please enter your name');
      isValid = false;
      return isValid;
    }

    if (_emailController.text.isEmpty) {
      _showErrorDialog('Please enter your email');
      isValid = false;
      return isValid;
    }

    if (!_isEmailValid) {
      setState(() {
        _emailError = "Please enter a valid email address with '@'";
      });
      isValid = false;
    }

    if (_passwordController.text.isEmpty) {
      _showErrorDialog('Please enter a password');
      isValid = false;
      return isValid;
    }

    // Password validation
    if (!_hasMinLength ||
        !_hasLowercase ||
        !_hasUppercase ||
        !_hasNumber ||
        !_hasSpecialChar) {
      setState(() {
        _passwordError = "All password requirements must be met";
      });
      isValid = false;
    } else {
      setState(() {
        _passwordError = null;
      });
    }

    if (_dobController.text.isEmpty) {
      _showErrorDialog('Please select your date of birth');
      isValid = false;
      return isValid;
    }

    // DOB validation (age check)
    if (_selectedDate != null) {
      DateTime today = DateTime.now();
      int age = today.year - _selectedDate!.year;
      if (today.month < _selectedDate!.month ||
          (today.month == _selectedDate!.month &&
              today.day < _selectedDate!.day)) {
        age--;
      }

      if (age < 18) {
        setState(() {
          _dobError = "You must be at least 18 years old to register";
        });
        isValid = false;
      } else {
        setState(() {
          _dobError = null;
        });
      }
    }

    if (_weightController.text.isEmpty) {
      _showErrorDialog('Please enter your weight');
      isValid = false;
      return isValid;
    }

    if (_heightController.text.isEmpty) {
      _showErrorDialog('Please enter your height');
      isValid = false;
      return isValid;
    }

    return isValid;
  }

  Future<void> _registerUser() async {
    if (!_validateForm()) {
      return;
    }

    // Show consent dialog
    bool? userConsented = await _showConsentDialog();

    if (userConsented != true) {
      return; // User refused consent, return to registration page
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Attempt to create user - this will fail if email already exists
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String userId = userCredential.user!.uid;

      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'height': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'gender': _gender,
        'createdAt': FieldValue.serverTimestamp(),
        'points': 0,
        'seedsInventory': {
          'Regular Seeds': 0,
          'Rare Seeds': 0,
          'Legendary Seeds': 0,
          'Growth Accelerator': 0,
        },
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please log in.'),
            backgroundColor: colorGreenDark,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to login after short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
                  (route) => false,
            );
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Registration failed';
      if (e.code == 'email-already-in-use') {
        setState(() {
          _emailError = 'This email has been used before';
        });
        errorMessage = 'This email is already registered';
      } else if (e.code == 'invalid-email') {
        setState(() {
          _emailError = 'Invalid email address';
        });
        errorMessage = 'Please enter a valid email address';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      } else {
        errorMessage = e.message ?? 'An error occurred';
      }

      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorDialog('An error occurred. Please try again');
      }
    }
  }

  Future<bool?> _showConsentDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: const Text(
          'Data Sharing Consent',
          style: TextStyle(color: colorGreenDark, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'We would like to collect and use your personal data to improve your experience. '
              'This includes your name, email, date of birth, weight, height, and gender. '
              'Do you consent to sharing this information?',
          style: TextStyle(color: colorGreenDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'No, thanks',
              style: TextStyle(color: colorGreenDark),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorGreenDark,
            ),
            child: const Text(
              'I Consent',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorCream,
        title: const Text('Error', style: TextStyle(color: colorGreenDark)),
        content: Text(message, style: const TextStyle(color: colorGreenDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: colorGreenDark)),
          ),
        ],
      ),
    );
  }

  String _getPasswordRequirementsText() {
    List<String> missing = [];
    if (!_hasMinLength) missing.add("6+ characters");
    if (!_hasLowercase) missing.add("lowercase letter");
    if (!_hasUppercase) missing.add("uppercase letter");
    if (!_hasNumber) missing.add("number");
    if (!_hasSpecialChar) missing.add("special character");

    if (missing.isEmpty) {
      return "✓ All password requirements met";
    } else {
      return "Password needs: ${missing.join(', ')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorCream,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            left: -30,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: colorPinkish.withOpacity(0.4),
            ),
          ),
          Positioned(
            bottom: 150,
            right: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: colorGreenLight.withOpacity(0.3),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: colorGreenDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      "Create your account",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorGreenDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Name field
                  TextField(
                    controller: _nameController,
                    decoration: _buildInputDecoration("alia"),
                  ),
                  const SizedBox(height: 15),

                  // Email field with validation
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _buildInputDecoration(
                      "sara@gmail.com",
                      errorText: _emailError,
                      suffixIcon: _isEmailValid
                          ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 20)
                          : null,
                    ),
                    onChanged: (value) {
                      _validateEmailFormat();
                    },
                  ),
                  if (_emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Text(
                        _emailError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),

                  // Password field with real-time requirements
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _buildInputDecoration(
                      "Password123!",
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: colorGreenDark,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      errorText: _passwordError,
                    ),
                  ),

                  // Password requirements reminder
                  Container(
                    margin: const EdgeInsets.only(top: 8, left: 12, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorPinkish.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPasswordRequirementsText(),
                          style: TextStyle(
                            color: (_hasMinLength &&
                                _hasLowercase &&
                                _hasUppercase &&
                                _hasNumber &&
                                _hasSpecialChar)
                                ? Colors.green
                                : colorGreenDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildRequirementChip("6+ chars", _hasMinLength),
                            _buildRequirementChip("a-z", _hasLowercase),
                            _buildRequirementChip("A-Z", _hasUppercase),
                            _buildRequirementChip("0-9", _hasNumber),
                            _buildRequirementChip("!@#\$%", _hasSpecialChar),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_passwordError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 12),
                      child: Text(
                        _passwordError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),

                  // Date of Birth field with DatePicker
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _dobController,
                        keyboardType: TextInputType.datetime,
                        decoration: _buildInputDecoration(
                          "Select your date of birth",
                          icon: Icons.calendar_month,
                          errorText: _dobError,
                        ),
                      ),
                    ),
                  ),
                  if (_dobError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Text(
                        _dobError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),

                  // Weight and Height with number only input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: _buildInputDecoration(
                            "70.5",
                            suffix: "kg",
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            "175",
                            suffix: "cm",
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Gender selection
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    height: 55,
                    decoration: BoxDecoration(
                      color: colorPinkish,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          "Gender",
                          style: TextStyle(
                              color: colorPlaceholder,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        _buildGenderOption("Female"),
                        const SizedBox(width: 15),
                        _buildGenderOption("Male"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorGreenDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        "CREATE ACCOUNT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login link
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const Login()),
                        );
                      },
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              color: Color(0xFF362427),
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                          children: [
                            TextSpan(text: "ALREADY HAVE AN ACCOUNT? "),
                            TextSpan(
                              text: "LOG IN",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String gender) {
    return GestureDetector(
      onTap: () => setState(() => _gender = gender),
      child: Row(
        children: [
          Icon(
            _gender == gender ? Icons.check_circle : Icons.radio_button_off,
            size: 18,
            color: colorGreenDark,
          ),
          const SizedBox(width: 4),
          Text(gender,
              style: const TextStyle(color: colorPlaceholder, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(String text, bool isMet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet ? Colors.green : colorPinkish,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMet) const Icon(Icons.check, color: Colors.white, size: 12),
          if (!isMet) const Icon(Icons.circle, color: colorGreenDark, size: 8),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.white : colorGreenDark,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint,
      {IconData? icon, String? suffix, String? errorText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: colorPlaceholder,
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
      errorText: errorText,
      errorStyle: const TextStyle(
        color: Colors.red,
        fontSize: 12,
      ),
      filled: true,
      fillColor: colorPinkish,
      suffixText: suffix,
      suffixStyle: const TextStyle(
        color: colorGreenDark,
        fontWeight: FontWeight.bold,
      ),
      suffixIcon: suffixIcon ??
          (icon != null ? Icon(icon, color: colorGreenDark, size: 20) : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: colorGreenDark,
          width: 2,
        ),
      ),
    );
  }
}