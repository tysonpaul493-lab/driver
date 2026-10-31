import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../models/vehicle_model.dart';
import '../providers/auth_provider.dart';
import 'document_upload_screen.dart';

class DriverRegistrationScreen extends ConsumerStatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  ConsumerState<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends ConsumerState<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Driver details controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _licenseExpiryController = TextEditingController();

  // Vehicle details controllers
  final _ambulanceRegController = TextEditingController();
  final _makeModelController = TextEditingController();
  final _yearController = TextEditingController();
  VehicleType _selectedVehicleType = VehicleType.als;
  final _operatorAffiliationController = TextEditingController();
  final _permitNumberController = TextEditingController();
  final _permitExpiryController = TextEditingController();
  final _insuranceNumberController = TextEditingController();
  final _insuranceExpiryController = TextEditingController();

  // Equipment checklist (empty by default; user checks what is actually equipped)
  final Map<String, bool> _equipmentChecked = {
    'Oxygen Cylinder & Regulators': false,
    'Defibrillator / AED': false,
    'Transport Ventilator': false,
    'Suction Unit (Electric/Manual)': false,
    'Foldable Stretcher & Spine Board': false,
    'Emergency Trauma First Aid Kit': false,
    'Multipara Cardiac Monitor': false,
    'Cervical Collars & Splints': false,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _licenseNumberController.dispose();
    _licenseExpiryController.dispose();
    _ambulanceRegController.dispose();
    _makeModelController.dispose();
    _yearController.dispose();
    _operatorAffiliationController.dispose();
    _permitNumberController.dispose();
    _permitExpiryController.dispose();
    _insuranceNumberController.dispose();
    _insuranceExpiryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      controller.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all mandatory fields')),
      );
      return;
    }

    final selectedEquipment = _equipmentChecked.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final success = await ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          emergencyContact: _emergencyContactController.text.trim(),
          licenseNumber: _licenseNumberController.text.trim(),
          licenseExpiryDate: _licenseExpiryController.text.trim(),
          ambulanceRegNumber: _ambulanceRegController.text.trim().toUpperCase(),
          vehicleType: _selectedVehicleType.name,
          makeModel: _makeModelController.text.trim(),
          year: int.tryParse(_yearController.text.trim()) ?? 2024,
          equipmentList: selectedEquipment,
          operatorAffiliation: _operatorAffiliationController.text.trim(),
          permitNumber: _permitNumberController.text.trim(),
          permitExpiryDate: _permitExpiryController.text.trim(),
          insurancePolicyNumber: _insuranceNumberController.text.trim(),
          insuranceExpiryDate: _insuranceExpiryController.text.trim(),
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DocumentUploadScreen()),
      );
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ambulanceTeal, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ambulanceTeal,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver & Ambulance Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Register for Emergency Dispatch',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Submit your credentials and ambulance specifications. All submissions undergo administrative audit before activation.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                ),

                const SizedBox(height: 16),

                // 1. DRIVER DETAILS
                _buildSectionHeader('1. Driver Profile', Icons.person_outline_rounded),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Legal Name *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Mobile Number *'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyContactController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Emergency Contact *'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),

                // 2. DRIVING LICENCE
                _buildSectionHeader('2. Driving Licence', Icons.badge_outlined),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _licenseNumberController,
                        decoration: const InputDecoration(labelText: 'Commercial Licence No. *'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _licenseExpiryController,
                        readOnly: true,
                        onTap: () => _pickDate(_licenseExpiryController),
                        decoration: InputDecoration(
                          labelText: 'Expiry *',
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_rounded, size: 18),
                            onPressed: () => _pickDate(_licenseExpiryController),
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                // 3. AMBULANCE SPECIFICATION
                _buildSectionHeader('3. Ambulance Vehicle', Icons.airport_shuttle_rounded),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _ambulanceRegController,
                        decoration: const InputDecoration(labelText: 'Ambulance Reg Plate * (e.g. MH02AB1234)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Model Year *'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _makeModelController,
                  decoration: const InputDecoration(labelText: 'Make & Model *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Vehicle Type Dropdown
                const Text(
                  'Ambulance Triage Classification *',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VehicleType>(
                      value: _selectedVehicleType,
                      isExpanded: true,
                      dropdownColor: AppColors.surfaceDark,
                      items: VehicleType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.displayName,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedVehicleType = val);
                      },
                    ),
                  ),
                ),

                // 4. ONBOARD MEDICAL EQUIPMENT
                _buildSectionHeader('4. Onboard Equipment Inventory', Icons.medical_services_outlined),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Column(
                    children: _equipmentChecked.keys.map((item) {
                      return CheckboxListTile(
                        dense: true,
                        activeColor: AppColors.ambulanceTeal,
                        checkColor: Colors.white,
                        title: Text(item, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                        value: _equipmentChecked[item],
                        onChanged: (val) {
                          setState(() {
                            _equipmentChecked[item] = val ?? false;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),

                // 5. OPERATOR & PERMITS
                _buildSectionHeader('5. Operator Affiliation & Permits', Icons.verified_user_outlined),
                TextFormField(
                  controller: _operatorAffiliationController,
                  decoration: const InputDecoration(labelText: 'Operator / Hospital Affiliation *'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _permitNumberController,
                        decoration: const InputDecoration(labelText: 'Ambulance Permit No. *'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _permitExpiryController,
                        readOnly: true,
                        onTap: () => _pickDate(_permitExpiryController),
                        decoration: InputDecoration(
                          labelText: 'Permit Expiry *',
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_rounded, size: 18),
                            onPressed: () => _pickDate(_permitExpiryController),
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _insuranceNumberController,
                        decoration: const InputDecoration(labelText: 'Commercial Insurance No. *'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _insuranceExpiryController,
                        readOnly: true,
                        onTap: () => _pickDate(_insuranceExpiryController),
                        decoration: InputDecoration(
                          labelText: 'Policy Expiry *',
                          hintText: 'YYYY-MM-DD',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_rounded, size: 18),
                            onPressed: () => _pickDate(_insuranceExpiryController),
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: AppColors.emergencyRed, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 28),
                CustomButton(
                  label: 'Proceed to Document Upload',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: authState.isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
