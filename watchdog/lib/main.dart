import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/svg.dart';

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
  int _Altitude = 0;
  int _Speed = 0;
  String _TimeSinceLastTrackerSignal = "";
  String _TimeSinceLastServerUpdate = "";
  final Stopwatch _Stopwatch = Stopwatch()..start();

  Future<void> _OpenMapMobile(double latitude, double longitude) async
  {
    try
    {
      const title = "Car";
      final coords = Coords(latitude, longitude);
      final availableMaps = await MapLauncher.installedMaps;
      if (availableMaps.length == 1)
      {
        await availableMaps.first.showMarker(coords: coords, title: title);
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Container(
                child: Wrap(
                  children: <Widget>[
                    for (var map in availableMaps)
                      ListTile(
                        onTap: () => map.showMarker(
                          coords: coords,
                          title: title,
                        ),
                        title: Text(map.mapName),
                        leading: SvgPicture.asset(
                          map.icon,
                          height: 30.0,
                          width: 30.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
    catch (e)
    {
      print(e);
    }
  }

  Future<void> _OpenMap(double latitude, double longitude) async
  {
    if (Platform.isAndroid || Platform.isIOS)
    {
      await _OpenMapMobile(latitude, longitude);
      return;
    }

    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(url))
    {
      await launchUrl(url);
    }
    else
    {
      _ShowError("Could not open the map");
    }
  }


  void _ShowError(String msg)
  {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      dismissDirection: DismissDirection.down,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red[400],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ));
  }


  String _TimeAsString(int timeInMs)
  {
    if (timeInMs < 60000) return (timeInMs / 1000.0).toStringAsFixed(2) + " seconds";
    else if (timeInMs < 3600000) return (timeInMs / 60000.0).toStringAsFixed(2) + " minutes";
    else return (timeInMs / 3600000.0).toStringAsFixed(2) + " hours";
  }

  void _Request()
  {
    /*
        Structure: "time_since_last_update,oldLat,oldLng,lat,lng,alt,kmh"
        example: "3000,31.1290,59.138193,49.02536179,11.95466600,436,10"

        TODO: alt as int (in tracker), kmh as int and if less then 15 = 0 (in tracker)

        Authentication:
        User: login
        Pw: 1234
    */
    final String result = "3512,31.1290,59.138193,49.02536179,11.95466600,436,10";
    List<String> split = result.split(",");
    if (split.length != 7)
    {
      _ShowError("Result is not properly formatted");
      return;
    }

    try
    {
      final double lat = double.parse(split[3]);
      final double lng = double.parse(split[4]);

      if (lat != _Latitude || lng != _Longitude)
      {
        // Will always update the first time because _Latitude = 0 and _Longitude = 0
        // that's a point in the golf of guinea
        setState(() {
          _Latitude = lat;
          _Longitude = lng;
          _TimeSinceLastTrackerSignal = _TimeAsString(int.parse(split[0]));
          _Altitude = int.parse(split[5]);
          _Speed = int.parse(split[6]);

          _TimeSinceLastServerUpdate = _TimeAsString(_Stopwatch.elapsedMilliseconds);
          _Stopwatch.reset();
        });
      }
    }
    on FormatException catch (e)
    {
      _ShowError("Failed to parse parameter: '${e.source}' ${e.message}");
      return;
    }
    catch(e)
    {
      _ShowError("Unknown exception: ${e.toString()}");
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
              Row(children: <Widget>[
                  const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Latitude:  "))),
                  const VerticalDivider(width: 1.0),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: Text.rich(TextSpan(text: "$_Latitude", style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () => _OpenMap(_Latitude, _Longitude)))))
              ]),

              Row(children: <Widget>[
                const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Longitude:  "))),
                const VerticalDivider(width: 1.0),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: Text.rich(TextSpan(text: "$_Longitude", style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold, decoration: TextDecoration.underline), recognizer: TapGestureRecognizer()..onTap = () => _OpenMap(_Latitude, _Longitude)))))
              ]),

              Row(children: <Widget>[
                const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Altitude:  "))),
                const VerticalDivider(width: 1.0),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: Text("$_Altitude meters")))
              ]),

              Row(children: <Widget>[
                const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Speed:  "))),
                const VerticalDivider(width: 1.0),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: Text("$_Speed km/h")))
              ]),

              Text("\nTime since last tracker signal: $_TimeSinceLastTrackerSignal"),
              Text("Time since last server update: $_TimeSinceLastServerUpdate")
            ],
          )
        )
      );
    });
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
                    options: MapOptions(center: LatLng(_Latitude, _Longitude), zoom: 8),
                    children: [
                      TileLayer(
                          urlTemplate: ""
                        //urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                        //urlTemplate: "https://mt0.google.com/vt/lyrs=m@221097413&x={x}&y={y}&z={z}",
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(rotate: true, point: LatLng(_Latitude, _Longitude), builder: (ctx) => IconButton(onPressed: _Request, icon: const Icon(Icons.directions_car)))
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