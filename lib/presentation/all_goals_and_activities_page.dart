// ========== lib/presentation/all_goals_and_activities_page.dart ==========
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../domain/all_goals_logic.dart';
import '../../data/all_goals_data.dart';

class AllGoalsAndActivitiesPage extends StatefulWidget {
  const AllGoalsAndActivitiesPage({super.key});

  @override
  State<AllGoalsAndActivitiesPage> createState() => _AllGoalsAndActivitiesPageState();
}

class _AllGoalsAndActivitiesPageState extends State<AllGoalsAndActivitiesPage> {
  final AllGoalsLogic _logic = AllGoalsLogic();
  final AllGoalsData _data = AllGoalsData();

  String _userId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final user = await _data.getCurrentUser();
    if (user != null) {
      setState(() {
        _userId = user['uid'] ?? '';
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Goals & Activities', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff7f9461),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE7CCCC), Color(0xFFEDE8DC), Color(0xFFC1CFA1)],
            stops: [0.1, 0.5, 1.0],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xff7f9461)))
            : _userId.isEmpty
            ? _logic.buildNoUserWidget(context)
            : _buildAnalysesList(),
      ),
    );
  }

  Widget _buildAnalysesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _data.getAnalysesStream(_userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _logic.buildErrorWidget(context, snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xff7f9461)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _logic.buildEmptyWidget(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            data['analysisId'] = doc.id;
            return _logic.buildAnalysisCard(context, data, _toggleActivity);
          },
        );
      },
    );
  }

  Future<void> _toggleActivity(String analysisId, int activityIndex, bool newValue) async {
    if (_userId.isEmpty) return;

    final success = await _data.toggleActivity(_userId, analysisId, activityIndex, newValue);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update activity'), backgroundColor: Colors.red),
      );
    }
  }
}

