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
  static const String lockupAsset =
      'assets/images/statement-logo-lockup-white.png';
  static const String emblemAsset = 'assets/images/statement-emblem.png';

  /// The Naira sign, U+20A6.
  ///
  /// The `pdf` package's built-in fonts encode text as Latin-1 and replace an
  /// unsupported rune with a blank placeholder rather than rejecting it, which
  /// is why an earlier revision of this service printed `NGN` instead. The
  /// document now embeds Inter, whose Naira glyph is present, so the sign is
  /// drawn and the statement matches the figures shown in the app.
  static const String currencySign = '\u20A6';

  /// Section sign, used to number the notes.
  static const String _section = '\u00A7';

  // The app's own palette, so the statement is unmistakably the same product.
  // Every colour is read from [CoopvestColors] rather than typed here, so a
  // brand change reaches the PDF without touching this file.
  static final PdfColor _emerald =
      PdfColor.fromInt(CoopvestColors.primary.toARGB32());
  static final PdfColor _gold =
      PdfColor.fromInt(CoopvestColors.accent.toARGB32());

  /// `primaryDark`, used for the header band's lower edge so the band reads as
  /// a deliberate two-tone brand surface instead of a flat block.
  static final PdfColor _emeraldDeep =
      PdfColor.fromInt(CoopvestColors.primaryDark.toARGB32());

  /// `headerLabel` and `headerNudge`: the two text tints the app already uses
  /// on an emerald header, and both are contrast-checked against it.
  static final PdfColor _headerLabel =
      PdfColor.fromInt(CoopvestColors.headerLabel.toARGB32());
  static final PdfColor _headerNudge =
      PdfColor.fromInt(CoopvestColors.headerNudge.toARGB32());

  static const PdfColor _ink = PdfColor.fromInt(0xFF101B16);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5C6B64);
  static const PdfColor _hairline = PdfColor.fromInt(0xFFE3EAE6);
  static const PdfColor _surface = PdfColor.fromInt(0xFFF5F7F6);
  static const PdfColor _credit = PdfColor.fromInt(0xFF15803D);
  static const PdfColor _debit = PdfColor.fromInt(0xFFB91C1C);
  static const PdfColor _white = PdfColors.white;

  /// Height of the full-bleed header band, reserved on every page.
  static const double _bandHeight = 96.0;

  /// Horizontal inset of the band's contents, matching the page margin so
  /// the logo lines up with the body text.
  static const double _bandInset = 36.0;

  static final NumberFormat _moneyFormat = NumberFormat('#,##0.00');

  /// Renders a figure as `₦1,234.50`, matching `Utils.formatCurrency`.
  ///
  /// Public and pure so the glyph coverage can be tested directly.
  static String money(double value) =>
      '$currencySign${_moneyFormat.format(value)}';

  /// Renders a signed figure, e.g. `+20A6500.00` for a credit.
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

    // Real Inter, so the Naira sign and any diacritics in a member's name are
    // drawn rather than blanked by the built-in Latin-1 fonts.
    final regularData =
        await rootBundle.load('assets/fonts/statement/Inter-Regular.ttf');
    final boldData =
        await rootBundle.load('assets/fonts/statement/Inter-Bold.ttf');
    final fontRegular = pw.Font.ttf(regularData);
    final fontBold = pw.Font.ttf(boldData);
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // The header band's height. It is fixed so the band can be painted
    // full-bleed in the background while the white logo lockup sits inside the
    // page margins, and so the first page's content starts below it.
    const margin = pw.EdgeInsets.fromLTRB(36, 34, 36, 40);

    final document = pw.Document(
      title: 'Coopvest Africa Member Account Statement',
      author: 'Coopvest Africa',
      creator: 'Coopvest Africa',
      subject: statementTypeLabel(statementType),
      theme: theme,
    );

    document.addPage(
      pw.MultiPage(
        // pageTheme carries everything, including the faint emblem behind the
        // text. It is the emblem alone on a transparent field, so it tints the
        // page rather than stamping a dark square over it (which is what the
        // previous opaque watermark image did). The font theme goes here rather
        // than on MultiPage, which rejects both at once.
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: margin,
          theme: theme,
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(
              children: [
                // Watermark, first so it sits behind every other element.
                pw.Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.05,
                      child: pw.Image(
                        emblem,
                        width: 380,
                        height: 380,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // Brand header band, bled to the page edges. Painted here
                // rather than as a page header so it can ignore the margins.
                pw.Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  child: pw.SizedBox(
                    height: _bandHeight,
                    child: _headerBand(lockup),
                  ),
                ),
                // Footer band, likewise full-bleed.
                pw.Positioned(
                  left: 0,
                  bottom: 0,
                  right: 0,
                  child: pw.SizedBox(
                    height: margin.bottom,
                    child: _footerBand(generatedAt),
                  ),
                ),
              ],
            ),
          ),
        ),
        // The band is painted full-bleed in the background on every page, so
        // the in-flow header only reserves its height; the body then starts
        // clear of the band and a detached sheet still carries the brand.
        header: (context) => pw.SizedBox(height: _bandHeight),
        footer: (context) => pw.SizedBox(height: 4),
        build: (context) => [
          _documentBar(startDate, endDate, generatedAt),
          pw.SizedBox(height: 16),
          _memberStrip(user),
          pw.SizedBox(height: 20),
          _sectionTitle('Statement at a glance'),
          pw.SizedBox(height: 10),
          _tileRow([
            _Tile('Opening Balance', money(opening)),
            _Tile('Total Credits', money(credits), accent: _credit),
            _Tile('Total Debits', money(debits), accent: _debit),
            _Tile('Closing Balance', money(closing), accent: _emerald),
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

  /// Full-bleed emerald header band: the brand surface the page opens with.
  ///
  /// It is painted in [PageTheme.buildBackground] rather than as a page header
  /// because only the background can ignore the page margins and bleed to the
  /// paper edge. The content inside it is inset to [_bandInset] so the logo and
  /// wordmark line up with the body text below.
  pw.Widget _headerBand(pw.MemoryImage lockupWhite) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [_emerald, _emeraldDeep],
        ),
      ),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          // Gold accent rule along the bottom edge of the band.
          pw.Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: pw.SizedBox(
              height: 4,
              child: pw.Container(color: _gold),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(
              _bandInset, 20, _bandInset, 20,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(
                  lockupWhite,
                  height: 56,
                  fit: pw.BoxFit.contain,
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'MEMBER ACCOUNT',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _headerNudge,
                        letterSpacing: 1.6,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'STATEMENT',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _headerNudge,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Full-bleed emerald footer band, mirroring the header so the page is
  /// bookended by brand surfaces.
  pw.Widget _footerBand(DateTime generatedAt) {
    return pw.Container(
      color: _emerald,
      padding: const pw.EdgeInsets.fromLTRB(_bandInset, 7, _bandInset, 7),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Coopvest Africa  \u00B7  coopvest.africa  \u00B7  support@coopvest.com',
                style: pw.TextStyle(fontSize: 7.5, color: _headerLabel),
              ),
              pw.Text(
                'Generated ${_dateTime(generatedAt)}',
                style: pw.TextStyle(fontSize: 7.5, color: _headerLabel),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Computer-generated document. No signature is required. '
            'Any query about this statement must be raised within 14 days.',
            style: pw.TextStyle(fontSize: 6.5, color: _headerLabel),
          ),
        ],
      ),
    );
  }

  /// Statement identity bar: what this document is and the period it covers.
  pw.Widget _documentBar(
    DateTime startDate,
    DateTime endDate,
    DateTime generatedAt,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _hairline, width: 1),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(width: 3, height: 24, color: _gold),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MEMBER ACCOUNT STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _emerald,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${_date(startDate)}  to  ${_date(endDate)}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
              ],
            ),
          ),
          _labelledRight('Generated', _dateTime(generatedAt)),
        ],
      ),
    );
  }

  // ── Content blocks ────────────────────────────────────────────────────────

  pw.Widget _memberStrip(User? user) {
    // Two columns rather than four: a quarter-width column clipped real email
    // addresses mid-string, and the strip is the member's own identification.
    final fields = <List<String>>[
      ['Member', user?.name ?? 'Member'],
      ['Email', user?.email ?? '-'],
      ['Phone', user?.phone ?? '-'],
      ['Status', _statusLabel(user?.membershipStatus)],
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _hairline, width: 1),
      ),
      child: pw.Column(
        children: [
          for (var i = 0; i < fields.length; i += 2) ...[
            if (i > 0) pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _detail(fields[i][0], fields[i][1]),
                _divider(),
                _detail(fields[i + 1][0], fields[i + 1][1]),
              ],
            ),
          ],
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
                      color: i == 3 ? _emerald : _ink,
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
          decoration: pw.BoxDecoration(color: _emerald),
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
              color: _emerald,
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
            '$_section 2  Balances are stated in Nigerian Naira ($currencySign). '
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
        pw.Container(width: 3, height: 12, color: _gold),
        pw.SizedBox(width: 7),
        pw.Text(
          text.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: _emerald,
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
