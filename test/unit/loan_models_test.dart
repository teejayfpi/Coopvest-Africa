import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/data/models/loan_models.dart';

void main() {
  group('Loan Model Tests', () {
    test('should create Loan from JSON', () {
      final json = {
        'id': 'loan_123',
        'user_id': 'user_456',
        'type': 'Personal Loan',
        'amount': 500000.0,
        'tenure': 12,
        'interest_rate': 10.0,
        'monthly_repayment': 45000.0,
        'total_repayment': 540000.0,
        'status': 'pending',
        'guarantors_accepted': 0,
        'guarantors_required': 2,
        'created_at': '2024-01-15T10:30:00Z',
        'updated_at': '2024-01-15T10:30:00Z',
      };

      final loan = Loan.fromJson(json);

      expect(loan.id, 'loan_123');
      expect(loan.userId, 'user_456');
      expect(loan.amount, 500000.0);
      expect(loan.tenure, 12);
      expect(loan.interestRate, 10.0);
      expect(loan.status, 'pending');
      expect(loan.guarantorsRequired, 2);
    });

    test('should handle missing optional fields', () {
      final json = {
        'id': 'loan_minimal',
        'user_id': 'user_123',
        'created_at': '2024-02-01T08:00:00Z',
        'updated_at': '2024-02-01T08:00:00Z',
      };

      final loan = Loan.fromJson(json);

      expect(loan.purpose, isNull);
      expect(loan.approvedAt, isNull);
      expect(loan.disbursedAt, isNull);
    });

    test('should convert Loan to JSON', () {
      final loan = Loan(
        id: 'loan_test',
        userId: 'user_test',
        type: 'Emergency Loan',
        amount: 100000.0,
        tenure: 6,
        interestRate: 8.0,
        monthlyRepayment: 18000.0,
        totalRepayment: 108000.0,
        status: 'active',
        guarantorsAccepted: 2,
        guarantorsRequired: 2,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 15),
      );

      final json = loan.toJson();

      expect(json['id'], 'loan_test');
      expect(json['amount'], 100000.0);
      expect(json['status'], 'active');
    });

    test('should calculate days since creation', () {
      final loan = Loan(
        id: '1',
        userId: 'user_1',
        type: 'Test Loan',
        amount: 50000.0,
        tenure: 12,
        interestRate: 5.0,
        monthlyRepayment: 4500.0,
        totalRepayment: 54000.0,
        status: 'pending',
        guarantorsAccepted: 0,
        guarantorsRequired: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      expect(loan.daysSinceCreation, greaterThanOrEqualTo(29));
    });

    test('should identify pending status correctly', () {
      final pendingLoan = Loan(
        id: '1',
        userId: 'user_1',
        type: 'Test Loan',
        amount: 50000.0,
        tenure: 12,
        interestRate: 5.0,
        monthlyRepayment: 4500.0,
        totalRepayment: 54000.0,
        status: 'pending',
        guarantorsAccepted: 0,
        guarantorsRequired: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(pendingLoan.isPending, isTrue);
      expect(pendingLoan.isApproved, isFalse);
      expect(pendingLoan.isActive, isFalse);
    });

    test('should identify approved status correctly', () {
      final approvedLoan = Loan(
        id: '1',
        userId: 'user_1',
        type: 'Test Loan',
        amount: 50000.0,
        tenure: 12,
        interestRate: 5.0,
        monthlyRepayment: 4500.0,
        totalRepayment: 54000.0,
        status: 'approved',
        guarantorsAccepted: 2,
        guarantorsRequired: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
        approvedAt: DateTime.now(),
      );

      expect(approvedLoan.isApproved, isTrue);
      expect(approvedLoan.isPending, isFalse);
      expect(approvedLoan.isActive, isFalse);
    });

    test('should identify active/repaying status correctly', () {
      final activeLoan = Loan(
        id: '1',
        userId: 'user_1',
        type: 'Test Loan',
        amount: 50000.0,
        tenure: 12,
        interestRate: 5.0,
        monthlyRepayment: 4500.0,
        totalRepayment: 54000.0,
        status: 'repaying',
        guarantorsAccepted: 2,
        guarantorsRequired: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now(),
        approvedAt: DateTime.now().subtract(const Duration(days: 30)),
        disbursedAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      expect(activeLoan.isActive, isTrue);
      expect(activeLoan.isApproved, isFalse);
      expect(activeLoan.isPending, isFalse);
    });

    test('should handle guarantors status', () {
      final loanWaitingForGuarantors = Loan(
        id: '1',
        userId: 'user_1',
        type: 'Test Loan',
        amount: 50000.0,
        tenure: 12,
        interestRate: 5.0,
        monthlyRepayment: 4500.0,
        totalRepayment: 54000.0,
        status: 'pending_guarantors',
        guarantorsAccepted: 1,
        guarantorsRequired: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(loanWaitingForGuarantors.isPending, isTrue);
      expect(loanWaitingForGuarantors.isGuarantorsPending, isTrue);
    });
  });

  group('LoanCalculator Tests', () {
    test('should calculate monthly repayment correctly', () {
      // 100,000 at 10% for 12 months
      final result = LoanCalculator.calculateMonthlyRepayment(
        principal: 100000.0,
        annualRate: 10.0,
        tenureMonths: 12,
      );

      expect(result, closeTo(8791.59, 0.01));
    });

    test('should calculate total repayment correctly', () {
      final monthlyRepayment = 8791.59;
      final tenureMonths = 12;

      final total = LoanCalculator.calculateTotalRepayment(
        monthlyRepayment: monthlyRepayment,
        tenureMonths: tenureMonths,
      );

      expect(total, closeTo(105499.08, 0.01));
    });

    test('should calculate total interest correctly', () {
      final totalInterest = LoanCalculator.calculateTotalInterest(
        principal: 100000.0,
        totalRepayment: 105499.08,
      );

      expect(totalInterest, closeTo(5499.08, 0.01));
    });
  });
}
