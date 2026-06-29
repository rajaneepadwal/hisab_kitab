import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../main.dart';
import '../widgets/add_expense_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = DatabaseHelper.instance;

  Map<String, dynamic>? _user;
  Map<String, dynamic>? _today;
  List<Map<String, dynamic>> _recentTx = [];
  bool _loading = true;

  // Key to detect when list is scrolled near bottom
  final _scrollCtrl = ScrollController();
  bool _showViewAll = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollCtrl.addListener(() {
      if (!mounted) return;
      final nearEnd = _scrollCtrl.position.pixels >
          _scrollCtrl.position.maxScrollExtent - 80;
      if (nearEnd != _showViewAll) setState(() => _showViewAll = nearEnd);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final user  = await db.getUser();
    final today = await db.getOrCreateToday();
    final txs   = await db.getRecentTransactions(limit: 10);
    if (mounted) {
      setState(() {
        _user     = user;
        _today    = today;
        _recentTx = txs;
        _loading  = false;
      });
    }
  }

  double get _budgetLeft {
    if (_today == null) return 0;
    final base  = (_today!['base_budget'] as num).toDouble();
    final spent = (_today!['total_spent_daily'] as num).toDouble();
    return (base - spent).clamp(0, double.infinity);
  }

  Color _budgetColor() {
    final base  = (_today?['base_budget'] as num?)?.toDouble() ?? 200;
    final ratio = _budgetLeft / base;
    if (ratio > 0.5) return AppColors.success;
    if (ratio > 0.2) return const Color(0xFFF39C12);
    return AppColors.accent;
  }

  void _openAddExpense() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(onSaved: _loadAll, todayEntry: _today!),
    );
  }

  void _goToHistory() => MainShell.switchTab(context, 0);
  void _goToProfile() => MainShell.switchTab(context, 2);

  String _categoryEmoji(String category) {
    const map = {
      'Food': '🍕', 'Transport': '🚌', 'Grocery': '🛒',
      'Entertainment': '🎬', 'Other': '📦', 'Big Purchase': '👗', 'Income': '💰',
    };
    return map[category] ?? '📦';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final name = _user?['name'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _greeting(name),
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          letterSpacing: 0.2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _goToProfile,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withOpacity(0.4),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ─── ADD EXPENSE button ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _today != null ? _openAddExpense : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'ADD EXPENSE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Budget left ─────────────────────────────────
            Text(
              '₹${_budgetLeft.toStringAsFixed(0)}',
              style: TextStyle(
                  color: _budgetColor(),
                  fontSize: 54,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2),
            ),
            const Text(
              'left today',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 14, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              'Daily budget  ₹${(_today?['base_budget'] as num?)?.toStringAsFixed(0) ?? '-'}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),

            const SizedBox(height: 20),

            Divider(color: AppColors.divider, height: 1, thickness: 1),

            // ─── Recent transactions ─────────────────────────
            Expanded(
              child: _recentTx.isEmpty ? _emptyState() : _txList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _txList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECENT',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              GestureDetector(
                onTap: _goToHistory,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _showViewAll
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'View all →',
                    style: TextStyle(
                        color: _showViewAll ? Colors.white : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _recentTx.length,
            itemBuilder: (_, i) => _txTile(_recentTx[i]),
          ),
        ),
      ],
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final isIncome = tx['type'] == 'income';
    final isBig    = tx['category'] == 'Big Purchase';
    final amount   = (tx['amount'] as num).toDouble();
    final time     = DateTime.parse(tx['created_at']);
    final timeStr  =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    // Show day label if not today
    final todayKey = db.todayKey();
    final txDay    = tx['day_date'] as String? ?? todayKey;
    final isToday  = txDay == todayKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBig
              ? AppColors.accent.withOpacity(0.25)
              : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Text(_categoryEmoji(tx['category']),
              style: const TextStyle(fontSize: 22)),
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
                Row(
                  children: [
                    Text(tx['category'],
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                    if (!isToday) ...[
                      const Text('  ·  ',
                          style: TextStyle(color: AppColors.muted, fontSize: 11)),
                      Text(txDay,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                    ],
                  ],
                ),
                if (isBig)
                  const Text('Not counted in daily budget',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontStyle: FontStyle.italic)),
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('🌿', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text('No expenses yet',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
          SizedBox(height: 4),
          Text('Tap ADD EXPENSE to log one',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }

  String _greeting(String name) {
    final h    = DateTime.now().hour;
    final part = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return name.isNotEmpty ? '$part, $name 👋' : part;
  }
}