import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/wallet_models.dart';
import '../../../presentation/providers/wallet_provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';

/// Statement Download Screen - Allows users to download their account statements
class StatementDownloadScreen extends ConsumerStatefulWidget {
  const StatementDownloadScreen({super.key});

  @override
  ConsumerState<StatementDownloadScreen> createState() => _StatementDownloadScreenState();
}

class _StatementDownloadScreenState extends ConsumerState<StatementDownloadScreen> {
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

  String _capitalizeString(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

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
      final walletState = ref.read(walletProvider);
      final user = ref.read(currentUserProvider);
      final transactions = walletState.transactions;

      // Filter transactions by date range
      final filteredTransactions = transactions.where((txn) {
        final txnDate = txn.createdAt;
        return txnDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            txnDate.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();

      // Generate PDF
      final pdf = await _createPdf(
        user: user,
        transactions: filteredTransactions,
        wallet: walletState.wallet,
        startDate: _startDate!,
        endDate: _endDate!,
        statementType: _selectedType,
      );

      // Save and open the PDF
      final output = await getTemporaryDirectory();
      final fileName = 'CoopV_Statement_${DateFormat('yyyyMMdd').format(_startDate!)}_to_${DateFormat('yyyyMMdd').format(_endDate!)}.pdf';
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

  Future<pw.Document> _createPdf({
    required dynamic user,
    required List<Transaction> transactions,
    required Wallet? wallet,
    required DateTime startDate,
    required DateTime endDate,
    required String statementType,
  }) async {
    final pdf = pw.Document();

    // Load logo image
    final ByteData logoData = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => _buildPdfPageFooter(context),
        build: (context) => [
          // Header with Logo
          _buildPdfHeader(logoImage, user, startDate, endDate),
          pw.SizedBox(height: 20),
          // Account Summary
          _buildPdfAccountSummary(wallet),
          pw.SizedBox(height: 20),
          // Statement Type Header
          _buildPdfStatementType(statementType),
          pw.SizedBox(height: 10),
          // Transactions Table Header
          _buildPdfTableHeader(),
          pw.Divider(height: 1, color: PdfColors.grey400),
          // Transactions
          ..._buildPdfTransactions(transactions),
          // Summary Footer
          _buildPdfSummary(transactions, wallet),
        ],
      ),
    );

    return pdf;
  }

  // Footer for each page
  pw.Widget _buildPdfPageFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Coopvest Africa - Empowering Cooperative Finance',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeader(pw.MemoryImage logoImage, dynamic user, DateTime startDate, DateTime endDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Logo and Title Row
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              colors: [PdfColors.green800, PdfColors.green600],
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
            ),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                width: 60,
                height: 60,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'COOPVEST AFRICA',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.Text(
                      'Member Account Statement',
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0x33FFFFFF),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Statement Date',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                    ),
                    pw.Text(
                      DateFormat('MMM dd, yyyy').format(DateTime.now()),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        // Member Info Card
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Member Information', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(user?.name ?? 'Member', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(user?.email ?? '', style: const pw.TextStyle(fontSize: 10)),
                    if (user?.phone != null) pw.Text(user?.phone ?? '', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Container(
                width: 1,
                height: 60,
                color: PdfColors.grey300,
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Statement Period', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(DateFormat('MMMM dd, yyyy').format(startDate),
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('to', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(DateFormat('MMMM dd, yyyy').format(endDate),
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Container(
                width: 1,
                height: 60,
                color: PdfColors.grey300,
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text('Generated On', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(DateFormat('EEEE').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfAccountSummary(Wallet? wallet) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPdfStatItem('Wallet Balance', '₦${(wallet?.balance ?? 0).formatNumber()}', true),
          _buildPdfStatItem('Total Contributions', '₦${(wallet?.totalContributions ?? 0).formatNumber()}', false),
          _buildPdfStatItem('Total Withdrawals', '₦${(wallet?.availableForWithdrawal ?? 0).formatNumber()}', false),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatItem(String label, String value, bool isPrimary) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: isPrimary ? PdfColor.fromInt(CoopvestColors.primary.value) : PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfStatementType(String type) {
    String typeLabel = 'All Transactions';
    switch (type) {
      case 'contributions':
        typeLabel = 'Contributions Statement';
        break;
      case 'loans':
        typeLabel = 'Loans Statement';
        break;
      case 'transactions':
        typeLabel = 'Transaction History';
        break;
    }
    return pw.Text(
      typeLabel,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromInt(CoopvestColors.primary.value),
      ),
    );
  }

  pw.Widget _buildPdfTableHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 2, child: pw.Text('Date', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 4, child: pw.Text('Description', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Type', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(flex: 2, child: pw.Text('Amount', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  List<pw.Widget> _buildPdfTransactions(List<Transaction> transactions) {
    return transactions.map((txn) {
      final isCredit = txn.type == 'contribution' || txn.type == 'loan_disbursement' || txn.type == 'refund';
      return [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 2, child: pw.Text(DateFormat('MMM dd, yyyy').format(txn.createdAt), style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 4, child: pw.Text(txn.description ?? _capitalizeString(txn.type.replaceAll('_', ' ')), style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(flex: 2, child: pw.Text(_capitalizeString(txn.type.replaceAll('_', ' ')), style: const pw.TextStyle(fontSize: 10))),
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  '${isCredit ? '+' : '-'}₦${txn.amount.formatNumber()}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: isCredit ? PdfColors.green700 : PdfColors.red700,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        pw.Divider(height: 1, color: PdfColors.grey200),
      ];
    }).expand((widget) => widget).toList();
  }

  pw.Widget _buildPdfSummary(List<Transaction> transactions, Wallet? wallet) {
    final totalCredits = transactions
        .where((t) => t.type == 'contribution' || t.type == 'loan_disbursement' || t.type == 'refund')
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalDebits = transactions
        .where((t) => t.type != 'contribution' && t.type != 'loan_disbursement' && t.type != 'refund')
        .fold(0.0, (sum, t) => sum + t.amount);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPdfSummaryItem('Total Credits', totalCredits, true),
          _buildPdfSummaryItem('Total Debits', totalDebits, false),
          _buildPdfSummaryItem('Net Change', totalCredits - totalDebits, true),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, double amount, bool isPositive) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Text(
          '₦${amount.formatNumber()}',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: amount >= 0 ? PdfColors.green700 : PdfColors.red700,
          ),
        ),
      ],
    );
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