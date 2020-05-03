import 'package:flutter/material.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:math';

void main() => runApp(MaterialApp(
      title: 'TestGeoFlutterFire',
      home: MyApp(),
    ));

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoogleMapController _mapController;
  Firestore _firestore = Firestore.instance;
  Geoflutterfire geo;
  Stream<List<DocumentSnapshot>> stream;
  var radius = BehaviorSubject<double>.seeded(1.0);
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  String style;
  @override
  void initState() {
    super.initState();
    setCustomMapStyle();
    geo = Geoflutterfire();
    GeoFirePoint center = geo.point(latitude: 48.0833 , longitude: 7.3667);
    stream = radius.switchMap((rad) {
      var collectionReference = _firestore.collection('locations');
      return geo.collection(collectionRef: collectionReference).within(
          center: center, radius: rad, field: 'position', strictMode: true);
    });
  }

  @override
  void dispose() {
    super.dispose();
    radius.close();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromARGB(250,0,0,0),
          title: const Text('TestGeoFire'),
          actions: <Widget>[
            IconButton(
              onPressed: _mapController == null
                  ? null
                  : () {
                      _showHome();
                    },
              icon: Icon(Icons.home),
            )
          ],
        ),
        body: Container(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Center(
                child: Card(
                  elevation: 4,
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 30,
                    height: MediaQuery.of(context).size.height * (15/20),
                    child: GoogleMap(
                      myLocationEnabled: true,
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(48.0833, 48.0833),
                        zoom: 15.0,
                      ),
                      markers: Set<Marker>.of(markers.values),
                      onTap: (LatLng location){
                        var random = Random();
                        _addPoint(location.latitude, location.longitude, random.nextBool());
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Slider(
                  min: 1,
                  max: 200,
                  divisions: 4,
                  value: _value,
                  label: _label,
                  activeColor: Colors.grey,
                  inactiveColor: Colors.grey.withOpacity(0.2),
                  onChanged: (double value) => changed(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
      _mapController.setMapStyle(style);
      stream.listen((List<DocumentSnapshot> documentList) {
        _updateMarkers(documentList);
      });
    });
  }

  void _showHome() {
    _mapController.animateCamera(CameraUpdate.newCameraPosition(
      const CameraPosition(
        target: LatLng(48.0833, 7.3667),
        zoom: 15.0,
      ),
    ));
  }

  void _addPoint(double lat, double lng, bool positive) {
    GeoFirePoint geoFirePoint = geo.point(latitude: lat, longitude: lng);
    _firestore
        .collection('locations')
        .add({'name': 'Random Guy ${geoFirePoint.hash} ','isPositive': positive, 'position': geoFirePoint.data}).then((_) {
      print('added ${geoFirePoint.hash} successfully');
    });
  }


  void _addMarker(double lat, double lng, bool positive) {
    MarkerId id = MarkerId(lat.toString() + lng.toString());
    BitmapDescriptor iconPositive;
    String message;
    if(positive){
      iconPositive = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      message = 'This Guy is Positive';
    }
    else{
      iconPositive = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      message = 'This Guy is Cool';
    }
    Marker _marker = Marker(
      markerId: id,
      position: LatLng(lat, lng),
      icon: iconPositive,
      infoWindow: InfoWindow(title:'$message', snippet: '$lat,$lng'),
    );
    setState(() {
      markers[id] = _marker;
    });
  }

  void _updateMarkers(List<DocumentSnapshot> documentList) {
    documentList.forEach((DocumentSnapshot document) {
      GeoPoint point = document.data['position']['geopoint'];
      bool isPositive = document.data['isPositive'];
      _addMarker(point.latitude, point.longitude, isPositive);
      print('marker added to markers');
    });
  }

  double _value = 20.0;
  String _label = '';
  changed(value) {
    setState(() {
      _value = value;
      _label = '${_value.toInt().toString()} kms';
      markers.clear();
    });
    radius.add(value);
  }

  void setCustomMapStyle() async {
    style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
  }

}


