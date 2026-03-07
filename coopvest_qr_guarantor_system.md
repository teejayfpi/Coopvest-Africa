# Coopvest Africa - QR-Based Loan Guarantor System

**Version:** 1.0  
**Date:** December 2025  
**Purpose:** Secure, transparent, and verifiable peer-to-peer loan guarantor system

---

## Table of Contents

1. [System Overview](#system-overview)
2. [QR Code Specification](#qr-code-specification)
3. [QR Generation Process](#qr-generation-process)
4. [QR Scanning & Validation](#qr-scanning--validation)
5. [Guarantor Approval Flow](#guarantor-approval-flow)
6. [Security & Verification](#security--verification)
7. [Real-Time Progress Tracking](#real-time-progress-tracking)
8. [Data Storage & Audit Trail](#data-storage--audit-trail)
9. [Error Handling & Edge Cases](#error-handling--edge-cases)
10. [Implementation Guide](#implementation-guide)

---

## System Overview

### Core Principles

1. **Transparency:** All guarantor information visible to applicant
2. **Accountability:** Digital commitment with timestamp and device binding
3. **Security:** Encrypted QR codes with signature verification
4. **Simplicity:** One-tap approval process
5. **Auditability:** Complete audit trail for compliance

### Key Features

- **Unique QR Code per Loan:** Time-bound, cryptographically signed
- **Three-Guarantor Requirement:** Mandatory peer accountability
- **Real-Time Updates:** Applicant sees guarantor progress instantly
- **Device Binding:** Guarantor commitment tied to device
- **Blockchain-Ready:** Optional immutable record keeping
- **Offline Support:** QR scanning works without internet

---

## QR Code Specification

### QR Code Data Structure

```json
{
  "version": "1.0",
  "type": "loan_guarantor",
  "loan_id": "LOAN_20251223_001",
  "applicant_id": "MEMBER_12345",
  "applicant_name": "John Doe",
  "applicant_phone": "+234801234567",
  "loan_amount": 500000,
  "loan_currency": "NGN",
  "loan_tenure": 12,
  "interest_rate": 10.0,
  "monthly_repayment": 45000,
  "total_repayment": 540000,
  "purpose": "Business expansion",
  "created_at": "2025-12-23T14:00:00Z",
  "expires_at": "2025-12-30T14:00:00Z",
  "qr_id": "QR_20251223_001",
  "signature": "sha256_hmac_signature_here",
  "public_key_id": "key_20251223_001"
}
```

### QR Code Format

```
┌─────────────────────────────────────┐
│                                     │
│      [QR Code Image (200x200)]      │
│                                     │
│  Loan ID: LOAN_20251223_001         │
│  Amount: ₦500,000                   │
│  Tenure: 12 months                  │
│  Expires: 2025-12-30                │
│                                     │
│  [Share] [Copy Link] [Download]     │
│                                     │
└─────────────────────────────────────┘
```

### QR Code Properties

| Property | Value | Notes |
|----------|-------|-------|
| **Version** | QR Code 2005 | Standard format |
| **Error Correction** | Level H (30%) | High redundancy |
| **Size** | 200x200 pixels | Minimum for scanning |
| **Data Capacity** | ~500 bytes | Sufficient for loan data |
| **Encoding** | UTF-8 | Unicode support |
| **Expiry** | 7 days | Time-bound validity |

### QR Code Variants

1. **Standard QR:** Full loan details embedded
2. **Short QR:** Loan ID only, details fetched from server
3. **Dynamic QR:** Updates in real-time (premium feature)

---

## QR Generation Process

### Step 1: Loan Application Submission

```dart
class LoanApplicationService {
  Future<LoanApplication> submitLoanApplication({
    required double amount,
    required int tenure,
    required String purpose,
  }) async {
    // Validate loan amount
    if (amount < 50000 || amount > 5000000) {
      throw ValidationException('Loan amount out of range');
    }
    
    // Validate tenure
    if (![3, 6, 12].contains(tenure)) {
      throw ValidationException('Invalid tenure');
    }
    
    // Calculate loan details
    final interestRate = _calculateInterestRate(amount, tenure);
    final monthlyRepayment = _calculateMonthlyRepayment(
      amount,
      interestRate,
      tenure,
    );
    
    // Create loan application
    final loanApp = LoanApplication(
      id: _generateLoanId(),
      applicantId: _currentUserId,
      amount: amount,
      tenure: tenure,
      interestRate: interestRate,
      monthlyRepayment: monthlyRepayment,
      totalRepayment: monthlyRepayment * tenure,
      purpose: purpose,
      status: LoanStatus.pendingGuarantors,
      createdAt: DateTime.now(),
    );
    
    // Save to database
    await _loanRepository.saveLoanApplication(loanApp);
    
    // Generate QR code
    await _generateQRCode(loanApp);
    
    return loanApp;
  }
  
  String _generateLoanId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'LOAN_${timestamp}_$random';
  }
  
  double _calculateInterestRate(double amount, int tenure) {
    // Base rate: 10% per annum
    double baseRate = 10.0;
    
    // Adjust based on amount (larger loans get lower rates)
    if (amount >= 1000000) baseRate -= 2.0;
    else if (amount >= 500000) baseRate -= 1.0;
    
    // Adjust based on tenure (longer tenure gets higher rates)
    if (tenure == 12) baseRate += 1.0;
    
    return baseRate;
  }
  
  double _calculateMonthlyRepayment(
    double principal,
    double annualRate,
    int months,
  ) {
    final monthlyRate = annualRate / 100 / 12;
    final numerator = principal * monthlyRate * pow(1 + monthlyRate, months);
    final denominator = pow(1 + monthlyRate, months) - 1;
    return numerator / denominator;
  }
}
```

### Step 2: QR Code Generation

```dart
class QRCodeService {
  final EncryptionService _encryptionService;
  final ApiClient _apiClient;
  
  Future<QRCodeData> generateQRCode(LoanApplication loanApp) async {
    // Create QR data
    final qrData = QRCodeData(
      version: '1.0',
      type: 'loan_guarantor',
      loanId: loanApp.id,
      applicantId: loanApp.applicantId,
      applicantName: _currentUserName,
      applicantPhone: _currentUserPhone,
      loanAmount: loanApp.amount,
      loanCurrency: 'NGN',
      loanTenure: loanApp.tenure,
      interestRate: loanApp.interestRate,
      monthlyRepayment: loanApp.monthlyRepayment,
      totalRepayment: loanApp.totalRepayment,
      purpose: loanApp.purpose,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(days: 7)),
      qrId: _generateQRId(),
    );
    
    // Sign QR data
    final signature = await _signQRData(qrData);
    qrData.signature = signature;
    
    // Generate QR code image
    final qrImage = await _generateQRImage(jsonEncode(qrData.toJson()));
    
    // Save QR code record
    await _saveQRCodeRecord(qrData, qrImage);
    
    return qrData;
  }
  
  Future<String> _signQRData(QRCodeData qrData) async {
    final dataString = jsonEncode(qrData.toJson());
    final signature = await _encryptionService.sign(dataString);
    return signature;
  }
  
  Future<Uint8List> _generateQRImage(String data) async {
    final qrCode = QrCode(
      10, // Version
      QrErrorCorrectLevel.H, // Error correction level
    );
    qrCode.addData(data);
    qrCode.make();
    
    final qrImage = QrImage(qrCode);
    return qrImage.toImageAsBytes(
      size: 200,
      format: ImageFormat.png,
    );
  }
  
  Future<void> _saveQRCodeRecord(
    QRCodeData qrData,
    Uint8List qrImage,
  ) async {
    // Save to database
    await _database.insert('qr_codes', {
      'qr_id': qrData.qrId,
      'loan_id': qrData.loanId,
      'applicant_id': qrData.applicantId,
      'data': jsonEncode(qrData.toJson()),
      'image': qrImage,
      'signature': qrData.signature,
      'created_at': qrData.createdAt.toIso8601String(),
      'expires_at': qrData.expiresAt.toIso8601String(),
      'scanned_count': 0,
    });
    
    // Upload to server for backup
    await _apiClient.post(
      '/qr-codes',
      data: {
        'qr_id': qrData.qrId,
        'loan_id': qrData.loanId,
        'data': jsonEncode(qrData.toJson()),
        'signature': qrData.signature,
      },
    );
  }
  
  String _generateQRId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'QR_${timestamp}_$random';
  }
}
```

---

## QR Scanning & Validation

### Step 1: QR Code Scanning

```dart
class QRScannerService {
  final MobileScanner _scanner = MobileScanner();
  
  Future<QRCodeData?> scanQRCode() async {
    try {
      final result = await _scanner.start();
      
      // Listen for barcode detection
      result.barcodes.listen((barcode) {
        if (barcode.rawValue != null) {
          _processScannedQR(barcode.rawValue!);
        }
      });
    } catch (e) {
      throw QRScanException('Failed to scan QR code: $e');
    }
  }
  
  Future<QRCodeData> _processScannedQR(String rawValue) async {
    try {
      // Parse QR data
      final qrData = QRCodeData.fromJson(jsonDecode(rawValue));
      
      // Validate QR code
      await _validateQRCode(qrData);
      
      return qrData;
    } catch (e) {
      throw QRValidationException('Invalid QR code: $e');
    }
  }
}
```

### Step 2: QR Code Validation

```dart
class QRValidationService {
  final EncryptionService _encryptionService;
  final ApiClient _apiClient;
  
  Future<bool> validateQRCode(QRCodeData qrData) async {
    // 1. Check expiry
    if (DateTime.now().isAfter(qrData.expiresAt)) {
      throw QRExpiredException('QR code has expired');
    }
    
    // 2. Verify signature
    final isSignatureValid = await _verifySignature(qrData);
    if (!isSignatureValid) {
      throw QRSignatureException('QR code signature is invalid');
    }
    
    // 3. Verify loan exists and is valid
    final loan = await _apiClient.get('/loans/${qrData.loanId}');
    if (loan == null) {
      throw QRLoanNotFoundException('Loan not found');
    }
    
    // 4. Check loan status
    if (loan['status'] != 'pending_guarantors') {
      throw QRLoanStatusException('Loan is not accepting guarantors');
    }
    
    // 5. Verify applicant
    if (loan['applicant_id'] != qrData.applicantId) {
      throw QRApplicantMismatchException('Applicant mismatch');
    }
    
    // 6. Check guarantor eligibility
    await _checkGuarantorEligibility(qrData);
    
    return true;
  }
  
  Future<bool> _verifySignature(QRCodeData qrData) async {
    final dataString = jsonEncode(qrData.toJson());
    return await _encryptionService.verify(
      dataString,
      qrData.signature,
    );
  }
  
  Future<void> _checkGuarantorEligibility(QRCodeData qrData) async {
    final guarantorId = _currentUserId;
    
    // 1. Check if guarantor is verified member
    final guarantor = await _apiClient.get('/users/$guarantorId');
    if (guarantor['kyc_status'] != 'approved') {
      throw GuarantorNotVerifiedException('Guarantor not verified');
    }
    
    // 2. Check if guarantor has active contributions
    final wallet = await _apiClient.get('/wallets/$guarantorId');
    if (wallet['total_contributions'] == 0) {
      throw GuarantorNoContributionsException('No active contributions');
    }
    
    // 3. Check for unresolved defaults
    final defaults = await _apiClient.get(
      '/loans?guarantor_id=$guarantorId&status=defaulted',
    );
    if (defaults.isNotEmpty) {
      throw GuarantorHasDefaultsException('Unresolved defaults');
    }
    
    // 4. Check guarantor limit
    final currentCommitments = await _apiClient.get(
      '/loans?guarantor_id=$guarantorId&status=active',
    );
    final totalCommitment = currentCommitments.fold<double>(
      0,
      (sum, loan) => sum + (loan['amount'] as double),
    );
    
    const maxGuarantorLimit = 5000000.0; // ₦5M max
    if (totalCommitment + qrData.loanAmount > maxGuarantorLimit) {
      throw GuarantorLimitExceededException('Guarantor limit exceeded');
    }
    
    // 5. Check if already a guarantor for this loan
    final existingGuarantors = await _apiClient.get(
      '/loans/${qrData.loanId}/guarantors',
    );
    if (existingGuarantors.any((g) => g['guarantor_id'] == guarantorId)) {
      throw AlreadyGuarantorException('Already a guarantor for this loan');
    }
  }
}
```

---

## Guarantor Approval Flow

### Step 1: Display Guarantor Request

```dart
class GuarantorRequestScreen extends ConsumerWidget {
  final QRCodeData qrData;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guarantor Request')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Applicant Information
            _buildApplicantCard(qrData),
            
            // Loan Details
            _buildLoanDetailsCard(qrData),
            
            // Guarantor Responsibility Notice
            _buildResponsibilityNotice(),
            
            // Current Commitments
            _buildCurrentCommitments(ref),
            
            // Action Buttons
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }
  
  Widget _buildApplicantCard(QRCodeData qrData) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              child: Text(qrData.applicantName[0]),
            ),
            const SizedBox(height: 12),
            Text(
              qrData.applicantName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              qrData.applicantPhone,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoanDetailsCard(QRCodeData qrData) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loan Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Loan Amount',
              '₦${qrData.loanAmount.toStringAsFixed(0)}',
            ),
            _buildDetailRow(
              'Tenure',
              '${qrData.loanTenure} months',
            ),
            _buildDetailRow(
              'Interest Rate',
              '${qrData.interestRate}% per annum',
            ),
            _buildDetailRow(
              'Monthly Repayment',
              '₦${qrData.monthlyRepayment.toStringAsFixed(0)}',
            ),
            _buildDetailRow(
              'Total Repayment',
              '₦${qrData.totalRepayment.toStringAsFixed(0)}',
            ),
            _buildDetailRow(
              'Purpose',
              qrData.purpose,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResponsibilityNotice() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Guarantor Responsibility',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'By accepting this request, you agree to be a guarantor for this loan. '
            'If the applicant fails to repay, you may be held responsible for the outstanding amount. '
            'This is a serious commitment and should not be taken lightly.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrentCommitments(WidgetRef ref) {
    final commitments = ref.watch(guarantorCommitmentsProvider);
    
    return commitments.when(
      data: (data) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Current Commitments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Total Committed',
                '₦${data.totalCommitted.toStringAsFixed(0)}',
              ),
              _buildDetailRow(
                'Remaining Limit',
                '₦${data.remainingLimit.toStringAsFixed(0)}',
              ),
              _buildDetailRow(
                'Active Guarantees',
                '${data.activeGuarantees}',
              ),
            ],
          ),
        ),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
  
  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _acceptGuarantor(context, ref),
              child: const Text('Accept'),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _acceptGuarantor(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Show biometric confirmation
    final isAuthenticated = await _showBiometricConfirmation(context);
    if (!isAuthenticated) return;
    
    // Submit guarantor approval
    ref.read(guarantorApprovalProvider).approveGuarantor(qrData);
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
```

### Step 2: Biometric Confirmation

```dart
class BiometricConfirmationService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  Future<bool> authenticate() async {
    try {
      final isDeviceSupported = await _localAuth.canCheckBiometrics;
      final isDeviceSecure = await _localAuth.deviceSupportsBiometrics;
      
      if (!isDeviceSupported || !isDeviceSecure) {
        throw BiometricNotAvailableException();
      }
      
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Confirm guarantor commitment with biometric',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      
      return isAuthenticated;
    } catch (e) {
      throw BiometricException('Biometric authentication failed: $e');
    }
  }
}
```

### Step 3: Record Guarantor Commitment

```dart
class GuarantorCommitmentService {
  final Database _database;
  final ApiClient _apiClient;
  final DeviceInfoService _deviceInfo;
  
  Future<GuarantorRecord> recordGuarantorCommitment(
    QRCodeData qrData,
  ) async {
    // Get device information
    final deviceId = await _deviceInfo.getDeviceId();
    final deviceName = await _deviceInfo.getDeviceName();
    final osVersion = await _deviceInfo.getOSVersion();
    
    // Get session information
    final sessionId = _generateSessionId();
    final ipAddress = await _getIPAddress();
    
    // Create guarantor record
    final guarantorRecord = GuarantorRecord(
      id: _generateGuarantorId(),
      loanId: qrData.loanId,
      guarantorId: _currentUserId,
      status: GuarantorStatus.accepted,
      acceptedAt: DateTime.now(),
      deviceId: deviceId,
      deviceName: deviceName,
      osVersion: osVersion,
      sessionId: sessionId,
      ipAddress: ipAddress,
      latitude: await _getLatitude(),
      longitude: await _getLongitude(),
      signature: await _generateSignature(),
    );
    
    // Save to local database
    await _database.insert('guarantors', guarantorRecord.toMap());
    
    // Send to server
    await _apiClient.post(
      '/loans/${qrData.loanId}/guarantors',
      data: guarantorRecord.toJson(),
    );
    
    // Update guarantor limit
    await _updateGuarantorLimit(qrData.loanAmount);
    
    return guarantorRecord;
  }
  
  Future<void> _updateGuarantorLimit(double loanAmount) async {
    final guarantorId = _currentUserId;
    
    // Get current commitments
    final result = await _database.query(
      'guarantors',
      where: 'guarantor_id = ? AND status = ?',
      whereArgs: [guarantorId, 'accepted'],
    );
    
    double totalCommitted = 0;
    for (final row in result) {
      totalCommitted += row['loan_amount'] as double;
    }
    
    // Update in database
    await _database.update(
      'users',
      {'guarantor_limit_used': totalCommitted},
      where: 'id = ?',
      whereArgs: [guarantorId],
    );
  }
  
  String _generateGuarantorId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'GUAR_${timestamp}_$random';
  }
  
  String _generateSessionId() {
    return 'SESSION_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  Future<String> _generateSignature() async {
    final data = jsonEncode({
      'guarantor_id': _currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': await _deviceInfo.getDeviceId(),
    });
    
    return _encryptionService.sign(data);
  }
}
```

---

## Real-Time Progress Tracking

### WebSocket Connection

```dart
class LoanProgressService {
  late WebSocketChannel _channel;
  final StreamController<LoanProgress> _progressController =
      StreamController<LoanProgress>.broadcast();
  
  Future<void> subscribeToLoanProgress(String loanId) async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://api.coopvest.com/loans/$loanId/progress'),
      );
      
      _channel.stream.listen(
        (message) {
          final progress = LoanProgress.fromJson(jsonDecode(message));
          _progressController.add(progress);
        },
        onError: (error) {
          _progressController.addError(error);
        },
        onDone: () {
          _progressController.close();
        },
      );
    } catch (e) {
      _progressController.addError(e);
    }
  }
  
  Stream<LoanProgress> get progressStream => _progressController.stream;
  
  void dispose() {
    _channel.sink.close();
    _progressController.close();
  }
}
```

### Progress Display Widget

```dart
class LoanProgressWidget extends ConsumerWidget {
  final String loanId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressStream = ref.watch(loanProgressProvider(loanId));
    
    return progressStream.when(
      data: (progress) => Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(progress),
          
          // Guarantor list
          _buildGuarantorList(progress),
          
          // Status message
          _buildStatusMessage(progress),
        ],
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
  
  Widget _buildProgressIndicator(LoanProgress progress) {
    final completed = progress.guarantorsAccepted;
    final total = 3;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '$completed / $total Guarantors',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completed / total,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                completed == total ? Colors.green : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGuarantorList(LoanProgress progress) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: progress.guarantors.length,
      itemBuilder: (context, index) {
        final guarantor = progress.guarantors[index];
        return _buildGuarantorTile(guarantor);
      },
    );
  }
  
  Widget _buildGuarantorTile(GuarantorInfo guarantor) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(guarantor.name[0]),
      ),
      title: Text(guarantor.name),
      subtitle: Text(guarantor.phone),
      trailing: _buildStatusIcon(guarantor.status),
    );
  }
  
  Widget _buildStatusIcon(GuarantorStatus status) {
    switch (status) {
      case GuarantorStatus.accepted:
        return const Icon(Icons.check_circle, color: Colors.green);
      case GuarantorStatus.declined:
        return const Icon(Icons.cancel, color: Colors.red);
      case GuarantorStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange);
      case GuarantorStatus.expired:
        return const Icon(Icons.error, color: Colors.grey);
    }
  }
  
  Widget _buildStatusMessage(LoanProgress progress) {
    String message;
    
    if (progress.guarantorsAccepted == 3) {
      message = 'All guarantors confirmed! Your loan is under review.';
    } else if (progress.guarantorsAccepted == 2) {
      message = 'One more guarantor needed to proceed.';
    } else if (progress.guarantorsAccepted == 1) {
      message = 'Two more guarantors needed to proceed.';
    } else {
      message = 'Share your QR code with guarantors to get started.';
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message,
          style: const TextStyle(color: Colors.blue),
        ),
      ),
    );
  }
}
```

---

## Security & Verification

### QR Code Security Measures

1. **Cryptographic Signing**
   - HMAC-SHA256 signature
   - Server-side verification
   - Public key infrastructure

2. **Time-Based Expiry**
   - 7-day validity period
   - Automatic expiration
   - No manual revocation needed

3. **Device Binding**
   - Device ID recorded
   - Session tracking
   - IP address logging

4. **Rate Limiting**
   - Max 3 scans per QR code
   - Prevents brute force
   - Alerts on suspicious activity

5. **Audit Trail**
   - All scans logged
   - Guarantor commitments recorded
   - Immutable blockchain record (optional)

### Fraud Detection

```dart
class FraudDetectionService {
  final ApiClient _apiClient;
  
  Future<FraudRisk> assessFraudRisk(QRCodeData qrData) async {
    final riskFactors = <String, double>{};
    
    // 1. Check for duplicate QR scans
    final scanCount = await _getScanCount(qrData.qrId);
    if (scanCount > 3) {
      riskFactors['duplicate_scans'] = 0.8;
    }
    
    // 2. Check for rapid guarantor approvals
    final approvalTime = await _getApprovalTime(qrData.loanId);
    if (approvalTime < Duration(minutes: 5)) {
      riskFactors['rapid_approval'] = 0.6;
    }
    
    // 3. Check for geographic anomalies
    final locations = await _getGuarantorLocations(qrData.loanId);
    if (_isGeographicallyAnomalous(locations)) {
      riskFactors['geographic_anomaly'] = 0.7;
    }
    
    // 4. Check for device anomalies
    final devices = await _getGuarantorDevices(qrData.loanId);
    if (_isDeviceAnomalous(devices)) {
      riskFactors['device_anomaly'] = 0.6;
    }
    
    // Calculate overall risk
    final overallRisk = riskFactors.values.reduce((a, b) => a + b) /
        riskFactors.length;
    
    return FraudRisk(
      overallRisk: overallRisk,
      riskFactors: riskFactors,
      flagged: overallRisk > 0.7,
    );
  }
}
```

---

## Data Storage & Audit Trail

### Audit Log Schema

```sql
CREATE TABLE audit_logs (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  user_id TEXT,
  action TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  device_id TEXT,
  ip_address TEXT,
  timestamp TEXT NOT NULL,
  signature TEXT
);

-- Example entries:
-- QR code generated
-- QR code scanned
-- Guarantor approved
-- Guarantor declined
-- Loan status changed
-- Fraud alert triggered
```

### Blockchain Integration (Optional)

```dart
class BlockchainService {
  final Web3Client _web3Client;
  
  Future<String> recordGuarantorCommitment(
    GuarantorRecord record,
  ) async {
    // Create transaction
    final transaction = Transaction(
      to: EthereumAddress.fromHex('0x...'),
      data: _encodeGuarantorData(record),
      gasPrice: EtherAmount.inWei(BigInt.from(1000000000)),
      maxGas: 100000,
    );
    
    // Send transaction
    final txHash = await _web3Client.sendTransaction(
      _credentials,
      transaction,
    );
    
    return txHash;
  }
  
  Uint8List _encodeGuarantorData(GuarantorRecord record) {
    // Encode using Solidity ABI
    return AbiCodec.encode(
      [
        record.loanId,
        record.guarantorId,
        record.acceptedAt.millisecondsSinceEpoch,
        record.signature,
      ],
    );
  }
}
```

---

## Error Handling & Edge Cases

### Common Errors

```dart
enum QRError {
  qrExpired,
  qrInvalid,
  signatureInvalid,
  loanNotFound,
  loanStatusInvalid,
  guarantorNotVerified,
  guarantorNoContributions,
  guarantorHasDefaults,
  guarantorLimitExceeded,
  alreadyGuarantor,
  networkError,
  biometricFailed,
  deviceBindingFailed,
}

class QRErrorHandler {
  static String getErrorMessage(QRError error) {
    switch (error) {
      case QRError.qrExpired:
        return 'This QR code has expired. Please ask for a new one.';
      case QRError.qrInvalid:
        return 'This QR code is invalid. Please try again.';
      case QRError.signatureInvalid:
        return 'QR code verification failed. This may be a fraudulent code.';
      case QRError.loanNotFound:
        return 'Loan not found. Please check the QR code.';
      case QRError.loanStatusInvalid:
        return 'This loan is no longer accepting guarantors.';
      case QRError.guarantorNotVerified:
        return 'You must complete KYC verification first.';
      case QRError.guarantorNoContributions:
        return 'You must have active contributions to be a guarantor.';
      case QRError.guarantorHasDefaults:
        return 'You have unresolved loan defaults. Please resolve them first.';
      case QRError.guarantorLimitExceeded:
        return 'You have reached your maximum guarantor commitment limit.';
      case QRError.alreadyGuarantor:
        return 'You are already a guarantor for this loan.';
      case QRError.networkError:
        return 'Network error. Please check your connection and try again.';
      case QRError.biometricFailed:
        return 'Biometric authentication failed. Please try again.';
      case QRError.deviceBindingFailed:
        return 'Device binding failed. Please try again.';
    }
  }
}
```

---

## Implementation Guide

### Phase 1: Backend Setup
1. Create QR code generation service
2. Implement QR validation logic
3. Set up guarantor approval endpoints
4. Create audit logging system
5. Implement fraud detection

### Phase 2: Mobile Implementation
1. Integrate QR scanning library
2. Implement QR validation on mobile
3. Create guarantor approval UI
4. Add biometric confirmation
5. Implement real-time progress tracking

### Phase 3: Testing & Security
1. Unit tests for QR generation/validation
2. Integration tests for guarantor flow
3. Security audit and penetration testing
4. Performance testing under load
5. User acceptance testing

### Phase 4: Deployment
1. Deploy backend services
2. Release mobile app to app stores
3. Monitor for issues
4. Gather user feedback
5. Iterate and improve

---

## Conclusion

The QR-based loan guarantor system provides a secure, transparent, and user-friendly way to manage peer-to-peer loan guarantees. By combining cryptographic security, real-time tracking, and comprehensive audit trails, Coopvest can build trust and accountability within its cooperative community.

