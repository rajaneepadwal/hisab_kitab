import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _transactions = [];
  String _selectedPeriod   = 'Month';
  String _selectedCategory = 'All';
  bool _loading = true;

  final _periods    = ['Week', 'Month', 'Year', 'All'];
  final _categories = [
    'All', 'Food', 'Transport', 'Grocery',
    'Entertainment', 'Other', 'Big Purchase', 'Income',
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
        from = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
        break;
      case 'Month':
        from = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
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

  Map<String, List<Map<String, dynamic>>> _grouped() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final tx in _transactions) {
      final dt = DateTime.parse(tx['created_at'] as String);
      final effective = dt.hour < 6 ? dt.subtract(const Duration(days: 1)) : dt;
      final key = DateFormat('yyyy-MM-dd').format(effective);
      map.putIfAbsent(key, () => []).add(tx);
    }
    return map;
  }

  String _dateLabel(String key) {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(
        now.hour < 6 ? now.subtract(const Duration(days: 1)) : now);
    final yesterdayKey = DateFormat('yyyy-MM-dd').format(
        now.hour < 6
            ? now.subtract(const Duration(days: 2))
            : now.subtract(const Duration(days: 1)));

    if (key == todayKey) return 'TODAY';
    if (key == yesterdayKey) return 'YESTERDAY';
    return DateFormat('EEE, d MMM yyyy').format(DateFormat('yyyy-MM-dd').parse(key)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final grouped    = _grouped();
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('History',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
              ),
            ),

            // ─── Period filter ────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _periods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _chip(
                  _periods[i],
                  _selectedPeriod == _periods[i],
                      () { setState(() => _selectedPeriod = _periods[i]); _load(); },
                  accent: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Category filter ──────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  return _chip(
                    '${_categoryEmojis[cat]} $cat',
                    _selectedCategory == cat,
                        () { setState(() => _selectedCategory = cat); _load(); },
                    accent: AppColors.accent,
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            Divider(color: AppColors.divider, height: 1, thickness: 1),

            // ─── List ─────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
                  : sortedKeys.isEmpty
                  ? _empty()
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: sortedKeys.length,
                itemBuilder: (_, i) =>
                    _daySection(sortedKeys[i], grouped[sortedKeys[i]]!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daySection(String key, List<Map<String, dynamic>> txs) {
    final dailyTotal = txs
        .where((t) => t['type'] == 'expense')
        .fold<double>(0, (s, t) => s + (t['amount'] as num).toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_dateLabel(key),
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              Text('-₹${dailyTotal.toStringAsFixed(0)}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        ...txs.map((tx) => _txTile(tx)),
        Divider(color: AppColors.divider, height: 1, thickness: 1),
      ],
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final isIncome = tx['type'] == 'income';
    final isBig    = tx['category'] == 'Big Purchase';
    final amount   = (tx['amount'] as num).toDouble();
    final dt       = DateTime.parse(tx['created_at']);
    final timeStr  = DateFormat('h:mm a').format(dt);

    const emojis = {
      'Food': '🍕', 'Transport': '🚌', 'Grocery': '🛒',
      'Entertainment': '🎬', 'Other': '📦', 'Big Purchase': '👗', 'Income': '💰',
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isBig ? AppColors.accent.withOpacity(0.2) : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
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
                Text(tx['note'],
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                Text(tx['category'],
                    style: const TextStyle(color: AppColors.muted, fontSize: 11)),
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
                        ? AppColors.success
                        : isBig
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              Text(timeStr,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {required Color accent}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? accent : AppColors.divider, width: 1.5),
          boxShadow: selected
              ? [BoxShadow(
              color: accent.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400),
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
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
          SizedBox(height: 4),
          Text('Try a different filter',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}