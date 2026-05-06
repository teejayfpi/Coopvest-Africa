import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
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
    Future.delayed(const Duration(seconds: 5), () { if (mounted) setState(() => _showGuidelines = false); });
  }

  Future<void> _captureSelfie() async {
    setState(() { _isCapturing = true; _showGuidelines = false; });
    try {
      await Future.delayed(const Duration(seconds: 2));
      setState(() { _selfieImagePath = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg'; _isCapturing = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selfie captured successfully'), backgroundColor: CoopvestColors.success));
    } catch (e) {
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to capture selfie: $e'), backgroundColor: CoopvestColors.error));
    }
  }

  void _validateAndSubmit() {
    if (_selfieImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please capture a selfie'), backgroundColor: CoopvestColors.error));
      return;
    }
    ref.read(kycProvider.notifier).updateSelfie(_selfieImagePath!);
    _submitKYC();
  }

  Future<void> _submitKYC() async {
    try {
      await ref.read(kycProvider.notifier).submitKYC();
      if (mounted) Navigator.of(context).pushReplacementNamed('/kyc-bank-info');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit KYC: $e'), backgroundColor: CoopvestColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(elevation: 0, backgroundColor: Colors.black, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()), title: const Text('Take Selfie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(width: double.infinity, height: double.infinity, color: Colors.grey[900], child: _selfieImagePath == null ? _buildCameraPreview() : _buildSelfiePreview()),
                  if (_showGuidelines && _selfieImagePath == null) _buildGuidelinesOverlay(),
                  if (!_showGuidelines && _selfieImagePath == null) _buildFaceFrameGuide(),
                ],
              ),
            ),
            Container(
              color: Colors.black, padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_isCapturing) const Text('Capturing...', style: TextStyle(color: Colors.white, fontSize: 16))
                  else if (_selfieImagePath == null) const Text('Position your face in the frame', style: TextStyle(color: Colors.white70, fontSize: 14))
                  else const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: CoopvestColors.success), SizedBox(width: 8), Text('Selfie captured successfully', style: TextStyle(color: CoopvestColors.success, fontSize: 14))]),
                  const SizedBox(height: 24),
                  if (_selfieImagePath == null)
                    _isCapturing ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)) : Center(child: GestureDetector(onTap: _captureSelfie, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white, width: 4)), child: const Icon(Icons.camera_alt, color: CoopvestColors.primary, size: 40))))
                  else
                    Row(children: [Expanded(child: SecondaryButton(label: 'Retake', onPressed: () => setState(() { _selfieImagePath = null; _showGuidelines = true; }), textStyle: const TextStyle(color: Colors.white))), const SizedBox(width: 16), Expanded(child: PrimaryButton(label: 'Submit', onPressed: _validateAndSubmit, isEnabled: !ref.watch(kycProvider).isSubmitting))]),
                  const SizedBox(height: 16),
                  TextButton(onPressed: () => setState(() => _showGuidelines = !_showGuidelines), child: Text(_showGuidelines ? 'Hide Guidelines' : 'Show Guidelines', style: const TextStyle(color: Colors.white70, fontSize: 14))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_outline, color: Colors.grey[700], size: 80), const SizedBox(height: 16), Text('Camera Preview', style: TextStyle(color: Colors.grey[600], fontSize: 14))]));
  Widget _buildSelfiePreview() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person, color: Colors.grey[700], size: 80), const SizedBox(height: 16), Text('Selfie Captured', style: TextStyle(color: Colors.grey[600], fontSize: 14))]));
  Widget _buildGuidelinesOverlay() => Container(color: Colors.black.withOpacity(0.7), padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Selfie Guidelines', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 24), _buildGuidelineItem(Icons.wb_sunny_outlined, 'Ensure good lighting'), _buildGuidelineItem(Icons.face_retouching_natural, 'Remove glasses or hats'), _buildGuidelineItem(Icons.center_focus_strong, 'Keep your face in the frame'), const SizedBox(height: 32), PrimaryButton(label: 'Got it', onPressed: () => setState(() => _showGuidelines = false), width: 120)]));
  Widget _buildGuidelineItem(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [Icon(icon, color: CoopvestColors.primary, size: 24), const SizedBox(width: 16), Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))]));
  Widget _buildFaceFrameGuide() => Center(child: Container(width: 280, height: 380, decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.5), width: 2), borderRadius: BorderRadius.circular(140))));
}
