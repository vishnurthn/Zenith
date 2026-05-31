import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_webservice/places.dart';

import 'main.dart';

class ZenithMapPage extends StatefulWidget {
  final dynamic userData;

  const ZenithMapPage({
    super.key,
    required this.userData,
  });

  @override
  State<ZenithMapPage> createState() => _ZenithMapPageState();
}

class _ZenithMapPageState extends State<ZenithMapPage> {
  GoogleMapController? _mapController;

  final TextEditingController _searchController = TextEditingController();

  final String googleApiKey = "YOUR_GOOGLE_MAPS_API_KEY";

  final String apiUrl =
      "https://displace-unshaven-bush.ngrok-free.dev/predict_risk";

  final places = GoogleMapsPlaces(apiKey: "YOUR_GOOGLE_MAPS_API_KEY");

  LatLng? _currentLocation;

  final Set<Circle> _riskZones = {};
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  List<Prediction> _predictions = [];

  final PolylinePoints polylinePoints = PolylinePoints();

  final String darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#111111"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#8c8c8c"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#1b1b1b"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#000000"}]
  }
]
''';

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    await _getCurrentLocation();

    _loadRiskZones();

    Timer.periodic(
      const Duration(seconds: 4),
      (timer) {
        _fetchMLSafetyData();
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _currentLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    _markers.add(
      Marker(
        markerId: const MarkerId("current"),
        position: _currentLocation!,
      ),
    );

    setState(() {});
  }

  void _loadRiskZones() {
    final List<LatLng> highRiskZones = [
      const LatLng(13.0827, 80.2707),
      const LatLng(12.9716, 77.5946),
      const LatLng(17.3850, 78.4867),
    ];

    final List<LatLng> mediumRiskZones = [
      const LatLng(13.0300, 80.2600),
      const LatLng(12.9900, 77.5700),
      const LatLng(17.3400, 78.4700),
    ];

    for (var zone in highRiskZones) {
      _riskZones.add(
        Circle(
          circleId: CircleId(zone.toString()),
          center: zone,
          radius: 1000,
          fillColor: Colors.redAccent.withOpacity(0.30),
          strokeColor: Colors.redAccent,
          strokeWidth: 1,
        ),
      );
    }

    for (var zone in mediumRiskZones) {
      _riskZones.add(
        Circle(
          circleId: CircleId(zone.toString()),
          center: zone,
          radius: 1000,
          fillColor: Colors.orangeAccent.withOpacity(0.25),
          strokeColor: Colors.orangeAccent,
          strokeWidth: 1,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _fetchMLSafetyData() async {
    if (_currentLocation == null) return;

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": _currentLocation!.latitude,
          "longitude": _currentLocation!.longitude,
        }),
      );
    } catch (_) {}
  }

  Future<void> _searchPlaces(String value) async {
    if (value.isEmpty) {
      setState(() {
        _predictions = [];
      });

      return;
    }

    final response = await places.autocomplete(value);

    setState(() {
      _predictions = response.predictions;
    });
  }

  Future<void> _selectPlace(
    Prediction prediction,
  ) async {
    PlacesDetailsResponse detail = await places.getDetailsByPlaceId(
      prediction.placeId!,
    );

    final lat = detail.result.geometry!.location.lat;

    final lng = detail.result.geometry!.location.lng;

    LatLng destination = LatLng(lat, lng);

    _markers.removeWhere(
      (m) => m.markerId.value == "destination",
    );

    _markers.add(
      Marker(
        markerId: const MarkerId("destination"),
        position: destination,
      ),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        destination,
        15,
      ),
    );

    _drawRoute(destination);

    _searchController.text = prediction.description ?? "";

    setState(() {
      _predictions = [];
    });
  }

  Future<void> _drawRoute(
    LatLng destination,
  ) async {
    if (_currentLocation == null) return;

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey,
      PointLatLng(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      ),
      PointLatLng(
        destination.latitude,
        destination.longitude,
      ),
    );

    List<LatLng> routeCoords = [];

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        routeCoords.add(
          LatLng(point.latitude, point.longitude),
        );
      }
    }

    _polylines.clear();

    _polylines.add(
      Polyline(
        polylineId: const PolylineId("route"),
        points: routeCoords,
        width: 5,
        color: Colors.redAccent,
      ),
    );

    setState(() {});
  }

  Widget _navItem(
    IconData icon,
    String title,
    bool active,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: active ? Colors.redAccent : Colors.white54,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: active ? Colors.redAccent : Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _legendItem(
    Color color,
    String title,
    String speed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 5,
            backgroundColor: color,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                speed,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(13.0827, 80.2707),
                zoom: 13,
              ),
              onMapCreated: (GoogleMapController controller) async {
                _mapController = controller;

                await controller.setMapStyle(
                  darkMapStyle,
                );
              },
              circles: _riskZones,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),

            /// SEARCH BAR
            Positioned(
              top: 20,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(
                        30,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                            onChanged: _searchPlaces,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "Search places...",
                              hintStyle: TextStyle(
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(
                            right: 8,
                          ),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.redAccent,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.search,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_predictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(
                        top: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _predictions.length,
                        itemBuilder: (context, index) {
                          final item = _predictions[index];

                          return ListTile(
                            title: Text(
                              item.description ?? "",
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            onTap: () {
                              _selectPlace(item);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            /// RISK BOX
            Positioned(
              left: 16,
              bottom: 20,
              child: Container(
                width: 145,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _legendItem(
                      Colors.redAccent,
                      "High Risk",
                      "< 60 KM/H",
                    ),
                    _legendItem(
                      Colors.orangeAccent,
                      "Medium Risk",
                      "60 - 80 KM/H",
                    ),
                  ],
                ),
              ),
            ),

            /// RIGHT CONTROLS
            Positioned(
              right: 16,
              bottom: 50,
              child: Container(
                width: 62,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    IconButton(
                      onPressed: () async {
                        Position position = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high,
                        );

                        LatLng current = LatLng(
                          position.latitude,
                          position.longitude,
                        );

                        _mapController?.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: current,
                              zoom: 16,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.my_location,
                        color: Colors.redAccent,
                      ),
                    ),
                    const Divider(
                      color: Colors.white12,
                    ),
                    IconButton(
                      onPressed: () {
                        _mapController?.animateCamera(
                          CameraUpdate.zoomIn(),
                        );
                      },
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _mapController?.animateCamera(
                          CameraUpdate.zoomOut(),
                        );
                      },
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
