import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../main.dart';

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
    final user  = await db.getUser();
    final spent = await db.getTotalSpentSinceGoalStart();
    if (mounted) setState(() { _user = user; _goalSpent = spent; _loading = false; });
  }

  void _editName() {
    final ctrl = TextEditingController(text: _user?['name']);
    _showInputDialog(
      title: 'Your name',
      controller: ctrl,
      keyboardType: TextInputType.name,
      onSave: () async {
        if (ctrl.text.trim().isEmpty) return;
        await db.updateUser({'name': ctrl.text.trim()});
        Navigator.pop(context);
        _load();
      },
    );
  }

  void _editDailyBudget() {
    final ctrl = TextEditingController(
        text: (_user?['daily_budget'] as num?)?.toStringAsFixed(0));
    _showInputDialog(
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
    );
  }

  void _addPocketMoney() {
    final amtCtrl  = TextEditingController();
    final noteCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add money',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _field(amtCtrl, 'Amount (₹)', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _field(noteCtrl, 'Note (optional)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success),
                  onPressed: () async {
                    final amount = double.tryParse(amtCtrl.text);
                    if (amount == null || amount <= 0) return;
                    final note = noteCtrl.text.trim().isEmpty
                        ? 'Income'
                        : noteCtrl.text.trim();
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
                    if (mounted) Navigator.pop(context);
                    _load();
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetSavings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Reset savings?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'This sets your savings back to ₹0. This cannot be undone.',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.muted))),
          TextButton(
              onPressed: () async {
                await db.resetSavings();
                Navigator.pop(context);
                _load();
              },
              child: const Text('Reset',
                  style: TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final name         = _user?['name'] ?? '';
    final balance      = (_user?['current_balance'] as num?)?.toDouble() ?? 0;
    final savings      = (_user?['savings'] as num?)?.toDouble() ?? 0;
    final dailyBudget  = (_user?['daily_budget'] as num?)?.toDouble() ?? 200;
    final goalAmount   = (_user?['goal_amount'] as num?)?.toDouble();
    final goalDays     = (_user?['goal_days'] as num?)?.toInt();
    final goalStartDate = _user?['goal_start_date'] as String?;

    int? dayInGoal;
    if (goalStartDate != null) {
      final start = DateTime.parse(goalStartDate);
      dayInGoal = DateTime.now().difference(start).inDays + 1;
      if (goalDays != null) dayInGoal = dayInGoal!.clamp(1, goalDays);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Avatar + name ────────────────────────────
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withOpacity(0.35),
                      border: Border.all(color: AppColors.primary, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
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
                        Text(name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                        Text('Daily budget  ₹${dailyBudget.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ─── Settings ─────────────────────────────────
              _sectionLabel('SETTINGS'),
              const SizedBox(height: 10),
              _settingRow('Name', name, _editName),
              const SizedBox(height: 8),
              _settingRow('Daily budget', '₹${dailyBudget.toStringAsFixed(0)}',
                  _editDailyBudget, subtitle: 'Changes apply from tomorrow'),

              const SizedBox(height: 28),

              // ─── Account ──────────────────────────────────
              _sectionLabel('ACCOUNT'),
              const SizedBox(height: 10),
              _card(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 14)),
                        Text('₹${balance.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addPocketMoney,
                        icon: const Icon(Icons.add,
                            color: AppColors.success, size: 18),
                        label: const Text('Add pocket money',
                            style: TextStyle(color: AppColors.success)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.success),
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

              // ─── Savings ──────────────────────────────────
              _sectionLabel('SAVINGS'),
              const SizedBox(height: 10),
              _card(
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Total saved since start',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 13)),
                        ),
                        Text('₹${savings.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 26,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _resetSavings,
                      child: const Text('Reset to ₹0',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.accent)),
                    ),
                  ],
                ),
              ),

              // ─── Goal ─────────────────────────────────────
              if (goalAmount != null && goalDays != null) ...[
                const SizedBox(height: 28),
                _sectionLabel('30-DAY GOAL'),
                const SizedBox(height: 10),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Day ${dayInGoal ?? 1} of $goalDays',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 13)),
                          Flexible(
                            child: Text(
                              '₹${_goalSpent.toStringAsFixed(0)} / ₹${goalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_goalSpent / goalAmount).clamp(0, 1),
                          minHeight: 10,
                          backgroundColor: AppColors.divider,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _goalSpent > goalAmount
                                ? AppColors.accent
                                : AppColors.primary,
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
                              ? AppColors.accent
                              : AppColors.muted,
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

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2));

  Widget _settingRow(String label, String value, VoidCallback onTap,
      {String? subtitle}) {
    return GestureDetector(
      onTap: onTap,
      child: _card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 11)),
              ],
            ),
            Row(
              children: [
                Text(value,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.muted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, Border? border}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: child,
    );
  }

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: hint),
    );
  }

  void _showInputDialog({
    required String title,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onSave,
    String? hint,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 17)),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.muted))),
          TextButton(
              onPressed: onSave,
              child: const Text('Save',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}