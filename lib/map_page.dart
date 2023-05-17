import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_maps/api_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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
  List listOfPoint = [];
  List<LatLng> routepoints = [];
  LatLng? geofenceCoordinates;
  String currentLocation = '';
  String markedLocation = '';
  bool isClikMarker = false;

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

      isClikMarker = true;
    });

    List<Placemark> placemarks = await placemarkFromCoordinates(
      tappedLatLng!.latitude,
      tappedLatLng!.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks[0];
      String formattedAddress =
          '${placemark.thoroughfare} ${placemark.subThoroughfare} ${placemark.subLocality}, ${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea},${placemark.postalCode} ${placemark.country}';
      setState(() {
        markedLocation = formattedAddress;
      });
    } else {
      setState(() {
        markedLocation = 'No address available';
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
          '${placemark.thoroughfare} ${placemark.subThoroughfare} ${placemark.subLocality}, ${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea},${placemark.postalCode} ${placemark.country}';
      setState(() {
        currentLocation = formattedAddress;
      });
    } else {
      setState(() {
        currentLocation = 'No address available';
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

  getCoordinates() async {
    var response = await http.get(getRouteUrl(
        "${point!.longitude.toString()},${point!.latitude.toString()}",
        "${tappedLatLng!.longitude.toString()},${tappedLatLng!.latitude.toString()}"));
    setState(() {
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        listOfPoint = data['features'][0]['geometry']['coordinates'];
        routepoints = listOfPoint
            .map((p) => LatLng(p[1].toDouble(), p[0].toDouble()))
            .toList();
      }
    });
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
            nonRotatedChildren: const [
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: null,
                  ),
                ],
              )
            ],
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
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routepoints,
                    color: Colors.blue,
                    strokeWidth: 4,
                  )
                ],
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Column(
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(currentLocation),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Visibility(
                      visible: isClikMarker,
                      child: Column(
                        children: [
                          const Text(
                            'Lokasi yang di klik',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(markedLocation),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 15,
            right: 15,
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
            right: 15,
            child: FloatingActionButton(
              backgroundColor: Colors.green.shade500,
              onPressed: () {
                getCoordinates();
              },
              child: const Icon(
                Icons.route,
                color: Colors.black,
              ),
            ),
          ),
          Positioned(
            bottom: 145,
            right: 15,
            child: Visibility(
              visible: isClikMarker,
              child: FloatingActionButton(
                backgroundColor: Colors.red.shade500,
                onPressed: () {
                  getCoordinates();
                },
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      isClikMarker = false;
                      markedLocation = '';
                      tappedMarker = null;
                      routepoints = [];
                    });
                  },
                  icon: const Icon(
                    Icons.location_off,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}
