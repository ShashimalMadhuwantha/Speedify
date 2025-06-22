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
  late Future<Map<String, dynamic>> _practiceSummaryFuture;

  String _selectedPage = 'Dashboard';

  @override
  void initState() {
    super.initState();
    _sprinterFuture = _firestore.collection('sprinters').doc(widget.sprinterId).get();
    _practiceSummaryFuture = _fetchPracticeSummary();
  }

  // Fetches practice summary stats from Firestore
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

      int lapCount = (data['lapCount'] ?? 0).toInt();
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
    final blueColor = const Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speedify', style: TextStyle(fontWeight: FontWeight.bold)),
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
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Sprinter not found.'));
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
                    return Center(
                        child: Text('Error loading summary: ${summarySnapshot.error}',
                            style: const TextStyle(color: Colors.red)));
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
              return const Center(child: Text('Page not found'));
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
          colors: [blueColor.withOpacity(0.08), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?auto=format&fit=crop&w=1050&q=80',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                        color: blueColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundImage: const NetworkImage('https://cdn-icons-png.flaticon.com/512/9131/9131529.png'),
              backgroundColor: blueColor.withOpacity(0.1),
            ),
            const SizedBox(height: 12),
            Text(
              data['name'] ?? 'No Name',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: blueColor),
            ),
            const SizedBox(height: 4),
            Text(
              data['email'] ?? 'No Email',
              style: TextStyle(fontSize: 16, color: blueColor.withOpacity(0.6)),
            ),
            const SizedBox(height: 28),
            _buildSummaryCard(totalSessions, totalLaps, averageLapDistance, latestPracticeDate, blueColor),
            const SizedBox(height: 24),
            Text(
              'Ready to break your limits today?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: blueColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildActionButton(Icons.play_arrow_rounded, 'Start Practice', () {
                  setState(() => _selectedPage = 'New Practice');
                }, blueColor),
                _buildActionButton(Icons.history_edu_rounded, 'Practice History', () {
                  setState(() => _selectedPage = 'Practice History');
                }, blueColor.withOpacity(0.9)),
                _buildActionButton(Icons.speed_rounded, 'Practice Modes', () {
                  setState(() => _selectedPage = 'Practice Modes');
                }, blueColor.withOpacity(0.8)),
              ],
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int totalSessions, int totalLaps, double avgLapDistance, DateTime? latestPracticeDate, Color blueColor) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Text('Practice Summary',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: blueColor)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(Icons.fitness_center, 'Sessions', totalSessions.toString(), blueColor),
                _buildSummaryItem(Icons.directions_run, 'Laps', totalLaps.toString(), blueColor),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(Icons.timeline, 'Avg Lap', '${avgLapDistance.toStringAsFixed(2)} m', blueColor),
                _buildSummaryItem(Icons.calendar_today, 'Latest', latestPracticeDate != null
                    ? '${latestPracticeDate.day}/${latestPracticeDate.month}/${latestPracticeDate.year}'
                    : 'N/A', blueColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Summary items with black text
  Widget _buildSummaryItem(IconData icon, String label, String value, Color color) {
  return Column(
    children: [
      Icon(icon, size: 36, color: Colors.black),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)), // no const before Text
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
    ],
  );
}


  Widget _buildActionButton(IconData icon, String label, VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 24, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: onPressed,
    );
  }
}
