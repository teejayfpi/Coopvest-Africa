/// Terms & Conditions content model.
///
/// The app first tries to load the current document from the backend
/// (`GET /api/v1/terms`) so legal text can be updated without an app
/// release; the bundled copy below is the offline fallback. The [version]
/// of the document a member accepts is recorded together with the
/// acceptance timestamp.
library;

class TermsSection {
  /// Stable identifier used to track "viewed" and "accepted" state.
  final String id;
  final String title;
  final String summary;
  final String body;

  const TermsSection({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
  });

  factory TermsSection.fromJson(Map<String, dynamic> json) {
    return TermsSection(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      body: (json['body'] ?? '') as String,
    );
  }
}

class TermsDocument {
  final String version;
  final List<TermsSection> sections;

  const TermsDocument({required this.version, required this.sections});

  factory TermsDocument.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    return TermsDocument(
      version: (json['version'] ?? TermsContent.version) as String,
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(TermsSection.fromJson)
              .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
              .toList()
          : TermsContent.sections,
    );
  }
}

class TermsContent {
  TermsContent._();

  /// Version of the bundled document. Bump whenever the text changes.
  static const String version = '2026-09-01';

  static const List<TermsSection> sections = [
    TermsSection(
      id: 'terms_and_conditions',
      title: 'Terms & Conditions',
      summary:
          'The membership terms governing your Coopvest Africa account.',
      body:
          'These Terms and Conditions govern your membership of Coopvest Africa '
          'and your use of the Coopvest mobile application and related services. '
          'By creating an account you agree to be bound by these terms.\n\n'
          '1. Membership is open to individuals who are at least 18 years old and '
          'who complete the required identity verification (KYC) process.\n\n'
          '2. You are responsible for the accuracy of the information you provide '
          'and for keeping your login credentials confidential.\n\n'
          '3. Coopvest Africa provides cooperative savings, contribution, and '
          'credit services to registered members. Services may be updated, '
          'suspended, or withdrawn with reasonable notice.\n\n'
          '4. You must not use the platform for any unlawful purpose, including '
          'fraud, money laundering, or the financing of prohibited activities.\n\n'
          '5. Coopvest Africa may suspend or terminate accounts that breach these '
          'terms, subject to applicable law and the cooperative\'s bylaws.\n\n'
          '6. These terms are governed by the laws of the Federal Republic of '
          'Nigeria.',
    ),
    TermsSection(
      id: 'contribution_policy',
      title: 'Contribution Policy',
      summary:
          'Monthly contribution rules: minimum ₦5,000, increases anytime, '
          'reductions require 3-month notice.',
      body:
          '1. Every member must make a minimum monthly contribution of ₦5,000. '
          'A one-time, non-refundable registration fee of ₦5,000 applies to all '
          'new members and is added to the first contribution.\n\n'
          '2. Members may increase their monthly contribution at any time '
          'through the app, and the new amount takes effect from the next '
          'contribution cycle.\n\n'
          '3. Requests to reduce a monthly contribution require a minimum of '
          'three (3) months\' written notice to the cooperative.\n\n'
          '4. Contributions may be made by manual monthly self-contribution or '
          'by salary deduction (payroll) through your employer.\n\n'
          '5. Consistent contributions improve eligibility for future financial '
          'support services. Contribution history and account records are '
          'tracked digitally for transparency.',
    ),
    TermsSection(
      id: 'loan_policy',
      title: 'Loan Policy',
      summary:
          'Loan eligibility criteria, guarantor requirements, and repayment '
          'obligations.',
      body:
          '1. Loan eligibility is based on membership duration, contribution '
          'history, and the cooperative\'s prevailing credit policy.\n\n'
          '2. Loan amounts, interest rates, and tenures are determined by the '
          'loan product selected and are displayed in the app before you apply.\n\n'
          '3. Approved loans are disbursed to the bank account verified during '
          'registration.\n\n'
          '4. Repayment is made in line with the repayment schedule shown at '
          'the time of application. Early repayment is allowed without penalty.\n\n'
          '5. Failure to repay as scheduled may affect your credit standing '
          'within the cooperative, your eligibility for future loans, and may '
          'trigger the Default & Recovery Policy.',
    ),
    TermsSection(
      id: 'guarantor_requirement',
      title: 'Guarantor Requirement',
      summary:
          'Loans under the direct contribution model require three guarantors.',
      body:
          '1. Loans accessed under the direct contribution model require three '
          '(3) guarantors who are themselves registered and contributing members '
          'of the cooperative.\n\n'
          '2. Each guarantor must confirm their consent within the app before '
          'the loan application can proceed.\n\n'
          '3. By standing as guarantor, a member accepts joint responsibility '
          'for the repayment of the guaranteed loan in the event of default.\n\n'
          '4. Guarantor obligations end when the guaranteed loan is fully '
          'repaid.',
    ),
    TermsSection(
      id: 'default_recovery_policy',
      title: 'Default & Recovery Policy',
      summary:
          'Guarantors may be contacted in the event of prolonged loan default.',
      body:
          '1. A loan is in default when a scheduled repayment remains unpaid '
          'beyond the grace period communicated at disbursement.\n\n'
          '2. In the event of prolonged default, the cooperative may contact '
          'the borrower\'s guarantors to recover the outstanding balance.\n\n'
          '3. Outstanding balances may be recovered from the member\'s '
          'contributions, savings, or dividends held with the cooperative, in '
          'line with the cooperative\'s bylaws.\n\n'
          '4. Defaulting members may be reported to relevant credit bureaus as '
          'permitted by law.',
    ),
    TermsSection(
      id: 'registration_fee_policy',
      title: 'Registration Fee Policy',
      summary:
          'The ₦5,000 registration fee is non-refundable and is added to your '
          'first contribution.',
      body:
          '1. A one-time registration fee of ₦5,000 applies to all new members.\n\n'
          '2. The registration fee is non-refundable under any circumstances, '
          'including voluntary withdrawal or termination of membership.\n\n'
          '3. The fee is added to, and collected together with, your first '
          'monthly contribution.',
    ),
    TermsSection(
      id: 'privacy_policy',
      title: 'Privacy Policy',
      summary:
          'How we collect, store, and use your personal and financial data.',
      body:
          '1. We collect the personal and financial information you provide '
          'during registration and KYC — including your name, contact details, '
          'identification documents, BVN, and bank account details — solely to '
          'provide cooperative financial services to you.\n\n'
          '2. Your data is stored securely and processed in accordance with the '
          'Nigeria Data Protection Act (NDPA) and other applicable data '
          'protection regulations.\n\n'
          '3. Bank account verification is performed through licensed, secure '
          'third-party providers; verification credentials are never stored on '
          'your device.\n\n'
          '4. We do not sell your personal data. Data is shared only with '
          'service providers who need it to deliver the services you use, or '
          'where required by law or regulation.\n\n'
          '5. You may request access to, correction of, or deletion of your '
          'personal data, subject to legal and regulatory retention '
          'requirements, by contacting support.',
    ),
  ];

  static TermsDocument bundled() =>
      const TermsDocument(version: version, sections: sections);
}
