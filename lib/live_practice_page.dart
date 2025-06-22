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

  Future<void> _updateLapsInFirestore(Map<int, Map<String, dynamic>> lapsData) async {
    final firestore = FirebaseFirestore.instance;
    final WriteBatch batch = firestore.batch();

    final lapsCollection = firestore
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .doc(widget.practiceId)
        .collection('laps');

    for (var entry in lapsData.entries) {
      final lapDoc = lapsCollection.doc('lap_${entry.key}');
      batch.set(lapDoc, {
        'time': entry.value['time'],
        'speed': entry.value['speed'],
      });
    }

    try {
      await batch.commit();
      print("Laps updated in Firestore successfully.");
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

                  // Update session status from DB
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
                        // Clear lap data but keep 'direction' and 'status'
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
                    // Trigger session over update
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

                  // Build lap cards
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
                              ? Text('Speed: ${lap['speed']} m/s')
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
