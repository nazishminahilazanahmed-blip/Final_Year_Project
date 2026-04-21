import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const StatsScreen({super.key, required this.data});

  List<Map<String, dynamic>> getTopApps() {
    if (data.isEmpty) return [];
    List<Map<String, dynamic>> sorted = List.from(data);
    sorted.sort((a, b) => b['timeInForeground'].compareTo(a['timeInForeground']));
    return sorted.take(5).toList();
  }

  double getTotalTime() {
    return data.fold<double>(
        0, (sum, app) => sum + ((app['timeInForeground'] ?? 0) / 60000));
  }

  @override
  Widget build(BuildContext context) {
    final topApps = getTopApps();
    final totalMinutes = getTotalTime();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Usage Statistics"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: topApps.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No Usage Data Available"),
            SizedBox(height: 8),
            Text("Use your phone normally, then come back"),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== TOTAL TIME CARD ==========
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    "Total Screen Time",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${totalMinutes.toStringAsFixed(0)} minutes",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${(totalMinutes / 60).toStringAsFixed(1)} hours",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            // ========== PIE CHART SECTION ==========
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Usage Distribution",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 280,
              width: double.infinity,
              child: PieChart(
                PieChartData(
                  sections: topApps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final app = entry.value;
                    final minutes = (app['timeInForeground'] ?? 0) / 60000;
                    final percentage = totalMinutes > 0 ? (minutes / totalMinutes * 100) : 0;

                    final List<Color> colors = [
                      Colors.deepPurple,
                      Colors.purple,
                      const Color(0xFF9C27B0),
                      const Color(0xFFBA68C8),
                      const Color(0xFFCE93D8),
                    ];

                    return PieChartSectionData(
                      value: minutes,
                      title: percentage > 5 ? "${percentage.toStringAsFixed(0)}%" : "",
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      color: colors[index % colors.length],
                      radius: 110,
                      titlePositionPercentageOffset: 0.55,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 45,
                  startDegreeOffset: -90,
                ),
              ),
            ),

            // Legend
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: topApps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final app = entry.value;
                  final List<Color> colors = [
                    Colors.deepPurple,
                    Colors.purple,
                    const Color(0xFF9C27B0),
                    const Color(0xFFBA68C8),
                    const Color(0xFFCE93D8),
                  ];
                  final minutes = ((app['timeInForeground'] ?? 0) / 60000).toInt();
                  final appName = app['appName'] ?? app['packageName'] ?? 'Unknown';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors[index % colors.length].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors[index % colors.length].withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getShortName(appName),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          " ($minutes min)",
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ========== BAR CHART SECTION ==========
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Usage by App (Minutes)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 350,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, left: 8),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: topApps.fold<double>(
                        0, (max, app) =>
                    max > ((app['timeInForeground'] ?? 0) / 60000)
                        ? max
                        : ((app['timeInForeground'] ?? 0) / 60000)) + 5,
                    barGroups: topApps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final app = entry.value;
                      final minutes = (app['timeInForeground'] ?? 0) / 60000;

                      final List<Color> colors = [
                        Colors.deepPurple,
                        Colors.purple,
                        const Color(0xFF9C27B0),
                        const Color(0xFFBA68C8),
                        const Color(0xFFCE93D8),
                      ];

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: minutes,
                            color: colors[index % colors.length],
                            width: 40,
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: minutes + 2,
                              color: colors[index % colors.length].withOpacity(0.1),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < topApps.length) {
                              final appName = topApps[index]['appName'] ??
                                  topApps[index]['packageName'] ??
                                  'App';
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Transform.rotate(
                                  angle: -0.3,
                                  child: Text(
                                    _getShortName(appName),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.3),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ),

            // ========== TOP 5 APPS LIST ==========
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Top 5 Apps by Usage",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...topApps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final app = entry.value;
                      final minutes = (app['timeInForeground'] ?? 0) / 60000;
                      final percentage = totalMinutes > 0 ? (minutes / totalMinutes * 100) : 0;
                      final appName = app['appName'] ?? app['packageName'] ?? 'Unknown';

                      final List<Color> colors = [
                        Colors.deepPurple,
                        Colors.purple,
                        const Color(0xFF9C27B0),
                        const Color(0xFFBA68C8),
                        const Color(0xFFCE93D8),
                      ];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  "${index + 1}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                appName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                "${percentage.toStringAsFixed(1)}%",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _getShortName(String name) {
    if (name.length <= 12) return name;
    return '${name.substring(0, 10)}...';
  }
}