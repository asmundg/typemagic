import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import 'stats_repository.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _selectedDays = 30; // 7, 30, or 0 for all

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(statsRepositoryProvider);
    final totalStats = repo.getTotalStats();
    final dailyStats =
        repo.getDailyStats(days: _selectedDays > 0 ? _selectedDays : null);
    final keyStats = repo.getKeyStatsAggregate();
    final personalBests = repo.getPersonalBests();
    final recentHistory = repo.getHistory(limit: 50);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview cards
              _OverviewCards(stats: totalStats),
              const SizedBox(height: 32),

              // Time range selector + charts
              _TimeRangeRow(
                selectedDays: _selectedDays,
                onChanged: (days) => setState(() => _selectedDays = days),
              ),
              const SizedBox(height: 16),
              _WpmChart(dailyStats: dailyStats),
              const SizedBox(height: 16),
              _AccuracyChart(dailyStats: dailyStats),
              const SizedBox(height: 32),

              // Keyboard heatmap
              const _SectionTitle(text: 'Tastatur'),
              const SizedBox(height: 12),
              _KeyboardHeatmap(keyStats: keyStats),
              const SizedBox(height: 24),

              // Problem keys
              _ProblemKeys(keyStats: keyStats),
              const SizedBox(height: 32),

              // Personal bests
              const _SectionTitle(text: 'Personlige rekorder'),
              const SizedBox(height: 12),
              _PersonalBests(bests: personalBests),
              const SizedBox(height: 32),

              // Recent history
              const _SectionTitle(text: 'Siste tester'),
              const SizedBox(height: 12),
              _RecentHistory(history: recentHistory),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview cards
// ---------------------------------------------------------------------------

class _OverviewCards extends StatelessWidget {
  final TotalStats stats;
  const _OverviewCards({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(label: 'Tester', value: '${stats.totalTests}'),
        _StatCard(label: 'Total tid', value: _formatDuration(stats.totalTime)),
        _StatCard(label: 'Ord', value: '${stats.totalWords}'),
        _StatCard(
          label: 'Snitt WPM',
          value: stats.avgWpm.round().toString(),
          color: AppColors.speedLine,
        ),
        _StatCard(
          label: 'Snitt nøyaktighet',
          value: '${stats.avgAccuracy.round()}%',
          color: AppColors.accent,
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}t ${d.inMinutes % 60}m';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title + time range selector
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.monoStyleSmall.copyWith(
        color: AppColors.textMuted,
        fontSize: 14,
        letterSpacing: 1,
      ),
    );
  }
}

class _TimeRangeRow extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onChanged;

  const _TimeRangeRow({
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Fremgang',
          style: AppTheme.monoStyleSmall.copyWith(
            color: AppColors.textMuted,
            fontSize: 14,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        _RangeChip(
          label: '7d',
          selected: selectedDays == 7,
          onTap: () => onChanged(7),
        ),
        const SizedBox(width: 4),
        _RangeChip(
          label: '30d',
          selected: selectedDays == 30,
          onTap: () => onChanged(30),
        ),
        const SizedBox(width: 4),
        _RangeChip(
          label: 'Alle',
          selected: selectedDays == 0,
          onTap: () => onChanged(0),
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: AppTheme.monoStyleSmall.copyWith(
              color: selected ? AppColors.accent : AppColors.textMuted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WPM line chart
// ---------------------------------------------------------------------------

class _WpmChart extends StatelessWidget {
  final List<DailyStats> dailyStats;
  const _WpmChart({required this.dailyStats});

  @override
  Widget build(BuildContext context) {
    return _ChartContainer(
      title: 'WPM',
      isEmpty: dailyStats.isEmpty,
      child: _buildChart(),
    );
  }

  Widget _buildChart() {
    final spots = dailyStats
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgWpm))
        .toList();

    final maxY = spots.isEmpty
        ? 100.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2)
            .ceilToDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 25,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.textSubtle.withValues(alpha: 0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: _buildTitles(maxY),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.round()} wpm',
                      GoogleFonts.jetBrainsMono(
                        color: AppColors.speedLine,
                        fontSize: 13,
                      ),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.speedLine,
            barWidth: 2.5,
            dotData: FlDotData(
              show: spots.length <= 14,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.speedLine,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.speedLine.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _buildTitles(double maxY) {
    final dateFormat = DateFormat('d/M');
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: dailyStats.length > 10
              ? (dailyStats.length / 6).ceilToDouble()
              : 1,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= dailyStats.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                dateFormat.format(dailyStats[idx].date),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: maxY > 0 ? (maxY / 4).ceilToDouble() : 25,
          getTitlesWidget: (value, meta) {
            return Text(
              '${value.toInt()}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
    );
  }
}

// ---------------------------------------------------------------------------
// Accuracy line chart
// ---------------------------------------------------------------------------

class _AccuracyChart extends StatelessWidget {
  final List<DailyStats> dailyStats;
  const _AccuracyChart({required this.dailyStats});

  @override
  Widget build(BuildContext context) {
    return _ChartContainer(
      title: 'Nøyaktighet',
      isEmpty: dailyStats.isEmpty,
      child: _buildChart(),
    );
  }

  Widget _buildChart() {
    final spots = dailyStats
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgAccuracy))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.textSubtle.withValues(alpha: 0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: _buildTitles(),
        borderData: FlBorderData(show: false),
        minY: spots.isEmpty
            ? 80
            : (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5)
                .clamp(0, 100)
                .floorToDouble(),
        maxY: 100,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceLight,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)}%',
                      GoogleFonts.jetBrainsMono(
                        color: AppColors.accuracyLine,
                        fontSize: 13,
                      ),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.accuracyLine,
            barWidth: 2.5,
            dotData: FlDotData(
              show: spots.length <= 14,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.accuracyLine,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accuracyLine.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _buildTitles() {
    final dateFormat = DateFormat('d/M');
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: dailyStats.length > 10
              ? (dailyStats.length / 6).ceilToDouble()
              : 1,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= dailyStats.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                dateFormat.format(dailyStats[idx].date),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 5,
          getTitlesWidget: (value, meta) {
            return Text(
              '${value.toInt()}%',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false)),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared chart container
// ---------------------------------------------------------------------------

class _ChartContainer extends StatelessWidget {
  final String title;
  final bool isEmpty;
  final Widget child;

  const _ChartContainer({
    required this.title,
    required this.isEmpty,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: AppTheme.monoStyleSmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: isEmpty
                ? Center(
                    child: Text(
                      'Ingen data ennå',
                      style: AppTheme.monoStyleSmall.copyWith(
                        color: AppColors.textSubtle,
                        fontSize: 13,
                      ),
                    ),
                  )
                : child,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keyboard heatmap
// ---------------------------------------------------------------------------

const _keyboardRows = [
  ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', 'å'],
  ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'ø', 'æ'],
  ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
];

class _KeyboardHeatmap extends StatelessWidget {
  final Map<String, KeyStats> keyStats;
  const _KeyboardHeatmap({required this.keyStats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var rowIdx = 0; rowIdx < _keyboardRows.length; rowIdx++) ...[
            if (rowIdx > 0) const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Offset for home row and bottom row
                if (rowIdx == 1) const SizedBox(width: 16),
                if (rowIdx == 2) const SizedBox(width: 40),
                for (final key in _keyboardRows[rowIdx]) ...[
                  _KeyboardKey(
                    label: key,
                    stats: keyStats[key],
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  final String label;
  final KeyStats? stats;

  const _KeyboardKey({required this.label, this.stats});

  @override
  Widget build(BuildContext context) {
    final accuracy = stats?.accuracy ?? -1;
    final color = _getKeyColor(accuracy);
    final hasData = stats != null && stats!.total > 0;

    return Tooltip(
      message: hasData
          ? '$label: ${(accuracy * 100).round()}% (${stats!.total} trykk)'
          : '$label: ingen data',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: hasData
                ? AppColors.background.withValues(alpha: 0.9)
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Color _getKeyColor(double accuracy) {
    if (accuracy < 0) return AppColors.surfaceLight; // no data
    const green = Color(0xFF4ec9b0);
    const yellow = Color(0xFFe2b714);
    const red = Color(0xFFca4754);

    if (accuracy >= 0.95) return green;
    if (accuracy >= 0.80) {
      final t = (accuracy - 0.80) / 0.15;
      return Color.lerp(yellow, green, t)!;
    }
    final t = accuracy / 0.80;
    return Color.lerp(red, yellow, t)!;
  }
}

// ---------------------------------------------------------------------------
// Problem keys
// ---------------------------------------------------------------------------

class _ProblemKeys extends StatelessWidget {
  final Map<String, KeyStats> keyStats;
  const _ProblemKeys({required this.keyStats});

  @override
  Widget build(BuildContext context) {
    // Filter to keys with at least some data, sort by accuracy ascending
    final entries = keyStats.entries
        .where((e) => e.value.total >= 5) // minimum sample size
        .toList()
      ..sort((a, b) => a.value.accuracy.compareTo(b.value.accuracy));

    final worst = entries.take(5).toList();

    if (worst.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(text: 'Problemtaster'),
          const SizedBox(height: 8),
          Text(
            'Ingen data ennå',
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.textSubtle,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(text: 'Problemtaster'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: worst.map((e) {
            final pct = (e.value.accuracy * 100).round();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.incorrect.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key.toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.incorrect,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$pct%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Personal bests
// ---------------------------------------------------------------------------

class _PersonalBests extends StatelessWidget {
  final Map<TestMode, double> bests;
  const _PersonalBests({required this.bests});

  @override
  Widget build(BuildContext context) {
    if (bests.isEmpty) {
      return Text(
        'Ingen rekorder ennå',
        style: AppTheme.monoStyleSmall.copyWith(
          color: AppColors.textSubtle,
          fontSize: 13,
        ),
      );
    }

    return Row(
      children: [
        for (final mode in TestMode.values)
          if (bests.containsKey(mode))
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _modeName(mode),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${bests[mode]!.round()}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'wpm',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String _modeName(TestMode mode) {
    switch (mode) {
      case TestMode.time:
        return 'Tid';
      case TestMode.words:
        return 'Ord';
      case TestMode.sentences:
        return 'Setninger';
    }
  }
}

// ---------------------------------------------------------------------------
// Recent history
// ---------------------------------------------------------------------------

class _RecentHistory extends StatelessWidget {
  final List<TestResult> history;
  const _RecentHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Ingen tester ennå. Skriv litt først!',
            style: AppTheme.monoStyleSmall.copyWith(
              color: AppColors.textSubtle,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: history.length,
        separatorBuilder: (context, index) => Divider(
          color: AppColors.textSubtle.withValues(alpha: 0.2),
          height: 1,
        ),
        itemBuilder: (context, index) => _HistoryItem(result: history[index]),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final TestResult result;
  const _HistoryItem({required this.result});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d. MMM HH:mm', 'nb_NO');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // WPM
          SizedBox(
            width: 70,
            child: Text(
              '${result.wpm.round()}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.speedLine,
              ),
            ),
          ),
          Text(
            'wpm',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 20),

          // Accuracy
          SizedBox(
            width: 50,
            child: Text(
              '${result.accuracy.round()}%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              result.config.label,
              style: AppTheme.monoStyleSmall.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),

          const Spacer(),

          // Date
          Text(
            dateFormat.format(result.completedAt),
            style: TextStyle(
              color: AppColors.textSubtle,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
