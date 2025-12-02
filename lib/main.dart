import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plutus',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006064),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: Colors.white,
          onPrimary: Colors.black,
          primaryContainer: Color(0xFF1E1E1E),
          onPrimaryContainer: Colors.white,
          secondary: Color(0xFF9E9E9E),
          onSecondary: Colors.black,
          secondaryContainer: Color(0xFF2C2C2C),
          onSecondaryContainer: Colors.white,
          surface: Color(0xFF000000),
          onSurface: Colors.white,
          surfaceContainerHighest: Color(0xFF1E1E1E),
          error: Color(0xFFBDBDBD),
          onError: Colors.black,
          outline: Color(0xFF424242),
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        scaffoldBackgroundColor: const Color(0xFF000000),
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: const Color(0xFF424242),
        iconTheme: const IconThemeData(color: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: PlutusHome(toggleTheme: _toggleTheme, currentThemeMode: _themeMode),
    );
  }
}

// --- Data Models ---

class Transaction {
  final String id;
  final String title;
  final double amount;
  final String type;
  final String category;
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
  });

  String toCsv() {
    return '$id,$date,$title,$type,$category,$amount';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      type: json['type'],
      category: json['category'],
      date: DateTime.parse(json['date']),
    );
  }
}

// --- Constants ---

const List<String> incomeCategories = [
  'Scholarship',
  'Parents',
  'Part-time Job',
  'Gifts',
  'Other',
];

const List<String> expenseCategories = [
  'Tuition/Fees',
  'Rent/Housing',
  'Food/Groceries',
  'Books/Supplies',
  'Transportation',
  'Reload',
  'Social/Leisure',
  'Savings',
  'Other',
];

// --- Main Screen ---

class PlutusHome extends StatefulWidget {
  final Function(ThemeMode) toggleTheme;
  final ThemeMode currentThemeMode;

  const PlutusHome({
    super.key,
    required this.toggleTheme,
    required this.currentThemeMode,
  });

  @override
  State<PlutusHome> createState() => _PlutusHomeState();
}

class _PlutusHomeState extends State<PlutusHome> {
  int _currentIndex = 0;
  final List<Transaction> _transactions = [];
  String _apiKey = '';

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedType = 'Expense';
  String? _selectedCategory;

  final _questionController = TextEditingController();
  String _advice = '';
  bool _isLoadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = expenseCategories.first;
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load API Key
    _apiKey = prefs.getString('apiKey') ?? '';

    // Load Transactions
    final transactionsJson = prefs.getString('transactions');
    if (transactionsJson != null) {
      final List<dynamic> decoded = jsonDecode(transactionsJson);
      setState(() {
        _transactions.clear();
        _transactions.addAll(decoded.map((e) => Transaction.fromJson(e)));
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    // Save API Key
    await prefs.setString('apiKey', _apiKey);

    // Save Transactions
    final encoded = jsonEncode(_transactions.map((e) => e.toJson()).toList());
    await prefs.setString('transactions', encoded);
  }

  void _addTransaction() {
    final title = _titleController.text;
    final amountText = _amountController.text;

    if (title.isEmpty || amountText.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount')),
      );
      return;
    }

    setState(() {
      _transactions.insert(
        0,
        Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          type: _selectedType,
          category: _selectedCategory!,
          date: DateTime.now(),
        ),
      );
    });

    _saveData();
    _titleController.clear();
    _amountController.clear();
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction added successfully!')),
    );
  }

  double get _totalIncome => _transactions
      .where((t) => t.type == 'Income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalExpense => _transactions
      .where((t) => t.type == 'Expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _netBalance => _totalIncome - _totalExpense;

  Map<String, double> get _expensesByCategory {
    final Map<String, double> map = {};
    for (var t in _transactions.where((t) => t.type == 'Expense')) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  Future<void> _getFinancialAdvice() async {
    final question = _questionController.text;
    if (question.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a question')));
      return;
    }

    if (_apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Key is missing. Go to Settings.')),
      );
      return;
    }

    setState(() {
      _isLoadingAdvice = true;
      _advice = '';
    });

    try {
      final income = _totalIncome.toStringAsFixed(2);
      final expense = _totalExpense.toStringAsFixed(2);
      final balance = _netBalance.toStringAsFixed(2);
      final breakdown = _expensesByCategory.entries
          .map((e) => '${e.key}: \$${e.value.toStringAsFixed(2)}')
          .join(', ');

      final prompt = '''
Context:
Total Income: \$$income
Total Expenses: \$$expense
Net Balance: \$$balance
Expense Breakdown: $breakdown

User Question: $question
''';

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "system_instruction": {
            "parts": {
              "text":
                  "You are a supportive and knowledgeable financial advisor specialized in student budgeting. Provide constructive, actionable, and personalized advice based on the user's current financial data. Keep the response concise (under 200 words).",
            },
          },
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        setState(() {
          _advice = text;
        });
      } else {
        setState(() {
          _advice = 'Error: Failed to fetch advice. (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _advice = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoadingAdvice = false;
      });
    }
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SettingsScreen(
              currentThemeMode: widget.currentThemeMode,
              onThemeChanged: widget.toggleTheme,
              apiKey: _apiKey,
              onApiKeyChanged: (key) {
                setState(() {
                  _apiKey = key;
                });
                _saveData();
              },
              transactions: _transactions,
              onReset: () {
                setState(() {
                  _transactions.clear();
                });
                _saveData();
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      _buildDashboardTab(),
      _buildVisualizationTab(),
      _buildAdviceTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Plutus',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Analysis',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'Advisor',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2C)
                    : Theme.of(context).colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    'Net Balance',
                    style: TextStyle(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${_netBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Add Transaction',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              ['Income', 'Expense']
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                              _selectedCategory =
                                  _selectedType == 'Income'
                                      ? incomeCategories.first
                                      : expenseCategories.first;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              (_selectedType == 'Income'
                                      ? incomeCategories
                                      : expenseCategories)
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addTransaction,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Transaction'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Transactions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No transactions yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final t = _transactions[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          t.type == 'Income'
                              ? _getIncomeColor(context).withValues(alpha: 0.2)
                              : _getExpenseColor(
                                context,
                              ).withValues(alpha: 0.2),
                      child: Icon(
                        t.type == 'Income'
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color:
                            t.type == 'Income'
                                ? _getIncomeColor(context)
                                : _getExpenseColor(context),
                      ),
                    ),
                    title: Text(
                      t.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${t.category} • ${DateFormat.MMMd().format(t.date)}',
                    ),
                    trailing: Text(
                      '${t.type == 'Income' ? '+' : '-'}\$${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            t.type == 'Income'
                                ? _getIncomeColor(context)
                                : _getExpenseColor(context),
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Time period for transaction charts
  String _selectedTimePeriod = 'Daily';

  // Helper methods to get theme-aware colors
  Color _getIncomeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[300]!
        : Colors.green;
  }

  Color _getExpenseColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[600]!
        : Colors.red;
  }

  // Get daily transactions for the last 7 days
  Map<String, Map<String, double>> _getDailyTransactions() {
    final now = DateTime.now();
    final Map<String, Map<String, double>> dailyData = {};

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('MMM dd').format(date);
      dailyData[dateKey] = {'income': 0.0, 'expense': 0.0};
    }

    for (var transaction in _transactions) {
      final daysDiff = now.difference(transaction.date).inDays;
      if (daysDiff >= 0 && daysDiff < 7) {
        final dateKey = DateFormat('MMM dd').format(transaction.date);
        if (dailyData.containsKey(dateKey)) {
          if (transaction.type == 'Income') {
            dailyData[dateKey]!['income'] =
                (dailyData[dateKey]!['income'] ?? 0) + transaction.amount;
          } else {
            dailyData[dateKey]!['expense'] =
                (dailyData[dateKey]!['expense'] ?? 0) + transaction.amount;
          }
        }
      }
    }

    return dailyData;
  }

  // Get weekly transactions for the last 4 weeks
  Map<String, Map<String, double>> _getWeeklyTransactions() {
    final now = DateTime.now();
    final Map<String, Map<String, double>> weeklyData = {};

    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final weekKey = 'Week ${4 - i}';
      weeklyData[weekKey] = {'income': 0.0, 'expense': 0.0};

      for (var transaction in _transactions) {
        final transactionWeekStart = transaction.date.subtract(
          Duration(days: transaction.date.weekday - 1),
        );
        if (transactionWeekStart.year == weekStart.year &&
            transactionWeekStart.month == weekStart.month &&
            transactionWeekStart.day == weekStart.day) {
          if (transaction.type == 'Income') {
            weeklyData[weekKey]!['income'] =
                (weeklyData[weekKey]!['income'] ?? 0) + transaction.amount;
          } else {
            weeklyData[weekKey]!['expense'] =
                (weeklyData[weekKey]!['expense'] ?? 0) + transaction.amount;
          }
        }
      }
    }

    return weeklyData;
  }

  // Get monthly transactions for the last 6 months
  Map<String, Map<String, double>> _getMonthlyTransactions() {
    final now = DateTime.now();
    final Map<String, Map<String, double>> monthlyData = {};

    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('MMM').format(month);
      monthlyData[monthKey] = {'income': 0.0, 'expense': 0.0};
    }

    for (var transaction in _transactions) {
      final monthKey = DateFormat('MMM').format(transaction.date);
      final monthsDiff =
          (now.year - transaction.date.year) * 12 +
          (now.month - transaction.date.month);

      if (monthsDiff >= 0 &&
          monthsDiff < 6 &&
          monthlyData.containsKey(monthKey)) {
        if (transaction.type == 'Income') {
          monthlyData[monthKey]!['income'] =
              (monthlyData[monthKey]!['income'] ?? 0) + transaction.amount;
        } else {
          monthlyData[monthKey]!['expense'] =
              (monthlyData[monthKey]!['expense'] ?? 0) + transaction.amount;
        }
      }
    }

    return monthlyData;
  }

  // Build transaction bar chart
  Widget _buildTransactionBarChart(Map<String, Map<String, double>> data) {
    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No transaction data available'),
        ),
      );
    }

    final maxY = data.values.fold<double>(
      0,
      (max, entry) => [
        max,
        entry['income'] ?? 0,
        entry['expense'] ?? 0,
      ].reduce((a, b) => a > b ? a : b),
    );

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, right: 16.0),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY > 0 ? maxY * 1.2 : 100,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final label = rodIndex == 0 ? 'Income' : 'Expense';
                  return BarTooltipItem(
                    '$label\n\$${rod.toY.toStringAsFixed(2)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < data.keys.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data.keys.elementAt(index),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '\$${value.toInt()}',
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY > 0 ? maxY / 5 : 20,
            ),
            borderData: FlBorderData(show: false),
            barGroups:
                data.entries.toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final dataEntry = entry.value;
                  final income = dataEntry.value['income'] ?? 0;
                  final expense = dataEntry.value['expense'] ?? 0;

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: income,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[300]!
                                : Colors.green,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: expense,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[600]!
                                : Colors.red,
                        width: 12,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizationTab() {
    final expenses = _expensesByCategory;
    final totalExpense = _totalExpense;

    // Get chart data based on selected time period
    Map<String, Map<String, double>> chartData;
    switch (_selectedTimePeriod) {
      case 'Weekly':
        chartData = _getWeeklyTransactions();
        break;
      case 'Monthly':
        chartData = _getMonthlyTransactions();
        break;
      case 'Daily':
      default:
        chartData = _getDailyTransactions();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Transaction Trends',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Time period selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Daily',
                label: Text('Daily'),
                icon: Icon(Icons.today, size: 16),
              ),
              ButtonSegment(
                value: 'Weekly',
                label: Text('Weekly'),
                icon: Icon(Icons.view_week, size: 16),
              ),
              ButtonSegment(
                value: 'Monthly',
                label: Text('Monthly'),
                icon: Icon(Icons.calendar_month, size: 16),
              ),
            ],
            selected: {_selectedTimePeriod},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedTimePeriod = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTransactionBarChart(chartData),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getIncomeColor(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Income'),
                      const SizedBox(width: 24),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getExpenseColor(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Expense'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Income',
                  _totalIncome,
                  _getIncomeColor(context),
                  Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Expense',
                  _totalExpense,
                  _getExpenseColor(context),
                  Icons.arrow_upward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Expense Breakdown',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (expenses.isEmpty)
            const Center(child: Text('No expenses yet.'))
          else
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections:
                      expenses.entries.map((e) {
                        final percentage = (e.value / totalExpense) * 100;
                        return PieChartSectionData(
                          color:
                              Colors.primaries[expenses.keys.toList().indexOf(
                                    e.key,
                                  ) %
                                  Colors.primaries.length],
                          value: e.value,
                          title: '${percentage.toStringAsFixed(1)}%',
                          radius: 100,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (expenses.isNotEmpty)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children:
                  expenses.entries.map((e) {
                    final color =
                        Colors.primaries[expenses.keys.toList().indexOf(e.key) %
                            Colors.primaries.length];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${e.key} (\$${e.value.toStringAsFixed(2)})'),
                      ],
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceTab() {
    if (_apiKey.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.key_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'API Key Missing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enter your Gemini API Key in Settings\nto use the AI Advisor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _openSettings,
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'AI Financial Advisor',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask for personalized budgeting tips based on your current data.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _questionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'e.g., "How can I save more on food?"',
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoadingAdvice ? null : _getFinancialAdvice,
            icon:
                _isLoadingAdvice
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.auto_awesome),
            label: Text(_isLoadingAdvice ? 'Analyzing...' : 'Get Advice'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Advisor Response',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child:
                        _advice.isEmpty
                            ? const Center(
                              child: Text(
                                'Your financial advice will appear here.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : Markdown(
                              data: _advice,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                  height: 1.5,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Settings Screen ---

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final Function(ThemeMode) onThemeChanged;
  final String apiKey;
  final Function(String) onApiKeyChanged;
  final List<Transaction> transactions;
  final VoidCallback onReset;

  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    required this.apiKey,
    required this.onApiKeyChanged,
    required this.transactions,
    required this.onReset,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.apiKey);
  }

  Future<void> _exportCsv() async {
    final selection = await showDialog<String>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Select Time Range'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'Day'),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Today'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'Week'),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('This Week'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'Month'),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('This Month'),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'Year'),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('This Year'),
                ),
              ),
            ],
          ),
    );

    if (selection == null) return;

    final now = DateTime.now();
    List<Transaction> filtered = [];
    if (selection == 'Day') {
      filtered =
          widget.transactions
              .where(
                (t) =>
                    t.date.year == now.year &&
                    t.date.month == now.month &&
                    t.date.day == now.day,
              )
              .toList();
    } else if (selection == 'Week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      filtered =
          widget.transactions
              .where(
                (t) => t.date.isAfter(
                  startOfWeek.subtract(const Duration(seconds: 1)),
                ),
              )
              .toList();
    } else if (selection == 'Month') {
      filtered =
          widget.transactions
              .where(
                (t) => t.date.year == now.year && t.date.month == now.month,
              )
              .toList();
    } else if (selection == 'Year') {
      filtered =
          widget.transactions.where((t) => t.date.year == now.year).toList();
    }

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transactions found for this period.'),
          ),
        );
      }
      return;
    }

    final csvBuffer = StringBuffer();
    csvBuffer.writeln('ID,Date,Title,Type,Category,Amount');
    for (var t in filtered) {
      csvBuffer.writeln(t.toCsv());
    }

    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }

        Directory? directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }

        if (directory != null) {
          final dateStr = DateFormat('dd-MM-yyyy').format(now);
          final fileName = '${dateStr}_$selection.csv';
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csvBuffer.toString());

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
          }
        } else {
          throw Exception('Could not access storage directory');
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final dateStr = DateFormat('dd-MM-yyyy').format(now);
        final fileName = '${dateStr}_$selection.csv';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvBuffer.toString());
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
      }
    }
  }

  Future<void> _resetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset App?'),
            content: const Text(
              'This will backup all your transactions to a CSV file and then wipe all data. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reset App'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    // 1. Backup to CSV
    if (widget.transactions.isNotEmpty) {
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('ID,Date,Title,Type,Category,Amount');
      for (var t in widget.transactions) {
        csvBuffer.writeln(t.toCsv());
      }

      try {
        if (Platform.isAndroid) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }

          Directory? directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }

          if (directory != null) {
            final dateStr = DateFormat('dd-MM-yy').format(DateTime.now());
            final fileName = '$dateStr-reset.csv';
            final file = File('${directory.path}/$fileName');
            await file.writeAsString(csvBuffer.toString());

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Backup saved to ${file.path}')),
              );
            }
          }
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final dateStr = DateFormat('dd-MM-yy').format(DateTime.now());
          final fileName = '$dateStr-reset.csv';
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csvBuffer.toString());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backup saved to ${file.path}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating backup: $e')));
        }
        return;
      }
    }

    // 2. Wipe data
    widget.onReset();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('App reset successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: widget.currentThemeMode == ThemeMode.dark,
            onChanged: (value) {
              widget.onThemeChanged(value ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'API Configuration',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
                helperText: 'Required for AI Advisor',
              ),
              obscureText: true,
              onChanged: widget.onApiKeyChanged,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Data',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download Information'),
            subtitle: const Text('Export transactions as CSV'),
            onTap: _exportCsv,
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt, color: Colors.red),
            title: const Text('Reset App', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Backup and wipe all data'),
            onTap: _resetApp,
          ),
        ],
      ),
    );
  }
}
