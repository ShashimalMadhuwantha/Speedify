import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Lap times and speeds saved successfully'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.speed, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Text(
                'Live Practice Session',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Distance/Lap',
                  '${lapDistance.toStringAsFixed(2)}m',
                  Icons.straighten,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Laps',
                  '$lapCount',
                  Icons.repeat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLapCard(int index, Map<String, String>? lapData) {
    if (lapData == null) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_run, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lap ${index + 1}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Waiting for data...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final lapTimeSeconds = _calculateLapDurationSeconds(lapData);
    final speed = _calculateSpeed(lapDistance, lapTimeSeconds);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timer, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                Text(
                  'Lap ${index + 1}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildLapStat(
                    'Time',
                    '${lapTimeSeconds.toStringAsFixed(2)}s',
                    Icons.access_time,
                    Colors.orange.shade600,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildLapStat(
                    'Speed',
                    '${speed.toStringAsFixed(2)} m/s',
                    Icons.speed,
                    Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLapStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        title: Text(
          'Live Practice',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          _saving
              ? Container(
                  margin: EdgeInsets.all(16),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Container(
                  margin: EdgeInsets.all(8),
                  child: ElevatedButton.icon(
                    onPressed: _onSavePressed,
                    icon: Icon(Icons.save, size: 18),
                    label: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading practice data...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      SizedBox(height: 24),
                      Text(
                        'Lap Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: lapCount == 0
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.timer_off,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No lap data available',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Start your practice session to see lap times',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: lapCount,
                                itemBuilder: (context, index) {
                                  final lapKey = 'lap${index + 1}';
                                  final lapDataDynamic = lapTimes[lapKey];
                                  final lapData = lapDataDynamic != null
                                      ? Map<String, String>.from(lapDataDynamic)
                                      : null;

                                  return _buildLapCard(index, lapData);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
