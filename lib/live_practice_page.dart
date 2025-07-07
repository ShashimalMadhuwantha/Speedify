import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

class LivePracticePage extends StatefulWidget {
  final String userId;
  final String practiceId;

  const LivePracticePage({
    Key? key,
    required this.userId,
    required this.practiceId,
  }) : super(key: key);

  @override
  _LivePracticePageState createState() => _LivePracticePageState();
}

class _LivePracticePageState extends State<LivePracticePage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int lapCount = 0;
  double lapDistance = 0.0;
  Map<String, dynamic> lapTimes = {};
  String status = '';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _listenRealtimeData();
  }

  void _listenRealtimeData() {
    _dbRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map<dynamic, dynamic>) {
        setState(() {
          lapCount = data['lapcount'] ?? 0;
          lapDistance = (data['distance'] ?? 0).toDouble();
          lapTimes = Map<String, dynamic>.from(data['lapTimes'] ?? {});
          status = data['status'] ?? '';
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    });
  }

  Duration _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 3) return Duration.zero;
    final hour = int.tryParse(parts[0]) ?? 0;
    final min = int.tryParse(parts[1]) ?? 0;
    final sec = int.tryParse(parts[2]) ?? 0;
    return Duration(hours: hour, minutes: min, seconds: sec);
  }

  double _calculateLapDurationSeconds(Map<String, String> lap) {
    final sensor1Time = _parseTime(lap['sensor1'] ?? '');
    final sensor2Time = _parseTime(lap['sensor2'] ?? '');

    Duration diff;
    if (sensor2Time >= sensor1Time) {
      diff = sensor2Time - sensor1Time;
    } else {
      diff = sensor1Time - sensor2Time;
    }

    return diff.inMilliseconds / 1000.0;
  }

  double _calculateSpeed(double distance, double timeSeconds) {
    if (timeSeconds <= 0) return 0.0;
    return distance / timeSeconds; // meters per second
  }

  Future<void> _updatePracticeDocLapDistance() async {
    final firestore = FirebaseFirestore.instance;

    try {
      await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('practices')
          .doc(widget.practiceId)
          .update({
        'lapDistance': lapDistance,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("Practice lapDistance updated.");
    } catch (e) {
      print("Failed to update practice lapDistance: $e");
    }
  }

  Future<void> _updateLapsInFirestore(Map<int, Map<String, dynamic>> lapsData) async {
    final firestore = FirebaseFirestore.instance;

    final practiceDocRef = firestore
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .doc(widget.practiceId);

    final lapsCollection = practiceDocRef.collection('laps');

    WriteBatch batch = firestore.batch();

    for (int i = 1; i <= lapCount; i++) {
      final lapData = lapsData[i];

      if (lapData != null) {
        final lapDocRef = lapsCollection.doc('lap_$i');

        batch.update(lapDocRef, {
          'time': lapData['time'] ?? 0,
          'speed': lapData['speed'] ?? 0.0,
        });
      }
    }

    try {
      await batch.commit();
      await _updatePracticeDocLapDistance();

      print("All lap times and speeds updated in Firestore, lapDistance preserved.");
    } catch (e) {
      print("Failed to update laps in Firestore: $e");
    }
  }

  void _onSavePressed() async {
    setState(() {
      _saving = true;
    });

    // Prepare lap data map for Firestore batch update
    Map<int, Map<String, dynamic>> lapsData = {};

    for (int i = 1; i <= lapCount; i++) {
      final lapKey = 'lap$i';
      final lapDataDynamic = lapTimes[lapKey];

      if (lapDataDynamic != null) {
        final lapData = Map<String, String>.from(lapDataDynamic);
        final lapTimeSeconds = _calculateLapDurationSeconds(lapData);
        final speed = _calculateSpeed(lapDistance, lapTimeSeconds);

        lapsData[i] = {
          'time': lapTimeSeconds,
          'speed': speed,
        };
      }
    }

    await _updateLapsInFirestore(lapsData);

    setState(() {
      _saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lap times and speeds saved successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Practice'),
        actions: [
          _saving
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _onSavePressed,
                  tooltip: 'Save lap data',
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distance per lap: ${lapDistance.toStringAsFixed(2)} meters',
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text('Lap Count: $lapCount', style: const TextStyle(fontSize: 18)),
                  const Divider(height: 30),
                  Expanded(
                    child: lapCount == 0
                        ? const Center(child: Text('No lap data found'))
                        : ListView.builder(
                            itemCount: lapCount,
                            itemBuilder: (context, index) {
                              final lapKey = 'lap${index + 1}';
                              final lapDataDynamic = lapTimes[lapKey];

                              if (lapDataDynamic == null) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    title: Text('Lap ${index + 1}'),
                                    subtitle: const Text('No lap time data'),
                                  ),
                                );
                              }

                              final lapData = Map<String, String>.from(lapDataDynamic);
                              final lapTimeSeconds = _calculateLapDurationSeconds(lapData);
                              final speed = _calculateSpeed(lapDistance, lapTimeSeconds);

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Lap ${index + 1}',
                                        style: const TextStyle(
                                            fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Lap Time: ${lapTimeSeconds.toStringAsFixed(2)} seconds'),
                                      Text('Speed: ${speed.toStringAsFixed(2)} m/s'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
