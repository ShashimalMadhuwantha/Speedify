import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LivePracticePage extends StatefulWidget {
  final String userId;
  final String practiceId;
  final int lapCount;

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
  bool _hasUpdatedFirestore = false;
  bool _isDirectionReversed = false;
  String _sessionState = "not_over";
  double _selectedLapDistance = 1000.0;

  @override
  void initState() {
    super.initState();
    lapsRef = FirebaseDatabase.instance.ref("laps");

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
      await firestore
          .collection('users')
          .doc(widget.userId)
          .collection('practices')
          .doc(widget.practiceId)
          .update({
        'lapDistance': _selectedLapDistance,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Failed to update practice lapDistance: $e");
    }
  }

  Future<void> _updateLapsInFirestore(Map<int, Map<String, dynamic>> lapsData) async {
    final firestore = FirebaseFirestore.instance;
    final lapsCollection = firestore
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .doc(widget.practiceId)
        .collection('laps');

    WriteBatch batch = firestore.batch();

    for (int i = 1; i <= widget.lapCount; i++) {
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

      final snapshot = await lapsRef.get();
      if (snapshot.exists) {
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        for (var key in map.keys) {
          if (key != 'direction' && key != 'status') {
            await lapsRef.child(key).remove();
          }
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Session Over'),
            content: const Text('All laps have been completed and recorded.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print("Failed to update laps in Firestore: $e");
    }
  }

  Future<void> _updateDirectionInRealtimeDB(bool reversed) async {
    try {
      await lapsRef.child('direction').set(reversed ? "reversed" : "not reversed");
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
        _sessionState = "not_over";
      });
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
            StreamBuilder<DatabaseEvent>(
              stream: lapsRef.onValue,
              builder: (context, snapshot) {
                Map<String, dynamic> lapsMap = {};
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  lapsMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                }

                Map<int, Map<String, dynamic>> structuredLaps = {};
                for (var entry in lapsMap.entries) {
                  if (entry.key == 'direction' || entry.key == 'status') continue;
                  final lapData = Map<String, dynamic>.from(entry.value);
                  structuredLaps[lapData['lapNumber']] = lapData;
                }

                int lastLap = structuredLaps.keys.isNotEmpty
                    ? structuredLaps.keys.reduce((a, b) => a > b ? a : b)
                    : 0;

                return Text(
                  'Ongoing Lap: ${lastLap + 1} / ${widget.lapCount}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                );
              },
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

                  int lastLap = structuredLaps.keys.isNotEmpty
                      ? structuredLaps.keys.reduce((a, b) => a > b ? a : b)
                      : 0;

                  if (_sessionState == "over") {
                    if (structuredLaps.length < widget.lapCount) {
                      lapsRef.child('status').set('not_over');
                      _hasUpdatedFirestore = false;
                      _sessionState = "not_over";
                    } else if (!_hasUpdatedFirestore) {
                      _hasUpdatedFirestore = true;
                      _updateLapsInFirestore(structuredLaps);
                    }
                  } else if (lastLap >= widget.lapCount) {
                    lapsRef.child('status').set('over');
                  }

                  List<Widget> lapCards = [];
                  for (int i = 1; i <= widget.lapCount; i++) {
                    final lap = structuredLaps[i];
                    final isCurrentLap = i == lastLap + 1;

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
                              : const Text('Lap not completed yet'),
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
