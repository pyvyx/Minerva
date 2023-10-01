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
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterMapTileCaching.initialise();
  await FMTC.instance('mapStore').manage.createAsync();
  HttpOverrides.global = DevHttpOverrides();
  Settings.ReadSettings();
  runApp(const App());
}


class DevHttpOverrides extends HttpOverrides
{
  @override
  HttpClient createHttpClient(SecurityContext? context)
  { // accept self signed certificate
    return super.createHttpClient(context)..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}


class App extends StatefulWidget
{
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App>
{
  void _UpdateApp(dynamic)
  {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(home: Home(updateApp: _UpdateApp), theme: CupertinoThemeData(brightness: Settings.darkModeApp ? Brightness.dark : Brightness.light));
  }

  @override
  void dispose()
  {
    Settings.SaveSettings(true);
    super.dispose();
  }
}



class Home extends StatefulWidget
{
  final ValueChanged updateApp;
  const Home({super.key, required this.updateApp});

  @override
  _HomeState createState() => _HomeState(updateApp: updateApp);
}


class _HomeState extends State<Home>
{
  final ValueChanged updateApp;
  _HomeState({required this.updateApp});

  static double _Latitude = 0;
  static double _Longitude = 0;
  static int _Altitude = 0;
  static int _Speed = 0;
  static int _TimeSinceLastTrackerSignal = 0;
  static int _TimeSinceLastServerUpdate = 0;
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
      return CupertinoActionSheet(title: const Text("Select app"), actions: actions);
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

    bool cont = true;
    String u = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (Platform.isMacOS)
    {
      await showCupertinoModalPopup<void>(context: context, builder: (BuildContext context)
      {
        return CupertinoActionSheet(title: const Text("Select app"),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () { u = "https://maps.apple.com/?q=$latitude,$longitude"; Navigator.pop(context); },
              child: const Text("Apple Maps")
            ),

            CupertinoActionSheetAction(
                onPressed: () { u = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'; Navigator.pop(context);  },
                child: const Text("Google Maps")
            )
          ],
          cancelButton: CupertinoActionSheetAction(
              onPressed: () { Navigator.pop(context); cont = false; },
              isDestructiveAction: true,
              child: const Text("Cancel")
          ),
        );
      });
    }
    if (!cont) return;

    final Uri url = Uri.parse(u);
    if (await canLaunchUrl(url))
    {
      await launchUrl(url);
    }
    else
    {
      _ShowError(context, "Could not open the map");
    }
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
      _ShowError(context, "Result is not properly formatted");
      return;
    }

    try
    {
      final double lat = double.parse(split[1]);
      final double lng = double.parse(split[2]);

      int tmp = _Stopwatch.elapsedMilliseconds;
      _TimeSinceLastTrackerSignal = int.parse(split[0]) + tmp;
      _TimeSinceLastServerUpdate = tmp;
      _Stopwatch.reset();

      if (lat != _Latitude || lng != _Longitude)
      {
        // Will always update the first time because _Latitude = 0 and _Longitude = 0
        // that's a point in the golf of guinea
        setState(() {
          _Latitude = lat;
          _Longitude = lng;
          _Altitude = int.parse(split[3]);
          _Speed = int.parse(split[4]) < 10 ? 0 : int.parse(split[4]);
        });
      }
      Settings.SaveSettings(false);
    }
    on FormatException catch (e)
    {
      _ShowError(context, "Failed to parse parameter: '${e.source}' ${e.message}");
    }
    catch(e)
    {
      _ShowError(context, "Unknown exception: ${e.toString()}");
    }
  }


  void _Request()
  {
    /*
        Structure: "time_since_last_update,lat,lng,alt,kmh"
        example: "3000,49.02536179,11.95466600,436,10"

        Authentication:
        User: login
        Pw: 1234
    */

    http.get(Uri.parse('https://${Settings.serverIp}'), headers: {"authorization": 'Basic ${base64.encode(ascii.encode(Settings.serverAuth))}'}).then(_ParseBody).catchError((e){_ShowError(context, "Failed to get information: ${e.toString()}");});
  }


  void _ShowInfoSection()
  {
    _TimeSinceLastTrackerSignal += _Stopwatch.elapsedMilliseconds;
    _TimeSinceLastServerUpdate += _Stopwatch.elapsedMilliseconds;
    _Stopwatch.reset();
    
    showCupertinoModalPopup<void>(context: context, builder: (BuildContext context)
    {
      return CupertinoActionSheet(
        title: const Text("Information"),
        actions: [
          CupertinoActionSheetAction(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Latitude:  ", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color)))),
                    const VerticalDivider(width: 1.0),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: Text.rich(TextSpan(text: "$_Latitude", style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),))))
                ]),

                Row(children: <Widget>[
                  Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Longitude:  ", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color)))),
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
                    Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Altitude:  ", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color)))),
                    const VerticalDivider(width: 1.0),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: Text("$_Altitude meters", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color))))
                  ]),

                  Row(children: <Widget>[
                    Expanded(child: Align(alignment: Alignment.centerRight, child: Text("Speed:  ", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color)))),
                    const VerticalDivider(width: 1.0),
                    Expanded(child: Align(alignment: Alignment.centerLeft, child: Text("$_Speed km/h", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color))))
                  ]),

                  Text("\nTime since last tracker signal: ${_TimeAsString(_TimeSinceLastTrackerSignal)}", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color)),
                  Text("Time since last server update: ${_TimeAsString(_TimeSinceLastServerUpdate)}", style: TextStyle(color: CupertinoTheme.of(context).textTheme.textStyle.color))
                ]),
            onPressed: () => _Request(),
          ),
        ]
      );
    });
  }


  void _UpdateHomePage(dynamic)
  {
    setState(() {});
  }


  @override
  Widget build(BuildContext context)
  {
    if (Settings.serverRequestChanged) { _MakeRequest(); Settings.serverRequestChanged = false; }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsPage(updateHomePage: _UpdateHomePage, updateApp: updateApp))), padding: EdgeInsets.zero,  child: const Icon(Icons.settings)),
        middle: const Text("Tracker")
      ),
      child: Center(
        child: Column(
          children: [
            Flexible(
              child: FlutterMap(
                options: MapOptions(
                  maxZoom: Settings.zoomList[Settings.maxZoom].toDouble(),
                  minZoom: Settings.zoomList[Settings.minZoom].toDouble(),
                  center: LatLng(_Latitude, _Longitude),
                  zoom: 14,
                  interactiveFlags: Settings.mapRotation ? InteractiveFlag.all : InteractiveFlag.all & ~InteractiveFlag.rotate
                ),
                children: [
                  TileLayer(
                    tileProvider: FMTC.instance('mapStore').getTileProvider(),
                    maxNativeZoom: Settings.zoomList[Settings.maxNativeZoom],
                    minNativeZoom: Settings.zoomList[Settings.minNativeZoom],
                    urlTemplate: Settings.MapProviderLink(),
                    tileBuilder: !Settings.darkMode ? null : (BuildContext context, Widget tileWidget, TileImage tile) {
                      return ColorFiltered(colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                      ]),
                      child: tileWidget);
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(rotate: true, point: LatLng(_Latitude, _Longitude), builder: (ctx) => CupertinoButton(color: Colors.deepOrangeAccent, onPressed: _ShowInfoSection, padding: EdgeInsets.zero, child: Icon(Icons.directions_car, color: Colors.grey[400])))
                    ]
                  )
                ],
              )
            )
          ],
        )
      )
    );
  }


  Timer? _RequestTimer;
  @override
  void initState()
  {
    _MakeRequest();
  }

  Future<void> _MakeRequest() async
  {
    _Request();
    _RequestTimer = Timer.periodic(Settings.serverRequestVar, (timer) {
      _Request();
    });
  }

  @override
  void dispose()
  {
    _RequestTimer?.cancel();
    super.dispose();
  }
}


void _ShowError(BuildContext context, String msg)
{
  if (!context.mounted) return;

  Timer? timer = Timer(const Duration(milliseconds: 2500), () {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  });

  showCupertinoModalPopup<void>(
    context: context,
    builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Alert'),
        actions: [
          Center(child: Text(msg, style: TextStyle(color: Colors.red[600])))
        ]
    ),
  ).then((value) {
    timer?.cancel();
    timer = null;
  });
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
  // app settings
  static bool darkModeApp = true;
  static Duration serverRequestVar = const Duration(seconds: 45);
  static bool serverRequestChanged = false;

  static set serverRequest(Duration d) { serverRequestVar = d; serverRequestChanged = true; }
  static Duration get serverRequest => serverRequestVar;

  // map settings
  static bool darkMode = false;
  static int mapProvider = 0; // 0 = open street map, 1 = google maps
  static bool mapRotation = false;
  static int maxZoom = 17;
  static int minZoom = 0;
  static int maxNativeZoom = 10;
  static int minNativeZoom = 0;
  static List<int> zoomList = List<int>.generate(18, (i) => i + 1);

  static String MapProviderLink()
  {
    switch(mapProvider)
    {
      case 1:
        // "http://gsp2.apple.com/tile?api=1&style=slideshow&layers=default&lang=en_US&z={z}&x={x}&y={y}&v=9"
        return "https://mt0.google.com/vt/lyrs=m@221097413&x={x}&y={y}&z={z}";
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'; //subdomains: ['a', 'b', 'c'],
    }
  }

  // tracker settings
  static bool trackerApproved = true;
  static bool updateTracker = false;
  static Duration sleepAfterSendVar = const Duration(seconds: 45);
  static Duration sleepBetweenSamplesVar = const Duration(seconds: 1);
  static Duration sleepWhileNoSignalVar = const Duration(seconds: 3);
  static int samplesBeforeSendVar = 2;
  static List<int> samplesList = List<int>.generate(60, (i) => i + 1);

  static void set sleepAfterSend(Duration s) { updateTracker = true; sleepAfterSendVar = s; }
  static void set sleepBetweenSamples(Duration s) { updateTracker = true; sleepBetweenSamplesVar = s; }
  static void set sleepWhileNoSignal(Duration s) { updateTracker = true; sleepWhileNoSignalVar = s; }
  static void set samplesBeforeSend(int s) { updateTracker = true; samplesBeforeSendVar = s; }

  static Duration get sleepAfterSend => sleepAfterSendVar;
  static Duration get sleepBetweenSamples => sleepBetweenSamplesVar;
  static Duration get sleepWhileNoSignal => sleepWhileNoSignalVar;
  static int get samplesBeforeSend => samplesBeforeSendVar;

  static String _BuildTrackerBody()
  {
    return sleepAfterSendVar.inMilliseconds.toString() + "," + sleepBetweenSamplesVar.inMilliseconds.toString() + "," + samplesList[samplesBeforeSendVar].toString() + "," + sleepWhileNoSignalVar.inMilliseconds.toString();
  }

  static Future<void> UpdateTracker(BuildContext context) async
  {
    try
    {
      await http.post(Uri.parse('https://${Settings.serverIp}/settings/tracker'), headers: {"authorization": 'Basic ${base64.encode(ascii.encode(Settings.serverAuth))}'}, body: _BuildTrackerBody());
      updateTracker = false;
      trackerApproved = false;
    }
    catch (e)
    {
      _ShowError(context, "Failed to post tracker settings: ${e.toString()}");
    }
  }

  // server settings
  static String serverIp = "192.168.178.90";
  static String serverAuth = "login:1234";


  static T _GetSetting<T>(T? ret, T defaultValue)
  {
    return ret ?? defaultValue;
  }

  static void ReadSettings() async
  {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    darkModeApp = _GetSetting(prefs.getBool("darkModeApp"), true);
    serverRequestChanged = _GetSetting(prefs.getBool("serverRequestChanged"), false);
    serverRequestVar = Duration(seconds: _GetSetting(prefs.getInt("serverRequestVar"), 45));

    darkMode = _GetSetting(prefs.getBool("darkMode"), false);
    mapProvider = _GetSetting(prefs.getInt("mapProvider"), 0);
    mapRotation = _GetSetting(prefs.getBool("mapRotation"), false);
    maxZoom = _GetSetting(prefs.getInt("maxZoom"), 17);
    minZoom = _GetSetting(prefs.getInt("minZoom"), 0);
    maxNativeZoom = _GetSetting(prefs.getInt("maxNativeZoom"), 10);
    minNativeZoom = _GetSetting(prefs.getInt("minNativeZoom"), 0);

    trackerApproved = _GetSetting(prefs.getBool("trackerApproved"), true);
    updateTracker = _GetSetting(prefs.getBool("updateTracker"), false);
    sleepAfterSendVar = Duration(seconds: _GetSetting(prefs.getInt("sleepAfterSendVar"), 45));
    sleepBetweenSamplesVar = Duration(seconds: _GetSetting(prefs.getInt("sleepBetweenSamplesVar"), 1));
    sleepWhileNoSignalVar = Duration(seconds: _GetSetting(prefs.getInt("sleepWhileNoSignalVar"), 3));
    samplesBeforeSendVar = _GetSetting(prefs.getInt("samplesBeforeSendVar"), 2);

    _HomeState._Latitude = _GetSetting(prefs.getDouble("_HomeState._Latitude"), 0);
    _HomeState._Longitude = _GetSetting(prefs.getDouble("_HomeState._Longitude"), 0);
    _HomeState._Altitude = _GetSetting(prefs.getInt("_HomeState._Altitude"), 0);
    _HomeState._Speed = _GetSetting(prefs.getInt("_HomeState._Speed"), 0);
    _HomeState._TimeSinceLastTrackerSignal = _GetSetting(prefs.getInt("_HomeState._TimeSinceLastTrackerSignal"), 0);
    _HomeState._TimeSinceLastServerUpdate = _GetSetting(prefs.getInt("_HomeState._TimeSinceLastServerUpdate"), 0);
   }


  static Future<void> SaveSettings(bool saveSettings) async
  {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (saveSettings)
    {
      await prefs.setBool("darkModeApp", darkModeApp);
      await prefs.setBool("serverRequestChanged", serverRequestChanged);
      await prefs.setInt("serverRequestVar", serverRequestVar.inSeconds);

      await prefs.setBool("darkMode", darkMode);
      await prefs.setInt("mapProvider", mapProvider);
      await prefs.setBool("mapRotation", mapRotation);
      await prefs.setInt("maxZoom", maxZoom);
      await prefs.setInt("minZoom", minZoom);
      await prefs.setInt("maxNativeZoom", maxNativeZoom);
      await prefs.setInt("minNativeZoom", minNativeZoom);

      await prefs.setBool("trackerApproved", trackerApproved);
      await prefs.setBool("updateTracker", updateTracker);
      await prefs.setInt("sleepAfterSendVar", sleepAfterSendVar.inSeconds);
      await prefs.setInt("sleepBetweenSamplesVar", sleepBetweenSamplesVar.inSeconds);
      await prefs.setInt("sleepWhileNoSignalVar", sleepWhileNoSignalVar.inSeconds);
      await prefs.setInt("samplesBeforeSendVar", samplesBeforeSendVar);
    }
    else
    {
      await prefs.setDouble("_HomeState._Latitude", _HomeState._Latitude);
      await prefs.setDouble("_HomeState._Longitude", _HomeState._Longitude);
      await prefs.setInt("_HomeState._Altitude", _HomeState._Altitude);
      await prefs.setInt("_HomeState._Speed", _HomeState._Speed);
      await prefs.setInt("_HomeState._TimeSinceLastTrackerSignal", _HomeState._TimeSinceLastTrackerSignal);
      await prefs.setInt("_HomeState._TimeSinceLastServerUpdate", _HomeState._TimeSinceLastServerUpdate);
    }
  }
}


class SettingsPage extends StatefulWidget
{
  final ValueChanged updateApp;
  final ValueChanged updateHomePage;
  const SettingsPage({super.key, required this.updateHomePage, required this.updateApp});

  @override
  State<SettingsPage> createState() => _SettingsPageState(updateHomePage: updateHomePage, updateApp: updateApp);
}


class _SettingsPageState extends State<SettingsPage>
{
  final ValueChanged updateApp;
  final ValueChanged updateHomePage;
  _SettingsPageState({required this.updateHomePage, required this.updateApp});

  void _SelectMapProvider(BuildContext context) async
  {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select map provider'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Settings.mapProvider = 0;
              Navigator.pop(context);
            },
            child: const Text('OpenStreetMap'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Settings.mapProvider = 1;
              Navigator.pop(context);
            },
            child: const Text('Google Maps'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
            },
            isDestructiveAction: true,
            child: const Text('Cancel')
          )
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


  Future<int> _NumberPicker(int idx, List<int> list) async
  {
    await _ShowDialog(CupertinoPicker(
      magnification: 1.22,
      squeeze: 1.2,
      useMagnifier: true,
      itemExtent: 32,
      scrollController: FixedExtentScrollController(initialItem: idx),
      onSelectedItemChanged: (int selectedItem) {
        setState(() {
          idx = selectedItem;
        });
      },
      children:
      List<Widget>.generate(list.length, (int index) {
        return Center(child: Text(list[index].toString()));
      }),
      ),
    );
    return idx;
  }


  Future<Duration> _TimerPicker(Duration duration) async
  {
    await _ShowDialog(
      CupertinoTimerPicker(
        mode: CupertinoTimerPickerMode.hms,
        initialTimerDuration: duration,
        onTimerDurationChanged: (Duration newDuration) {
          setState(() => duration = newDuration);
        },
      ),
    );
    return duration;
  }


  @override
  Widget build(BuildContext context)
  {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(onPressed: () { Settings.SaveSettings(true).then((e){Navigator.pop(context); updateHomePage(1);}); }, padding: EdgeInsets.zero, child: const Icon(Icons.arrow_back_ios_new)),
        middle: const Text("Settings"),
      ),
      child: SafeArea(
        child: SettingsList(
          applicationType: ApplicationType.cupertino,
          platform: DevicePlatform.iOS,
          sections: [
            SettingsSection(
              title: const Text("Common"),
              tiles: <SettingsTile>[
                SettingsTile.switchTile(
                    title: const Text("Dark mode"),
                    onToggle: (value) => setState(() { Settings.darkModeApp = value; updateApp(1); }),
                    leading: Icon(Settings.darkModeApp ? Icons.dark_mode : Icons.sunny),
                    initialValue: Settings.darkModeApp
                ),

                SettingsTile.navigation(
                    title: const Text("Server request"),
                    leading: const Icon(CupertinoIcons.time_solid),
                    value: Text(Settings.serverRequestVar.toString().split(".")[0]),
                    onPressed: (context) => _TimerPicker(Settings.serverRequestVar).then((value) => setState(() => Settings.serverRequest = value))
                )
              ]
            ),

            SettingsSection(
              title: const Text("Map"),
              tiles: <SettingsTile>[
                SettingsTile.navigation(
                  title: const Text("Provider"),
                  leading: const Icon(CupertinoIcons.map),
                  value: Text(Settings.mapProvider == 0 ? "OpenStreetMap" : "Google Maps"),
                  onPressed: (context) => _SelectMapProvider(context),
                ),

                SettingsTile.switchTile(
                  title: const Text("Dark mode"),
                  onToggle: (value) => setState(() => Settings.darkMode = value),
                  leading: Icon(Settings.darkMode ? Icons.dark_mode : Icons.sunny),
                  initialValue: Settings.darkMode
                ),

                SettingsTile.switchTile(
                  title: const Text("Rotation"),
                  onToggle: (value) => setState(() => Settings.mapRotation = value),
                  leading: const Icon(CupertinoIcons.crop_rotate),
                  initialValue: Settings.mapRotation
                ),

                SettingsTile.navigation(
                  title: const Text("Max zoom"),
                  leading: const Icon(CupertinoIcons.zoom_in),
                  value: Text(Settings.zoomList[Settings.maxZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.maxZoom, Settings.zoomList).then((value) => setState(() { Settings.minZoom = value < Settings.minZoom ? value : Settings.minZoom; Settings.maxZoom = value; })),
                ),

                SettingsTile.navigation(
                  title: const Text("Min zoom"),
                  leading: const Icon(CupertinoIcons.zoom_out),
                  value: Text(Settings.zoomList[Settings.minZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.minZoom, Settings.zoomList).then((value) => setState(() { Settings.maxZoom = value > Settings.maxZoom ? value : Settings.maxZoom; Settings.minZoom = value; })),
                ),

                SettingsTile.navigation(
                  title: const Text("Max native zoom"),
                  leading: const Icon(CupertinoIcons.zoom_in),
                  value: Text(Settings.zoomList[Settings.maxNativeZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.maxNativeZoom, Settings.zoomList).then((value) => setState(() { Settings.minNativeZoom = value < Settings.minNativeZoom ? value : Settings.minNativeZoom; Settings.maxNativeZoom = value; })),
                ),

                SettingsTile.navigation(
                  title: const Text("Min native zoom"),
                  leading: const Icon(CupertinoIcons.zoom_out),
                  value: Text(Settings.zoomList[Settings.minNativeZoom].toString()),
                  onPressed: (context) => _NumberPicker(Settings.minNativeZoom, Settings.zoomList).then((value) => setState(() { Settings.maxNativeZoom = value > Settings.maxNativeZoom ? value : Settings.maxNativeZoom; Settings.minNativeZoom = value; })),
                )
              ],
            ),

            SettingsSection(
              title: const Text("Tracker"),
              tiles: <SettingsTile>[
                SettingsTile(
                  enabled: Settings.updateTracker,
                  title: Settings.updateTracker ? const Text("Update") : Text(Settings.trackerApproved ? "Approved" : "Pending"),
                  leading: Settings.updateTracker ? const Icon(Icons.update) : Icon(Settings.trackerApproved ? CupertinoIcons.check_mark : Icons.pending),
                  onPressed: (context) => Settings.UpdateTracker(context).then((a){initState(); setState(() {});}),
                ),

                SettingsTile.navigation(
                  title: const Text("Sleep after send"),
                  leading: const Icon(CupertinoIcons.time_solid),
                  value: Text(Settings.sleepAfterSendVar.toString().split(".")[0]),
                  onPressed: (context) => _TimerPicker(Settings.sleepAfterSendVar).then((value) => setState(() => Settings.sleepAfterSend = value))
                ),

                SettingsTile.navigation(
                    title: const Text("Sleep between samples"),
                    leading: const Icon(CupertinoIcons.time_solid),
                    value: Text(Settings.sleepBetweenSamplesVar.toString().split(".")[0]),
                    onPressed: (context) => _TimerPicker(Settings.sleepBetweenSamplesVar).then((value) => setState(() => Settings.sleepBetweenSamples = value))
                ),

                SettingsTile.navigation(
                  title: const Text("Samples"),
                  leading: const Icon(CupertinoIcons.archivebox_fill),
                  value: Text(Settings.samplesList[Settings.samplesBeforeSendVar].toString()),
                  onPressed: (context) => _NumberPicker(Settings.samplesBeforeSendVar, Settings.samplesList).then((value) => setState(() { Settings.samplesBeforeSend = value; })),
                ),

                SettingsTile.navigation(
                    title: const Text("Sleep while no signal"),
                    leading: const Icon(CupertinoIcons.time_solid),
                    value: Text(Settings.sleepWhileNoSignalVar.toString().split(".")[0]),
                    onPressed: (context) => _TimerPicker(Settings.sleepWhileNoSignalVar).then((value) => setState(() => Settings.sleepWhileNoSignal = value))
                )
              ],
            )
          ],
        ),
      )
    );
  }


  Timer? _RequestTimer;
  @override
  void initState()
  {
    if (!Settings.trackerApproved) _MakeRequest();
  }

  Future<void> _MakeRequest() async
  {
    http.get(Uri.parse('https://${Settings.serverIp}/settings/tracker/status'), headers: {"authorization": 'Basic ${base64.encode(ascii.encode(Settings.serverAuth))}'}).then((response) {
      setState(() {
        Settings.trackerApproved = response.statusCode == 203;
      });
      _RequestTimer?.cancel();
      _RequestTimer = null;
    }).catchError((e){_ShowError(context, "Failed to get settings status: ${e.toString()}");});

    _RequestTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      http.get(Uri.parse('https://${Settings.serverIp}/settings/tracker/status'), headers: {"authorization": 'Basic ${base64.encode(ascii.encode(Settings.serverAuth))}'}).then((response) {
        setState(() {
          Settings.trackerApproved = response.statusCode == 203;
        });
        _RequestTimer?.cancel();
        _RequestTimer = null;
      }).catchError((e){_ShowError(context, "Failed to get settings status: ${e.toString()}");});
    });
  }

  @override
  void dispose()
  {
    _RequestTimer?.cancel();
    _RequestTimer = null;
    super.dispose();
  }
}

/*
  Settings:
  Map:
  -- select google / open maps
  if google select state (traffic, etc.) and e.g. (roads only)
  -- Dark mode for the map
  -- max zoom
  -- min zoom
  -- max native zoom
  -- min native zoom
  -- map rotation

  Tracker:
  -- how long to sleep after send
  -- time to sleep between samples
  -- coordinate samples to gather before sending
*/