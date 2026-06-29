import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../main.dart';

class AddExpenseSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic> todayEntry;

  const AddExpenseSheet({
    super.key,
    required this.onSaved,
    required this.todayEntry,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final db         = DatabaseHelper.instance;
  final _amtCtrl   = TextEditingController();
  final _noteCtrl  = TextEditingController();

  String _category = 'Food';
  bool _saving     = false;

  final _categories = [
    'Food', 'Transport', 'Grocery',
    'Entertainment', 'Other', 'Big Purchase',
  ];

  final _emojis = {
    'Food': '🍕', 'Transport': '🚌', 'Grocery': '🛒',
    'Entertainment': '🎬', 'Other': '📦', 'Big Purchase': '👗',
  };

  Future<void> _save() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || amount <= 0) return;
    final note = _noteCtrl.text.trim().isEmpty ? _category : _noteCtrl.text.trim();

    setState(() => _saving = true);

    // Balance guard
    final ok = await db.subtractFromBalance(amount);
    if (!ok) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
      return;
    }

    final isBig = _category == 'Big Purchase';

    await db.insertTransaction({
      'daily_budget_id': widget.todayEntry['id'],
      'type': 'expense',
      'amount': amount,
      'category': _category,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Big purchases don't count against daily budget
    if (!isBig) {
      await db.updateDailySpent(
          widget.todayEntry['date'] as String, amount);
    }

    if (mounted) Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            const Text('Add Expense',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Amount
            TextField(
              controller: _amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                prefixText: '₹  ',
                prefixStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.muted, fontSize: 28),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 14),

            // Note
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(hintText: 'Note (optional)'),
            ),
            const SizedBox(height: 18),

            // Category chips
            const Text('Category',
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = cat == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      '${_emojis[cat]} $cat',
                      style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('Save expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}