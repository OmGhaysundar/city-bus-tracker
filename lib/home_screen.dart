import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(20.9374, 77.7796),
    zoom: 14,
  );

  List<Marker> _marker = [];
  Set<Polyline> _polylines = {};

  // Route data
  String? selectedFrom;
  String? selectedTo;
  String? selectedTimeSlot;
  Map<String, dynamic>? selectedBusSchedule;

  // Bus route locations with real coordinates
  final List<Map<String, dynamic>> locations = [
     
    {'name': 'Navsari', 'lat': 20.965926095443233, 'lng': 77.74577881208559},
    {'name': 'Panchawati', 'lat': 20.944035032005164, 'lng': 77.76892649206981},
    {'name': 'Irwin Sq', 'lat': 20.933808353562945, 'lng': 77.76102974735286 },
    {'name': 'Rajkamal Sq', 'lat': 20.9283669336735, 'lng': 77.7540531837026},
    {'name': 'Sai Nagar', 'lat':  20.89926767912191, 'lng': 77.74826796265233},
    {'name': 'Old Town Badnera', 'lat': 20.856694684200395, 'lng': 77.73094843893523},
  ];

  // Real bus schedules from Navsari to Old Town Badnera
  final List<Map<String, dynamic>> busSchedules = [
    {
      'departureFromNavsari': '06:30 AM',
      'arrivalAtOldTown': '07:05 AM',
      'departureFromOldTown': '02:05 PM',
      'arrivalAtNavsari': '02:40 PM',
    },
    {
      'departureFromNavsari': '06:55 AM',
      'arrivalAtOldTown': '07:30 AM',
      'departureFromOldTown': '02:15 PM',
      'arrivalAtNavsari': '02:50 PM',
    },
    {
      'departureFromNavsari': '09:45 AM',
      'arrivalAtOldTown': '10:20 AM',
      'departureFromOldTown': '05:35 PM',
      'arrivalAtNavsari': '06:10 PM',
    },
    {
      'departureFromNavsari': '10:00 AM',
      'arrivalAtOldTown': '10:35 AM',
      'departureFromOldTown': '05:50 PM',
      'arrivalAtNavsari': '06:25 PM',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    _marker = locations.map((loc) {
      return Marker(
        markerId: MarkerId(loc['name']),
        position: LatLng(loc['lat'], loc['lng']),
        infoWindow: InfoWindow(title: loc['name']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }).toList();
  }

  List<String> _getAvailableTimeSlots() {
    if (selectedFrom == null || selectedTo == null) return [];

    List<String> slots = [];

    // Check if route is in forward direction (Navsari side to Old Town side)
    int fromIndex = locations.indexWhere((loc) => loc['name'] == selectedFrom);
    int toIndex = locations.indexWhere((loc) => loc['name'] == selectedTo);

    if (fromIndex < toIndex) {
      // Forward direction - use Navsari departure times
      for (var schedule in busSchedules) {
        slots.add(schedule['departureFromNavsari']);
      }
    } else if (fromIndex > toIndex) {
      // Reverse direction - use Old Town departure times
      for (var schedule in busSchedules) {
        slots.add(schedule['departureFromOldTown']);
      }
    }

    return slots;
  }

  Map<String, dynamic>? _getBusScheduleForTimeSlot(String timeSlot) {
    int fromIndex = locations.indexWhere((loc) => loc['name'] == selectedFrom);
    int toIndex = locations.indexWhere((loc) => loc['name'] == selectedTo);

    // Forward direction (towards Old Town)
    if (fromIndex < toIndex) {
      for (var schedule in busSchedules) {
        if (schedule['departureFromNavsari'] == timeSlot) {
          // Calculate approximate times for intermediate stops
          int stopsFromStart = fromIndex;
          int stopsToEnd = toIndex;
          int totalStops = locations.length - 1;

          // Estimate departure and arrival (roughly 7 mins per stop)
          String estimatedDeparture = timeSlot;
          String estimatedArrival = _addMinutesToTime(timeSlot, (toIndex - fromIndex) * 7);

          return {
            'departure': estimatedDeparture,
            'arrival': estimatedArrival,
            'duration': '${(toIndex - fromIndex) * 7} mins',
          };
        }
      }
    }
    // Reverse direction (towards Navsari)
    else if (fromIndex > toIndex) {
      for (var schedule in busSchedules) {
        if (schedule['departureFromOldTown'] == timeSlot) {
          String estimatedDeparture = timeSlot;
          String estimatedArrival = _addMinutesToTime(timeSlot, (fromIndex - toIndex) * 7);

          return {
            'departure': estimatedDeparture,
            'arrival': estimatedArrival,
            'duration': '${(fromIndex - toIndex) * 7} mins',
          };
        }
      }
    }
    return null;
  }

  String _addMinutesToTime(String time, int minutes) {
    // Simple time addition (you can make this more robust)
    final parts = time.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    String period = parts[1];

    minute += minutes;
    while (minute >= 60) {
      minute -= 60;
      hour += 1;
    }

    if (hour >= 12) {
      if (hour > 12) hour -= 12;
      period = period == 'AM' ? 'PM' : 'AM';
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  void _drawRoute() {
    if (selectedFrom != null && selectedTo != null) {
      final from = locations.firstWhere((loc) => loc['name'] == selectedFrom);
      final to = locations.firstWhere((loc) => loc['name'] == selectedTo);

      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: [
              LatLng(from['lat'], from['lng']),
              LatLng(to['lat'], to['lng']),
            ],
            color: Colors.cyan,
            width: 5,
          ),
        );

        // Add bus marker at starting point
        _marker.add(
          Marker(
            markerId: const MarkerId('bus'),
            position: LatLng(from['lat'], from['lng']),
            infoWindow: const InfoWindow(title: 'Bus Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      });

      _moveCameraToRoute(from, to);
    }
  }

  Future<void> _moveCameraToRoute(Map<String, dynamic> from, Map<String, dynamic> to) async {
    final controller = await _controller.future;
    final bounds = LatLngBounds(
      southwest: LatLng(
        from['lat'] < to['lat'] ? from['lat'] : to['lat'],
        from['lng'] < to['lng'] ? from['lng'] : to['lng'],
      ),
      northeast: LatLng(
        from['lat'] > to['lat'] ? from['lat'] : to['lat'],
        from['lng'] > to['lng'] ? from['lng'] : to['lng'],
      ),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _showRouteSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final availableSlots = _getAvailableTimeSlots();

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const Text(
                    'Plan Your Journey',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // From Location
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'From',
                        prefixIcon: Icon(Icons.location_on, color: Colors.green),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      value: selectedFrom,
                      items: locations.map((loc) {
                        return DropdownMenuItem<String>(
                          value: loc['name'] as String,
                          child: Text(loc['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedFrom = value;
                          selectedTo = null;
                          selectedTimeSlot = null;
                          selectedBusSchedule = null;
                        });
                        setState(() {
                          selectedFrom = value;
                          selectedTo = null;
                          selectedTimeSlot = null;
                          selectedBusSchedule = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // To Location
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'To',
                        prefixIcon: Icon(Icons.location_on, color: Colors.red),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      value: selectedTo,
                      items: locations
                          .where((loc) => loc['name'] != selectedFrom)
                          .map((loc) {
                        return DropdownMenuItem<String>(
                          value: loc['name'] as String,
                          child: Text(loc['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedTo = value;
                          selectedTimeSlot = null;
                          selectedBusSchedule = null;
                        });
                        setState(() {
                          selectedTo = value;
                          selectedTimeSlot = null;
                          selectedBusSchedule = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Time Slot Selection
                  if (availableSlots.isNotEmpty) ...[
                    const Text(
                      'Available Bus Timings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...availableSlots.map((slot) {
                      final schedule = _getBusScheduleForTimeSlot(slot);
                      final isSelected = selectedTimeSlot == slot;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isSelected ? Colors.cyan.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? Colors.cyan : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedTimeSlot = slot;
                              selectedBusSchedule = schedule;
                            });
                            setState(() {
                              selectedTimeSlot = slot;
                              selectedBusSchedule = schedule;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: isSelected ? Colors.cyan : Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Departure: ${schedule?['departure']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isSelected ? Colors.cyan.shade900 : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Arrival: ${schedule?['arrival']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle, color: Colors.cyan),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  const SizedBox(height: 24),

                  // Track Button
                  ElevatedButton(
                    onPressed: (selectedFrom != null &&
                        selectedTo != null &&
                        selectedTimeSlot != null)
                        ? () {
                      Navigator.pop(context);
                      _drawRoute();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tracking bus from $selectedFrom to $selectedTo at $selectedTimeSlot',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text(
                      'Track Bus',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (selectedBusSchedule != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Card(
                        color: Colors.cyan[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Journey Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Departure: ${selectedBusSchedule!['departure']}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.alarm, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Arrival: ${selectedBusSchedule!['arrival']}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.timer, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Duration: ${selectedBusSchedule!['duration']}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _kGooglePlex,
              markers: Set<Marker>.of(_marker),
              polylines: _polylines,
              mapType: MapType.normal,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                if (!_controller.isCompleted) _controller.complete(controller);
              },
            ),

            // Top Card with current selection
            if (selectedFrom != null && selectedTo != null && selectedTimeSlot != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_bus, color: Colors.cyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$selectedFrom → $selectedTo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                setState(() {
                                  selectedFrom = null;
                                  selectedTo = null;
                                  selectedTimeSlot = null;
                                  selectedBusSchedule = null;
                                  _polylines.clear();
                                  _initializeMarkers();
                                });
                              },
                            ),
                          ],
                        ),
                        Text(
                          'Departure: $selectedTimeSlot',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        if (selectedBusSchedule != null)
                          Text(
                            'Arrival: ${selectedBusSchedule!['arrival']}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'route',
            backgroundColor: Colors.cyan,
            child: const Icon(Icons.search),
            onPressed: _showRouteSelector,
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'location',
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Colors.cyan),
            onPressed: () async {
              final controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(_kGooglePlex),
              );
            },
          ),
        ],
      ),
    );
  }
}