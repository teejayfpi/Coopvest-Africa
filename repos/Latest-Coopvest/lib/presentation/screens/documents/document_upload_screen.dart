import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../config/theme_config.dart';
import '../../../config/theme_extension.dart';
import '../../../core/extensions/number_extensions.dart';
import '../../../data/models/document_models.dart';
import '../../../presentation/providers/document_provider.dart';
import '../../../presentation/widgets/common/cards.dart';
import '../../../presentation/widgets/common/loading.dart';

/// Document Upload Screen - For KYC document submission
class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  File? _selectedFile;
  String _selectedDocumentType = 'other';
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(documentProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.scaffoldBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Document Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CoopvestColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: CoopvestColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a document first'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a document name'),
          backgroundColor: CoopvestColors.error,
        ),
      );
      return;
    }

    final success = await ref.read(documentProvider.notifier).uploadDocument(
          file: _selectedFile!,
          documentType: _selectedDocumentType,
          name: _nameController.text,
        );

    if (success && mounted) {
      setState(() {
        _selectedFile = null;
        _nameController.clear();
        _selectedDocumentType = 'other';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully'),
          backgroundColor: CoopvestColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(documentProvider).uploadError ?? 'Upload failed'),
          backgroundColor: CoopvestColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);
    final kycStatus = state.kycStatus;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Documents'),
        elevation: 0,
        actions: [
          if (state.pendingCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CoopvestColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.pendingCount} pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: CoopvestColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // KYC Progress Card
          _buildKycProgressCard(kycStatus),
          // Upload Section
          _buildUploadSection(state),
          const SizedBox(height: 16),
          // Documents List
          Expanded(
            child: state.isLoading
                ? const LoadingWidget()
                : _buildDocumentsList(state.documents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadDialog(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload New'),
        backgroundColor: CoopvestColors.primary,
      ),
    );
  }

  Widget _buildKycProgressCard(Map<String, dynamic> kycStatus) {
    final isComplete = kycStatus['isComplete'] as bool? ?? false;
    final submitted = kycStatus['submittedCount'] as int? ?? 0;
    final approved = kycStatus['approvedCount'] as int? ?? 0;
    final required = kycStatus['requiredCount'] as int? ?? 0;
    final missing = List<String>.from(kycStatus['missingTypes'] ?? []);

    final double progress = required > 0 ? approved / required : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isComplete
              ? [
                  CoopvestColors.success.withOpacity(0.1),
                  CoopvestColors.success.withOpacity(0.05),
                ]
              : [
                  CoopvestColors.primary.withOpacity(0.1),
                  CoopvestColors.primary.withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? CoopvestColors.success.withOpacity(0.3)
              : CoopvestColors.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.verified : Icons.verified_user,
                color: isComplete ? CoopvestColors.success : CoopvestColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete ? 'KYC Complete' : 'KYC Verification',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isComplete
                          ? 'Your verification is complete'
                          : '$approved/$required documents approved',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isComplete ? CoopvestColors.success : CoopvestColors.warning)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isComplete ? 'Verified' : 'In Progress',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? CoopvestColors.success : CoopvestColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  (isComplete ? CoopvestColors.success : CoopvestColors.primary)
                      .withOpacity(0.1),
              valueColor:
                  AlwaysStoppedAnimation(isComplete ? CoopvestColors.success : CoopvestColors.primary),
            ),
          ),
          if (!isComplete && missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Missing: ${missing.map((e) => DocumentType.getByValue(e).label).join(', ')}',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadSection(DocumentState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Document',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // File Picker
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selectedFile != null
                      ? CoopvestColors.success
                      : context.dividerColor,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _selectedFile != null
                    ? CoopvestColors.success.withOpacity(0.05)
                    : context.secondaryCardBackground.withOpacity(0.5),
              ),
              child: _selectedFile != null
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CoopvestColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              const Icon(Icons.check_circle, color: CoopvestColors.success),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'File Selected',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                              ),
                              Text(
                                _selectedFile!.path.split('/').last,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _selectedFile = null),
                          icon: Icon(Icons.close, color: context.textSecondary),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: context.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to select document',
                          style: TextStyle(
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPG, PNG, PDF (max 10MB)',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Document Type Dropdown
          DropdownButtonFormField<String>(
            value: _selectedDocumentType,
            decoration: const InputDecoration(
              labelText: 'Document Type',
              border: OutlineInputBorder(),
            ),
            items: DocumentType.allTypes.map((type) {
              return DropdownMenuItem(
                value: type.value,
                child: Row(
                  children: [
                    Icon(_getIconForType(type.icon), size: 20),
                    const SizedBox(width: 8),
                    Text(type.label),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedDocumentType = value ?? 'other';
              });
            },
          ),
          const SizedBox(height: 16),
          // Document Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Document Name',
              hintText: 'e.g., My National ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          // Upload Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isUploading ? null : _uploadDocument,
              icon: state.isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.upload),
              label: state.isUploading
                  ? const Text('Uploading...')
                  : const Text('Upload Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoopvestColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: context.scaffoldBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: DocumentUploadForm()),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList(List<Document> documents) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              color: context.textSecondary,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No Documents',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your KYC documents to get verified',
              style: TextStyle(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final document = documents[index];
        return _buildDocumentCard(document);
      },
    );
  }

  Widget _buildDocumentCard(Document document) {
    final statusColor = document.isApproved
        ? CoopvestColors.success
        : document.isRejected
            ? CoopvestColors.error
            : CoopvestColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getDocumentIcon(document.type),
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DocumentType.getByValue(document.type).label,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(document.uploadedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    document.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                if (document.isRejected && document.reviewNotes != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 150,
                    child: Text(
                      document.reviewNotes!,
                      style: TextStyle(
                        fontSize: 11,
                        color: CoopvestColors.error,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'id_card':
        return Icons.badge;
      case 'passport':
        return Icons.flight;
      case 'drivers_license':
        return Icons.directions_car;
      case 'voters_card':
        return Icons.how_to_vote;
      case 'utility_bill':
        return Icons.electric_bolt;
      case 'bank_statement':
        return Icons.account_balance;
      case 'signature':
        return Icons.draw;
      default:
        return Icons.description;
    }
  }

  IconData _getIconForType(String iconName) {
    switch (iconName) {
      case 'badge':
        return Icons.badge;
      case 'flight':
        return Icons.flight;
      case 'directions_car':
        return Icons.directions_car;
      case 'how_to_vote':
        return Icons.how_to_vote;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'account_balance':
        return Icons.account_balance;
      case 'draw':
        return Icons.draw;
      default:
        return Icons.description;
    }
  }
}

/// Separate widget for upload form in modal
class DocumentUploadForm extends ConsumerStatefulWidget {
  const DocumentUploadForm({super.key});

  @override
  ConsumerState<DocumentUploadForm> createState() => _DocumentUploadFormState();
}

class _DocumentUploadFormState extends ConsumerState<DocumentUploadForm> {
  File? _selectedFile;
  String _selectedDocumentType = 'other';
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.scaffoldBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Document Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.camera);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CoopvestColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: CoopvestColors.primary),
                          SizedBox(height: 8),
                          Text('Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _pickImage(ImageSource.gallery);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CoopvestColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.photo_library, size: 40, color: CoopvestColors.primary),
                          SizedBox(height: 8),
                          Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Future<void> _uploadDocument() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document first')),
      );
      return;
    }

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a document name')),
      );
      return;
    }

    final stateBefore = ref.read(documentProvider);
    if (stateBefore.isUploading) return;

    final success = await ref.read(documentProvider.notifier).uploadDocument(
          file: _selectedFile!,
          documentType: _selectedDocumentType,
          name: _nameController.text,
        );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded successfully'),
          backgroundColor: CoopvestColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Upload Document'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File Picker
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedFile != null
                        ? CoopvestColors.success
                        : context.dividerColor,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _selectedFile != null
                      ? CoopvestColors.success.withOpacity(0.05)
                      : context.secondaryCardBackground.withOpacity(0.5),
                ),
                child: _selectedFile != null
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: CoopvestColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check_circle, color: CoopvestColors.success),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('File Selected',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  _selectedFile!.path.split('/').last,
                                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Icon(Icons.cloud_upload_outlined,
                              size: 48, color: context.textSecondary),
                          const SizedBox(height: 12),
                          const Text('Tap to select document',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('JPG, PNG, PDF (max 10MB)',
                              style: TextStyle(
                                  fontSize: 12, color: context.textSecondary.withOpacity(0.7))),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // Document Type
            DropdownButtonFormField<String>(
              value: _selectedDocumentType,
              decoration: const InputDecoration(
                labelText: 'Document Type',
                border: OutlineInputBorder(),
              ),
              items: DocumentType.allTypes.map((type) {
                return DropdownMenuItem(
                  value: type.value,
                  child: Row(
                    children: [
                      Icon(_getIconForType(type.icon), size: 20),
                      const SizedBox(width: 8),
                      Text(type.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDocumentType = value ?? 'other';
                });
              },
            ),
            const SizedBox(height: 16),
            // Document Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Document Name',
                hintText: 'e.g., My National ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              DocumentType.getByValue(_selectedDocumentType).description,
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            const SizedBox(height: 24),
            // Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isUploading ? null : _uploadDocument,
                icon: state.isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.upload),
                label: state.isUploading
                    ? const Text('Uploading...')
                    : const Text('Upload Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CoopvestColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String iconName) {
    switch (iconName) {
      case 'badge':
        return Icons.badge;
      case 'flight':
        return Icons.flight;
      case 'directions_car':
        return Icons.directions_car;
      case 'how_to_vote':
        return Icons.how_to_vote;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'account_balance':
        return Icons.account_balance;
      case 'draw':
        return Icons.draw;
      default:
        return Icons.description;
    }
  }
}
