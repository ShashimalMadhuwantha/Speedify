import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'sprinter_drawer.dart';
import 'practice_page.dart';
import 'PracticeHistoryPage.dart';
import 'practice_modes_page.dart';

class SprinterDashboard extends StatefulWidget {
  final String sprinterId;

  const SprinterDashboard({Key? key, required this.sprinterId}) : super(key: key);

  @override
  _SprinterDashboardState createState() => _SprinterDashboardState();
}

class _SprinterDashboardState extends State<SprinterDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<DocumentSnapshot> _sprinterFuture;
  String _selectedPage = 'Dashboard';

  // Practice summary future
  late Future<Map<String, dynamic>> _practiceSummaryFuture;

  @override
  void initState() {
    super.initState();
    _sprinterFuture = _firestore.collection('sprinters').doc(widget.sprinterId).get();
    _practiceSummaryFuture = _fetchPracticeSummary();
  }

  Future<Map<String, dynamic>> _fetchPracticeSummary() async {
    QuerySnapshot practiceSnapshot = await _firestore
        .collection('users')
        .doc(widget.sprinterId)
        .collection('practices')
        .get();

    int totalSessions = practiceSnapshot.docs.length;
    int totalLaps = 0;
    double totalDistance = 0.0;
    Timestamp? latestTimestamp;

    for (var doc in practiceSnapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      int lapCount = data['lapCount'] ?? 0;
      double lapDistance = (data['lapDistance'] ?? 0).toDouble();

      totalLaps += lapCount;
      totalDistance += lapDistance * lapCount;

      Timestamp? timestamp = data['timestamp'];
      if (timestamp != null) {
        if (latestTimestamp == null || timestamp.seconds > latestTimestamp.seconds) {
          latestTimestamp = timestamp;
        }
      }
    }

    double averageLapDistance = totalLaps > 0 ? totalDistance / totalLaps : 0;

    return {
      'totalSessions': totalSessions,
      'totalLaps': totalLaps,
      'averageLapDistance': averageLapDistance,
      'latestPracticeDate': latestTimestamp != null ? latestTimestamp.toDate() : null,
    };
  }

  void _onDrawerSelection(String page) {
    setState(() {
      _selectedPage = page;
      // Refresh practice summary when returning to dashboard
      if (page == 'Dashboard') {
        _practiceSummaryFuture = _fetchPracticeSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Speedify'),
        backgroundColor: blueColor,
        elevation: 4,
      ),
      drawer: SprinterDrawer(
        selected: _selectedPage,
        onSelect: _onDrawerSelection,
        sprinterId: widget.sprinterId,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _sprinterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: blueColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Sprinter not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          switch (_selectedPage) {
            case 'Dashboard':
              return FutureBuilder<Map<String, dynamic>>(
                future: _practiceSummaryFuture,
                builder: (context, summarySnapshot) {
                  if (summarySnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: blueColor));
                  }
                  if (summarySnapshot.hasError) {
                    return Center(child: Text('Error loading practice summary: ${summarySnapshot.error}', style: TextStyle(color: Colors.red)));
                  }
                  final summary = summarySnapshot.data ?? {};
                  return _buildDashboard(data, summary, blueColor);
                },
              );
            case 'New Practice':
              return PracticePage(userId: widget.sprinterId);
            case 'Practice History':
              return PracticeHistoryPage(userId: widget.sprinterId);
            case 'Practice Modes':
              return PracticeModesPage();
            default:
              return Center(child: Text('Page not found'));
          }
        },
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> data, Map<String, dynamic> summary, Color blueColor) {
    final totalSessions = summary['totalSessions'] ?? 0;
    final totalLaps = summary['totalLaps'] ?? 0;
    final averageLapDistance = summary['averageLapDistance'] ?? 0.0;
    final latestPracticeDate = summary['latestPracticeDate'] as DateTime?;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [blueColor.withOpacity(0.1), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: SingleChildScrollView(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 12,
          shadowColor: blueColor.withOpacity(0.3),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: blueColor,
                  child: Icon(Icons.directions_run, size: 70, color: Colors.white),
                ),
                SizedBox(height: 28),
                Text(
                  data['name'] ?? 'No Name',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: blueColor,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  data['email'] ?? 'No Email',
                  style: TextStyle(
                    fontSize: 18,
                    color: blueColor.withOpacity(0.75),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 24),
                Divider(thickness: 1.5, color: blueColor.withOpacity(0.3)),
                SizedBox(height: 24),

                // Summary section
                _buildSummaryCard(totalSessions, totalLaps, averageLapDistance, latestPracticeDate, blueColor),

                SizedBox(height: 24),

                Text(
                  'Welcome back, ready to speed up your training?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: blueColor,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedPage = 'New Practice';
                    });
                  },
                  icon: Icon(Icons.play_arrow),
                  label: Text('Start New Practice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedPage = 'Practice History';
                    });
                  },
                  icon: Icon(Icons.history),
                  label: Text('View Practice History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor.withOpacity(0.85),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedPage = 'Practice Modes';
                    });
                  },
                  icon: Icon(Icons.speed),
                  label: Text('Practice Modes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor.withOpacity(0.75),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int totalSessions, int totalLaps, double avgLapDistance, DateTime? latestPracticeDate, Color blueColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      color: blueColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
        child: Column(
          children: [
            Text(
              'Practice Summary',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total Sessions', totalSessions.toString(), blueColor),
                _summaryItem('Total Laps', totalLaps.toString(), blueColor),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Avg Lap Distance', '${avgLapDistance.toStringAsFixed(2)} m', blueColor),
                _summaryItem(
                  'Last Practice',
                  latestPracticeDate != null ? '${latestPracticeDate.day}/${latestPracticeDate.month}/${latestPracticeDate.year}' : 'N/A',
                  blueColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color blueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: blueColor,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: blueColor.withOpacity(0.75),
          ),
        ),
      ],
    );
  }
}
