// ========== lib/presentation/all_goals_and_activities_page.dart ==========
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../domain/all_goals_logic.dart';
import '../../data/all_goals_data.dart';
import 'widgets/all_goals_shimmer.dart';

class AllGoalsAndActivitiesPage extends StatefulWidget {
  const AllGoalsAndActivitiesPage({super.key});

  @override
  State<AllGoalsAndActivitiesPage> createState() =>
      _AllGoalsAndActivitiesPageState();
}

class _AllGoalsAndActivitiesPageState extends State<AllGoalsAndActivitiesPage> {
  final AllGoalsLogic _logic = AllGoalsLogic();
  final AllGoalsData _data = AllGoalsData();

  String _userId = '';
  bool _resolvingUser = false;
  final Map<String, bool> _optimisticTodayByKey = <String, bool>{};

  @override
  void initState() {
    super.initState();
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      _userId = uid;
    } else {
      _resolvingUser = true;
      unawaited(_resolveUser());
    }
  }

  Future<void> _resolveUser() async {
    final Map<String, dynamic>? user = await _data.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _userId = user?['uid'] as String? ?? '';
      _resolvingUser = false;
    });
  }

  String _toggleKey(String analysisId, int index) => '$analysisId-$index';

  Future<void> _toggleActivity(
    String analysisId,
    int activityIndex,
    bool newValue,
  ) async {
    if (_userId.isEmpty) return;

    final String key = _toggleKey(analysisId, activityIndex);
    setState(() => _optimisticTodayByKey[key] = newValue);

    final bool success = await _data.toggleActivity(
      _userId,
      analysisId,
      activityIndex,
      newValue,
    );

    if (!mounted) return;
    if (!success) {
      setState(() => _optimisticTodayByKey.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update activity'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Goals & Activities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff7f9461),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFE7CCCC),
              Color(0xFFEDE8DC),
              Color(0xFFC1CFA1),
            ],
            stops: <double>[0.1, 0.5, 1.0],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_resolvingUser) {
      return const AllGoalsShimmer();
    }
    if (_userId.isEmpty) {
      return _logic.buildNoUserWidget(context);
    }
    return _buildAnalysesList();
  }

  Widget _buildAnalysesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _data.getAnalysesStream(_userId),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
        if (snapshot.hasError) {
          return _logic.buildErrorWidget(context, snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AllGoalsShimmer();
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (docs.isEmpty) {
          return _logic.buildEmptyWidget(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          cacheExtent: 480,
          itemCount: docs.length,
          itemBuilder: (BuildContext context, int index) {
            final QueryDocumentSnapshot<Map<String, dynamic>> doc = docs[index];
            final AnalysisCardModel model = AnalysisCardModel.fromFirestore(
              doc.id,
              doc.data(),
            );
            return RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.only(bottom: index == docs.length - 1 ? 0 : 4),
                child: _logic.buildAnalysisCard(
                  context,
                  model,
                  _toggleActivity,
                  optimisticTodayByKey: _optimisticTodayByKey,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
