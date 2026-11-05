import 'package:flutter_test/flutter_test.dart';
import 'package:liferoute_driver/features/requests/models/booking_request_model.dart';
import 'package:liferoute_driver/features/dashboard/models/dashboard_summary_model.dart';
import 'package:liferoute_driver/features/auth/models/driver_model.dart';
import 'package:liferoute_driver/features/auth/models/vehicle_model.dart';

void main() {
  group('LifeRoute Driver - Requested Features Verification', () {
    test('1. Booking Request countdown is 120s (2 minutes) and includes patient phone', () {
      final request = BookingRequestModel(
        id: 101,
        bookingReference: 'BK-12345',
        pickupAddress: 'Indiranagar 100ft Road',
        pickupLandmark: 'Metro Pillar 42',
        pickupLatitude: 12.9784,
        pickupLongitude: 77.6408,
        destinationHospital: 'Manipal Hospital HAL',
        destinationAddress: 'HAL Old Airport Road',
        destinationLatitude: 12.9592,
        destinationLongitude: 77.6540,
        emergencyCategory: 'Critical',
        essentialInstructions: 'Oxygen cylinder needed',
        countdownSeconds: 120,
        createdAt: DateTime.now(),
        patientName: 'Arjun Mehta',
        patientPhone: '+91 98450 12345',
      );

      expect(request.countdownSeconds, 120);
      expect(request.patientName, 'Arjun Mehta');
      expect(request.patientPhone, '+91 98450 12345');
    });

    test('2. Dashboard Summary model copyWith updates all operational metrics', () {
      final initial = DashboardSummaryModel(
        completedTripsToday: 2,
        distanceCoveredKm: 18.5,
        onlineHours: 3.2,
        emergencyCriticalTrips: 1,
        earningsToday: 1500.0,
      );

      final updated = initial.copyWith(
        completedTripsToday: initial.completedTripsToday + 1,
        distanceCoveredKm: initial.distanceCoveredKm + 6.2,
        onlineHours: initial.onlineHours + 0.5,
        emergencyCriticalTrips: initial.emergencyCriticalTrips + 1,
        earningsToday: initial.earningsToday + 850.0,
      );

      expect(updated.completedTripsToday, 3);
      expect(updated.distanceCoveredKm, closeTo(24.7, 0.01));
      expect(updated.onlineHours, closeTo(3.7, 0.01));
      expect(updated.emergencyCriticalTrips, 2);
      expect(updated.earningsToday, 2350.0);
    });

    test('3. Driver Model copyWith preserves vehicle and registration updates across app', () {
      final driver = DriverModel(
        id: 1,
        name: 'Rajesh Kumar',
        phone: '+91 98765 43210',
        email: 'rajesh.driver@liferoute.in',
        licenseNumber: 'KA-01-2018-0098234',
        licenseExpiryDate: '2028-12-31',
        emergencyContact: '+91 98765 99999',
        verificationStatus: VerificationStatus.approved,
        isOnline: true,
        documentsUploaded: const {},
        assignedVehicle: VehicleModel(
          registrationNumber: 'KA-01-EA-1080',
          vehicleType: VehicleType.als,
          makeModel: 'Force Traveller ICU Ambulance',
          year: 2024,
          equipmentList: ['Ventilator', 'Defibrillator'],
          operatorAffiliation: 'Manipal Emergency Network',
          permitNumber: 'KA-AMB-2024-998',
          permitExpiryDate: '2026-12-31',
          insurancePolicyNumber: 'HDFC-ERGO-AMB-99812',
          insuranceExpiryDate: '2025-11-30',
        ),
      );

      expect(driver.name, 'Rajesh Kumar');
      expect(driver.assignedVehicle?.registrationNumber, 'KA-01-EA-1080');

      final updated = driver.copyWith(
        name: 'Rajesh K. Sharma',
        assignedVehicle: driver.assignedVehicle?.copyWith(
          registrationNumber: 'KA-01-EA-9999',
          makeModel: 'Mercedes Sprinter ALS',
        ),
      );

      expect(updated.name, 'Rajesh K. Sharma');
      expect(updated.assignedVehicle?.registrationNumber, 'KA-01-EA-9999');
      expect(updated.assignedVehicle?.makeModel, 'Mercedes Sprinter ALS');
    });
  });
}
