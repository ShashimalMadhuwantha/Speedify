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

  // Theme colors
  final Color primaryBlue = const Color(0xFF1565C0);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color accentBlue = const Color(0xFF64B5F6);

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
        elevation: 6,
        centerTitle: true,
        backgroundColor: primaryBlue,
        title: const Text(
          'Practice Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _lapDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryBlue));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No laps data found.',
                style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.black54),
              ),
            );
          }

          final laps = snapshot.data!;

          return Column(
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 10,
                    shadowColor: primaryBlue.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SfCartesianChart(
                        backgroundColor: Colors.white,
                        plotAreaBackgroundColor: Colors.white,
                        title: ChartTitle(
                          text: 'Speed per Lap',
                          textStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: primaryBlue,
                            letterSpacing: 0.6,
                          ),
                        ),
                        primaryXAxis: CategoryAxis(
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                            fontSize: 14,
                          ),
                          majorGridLines: const MajorGridLines(width: 0),
                        ),
                        primaryYAxis: NumericAxis(
                          title: AxisTitle(
                            text: 'Speed (m/s)',
                            textStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                              fontSize: 14,
                            ),
                          ),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryBlue,
                            fontSize: 13,
                          ),
                          majorGridLines: const MajorGridLines(
                            dashArray: <double>[5, 5],
                          ),
                          axisLine: const AxisLine(width: 0),
                        ),
                        series: <CartesianSeries<Map<String, dynamic>, String>>[
                          ColumnSeries<Map<String, dynamic>, String>(
                            dataSource: laps,
                            xValueMapper: (lap, _) => 'Lap ${lap['lapNumber']}',
                            yValueMapper: (lap, _) {
                              var speed = lap['speed'];
                              return speed is int ? speed.toDouble() : speed;
                            },
                            color: accentBlue,
                            borderRadius: BorderRadius.circular(8),
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    itemCount: widget.lapCount,
                    itemBuilder: (context, index) {
                      final lapNumber = index + 1;
                      final lap = _findLap(laps, lapNumber);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: lap != null
                              ? LinearGradient(
                                  colors: [Colors.white, lightBlue.withOpacity(0.7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [Colors.grey.shade100, Colors.grey.shade50],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: lap != null ? primaryBlue.withOpacity(0.2) : Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: lap != null ? primaryBlue : Colors.grey.shade400,
                            child: Text(
                              '$lapNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          title: lap != null
                              ? Text(
                                  'Time: ${lap['time']} sec',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                )
                              : const Text(
                                  'No data yet',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black45,
                                  ),
                                ),
                          subtitle: lap != null
                              ? Text(
                                  'Speed: ${lap['speed']} m/s',
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const Text(
                                  'Lap not completed',
                                  style: TextStyle(
                                    color: Colors.black38,
                                  ),
                                ),
                          trailing: lap != null
                              ? Icon(Icons.check_circle, color: primaryBlue)
                              : Icon(Icons.remove_circle_outline, color: Colors.grey.shade400),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
