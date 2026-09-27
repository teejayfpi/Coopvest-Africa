import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../config/theme_config.dart';
import '../../data/models/auth_models.dart';
import '../../data/models/wallet_models.dart';

/// Builds the downloadable member account statement.
///
/// Lives outside [StatementDownloadScreen] so the document can be generated and
/// asserted on in a test without pumping a widget tree.
class StatementPdfService {
  /// Brand lockup (emblem, wordmark and strapline) and the bare emblem, both
  /// derived from the splash screen artwork so every surface shows one logo.
  static const String lockupAsset = 'assets/images/statement-logo-lockup.png';
  static const String emblemAsset = 'assets/images/statement-emblem.png';

  /// The `pdf` package's built-in fonts are Latin-1 only, and an unsupported
  /// rune is replaced by a blank placeholder rather than rejected. A Naira sign
  /// would therefore print as an empty box on exactly the figure a member cares
  /// about, so money is written as `NGN`. [money] is asserted by
  /// `test/unit/statement_pdf_service_test.dart` to stay inside Latin-1.
  static const String currencyCode = 'NGN';

  /// U+00B7 and U+00A7 are inside Latin-1 and safe with the built-in fonts.
  /// Em dashes and bullets are deliberately not used: they render blank.
  static const String _dot = '\u00B7';
  static const String _section = '\u00A7';

  // Colours sampled from the splash logo artwork, so the statement and the app
  // share one palette rather than the statement inventing its own greens.
  static const PdfColor _navy = PdfColor.fromInt(0xFF022D63);
  static const PdfColor _logoGreen = PdfColor.fromInt(0xFF56B241);

  static const PdfColor _ink = PdfColor.fromInt(0xFF101B16);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5C6B64);
  static const PdfColor _hairline = PdfColor.fromInt(0xFFE3EAE6);
  static const PdfColor _surface = PdfColor.fromInt(0xFFF5F7F6);
  static const PdfColor _credit = PdfColor.fromInt(0xFF15803D);
  static const PdfColor _debit = PdfColor.fromInt(0xFFB91C1C);
  static const PdfColor _white = PdfColors.white;

  static final PdfColor _primary =
      PdfColor.fromInt(CoopvestColors.primary.toARGB32());

  static final NumberFormat _moneyFormat = NumberFormat('#,##0.00');

  /// Renders a figure as `NGN 1,234.50`.
  ///
  /// Public and pure so the Latin-1 constraint can be tested directly.
  static String money(double value) =>
      '$currencyCode ${_moneyFormat.format(value)}';

  /// Renders a signed figure, e.g. `+NGN 500.00` for a credit.
  static String signedMoney(double value) {
    final sign = value < 0 ? '-' : '+';
    return '$sign${money(value.abs())}';
  }

  /// Human label for a stored transaction type, e.g. `loan_repayment` to
  /// `Loan Repayment`.
  static String typeLabel(String type) {
    final words = type.replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Transaction';
    return words
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Human label for the statement flavour chosen on the screen.
  static String statementTypeLabel(String type) {
    switch (type) {
      case 'contributions':
        return 'Contributions Statement';
      case 'loans':
        return 'Loans Statement';
      case 'transactions':
        return 'Transaction History';
      default:
        return 'Complete Account Statement';
    }
  }

  /// Balance the account opened the period with.
  ///
  /// Derived, because the wallet only exposes its current balance: it is today's
  /// balance walked backwards through the movements shown in the statement.
  static double openingBalance(
    Wallet? wallet,
    List<Transaction> transactions,
  ) {
    var credits = 0.0;
    var debits = 0.0;
    for (final t in transactions) {
      if (t.isCredit) {
        credits += t.amount.abs();
      } else {
        debits += t.amount.abs();
      }
    }
    return (wallet?.balance ?? 0) - credits + debits;
  }

  /// Builds the statement. [transactions] are the already-filtered rows for the
  /// period, newest first.
  Future<pw.Document> build({
    required User? user,
    required List<Transaction> transactions,
    required Wallet? wallet,
    required DateTime startDate,
    required DateTime endDate,
    required String statementType,
  }) async {
    final lockup = pw.MemoryImage(
      (await rootBundle.load(lockupAsset)).buffer.asUint8List(),
    );
    final emblem = pw.MemoryImage(
      (await rootBundle.load(emblemAsset)).buffer.asUint8List(),
    );

    final generatedAt = DateTime.now();
    final opening = openingBalance(wallet, transactions);
    final closing = wallet?.balance ?? 0;

    var credits = 0.0;
    var debits = 0.0;
    for (final t in transactions) {
      if (t.isCredit) {
        credits += t.amount.abs();
      } else {
        debits += t.amount.abs();
      }
    }

    final document = pw.Document(
      title: 'Coopvest Africa Member Account Statement',
      author: 'Coopvest Africa',
      creator: 'Coopvest Africa',
      subject: statementTypeLabel(statementType),
    );

    document.addPage(
      pw.MultiPage(
        // pageTheme carries everything, including the faint emblem behind the
        // text. It is the emblem alone on a transparent field, so it tints the
        // page rather than stamping a dark square over it (which is what the
        // previous opaque watermark image did).
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 34),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Opacity(
                opacity: 0.045,
                child: pw.Image(
                  emblem,
                  width: 380,
                  height: 380,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
        // Page one carries the full lockup in the content flow; continuation
        // pages get a compact letterhead so a detached sheet is still
        // identifiable.
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : _runningHeader(lockup, startDate, endDate),
        footer: (context) => _footer(context, generatedAt),
        build: (context) => [
          _hero(lockup, startDate, endDate, generatedAt),
          pw.SizedBox(height: 16),
          _memberStrip(user),
          pw.SizedBox(height: 20),
          _sectionTitle('Statement at a glance'),
          pw.SizedBox(height: 10),
          _tileRow([
            _Tile('Opening Balance', money(opening)),
            _Tile('Total Credits', money(credits), accent: _credit),
            _Tile('Total Debits', money(debits), accent: _debit),
            _Tile('Closing Balance', money(closing), accent: _primary),
          ]),
          pw.SizedBox(height: 20),
          _sectionTitle('Account position'),
          pw.SizedBox(height: 10),
          _accountsTable(wallet, opening, closing, credits, debits),
          pw.SizedBox(height: 22),
          _sectionTitle('${statementTypeLabel(statementType)} details'),
          pw.SizedBox(height: 10),
          _transactionsTable(transactions),
          pw.SizedBox(height: 22),
          _certification(),
        ],
      ),
    );

    return document;
  }

  // ── Page furniture ────────────────────────────────────────────────────────

  pw.Widget _hero(
    pw.MemoryImage lockup,
    DateTime startDate,
    DateTime endDate,
    DateTime generatedAt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _hairline, width: 1.2),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(lockup, width: 168, height: 132, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'MEMBER ACCOUNT STATEMENT',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    letterSpacing: 1.1,
                  ),
                ),
                pw.SizedBox(height: 8),
                _labelledRight('Statement period',
                    '${_date(startDate)}  to  ${_date(endDate)}'),
                pw.SizedBox(height: 5),
                _labelledRight('Generated', _dateTime(generatedAt)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _runningHeader(
    pw.MemoryImage lockup,
    DateTime startDate,
    DateTime endDate,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _hairline, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(lockup, width: 64, height: 50, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              'Coopvest Africa $_dot Member Account Statement',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _navy,
              ),
            ),
          ),
          pw.Text(
            '${_date(startDate)} to ${_date(endDate)}',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Context context, DateTime generatedAt) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _hairline, width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Coopvest Africa $_dot Cooperative Financial Services $_dot coopvest.africa',
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7.5, color: _muted),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Computer-generated document, issued ${_dateTime(generatedAt)}. '
            'No signature is required. Queries: support@coopvest.com',
            style: const pw.TextStyle(fontSize: 7, color: _muted),
          ),
        ],
      ),
    );
  }

  // ── Content blocks ────────────────────────────────────────────────────────

  pw.Widget _memberStrip(User? user) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _hairline, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _detail('Member', user?.name ?? 'Member'),
          _divider(),
          _detail('Email', user?.email ?? '-'),
          _divider(),
          _detail('Phone', user?.phone ?? '-'),
          _divider(),
          _detail('Status', _statusLabel(user?.membershipStatus)),
        ],
      ),
    );
  }

  pw.Widget _accountsTable(
    Wallet? wallet,
    double opening,
    double closing,
    double credits,
    double debits,
  ) {
    final rows = <List<String>>[
      ['Balance brought forward', money(opening)],
      ['Total credits in period', signedMoney(credits)],
      ['Total debits in period', signedMoney(-debits)],
      ['Balance carried forward', money(closing)],
      ['Available for withdrawal', money(wallet?.availableForWithdrawal ?? 0)],
      ['Total savings', money(wallet?.totalSavings ?? 0)],
      ['Monthly savings pledge', money(wallet?.monthlySavings ?? 0)],
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hairline, width: 1),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: pw.BoxDecoration(
                color: i == rows.length - 1 ? _surface : _white,
                border: i == rows.length - 1
                    ? null
                    : const pw.Border(
                        bottom: pw.BorderSide(color: _hairline, width: 0.6),
                      ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    rows[i][0],
                    style: const pw.TextStyle(fontSize: 9, color: _ink),
                  ),
                  pw.Text(
                    rows[i][1],
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: i == 3 ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: i == 3 ? _primary : _ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _transactionsTable(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 22, horizontal: 14),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _hairline, width: 1),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              'No completed transactions in this period',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Adjust the date range or statement type, then generate again.',
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ],
        ),
      );
    }

    const cell = pw.EdgeInsets.symmetric(vertical: 6, horizontal: 7);
    final headerStyle = pw.TextStyle(
      fontSize: 8.5,
      fontWeight: pw.FontWeight.bold,
      color: _white,
      letterSpacing: 0.4,
    );
    const bodyStyle = pw.TextStyle(fontSize: 8.5, color: _ink);

    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(66),
        1: pw.FlexColumnWidth(3),
        2: pw.FixedColumnWidth(80),
        3: pw.FixedColumnWidth(96),
      },
      border: const pw.TableBorder(
        verticalInside: pw.BorderSide(color: _hairline, width: 0.6),
        horizontalInside: pw.BorderSide(color: _hairline, width: 0.6),
        top: pw.BorderSide(color: _hairline, width: 1),
        bottom: pw.BorderSide(color: _hairline, width: 1),
        left: pw.BorderSide(color: _hairline, width: 1),
        right: pw.BorderSide(color: _hairline, width: 1),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _navy),
          children: [
            _headCell('Date', headerStyle, cell),
            _headCell('Description', headerStyle, cell),
            _headCell('Type', headerStyle, cell),
            _headCell('Amount', headerStyle, cell, alignRight: true),
          ],
        ),
        for (var i = 0; i < transactions.length; i++)
          _transactionRow(transactions[i], i, bodyStyle, cell),
      ],
    );
  }

  pw.TableRow _transactionRow(
    Transaction txn,
    int index,
    pw.TextStyle bodyStyle,
    pw.EdgeInsets cell,
  ) {
    final isCredit = txn.isCredit;
    final description = (txn.description == null || txn.description!.isEmpty)
        ? typeLabel(txn.type)
        : txn.description!;

    return pw.TableRow(
      decoration: pw.BoxDecoration(color: index.isEven ? _white : _surface),
      children: [
        _bodyCell(_date(txn.createdAt.toLocal()), bodyStyle, cell),
        _bodyCell(description, bodyStyle, cell, maxLines: 2),
        _bodyCell(typeLabel(txn.type), bodyStyle, cell, maxLines: 2),
        pw.Padding(
          padding: cell,
          child: pw.Text(
            signedMoney(isCredit ? txn.amount.abs() : -txn.amount.abs()),
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: isCredit ? _credit : _debit,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _certification() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(6),
        // A uniform border only: the pdf package rejects a borderRadius
        // combined with per-side borders ("A borderRadius can only be given for
        // a uniform Border"). The green brand accent is carried by the section
        // titles instead.
        border: pw.Border.all(color: _hairline, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Important information',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _navy,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            '$_section 1  This statement covers completed transactions only, and '
            'lists them newest first. Pending or failed movements are excluded.',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '$_section 2  Balances are stated in Nigerian Naira ($currencyCode). '
            'The opening balance is the closing balance less credits plus debits '
            'for the period shown.',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '$_section 3  Please report any discrepancy within 14 days of the '
            'generated date so it can be reconciled against the ledger.',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );
  }

  // ── Small builders ────────────────────────────────────────────────────────

  pw.Widget _sectionTitle(String text) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(width: 3, height: 12, color: _logoGreen),
        pw.SizedBox(width: 7),
        pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }

  pw.Widget _tileRow(List<_Tile> tiles) {
    return pw.Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(child: _tile(tiles[i])),
        ],
      ],
    );
  }

  pw.Widget _tile(_Tile tile) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: _hairline, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            tile.label,
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            tile.value,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: tile.accent ?? _ink,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _bodyCell(
    String text,
    pw.TextStyle style,
    pw.EdgeInsets cell, {
    int? maxLines,
  }) {
    return pw.Padding(
      padding: cell,
      child: pw.Text(text, style: style, maxLines: maxLines),
    );
  }

  pw.Widget _headCell(
    String text,
    pw.TextStyle style,
    pw.EdgeInsets cell, {
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: cell,
      child: pw.Text(
        text,
        style: style,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _detail(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _muted,
              letterSpacing: 0.6,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _divider() => pw.Container(
        width: 1,
        height: 26,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8),
        color: _hairline,
      );

  pw.Widget _labelledRight(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
            letterSpacing: 0.6,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
      ],
    );
  }

  static String _statusLabel(String? status) {
    if (status == null || status.isEmpty) return 'Active';
    return typeLabel(status);
  }

  static String _date(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  static String _dateTime(DateTime d) =>
      DateFormat('dd MMM yyyy, HH:mm').format(d);
}

class _Tile {
  final String label;
  final String value;
  final PdfColor? accent;

  const _Tile(this.label, this.value, {this.accent});
}
