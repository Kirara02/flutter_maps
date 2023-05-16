import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng? point;
  Geolocator geolocator = Geolocator();
  MapController mapController = MapController();
  Marker? tappedMarker;
  LatLng? tappedLatLng;
  List<LatLng> routepoints = [];
  LatLng? geofenceCoordinates;
  TextEditingController currentLoc = TextEditingController(text: '');
  TextEditingController markerLoc = TextEditingController(text: '');
  bool isVisible = false;

  void handleTap(TapPosition post, LatLng latLng) async {
    setState(() {
      tappedLatLng = latLng;
      tappedMarker = Marker(
        point: latLng,
        builder: (ctx) => const Icon(
          Icons.location_pin,
          color: Colors.green,
        ),
      );
    });

    if (routepoints.length >= 2) {
      routepoints[1] = tappedLatLng!;
    } else {
      routepoints.add(tappedLatLng!);
    }

    List<Placemark> placemarks = await placemarkFromCoordinates(
      tappedLatLng!.latitude,
      tappedLatLng!.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks[0];
      String formattedAddress =
          '${placemark.name}, ${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea}, ${placemark.country}';
      setState(() {
        markerLoc.text = formattedAddress;
      });
    } else {
      setState(() {
        markerLoc.text = 'No address available';
      });
    }

    String distance = calculateDistance(point!, latLng);

    print('Jarak antara lokasi anda ke lokasi yang dituju adalah $distance km');
  }

  String calculateDistance(LatLng latLng1, LatLng latLng2) {
    double distanceInMeters = Geolocator.distanceBetween(
      latLng1.latitude,
      latLng1.longitude,
      latLng2.latitude,
      latLng2.longitude,
    );

    // Mengkonversi jarak dari meter ke kilometer
    double distanceInKilometers = distanceInMeters / 1000;

    String formattedDistance = distanceInKilometers
        .toStringAsFixed(2); // Menampilkan 2 angka di belakang koma

    return formattedDistance;
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> checkLocationPermission() async {
    final permissionStatus = await Permission.locationWhenInUse.request();
    if (permissionStatus.isGranted) {
      updateMarker();
    }
  }

  void updateMarker() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      point = LatLng(position.latitude, position.longitude);
    });

    List<Placemark> placemarks = await placemarkFromCoordinates(
      point!.latitude,
      point!.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks[0];
      String formattedAddress =
          '${placemark.name}, ${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea}, ${placemark.country}';
      setState(() {
        currentLoc.text = formattedAddress;
      });
    } else {
      setState(() {
        currentLoc.text = 'No address available';
      });
    }
    routepoints.add(point!);
    zoomToCurrentLocation();
  }

  void zoomToCurrentLocation() {
    if (point != null) {
      mapController.move(point!, 18.0);
    }
  }

  @override
  void initState() {
    super.initState();
    determinePosition();
    checkLocationPermission();
    geofenceCoordinates = LatLng(-6.9676662, 107.6565929);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: LatLng(0, 0),
              zoom: 12.0,
              onTap: handleTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_maps',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  if (point != null)
                    Marker(
                      point: point!,
                      builder: (ctx) => const Icon(
                        Icons.location_on,
                        color: Colors.red,
                      ),
                    ),
                  if (tappedMarker != null) tappedMarker!,
                ],
              ),
              Visibility(
                visible: isVisible,
                child: PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routepoints,
                      color: Colors.blue,
                      strokeWidth: 4,
                    )
                  ],
                ),
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Container(
              height: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokasi saat ini',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      TextField(
                        controller: currentLoc,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lokasi dituju',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      TextField(
                        controller: markerLoc,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () => updateMarker(),
              child: const Icon(
                Icons.my_location,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: isVisible == true ? Colors.blue : Colors.white,
              onPressed: () {
                setState(() {
                  isVisible = !isVisible;
                });
              },
              child: const Icon(
                Icons.route,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}
