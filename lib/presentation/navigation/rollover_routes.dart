import 'package:flutter/material.dart';
import '../screens/rollover/rollover_eligibility_screen.dart';
import '../screens/rollover/rollover_request_screen.dart';
import '../screens/rollover/guarantor_consent_screen.dart';
import '../screens/rollover/guarantor_response_screen.dart';
import '../screens/rollover/rollover_status_screen.dart';
import '../../data/models/loan_models.dart';

/// Rollover Routes - Member-only functionality
/// Admin operations are handled in the dedicated admin web portal
class RolloverRoutes {
  static const String eligibility = '/rollover/eligibility';
  static const String request = '/rollover/request';
  static const String consent = '/rollover/consent';
  static const String status = '/rollover/status';
  static const String guarantorResponse = '/rollover/guarantor-response';

  static Map<String, Widget Function(BuildContext, dynamic)> get routes {
    return {
      eligibility: (context, args) => RolloverEligibilityScreen(
            loan: args as Loan,
          ),
      request: (context, args) => RolloverRequestScreen(
            loan: args as Loan,
          ),
      consent: (context, args) => GuarantorConsentScreen(
            rolloverId: args as String,
          ),
      status: (context, args) => RolloverStatusScreen(
            rolloverId: args as String,
          ),
      guarantorResponse: (context, args) {
        final map = args as Map<String, String>;
        return GuarantorResponseScreen(
          rolloverId: map['rolloverId']!,
          guarantorId: map['guarantorId']!,
        );
      },
    };
  }

  static List<RouteInfo> get allRoutes => [
        RouteInfo(
          path: eligibility,
          name: 'Rollover Eligibility',
          description: 'Check if a loan is eligible for rollover',
        ),
        RouteInfo(
          path: request,
          name: 'Request Rollover',
          description: 'Submit a rollover request',
        ),
        RouteInfo(
          path: consent,
          name: 'Guarantor Consent',
          description: 'Track guarantor consent status (borrower view)',
        ),
        RouteInfo(
          path: status,
          name: 'Rollover Status',
          description: 'Full timeline & status view',
        ),
        RouteInfo(
          path: guarantorResponse,
          name: 'Guarantor Response',
          description: 'Guarantor accepts or declines a rollover consent request',
        ),
      ];
}

/// Route Information for documentation
class RouteInfo {
  final String path;
  final String name;
  final String description;

  RouteInfo({
    required this.path,
    required this.name,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'description': description,
      };
}

/// Navigation Helper for Rollover Screens
class RolloverNavigator {
  /// Navigate to eligibility check screen
  static Future<void> toEligibility(BuildContext context, Loan loan) {
    return Navigator.pushNamed(
      context,
      RolloverRoutes.eligibility,
      arguments: loan,
    );
  }

  /// Navigate to rollover request screen
  static Future<void> toRequest(BuildContext context, Loan loan) {
    return Navigator.pushNamed(
      context,
      RolloverRoutes.request,
      arguments: loan,
    );
  }

  /// Navigate to guarantor consent tracker (borrower)
  static Future<void> toConsent(BuildContext context, String rolloverId) {
    return Navigator.pushNamed(
      context,
      RolloverRoutes.consent,
      arguments: rolloverId,
    );
  }

  /// Navigate to rollover status screen
  static Future<void> toStatus(BuildContext context, String rolloverId) {
    return Navigator.pushNamed(
      context,
      RolloverRoutes.status,
      arguments: rolloverId,
    );
  }

  /// Navigate to guarantor response screen (guarantor)
  static Future<void> toGuarantorResponse(
    BuildContext context, {
    required String rolloverId,
    required String guarantorId,
  }) {
    return Navigator.pushNamed(
      context,
      RolloverRoutes.guarantorResponse,
      arguments: {'rolloverId': rolloverId, 'guarantorId': guarantorId},
    );
  }
}
