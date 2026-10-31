import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/document_viewer_dialog.dart';
import '../../profile/screens/driver_profile_screen.dart';
import '../providers/auth_provider.dart';
import 'phone_login_screen.dart';

class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key});

  @override
  ConsumerState<DocumentUploadScreen> createState() => _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  // Document keys and human-readable names
  final List<Map<String, String>> _requiredDocs = [
    {
      'key': 'driving_license_front',
      'title': 'Driving Licence (Front)',
      'subtitle': 'Commercial heavy/medium transport category',
      'icon': 'badge',
    },
    {
      'key': 'driving_license_back',
      'title': 'Driving Licence (Back)',
      'subtitle': 'Authorizations and endorsements page',
      'icon': 'badge',
    },
    {
      'key': 'vehicle_registration',
      'title': 'Vehicle Registration (RC)',
      'subtitle': 'Official vehicle fitness certificate',
      'icon': 'car',
    },
    {
      'key': 'ambulance_permit',
      'title': 'Ambulance Operational Permit',
      'subtitle': 'Health authority / Regional Transport permit',
      'icon': 'permit',
    },
    {
      'key': 'insurance_policy',
      'title': 'Commercial Vehicle Insurance',
      'subtitle': 'Valid third party and comprehensive cover',
      'icon': 'insurance',
    },
    {
      'key': 'commercial_driver_badge',
      'title': 'Commercial Driver Badge / First Aid Cert',
      'subtitle': 'Certified emergency responder badge',
      'icon': 'badge',
    },
  ];

  final Map<String, File?> _selectedFiles = {};
  final Map<String, bool> _uploading = {};
  final Map<String, bool> _uploaded = {};
  final Map<String, String> _savedPaths = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final storage = ref.read(storageServiceProvider);
      final paths = await storage.getAllDocumentImagePaths();
      if (mounted && paths.isNotEmpty) {
        setState(() {
          _savedPaths.addAll(paths);
          for (final key in paths.keys) {
            _uploaded[key] = true;
          }
        });
      }
    });
  }

  Future<void> _pickAndUpload(String docKey) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.ambulanceTeal),
              title: const Text('Take Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                if (picked != null) _processFile(docKey, File(picked.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.ambulanceTeal),
              title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked != null) _processFile(docKey, File(picked.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processFile(String docKey, File file) async {
    setState(() {
      _selectedFiles[docKey] = file;
      _uploading[docKey] = true;
    });

    final success = await ref.read(authNotifierProvider.notifier).uploadDocument(file, docKey);

    setState(() {
      _uploading[docKey] = false;
      if (success) {
        _uploaded[docKey] = true;
        _savedPaths[docKey] = file.path;
      }
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusGreen,
          content: Text('Document uploaded successfully to server'),
        ),
      );
    }
  }

  void _finishUploadFlow() {
    final driver = ref.read(currentDriverProvider);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(initialPhone: driver?.phone),
      ),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.statusGreen,
        content: Text('Registration & documents submitted! Please login with your registered mobile number.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance Document Upload'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_rounded, color: AppColors.ambulanceTeal),
            tooltip: 'Driver Profile',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Documents',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please upload clear scans or photographs of the required certificates. Administrative verification requires valid documentation.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 16),

                    // Document Cards
                    ..._requiredDocs.map((doc) {
                      final key = doc['key']!;
                      final isUploading = _uploading[key] ?? false;
                      final isUploaded = _uploaded[key] ?? (driver?.documentsUploaded[key] ?? false);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUploaded ? AppColors.statusGreen : AppColors.borderDark,
                            width: isUploaded ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isUploaded ? const Color(0x2206D6A0) : AppColors.cardDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isUploaded ? Icons.check_circle_rounded : Icons.description_outlined,
                                color: isUploaded ? AppColors.statusGreen : AppColors.ambulanceTeal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc['title']!,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    doc['subtitle']!,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  if (isUploaded) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Uploaded & Pending Audit',
                                      style: TextStyle(
                                        color: AppColors.statusGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isUploading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.ambulanceTeal),
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isUploaded)
                                    IconButton(
                                      icon: const Icon(Icons.visibility_rounded, color: AppColors.ambulanceTeal),
                                      tooltip: 'View Uploaded Document Image',
                                      onPressed: () {
                                        final path = _selectedFiles[key]?.path ?? _savedPaths[key];
                                        DocumentViewerDialog.show(
                                          context,
                                          title: doc['title']!,
                                          documentKey: key,
                                          imagePath: path,
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      isUploaded ? Icons.replay_rounded : Icons.file_upload_outlined,
                                      color: isUploaded ? AppColors.textSecondary : AppColors.ambulanceTeal,
                                    ),
                                    tooltip: isUploaded ? 'Replace Document' : 'Upload Document',
                                    onPressed: () => _pickAndUpload(key),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Bottom action container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(top: BorderSide(color: AppColors.borderDark)),
              ),
              child: Column(
                children: [
                  CustomButton(
                    label: 'Submit for Admin Approval',
                    icon: Icons.shield_rounded,
                    onPressed: _finishUploadFlow,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
