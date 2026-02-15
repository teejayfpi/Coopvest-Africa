import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/utils.dart';
import '../../../data/models/kyc_models.dart';
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
  
  String? _selectedEmploymentType;
  String? _selectedOrganization;
  String? _selectedIncomeRange;
  String? _selectedGender;
  String? _selectedCity;
  String? _selectedState;
  
  final List<String> _employmentTypes = EmploymentTypes.types;
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _cities = ['Lagos', 'Abuja', 'Port Harcourt', 'Ibadan', 'Kano', 'Other'];
  final List<String> _states = [
    'Lagos', 'Abuja FCT', 'Rivers', 'Oyo', 'Kano', 'Enugu', 'Delta', 'Other'
  ];

  // Pre-approved organizations
  final List<Map<String, dynamic>> _preApprovedOrganizations = [
    {
      'label': 'Government',
      'icon': Icons.account_balance,
      'organizations': [
        'Federal Government Ministries, Departments & Agencies (MDAs)',
        'State Government MDAs',
        'Local Government Councils',
      ]
    },
    {
      'label': 'Education',
      'icon': Icons.school,
      'organizations': [
        'Federal Universities',
        'State Universities',
        'Private Universities',
        'Federal Teaching Hospitals',
        'State Teaching Hospitals',
        'Polytechnics',
        'Colleges of Education',
      ]
    },
    {
      'label': 'Health',
      'icon': Icons.local_hospital,
      'organizations': [
        'Federal Health Institutions',
        'State Health Institutions',
        'Private Hospitals',
      ]
    },
    {
      'label': 'Banking & Finance',
      'icon': Icons.monetization_on,
      'organizations': [
        'Commercial Banks',
        'Microfinance Banks',
        'Insurance Companies',
        'Asset Management Companies',
      ]
    },
    {
      'label': 'Private Sector',
      'icon': Icons.business,
      'organizations': [
        'Registered Corporate Organizations',
        'Faith-Based Institutions',
        'Approved Private Companies',
      ]
    },
  ];

  List<String> _filteredOrganizations = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _dateOfBirthController = TextEditingController();
    _jobTitleController = TextEditingController();
    _addressController = TextEditingController();
    _organizationSearchController = TextEditingController();
    _organizationSearchController.addListener(_onOrganizationSearch);
    
    _filteredOrganizations = _preApprovedOrganizations
        .expand((cat) => cat['organizations'] as List)
        .cast<String>()
        .toList();
  }

  @override
  void dispose() {
    _dateOfBirthController.dispose();
    _jobTitleController.dispose();
    _addressController.dispose();
    _organizationSearchController.dispose();
    super.dispose();
  }

  void _onOrganizationSearch() {
    setState(() {
      _searchQuery = _organizationSearchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredOrganizations = _preApprovedOrganizations
            .expand((cat) => cat['organizations'] as List)
            .cast<String>()
            .toList();
      } else {
        _filteredOrganizations = _preApprovedOrganizations
            .expand((cat) => cat['organizations'] as List)
            .cast<String>()
            .where((org) => org.toLowerCase().contains(_searchQuery))
            .toList();
      }
    });
  }

  void _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 70)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: CoopvestColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: CoopvestColors.darkGray,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  void _validateAndContinue() {
    final errors = <String>[];
    
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
    if (_dateOfBirthController.text.isEmpty) {
      errors.add('Date of birth is required');
    }
    if (_addressController.text.isEmpty) {
      errors.add('Residential address is required');
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
      organizationName: _selectedOrganization,
      jobTitle: _jobTitleController.text,
      monthlyIncomeRange: _selectedIncomeRange,
    );

    ref.read(kycProvider.notifier).updatePersonalDetails(
      dateOfBirth: _dateOfBirthController.text,
      gender: _selectedGender,
    );

    ref.read(kycProvider.notifier).updateAddress(
      residentialAddress: _addressController.text,
      city: _selectedCity,
      stateValue: _selectedState,
    );

    // Navigate to next step
    Navigator.of(context).pushNamed('/kyc-id-upload');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CoopvestColors.darkGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Employment Details',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: CoopvestColors.darkGray,
          ),
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
                style: CoopvestTypography.headlineSmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),

              // Date of Birth
              AppTextField(
                label: 'Date of Birth *',
                hint: 'Select your date of birth',
                controller: _dateOfBirthController,
                readOnly: true,
                onTap: _selectDateOfBirth,
                suffixIcon: const Icon(
                  Icons.calendar_today,
                  color: CoopvestColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 20),

              // Gender
              AppDropdown<String>(
                label: 'Gender (Optional)',
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
                style: CoopvestTypography.headlineSmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
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
                validator: (value) => value == null ? 'Employment type is required' : null,
              ),
              const SizedBox(height: 20),

              // Organization Search
              Text(
                'Organization / Employer *',
                style: CoopvestTypography.labelLarge.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              
              // Search Field
              TextField(
                controller: _organizationSearchController,
                decoration: InputDecoration(
                  hintText: 'Search for your organization...',
                  prefixIcon: const Icon(Icons.search, color: CoopvestColors.primary),
                  filled: true,
                  fillColor: CoopvestColors.veryLightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: CoopvestColors.lightGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: CoopvestColors.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: CoopvestColors.primary, width: 2),
                  ),
                ),
                onChanged: (_) => _onOrganizationSearch(),
              ),
              const SizedBox(height: 12),

              // Selected Organization Display
              if (_selectedOrganization != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CoopvestColors.primary.withAlpha((255 * 0.1).toInt()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CoopvestColors.primary),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: CoopvestColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedOrganization!,
                          style: CoopvestTypography.bodyMedium.copyWith(
                            color: CoopvestColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedOrganization = null;
                            _organizationSearchController.clear();
                          });
                        },
                        child: const Icon(Icons.close, color: CoopvestColors.primary),
                      ),
                    ],
                  ),
                )
              else if (_searchQuery.isEmpty)
                // Show categorized organizations
                _buildOrganizationCategories()
              else if (_filteredOrganizations.isEmpty)
                // Show "Not Listed" option
                _buildNotListedOption()
              else
                // Show search results
                _buildSearchResults(),

              const SizedBox(height: 20),

              // Job Title
              AppTextField(
                label: 'Job Title / Designation *',
                hint: 'e.g., Administrative Officer',
                controller: _jobTitleController,
                textInputAction: TextInputAction.next,
                validator: (value) => Validators.validateNotEmpty(value, 'Field'),
              ),
              const SizedBox(height: 20),

              // Monthly Income Range
              Text(
                'Monthly Income Range *',
                style: CoopvestTypography.labelLarge.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: IncomeRanges.ranges.map((range) {
                  final isSelected = _selectedIncomeRange == range['value'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIncomeRange = range['value'] as String?;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CoopvestColors.primary
                            : CoopvestColors.veryLightGray,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? CoopvestColors.primary
                              : CoopvestColors.lightGray,
                        ),
                      ),
                      child: Text(
                        range['label'] as String,
                        style: CoopvestTypography.bodySmall.copyWith(
                          color: isSelected ? Colors.white : CoopvestColors.darkGray,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Address Section
              Text(
                'Residential Address',
                style: CoopvestTypography.headlineSmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),

              // Residential Address
              AppTextField(
                label: 'Residential Address *',
                hint: 'Enter your full address',
                controller: _addressController,
                maxLines: 3,
                minLines: 2,
                validator: (value) => Validators.validateNotEmpty(value, 'Field'),
              ),
              const SizedBox(height: 20),

              // City & State
              Row(
                children: [
                  Expanded(
                    child: AppDropdown<String>(
                      label: 'City (Optional)',
                      value: _selectedCity,
                      items: _cities.map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCity = value;
                        });
                      },
                      hint: 'Select city',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppDropdown<String>(
                      label: 'State (Optional)',
                      value: _selectedState,
                      items: _states.map((state) => DropdownMenuItem(
                        value: state,
                        child: Text(state, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedState = value;
                        });
                      },
                      hint: 'Select state',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Continue Button
              PrimaryButton(
                label: 'Continue',
                onPressed: _validateAndContinue,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(int step, bool isActive) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? CoopvestColors.primary : CoopvestColors.lightGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: isActive
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                '$step',
                style: TextStyle(
                  color: isActive ? Colors.white : CoopvestColors.mediumGray,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    final isComplete = step < 1; // Step 1 is complete
    return Expanded(
      child: Container(
        height: 2,
        color: isComplete ? CoopvestColors.primary : CoopvestColors.lightGray,
      ),
    );
  }

  Widget _buildOrganizationCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _preApprovedOrganizations.map((category) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  (category['icon'] as IconData?) ?? Icons.business,
                  color: CoopvestColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  (category['label'] as String?) ?? 'Other',
                  style: CoopvestTypography.labelLarge.copyWith(
                    color: CoopvestColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...(category['organizations'] as List<String>).map((org) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedOrganization = org;
                    _organizationSearchController.text = org;
                  });
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: CoopvestColors.veryLightGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    org,
                    style: CoopvestTypography.bodyMedium.copyWith(
                      color: CoopvestColors.darkGray,
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search Results',
          style: CoopvestTypography.labelMedium.copyWith(
            color: CoopvestColors.mediumGray,
          ),
        ),
        const SizedBox(height: 8),
        ..._filteredOrganizations.map((org) {
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedOrganization = org;
                _organizationSearchController.text = org;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: CoopvestColors.veryLightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      org,
                      style: CoopvestTypography.bodyMedium.copyWith(
                        color: CoopvestColors.darkGray,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.add_circle_outline,
                    color: CoopvestColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        _buildNotListedOption(),
      ],
    );
  }

  Widget _buildNotListedOption() {
    return GestureDetector(
      onTap: () {
        // Show dialog to request organization approval
        _showRequestOrganizationDialog();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CoopvestColors.warning.withAlpha((255 * 0.1).toInt()),
          border: Border.all(color: CoopvestColors.warning),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: CoopvestColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My organization is not listed',
                    style: CoopvestTypography.bodyMedium.copyWith(
                      color: CoopvestColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submit a request for admin verification and approval',
                    style: CoopvestTypography.bodySmall.copyWith(
                      color: CoopvestColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: CoopvestColors.warning,
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestOrganizationDialog() {
    final organizationController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Organization Approval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your organization will be submitted for admin verification. This process typically takes 24-48 hours.',
              style: CoopvestTypography.bodyMedium.copyWith(
                color: CoopvestColors.mediumGray,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Organization Name',
              controller: organizationController,
              hint: 'Enter your organization name',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (organizationController.text.isNotEmpty) {
                ref.read(kycProvider.notifier).requestOrganizationApproval(
                  organizationController.text,
                );
                setState(() {
                  _selectedOrganization = organizationController.text;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}
