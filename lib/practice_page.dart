import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'live_practice_page.dart';
import 'AdjustRowerPage.dart';

class PracticePage extends StatefulWidget {
  final String userId;

  const PracticePage({Key? key, required this.userId}) : super(key: key);

  @override
  _PracticePageState createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _lapCountController = TextEditingController();

  bool _loading = false;
  String _error = '';
  double? _selectedLapDistance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _savePractice() async {
    if (!_formKey.currentState!.validate() || _selectedLapDistance == null) return;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      int lapCount = int.parse(_lapCountController.text.trim());

      // Save to Firestore
      DocumentReference practiceRef = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('practices')
          .add({
        'lapDistance': _selectedLapDistance,
        'lapCount': lapCount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      for (int i = 1; i <= lapCount; i++) {
        await practiceRef.collection('laps').doc('lap_$i').set({
          'lapNumber': i,
          'time': 0,
          'speed': 0.0,
        });
      }

      // Save raw data directly to Realtime Database root (overwrites all other data!)
      final DatabaseReference realtimeDbRef = FirebaseDatabase.instance.ref();
      await realtimeDbRef.set({
        'distance': _selectedLapDistance,
        'lapcount': lapCount,
        'status': 'init',
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Adjustrower(
            userId: widget.userId,
            practiceId: practiceRef.id,
            lapCount: lapCount,
          ),
        ),
      );

      _lapCountController.clear();
      setState(() {
        _selectedLapDistance = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to save practice: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _lapCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);
    final List<double> lapDistances = [100, 200, 500, 1000];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'New Practice',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                SizedBox(height: 25),

                if (_error.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error,
                      style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold),
                    ),
                  ),
                SizedBox(height: 15),

                Text(
                  'Lap Distance (meters)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<double>(
                    value: _selectedLapDistance,
                    decoration: InputDecoration(border: InputBorder.none),
                    isExpanded: true,
                    hint: Text('Select lap distance'),
                    items: lapDistances.map((value) {
                      return DropdownMenuItem<double>(
                        value: value,
                        child: Text('${value.toInt()} meters'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLapDistance = value;
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select a lap distance' : null,
                  ),
                ),

                SizedBox(height: 20),

                TextFormField(
                  controller: _lapCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Lap Count',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter lap count';
                    final number = int.tryParse(value);
                    if (number == null || number <= 0) return 'Enter a valid positive integer';
                    return null;
                  },
                ),
                SizedBox(height: 35),

                _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(blueColor),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _savePractice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 6,
                        ),
                        child: Text(
                          'Start Practice',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
