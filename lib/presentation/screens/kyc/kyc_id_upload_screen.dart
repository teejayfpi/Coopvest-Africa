import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme_config.dart';
import '../../../data/models/kyc_models.dart';
import '../../../presentation/providers/kyc_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/inputs.dart';

/// KYC ID Upload Screen
class KYCIDUploadScreen extends ConsumerStatefulWidget {
  const KYCIDUploadScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KYCIDUploadScreen> createState() => _KYCIDUploadScreenState();
}

class _KYCIDUploadScreenState extends ConsumerState<KYCIDUploadScreen> {
  late TextEditingController _idNumberController;
  
  String? _selectedIDType;
  String? _idImagePath;
  
  final List<Map<String, dynamic>> _idTypes = IDTypes.types;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _idNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickIDImage() async {
    // Show bottom sheet to choose between camera and gallery
    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Image Source',
                style: CoopvestTypography.headlineSmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickFromCamera(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: CoopvestColors.veryLightGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.camera_alt,
                              color: CoopvestColors.primary,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Camera',
                              style: TextStyle(
                                color: CoopvestColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickFromGallery(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: CoopvestColors.veryLightGray,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.photo_library,
                              color: CoopvestColors.primary,
                              size: 48,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                color: CoopvestColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    Navigator.of(context).pop(); // Close the bottom sheet
    
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (photo != null && mounted) {
        setState(() {
          _idImagePath = photo.path;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID image captured successfully'),
            backgroundColor: CoopvestColors.success,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    Navigator.of(context).pop(); // Close the bottom sheet
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() {
          _idImagePath = image.path;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID image selected successfully'),
            backgroundColor: CoopvestColors.success,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to select image: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: CoopvestColors.error,
        ),
      );
    }
  }

  Future<void> _retakeIDImage() async {
    setState(() {
      _idImagePath = null;
    });
    await _pickIDImage();
  }

  void _validateAndContinue() {
    if (_selectedIDType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an ID type'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_idNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your ID number'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_idImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo of your ID'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    // Validate ID number format based on type
    final validationError = _validateIDNumber();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    // Update KYC state
    ref.read(kycProvider.notifier).updateIDDetails(
      idType: _selectedIDType!,
      idNumber: _idNumberController.text,
      idPhotoPath: _idImagePath,
    );

    // Navigate to next step
    Navigator.of(context).pushNamed('/kyc-selfie');
  }

  String? _validateIDNumber() {
    final idNumber = _idNumberController.text.trim();
    
    switch (_selectedIDType) {
      case 'national_id':
        // NIN should be 11 digits
        if (idNumber.length != 11 || !RegExp(r'^[0-9]{11}$').hasMatch(idNumber)) {
          return 'NIN should be 11 digits';
        }
        break;
      case 'drivers_license':
        // Driver's license format varies, basic validation
        if (idNumber.length < 7 || idNumber.length > 10) {
          return 'Invalid driver\'s license number';
        }
        break;
      case 'passport':
        // Passport is typically alphanumeric
        if (idNumber.length < 8 || idNumber.length > 12) {
          return 'Invalid passport number';
        }
        break;
      case 'voters_card':
        // Voter's card is typically alphanumeric
        if (idNumber.length < 10 || idNumber.length > 15) {
          return 'Invalid voter\'s card number';
        }
        break;
    }
    
    return null;
  }

  void _goBack() {
    ref.read(kycProvider.notifier).previousStep();
    Navigator.of(context).pop();
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
          onPressed: _goBack,
        ),
        title: Text(
          'ID Verification',
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
                  _buildProgressStep(2, true),
                  _buildProgressLine(2),
                  _buildProgressStep(3, false),
                ],
              ),
              const SizedBox(height: 32),

              // Header
              Text(
                'Upload Government-issued ID',
                style: CoopvestTypography.headlineSmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a clear photo of your valid government-issued identification document',
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
              const SizedBox(height: 24),

              // ID Type Selection
              Text(
                'Select ID Type *',
                style: CoopvestTypography.labelLarge.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _idTypes.map((idType) {
                  final isSelected = _selectedIDType == idType['value'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIDType = idType['value'] as String?;
                        _idNumberController.clear();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CoopvestColors.primary
                            : CoopvestColors.veryLightGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? CoopvestColors.primary
                              : CoopvestColors.lightGray,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIDTypeIcon(idType['value'] as String),
                            color: isSelected ? Colors.white : CoopvestColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            idType['label'] as String,
                            style: CoopvestTypography.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : CoopvestColors.darkGray,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // ID Number Input
              if (_selectedIDType != null)
                AppTextField(
                  label: '${IDTypes.getLabel(_selectedIDType!)} Number *',
                  hint: 'Enter your ${IDTypes.getLabel(_selectedIDType!)} number',
                  controller: _idNumberController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'ID number is required';
                    }
                    return null;
                  },
                ),
              
              if (_selectedIDType != null) const SizedBox(height: 24),

              // ID Image Upload
              Text(
                'Upload ID Photo *',
                style: CoopvestTypography.labelLarge.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              
              if (_idImagePath == null)
                // Upload Button
                GestureDetector(
                  onTap: _pickIDImage,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: CoopvestColors.veryLightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CoopvestColors.primary,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: CoopvestColors.primary.withAlpha((255 * 0.1).toInt()),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: CoopvestColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Take Photo of ID',
                          style: CoopvestTypography.labelLarge.copyWith(
                            color: CoopvestColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'or upload from gallery',
                          style: CoopvestTypography.bodySmall.copyWith(
                            color: CoopvestColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // ID Image Preview
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: CoopvestColors.veryLightGray,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CoopvestColors.success),
                        // Load actual ID image from local file path
                        image: _idImagePath != null
                            ? DecorationImage(
                                image: FileImage(File(_idImagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CoopvestColors.success,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Uploaded',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              
              if (_idImagePath != null) const SizedBox(height: 12),

              // Retake/Change Button
              if (_idImagePath != null)
                Center(
                  child: TextButton.icon(
                    onPressed: _retakeIDImage,
                    icon: const Icon(Icons.camera_alt, color: CoopvestColors.primary),
                    label: Text(
                      'Retake Photo',
                      style: CoopvestTypography.bodyMedium.copyWith(
                        color: CoopvestColors.primary,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Tips Card
              AppCard(
                backgroundColor: CoopvestColors.info.withAlpha((255 * 0.1).toInt()),
                border: Border.all(color: CoopvestColors.info.withAlpha((255 * 0.3).toInt())),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: CoopvestColors.info,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tips for a clear ID photo',
                          style: CoopvestTypography.labelLarge.copyWith(
                            color: CoopvestColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTip('Ensure all text is clearly visible and readable'),
                    _buildTip('Good lighting without glare or shadows'),
                    _buildTip('All corners of the ID should be visible'),
                    _buildTip('Avoid blurry or low-quality images'),
                    _buildTip('Do not cover any part of the ID'),
                  ],
                ),
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
    final isComplete = step < 2; // Steps 1 and 2 are complete
    return Expanded(
      child: Container(
        height: 2,
        color: isComplete ? CoopvestColors.primary : CoopvestColors.lightGray,
      ),
    );
  }

  IconData _getIDTypeIcon(String idType) {
    switch (idType) {
      case 'national_id':
        return Icons.badge;
      case 'drivers_license':
        return Icons.directions_car;
      case 'passport':
        return Icons.flight;
      case 'voters_card':
        return Icons.how_to_vote;
      case 'residence_permit':
        return Icons.home;
      default:
        return Icons.credit_card;
    }
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: CoopvestColors.info),
          ),
          Expanded(
            child: Text(
              tip,
              style: CoopvestTypography.bodySmall.copyWith(
                color: CoopvestColors.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
