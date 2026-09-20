import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/kyc_models.dart';
import '../../../data/models/nigeria_locations.dart';
import '../../../presentation/providers/kyc_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// KYC Employment Details Screen
class KYCEmploymentDetailsScreen extends ConsumerStatefulWidget {
  final bool isFromRegistration;
  
  const KYCEmploymentDetailsScreen({
    Key? key,
    this.isFromRegistration = false,
  }) : super(key: key);

  @override
  ConsumerState<KYCEmploymentDetailsScreen> createState() =>
      _KYCEmploymentDetailsScreenState();
}

class _KYCEmploymentDetailsScreenState
    extends ConsumerState<KYCEmploymentDetailsScreen> {
  late TextEditingController _dateOfBirthController;
  late TextEditingController _jobTitleController;
  late TextEditingController _addressController;
  late TextEditingController _organizationSearchController;
  // Extra employment fields (aligned with registration onboarding)
  late TextEditingController _occupationController;
  late TextEditingController _employerNameController;
  late TextEditingController _workAddressController;
  late TextEditingController _yearsOfEmploymentController;

  String? _selectedEmploymentType;
  String? _selectedOrganization;
  String? _selectedIncomeRange;
  String? _selectedGender;
  String? _selectedCity;
  String? _selectedState;
  // Selected LGA value, driven by the state above it. Was a free-text field.
  String? _selectedLga;
  
  final List<String> _employmentTypes = EmploymentTypes.types;
  // Male / Female only. 'Other' and 'Prefer not to say' were removed so the
  // field records a binary value the KYC review can act on.
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _cities = ['Lagos', 'Abuja', 'Port Harcourt', 'Ibadan', 'Kano', 'Other'];
  // Superseded by NigeriaLocations.states — the list here was only eight
  // states ('Other' for everyone else), so most members could not pick their
  // real state and the LGA field next to it was free text.

  // Partner organisations are fetched from the backend so a new employer can be
  // added without an app release. This replaced a hardcoded list of ~18 generic
  // strings ("Federal Universities", "Commercial Banks", …) that could never
  // match a real `organizations` row, so the member's employer was recorded as
  // free text with no organisation id — and nothing could ever be remitted
  // against it.
  List<Organization> _organizations = [];
  bool _organizationsLoading = true;
  String? _organizationsError;
  /// Organisation the member picked, tracked by id as well as name so a payroll
  /// remittance can be matched to them later.
  String? _selectedOrganizationId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _dateOfBirthController = TextEditingController();
    _jobTitleController = TextEditingController();
    _addressController = TextEditingController();
    _organizationSearchController = TextEditingController();
    _occupationController = TextEditingController();
    _employerNameController = TextEditingController();
    _workAddressController = TextEditingController();
    _yearsOfEmploymentController = TextEditingController();
    _organizationSearchController.addListener(_onOrganizationSearch);
    _loadOrganizations();

    // Make sure we have the member's existing KYC loaded so we can pre-fill
    // already-saved data and skip steps that are already complete.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Re-run the pre-fill/skip logic whenever the KYC state transitions to
      // 'loaded' (e.g. after the initializeKYC() call we trigger here).
      ref.listenManual(kycProvider, (prev, next) {
        if (next.status == KYCStatus.loaded &&
            (prev == null || prev.status != KYCStatus.loaded)) {
          _loadExistingAndMaybeSkip();
        }
      });
      _loadExistingAndMaybeSkip();
    });
  }

  /// Pre-fill the form from any existing KYC submission and, if every field
  /// on this step is already present, jump straight to the next incomplete
  /// step (so the member is only asked for data that's actually missing).
  void _loadExistingAndMaybeSkip() {
    final kycState = ref.read(kycProvider);
    if (kycState.status == KYCStatus.initial ||
        kycState.status == KYCStatus.loading) {
      // Trigger a load; the listener above will re-run us when it completes.
      ref.read(kycProvider.notifier).initializeKYC();
      return;
    }

    final sub = kycState.submission;
    if (sub == null) {
      // No existing submission — start fresh.
      return;
    }

    setState(() {
      _selectedEmploymentType =
          sub.employmentType.isNotEmpty ? sub.employmentType : null;
      _selectedOrganization = sub.organizationName;
      _jobTitleController.text = sub.jobTitle;
      _selectedIncomeRange =
          sub.monthlyIncomeRange.isNotEmpty ? sub.monthlyIncomeRange : null;
      _dateOfBirthController.text = sub.dateOfBirth ?? '';
      _selectedGender = sub.gender;
      _addressController.text = sub.residentialAddress;
      _selectedCity = sub.city;
      _selectedState = sub.state;
      _selectedLga = sub.lga;
      // New aligned fields
      _occupationController.text = sub.occupation ?? '';
      _employerNameController.text = sub.employerName ?? '';
      _workAddressController.text = sub.workAddress ?? '';
      _yearsOfEmploymentController.text = sub.yearsOfEmployment ?? '';
    });

    // If this whole step is already complete, skip forward to the first
    // incomplete step.
    if (_isStepComplete(sub)) {
      _skipToNextIncompleteStep(sub);
    }
  }

  bool _isStepComplete(KYCSubmission sub) {
    // Employment fields only matter for salary-deduction members; everyone
    // needs the personal basics.
    final basics = sub.dateOfBirth != null &&
        sub.residentialAddress.isNotEmpty &&
        sub.state != null;
    if (!sub.isSalaryDeduction) return basics;
    return basics &&
        sub.employmentType.isNotEmpty &&
        sub.organizationName != null &&
        sub.jobTitle.isNotEmpty &&
        sub.monthlyIncomeRange.isNotEmpty;
  }

  /// Navigate to the first KYC section that still has missing data, in flow
  /// order: employment → identification → next-of-kin → bank → success.
  void _skipToNextIncompleteStep(KYCSubmission sub) {
    final missing = sub.missingSections;
    if (missing.isEmpty || missing.first == 'employment') {
      return; // stay here (or nothing missing — shouldn't reach via this entry)
    }
    final route = {
      'identification': '/kyc-id-upload',
      'nextOfKin': '/kyc-next-of-kin',
      'bank': '/kyc-bank-info',
    }[missing.first];
    if (route != null) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  @override
  void dispose() {
    _dateOfBirthController.dispose();
    _jobTitleController.dispose();
    _addressController.dispose();
    _organizationSearchController.dispose();
    _occupationController.dispose();
    _employerNameController.dispose();
    _workAddressController.dispose();
    _yearsOfEmploymentController.dispose();
    super.dispose();
  }

  /// Load the enrolled partner organisations once, at screen entry.
  ///
  /// A failure leaves the list empty and surfaces a retry rather than silently
  /// showing a stale hardcoded list — a member must not be able to pick an
  /// employer that is not actually enrolled, because their contributions could
  /// never be remitted.
  Future<void> _loadOrganizations() async {
    setState(() {
      _organizationsLoading = true;
      _organizationsError = null;
    });
    try {
      final orgs = await ref.read(kycProvider.notifier).loadOrganizations();
      if (!mounted) return;
      setState(() {
        _organizations = orgs;
        _organizationsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _organizationsLoading = false;
        _organizationsError = 'Could not load organizations. Please try again.';
      });
    }
  }

  void _onOrganizationSearch() {
    // The full list is small and already in memory, so filtering is local and
    // instant; a network round-trip per keystroke would add latency for no
    // benefit and would fail offline mid-KYC.
    setState(() {
      _searchQuery = _organizationSearchController.text.toLowerCase();
    });
  }

  /// Organisations matching the current search text.
  ///
  /// Matches on whole words as well as substrings: with 400+ institutions the
  /// list is impractical to scroll, so members search by what they remember —
  /// "polytechnic bauchi", "okoho", "bowen iwo". A plain substring test only
  /// finds a contiguous run, so "polytechnic bauchi" matched nothing even
  /// though "Federal Polytechnic, Bauchi" is listed. Every whitespace-separated
  /// term must appear somewhere in the name or code, in any order.
  List<Organization> get _filteredOrganizations {
    if (_searchQuery.isEmpty) return _organizations;
    final terms = _searchQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return _organizations;
    return _organizations.where((o) {
      final haystack = '${o.name} ${o.code ?? ''}'.toLowerCase();
      return terms.every(haystack.contains);
    }).toList();
  }

  void _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 70)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: CoopvestColors.primary,
              onPrimary: Colors.white,
              surface: isDarkMode ? CoopvestColors.darkSurface : Colors.white,
              onSurface: isDarkMode ? Colors.white : CoopvestColors.darkGray,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _validateAndContinue() {
    final errors = <String>[];

    // Payroll details are only mandatory for salary-deduction members;
    // direct-deposit members fill just the personal basics on this screen.
    final needsEmployment =
        ref.read(kycProvider).submission?.isSalaryDeduction ?? true;

    if (needsEmployment) {
      if (_selectedEmploymentType == null) {
        errors.add('Employment Type is required');
      }
      if (_selectedOrganization == null) {
        errors.add('Organization is required');
      }
      if (_jobTitleController.text.isEmpty) {
        errors.add('Job title is required');
      }
      if (_selectedIncomeRange == null) {
        errors.add('Monthly income range is required');
      }
    }
    // Gender is required for every member, not just payroll ones: it is part
    // of the KYC identity record.
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      errors.add('Gender is required');
    }
    if (_dateOfBirthController.text.isEmpty) {
      errors.add('Date of birth is required');
    }
    if (_addressController.text.isEmpty) {
      errors.add('Residential address is required');
    }
    if (_selectedState == null || _selectedState!.isEmpty) {
      errors.add('State is required');
    }
    if (_selectedLga == null || _selectedLga!.isEmpty) {
      errors.add('Local Government Area is required');
    }

    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: errors.map((e) => Text('• $e')).toList(),
          ),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    // Update KYC state
    ref.read(kycProvider.notifier).updateEmploymentDetails(
      employmentType: _selectedEmploymentType,
      // The id is what lets a payroll remittance be matched to this member; the
      // name alone cannot be reconciled against reliably.
      organizationId: _selectedOrganizationId,
      organizationName: _selectedOrganization,
      jobTitle: _jobTitleController.text,
      monthlyIncomeRange: _selectedIncomeRange,
      occupation: _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      employerName: _employerNameController.text.trim().isEmpty
          ? null
          : _employerNameController.text.trim(),
      workAddress: _workAddressController.text.trim().isEmpty
          ? null
          : _workAddressController.text.trim(),
      yearsOfEmployment: _yearsOfEmploymentController.text.trim().isEmpty
          ? null
          : _yearsOfEmploymentController.text.trim(),
    );

    ref.read(kycProvider.notifier).updatePersonalDetails(
      dateOfBirth: _dateOfBirthController.text,
      gender: _selectedGender,
    );

    ref.read(kycProvider.notifier).updateAddress(
      residentialAddress: _addressController.text,
      city: _selectedCity,
      stateValue: _selectedState,
      lga: _selectedLga,
    );

    // Navigate to next step
    Navigator.of(context).pushNamed('/kyc-id-upload');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Employment Details',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Indicator
              Row(
                children: [
                  _buildProgressStep(1, true),
                  _buildProgressLine(1),
                  _buildProgressStep(2, false),
                  _buildProgressLine(2),
                  _buildProgressStep(3, false),
                ],
              ),
              const SizedBox(height: 32),

              // Personal Information Section
              Text(
                'Personal Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 16),

              // Date of Birth
              AppTextField(
                label: 'Date of Birth *',
                hint: 'Select your date of birth',
                controller: _dateOfBirthController,
                readOnly: true,
                onTap: _selectDateOfBirth,
                suffixIcon: Icon(
                  Icons.calendar_today,
                  color: CoopvestColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 20),

              // Gender
              AppDropdown<String>(
                // Mandatory, Male/Female only.
                label: 'Gender',
                value: _selectedGender,
                items: _genders.map((gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                hint: 'Select your gender',
              ),
              const SizedBox(height: 20),

              // Employment Section
              Text(
                'Employment Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 16),

              // Employment Type
              AppDropdown<String>(
                label: 'Employment Type *',
                value: _selectedEmploymentType,
                items: _employmentTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEmploymentType = value;
                  });
                },
                hint: 'Select employment type',
              ),
              const SizedBox(height: 20),

              // Organization
              Text(
                'Organization *',
                style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showOrganizationPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedOrganization ?? 'Select your organization',
                          style: TextStyle(
                            color: _selectedOrganization == null 
                                ? context.textSecondary 
                                : context.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: context.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Job Title
              AppTextField(
                label: 'Job Title *',
                hint: 'Enter your job title',
                controller: _jobTitleController,
              ),
              const SizedBox(height: 20),

              // Income Range
              AppDropdown<String>(
                label: 'Monthly Income Range *',
                value: _selectedIncomeRange,
                items: IncomeRanges.ranges.map((range) => DropdownMenuItem<String>(
                  value: range['value'] as String,
                  child: Text(range['label'] as String),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedIncomeRange = value;
                  });
                },
                hint: 'Select income range',
              ),
              const SizedBox(height: 20),

              // Occupation (aligned with registration)
              AppTextField(
                label: 'Occupation',
                hint: 'Enter your occupation',
                controller: _occupationController,
              ),
              const SizedBox(height: 20),

              // Employer name
              AppTextField(
                label: 'Employer Name',
                hint: 'Enter your employer / organization name',
                controller: _employerNameController,
              ),
              const SizedBox(height: 20),

              // Work address
              AppTextField(
                label: 'Work Address',
                hint: 'Enter your work address',
                controller: _workAddressController,
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Years of employment
              AppTextField(
                label: 'Years of Employment',
                hint: 'e.g. 3',
                controller: _yearsOfEmploymentController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              // Address Section
              Text(
                'Residential Address',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 16),

              // Address
              AppTextField(
                label: 'Residential Address *',
                hint: 'Enter your full residential address',
                controller: _addressController,
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // State, then LGA driven by that state.
              //
              // Order matters to the member: pick the state first and the LGA
              // list narrows to that state's own LGAs. Previously this was a
              // free-text "LGA" box above an eight-state dropdown, so a member
              // outside those eight had no valid state to choose and the LGA
              // they typed could never match a canonical value.
              AppDropdown<String>(
                label: 'State *',
                value: _selectedState,
                items: NigeriaLocations.states
                    .map((state) => DropdownMenuItem(
                          value: state['value'],
                          child: Text(state['label'] ?? ''),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedState = value;
                    // The previous LGA belongs to the previous state, so clear
                    // it rather than silently persisting a mismatched pair.
                    _selectedLga = null;
                  });
                },
                hint: 'Select your state',
              ),
              const SizedBox(height: 20),

              AppDropdown<String>(
                label: 'Local Government Area *',
                value: _selectedLga,
                items: NigeriaLocations.lgasFor(_selectedState)
                    .map((lga) => DropdownMenuItem(
                          value: lga['value'],
                          child: Text(lga['label'] ?? ''),
                        ))
                    .toList(),
                onChanged: _selectedState == null
                    ? null
                    : (value) => setState(() => _selectedLga = value),
                hint: _selectedState == null
                    ? 'Select your state first'
                    : 'Select your LGA',
              ),
              const SizedBox(height: 20),

              // City
              Row(
                children: [
                  Expanded(
                    child: AppDropdown<String>(
                      label: 'City *',
                      value: _selectedCity,
                      items: _cities.map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCity = value;
                        });
                      },
                      hint: 'City',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Continue Button
              PrimaryButton(
                label: 'Continue',
                onPressed: _validateAndContinue,
                width: double.infinity,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrganizationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: context.scaffoldBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _organizationSearchController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search organization...',
                    hintStyle: TextStyle(color: context.textSecondary),
                    prefixIcon: Icon(Icons.search, color: context.textSecondary),
                    filled: true,
                    fillColor: context.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setModalState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildOrganizationList(setModalState)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationList(StateSetter setModalState) {
    if (_organizationsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_organizationsError != null) {
      return _buildOrganizationMessage(
        icon: Icons.cloud_off,
        title: 'Could not load organizations',
        message: _organizationsError!,
        actionLabel: 'Try again',
        onAction: () {
          setModalState(() {});
          _loadOrganizations();
        },
      );
    }

    if (_organizations.isEmpty) {
      return _buildOrganizationMessage(
        icon: Icons.business_outlined,
        title: 'No organizations enrolled yet',
        message:
            'Your employer is not yet set up for salary deduction. Request them below and we will contact them.',
        actionLabel: 'Request my employer',
        onAction: () => _promptRequestApproval(),
      );
    }

    final results = _filteredOrganizations;

    if (results.isEmpty) {
      // The member's employer is not enrolled. Previously there was nothing to
      // do here at all, and the "request approval" call went to an endpoint that
      // did not exist — so the member was stuck. Now the search text they typed
      // becomes the request.
      final typed = _organizationSearchController.text.trim();
      return _buildOrganizationMessage(
        icon: Icons.search_off,
        title: 'No match found',
        message: typed.isEmpty
            ? 'No organizations match your search.'
            : '"$typed" is not enrolled yet. You can request them below.',
        actionLabel: typed.isEmpty ? null : 'Request "$typed"',
        onAction: typed.isEmpty ? null : () => _promptRequestApproval(typed),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final org = results[index];
        return ListTile(
          title: Text(org.name, style: TextStyle(color: context.textPrimary)),
          subtitle: org.code == null || org.code!.isEmpty
              ? null
              : Text(
                  org.code!,
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
          onTap: () {
            setState(() {
              _selectedOrganization = org.name;
              _selectedOrganizationId = org.id;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildOrganizationMessage({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              PrimaryButton(label: actionLabel, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }

  /// Ask us to enrol an employer.
  ///
  /// Defaults to whatever the member typed in the search box, since they have
  /// already told us who their employer is by trying to find them.
  Future<void> _promptRequestApproval([String? prefilled]) async {
    final controller = TextEditingController(
      text: prefilled ?? _organizationSearchController.text.trim(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request your employer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell us who you work for and we will contact them about joining '
              'Coopvest. Salary deduction can be switched on once they are enrolled.',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Employer name',
                hintText: 'e.g. Lagos State Ministry of Finance',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    try {
      final result =
          await ref.read(kycProvider.notifier).requestOrganizationApproval(name);
      if (!mounted) return;

      final status = result['status'];
      if (status == 'enrolled') {
        // The employer turned out to be enrolled after all — refresh so the
        // member can simply pick them instead of waiting on a needless request.
        await _loadOrganizations();
        if (!mounted) return;
        _showSnack(
          result['message']?.toString() ??
              '$name is already enrolled — you can select it now.',
        );
      } else {
        if (!mounted) return;
        _showSnack(
          result['message']?.toString() ??
              'Request received. We will contact your employer.',
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not send your request. Please try again.', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? CoopvestColors.error : null,
      ),
    );
  }


  Widget _buildProgressStep(int step, bool isCompleted) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isCompleted ? CoopvestColors.primary : context.dividerColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted 
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : Text(
              '$step',
              style: TextStyle(
                color: context.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    return Expanded(
      child: Container(
        height: 2,
        color: context.dividerColor,
      ),
    );
  }
}