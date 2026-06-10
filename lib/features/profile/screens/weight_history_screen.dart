import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slyce/core/theme/app_theme.dart';
import 'package:slyce/widgets/app_snackbar.dart';

class _WeightEntry {
  final String date;
  final double weight;
  final double change;
  const _WeightEntry(this.date, this.weight, this.change);
}

class WeightHistoryScreen extends StatefulWidget {
  const WeightHistoryScreen({super.key});

  @override
  State<WeightHistoryScreen> createState() => _WeightHistoryScreenState();
}

class _WeightHistoryScreenState extends State<WeightHistoryScreen> {
  bool _isKg = true;

  final List<_WeightEntry> _log = const [
    _WeightEntry('Oct 15', 70.0, 2.0),
    _WeightEntry('Oct 15', 70.0, 2.0),
    _WeightEntry('Oct 15', 70.0, 2.0),
  ];

  // Placeholder chart data points (weight over time)
  final List<FlSpot> _spots = const [
    FlSpot(0, 72),
    FlSpot(1, 71.2),
    FlSpot(2, 71.8),
    FlSpot(3, 70.5),
    FlSpot(4, 70.9),
    FlSpot(5, 70.0),
    FlSpot(6, 70.3),
    FlSpot(7, 69.8),
    FlSpot(8, 70.0),
  ];

  double get _currentWeight => _isKg ? 70.0 : 70.0 * 2.20462;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kBgColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: kDarkColor),
        ),
        title: Text(
          'Weight History',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDarkColor,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLogSheet(context),
        backgroundColor: kPrimaryGreen,
        child: const Icon(Icons.add, color: kWhite),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        children: [
          _buildCurrentWeight(),
          const SizedBox(height: 20),
          _buildChart(),
          const SizedBox(height: 20),
          _buildLogHistory(),
        ],
      ),
    );
  }

  Widget _buildCurrentWeight() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Current Weight',
            style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
          ),
          const SizedBox(height: 8),
          Text(
            _isKg
                ? _currentWeight.toStringAsFixed(1)
                : _currentWeight.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              color: kDarkColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: kLightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _UnitTab(
                  label: 'KG',
                  selected: _isKg,
                  onTap: () => setState(() => _isKg = true),
                ),
                _UnitTab(
                  label: 'LBS',
                  selected: !_isKg,
                  onTap: () => setState(() => _isKg = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              'Weight Trend',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kDarkColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: kLightGrey,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 1,
                      getTitlesWidget: (val, _) => Text(
                        val.toInt().toString(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: kGreyColor,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 8,
                minY: 68,
                maxY: 74,
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots,
                    isCurved: true,
                    color: kPrimaryGreen,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          kPrimaryGreen.withValues(alpha: 0.25),
                          kPrimaryGreen.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log History',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kDarkColor,
            ),
          ),
          const SizedBox(height: 12),
          ..._log.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    entry.date,
                    style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
                  ),
                  const Spacer(),
                  Text(
                    '${entry.weight.toStringAsFixed(1)}${_isKg ? 'Kg' : 'Lbs'}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kDarkColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kPrimaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ ${entry.change.toStringAsFixed(0)}${_isKg ? 'kg' : 'lbs'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Weight',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kDarkColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 14, color: kDarkColor),
              decoration: InputDecoration(
                hintText: 'Enter weight (${_isKg ? 'kg' : 'lbs'})',
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                final val = double.tryParse(ctrl.text);
                if (val == null) return;
                Navigator.pop(ctx);
                showAppSnackbar(
                  'Weight logged: $val ${_isKg ? 'kg' : 'lbs'}',
                  type: AppSnackbarType.success,
                );
              },
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: kPrimaryGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Save',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kWhite,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnitTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: selected ? kPrimaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? kWhite : kGreyColor,
          ),
        ),
      ),
    );
  }
}


