import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(HimaApp());
}

class HimaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HIMA Mission Picker',
      home: HimaMapPicker(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HimaMapPicker extends StatefulWidget {
  @override
  _HimaMapPickerState createState() => _HimaMapPickerState();
}

class _HimaMapPickerState extends State<HimaMapPicker> {
  GoogleMapController? _mapController;
  List<LatLng> _regionCorners = [];
  LatLng? _startPoint;
  LatLng? _endPoint;
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  TextEditingController _searchController = TextEditingController();

  void _onMapTap(LatLng latLng) {
    setState(() {
      if (_regionCorners.length < 2) {
        _regionCorners.add(latLng);
        _markers.add(Marker(
          markerId: MarkerId('corner${_regionCorners.length}'),
          position: latLng,
          infoWindow: InfoWindow(
            title: _regionCorners.length == 1 ? 'Top-Left' : 'Bottom-Right',
          ),
        ));

        if (_regionCorners.length == 2) {
          _drawRegion();
        }
      } else if (_regionCorners.length == 2 &&
          _isWithinSelectedRegion(latLng)) {
        if (_startPoint == null) {
          _startPoint = latLng;
          _markers.add(Marker(
            markerId: MarkerId('start'),
            position: latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: 'Start'),
          ));
        } else if (_endPoint == null) {
          _endPoint = latLng;
          _markers.add(Marker(
            markerId: MarkerId('end'),
            position: latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'End'),
          ));

          _saveMission();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🚫 Tap inside the selected region only')),
        );
      }
    });
  }

  bool _isWithinSelectedRegion(LatLng point) {
    if (_regionCorners.length < 2) return false;

    final lat1 = _regionCorners[0].latitude;
    final lat2 = _regionCorners[1].latitude;
    final lng1 = _regionCorners[0].longitude;
    final lng2 = _regionCorners[1].longitude;

    final minLat = lat1 < lat2 ? lat1 : lat2;
    final maxLat = lat1 > lat2 ? lat1 : lat2;
    final minLng = lng1 < lng2 ? lng1 : lng2;
    final maxLng = lng1 > lng2 ? lng1 : lng2;

    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLng &&
        point.longitude <= maxLng;
  }

  void _drawRegion() {
    if (_regionCorners.length == 2) {
      LatLng topLeft = _regionCorners[0];
      LatLng bottomRight = _regionCorners[1];

      _polygons.add(Polygon(
        polygonId: PolygonId('region'),
        fillColor: Colors.blue.withOpacity(0.2),
        strokeColor: Colors.blue,
        strokeWidth: 2,
        points: [
          LatLng(topLeft.latitude, topLeft.longitude),
          LatLng(topLeft.latitude, bottomRight.longitude),
          LatLng(bottomRight.latitude, bottomRight.longitude),
          LatLng(bottomRight.latitude, topLeft.longitude),
        ],
      ));
    }
  }

  Future<void> _saveMission() async {
    final mission = {
      'region': {
        'top_left': {
          'lat': _regionCorners[0].latitude,
          'lon': _regionCorners[0].longitude,
        },
        'bottom_right': {
          'lat': _regionCorners[1].latitude,
          'lon': _regionCorners[1].longitude,
        },
      },
      'start': {
        'lat': _startPoint!.latitude,
        'lon': _startPoint!.longitude,
      },
      'end': {
        'lat': _endPoint!.latitude,
        'lon': _endPoint!.longitude,
      }
    };

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/mission.json');
    await file.writeAsString(jsonEncode(mission));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Mission saved to mission.json')),
    );
  }

  Future<void> _searchAndNavigate(String placeName) async {
    try {
      List<Location> locations = await locationFromAddress(placeName);
      if (locations.isNotEmpty) {
        final target =
        LatLng(locations.first.latitude, locations.first.longitude);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(target, 16),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location service is disabled')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission permanently denied')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final current = LatLng(position.latitude, position.longitude);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(current, 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HIMA Mission Picker'),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'Use My Location',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a location',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                _searchAndNavigate(value);
              },
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: LatLng(21.558, 39.206),
                zoom: 15,
              ),
              onTap: _onMapTap,
              markers: _markers,
              polygons: _polygons,
              myLocationButtonEnabled: false,
              myLocationEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}
