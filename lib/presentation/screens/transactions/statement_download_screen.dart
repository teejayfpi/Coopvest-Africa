import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../data/models/wallet_models.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/statement_pdf_service.dart';

/// Statement Download Screen - Allows users to download their account statements
class StatementDownloadScreen extends ConsumerStatefulWidget {
  const StatementDownloadScreen({super.key});

  @override
  ConsumerState<StatementDownloadScreen> createState() => _StatementDownloadScreenState();
}

class _StatementDownloadScreenState extends ConsumerState<StatementDownloadScreen> {
  final LoggerService _logger = LoggerService();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  final List<Map<String, dynamic>> _statementTypes = [
    {'type': 'all', 'label': 'Complete Statement', 'icon': Icons.description_outlined},
    {'type': 'contributions', 'label': 'Contributions Only', 'icon': Icons.savings_outlined},
    {'type': 'loans', 'label': 'Loans Only', 'icon': Icons.monetization_on_outlined},
    {'type': 'transactions', 'label': 'Transactions Only', 'icon': Icons.swap_horiz_outlined},
  ];

  String _selectedType = 'all';

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: CoopvestColors.primary,
              onPrimary: Colors.white,
              surface: context.scaffoldBackground,
              onSurface: context.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: CoopvestColors.primary,
              onPrimary: Colors.white,
              surface: context.scaffoldBackground,
              onSurface: context.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }

  Future<void> _loadTransactions() async {
    try {
      await ref.read(walletProvider.notifier).loadTransactions(pageSize: 100);
    } catch (e) {
      logger.e('Load transactions error: $e');
    }
  }

  List<Transaction> _prepareStatementTransactions(
    List<Transaction> transactions,
    String statementType,
    DateTime startDate,
    DateTime endDate,
  ) {
    final rangeStart = DateTime(startDate.year, startDate.month, startDate.day);
    final rangeEnd = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));
    final normalizedType = statementType.toLowerCase();

    final filtered = transactions.where((transaction) {
      final createdAt = transaction.createdAt.toLocal();
      final inDateRange = !createdAt.isBefore(rangeStart) && createdAt.isBefore(rangeEnd);
      final isCompleted = transaction.status.toLowerCase() == 'completed';
      if (!inDateRange || !isCompleted) return false;

      final type = transaction.type.toLowerCase();
      final description = (transaction.description ?? '').toLowerCase();
      switch (normalizedType) {
        case 'contributions':
          return type.contains('contribution') || description.contains('contribution');
        case 'loans':
          return type.contains('loan') || description.contains('loan');
        case 'transactions':
        case 'all':
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }

  Future<void> _generateAndDownloadStatement() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // First load real transactions from the API
      await _loadTransactions();
      
      final walletState = ref.read(walletProvider);
      final user = ref.read(currentUserProvider);
      
      // Get transactions - this should now have real data
      final transactions = walletState.transactions;

      // Include only completed transactions in the selected period and type,
      // sorted newest first for a predictable statement order.
      final filteredTransactions = _prepareStatementTransactions(
        transactions,
        _selectedType,
        _startDate!,
        _endDate!,
      );

      // Generate PDF
      final pdf = await StatementPdfService().build(
        user: user,
        transactions: filteredTransactions,
        wallet: walletState.wallet,
        startDate: _startDate!,
        endDate: _endDate!,
        statementType: _selectedType,
      );

      // Save and open the PDF
      final output = await getTemporaryDirectory();
      final fileName = 'CoopVest_Statement_${DateFormat('yyyyMMdd').format(_startDate!)}_to_${DateFormat('yyyyMMdd').format(_endDate!)}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Show success and open file
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statement downloaded: $fileName'),
            backgroundColor: CoopvestColors.success,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating statement: $e'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final transactions = walletState.transactions;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Download Statement'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: context.iconPrimary),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: context.cardBackground,
                  title: Text('Statement Help', style: TextStyle(color: context.textPrimary)),
                  content: Text(
                    'Generate and download your account statement as a PDF file.\n\n'
                    '1. Select a date range for the statement\n'
                    '2. Choose the type of transactions to include\n'
                    '3. Tap Download to generate and save the PDF\n\n'
                    'The statement will include:\n'
                    '- Your account summary\n'
                    '- All transactions within the selected period\n'
                    '- Total credits and debits\n\n'
                    'Note: PDF generation requires storage permission.',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Selection
            Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: InkWell(
                      onTap: () => _selectStartDate(context),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: CoopvestColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'From Date',
                                    style: TextStyle(fontSize: 10, color: context.textSecondary),
                                  ),
                                  Text(
                                    _startDateController.text.isEmpty ? 'Select date' : _startDateController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _startDateController.text.isEmpty ? context.textSecondary : context.textPrimary,
                                      fontWeight: _startDateController.text.isEmpty ? FontWeight.normal : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    child: InkWell(
                      onTap: () => _selectEndDate(context),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: CoopvestColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To Date',
                                    style: TextStyle(fontSize: 10, color: context.textSecondary),
                                  ),
                                  Text(
                                    _endDateController.text.isEmpty ? 'Select date' : _endDateController.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _endDateController.text.isEmpty ? context.textSecondary : context.textPrimary,
                                      fontWeight: _endDateController.text.isEmpty ? FontWeight.normal : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statement Type Selection
            Text(
              'Statement Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._statementTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: RadioListTile<String>(
                      value: type['type'] as String,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                      secondary: Icon(type['icon'] as IconData, color: CoopvestColors.primary),
                      title: Text(
                        type['label'] as String,
                        style: TextStyle(color: context.textPrimary),
                      ),
                      activeColor: CoopvestColors.primary,
                    ),
                  ),
                )).toList(),
            const SizedBox(height: 24),

            // Preview Section
            if (_startDate != null && _endDate != null) ...[
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Transactions in range:', style: TextStyle(color: context.textSecondary)),
                          Text(
                            '${transactions.where((t) => t.createdAt.isAfter(_startDate!.subtract(const Duration(days: 1))) && t.createdAt.isBefore(_endDate!.add(const Duration(days: 1)))).length}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date range:', style: TextStyle(color: context.textSecondary)),
                          Text(
                            '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Download Button
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: _isGenerating ? () async {} : _generateAndDownloadStatement,
                isLoading: _isGenerating,
                icon: const Icon(Icons.download_outlined),
                label: _isGenerating
                    ? 'Generating PDF...'
                    : 'Download Statement (PDF)',
              ),
            ),

            const SizedBox(height: 16),

            // Alternative: Share Option
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGenerating
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Use the Download button to generate a PDF statement'),
                            backgroundColor: CoopvestColors.primary,
                          ),
                        );
                      },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share Statement'),
              ),
            ),

            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CoopvestColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CoopvestColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: CoopvestColors.info, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Statements are generated as PDF files. You can open them in any PDF reader app.',
                      style: TextStyle(color: context.textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}