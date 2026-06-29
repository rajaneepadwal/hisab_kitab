import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const HisabKitabApp());
}

class HisabKitabApp extends StatelessWidget {
  const HisabKitabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BudgetFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C6FFF),
          surface: Color(0xFF1A1A24),
        ),
      ),
      home: const AppEntry(),
    );
  }
}

// ─── App entry: checks first launch ──────────────────────────
class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _checking = true;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = await DatabaseHelper.instance.getUser();
    setState(() {
      _needsOnboarding = user == null;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F14),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF7C6FFF))),
      );
    }
    return _needsOnboarding ? const OnboardingScreen() : const MainShell();
  }
}

// ─── Onboarding ──────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  bool _goalEnabled = false;
  bool _saving = false;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text);
    final budget = double.tryParse(_budgetCtrl.text);

    if (name.isEmpty || balance == null || budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all required fields'),
            backgroundColor: Color(0xFFE74C3C)),
      );
      return;
    }

    double? goalAmount;
    if (_goalEnabled) {
      goalAmount = double.tryParse(_goalCtrl.text);
      if (goalAmount == null || goalAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Enter a valid goal amount'),
              backgroundColor: Color(0xFFE74C3C)),
        );
        return;
      }
    }

    setState(() => _saving = true);

    await DatabaseHelper.instance.insertUser({
      'id': 1,
      'name': name,
      'daily_budget': budget,
      'current_balance': balance,
      'savings': 0.0,
      'goal_amount': goalAmount,
      'goal_days': goalAmount != null ? 30 : null,
      'goal_start_date':
      goalAmount != null ? DateTime.now().toIso8601String().substring(0, 10) : null,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Create first daily budget entry
    await DatabaseHelper.instance.getOrCreateToday();

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Logo area
              const Text('💸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'BudgetFlow',
                style: TextStyle(
                  color: Color(0xFFDDDDEE),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Spend with intention.',
                style: TextStyle(color: Color(0xFF5A5A6A), fontSize: 15),
              ),

              const SizedBox(height: 48),

              _label('Your name'),
              const SizedBox(height: 8),
              _field(_nameCtrl, 'Rajanee', keyboardType: TextInputType.name),

              const SizedBox(height: 20),

              _label('Money in your account right now (₹)'),
              const SizedBox(height: 8),
              _field(_balanceCtrl, '0',
                  keyboardType: TextInputType.number),

              const SizedBox(height: 20),

              _label('Daily budget (₹)'),
              const SizedBox(height: 8),
              _field(_budgetCtrl, '200',
                  keyboardType: TextInputType.number),

              const SizedBox(height: 28),

              // Goal toggle
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Set a 30-day goal?',
                            style: TextStyle(
                                color: Color(0xFFDDDDEE), fontSize: 15)),
                        Text('Track total spending for a month',
                            style: TextStyle(
                                color: Color(0xFF4A4A5A), fontSize: 12)),
                      ],
                    ),
                    Switch(
                      value: _goalEnabled,
                      onChanged: (v) => setState(() => _goalEnabled = v),
                      activeColor: const Color(0xFF7C6FFF),
                    ),
                  ],
                ),
              ),

              if (_goalEnabled) ...[
                const SizedBox(height: 12),
                _label('Total goal amount (₹)'),
                const SizedBox(height: 8),
                _field(_goalCtrl, 'e.g. 6000',
                    keyboardType: TextInputType.number),
              ],

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C6FFF),
                    disabledBackgroundColor:
                    const Color(0xFF7C6FFF).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
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
                    'Continue →',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(color: Color(0xFF8A8A9A), fontSize: 13));
  }

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Color(0xFFDDDDEE), fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF3A3A4A)),
        filled: true,
        fillColor: const Color(0xFF1A1A24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}

// ─── Main shell with bottom nav ───────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 1; // 0=History, 1=Home, 2=Profile

  void switchTab(int index) => setState(() => _tab = index);

  // Allow HomeScreen to jump to history
  static _MainShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainShellState>();
  }

  @override
  Widget build(BuildContext context) {
    const screens = [
      HistoryScreen(),
      HomeScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: IndexedStack(
        index: _tab,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1E1E2A), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: const Color(0xFF0F0F14),
          selectedItemColor: const Color(0xFF7C6FFF),
          unselectedItemColor: const Color(0xFF3A3A4A),
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}