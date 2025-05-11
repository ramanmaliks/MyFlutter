import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

class AddCategoryDialog extends StatefulWidget {
  final Function(String) onCategoryAdded;

  const AddCategoryDialog({super.key, required this.onCategoryAdded});

  @override
  AddCategoryDialogState createState() => AddCategoryDialogState();
}

class AddCategoryDialogState extends State<AddCategoryDialog> {
  final TextEditingController _categoryController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    final newCategory = _categoryController.text.trim();
    if (newCategory.isNotEmpty) {
      widget.onCategoryAdded(newCategory);
      _categoryController.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Category'),
      content: TextField(
        controller: _categoryController,
        decoration: const InputDecoration(hintText: 'Category Name'),
      ),
      actions: [
        TextButton(onPressed: _saveCategory, child: const Text('Save')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    );
  }
}

class Transaction {
  DateTime date;
  String details;
  double amount;
  String type;
  String currency;
  String? category;

  Transaction({
    required this.date,
    required this.details,
    required this.amount,
    required this.type,
    required this.currency,
    this.category,
  });
}

class CategoryManager {
  List<String> categories = [];

  Future<void> loadCategories() async {
    final file = File('categories.csv');
    if (await file.exists()) {
      final content = await file.readAsString();
      categories = content.split(',');
    }
  }

  void addCategory(String category) {
    categories.add(category);
    saveCategories();
  }

  List<String> getCategories() {
    return categories;
  }

  Future<void> saveCategories() async {
    final file = File('categories.csv');
    await file.writeAsString(categories.join(','));
  }
}

class PieChartWidget extends StatelessWidget {
  final Map<String, double> categoryTotals;

  const PieChartWidget({super.key, required this.categoryTotals});

  @override
  Widget build(BuildContext context) {
    // Define PieChartSectionData, PieChart, PieChartData, and FlBorderData here

    List<PieChartSectionData> sections = [];
    categoryTotals.forEach((category, total) {
      sections.add(
        PieChartSectionData(
          color: Color((category.hashCode * 1234567) % 0xFFFFFF).withOpacity(1.0),
          value: total,
          title: total.toStringAsFixed(2),
          radius: 50,
        ),
      );
    });

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Finance Automation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  List<Transaction> transactions = [];
  final CategoryManager _categoryManager = CategoryManager();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    await _categoryManager.loadCategories();
    await CsvHandler.loadTransactionsCategories(transactions);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _uploadCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });
      File file = File(result.files.single.path!);
      await CsvHandler.parseCsv(file, transactions);
      await _categoryManager.saveCategories();
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _getTotalDebit() {
    return transactions
        .where((t) => t.type == 'debit')
        .fold(0, (sum, t) => sum + t.amount);
  }

  double _getTotalCredit() {
    return transactions
        .where((t) => t.type == 'credit')
        .fold(0, (sum, t) => sum + t.amount);
  }

  void _addNewCategory() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddCategoryDialog(
          onCategoryAdded: (String newCategory) {
            setState(() {
              _categoryManager.addCategory(newCategory);
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> categoryTotals = {};
    for (var transaction in transactions) {
      if (transaction.category != null) {
        categoryTotals.update(transaction.category!,
            (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount);
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Finance Automation'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No data loaded yet.'),
                      ElevatedButton(
                        onPressed: _uploadCsv,
                        child: const Text('Upload Bank Statement (CSV)'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text('Expense Summary by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(
                          height: 300,
                          child: PieChartWidget(categoryTotals: categoryTotals)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Total Debit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(_getTotalDebit().toStringAsFixed(2), style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Total Credit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(_getTotalCredit().toStringAsFixed(2), style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Total Amount')),
                        ],
                        rows: categoryTotals.entries
                            .map((entry) => DataRow(cells: [
                                  DataCell(Text(entry.key)),
                                  DataCell(Text(entry.value.toStringAsFixed(2))),
                                ]))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: 'Credit'),
                                Tab(text: 'Debit'),
                              ],
                            ),
                            SizedBox(
                              height: 300,
                              child: TabBarView(
                                children: [
                                  ListView.builder(
                                    itemCount: transactions.where((t) => t.type == 'credit').length,
                                    itemBuilder: (context, index) {
                                      final transaction = transactions.where((t) => t.type == 'credit').toList()[index];
                                      return ListTile(
                                        title: Text('${transaction.date.toLocal()} - ${transaction.details}'),
                                        subtitle: DropdownButton<String>(
                                            hint: const Text('Select Category'),
                                            value: transaction.category,
                                            onChanged: (String? newValue) {
                                              if (newValue != null) {
                                                transaction.category = newValue;
                                                CsvHandler.saveTransactionsCategories(transactions);
                                                setState(() {});
                                              }
                                            },
                                            items: _categoryManager.getCategories().map<DropdownMenuItem<String>>((String category) {
                                              return DropdownMenuItem<String>(
                                                value: category,
                                                child: Text(category),
                                              );
                                            }).toList()),
                                        trailing: Text('${transaction.amount.toStringAsFixed(2)} ${transaction.currency}'),
                                      );
                                    },
                                  ),
                                  ListView.builder(
                                    itemCount: transactions.where((t) => t.type == 'debit').length,
                                    itemBuilder: (context, index) {
                                      final transaction = transactions.where((t) => t.type == 'debit').toList()[index];
                                      return ListTile(
                                        title: Text('${transaction.date.toLocal()} - ${transaction.details}'),
                                        subtitle: DropdownButton<String>(
                                          hint: const Text('Select Category'),
                                          value: transaction.category,
                                          onChanged: (String? newValue) {
                                            if (newValue != null) {
                                              transaction.category = newValue;
                                              CsvHandler.saveTransactionsCategories(transactions);
                                              setState(() {});
                                            }
                                          },
                                          items: _categoryManager.getCategories().map<DropdownMenuItem<String>>((String category) {
                                            return DropdownMenuItem<String>(
                                              value: category,
                                              child: Text(category),
                                            );
                                          }).toList(),
                                        ),
                                        trailing: Text('${transaction.amount.toStringAsFixed(2)} ${transaction.currency}'),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCategory,
        tooltip: 'Add New Category',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CsvHandler {
  static Future<void> parseCsv(File file, List<Transaction> transactions) async {
    final input = file.openRead();
    final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList();
    for (var i = 1; i < fields.length; i++) {
      var line = fields[i];
      final transaction = Transaction(
        date: DateTime.parse(line[0]),
        details: line[1],
        amount: double.parse(line[2]),
        type: line[3],
        currency: line[4],
      );
      transactions.add(transaction);
    }
  }

  static Future<void> loadTransactionsCategories(List<Transaction> transactions) async {
    // Add sample data if the transactions list is empty
    if (transactions.isEmpty) {
      transactions.addAll([
        Transaction(date: DateTime(2023, 10, 26), details: 'Grocery Store', amount: 55.20, type: 'debit', currency: 'USD', category: 'Groceries'),
        Transaction(date: DateTime(2023, 10, 25), details: 'Restaurant', amount: 30.50, type: 'debit', currency: 'USD', category: 'Dining Out'),
        Transaction(date: DateTime(2023, 10, 24), details: 'Salary Deposit', amount: 2500.00, type: 'credit', currency: 'USD', category: 'Income'),
        Transaction(date: DateTime(2023, 10, 23), details: 'Online Purchase', amount: 75.00, type: 'debit', currency: 'USD', category: 'Shopping'),
        Transaction(date: DateTime(2023, 10, 22), details: 'Transportation', amount: 15.00, type: 'debit', currency: 'USD', category: 'Transportation'),
      ]);
      // Save the sample data categories
      saveTransactionsCategories(transactions);
    }

    final file = File('transactions_categories.csv');
    if (await file.exists()) {
      final csvString = await file.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      for (var row in rows) {
        var transactionDetails = row[0];
        var transactionCategory = row[1];
        var matchingTransactions = transactions.where((t) => t.details == transactionDetails);
        for (var t in matchingTransactions) {
          t.category = transactionCategory;
        }
      }
    }
  }

  static Future<void> saveTransactionsCategories(List<Transaction> transactions) async {
    final file = File('transactions_categories.csv');
    final csvFile = file.openWrite();
    for (var transaction in transactions) {
      csvFile.write('${transaction.details},${transaction.category ?? ''}\n');
    }
    await csvFile.close();
  }
}
