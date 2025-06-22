import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'PracticeComparePage.dart';
import 'PracticeDetailPage.dart';

class PracticeHistoryPage extends StatelessWidget {
  final String userId;

  const PracticeHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final blueColor = Color(0xFF1565C0);

    return Scaffold(
      appBar: AppBar(
        title: Text("Practice History"),
        backgroundColor: blueColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('practices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final practices = snapshot.data!.docs;

          if (practices.isEmpty) return Center(child: Text("No practices found."));

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: practices.length,
            itemBuilder: (context, index) {
              final practice = practices[index];
              final practiceId = practice.id;
              final lapDistance = practice['lapDistance'];
              final lapCount = practice['lapCount'];
              final timestamp = (practice['timestamp'] as Timestamp?)?.toDate();

              return Card(
                elevation: 4,
                margin: EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Practice ID: $practiceId",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text("Lap Distance: ${lapDistance.toString()} meters"),
                      Text("Lap Count: $lapCount"),
                      Text("Date: ${timestamp?.toLocal().toString().split(' ')[0] ?? 'Unknown'}"),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // View Detail Button
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PracticeDetailPage(
                                    userId: userId,
                                    practiceId: practiceId,
                                    lapCount: lapCount,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text("View Details"),
                          ),
                          SizedBox(width: 10),
                          // Compare Button
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PracticeComparePage(
                                    userId: userId,
                                    firstPracticeId: practiceId,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text("Compare"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
