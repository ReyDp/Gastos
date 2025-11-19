import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GraphWidget extends StatelessWidget {
  final List<Map<String, dynamic>> expenses;

  const GraphWidget({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter =
        NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
    final spots = <FlSpot>[];
    if (expenses.isNotEmpty) {
      for (var expense in expenses) {
        final timestamp = expense['timestamp'] as DateTime?;
        final amount = (expense['amount'] as num?)?.toDouble();

        if (timestamp != null && amount != null) {
          spots.add(FlSpot(timestamp.day.toDouble(), amount));
        }
      }
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            color: Colors.blue,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.3),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 5 == 0 && value.toInt() != 0) {
                  return Text(value.toInt().toString());
                }
                return const Text('');
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueAccent,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  currencyFormatter.format(spot.y),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        minX: 1,
        maxX: 31,
      ),
    );
  }
}
