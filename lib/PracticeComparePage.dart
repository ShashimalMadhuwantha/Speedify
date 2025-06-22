import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PracticeComparePage extends StatefulWidget {
  final String userId;
  final String firstPracticeId;

  const PracticeComparePage({
    Key? key,
    required this.userId,
    required this.firstPracticeId,
  }) : super(key: key);

  @override
  State<PracticeComparePage> createState() => _PracticeComparePageState();
}

class _PracticeComparePageState extends State<PracticeComparePage> {
  String? _secondPracticeId;
  Map<String, dynamic>? _firstPracticeData;
  Map<String, dynamic>? _secondPracticeData;

  int _firstTotalTime = 0;
  int _secondTotalTime = 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPractice();
  }

  Future<void> _loadFirstPractice() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .doc(widget.firstPracticeId)
        .get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data()!;
      int totalTime = await _calculateTotalTime(widget.userId, widget.firstPracticeId);

      setState(() {
        _firstPracticeData = data;
        _firstTotalTime = totalTime;
        _firstPracticeData!['totalTime'] = totalTime;
      });
    }
  }

  Future<void> _loadSecondPracticeData() async {
    if (_secondPracticeId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .doc(_secondPracticeId)
        .get();

    if (doc.exists) {
      Map<String, dynamic> data = doc.data()!;
      int totalTime = await _calculateTotalTime(widget.userId, _secondPracticeId!);

      setState(() {
        _secondPracticeData = data;
        _secondTotalTime = totalTime;
        _secondPracticeData!['totalTime'] = totalTime;
      });
    }
  }

  Future<int> _calculateTotalTime(String userId, String practiceId) async {
    final lapsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('practices')
        .doc(practiceId)
        .collection('laps')
        .get();

    int totalTime = 0;
    for (var lapDoc in lapsSnapshot.docs) {
      // lapDoc['time'] might be stored as num/double, cast safely:
      int lapTime = 0;
      final timeValue = lapDoc.data()['time'];
      if (timeValue is int) {
        lapTime = timeValue;
      } else if (timeValue is double) {
        lapTime = timeValue.toInt();
      } else if (timeValue is num) {
        lapTime = timeValue.toInt();
      }
      totalTime += lapTime;
    }
    return totalTime;
  }

  Widget _buildPracticeSummary(Map<String, dynamic> data) {
    final lapCount = (data['lapCount'] ?? 0) as int;
    final lapDistance = (data['lapDistance'] ?? 0.0).toDouble();
    final totalTime = (data['totalTime'] ?? 0) as int;
    final averageSpeed = totalTime > 0 ? lapDistance * lapCount / totalTime : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Laps: $lapCount'),
        Text('Lap Distance: ${lapDistance.toStringAsFixed(2)} m'),
        Text('Total Distance: ${(lapCount * lapDistance).toStringAsFixed(2)} m'),
        Text('Total Time: ${_formatDuration(Duration(seconds: totalTime))}'),
        Text('Average Speed: ${averageSpeed.toStringAsFixed(2)} m/s'),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  String _generateLabelFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final lapCount = data['lapCount'] ?? 0;
    final lapDistance = (data['lapDistance'] ?? 0.0).toDouble();

    final timeString = (timestamp != null)
        ? _formatFullDate(timestamp)
        : 'Unknown time';

    return '$timeString ($lapCount laps, ${lapDistance.toStringAsFixed(1)}m)';
  }

  String _formatFullDate(Timestamp timestamp) {
    final dt = timestamp.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final practicesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Practices'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_firstPracticeData == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              const Text(
                'First Practice:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              _buildPracticeSummary(_firstPracticeData!),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(
                stream: practicesRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  final docs = snapshot.data!.docs
                      .where((doc) => doc.id != widget.firstPracticeId)
                      .toList();

                  if (docs.isEmpty) return const Text('No other practice sessions to compare.');

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Practice to Compare',
                      border: OutlineInputBorder(),
                    ),
                    value: _secondPracticeId,
                    items: docs.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(_generateLabelFromDoc(doc)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _secondPracticeId = value;
                        _secondPracticeData = null;
                        _secondTotalTime = 0;
                      });
                      _loadSecondPracticeData();
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              if (_secondPracticeData != null) ...[
                const Text(
                  'Second Practice:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                _buildPracticeSummary(_secondPracticeData!),
                const SizedBox(height: 20),
                const Text(
                  'Comparison:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                _buildComparison(_firstPracticeData!, _secondPracticeData!),
              ]
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparison(Map<String, dynamic> first, Map<String, dynamic> second) {
    int firstLapCount = first['lapCount'] ?? 0;
    int secondLapCount = second['lapCount'] ?? 0;

    double firstLapDistance = (first['lapDistance'] ?? 0.0).toDouble();
    double secondLapDistance = (second['lapDistance'] ?? 0.0).toDouble();

    int firstTotalTime = first['totalTime'] ?? 0;
    int secondTotalTime = second['totalTime'] ?? 0;

    double firstAvgSpeed = firstTotalTime > 0 ? firstLapDistance * firstLapCount / firstTotalTime : 0.0;
    double secondAvgSpeed = secondTotalTime > 0 ? secondLapDistance * secondLapCount / secondTotalTime : 0.0;

    String compareInt(int a, int b) => a > b ? '↑' : a < b ? '↓' : '–';
    String compareDouble(double a, double b) => a > b ? '↑' : a < b ? '↓' : '–';

    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Metric', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Practice 1\n${_formatPracticeDate(_firstPracticeData!['timestamp'])}'),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Practice 2\n${_formatPracticeDate(_secondPracticeData!['timestamp'])}'),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Trend', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Lap Count'),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Text('$firstLapCount')),
          Padding(padding: const EdgeInsets.all(8), child: Text('$secondLapCount')),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(compareInt(firstLapCount, secondLapCount)),
          ),
        ]),
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Lap Distance (m)'),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Text(firstLapDistance.toStringAsFixed(2))),
          Padding(padding: const EdgeInsets.all(8), child: Text(secondLapDistance.toStringAsFixed(2))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(compareDouble(firstLapDistance, secondLapDistance)),
          ),
        ]),
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Total Time'),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Text(_formatDuration(Duration(seconds: firstTotalTime)))),
          Padding(padding: const EdgeInsets.all(8), child: Text(_formatDuration(Duration(seconds: secondTotalTime)))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(compareInt(firstTotalTime, secondTotalTime)),
          ),
        ]),
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Average Speed (m/s)'),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Text(firstAvgSpeed.toStringAsFixed(2))),
          Padding(padding: const EdgeInsets.all(8), child: Text(secondAvgSpeed.toStringAsFixed(2))),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(compareDouble(firstAvgSpeed, secondAvgSpeed)),
          ),
        ]),
      ],
    );
  }

  String _formatPracticeDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }
}