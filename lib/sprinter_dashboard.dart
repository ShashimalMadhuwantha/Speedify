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
      'latestPracticeDate': latestTimestamp?.toDate(),
    };
  }

  void _onDrawerSelection(String page) {
    setState(() {
      _selectedPage = page;
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
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Hero image with sprinting athlete
            ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              child: Image.network(
                'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=1050&q=80',
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 20),
            CircleAvatar(
              radius: 52,
              backgroundImage: NetworkImage(
                'https://cdn-icons-png.flaticon.com/512/2922/2922510.png',
              ),
              backgroundColor: blueColor.withOpacity(0.1),
            ),
            SizedBox(height: 16),
            Text(
              data['name'] ?? 'No Name',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: blueColor),
            ),
            SizedBox(height: 6),
            Text(
              data['email'] ?? 'No Email',
              style: TextStyle(fontSize: 16, color: blueColor.withOpacity(0.7)),
            ),
            SizedBox(height: 24),
            _buildSummaryCard(totalSessions, totalLaps, averageLapDistance, latestPracticeDate, blueColor),
            SizedBox(height: 32),
            Text(
              'Ready to break your limits today?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: blueColor),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildActionButton(Icons.play_arrow, 'Start Practice', () {
                  setState(() => _selectedPage = 'New Practice');
                }, blueColor),
                _buildActionButton(Icons.history, 'Practice History', () {
                  setState(() => _selectedPage = 'Practice History');
                }, blueColor.withOpacity(0.9)),
                _buildActionButton(Icons.speed, 'Practice Modes', () {
                  setState(() => _selectedPage = 'Practice Modes');
                }, blueColor.withOpacity(0.8)),
              ],
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int totalSessions, int totalLaps, double avgLapDistance, DateTime? latestPracticeDate, Color blueColor) {
    final TextStyle labelStyle = TextStyle(color: blueColor.withOpacity(0.7), fontSize: 14);
    final TextStyle valueStyle = TextStyle(color: blueColor, fontSize: 20, fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
          child: Column(
            children: [
              Text('Practice Summary', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: blueColor)),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(Icons.fitness_center, 'Sessions', totalSessions.toString(), blueColor),
                  _buildSummaryItem(Icons.directions_run, 'Laps', totalLaps.toString(), blueColor),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(Icons.timeline, 'Avg Lap', '${avgLapDistance.toStringAsFixed(2)} m', blueColor),
                  _buildSummaryItem(Icons.calendar_today, 'Last Practice',
                      latestPracticeDate != null
                          ? '${latestPracticeDate.day}/${latestPracticeDate.month}/${latestPracticeDate.year}'
                          : 'N/A',
                      blueColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: color.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, Color bgColor) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
    );
  }
}
