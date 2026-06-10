import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:slyce/core/theme/app_theme.dart';

/// Full-screen map (styled to match the order-tracking map) where the user
/// picks their delivery location. They can either tap anywhere on the map or
/// search for a place by name. The exact tapped/selected latitude & longitude
/// are returned via Navigator.pop. No hard-coded location is saved.
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

/// A single place suggestion returned from the geocoding search.
class _PlaceResult {
  final String name;
  final LatLng point;
  const _PlaceResult(this.name, this.point);
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Neutral starting view (Cairo) when there is no previously chosen point.
  static const _fallbackCenter = LatLng(30.0444, 31.2357);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Dio _geocodeDio = Dio();

  // The pin the user dropped / selected; null until they choose.
  LatLng? _selected;
  List<_PlaceResult> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  LatLng get _initialCenter => widget.initial ?? _fallbackCenter;

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() => _results = []);
      return;
    }
    // Debounce to respect the public geocoder's rate limit.
    _debounce =
        Timer(const Duration(milliseconds: 450), () => _searchPlaces(query));
  }

  /// Looks up matching places by name using the free OpenStreetMap Nominatim
  /// geocoder (no API key). Returns real coordinates — no hard-coded data.
  Future<void> _searchPlaces(String query) async {
    setState(() => _searching = true);
    try {
      final resp = await _geocodeDio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 8,
          'addressdetails': 0,
          // Return place names in Arabic when available, falling back to
          // English. Arabic queries already work (UTF-8); this makes the
          // suggestions readable in both languages.
          'accept-language': 'ar,en',
        },
        options: Options(
          headers: {
            'User-Agent': 'com.slyce.app (delivery address search)',
          },
        ),
      );
      final data = resp.data;
      final list = <_PlaceResult>[];
      if (data is List) {
        for (final item in data) {
          final lat = double.tryParse('${item['lat']}');
          final lon = double.tryParse('${item['lon']}');
          final name = item['display_name']?.toString() ?? '';
          if (lat != null && lon != null && name.isNotEmpty) {
            list.add(_PlaceResult(name, LatLng(lat, lon)));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _results = list;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  void _selectPlace(_PlaceResult place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = place.point;
      _results = [];
      _searchController.text = place.name;
    });
    _mapController.move(place.point, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: selected ?? _initialCenter,
              initialZoom: 14.5,
              onTap: (tapPosition, point) {
                // Drop / move the pin wherever the user taps and read its
                // exact latitude & longitude.
                FocusScope.of(context).unfocus();
                setState(() {
                  _selected = point;
                  _results = [];
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.slyce.app',
              ),
              if (selected != null)
                MarkerLayer(
                  markers: [
                    _marker(selected, Icons.location_on, kPrimaryGreen),
                  ],
                ),
            ],
          ),
          _buildSearchHeader(context),
          _buildConfirmBar(context),
        ],
      ),
    );
  }

  /// Circular marker styled exactly like the order-tracking map's markers.
  Marker _marker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 42,
      height: 42,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: kWhite, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 8),
          ],
        ),
        child: Icon(icon, color: kWhite, size: 20),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: kWhite,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x22000000), blurRadius: 8),
                    ],
                  ),
                  child:
                      const Icon(Icons.arrow_back, color: kDarkColor, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: kWhite,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: kGreyColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (v) {
                            final q = v.trim();
                            if (q.length >= 3) _searchPlaces(q);
                          },
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: kDarkColor,
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search for a place or address',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14,
                              color: kGreyColor,
                            ),
                          ),
                        ),
                      ),
                      if (_searching)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                            setState(() => _results = []);
                          },
                          child: const Icon(
                            Icons.close,
                            color: kGreyColor,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, left: 54),
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 8),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: kLightGrey),
                itemBuilder: (context, i) {
                  final r = _results[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.location_on,
                      color: kPrimaryGreen,
                      size: 20,
                    ),
                    title: Text(
                      r.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kDarkColor,
                      ),
                    ),
                    onTap: () => _selectPlace(r),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmBar(BuildContext context) {
    final selected = _selected;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        decoration: const BoxDecoration(
          color: kBgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selected == null ? 'No location selected' : 'Selected location',
              style: GoogleFonts.inter(fontSize: 13, color: kGreyColor),
            ),
            const SizedBox(height: 4),
            Text(
              selected == null
                  ? 'Tap on the map or search to pick a spot'
                  : '${selected.latitude.toStringAsFixed(6)}, '
                      '${selected.longitude.toStringAsFixed(6)}',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kDarkColor,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selected == null ? kGreyColor : kPrimaryGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Confirm location',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kWhite,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
