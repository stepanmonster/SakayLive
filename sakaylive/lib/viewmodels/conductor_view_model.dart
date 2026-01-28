// lib/viewmodels/conductor_view_model.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sakaylive/services/conductor_tracking_service.dart';
import 'package:sakaylive/services/auth_service.dart';

/// Conductor occupancy status (what passengers see)
enum OccupancyStatus {
  green, // Seats available
  yellow, // Standing room only
  red, // Full capacity
}

extension OccupancyStatusExtension on OccupancyStatus {
  String get value {
    switch (this) {
      case OccupancyStatus.green:
        return 'green';
      case OccupancyStatus.yellow:
        return 'yellow';
      case OccupancyStatus.red:
        return 'red';
    }
  }

  String get label {
    switch (this) {
      case OccupancyStatus.green:
        return 'Seats Available';
      case OccupancyStatus.yellow:
        return 'Standing Only';
      case OccupancyStatus.red:
        return 'Full';
    }
  }

  Color get color {
    switch (this) {
      case OccupancyStatus.green:
        return const Color(0xFF22C55E);
      case OccupancyStatus.yellow:
        return const Color(0xFFF59E0B);
      case OccupancyStatus.red:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case OccupancyStatus.green:
        return Icons.event_seat;
      case OccupancyStatus.yellow:
        return Icons.directions_bus;
      case OccupancyStatus.red:
        return Icons.block;
    }
  }

  static OccupancyStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'yellow':
        return OccupancyStatus.yellow;
      case 'red':
        return OccupancyStatus.red;
      default:
        return OccupancyStatus.green;
    }
  }
}

/// Bus assignment data
class BusAssignment {
  final String busId;
  final String plateNumber;
  final String routeId;
  final String routeName;
  final int capacity;

  BusAssignment({
    required this.busId,
    required this.plateNumber,
    required this.routeId,
    required this.routeName,
    this.capacity = 30,
  });

  factory BusAssignment.fromMap(String id, Map<dynamic, dynamic> data) {
    return BusAssignment(
      busId: id,
      plateNumber: data['plate_number'] ?? id,
      routeId: data['route_id']?.toString() ?? '',
      routeName: data['route_name'] ?? 'Unknown Route',
      capacity: data['capacity'] ?? 30,
    );
  }
}

/// ViewModel for Conductor Dashboard following MVVM pattern.
///
/// Manages:
/// - Trip lifecycle (start/end)
/// - GPS location broadcasting
/// - Occupancy status updates
/// - Bus assignments
/// - Trip statistics
class ConductorViewModel extends ChangeNotifier {
  // Services
  late final FirebaseDatabase _database;
  late final ConductorTrackingService _trackingService;
  final AuthService _authService = AuthService();

  // State
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Conductor info
  String? _conductorId;
  String? _conductorName;

  // Bus assignments
  List<BusAssignment> _availableBuses = [];
  BusAssignment? _selectedBus;

  // Trip state
  bool _isTripActive = false;
  OccupancyStatus _currentStatus = OccupancyStatus.green;
  DateTime? _tripStartTime;
  int _passengerCount = 0;

  // Location state
  geo.Position? _currentPosition;
  double _tripDistanceMeters = 0;
  int _updateCount = 0;
  DateTime? _lastUpdateTime;

  // Trip history
  List<Map<String, dynamic>> _tripHistory = [];

  // --- GETTERS ---
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get conductorId => _conductorId;
  String? get conductorName => _conductorName;

  List<BusAssignment> get availableBuses => _availableBuses;
  BusAssignment? get selectedBus => _selectedBus;
  bool get hasBusSelected => _selectedBus != null;

  bool get isTripActive => _isTripActive;
  OccupancyStatus get currentStatus => _currentStatus;
  DateTime? get tripStartTime => _tripStartTime;
  int get passengerCount => _passengerCount;

  geo.Position? get currentPosition => _currentPosition;
  double get tripDistanceMeters => _tripDistanceMeters;
  String get tripDistanceText {
    if (_tripDistanceMeters < 1000) {
      return '${_tripDistanceMeters.round()}m';
    }
    return '${(_tripDistanceMeters / 1000).toStringAsFixed(2)}km';
  }

  int get updateCount => _updateCount;
  DateTime? get lastUpdateTime => _lastUpdateTime;

  Duration get tripDuration {
    if (_tripStartTime == null) return Duration.zero;
    return DateTime.now().difference(_tripStartTime!);
  }

  String get tripDurationText {
    final d = tripDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return "${h}h ${m}m";
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String get lastUpdateText {
    if (_lastUpdateTime == null) return 'Not updated yet';
    final diff = DateTime.now().difference(_lastUpdateTime!);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }

  List<Map<String, dynamic>> get tripHistory => _tripHistory;

  /// Initialize the ViewModel
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Initialize Firebase
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://sakaylive-1-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      // Initialize tracking service
      _trackingService = ConductorTrackingService(
        _database,
        config: ConductorTrackingConfig.production,
      );

      // Set up callbacks
      _trackingService.onTripUpdated = _onTripUpdated;
      _trackingService.onLocationUpdated = _onLocationUpdated;
      _trackingService.onError = _onTrackingError;

      // Get conductor info from auth
      final user = _authService.currentUser;
      if (user != null) {
        _conductorId = user.uid;
        _conductorName =
            user.displayName ?? user.email?.split('@').first ?? 'Conductor';

        // Load conductor-specific data
        await _loadConductorData();
      }

      // Load available buses
      await _loadAvailableBuses();

      // Load trip history
      if (_conductorId != null) {
        _tripHistory = await _trackingService.getTripHistory(_conductorId!);
      }

      _isInitialized = true;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
      debugPrint('🔴 ConductorViewModel init error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load conductor's profile data
  Future<void> _loadConductorData() async {
    if (_conductorId == null) return;

    try {
      final snapshot = await _database.ref('users/$_conductorId').get();

      if (snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        _conductorName = data['username'] ?? _conductorName;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load conductor data: $e');
    }
  }

  /// Load available buses for this conductor
  Future<void> _loadAvailableBuses() async {
    try {
      // For now, use a static list of buses
      // In production, this would come from Firebase based on conductor's assignment
      _availableBuses = [
        BusAssignment(
          busId: 'E-Bus 01',
          plateNumber: 'ABC 1234',
          routeId: '3',
          routeName: 'GT Pavia - Gaisano City',
          capacity: 30,
        ),
        BusAssignment(
          busId: 'E-Bus 02',
          plateNumber: 'DEF 5678',
          routeId: '4',
          routeName: 'GT Pavia - UPV CM',
          capacity: 30,
        ),
        BusAssignment(
          busId: 'E-Bus 03',
          plateNumber: 'GHI 9012',
          routeId: '5',
          routeName: 'JD Gen Luna - Festive Walk',
          capacity: 25,
        ),
        BusAssignment(
          busId: 'E-Bus 04',
          plateNumber: 'JKL 3456',
          routeId: '9',
          routeName: 'Infante - Mohon',
          capacity: 30,
        ),
        BusAssignment(
          busId: 'E-Bus 05',
          plateNumber: 'MNO 7890',
          routeId: '10',
          routeName: 'Tagbak - UI',
          capacity: 35,
        ),
      ];

      // Try to load from Firebase (conductor's assigned buses)
      if (_conductorId != null) {
        final snapshot = await _database
            .ref('conductorAssignments/$_conductorId/buses')
            .get();

        if (snapshot.value != null) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          _availableBuses = data.entries
              .map(
                (e) => BusAssignment.fromMap(e.key.toString(), e.value as Map),
              )
              .toList();
        }
      }

      // Select first bus by default
      if (_availableBuses.isNotEmpty && _selectedBus == null) {
        _selectedBus = _availableBuses.first;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load buses: $e');
    }
  }

  /// Select a bus
  void selectBus(BusAssignment bus) {
    if (_isTripActive) {
      _errorMessage = 'Cannot change bus during active trip';
      notifyListeners();
      return;
    }
    _selectedBus = bus;
    _errorMessage = null;
    notifyListeners();
  }

  /// Start a new trip
  Future<bool> startTrip() async {
    if (_selectedBus == null) {
      _errorMessage = 'Please select a bus first';
      notifyListeners();
      return false;
    }

    if (_conductorId == null) {
      _errorMessage = 'Please log in first';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _trackingService.startTrip(
        busId: _selectedBus!.busId,
        routeId: _selectedBus!.routeId,
        conductorId: _conductorId!,
        conductorName: _conductorName ?? 'Unknown',
      );

      if (success) {
        _isTripActive = true;
        _tripStartTime = DateTime.now();
        _currentStatus = OccupancyStatus.green;
        _passengerCount = 0;
        _tripDistanceMeters = 0;
        _updateCount = 0;
        debugPrint('✅ Trip started successfully');
      } else {
        _errorMessage = 'Failed to start trip. Check GPS permissions.';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Error starting trip: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// End the current trip
  Future<void> endTrip() async {
    if (!_isTripActive) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _trackingService.endTrip();

      _isTripActive = false;
      _tripStartTime = null;
      _currentPosition = null;
      _lastUpdateTime = null;

      // Refresh trip history
      if (_conductorId != null) {
        _tripHistory = await _trackingService.getTripHistory(_conductorId!);
      }

      debugPrint('✅ Trip ended successfully');
    } catch (e) {
      _errorMessage = 'Error ending trip: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update occupancy status
  void setOccupancyStatus(OccupancyStatus status) {
    if (!_isTripActive) return;

    _currentStatus = status;
    _trackingService.updateOccupancy(status.value);
    _lastUpdateTime = DateTime.now();
    notifyListeners();
  }

  /// Update passenger count
  void setPassengerCount(int count) {
    if (!_isTripActive) return;

    _passengerCount = count.clamp(0, _selectedBus?.capacity ?? 50);
    _trackingService.updatePassengerCount(_passengerCount);

    // Auto-update occupancy based on passenger count
    if (_selectedBus != null) {
      final capacity = _selectedBus!.capacity;
      if (_passengerCount >= capacity) {
        setOccupancyStatus(OccupancyStatus.red);
      } else if (_passengerCount >= capacity * 0.7) {
        setOccupancyStatus(OccupancyStatus.yellow);
      } else {
        setOccupancyStatus(OccupancyStatus.green);
      }
    }

    notifyListeners();
  }

  /// Increment passenger count
  void incrementPassengers() {
    setPassengerCount(_passengerCount + 1);
  }

  /// Decrement passenger count
  void decrementPassengers() {
    setPassengerCount(_passengerCount - 1);
  }

  /// Force a location update
  Future<void> forceLocationUpdate() async {
    if (!_isTripActive) return;
    await _trackingService.forceUpdate();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // --- CALLBACKS ---

  void _onTripUpdated(ConductorTripState tripState) {
    _tripDistanceMeters = tripState.totalDistanceMeters;
    _updateCount = tripState.updateCount;
    _lastUpdateTime = tripState.lastUpdateTime;
    notifyListeners();
  }

  void _onLocationUpdated(geo.Position position) {
    _currentPosition = position;
    _lastUpdateTime = DateTime.now();
    notifyListeners();
  }

  void _onTrackingError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isTripActive) {
      _trackingService.endTrip();
    }
    _trackingService.dispose();
    super.dispose();
  }
}
