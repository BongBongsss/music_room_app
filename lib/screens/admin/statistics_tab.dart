import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/services/statistics_service.dart';
import 'package:music_room_app/models/payment.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsTab extends ConsumerStatefulWidget {
  const StatisticsTab({super.key});

  @override
  ConsumerState<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends ConsumerState<StatisticsTab> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final month = DateFormat('yyyy-MM').format(_selectedDate);
      final stats = await ref.read(statisticsServiceProvider).getMonthlyStats(month);
      final chartData = await ref.read(statisticsServiceProvider).getLastSixMonthsStats();
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _chartData = chartData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '통계 데이터를 불러오지 못했습니다. 다시 시도해주세요.';
          _isLoading = false;
        });
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
    });
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadStats, child: const Text('재시도')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthSelector(
            selectedDate: _selectedDate,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 24),
          if (_stats != null) ...[
            _StatsSummary(stats: _stats!),
            const SizedBox(height: 24),
            _IncomeChart(chartData: _chartData),
            const SizedBox(height: 24),
            const Text('룸별 납부 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _RoomPaymentList(payments: _stats!['payments'] as List<Payment>),
          ],
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrev, onNext;

  const _MonthSelector({required this.selectedDate, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text(
          DateFormat('yyyy년 MM월').format(selectedDate),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _StatsSummary extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow(label: '총 계약 룸', value: '${stats['paymentCount']}개'),
            const Divider(),
            _StatRow(label: '총 예상 수입', value: '${fmt.format(stats['totalExpected'])}원'),
            _StatRow(label: '실제 납부 완료', value: '${fmt.format(stats['totalPaid'])}원', valueColor: Colors.blue),
            _StatRow(label: '미납 금액', value: '${fmt.format(stats['totalUnpaid'])}원', valueColor: Colors.red),
            const Divider(),
            _StatRow(
              label: '미납률', 
              value: '${(stats['delinquencyRate'] as double).toStringAsFixed(1)}%',
              valueColor: (stats['delinquencyRate'] as double) > 0 ? Colors.orange : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}

class _IncomeChart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  const _IncomeChart({required this.chartData});

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) return const SizedBox.shrink();

    double maxAmount = 0;
    for (var data in chartData) {
      if (data['amount'] > maxAmount) maxAmount = data['amount'].toDouble();
    }
    if (maxAmount == 0) maxAmount = 1000000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('최근 6개월 수입 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxAmount * 1.2,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      int index = value.toInt();
                      if (index < 0 || index >= chartData.length) return const SizedBox.shrink();
                      String month = chartData[index]['month'].split('-')[1];
                      return Text('$month월', style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: chartData.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value['amount'].toDouble(),
                      color: Colors.blue,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    )
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomPaymentList extends StatelessWidget {
  final List<Payment> payments;
  const _RoomPaymentList({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const Text('내역 없음');

    return Column(
      children: payments.map((p) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(p.roomId),
          subtitle: Text('납부일: ${p.dueDate}'),
          trailing: Text(
            p.status == 'paid' ? '완료' : '미납',
            style: TextStyle(
              color: p.status == 'paid' ? Colors.blue : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      )).toList(),
    );
  }
}
