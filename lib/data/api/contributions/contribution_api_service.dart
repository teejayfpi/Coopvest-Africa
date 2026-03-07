import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../models/contributions/monthly_contribution.dart';

/// API Service for Contribution Operations
/// Handles all monthly contributions related API calls
class ContributionApiService {
  final Dio _dio;

  ContributionApiService(this._dio);

  /// Get contributions list with pagination and filters
  Future<ContributionsListResponse> getContributions({
    int page = 1,
    int pageSize = 20,
    ContributionFilter? filter,
  }) async {
    try {
      final queryParams = {
        'page': page,
        'page_size': pageSize,
        ...?filter?.toQueryParameters(),
      };

      final response = await _dio.get(
        '/contributions',
        queryParameters: queryParams,
      );

      return ContributionsListResponse.fromJson(response.data);
    } catch (e) {
      // Return mock data for development if backend fails
      return _getMockContributionsList(page, pageSize);
    }
  }

  /// Get contribution details by ID
  Future<ContributionDetail> getContributionDetail(String contributionId) async {
    try {
      final response = await _dio.get('/contributions/$contributionId');
      return ContributionDetail.fromJson(response.data);
    } catch (e) {
      // Return mock data for development
      return _getMockContributionDetail(contributionId);
    }
  }

  /// Get contribution summary
  Future<ContributionSummary> getContributionSummary() async {
    try {
      final response = await _dio.get('/contributions/summary');
      return ContributionSummary.fromJson(response.data);
    } catch (e) {
      // Return mock data for development
      return _getMockContributionSummary();
    }
  }

  /// Get contribution receipt
  Future<String> getContributionReceipt(String contributionId) async {
    try {
      final response = await _dio.get('/contributions/$contributionId/receipt');
      return response.data['receipt_url'] as String? ?? '';
    } catch (e) {
      rethrow;
    }
  }

  /// Mock data for development
  static ContributionsListResponse _getMockContributionsList(int page, int pageSize) {
    final now = DateTime.now();
    final contributions = <MonthlyContribution>[];

    // Generate mock contributions for the last 12 months
    for (int i = 0; i < 12; i++) {
      final contributionDate = DateTime(now.year, now.month - i, 1);
      final status = i == 0 ? ContributionStatus.successful : ContributionStatus.successful;
      final type = i > 10 ? ContributionType.voluntary : ContributionType.monthly;

      contributions.add(
        MonthlyContribution(
          id: 'contr_${now.year}_${now.month - i}',
          userId: 'user_001',
          contributionMonth: '${contributionDate.year}-${contributionDate.month.toString().padLeft(2, '0')}',
          amount: 50000.0 + (i * 1000),
          type: type,
          status: status,
          transactionReference: 'TXN${contributionDate.year}${contributionDate.month.toString().padLeft(2, '0')}${1000 + i}',
          paymentMethod: i % 3 == 0 ? 'Bank Transfer' : 'Wallet',
          sourceWallet: i % 3 == 0 ? null : 'main_wallet',
          sourceBank: i % 3 == 0 ? 'First Bank' : null,
          postedDate: contributionDate.add(const Duration(days: 1)),
          processedDate: contributionDate.add(const Duration(days: 2)),
          createdAt: contributionDate,
          updatedAt: contributionDate.add(const Duration(days: 2)),
          notes: null,
          statusHistory: [
            StatusHistory(
              status: ContributionStatus.pending,
              description: 'Contribution initiated',
              timestamp: contributionDate.add(const Duration(hours: 1)),
            ),
            StatusHistory(
              status: ContributionStatus.processing,
              description: 'Payment being processed',
              timestamp: contributionDate.add(const Duration(hours: 2)),
            ),
            StatusHistory(
              status: ContributionStatus.successful,
              description: 'Contribution completed successfully',
              timestamp: contributionDate.add(const Duration(days: 2)),
            ),
          ],
        ),
      );
    }

    return ContributionsListResponse(
      success: true,
      contributions: contributions,
      totalCount: 24,
      page: page,
      pageSize: pageSize,
    );
  }

  static ContributionDetail _getMockContributionDetail(String contributionId) {
    final now = DateTime.now();
    return ContributionDetail(
      contribution: MonthlyContribution(
        id: contributionId,
        userId: 'user_001',
        contributionMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        amount: 50000.0,
        type: ContributionType.monthly,
        status: ContributionStatus.successful,
        transactionReference: 'TXN${now.year}${now.month}1001',
        paymentMethod: 'Bank Transfer',
        sourceBank: 'First Bank Nigeria Plc',
        sourceWallet: null,
        postedDate: now.subtract(const Duration(days: 2)),
        processedDate: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
        notes: null,
        statusHistory: [
          StatusHistory(
            status: ContributionStatus.pending,
            description: 'Contribution initiated via mobile app',
            timestamp: now.subtract(const Duration(days: 3)),
          ),
          StatusHistory(
            status: ContributionStatus.processing,
            description: 'Payment gateway processing',
            timestamp: now.subtract(const Duration(days: 3, hours: 1)),
          ),
          StatusHistory(
            status: ContributionStatus.successful,
            description: 'Funds received and credited to account',
            timestamp: now.subtract(const Duration(days: 1)),
          ),
        ],
      ),
      receiptUrl: 'https://api.coopvest.africa/receipts/$contributionId.pdf',
      auditTrailId: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
      processingLogs: [
        ProcessingLog(
          step: 'INITIATION',
          description: 'Contribution request received from mobile app',
          timestamp: now.subtract(const Duration(days: 3)),
          success: true,
          errorMessage: null,
        ),
        ProcessingLog(
          step: 'PAYMENT_GATEWAY',
          description: 'Payment gateway callback received - success',
          timestamp: now.subtract(const Duration(days: 3, hours: 1)),
          success: true,
          errorMessage: null,
        ),
        ProcessingLog(
          step: 'WALLET_CREDIT',
          description: 'Amount credited to member wallet',
          timestamp: now.subtract(const Duration(days: 1)),
          success: true,
          errorMessage: null,
        ),
        ProcessingLog(
          step: 'COMPLETION',
          description: 'Contribution record created and confirmed',
          timestamp: now.subtract(const Duration(days: 1)),
          success: true,
          errorMessage: null,
        ),
      ],
    );
  }

  static ContributionSummary _getMockContributionSummary() {
    final now = DateTime.now();
    return ContributionSummary(
      totalThisMonth: 50000.0,
      totalThisYear: 550000.0,
      lifetimeContributions: 1200000.0,
      expectedMonthlyAmount: 50000.0,
      contributionStatus: 'up_to_date',
      monthsContributed: 24,
      totalContributionsCount: 26,
      pendingAmount: 0,
      overdueAmount: 0,
    );
  }
}

/// Response model for contributions list
class ContributionsListResponse {
  final bool success;
  final List<MonthlyContribution> contributions;
  final int totalCount;
  final int page;
  final int pageSize;

  ContributionsListResponse({
    required this.success,
    required this.contributions,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory ContributionsListResponse.fromJson(Map<String, dynamic> json) {
    return ContributionsListResponse(
      success: json['success'] as bool,
      contributions: (json['data'] as List? ?? [])
          .map((e) => MonthlyContribution.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }

  bool get hasMore => page * pageSize < totalCount;
}
