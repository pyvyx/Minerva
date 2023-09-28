import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

class _HomeState extends State<Home>
{
  double _Latitude = 0;
  double _Longitude = 0;
  double _Altitude = 0;
  double _Speed = 0; // kmph

  void _Request()
  {
    /*
        Structure: "lat,lng,alt,kmh"
        example: "49.02536179,11.95466600,436.79907407,0.14565581"

        Authentication:
        User: login
        Pw: 1234
    */
    final String result = "12.12345678,49.274982,465,0.1489";
    List<String> split = result.split(",");
    if (split.length != 4)
    {
      print("Result is not properly formatted");
      return;
    }

    try
    {
      _Latitude = double.parse(split[0]);
      _Longitude = double.parse(split[1]);
      _Altitude = double.parse(split[2]);
      _Speed = double.parse(split[3]);
    }
    on FormatException catch (e)
    {
      print("Failed to parse parameter: '${e.source}' ${e.message}");
    }

    showModalBottomSheet(context: context, builder: (BuildContext context)
    {
      return SizedBox(
        height: 200,
        child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    text: "Latitude: ",
                    children: <TextSpan>[
                      TextSpan(text: "$_Latitude", style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () => print('Tap Here onTap'))
                    ]
                )),

                Text.rich(
                    TextSpan(
                        text: "Longitude: ",
                        children: <TextSpan>[
                          TextSpan(text: "$_Longitude", style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () => print('Tap Here onTap'))
                        ]
                    )),
                
                Text("Altitude: $_Altitude"),
                Text("Speed: $_Speed")
              ],
            )
        )
      );
    });

    print(_Latitude);
    print(_Longitude);
    print(_Altitude);
    print(_Speed);
  }

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
                        urlTemplate: ''
                        //urlTemplate: "https://mt0.google.com/vt/lyrs=m@221097413&x={x}&y={y}&z={z}",
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(point: LatLng(52.520008, 13.404954), builder: (ctx) => IconButton(onPressed: _Request, icon: const Icon(Icons.directions_car)))
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