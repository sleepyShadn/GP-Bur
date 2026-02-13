import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'analysis_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'garden_screen.dart';
import 'all_goals_and_activities_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color colorPinkish = Color(0xFFE7CCCC);
  static const Color colorCream = Color(0xFFEDE8DC);
  static const Color colorGreenDark = Color(0xff7f9461);
  static const Color colorGreenLight = Color(0xFFC1CFA1);

  late stt.SpeechToText _speech;
  bool _isListening = false;
  final TextEditingController _textController =
      TextEditingController(text: "happy full energy");

  int _selectedIndex = 2;
  List<bool> _activityChecks = [false, false, false];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => GardenPage()));
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShopPage()));
        break;
      case 2:
        print('Already on Home Page');
        break;
      case 3:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AnalyticsPage()));
        break;
      case 4:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => ProfilePage()));
        break;
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.5),
                      child: const Icon(Icons.person, color: colorGreenDark),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Welcome back, Mashaal",
                      style: TextStyle(
                          color: colorGreenDark, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(Icons.notifications_none, color: colorGreenDark),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  "How are you feeling today?",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: colorGreenDark,
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorPinkish.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _listen,
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Analyze Mood",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorGreenLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                _buildCard(
                  icon: Icons.lightbulb,
                  title: " : Today's Mood Insight",
                  content: "Goal",
                ),
                const SizedBox(height: 20),
                _buildCard(
                  icon: Icons.star,
                  title: "Sugested Activites",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildActivityItem(
                        "Keep this positive energy going!",
                        0,
                      ),
                      _buildActivityItem(
                        "Write one good thing that happened.",
                        1,
                      ),
                      _buildActivityItem(
                        "Water your garden today.",
                        2,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AllGoalsAndActivitiesPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorGreenDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Go Activities",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _onItemTapped(2);
        },
        backgroundColor: _selectedIndex == 2 ? colorGreenDark : colorGreenLight,
        shape: const CircleBorder(),
        child: Icon(
          Icons.home,
          color: Colors.white,
          size: _selectedIndex == 2 ? 32 : 30,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildActivityItem(String text, int index) {
    return Row(
      children: [
        Checkbox(
          value: _activityChecks[index],
          onChanged: (value) {
            setState(() {
              _activityChecks[index] = value ?? false;
            });
          },
          activeColor: colorGreenDark,
        ),
        Text(
          text,
          style: const TextStyle(color: colorGreenDark, height: 1.8),
        ),
      ],
    );
  }

  Widget _buildCard(
      {required IconData icon,
      required String title,
      String? content,
      Widget? child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorGreenDark, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    color: colorGreenDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          content != null
              ? Text(content, style: const TextStyle(color: colorGreenDark))
              : (child ?? const SizedBox()),
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
          Icon(
            icon,
            color: isSelected ? colorGreenDark : Colors.grey,
            size: isSelected ? 24 : 22,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? colorGreenDark : Colors.grey,
              fontSize: isSelected ? 11 : 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
