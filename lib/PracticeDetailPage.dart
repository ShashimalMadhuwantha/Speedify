import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class PracticeDetailPage extends StatefulWidget {
  final String userId;
  final String practiceId;
  final int lapCount;

  const PracticeDetailPage({
    Key? key,
    required this.userId,
    required this.practiceId,
    required this.lapCount,
  }) : super(key: key);

  @override
  State<PracticeDetailPage> createState() => _PracticeDetailPageState();
}

class _PracticeDetailPageState extends State<PracticeDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<List<Map<String, dynamic>>> _lapDataFuture;

  final Color primaryBlue = const Color(0xFF1565C0);
  final Color lightBlue = const Color(0xFFE3F2FD);

  @override
  void initState() {
    super.initState();
    _lapDataFuture = _fetchLaps();
  }

  Future<List<Map<String, dynamic>>> _fetchLaps() async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('practices')
        .doc(widget.practiceId)
        .collection('laps')
        .get();

    return snapshot.docs.map((doc) {
      return {
        'lapNumber': doc['lapNumber'],
        'time': doc['time'],
        'speed': doc['speed'],
      };
    }).toList();
  }

  Map<String, dynamic>? _findLap(List<Map<String, dynamic>> laps, int lapNumber) {
    try {
      return laps.firstWhere((lap) => lap['lapNumber'] == lapNumber);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBlue,
      appBar: AppBar(
        elevation: 4,
        centerTitle: true,
        title: const Text('Practice Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lapDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryBlue));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No laps data found.'));
          }

          final laps = snapshot.data!;

          return Column(
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    shadowColor: Colors.blueGrey,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SfCartesianChart(
                        backgroundColor: Colors.white,
                        plotAreaBackgroundColor: Colors.white,
                        title: ChartTitle(
                          text: 'Speed per Lap',
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        primaryXAxis: CategoryAxis(
                          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        primaryYAxis: NumericAxis(
                          title: AxisTitle(text: 'Speed (m/s)'),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        series: <CartesianSeries<Map<String, dynamic>, String>>[
                          ColumnSeries<Map<String, dynamic>, String>(
                            dataSource: laps,
                            xValueMapper: (lap, _) => 'Lap ${lap['lapNumber']}',
                            yValueMapper: (lap, _) {
                              var speed = lap['speed'];
                              return speed is int ? speed.toDouble() : speed;
                            },
                            color: primaryBlue,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 1,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: widget.lapCount,
                  itemBuilder: (context, index) {
                    final lapNumber = index + 1;
                    final lap = _findLap(laps, lapNumber);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: lap != null ? Colors.white : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: lap != null ? primaryBlue : Colors.grey.shade400,
                          child: Text(
                            '$lapNumber',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: lap != null
                            ? Text(
                                'Time: ${lap['time']} sec',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              )
                            : const Text(
                                'No data yet',
                                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                              ),
                        subtitle: lap != null
                            ? Text(
                                'Speed: ${lap['speed']} m/s',
                                style: const TextStyle(color: Colors.black54),
                              )
                            : const Text(
                                'Lap not completed',
                                style: TextStyle(color: Colors.black54),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
