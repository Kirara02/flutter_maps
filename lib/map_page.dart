import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_maps/api_service.dart';
import 'package:flutter_maps/main.dart';
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
  double currentZoom = 12.0;
  List<Map<String, dynamic>> searchResults = [];
  bool isClikMarker = false;
  TextEditingController searchC = TextEditingController(text: '');

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
    searchC.text = markedLocation;
    String distance = await calculateDistance(point!, latLng);

    print('Jarak antara lokasi anda ke lokasi yang dituju adalah $distance km');
  }

  Future<String> calculateDistance(LatLng latLng1, LatLng latLng2) async {
    double distanceInMeters = Geolocator.distanceBetween(
      latLng1.latitude,
      latLng1.longitude,
      latLng2.latitude,
      latLng2.longitude,
    );

    String? token = await FirebaseMessaging.instance.getToken();
    if (distanceInMeters <= 100) {
      // Di dalam Geofence
      print('Lokasi yang di Klik berada di dalam Geofence');
      sendNotification(
        'Geofence Radius',
        'Lokasi yang di Klik berada di dalam Geofence',
        token!,
      );
    } else {
      // Di luar Geofence
      print('Keluar dari Geofence');
      sendNotification(
        'Geofence Radius',
        'Lokasi yang di Klik berada di luar Geofence',
        token!,
      );
    }

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

  void showFlutterNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    if (notification != null && android != null && !kIsWeb) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            //      one that already exists in example app.
            icon: 'launch_background',
          ),
        ),
      );
    }
  }

  Future<void> sendNotification(String title, String body, String token) async {
    if (token == null) {
      print('Unable to send FCM message, no token exists.');
      return;
    }

    try {
      const url = 'https://fcm.googleapis.com/fcm/send';

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$firebase_server_key',
      };

      final payload = {
        'notification': {
          'title': title,
          'body': body,
        },
        'to': token, // Replace with the device token of the target device
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print('Failed to send notification');
      }
      print(response.statusCode);
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    super.initState();
    determinePosition();
    checkLocationPermission();
    geofenceCoordinates = LatLng(-6.9676662, 107.6565929);
    FirebaseMessaging.onMessage.listen(showFlutterNotification);
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      //
    });
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
              zoom: currentZoom,
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
                        Icons.my_location,
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
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(-6.9676561, 107.6565044),
                    radius: 200,
                    color: Colors.transparent,
                  )
                ],
              )
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                TextField(
                  controller: searchC,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_pin),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  onChanged: (value) {
                    // Panggil metode searchPlaces() saat nilai input berubah
                    searchPlaces(value).then((results) {
                      setState(() {
                        searchResults = results;
                      });
                    });
                  },
                ),
                if (searchResults.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        color: Colors.white,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: searchResults.length,
                          itemBuilder: (BuildContext context, int index) {
                            final result = searchResults[index];
                            final displayName = result['display_name'];
                            double lat = 0;
                            double lon = 0;
                            try {
                              double lat = double.parse(result['lat']);
                              double lon = double.parse(result['lon']);
                              tappedLatLng = LatLng(lat, lon);
                            } catch (e) {
                              print('Error parsing latitude or longitude: $e');
                            }

                            return Column(
                              children: [
                                Container(
                                  child: ListTile(
                                    title: Text(displayName),
                                    onTap: () {
                                      // Aksi yang ingin Anda lakukan saat item dipilih
                                      print('Item dipilih: $displayName');
                                      setState(() {
                                        tappedLatLng = LatLng(lat, lon);
                                        tappedMarker = Marker(
                                          point: LatLng(lat, lon),
                                          builder: (ctx) => const Icon(
                                            Icons.location_pin,
                                            color: Colors.green,
                                          ),
                                        );
    
                                        isClikMarker = true;
                                        mapController.move(tappedLatLng!, 10.0);
                                      });
                                    },
                                  ),
                                ),
                                const Divider(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      mapController.move(
                          mapController.center, mapController.zoom + 1);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red),
                    ),
                    child: Icon(
                      Icons.zoom_in,
                      size: 28,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      mapController.move(
                          mapController.center, mapController.zoom - 1);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.red),
                    ),
                    child: Icon(
                      Icons.zoom_out,
                      size: 28,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
              ],
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
                Icons.location_searching,
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
