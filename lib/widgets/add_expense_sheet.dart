import 'package:flutter/material.dart';
import '../db/database_helper.dart';

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
  final db = DatabaseHelper.instance;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _selectedCategory = 'Food';
  bool _saving = false;

  final _categories = [
    ('Food', '🍕'),
    ('Transport', '🚌'),
    ('Grocery', '🛒'),
    ('Entertainment', '🎬'),
    ('Other', '📦'),
    ('Big Purchase', '👗'),
  ];

  bool get _isBigPurchase => _selectedCategory == 'Big Purchase';

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid amount'),
            backgroundColor: Color(0xFFE74C3C)),
      );
      return;
    }

    setState(() => _saving = true);

    final note = _noteCtrl.text.trim().isEmpty
        ? _selectedCategory  // fallback to category name
        : _noteCtrl.text.trim();

    final now = DateTime.now();

    // Insert transaction
    await db.insertTransaction({
      'daily_budget_id': widget.todayEntry['id'],
      'type': 'expense',
      'amount': amount,
      'category': _selectedCategory,
      'note': note,
      'created_at': now.toIso8601String(),
    });

    // Only deduct from daily spent if NOT a big purchase
    if (!_isBigPurchase) {
      await db.updateDailySpent(widget.todayEntry['date'], amount);
    }

    // Always deduct from account balance
    await db.subtractFromBalance(amount);

    Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A24),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A36),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'How much did you spend?',
              style: TextStyle(
                color: Color(0xFF8A8A9A),
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),

            // Amount input
            TextField(
              controller: _amountCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(
                color: Color(0xFFDDDDEE),
                fontSize: 36,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                prefixText: '₹  ',
                prefixStyle: const TextStyle(
                  color: Color(0xFF5A5A6A),
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
                hintText: '0',
                hintStyle: const TextStyle(
                    color: Color(0xFF2A2A36), fontSize: 36),
                filled: true,
                fillColor: const Color(0xFF0F0F14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Category',
              style: TextStyle(color: Color(0xFF8A8A9A), fontSize: 13),
            ),
            const SizedBox(height: 10),

            // Category chips — wrap layout
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((pair) {
                final name = pair.$1;
                final emoji = pair.$2;
                final selected = _selectedCategory == name;
                final isBig = name == 'Big Purchase';

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isBig
                          ? const Color(0xFFFF6B9D).withOpacity(0.15)
                          : const Color(0xFF7C6FFF).withOpacity(0.15))
                          : const Color(0xFF0F0F14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? (isBig
                            ? const Color(0xFFFF6B9D)
                            : const Color(0xFF7C6FFF))
                            : const Color(0xFF2A2A36),
                      ),
                    ),
                    child: Text(
                      '$emoji $name',
                      style: TextStyle(
                        color: selected
                            ? (isBig
                            ? const Color(0xFFFF6B9D)
                            : const Color(0xFF7C6FFF))
                            : const Color(0xFF6A6A7A),
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Big purchase note
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isBigPurchase
                  ? const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFFFF6B9D), size: 14),
                    SizedBox(width: 6),
                    Text(
                      "Won't count against your daily ₹200",
                      style: TextStyle(
                          color: Color(0xFFFF6B9D), fontSize: 12),
                    ),
                  ],
                ),
              )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 18),

            // Note field
            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: Color(0xFFDDDDEE), fontSize: 15),
              decoration: InputDecoration(
                hintText:
                'Note (optional) — defaults to "$_selectedCategory"',
                hintStyle:
                const TextStyle(color: Color(0xFF3A3A4A), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF0F0F14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6FFF),
                  disabledBackgroundColor:
                  const Color(0xFF7C6FFF).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text(
                  'Save Expense',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}