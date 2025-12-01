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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006064),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        scaffoldBackgroundColor: const Color(0xFF121212),
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
            color: Theme.of(context).colorScheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'Net Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
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
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2),
                      child: Icon(
                        t.type == 'Income'
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: t.type == 'Income' ? Colors.green : Colors.red,
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
                        color: t.type == 'Income' ? Colors.green : Colors.red,
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

  Widget _buildVisualizationTab() {
    final expenses = _expensesByCategory;
    final totalExpense = _totalExpense;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Income',
                  _totalIncome,
                  Colors.green,
                  Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Expense',
                  _totalExpense,
                  Colors.red,
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
                  color: Colors.grey[600],
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
