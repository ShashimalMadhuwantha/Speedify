import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LivePracticePage extends StatefulWidget {
  final String userId;
  final String practiceId;
  final int lapCount; // total laps expected

  const LivePracticePage({
    Key? key,
    required this.userId,
    required this.practiceId,
    required this.lapCount,
  }) : super(key: key);

  @override
  State<LivePracticePage> createState() => _LivePracticePageState();
}

class _LivePracticePageState extends State<LivePracticePage> {
  final Color blueColor = const Color(0xFF1565C0);

  late DatabaseReference lapsRef;
  String practiceStatus = "Not started";
  bool _hasUpdatedFirestore = false;
  bool _isDirectionReversed = false;
  String _sessionState = "not_over"; // Read from realtime DB

  // Example lapDistance stored separately in practice doc, update this as needed
  double _selectedLapDistance = 1000.0; // Default or from your UI

  @override
  void initState() {
    super.initState();
    lapsRef = FirebaseDatabase.instance.ref("laps");

    // Read direction and session status
    lapsRef.child('direction').get().then((snapshot) {
      if (snapshot.exists) {
        final val = snapshot.value.toString();
        setState(() {
          _isDirectionReversed = (val.toLowerCase() == "reversed");
        });
      }
    });

    lapsRef.child('status').get().then((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _sessionState = snapshot.value.toString();
        });
      }
    });
  }

  Future<void> _updatePracticeDocLapDistance() async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Update lapDistance only on the practice document (not laps)
      await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('practices')
          .doc(widget.practiceId)
          .update({
        'lapDistance': _selectedLapDistance,
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

    for (int i = 1; i <= widget.lapCount; i++) {
      final lapData = lapsData[i];

      if (lapData != null) {
        final lapDocRef = lapsCollection.doc('lap_$i');

        // Only update time and speed fields; do not overwrite the whole doc
        batch.update(lapDocRef, {
          'time': lapData['time'] ?? 0,
          'speed': lapData['speed'] ?? 0.0,
        });
      }
    }

    try {
      await batch.commit();

      // Optionally update lapDistance in parent doc too (if needed)
      await _updatePracticeDocLapDistance();

      print("All lap times and speeds updated in Firestore, lapDistance preserved.");
    } catch (e) {
      print("Failed to update laps in Firestore: $e");
    }
  }

  Future<void> _updateDirectionInRealtimeDB(bool reversed) async {
    try {
      await lapsRef.child('direction').set(reversed ? "reversed" : "not reversed");
      print("Direction updated to ${reversed ? "reversed" : "not reversed"}");
    } catch (e) {
      print("Failed to update direction: $e");
    }
  }

  Future<void> _resetSession() async {
    try {
      final snapshot = await lapsRef.get();
      if (snapshot.exists) {
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        for (var key in map.keys) {
          if (key != 'direction' && key != 'status') {
            await lapsRef.child(key).remove();
          }
        }
      }

      await lapsRef.child('status').set('not_over');
      setState(() {
        _hasUpdatedFirestore = false;
        practiceStatus = "Not started";
        _sessionState = "not_over";
      });

      print("Session reset successfully.");
    } catch (e) {
      print("Failed to reset session: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Practice'),
        backgroundColor: blueColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSession,
            tooltip: "Reset Session",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              'Status: $practiceStatus',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Reverse Direction'),
              value: _isDirectionReversed,
              activeColor: blueColor,
              onChanged: (value) {
                setState(() => _isDirectionReversed = value);
                _updateDirectionInRealtimeDB(value);
              },
            ),
            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: lapsRef.onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  Map<String, dynamic> lapsMap = {};
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    lapsMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                  }

                  final sessionStatusRaw = lapsMap['status']?.toString();
                  if (sessionStatusRaw != null && sessionStatusRaw != _sessionState) {
                    _sessionState = sessionStatusRaw;
                  }

                  Map<int, Map<String, dynamic>> structuredLaps = {};
                  for (var entry in lapsMap.entries) {
                    if (entry.key == 'direction' || entry.key == 'status') continue;
                    final lapData = Map<String, dynamic>.from(entry.value);
                    structuredLaps[lapData['lapNumber']] = lapData;
                  }

                  int lastAvailableLap = structuredLaps.keys.isNotEmpty
                      ? structuredLaps.keys.reduce((a, b) => a > b ? a : b)
                      : 0;

                  String currentStatus = "Not started";

                  if (_sessionState == "over") {
                    currentStatus = "Session Over";

                    if (!_hasUpdatedFirestore) {
                      _hasUpdatedFirestore = true;

                      _updateLapsInFirestore(structuredLaps).then((_) async {
                        for (var key in lapsMap.keys) {
                          if (key != 'direction' && key != 'status') {
                            await lapsRef.child(key).remove();
                          }
                        }
                        print("Lap data cleared after session over.");
                      });
                    }
                  } else if (lastAvailableLap == 0) {
                    currentStatus = "Not started";
                    _hasUpdatedFirestore = false;
                  } else if (lastAvailableLap < widget.lapCount) {
                    currentStatus = "Running (Lap $lastAvailableLap)";
                    _hasUpdatedFirestore = false;
                  } else if (lastAvailableLap >= widget.lapCount) {
                    currentStatus = "Completing...";
                    lapsRef.child('status').set('over');
                  }

                  if (practiceStatus != currentStatus) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          practiceStatus = currentStatus;
                        });
                      }
                    });
                  }

                  List<Widget> lapCards = [];
                  for (int i = 1; i <= widget.lapCount; i++) {
                    final lap = structuredLaps[i];
                    final isCurrentLap = i == lastAvailableLap && lastAvailableLap < widget.lapCount;

                    lapCards.add(
                      Card(
                        color: lap != null
                            ? (isCurrentLap ? blueColor.withOpacity(0.2) : null)
                            : Colors.grey.shade100,
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: lap != null
                                ? (isCurrentLap ? blueColor : Colors.grey)
                                : Colors.grey.shade400,
                            child: Text('$i', style: const TextStyle(color: Colors.white)),
                          ),
                          title: lap != null
                              ? Text('Time: ${lap['time']} sec')
                              : const Text('Waiting for data...'),
                          subtitle: lap != null
                              ? Text('Speed: ${lap['speed']} m/s\nDistance: ${_selectedLapDistance} m')
                              : const Text('Lap not yet completed'),
                          trailing: isCurrentLap
                              ? Icon(Icons.play_arrow, color: blueColor)
                              : (i == widget.lapCount && lastAvailableLap == widget.lapCount
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null),
                        ),
                      ),
                    );
                  }

                  return ListView(children: lapCards);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
