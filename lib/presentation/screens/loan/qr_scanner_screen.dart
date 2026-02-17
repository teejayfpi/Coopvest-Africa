import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/widgets/common/cards.dart';
import 'guarantor_verification_screen.dart';

/// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  final String guarantorId;
  final String guarantorName;
  const QRScannerScreen({super.key, required this.guarantorId, required this.guarantorName});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _hasScanned = false;
  bool _isProcessing = false;
  String _errorMessage = '';

  void _handleBarcode(BarcodeCapture barcodes) {
    if (_hasScanned || _isProcessing) return;
    for (final barcode in barcodes.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.startsWith('COOP-')) {
        setState(() { _hasScanned = true; });
        _processScannedLoan(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _processScannedLoan(String loanId) async {
    setState(() { _isProcessing = true; _errorMessage = ''; });
    try {
      await Future.delayed(const Duration(seconds: 1));
      final parts = loanId.split('-');
      if (parts.length < 4) { setState(() { _errorMessage = 'Invalid QR code format'; _isProcessing = false; }); return; }
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => GuarantorVerificationScreen(loanId: loanId, borrowerName: 'Coopvest Member', loanAmount: 50000.0, loanType: 'Quick Loan', loanTenor: 12, guarantorId: widget.guarantorId, guarantorName: widget.guarantorName)));
      }
    } catch (e) { setState(() { _errorMessage = 'Error processing QR code: $e'; _isProcessing = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()), title: const Text('Scan Loan QR Code', style: TextStyle(color: Colors.white))),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(onDetect: _handleBarcode),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: CoopvestColors.primary, width: 3), borderRadius: BorderRadius.circular(20))),
                      const SizedBox(height: 24),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)), child: const Text('Position QR code within the frame', style: TextStyle(color: Colors.white))),
                    ],
                  ),
                ),
                if (_isProcessing) Container(color: Colors.black.withOpacity(0.8), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: CoopvestColors.primary), SizedBox(height: 16), Text('Processing QR Code...', style: TextStyle(color: Colors.white))]))),
                if (_errorMessage.isNotEmpty) Positioned(bottom: 100, left: 24, right: 24, child: AppCard(backgroundColor: CoopvestColors.error.withOpacity(0.9), child: Row(children: [const Icon(Icons.error, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.white))), IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _errorMessage = ''))]))),
              ],
            ),
          ),
          Container(
            color: Colors.black, padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                AppCard(
                  backgroundColor: CoopvestColors.primary.withOpacity(0.2),
                  child: const Column(
                    children: [
                      Row(children: [Icon(Icons.info, color: CoopvestColors.primary), SizedBox(width: 8), Expanded(child: Text('Scan a loan QR code to confirm your guarantee', style: TextStyle(color: Colors.white)))]),
                      SizedBox(height: 12),
                      Text('By scanning, you agree to be responsible for 1/3 of the loan amount if the borrower defaults.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Scanning as: ${widget.guarantorName}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
