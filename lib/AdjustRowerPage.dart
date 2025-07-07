import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'live_practice_page.dart';

class Adjustrower extends StatefulWidget {
  final String userId;
  final String practiceId;
  final int lapCount;

  const Adjustrower({
    Key? key,
    required this.userId,
    required this.practiceId,
    required this.lapCount,
  }) : super(key: key);

  @override
  _AdjustrowerState createState() => _AdjustrowerState();
}

class _AdjustrowerState extends State<Adjustrower> {
  final Color blueColor = Color(0xFF1565C0);
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool _isUpdating = false;

  Future<void> _setReadyStatusAndNavigate() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await _dbRef.child('status').set('ready');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LivePracticePage(
            userId: widget.userId,
            practiceId: widget.practiceId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjustrower'),
        backgroundColor: blueColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Adjust the rower for you',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Image.network(
                'https://cdn-icons-png.flaticon.com/512/889/889105.png',
                width: 120,
                height: 120,
                color: blueColor.withOpacity(0.8),
                colorBlendMode: BlendMode.modulate,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Get Ready!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(height: 32),

            Center(
              child: _isUpdating
                  ? CircularProgressIndicator(color: blueColor)
                  : ElevatedButton(
                      onPressed: _setReadyStatusAndNavigate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 6,
                      ),
                      child: const Text(
                        'Ready',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
