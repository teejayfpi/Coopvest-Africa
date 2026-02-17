import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
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

              // State & City
              Row(
                children: [
                  Expanded(
                    child: AppDropdown<String>(
                      label: 'State *',
                      value: _selectedState,
                      items: _states.map((state) => DropdownMenuItem(
                        value: state,
                        child: Text(state),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedState = value;
                        });
                      },
                      hint: 'State',
                    ),
                  ),
                  const SizedBox(width: 16),
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
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredOrganizations.length,
                  itemBuilder: (context, index) {
                    final org = _filteredOrganizations[index];
                    return ListTile(
                      title: Text(org, style: TextStyle(color: context.textPrimary)),
                      onTap: () {
                        setState(() {
                          _selectedOrganization = org;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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