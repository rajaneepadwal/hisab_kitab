import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final db = DatabaseHelper.instance;
  Map<String, dynamic>? _user;
  double _goalSpent = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await db.getUser();
    final spent = await db.getTotalSpentSinceGoalStart();
    if (mounted) {
      setState(() {
        _user = user;
        _goalSpent = spent;
        _loading = false;
      });
    }
  }

  // ─── Edit name ───────────────────────────────────────────
  void _editName() {
    final ctrl = TextEditingController(text: _user?['name']);
    showDialog(
      context: context,
      builder: (_) => _inputDialog(
        title: 'Your name',
        controller: ctrl,
        keyboardType: TextInputType.name,
        onSave: () async {
          if (ctrl.text.trim().isEmpty) return;
          await db.updateUser({'name': ctrl.text.trim()});
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  // ─── Edit daily budget ───────────────────────────────────
  void _editDailyBudget() {
    final ctrl = TextEditingController(
        text: (_user?['daily_budget'] as num?)?.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => _inputDialog(
        title: 'Daily budget (₹)',
        controller: ctrl,
        keyboardType: TextInputType.number,
        hint: 'Applies from tomorrow',
        onSave: () async {
          final val = double.tryParse(ctrl.text);
          if (val == null || val <= 0) return;
          await db.updateUser({'daily_budget': val});
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }

  // ─── Add pocket money ────────────────────────────────────
  void _addPocketMoney() {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A24),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add money',
                  style: TextStyle(
                      color: Color(0xFFDDDDEE),
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _darkField(amtCtrl, 'Amount (₹)',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _darkField(noteCtrl, 'Note (optional)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(amtCtrl.text);
                    if (amount == null || amount <= 0) return;
                    final note = noteCtrl.text.trim().isEmpty
                        ? 'Income'
                        : noteCtrl.text.trim();

                    // Get or create today entry for FK
                    final today = await db.getOrCreateToday();

                    await db.insertTransaction({
                      'daily_budget_id': today['id'],
                      'type': 'income',
                      'amount': amount,
                      'category': 'Income',
                      'note': note,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    await db.addToBalance(amount);
                    Navigator.pop(context);
                    _load();
                  },
                  child: const Text('Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Reset savings ───────────────────────────────────────
  void _resetSavings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Reset savings?',
            style: TextStyle(color: Color(0xFFDDDDEE))),
        content: const Text(
            'This sets your savings back to ₹0. This cannot be undone.',
            style: TextStyle(color: Color(0xFF8A8A9A))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF5A5A6A))),
          ),
          TextButton(
            onPressed: () async {
              await db.resetSavings();
              Navigator.pop(context);
              _load();
            },
            child: const Text('Reset',
                style: TextStyle(
                    color: Color(0xFFE74C3C), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F14),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF7C6FFF))),
      );
    }

    final name = _user?['name'] ?? '';
    final balance = (_user?['current_balance'] as num?)?.toDouble() ?? 0;
    final savings = (_user?['savings'] as num?)?.toDouble() ?? 0;
    final dailyBudget = (_user?['daily_budget'] as num?)?.toDouble() ?? 200;
    final goalAmount = (_user?['goal_amount'] as num?)?.toDouble();
    final goalDays = (_user?['goal_days'] as num?)?.toInt();
    final goalStartDate = _user?['goal_start_date'] as String?;

    // How many days into goal
    int? dayInGoal;
    if (goalStartDate != null) {
      final start = DateTime.parse(goalStartDate);
      dayInGoal = DateTime.now().difference(start).inDays + 1;
      if (goalDays != null) dayInGoal = dayInGoal!.clamp(1, goalDays);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Avatar + name ──────────────────────────
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E1E2A),
                      border: Border.all(
                          color: const Color(0xFF7C6FFF), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFF7C6FFF),
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              color: Color(0xFFDDDDEE),
                              fontSize: 22,
                              fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Daily budget  ₹${dailyBudget.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFF5A5A6A), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ─── Settings cards ──────────────────────────
              _sectionLabel('SETTINGS'),
              const SizedBox(height: 10),
              _settingRow('Name', name, _editName),
              const SizedBox(height: 8),
              _settingRow(
                'Daily budget',
                '₹${dailyBudget.toStringAsFixed(0)}',
                _editDailyBudget,
                subtitle: 'Changes apply from tomorrow',
              ),

              const SizedBox(height: 28),

              // ─── Account balance ─────────────────────────
              _sectionLabel('ACCOUNT'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance',
                            style: TextStyle(
                                color: Color(0xFF8A8A9A), fontSize: 14)),
                        Text(
                          '₹${balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFFDDDDEE),
                              fontSize: 22,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addPocketMoney,
                        icon: const Icon(Icons.add,
                            color: Color(0xFF2ECC71), size: 18),
                        label: const Text('Add pocket money',
                            style: TextStyle(color: Color(0xFF2ECC71))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2ECC71)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ─── Savings ─────────────────────────────────
              _sectionLabel('SAVINGS'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF7C6FFF).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total saved since start',
                            style: TextStyle(
                                color: Color(0xFF8A8A9A), fontSize: 13)),
                        Text(
                          '₹${savings.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFF7C6FFF),
                              fontSize: 28,
                              fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _resetSavings,
                      child: const Text(
                        'Reset to ₹0',
                        style: TextStyle(
                            color: Color(0xFFE74C3C),
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFE74C3C)),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Goal progress ────────────────────────────
              if (goalAmount != null && goalDays != null) ...[
                const SizedBox(height: 28),
                _sectionLabel('30-DAY GOAL'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Day ${dayInGoal ?? 1} of $goalDays',
                            style: const TextStyle(
                                color: Color(0xFF8A8A9A), fontSize: 13),
                          ),
                          Text(
                            '₹${_goalSpent.toStringAsFixed(0)} / ₹${goalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Color(0xFFDDDDEE),
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_goalSpent / goalAmount).clamp(0, 1),
                          minHeight: 10,
                          backgroundColor: const Color(0xFF2A2A36),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _goalSpent > goalAmount
                                ? const Color(0xFFE74C3C)
                                : const Color(0xFF7C6FFF),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _goalSpent > goalAmount
                            ? 'Over budget by ₹${(_goalSpent - goalAmount).toStringAsFixed(0)}'
                            : '₹${(goalAmount - _goalSpent).toStringAsFixed(0)} remaining in goal',
                        style: TextStyle(
                          color: _goalSpent > goalAmount
                              ? const Color(0xFFE74C3C)
                              : const Color(0xFF5A5A6A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF4A4A5A),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }

  Widget _settingRow(String label, String value, VoidCallback onTap,
      {String? subtitle}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF8A8A9A), fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF4A4A5A), fontSize: 11)),
              ],
            ),
            Row(
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Color(0xFFDDDDEE),
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF4A4A5A), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkField(TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFFDDDDEE)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4A4A5A)),
        filled: true,
        fillColor: const Color(0xFF0F0F14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _inputDialog({
    required String title,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onSave,
    String? hint,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A24),
      title: Text(title,
          style: const TextStyle(color: Color(0xFFDDDDEE), fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofocus: true,
            style: const TextStyle(color: Color(0xFFDDDDEE)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF4A4A5A)),
              filled: true,
              fillColor: const Color(0xFF0F0F14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF5A5A6A)))),
        TextButton(
            onPressed: onSave,
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF7C6FFF),
                    fontWeight: FontWeight.w700))),
      ],
    );
  }
}