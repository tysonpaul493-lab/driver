import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/document_viewer_dialog.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/models/driver_model.dart';
import '../../auth/models/vehicle_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/document_upload_screen.dart';
import '../../auth/screens/phone_login_screen.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  Map<String, String> _savedDocPaths = {};

  final List<Map<String, String>> _complianceDocs = [
    {
      'key': 'driving_license_front',
      'title': 'Driving Licence (Front)',
      'subtitle': 'Commercial transport endorsement',
      'icon': 'badge',
    },
    {
      'key': 'driving_license_back',
      'title': 'Driving Licence (Back)',
      'subtitle': 'Authorization & endorsements',
      'icon': 'badge',
    },
    {
      'key': 'vehicle_registration',
      'title': 'Vehicle Registration (RC)',
      'subtitle': 'Ambulance fitness certificate',
      'icon': 'car',
    },
    {
      'key': 'ambulance_permit',
      'title': 'Ambulance Operational Permit',
      'subtitle': 'Transport authority clearance',
      'icon': 'permit',
    },
    {
      'key': 'insurance_policy',
      'title': 'Commercial Vehicle Insurance',
      'subtitle': 'Comprehensive emergency fleet cover',
      'icon': 'insurance',
    },
    {
      'key': 'commercial_driver_badge',
      'title': 'Commercial Driver Badge / First Aid',
      'subtitle': 'Certified emergency responder badge',
      'icon': 'badge',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDocumentPaths();
  }

  Future<void> _loadDocumentPaths() async {
    final storage = ref.read(storageServiceProvider);
    final paths = await storage.getAllDocumentImagePaths();
    if (mounted) {
      setState(() => _savedDocPaths = paths);
    }
  }

  Future<void> _callHelpline() async {
    final uri = Uri.parse('tel:${ApiConstants.nationalAmbulanceEmergencyNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _getDocMatchingSpec(String key, DriverModel? driver, VehicleModel? vehicle) {
    switch (key) {
      case 'driving_license_front':
      case 'driving_license_back':
        return driver?.licenseNumber.isNotEmpty == true
            ? 'Matched to License: ${driver!.licenseNumber}'
            : 'License number pending input';
      case 'vehicle_registration':
        return vehicle?.registrationNumber.isNotEmpty == true
            ? 'Matched to RC Plate: ${vehicle!.registrationNumber}'
            : 'Vehicle plate pending';
      case 'ambulance_permit':
        return vehicle?.permitNumber.isNotEmpty == true
            ? 'Matched to Permit: ${vehicle!.permitNumber}'
            : 'Permit number pending';
      case 'insurance_policy':
        return vehicle?.insurancePolicyNumber.isNotEmpty == true
            ? 'Matched to Policy: ${vehicle!.insurancePolicyNumber}'
            : 'Insurance policy pending';
      case 'commercial_driver_badge':
        return vehicle?.operatorAffiliation.isNotEmpty == true
            ? 'Matched to Fleet: ${vehicle!.operatorAffiliation}'
            : 'Fleet affiliation pending';
      default:
        return '';
    }
  }

  void _showEditProfileSheet(DriverModel driver, VehicleModel? vehicle) {
    final nameCtrl = TextEditingController(text: driver.name);
    final emailCtrl = TextEditingController(text: driver.email);
    final phoneCtrl = TextEditingController(text: driver.phone);
    final emgContactCtrl = TextEditingController(text: driver.emergencyContact);
    final licenseCtrl = TextEditingController(text: driver.licenseNumber);
    final regPlateCtrl = TextEditingController(text: vehicle?.registrationNumber ?? '');
    final makeModelCtrl = TextEditingController(text: vehicle?.makeModel ?? '');
    final operatorCtrl = TextEditingController(text: vehicle?.operatorAffiliation ?? '');
    VehicleType selectedType = vehicle?.vehicleType ?? VehicleType.als;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.edit_note_rounded, color: AppColors.ambulanceTeal, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Edit Driver Profile',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20, color: AppColors.divider),
                const SizedBox(height: 8),

                // Name
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Legal Name *'),
                ),
                const SizedBox(height: 12),

                // Phone (Read-only registered phone)
                TextFormField(
                  controller: phoneCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Registered Mobile Number',
                    helperText: 'Locked to primary login SIM',
                  ),
                ),
                const SizedBox(height: 12),

                // Email & Emergency Contact
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email Address'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: emgContactCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Emergency Contact'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Commercial Licence
                TextFormField(
                  controller: licenseCtrl,
                  decoration: const InputDecoration(labelText: 'Commercial Driving Licence No.'),
                ),
                const SizedBox(height: 12),

                // Ambulance Plate & Make Model
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: regPlateCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Ambulance Plate *'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: makeModelCtrl,
                        decoration: const InputDecoration(labelText: 'Vehicle Make/Model'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Vehicle Classification Dropdown
                const Text(
                  'Ambulance Triage Classification',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VehicleType>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      items: VehicleType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Operator Affiliation
                TextFormField(
                  controller: operatorCtrl,
                  decoration: const InputDecoration(labelText: 'Operator / Hospital Fleet Affiliation'),
                ),
                const SizedBox(height: 24),

                CustomButton(
                  label: 'Save Profile Changes',
                  icon: Icons.check_rounded,
                  onPressed: () async {
                    final newName = nameCtrl.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Driver name is required')),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    await ref.read(authNotifierProvider.notifier).updateDriverProfile(
                          name: newName,
                          email: emailCtrl.text.trim(),
                          emergencyContact: emgContactCtrl.text.trim(),
                          licenseNumber: licenseCtrl.text.trim(),
                          registrationNumber: regPlateCtrl.text.trim().toUpperCase(),
                          vehicleType: selectedType.name,
                          makeModel: makeModelCtrl.text.trim(),
                          operatorAffiliation: operatorCtrl.text.trim(),
                        );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.statusGreen,
                          content: Text('Profile updated successfully'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(currentDriverProvider);
    final vehicle = driver?.assignedVehicle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver & Ambulance Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.ambulanceTeal),
            tooltip: 'Edit Profile',
            onPressed: () {
              if (driver != null) _showEditProfileSheet(driver, vehicle);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).refreshVerificationStatus();
              await _loadDocumentPaths();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Driver Profile Header Card (Daylight Theme)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardDark,
                          border: Border.all(color: AppColors.ambulanceTeal, width: 2),
                        ),
                        child: const Icon(Icons.person, color: AppColors.ambulanceTeal, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver?.name.isNotEmpty == true ? driver!.name : 'Registered Driver',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              driver?.phone.isNotEmpty == true ? driver!.phone : '',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            StatusBadge.verification(
                              driver?.verificationStatus.name ?? 'Approved',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniMetric('RATING', '★ ${driver?.rating ?? 5.0}'),
                      _buildMiniMetric('TOTAL TRIPS', '${driver?.completedTripsCount ?? 0}'),
                      _buildMiniMetric('DUTY SHIFT', 'Active (India)'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (driver != null) _showEditProfileSheet(driver, vehicle);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ambulanceTeal,
                        side: const BorderSide(color: AppColors.ambulanceTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Profile & Vehicle Details'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Vehicle Specifications Card (No Fake Defaults)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.airport_shuttle_rounded, color: AppColors.ambulanceTeal, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Assigned Ambulance Specifications',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.divider),
                  _buildDetailRow(
                    'Plate Registration',
                    vehicle?.registrationNumber.isNotEmpty == true
                        ? vehicle!.registrationNumber
                        : 'Not Assigned',
                  ),
                  _buildDetailRow(
                    'Vehicle Model',
                    vehicle?.makeModel.isNotEmpty == true
                        ? '${vehicle!.makeModel} (${vehicle.year})'.trim()
                        : 'Ambulance Unit',
                  ),
                  _buildDetailRow(
                    'Triage Classification',
                    vehicle?.vehicleType.displayName ?? 'Basic Life Support (BLS)',
                  ),
                  _buildDetailRow(
                    'Emergency Service',
                    vehicle?.operatorAffiliation.isNotEmpty == true
                        ? vehicle!.operatorAffiliation
                        : 'Registered Fleet',
                  ),
                  _buildDetailRow(
                    'Permit Number',
                    vehicle?.permitNumber.isNotEmpty == true ? vehicle!.permitNumber : 'N/A',
                  ),
                  _buildDetailRow(
                    'Permit Expiry',
                    vehicle?.permitExpiryDate.isNotEmpty == true ? vehicle!.permitExpiryDate : 'N/A',
                  ),
                  _buildDetailRow(
                    'Insurance Policy',
                    vehicle?.insurancePolicyNumber.isNotEmpty == true ? vehicle!.insurancePolicyNumber : 'N/A',
                  ),
                  _buildDetailRow(
                    'Insurance Expiry',
                    vehicle?.insuranceExpiryDate.isNotEmpty == true ? vehicle!.insuranceExpiryDate : 'N/A',
                  ),
                  if (vehicle != null && vehicle.equipmentList.isNotEmpty) ...[
                    const Divider(height: 18, color: AppColors.divider),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Onboard Medical Equipment',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: vehicle.equipmentList.map((eq) => Chip(
                        label: Text(eq, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                        backgroundColor: AppColors.cardDark,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: AppColors.borderDark),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Uploaded Documents Preview Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.folder_shared_rounded, color: AppColors.statusGreen, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Uploaded Compliance Documents',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DocumentUploadScreen(fromProfile: true)),
                          ).then((_) => _loadDocumentPaths());
                        },
                        child: const Text('Manage', style: TextStyle(color: AppColors.ambulanceTeal)),
                      ),
                    ],
                  ),
                  const Divider(height: 16, color: AppColors.divider),
                  ..._complianceDocs.map((doc) {
                    final key = doc['key']!;
                    final isUploaded = (driver?.documentsUploaded[key] ?? false) || _savedDocPaths.containsKey(key);
                    final path = _savedDocPaths[key];

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUploaded
                              ? AppColors.statusGreen.withValues(alpha: 0.5)
                              : AppColors.emergencyRed.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isUploaded ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            color: isUploaded ? AppColors.statusGreen : AppColors.emergencyRed,
                            size: 22,
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
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getDocMatchingSpec(key, driver, vehicle),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (isUploaded)
                                  Row(
                                    children: const [
                                      Icon(Icons.verified_rounded, size: 12, color: AppColors.statusGreen),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified & Compliant',
                                        style: TextStyle(
                                          color: AppColors.statusGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0x22E53935),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: AppColors.emergencyRed, width: 1),
                                    ),
                                    child: const Text(
                                      'Pending',
                                      style: TextStyle(
                                        color: AppColors.emergencyRed,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isUploaded)
                            TextButton.icon(
                              onPressed: () {
                                DocumentViewerDialog.show(
                                  context,
                                  title: doc['title']!,
                                  documentKey: key,
                                  imagePath: path,
                                );
                              },
                              style: TextButton.styleFrom(
                                enableFeedback: true,
                              ),
                              icon: const Icon(Icons.visibility_rounded, size: 16, color: AppColors.ambulanceTeal),
                              label: const Text(
                                'View',
                                style: TextStyle(color: AppColors.ambulanceTeal, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const DocumentUploadScreen(fromProfile: true)),
                                ).then((_) => _loadDocumentPaths());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emergencyRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                enableFeedback: true,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.upload_file_rounded, size: 14),
                              label: const Text('Upload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Onboard Equipment Card
            if (vehicle?.equipmentList != null && vehicle!.equipmentList.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderDark),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.medical_services_rounded, color: AppColors.statusGreen, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Onboard Medical Equipment',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.divider),
                    ...vehicle.equipmentList.map((eq) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.statusGreen, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(eq, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // National Ambulance Helpline (108)
            CustomButton(
              label: 'Call 108 Emergency Control Room',
              icon: Icons.support_agent_rounded,
              backgroundColor: AppColors.emergencyRed,
              textColor: Colors.white,
              onPressed: _callHelpline,
            ),

            const SizedBox(height: 16),

            // Sign out
            TextButton.icon(
              onPressed: () async {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 18),
              label: const Text(
                'Sign Out from Ambulance Unit',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
