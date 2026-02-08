import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../presentation/providers/kyc_provider.dart';
import '../../../presentation/widgets/common/buttons.dart';
import '../../../presentation/widgets/common/cards.dart';

/// KYC Selfie Capture Screen
class KYCSelfieScreen extends ConsumerStatefulWidget {
  const KYCSelfieScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<KYCSelfieScreen> createState() => _KYCSelfieScreenState();
}

class _KYCSelfieScreenState extends ConsumerState<KYCSelfieScreen> {
  String? _selfieImagePath;
  bool _isCapturing = false;
  bool _showGuidelines = true;

  @override
  void initState() {
    super.initState();
    // Auto-hide guidelines after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showGuidelines = false;
        });
      }
    });
  }

  Future<void> _captureSelfie() async {
    setState(() {
      _isCapturing = true;
      _showGuidelines = false;
    });

    try {
      // In production, implement camera integration
      // For demo, simulate selfie capture
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _selfieImagePath = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _isCapturing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selfie captured successfully'),
          backgroundColor: CoopvestColors.success,
        ),
      );
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture selfie: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    }
  }

  Future<void> _retakeSelfie() async {
    setState(() {
      _selfieImagePath = null;
      _showGuidelines = true;
    });
    
    // Auto-hide guidelines again
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showGuidelines = false;
        });
      }
    });
  }

  void _validateAndSubmit() {
    if (_selfieImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a selfie'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    // Update KYC state
    ref.read(kycProvider.notifier).updateSelfie(_selfieImagePath!);

    // Submit KYC
    _submitKYC();
  }

  Future<void> _submitKYC() async {
    try {
      await ref.read(kycProvider.notifier).submitKYC();
      
      if (mounted) {
        // Navigate to Bank Info screen (for Google and manual users)
        Navigator.of(context).pushReplacementNamed('/kyc-bank-info');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit KYC: $e'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    }
  }

  void _goBack() {
    ref.read(kycProvider.notifier).previousStep();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
        title: Text(
          'Take Selfie',
          style: CoopvestTypography.headlineLarge.copyWith(
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera Preview / Selfie Display
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  // Camera Preview Placeholder
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.grey[900],
                    child: _selfieImagePath == null
                        ? _buildCameraPreview()
                        : _buildSelfiePreview(),
                  ),
                  
                  // Guidelines Overlay
                  if (_showGuidelines && _selfieImagePath == null)
                    _buildGuidelinesOverlay(),
                  
                  // Face Frame Guide
                  if (!_showGuidelines && _selfieImagePath == null)
                    _buildFaceFrameGuide(),
                ],
              ),
            ),

            // Bottom Controls
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Status Text
                  if (_isCapturing)
                    const Text(
                      'Capturing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    )
                  else if (_selfieImagePath == null)
                    const Text(
                      'Position your face in the frame',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle, color: CoopvestColors.success),
                        SizedBox(width: 8),
                        Text(
                          'Selfie captured successfully',
                          style: TextStyle(
                            color: CoopvestColors.success,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 24),

                  // Capture/Retake Button
                  if (_selfieImagePath == null)
                    _isCapturing
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Center(
                            child: GestureDetector(
                              onTap: _captureSelfie,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: CoopvestColors.primary,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Retake',
                            onPressed: _retakeSelfie,
                            textStyle: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Submit',
                            onPressed: _validateAndSubmit,
                            isEnabled: !ref.watch(kycProvider).isSubmitting,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Help Link
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showGuidelines = !_showGuidelines;
                      });
                    },
                    child: Text(
                      _showGuidelines ? 'Hide Guidelines' : 'Show Guidelines',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            color: Colors.grey[700],
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            'Camera Preview',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfiePreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            color: Colors.grey[700],
            size: 80,
          ),
          const SizedBox(height: 16),
          Text(
            'Selfie Captured',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.black.withAlpha((255 * 0.5).toInt()),
          child: Center(
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((255 * 0.8).toInt()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CoopvestColors.primary),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lightbulb, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Selfie Guidelines',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildGuidelineItem(Icons.check, 'Your full face is visible'),
                  _buildGuidelineItem(Icons.check, 'Good lighting on your face'),
                  _buildGuidelineItem(Icons.check, 'Plain background behind you'),
                  _buildGuidelineItem(Icons.check, 'No sunglasses or hats'),
                  _buildGuidelineItem(Icons.check, 'Face clearly visible (not blurred)'),
                  const SizedBox(height: 16),
                  const Text(
                    'This helps us verify your identity securely',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceFrameGuide() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: FaceFramePainter(),
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: CoopvestColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Face Frame Painter for selfie guide
class FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = CoopvestColors.primary.withAlpha((255 * 0.5).toInt())
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw face guide oval
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 40),
      width: 200,
      height: 260,
    );
    canvas.drawOval(ovalRect, guidePaint);

    // Draw corner markers
    final cornerLength = 30.0;
    
    // Top-left corner
    _drawCorner(canvas, Offset(40, 80), cornerLength, guidePaint);
    
    // Top-right corner
    _drawCorner(canvas, Offset(size.width - 40, 80), cornerLength, guidePaint);
    
    // Bottom-left corner
    _drawCorner(canvas, Offset(40, size.height - 120), cornerLength, guidePaint, mirrorY: true);
    
    // Bottom-right corner
    _drawCorner(
      canvas,
      Offset(size.width - 40, size.height - 120),
      cornerLength,
      guidePaint,
      mirrorX: true,
      mirrorY: true,
    );

    // Draw instruction text
    final textStyle = TextStyle(
      color: Colors.white.withAlpha((255 * 0.7).toInt()),
      fontSize: 14,
    );
    final textSpan = TextSpan(text: 'Position your face here', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height - 80,
      ),
    );
  }

  void _drawCorner(
    Canvas canvas,
    Offset position,
    double length,
    Paint paint, {
    bool mirrorX = false,
    bool mirrorY = false,
  }) {
    final startX = mirrorX ? position.dx - length : position.dx + length;
    final startY = position.dy;
    
    final endX = position.dx;
    final endY = mirrorY ? position.dy - length : position.dy + length;
    
    // Horizontal line
    canvas.drawLine(
      Offset(startX, startY),
      position,
      paint,
    );
    
    // Vertical line
    canvas.drawLine(
      position,
      Offset(endX, endY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// KYC Selfie Success Screen
class KYCSelfieSuccessScreen extends StatelessWidget {
  const KYCSelfieSuccessScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: CoopvestColors.success.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: CoopvestColors.success,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'KYC Submitted Successfully!',
                textAlign: TextAlign.center,
                style: CoopvestTypography.displaySmall.copyWith(
                  color: CoopvestColors.darkGray,
                ),
              ),
              const SizedBox(height: 16),

              // Message
              Text(
                'Your identity verification has been submitted. Our team will review your documents within 24-48 hours.',
                textAlign: TextAlign.center,
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.mediumGray,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // Info Card
              AppCard(
                child: Column(
                  children: [
                    _buildInfoRow(Icons.access_time, 'Review Time', '24-48 hours'),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.notifications, 'Notifications', 'Email & Push'),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.verified, 'Status', 'Under Review'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Next Steps
              AppCard(
                backgroundColor: CoopvestColors.primary.withAlpha((255 * 0.05).toInt()),
                border: Border.all(color: CoopvestColors.primary.withAlpha((255 * 0.2).toInt())),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'While you wait:',
                      style: CoopvestTypography.labelLarge.copyWith(
                        color: CoopvestColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNextStep('1', 'Explore investment opportunities'),
                    const SizedBox(height: 8),
                    _buildNextStep('2', 'Set up your biometric login'),
                    const SizedBox(height: 8),
                    _buildNextStep('3', 'Make your first contribution'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Go to Dashboard Button
              PrimaryButton(
                label: 'Go to Dashboard',
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: CoopvestColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CoopvestTypography.bodySmall.copyWith(
                  color: CoopvestColors.mediumGray,
                ),
              ),
              Text(
                value,
                style: CoopvestTypography.bodyMedium.copyWith(
                  color: CoopvestColors.darkGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: CoopvestColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: CoopvestTypography.bodySmall.copyWith(
            color: CoopvestColors.darkGray,
          ),
        ),
      ],
    );
  }
}