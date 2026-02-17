import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../presentation/providers/kyc_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// KYC Personal Details Screen
class KYCPersonalDetailsScreen extends ConsumerStatefulWidget {
  const KYCPersonalDetailsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KYCPersonalDetailsScreen> createState() => _KYCPersonalDetailsScreenState();
}

class _KYCPersonalDetailsScreenState extends ConsumerState<KYCPersonalDetailsScreen> {
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  
  String? _selectedState;
  String? _selectedLGA;
  
  final List<Map<String, dynamic>> _states = [
    {'label': 'Abia', 'value': 'abia'},
    {'label': 'Adamawa', 'value': 'adamawa'},
    {'label': 'Akwa Ibom', 'value': 'akwa_ibom'},
    {'label': 'Anambra', 'value': 'anambra'},
    {'label': 'Bauchi', 'value': 'bauchi'},
    {'label': 'Bayelsa', 'value': 'bayelsa'},
    {'label': 'Benue', 'value': 'benue'},
    {'label': 'Borno', 'value': 'borno'},
    {'label': 'Cross River', 'value': 'cross_river'},
    {'label': 'Delta', 'value': 'delta'},
    {'label': 'Ebonyi', 'value': 'ebonyi'},
    {'label': 'Edo', 'value': 'edo'},
    {'label': 'Ekiti', 'value': 'ekiti'},
    {'label': 'Enugu', 'value': 'enugu'},
    {'label': 'Gombe', 'value': 'gombe'},
    {'label': 'Imo', 'value': 'imo'},
    {'label': 'Jigawa', 'value': 'jigawa'},
    {'label': 'Kaduna', 'value': 'kaduna'},
    {'label': 'Kano', 'value': 'kano'},
    {'label': 'Katsina', 'value': 'katsina'},
    {'label': 'Kebbi', 'value': 'kebbi'},
    {'label': 'Kogi', 'value': 'kogi'},
    {'label': 'Kwara', 'value': 'kwara'},
    {'label': 'Lagos', 'value': 'lagos'},
    {'label': 'Nasarawa', 'value': 'nasarawa'},
    {'label': 'Niger', 'value': 'niger'},
    {'label': 'Ogun', 'value': 'ogun'},
    {'label': 'Ondo', 'value': 'ondo'},
    {'label': 'Osun', 'value': 'osun'},
    {'label': 'Oyo', 'value': 'oyo'},
    {'label': 'Plateau', 'value': 'plateau'},
    {'label': 'Rivers', 'value': 'rivers'},
    {'label': 'Sokoto', 'value': 'sokoto'},
    {'label': 'Taraba', 'value': 'taraba'},
    {'label': 'Yobe', 'value': 'yobe'},
    {'label': 'Zamfara', 'value': 'zamfara'},
  ];

  final Map<String, List<Map<String, dynamic>>> _lgasByState = {
    'lagos': [
      {'label': 'Alimosho', 'value': 'alimosho'},
      {'label': 'Amuwo-Odofin', 'value': 'amuwo_odofin'},
      {'label': 'Apapa', 'value': 'apapa'},
      {'label': 'Badagry', 'value': 'badagry'},
      {'label': 'Epe', 'value': 'epe'},
      {'label': 'Eti-Osa', 'value': 'eti_osa'},
      {'label': 'Ibeju-Lekki', 'value': 'ibeju_lekki'},
      {'label': 'Ifako-Ijaye', 'value': 'ifako_ijaye'},
      {'label': 'Ikeja', 'value': 'ikeja'},
      {'label': 'Ikorodu', 'value': 'ikorodu'},
      {'label': 'Kosofe', 'value': 'kosofe'},
      {'label': 'Lagos Island', 'value': 'lagos_island'},
      {'label': 'Lagos Mainland', 'value': 'lagos_mainland'},
      {'label': 'Mushin', 'value': 'mushin'},
      {'label': 'Ojo', 'value': 'ojo'},
      {'label': 'Shomolu', 'value': 'shomolu'},
      {'label': 'Surulere', 'value': 'surulere'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _validateAndContinue() {
    if (_addressController.text.isEmpty) {
      _showError('Please enter your residential address');
      return;
    }

    if (_cityController.text.isEmpty) {
      _showError('Please enter your city');
      return;
    }

    if (_selectedState == null) {
      _showError('Please select your state');
      return;
    }

    if (_selectedLGA == null) {
      _showError('Please select your local government area');
      return;
    }

    ref.read(kycProvider.notifier).updateAddress(
      residentialAddress: _addressController.text,
      city: _cityController.text,
      stateValue: _selectedState!,
      country: null,
    );

    Navigator.of(context).pushNamed('/kyc-employment');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: CoopvestColors.error,
      ),
    );
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.iconPrimary),
          onPressed: _goBack,
        ),
        title: Text(
          'Personal Details',
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
                  _buildProgressStep(3, true),
                  _buildProgressLine(3),
                  _buildProgressStep(4, true),
                ],
              ),
              const SizedBox(height: 32),

              // Header
              Text(
                'Where Do You Live?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your residential information for verification purposes',
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 24),

              // Residential Address
              AppTextField(
                label: 'Residential Address *',
                hint: 'Enter your full address',
                controller: _addressController,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),

              // City
              AppTextField(
                label: 'City *',
                hint: 'Enter your city',
                controller: _cityController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              
              const SizedBox(height: 16),

              // State Selection
              AppDropdown<String>(
                label: 'State *',
                hint: 'Select your state',
                value: _selectedState,
                items: _states.map((state) {
                  return DropdownMenuItem<String>(
                    value: state['value'] as String?,
                    child: Text(state['label'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedState = value;
                    _selectedLGA = null;
                  });
                },
              ),
              
              const SizedBox(height: 16),

              // LGA Selection
              if (_selectedState != null)
                AppDropdown<String>(
                  label: 'Local Government Area (LGA) *',
                  hint: 'Select your LGA',
                  value: _selectedLGA,
                  items: (_lgasByState[_selectedState] ?? []).map((lga) {
                    return DropdownMenuItem<String>(
                      value: lga['value'] as String?,
                      child: Text(lga['label'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLGA = value;
                    });
                  },
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

  Widget _buildProgressStep(int step, bool isPending) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isPending ? context.dividerColor : CoopvestColors.primary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isPending ? context.textSecondary : Colors.white,
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
