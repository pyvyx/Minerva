import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/svg.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main()
{
  HttpOverrides.global = DevHttpOverrides();
  runApp(CupertinoApp(home: Home(), theme: const CupertinoThemeData(brightness: Brightness.dark)));
}


class DevHttpOverrides extends HttpOverrides
{
  @override
  HttpClient createHttpClient(SecurityContext? context)
  { // accept self signed certificate
    return super.createHttpClient(context)..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
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
  String _TimeSinceLastTrackerSignal = "Never";
  String _TimeSinceLastServerUpdate = "Never";
  final Stopwatch _Stopwatch = Stopwatch()..start();

  Future<void> _OpenMapMobile(double latitude, double longitude) async
  {
    const title = "Car";
    final coords = Coords(latitude, longitude);
    final availableMaps = await MapLauncher.installedMaps;
    if (availableMaps.length == 1)
    {
      await availableMaps.first.showMarker(coords: coords, title: title);
      return;
    }

    List<CupertinoActionSheetAction> actions = [];
    for (var map in availableMaps)
    {
      actions.add(CupertinoActionSheetAction(
        onPressed: () => map.showMarker(coords: coords, title: title,),
        child: CupertinoListTile(
          title: Text(map.mapName),
          leading: SvgPicture.asset(
            map.icon,
            height: 30.0,
            width: 30.0,
          ),
        )
      ));
    }

    showCupertinoModalPopup<void>(context: context, builder: (BuildContext context)
    {
      return CupertinoActionSheet(title: const Text("Information", style: TextStyle(color: Colors.black)), actions: actions);
    });

    // old version
    //showCupertinoModalPopup(
    //  context: context,
    //  builder: (BuildContext context) {
    //    return SafeArea(
    //      child: SingleChildScrollView(
    //        child: Container(
    //          child: Wrap(
    //            children: <Widget>[
    //              for (var map in availableMaps)
    //                CupertinoListTile(
    //                  onTap: () => map.showMarker(
    //                    coords: coords,
    //                    title: title,
    //                  ),
    //                  title: Text(map.mapName),
    //                  leading: SvgPicture.asset(
    //                    map.icon,
    //                    height: 30.0,
    //                    width: 30.0,
    //                  ),
    //                  backgroundColor: Colors.white,
    //                ),
    //            ],
    //          ),
    //        ),
    //      ),
    //    );
    //  },
    //);
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
    Timer? timer = Timer(Duration(milliseconds: 2500), () {
      Navigator.of(context, rootNavigator: true).pop();
    });

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Alert', style: TextStyle(color: Colors.black)),
        actions: [
          Center(child: Text(msg, style: TextStyle(color: Colors.red[600])))
        ]
      ),
    ).then((value) {
      timer?.cancel();
      timer = null;
    });
  }


  String _TimeAsString(int timeInMs)
  {
    if (timeInMs < 60000) return (timeInMs / 1000.0).toStringAsFixed(2) + " seconds";
    else if (timeInMs < 3600000) return (timeInMs / 60000.0).toStringAsFixed(2) + " minutes";
    else return (timeInMs / 3600000.0).toStringAsFixed(2) + " hours";
  }


  void _ParseBody(http.Response response)
  {
    List<String> split = response.body.split(",");
    if (split.length != 5)
    {
      _ShowError("Result is not properly formatted");
      return;
    }

    try
    {
      final double lat = double.parse(split[1]);
      final double lng = double.parse(split[2]);

      int tmp = _Stopwatch.elapsedMilliseconds;
      _TimeSinceLastTrackerSignal = _TimeAsString(int.parse(split[0]) + tmp);
      _TimeSinceLastServerUpdate = _TimeAsString(_Stopwatch.elapsedMilliseconds);
      _Stopwatch.reset();

      if (lat != _Latitude || lng != _Longitude)
      {
        // Will always update the first time because _Latitude = 0 and _Longitude = 0
        // that's a point in the golf of guinea
        print("Update");
        setState(() {
          _Latitude = lat;
          _Longitude = lng;
          _Altitude = int.parse(split[3]);
          _Speed = int.parse(split[4]);
        });
      }
    }
    on FormatException catch (e)
    {
      _ShowError("Failed to parse parameter: '${e.source}' ${e.message}");
    }
    catch(e)
    {
      _ShowError("Unknown exception: ${e.toString()}");
    }
  }


  void _Request()
  {
    /*
        Structure: "time_since_last_update,lat,lng,alt,kmh"
        example: "3000,49.02536179,11.95466600,436,10"

        TODO: alt as int (in tracker), kmh as int and if less then 15 = 0 (in tracker), battery percentage
        TODO: server doesn't need to keep old pos, app is responsible for it

        Authentication:
        User: login
        Pw: 1234
    */

    http.get(Uri.parse('https://192.168.178.90'), headers: {"authorization": 'Basic ${base64.encode(ascii.encode("login:1234"))}'}).then(_ParseBody).catchError((e){_ShowError("Failed to get information: ${e.toString()}");});
  }


  void _ShowInfoSection()
  {
    showCupertinoModalPopup<void>(context: context, builder: (BuildContext context)
    {
      return CupertinoActionSheet(
        title: const Text("Information", style: TextStyle(color: Colors.black)),
        actions: [
          CupertinoActionSheetAction(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                  Row(children: <Widget>[
                    const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Latitude:  ", style: TextStyle(color: Colors.black)))),
                    const VerticalDivider(width: 1.0),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: Text.rich(TextSpan(text: "$_Latitude", style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),))))
                ]),

                Row(children: <Widget>[
                  const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Longitude:  ", style: TextStyle(color: Colors.black)))),
                  const VerticalDivider(width: 1.0),
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: Text.rich(TextSpan(text: "$_Longitude", style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)))))
                ]),
            ]),
            onPressed: () => _OpenMap(_Latitude, _Longitude),
          ),

          CupertinoActionSheetAction(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(children: <Widget>[
                    const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Altitude:  ", style: TextStyle(color: Colors.black)))),
                    const VerticalDivider(width: 1.0),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: Text("$_Altitude meters", style: const TextStyle(color: Colors.black))))
                  ]),

                  Row(children: <Widget>[
                    const Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Speed:  ", style: TextStyle(color: Colors.black)))),
                    const VerticalDivider(width: 1.0),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: Text("$_Speed km/h", style: const TextStyle(color: Colors.black))))
                  ]),

                  Text("\nTime since last tracker signal: $_TimeSinceLastTrackerSignal", style: const TextStyle(color: Colors.black)),
                  Text("Time since last server update: $_TimeSinceLastServerUpdate", style: const TextStyle(color: Colors.black))
                ]),
            onPressed: () => _Request(),
          ),
        ]
      );
    });
  }


  @override
  Widget build(BuildContext context)
  {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => const SettingsPage())), padding: EdgeInsets.zero,  child: const Icon(Icons.settings)),
        middle: const Text("Tracker")
      ),
      child: Center(
          child: Container(
            child: Column(
              children: [
                Flexible(
                  child: FlutterMap(
                    options: MapOptions(center: LatLng(_Latitude, _Longitude), zoom: 8, interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    children: [
                      TileLayer(
                          urlTemplate: ""
                        //urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        //subdomains: ['a', 'b', 'c'],
                        //urlTemplate: "https://mt0.google.com/vt/lyrs=m@221097413&x={x}&y={y}&z={z}",
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(rotate: true, point: LatLng(_Latitude, _Longitude), builder: (ctx) => CupertinoButton(onPressed: _ShowInfoSection, padding: EdgeInsets.zero, child: const Icon(Icons.directions_car)))
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

  // TODO: unmark
  //Timer? _RequestTimer;
  //@override
  //void initState()
  //{
  //  _MakeRequest();
  //}
  //
  //Future<void> _MakeRequest() async
  //{
  //  _RequestTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
  //    _Request();//
  //  });
  //}
//
  //@override
  //void dispose()
  //{
  //  _RequestTimer?.cancel();
  //  super.dispose();
  //}
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


class Settings
{
  static bool darkMode = true;
  static bool useGoogleMaps = false;
  static int maxZoom = 22;
  static int minZoom = 4;
  static int maxNativeZoom = 22;
  static int minNativeZoom = 4;

  static List<int> zoomList = List<int>.generate(30, (i) => i + 1);
}


class SettingsPage extends StatefulWidget
{
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}


class _SettingsPageState extends State<SettingsPage>
{
  void _SelectMapProvider(BuildContext context) async
  {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select map provider'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Settings.useGoogleMaps = true;
              Navigator.pop(context);
            },
            child: const Text('Google Maps'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Settings.useGoogleMaps = false;
              Navigator.pop(context);
            },
            child: const Text('OpenStreetMap'),
          ),
        ],
      ),
    );
    setState((){});
  }


  Future<void> _ShowDialog(Widget child) async
  {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        // The Bottom margin is provided to align the popup above the system navigation bar.
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        // Provide a background color for the popup.
        color: CupertinoColors.systemBackground.resolveFrom(context),
        // Use a SafeArea widget to avoid system overlaps.
        child: SafeArea(
          top: false,
          child: child,
        ),
      ),
    );
  }


  Future<int> _NumberPicker(int idx) async
  {
    int num = idx;
    await _ShowDialog(CupertinoPicker(
      magnification: 1.22,
      squeeze: 1.2,
      useMagnifier: true,
      itemExtent: 32,
      scrollController: FixedExtentScrollController(initialItem: idx),
      onSelectedItemChanged: (int selectedItem) {
        setState(() {
          num = selectedItem;
        });
      },
      children:
      List<Widget>.generate(Settings.zoomList.length, (int index) {
        return Center(child: Text(Settings.zoomList[index].toString()));
      }),
      ),
    );
    return num;
  }


  @override
  Widget build(BuildContext context)
  {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, child: const Icon(Icons.arrow_back_ios_new)),
        middle: const Text("Settings"),
      ),
      child: SafeArea(
        child: SettingsList(
          applicationType: ApplicationType.cupertino,
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(
              title: const Text("Map"),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  title: const Text("Map provider"),
                  leading: const Icon(CupertinoIcons.map),
                  value: Text(Settings.useGoogleMaps ? "Google Maps" : "OpenStreetMap"),
                  onPressed: (context) => _SelectMapProvider(context),
                ),

                SettingsTile.switchTile(
                  title: const Text("Dark mode"),
                  onToggle: (value) => setState(() => Settings.darkMode = value),
                  leading: Icon(Settings.darkMode ? Icons.dark_mode : Icons.sunny),
                  initialValue: Settings.darkMode
                ),

                SettingsTile.navigation(
                  title: const Text("Max zoom"),
                  leading: const Icon(CupertinoIcons.zoom_in),
                  value: Text(Settings.zoomList[Settings.maxZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.maxZoom).then((value) => setState(() { Settings.minZoom = value < Settings.minZoom ? value : Settings.minZoom; Settings.maxZoom = value; })),
                ),

                SettingsTile.navigation(
                  title: const Text("Min zoom"),
                  leading: const Icon(CupertinoIcons.zoom_out),
                  value: Text(Settings.zoomList[Settings.minZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.minZoom).then((value) => setState(() { Settings.maxZoom = value > Settings.maxZoom ? value : Settings.maxZoom; Settings.minZoom = value; })),
                ),

                SettingsTile.navigation(
                  title: const Text("Max native zoom"),
                  leading: const Icon(CupertinoIcons.zoom_in),
                  value: Text(Settings.zoomList[Settings.maxNativeZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.maxNativeZoom).then((value) => setState(() { Settings.minNativeZoom = value < Settings.minNativeZoom ? value : Settings.minNativeZoom; Settings.maxNativeZoom = value; })),
                ),

                SettingsTile.navigation(
                  title: const Text("Min native zoom"),
                  leading: const Icon(CupertinoIcons.zoom_out),
                  value: Text(Settings.zoomList[Settings.minNativeZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.minNativeZoom).then((value) => setState(() { Settings.maxNativeZoom = value > Settings.maxNativeZoom ? value : Settings.maxNativeZoom; Settings.minNativeZoom = value; })),
                )
              ],
            )
          ],
        ),
      )
    );
  }
}

/*
  Settings:
  Map:
  -- select google / open maps
  if google select state (traffic, etc.) and e.g. (roads only)
  -- Dark mode for the map
  -- max zoom
  min zoom
  max native zoom
  min native zoom
  map rotation

  Tracker:
  how long to sleep after send
  coordinate samples to gather before sending
*/