import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SprinterDashboard extends StatefulWidget {
  final String sprinterId;

  const SprinterDashboard({Key? key, required this.sprinterId}) : super(key: key);

  @override
  _SprinterDashboardState createState() => _SprinterDashboardState();
}

class _SprinterDashboardState extends State<SprinterDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<DocumentSnapshot> _sprinterFuture;

  @override
  void initState() {
    super.initState();
    _sprinterFuture = _firestore.collection('sprinters').doc(widget.sprinterId).get();
  }

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);
    final white = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sprinter Dashboard'),
        backgroundColor: blueColor,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _sprinterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: blueColor));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading profile: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Sprinter profile not found.',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final sprinterData = snapshot.data!.data() as Map<String, dynamic>;

          return Container(
            color: lightBlue,
            padding: EdgeInsets.all(20),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: blueColor,
                      child: Icon(Icons.person, size: 60, color: white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      sprinterData['name'] ?? 'No Name',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      sprinterData['email'] ?? 'No Email',
                      style: TextStyle(fontSize: 18, color: blueColor.withOpacity(0.7)),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Welcome to your dashboard!',
                      style: TextStyle(fontSize: 20, color: blueColor),
                    ),
                    SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const lightBlue = Color(0xFFBBDEFB);
