import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('budgetflow.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        daily_budget REAL NOT NULL,
        current_balance REAL NOT NULL,
        savings REAL NOT NULL DEFAULT 0,
        goal_amount REAL,
        goal_days INTEGER,
        goal_start_date TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        base_budget REAL NOT NULL,
        total_spent_daily REAL NOT NULL DEFAULT 0,
        daily_saving REAL NOT NULL DEFAULT 0,
        is_closed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        daily_budget_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (daily_budget_id) REFERENCES daily_budgets (id)
      )
    ''');
  }

  // ─── USER ───────────────────────────────────────────────

  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    await db.insert('users', user);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final db = await database;
    final result = await db.query('users', limit: 1);
    return result.isEmpty ? null : result.first;
  }

  Future<void> updateUser(Map<String, dynamic> fields) async {
    final db = await database;
    await db.update('users', fields, where: 'id = 1');
  }

  Future<void> addToBalance(double amount) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE users SET current_balance = current_balance + ? WHERE id = 1',
        [amount]);
  }

  /// Returns false if balance would go negative; true on success.
  Future<bool> subtractFromBalance(double amount) async {
    final db = await database;
    final user = await getUser();
    final current = (user?['current_balance'] as num?)?.toDouble() ?? 0;
    if (current - amount < 0) return false;
    await db.rawUpdate(
        'UPDATE users SET current_balance = current_balance - ? WHERE id = 1',
        [amount]);
    return true;
  }

  Future<void> addToSavings(double amount) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE users SET savings = savings + ? WHERE id = 1', [amount]);
  }

  Future<void> resetSavings() async {
    final db = await database;
    await db.rawUpdate('UPDATE users SET savings = 0 WHERE id = 1');
  }

  // ─── DAILY BUDGETS ──────────────────────────────────────

  String todayKey() {
    final now = DateTime.now();
    final effective = now.hour < 6 ? now.subtract(const Duration(days: 1)) : now;
    return effective.toIso8601String().substring(0, 10);
  }

  Future<Map<String, dynamic>?> getDailyBudget(String dateKey) async {
    final db = await database;
    final result = await db.query('daily_budgets', where: 'date = ?', whereArgs: [dateKey]);
    return result.isEmpty ? null : result.first;
  }

  Future<Map<String, dynamic>> getOrCreateToday() async {
    final db = await database;
    final key = todayKey();
    final existing = await getDailyBudget(key);
    if (existing != null) return existing;

    final user = await getUser();
    final baseBudget = (user?['daily_budget'] as num?)?.toDouble() ?? 200.0;

    await _closePastDays(db, key, baseBudget);

    final id = await db.insert('daily_budgets', {
      'date': key,
      'base_budget': baseBudget,
      'total_spent_daily': 0.0,
      'daily_saving': 0.0,
      'is_closed': 0,
    });

    final created = await db.query('daily_budgets', where: 'id = ?', whereArgs: [id]);
    return created.first;
  }

  Future<void> _closePastDays(Database db, String todayKey, double baseBudget) async {
    final unclosed = await db.query('daily_budgets',
        where: 'is_closed = 0 AND date < ?',
        whereArgs: [todayKey],
        orderBy: 'date ASC');

    for (final day in unclosed) {
      final spent = (day['total_spent_daily'] as num).toDouble();
      final budget = (day['base_budget'] as num).toDouble();
      final saving = (budget - spent).clamp(0.0, double.infinity);

      await db.update(
        'daily_budgets',
        {'daily_saving': saving, 'is_closed': 1},
        where: 'id = ?',
        whereArgs: [day['id']],
      );

      if (saving > 0) await addToSavings(saving);
    }
  }

  Future<void> updateDailySpent(String dateKey, double amount) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE daily_budgets SET total_spent_daily = total_spent_daily + ? WHERE date = ?',
        [amount, dateKey]);
  }

  // ─── TRANSACTIONS ────────────────────────────────────────

  Future<void> insertTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    await db.insert('transactions', tx);
  }

  Future<List<Map<String, dynamic>>> getTodayTransactions() async {
    final db = await database;
    final key = todayKey();
    final day = await getDailyBudget(key);
    if (day == null) return [];
    return await db.query('transactions',
        where: 'daily_budget_id = ?',
        whereArgs: [day['id']],
        orderBy: 'created_at DESC');
  }

  /// Recent transactions across all days, up to [limit].
  Future<List<Map<String, dynamic>>> getRecentTransactions({int limit = 10}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT t.*, d.date as day_date
      FROM transactions t
      JOIN daily_budgets d ON t.daily_budget_id = d.id
      ORDER BY t.created_at DESC
      LIMIT $limit
    ''');
  }

  Future<List<Map<String, dynamic>>> getTransactions({
    String? fromDate,
    String? toDate,
    String? category,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (fromDate != null) {
      conditions.add("DATE(t.created_at) >= ?");
      args.add(fromDate);
    }
    if (toDate != null) {
      conditions.add("DATE(t.created_at) <= ?");
      args.add(toDate);
    }
    if (category != null && category != 'All') {
      conditions.add("t.category = ?");
      args.add(category);
    }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    return await db.rawQuery('''
      SELECT t.*, d.date as day_date
      FROM transactions t
      JOIN daily_budgets d ON t.daily_budget_id = d.id
      $where
      ORDER BY t.created_at DESC
    ''', args);
  }

  // ─── GOAL ────────────────────────────────────────────────

  Future<double> getTotalSpentSinceGoalStart() async {
    final db = await database;
    final user = await getUser();
    final startDate = user?['goal_start_date'] as String?;
    if (startDate == null) return 0;

    final result = await db.rawQuery('''
      SELECT SUM(t.amount) as total
      FROM transactions t
      JOIN daily_budgets d ON t.daily_budget_id = d.id
      WHERE t.type = 'expense'
      AND d.date >= ?
    ''', [startDate]);

    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}