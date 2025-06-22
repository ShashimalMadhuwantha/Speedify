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
  bool _hasUpdatedFirestore = false;  // flag to avoid repeated updates

  // New: switch state for direction
  bool _isDirectionReversed = false;

  @override
  void initState() {
    super.initState();
    lapsRef = FirebaseDatabase.instance.ref("laps");

    // Listen once for initial direction value in realtime DB and set switch state
    lapsRef.child('direction').get().then((snapshot) {
      if (snapshot.exists) {
        final val = snapshot.value.toString();
        setState(() {
          _isDirectionReversed = (val.toLowerCase() == "reversed");
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
      batch.update(lapDoc, {
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

  // New: Function to update direction in Realtime Database
  Future<void> _updateDirectionInRealtimeDB(bool reversed) async {
    try {
      await lapsRef.child('direction').set(reversed ? "reversed" : "not reversed");
      print("Direction updated to ${reversed ? "reversed" : "not reversed"} in Realtime DB.");
    } catch (e) {
      print("Failed to update direction in Realtime DB: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Practice'),
        backgroundColor: blueColor,
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

            // New: Direction switch
            SwitchListTile(
              title: const Text('Reverse Direction'),
              value: _isDirectionReversed,
              activeColor: blueColor,
              onChanged: (bool value) {
                setState(() {
                  _isDirectionReversed = value;
                });
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

                  // Create a map of lapNumber -> data
                  Map<int, Map<String, dynamic>> structuredLaps = {};
                  for (var entry in lapsMap.entries) {
                    // Skip the 'direction' key, which is a string, not a lap map
                    if (entry.key == 'direction') continue;

                    final lapData = Map<String, dynamic>.from(entry.value);
                    structuredLaps[lapData['lapNumber']] = lapData;
                  }

                  // Determine currentLap and session status
                  int lastAvailableLap = structuredLaps.keys.isNotEmpty
                      ? structuredLaps.keys.reduce((a, b) => a > b ? a : b)
                      : 0;

                  String currentStatus;
                  if (lastAvailableLap == 0) {
                    currentStatus = "Not started";
                    _hasUpdatedFirestore = false; // reset flag if new session
                  } else if (lastAvailableLap < widget.lapCount) {
                    currentStatus = "Running (Lap $lastAvailableLap)";
                    _hasUpdatedFirestore = false; // reset flag while running
                  } else {
                    currentStatus = "Session Over";

                    // Update Firestore laps once when session ends
                    if (!_hasUpdatedFirestore) {
                      _hasUpdatedFirestore = true;
                      _updateLapsInFirestore(structuredLaps);
                    }
                  }

                  // Update state only if changed (to avoid build loop)
                  if (practiceStatus != currentStatus) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          practiceStatus = currentStatus;
                        });
                      }
                    });
                  }

                  // Build full list of lap cards (some may be missing)
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
                            child: Text(
                              '$i',
                              style: const TextStyle(color: Colors.white),
                            ),
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
