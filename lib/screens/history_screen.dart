import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _transactions = [];
  String _selectedPeriod = 'Month';
  String _selectedCategory = 'All';
  bool _loading = true;

  final _periods = ['Week', 'Month', 'Year', 'All'];
  final _categories = [
    'All', 'Food', 'Transport', 'Grocery',
    'Entertainment', 'Other', 'Big Purchase', 'Income'
  ];

  final _categoryEmojis = {
    'All': '✨', 'Food': '🍕', 'Transport': '🚌', 'Grocery': '🛒',
    'Entertainment': '🎬', 'Other': '📦', 'Big Purchase': '👗', 'Income': '💰',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    String? from;

    switch (_selectedPeriod) {
      case 'Week':
        from = DateFormat('yyyy-MM-dd')
            .format(now.subtract(const Duration(days: 7)));
        break;
      case 'Month':
        from = DateFormat('yyyy-MM-dd')
            .format(DateTime(now.year, now.month, 1));
        break;
      case 'Year':
        from = DateFormat('yyyy-MM-dd').format(DateTime(now.year, 1, 1));
        break;
      case 'All':
        from = null;
        break;
    }

    final txs = await db.getTransactions(
      fromDate: from,
      category: _selectedCategory == 'All' ? null : _selectedCategory,
    );

    if (mounted) setState(() { _transactions = txs; _loading = false; });
  }

  // Group transactions by calendar date (YYYY-MM-DD)
  Map<String, List<Map<String, dynamic>>> _grouped() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final tx in _transactions) {
      final raw = tx['created_at'] as String;
      // Use actual datetime for grouping, respecting 6AM cutoff
      final dt = DateTime.parse(raw);
      final effective = dt.hour < 6 ? dt.subtract(const Duration(days: 1)) : dt;
      final key = DateFormat('yyyy-MM-dd').format(effective);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }

  String _dateLabel(String key) {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(
      now.hour < 6 ? now.subtract(const Duration(days: 1)) : now,
    );
    final yesterdayKey = DateFormat('yyyy-MM-dd').format(
      now.hour < 6
          ? now.subtract(const Duration(days: 2))
          : now.subtract(const Duration(days: 1)),
    );

    if (key == todayKey) return 'TODAY';
    if (key == yesterdayKey) return 'YESTERDAY';

    final dt = DateFormat('yyyy-MM-dd').parse(key);
    return DateFormat('EEE, d MMM yyyy').format(dt).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'History',
                  style: TextStyle(
                    color: Color(0xFFDDDDEE),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // ─── Period filter ────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _periods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _filterChip(
                  _periods[i],
                  _selectedPeriod == _periods[i],
                      () {
                    setState(() => _selectedPeriod = _periods[i]);
                    _load();
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ─── Category filter ──────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  return _filterChip(
                    '${_categoryEmojis[cat]} $cat',
                    _selectedCategory == cat,
                        () {
                      setState(() => _selectedCategory = cat);
                      _load();
                    },
                    accent: const Color(0xFFFF6B9D),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1E1E2A), height: 1),

            // ─── Transaction list ─────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF7C6FFF)))
                  : sortedKeys.isEmpty
                  ? _empty()
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: sortedKeys.length,
                itemBuilder: (_, i) {
                  final key = sortedKeys[i];
                  final txs = grouped[key]!;
                  return _daySection(key, txs);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daySection(String key, List<Map<String, dynamic>> txs) {
    // Daily total (expenses only, excluding big purchases for daily math)
    final dailyTotal = txs
        .where((t) => t['type'] == 'expense')
        .fold<double>(0, (sum, t) => sum + (t['amount'] as num).toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dateLabel(key),
                style: const TextStyle(
                  color: Color(0xFF5A5A6A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              Text(
                '-₹${dailyTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF4A4A5A),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ...txs.map((tx) => _txTile(tx)),
        const Divider(color: Color(0xFF1A1A24), height: 1),
      ],
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final isIncome = tx['type'] == 'income';
    final isBig = tx['category'] == 'Big Purchase';
    final amount = (tx['amount'] as num).toDouble();
    final dt = DateTime.parse(tx['created_at']);
    final timeStr = DateFormat('h:mm a').format(dt);

    final emojis = {
      'Food': '🍕', 'Transport': '🚌', 'Grocery': '🛒',
      'Entertainment': '🎬', 'Other': '📦', 'Big Purchase': '👗', 'Income': '💰',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(13),
        border: isBig
            ? Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.25))
            : null,
      ),
      child: Row(
        children: [
          Text(emojis[tx['category']] ?? '📦',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['note'],
                  style: const TextStyle(
                      color: Color(0xFFCCCCDD),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  tx['category'],
                  style: const TextStyle(
                      color: Color(0xFF4A4A5A), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: isIncome
                      ? const Color(0xFF2ECC71)
                      : isBig
                      ? const Color(0xFFFF6B9D)
                      : const Color(0xFFEEEEFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(timeStr,
                  style: const TextStyle(
                      color: Color(0xFF4A4A5A), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap,
      {Color accent = const Color(0xFF7C6FFF)}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent : const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : const Color(0xFF2A2A36),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6A6A7A),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🗂️', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('No transactions here',
              style: TextStyle(color: Color(0xFF4A4A5A), fontSize: 15)),
          SizedBox(height: 4),
          Text('Try a different filter',
              style: TextStyle(color: Color(0xFF3A3A4A), fontSize: 13)),
        ],
      ),
    );
  }
}