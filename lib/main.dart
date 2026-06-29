import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db/database_helper.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

// ─── Theme colours ────────────────────────────────────────────
class AppColors {
  static const bg         = Color(0xFFFFF5F7);
  static const card       = Color(0xFFFFFFFF);
  static const primary    = Color(0xFFF28FA3);
  static const secondary  = Color(0xFFD6C6E7);
  static const textPrimary   = Color(0xFF1A1F3D);
  static const textSecondary = Color(0xFF2C335E);
  static const accent     = Color(0xFFE63946);
  static const divider    = Color(0xFFF0E4E8);
  static const inputBg    = Color(0xFFFAEEF2);
  static const success    = Color(0xFF2ECC71);
  static const muted      = Color(0xFFB0A8B9);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
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
      theme: ThemeData(
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.card,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.inputBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: const TextStyle(color: AppColors.muted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const AppEntry(),
    );
  }
}

// ─── App entry ────────────────────────────────────────────────
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
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return _needsOnboarding ? const OnboardingScreen() : const MainShell();
  }
}

// ─── Onboarding ───────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl    = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _budgetCtrl  = TextEditingController();
  final _goalCtrl    = TextEditingController();
  bool _goalEnabled = false;
  bool _saving = false;

  Future<void> _save() async {
    final name    = _nameCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text);
    final budget  = double.tryParse(_budgetCtrl.text);

    if (name.isEmpty || balance == null || budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all required fields'),
        backgroundColor: AppColors.accent,
      ));
      return;
    }

    double? goalAmount;
    if (_goalEnabled) {
      goalAmount = double.tryParse(_goalCtrl.text);
      if (goalAmount == null || goalAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid goal amount'),
          backgroundColor: AppColors.accent,
        ));
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
      'goal_start_date': goalAmount != null
          ? DateTime.now().toIso8601String().substring(0, 10)
          : null,
      'created_at': DateTime.now().toIso8601String(),
    });

    await DatabaseHelper.instance.getOrCreateToday();

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: w * 0.07, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text('💸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('BudgetFlow',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 4),
              const Text('Spend with intention.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15)),
              const SizedBox(height: 40),
              _label('Your name'),
              const SizedBox(height: 8),
              _field(_nameCtrl, 'e.g. Rajanee', keyboardType: TextInputType.name),
              const SizedBox(height: 18),
              _label('Current account balance (₹)'),
              const SizedBox(height: 8),
              _field(_balanceCtrl, '0', keyboardType: TextInputType.number),
              const SizedBox(height: 18),
              _label('Daily budget (₹)'),
              const SizedBox(height: 8),
              _field(_budgetCtrl, '200', keyboardType: TextInputType.number),
              const SizedBox(height: 24),
              _card(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Set a 30-day spending goal?',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text('Track total spending for a month',
                              style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _goalEnabled,
                      onChanged: (v) => setState(() => _goalEnabled = v),
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              if (_goalEnabled) ...[
                const SizedBox(height: 14),
                _label('Total goal amount (₹)'),
                const SizedBox(height: 8),
                _field(_goalCtrl, 'e.g. 6000', keyboardType: TextInputType.number),
              ],
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Continue →'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600));

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3))
      ],
    ),
    child: child,
  );
}

// ─── Main shell ───────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();

  /// Call from any descendant widget to switch the bottom tab.
  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_MainShellState>()?.switchTab(index);
  }
}

class _MainShellState extends State<MainShell> {
  int _tab = 1; // 0=History, 1=Home, 2=Profile

  void switchTab(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HistoryScreen(),
      const HomeScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            backgroundColor: AppColors.card,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.muted,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.history_rounded), label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}