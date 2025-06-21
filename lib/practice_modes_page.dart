import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PracticeModesPage extends StatefulWidget {
  const PracticeModesPage({Key? key}) : super(key: key);

  @override
  _PracticeModesPageState createState() => _PracticeModesPageState();
}

class _PracticeModesPageState extends State<PracticeModesPage> {
  bool _isLapDirectionSwitchEnabled = false;
  final blueColor = Color(0xFF1565C0);

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  void _onToggleSwitch(bool value) async {
    setState(() {
      _isLapDirectionSwitchEnabled = value;
    });

    // Save reverseMode at fixed path in Realtime Database
    try {
      await _dbRef.child('reverseMode').set(value);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update mode: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Practice Modes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: blueColor,
            ),
          ),
          SizedBox(height: 24),
          Center(
            child: Image.network(
              'https://cdn-icons-png.flaticon.com/512/889/889105.png',
              width: 120,
              height: 120,
              color: blueColor.withOpacity(0.8),
              colorBlendMode: BlendMode.modulate,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Enable "Lap Direction Mode" to run continuously back and forth between your set distances. '
            'This mode automatically switches the running direction each lap, simulating interval training on a track.',
            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
          ),
          SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enable Lap Direction Mode',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              Switch(
                value: _isLapDirectionSwitchEnabled,
                activeColor: blueColor,
                onChanged: _onToggleSwitch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
