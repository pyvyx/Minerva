import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main()
{
  runApp(MaterialApp(home: Home()));
}

class Home extends StatefulWidget
{
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Container(
            child: Column(
              children: [
                Flexible(
                  child: FlutterMap(
                    options: MapOptions(center: LatLng(52.520008, 13.404954), zoom: 8),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                        //urlTemplate: "https://mt0.google.com/vt/lyrs=m@221097413&x={x}&y={y}&z={z}",
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(point: LatLng(52.520008, 13.404954), builder: (ctx) => Icon(Icons.directions_car))
                        ]
                      )
                    ],
                  )
                )
              ],
            )
          )
      )
    );
  }
}


/*
https://github.com/fleaflet/flutter_map/issues/1058
Ok, so here is the base URL:
https://mt0.google.com/vt/lyrs=m@221097413,traffic,transit,bike&x={x}&y={y}&z={z}

To change overlays, remove 'traffic', 'transit' or 'bike'.

To change style, replace 'm' with any of the following:

h: Roads only
m: Standard roadmap
p: Terrain
r: Different roadmap
s: Satellite only
t: Terrain only
y: Hybrid
It may be possible to mix and match these but I'm not 100% sure.

Use at your own risk and responsibility.
*/