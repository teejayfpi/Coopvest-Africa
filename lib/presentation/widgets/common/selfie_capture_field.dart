import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../common/buttons.dart';

/// Selfie capture control, reused by onboarding and KYC.
///
/// This was pulled out of the standalone KYC selfie screen so the same control
/// (and the same camera/gallery behaviour) can be shown during registration,
/// where the member is already uploading their details. Keeping one widget
/// means the two entry points cannot drift apart.
///
/// The control only *captures*: it hands the picked [File] back to the caller,
/// which decides where to store/upload it. Onboarding keeps the local path and
/// the KYC submit step uploads it (see `KYCCubit.submitKYC`, which swaps local
/// paths for server URLs before submitting).
class SelfieCaptureField extends StatefulWidget {
  /// Existing image, if one was already chosen.
  final File? file;

  /// Called with the newly picked file.
  final ValueChanged<File> onCaptured;

  /// Called when the member clears the chosen image.
  final VoidCallback? onCleared;

  const SelfieCaptureField({
    super.key,
    this.file,
    required this.onCaptured,
    this.onCleared,
  });

  @override
  State<SelfieCaptureField> createState() => _SelfieCaptureFieldState();
}

class _SelfieCaptureFieldState extends State<SelfieCaptureField> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        // Front camera is the sensible default for a selfie; gallery remains
        // available as a fallback.
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo == null) return;
      widget.onCaptured(File(photo.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get that photo: $e'),
            backgroundColor: CoopvestColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (file != null)
          // Preview with a way to retake, so a bad photo is never locked in.
          ClipRRect(
            borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Image.file(
                  file,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        widget.onCleared?.call();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: CoopvestColors.iconTintGreen,
              borderRadius: BorderRadius.circular(CoopvestShape.cardRadius),
              border: Border.all(color: CoopvestColors.cardBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 44,
                  color: context.textSecondary,
                ),
                const SizedBox(height: CoopvestShape.gapSm),
                Text(
                  'Add a clear photo of your face',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: CoopvestShape.gapXs),
                Text(
                  'Face the light and remove hats or glasses',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ],
            ),
          ),
        const SizedBox(height: CoopvestShape.gapMd),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: file == null ? 'Take photo' : 'Retake',
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
              ),
            ),
            const SizedBox(width: CoopvestShape.gapSm),
            Expanded(
              child: SecondaryButton(
                label: 'Choose from gallery',
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: CoopvestShape.gapSm),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }
}