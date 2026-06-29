import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
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
  List<Map<String, dynamic>> _todayTx = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final user = await db.getUser();
    final today = await db.getOrCreateToday();
    final txs = await db.getTodayTransactions();
    if (mounted) {
      setState(() {
        _user = user;
        _today = today;
        _todayTx = txs;
        _loading = false;
      });
    }
  }

  double get _budgetLeft {
    if (_today == null) return 0;
    final base = (_today!['base_budget'] as num).toDouble();
    final spent = (_today!['total_spent_daily'] as num).toDouble();
    return (base - spent).clamp(0, double.infinity);
  }

  String _categoryEmoji(String category) {
    const map = {
      'Food': '🍕',
      'Transport': '🚌',
      'Grocery': '🛒',
      'Entertainment': '🎬',
      'Other': '📦',
      'Big Purchase': '👗',
      'Income': '💰',
    };
    return map[category] ?? '📦';
  }

  Color _budgetColor() {
    final base = (_today?['base_budget'] as num?)?.toDouble() ?? 200;
    final ratio = _budgetLeft / base;
    if (ratio > 0.5) return const Color(0xFF2ECC71);
    if (ratio > 0.2) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }

  void _openAddExpense() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddExpenseSheet(
        onSaved: _loadAll,
        todayEntry: _today!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C6FFF))),
      );
    }

    final name = _user?['name'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top greeting ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _greeting(name),
                    style: const TextStyle(
                      color: Color(0xFF8A8A9A),
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E2A),
                      border: Border.all(
                          color: const Color(0xFF7C6FFF), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFF7C6FFF),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ─── Big ADD EXPENSE button ──────────────────────
            GestureDetector(
              onTap: _today != null ? _openAddExpense : null,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6FFF),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C6FFF).withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Center(
                  child: Text(
                    'ADD EXPENSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ─── Budget left ─────────────────────────────────
            Text(
              '₹${_budgetLeft.toStringAsFixed(0)}',
              style: TextStyle(
                color: _budgetColor(),
                fontSize: 58,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
              ),
            ),
            const Text(
              'left today',
              style: TextStyle(
                color: Color(0xFF5A5A6A),
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 8),

            // Base budget label
            Text(
              'Daily budget  ₹${(_today?['base_budget'] as num?)?.toStringAsFixed(0) ?? '-'}',
              style: const TextStyle(
                color: Color(0xFF4A4A5A),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 32),
            const Divider(color: Color(0xFF1E1E2A), height: 1),

            // ─── Today's transactions ────────────────────────
            Expanded(
              child: _todayTx.isEmpty
                  ? _emptyState()
                  : _transactionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TODAY",
                style: TextStyle(
                  color: Color(0xFF5A5A6A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Jump to history via parent navigator — handled by MainShell
                  _jumpToHistory(context);
                },
                child: const Text(
                  "View all →",
                  style: TextStyle(
                    color: Color(0xFF7C6FFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _todayTx.length,
            itemBuilder: (_, i) => _txTile(_todayTx[i]),
          ),
        ),
      ],
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final isIncome = tx['type'] == 'income';
    final isBig = tx['category'] == 'Big Purchase';
    final amount = (tx['amount'] as num).toDouble();
    final time = DateTime.parse(tx['created_at']);
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBig
              ? const Color(0xFFFF6B9D).withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Text(_categoryEmoji(tx['category']),
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx['note'],
                  style: const TextStyle(
                    color: Color(0xFFDDDDEE),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isBig)
                  const Text(
                    'Not counted in daily budget',
                    style: TextStyle(
                        color: Color(0xFFFF6B9D),
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
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
                      : const Color(0xFFFF6B9D),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(
                    color: Color(0xFF4A4A5A), fontSize: 11),
              ),
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
          Text(
            'No expenses yet today',
            style: TextStyle(color: Color(0xFF4A4A5A), fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Tap ADD EXPENSE to log one',
            style: TextStyle(color: Color(0xFF3A3A4A), fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _greeting(String name) {
    final h = DateTime.now().hour;
    final part = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return name.isNotEmpty ? '$part, $name' : part;
  }

  void _jumpToHistory(BuildContext context) {
    // Communicate to MainShell to switch tab
    MainShellState.of(context)?.switchTab(0);
  }
}

// Shell accessor — referenced from main.dart's MainShell
class MainShellState {
  static _MainShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainShellState>();
  }
}

// Placeholder so the import compiles; actual impl is in main.dart
class _MainShellState extends State<StatefulWidget> {
  void switchTab(int index) {}
  @override
  Widget build(BuildContext context) => const SizedBox();
}