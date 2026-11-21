import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masjid_namaz_app/core/utils/location_helper.dart';

class LocationInputWidget extends StatefulWidget {
  final TextEditingController latController;
  final TextEditingController lngController;
  final TextEditingController mapUrlController;
  final TextEditingController? masjidNameController;
  final TextEditingController? cityController;

  const LocationInputWidget({
    super.key,
    required this.latController,
    required this.lngController,
    required this.mapUrlController,
    this.masjidNameController,
    this.cityController,
  });

  @override
  State<LocationInputWidget> createState() => _LocationInputWidgetState();
}

class _LocationInputWidgetState extends State<LocationInputWidget> {
  // 0: Google Maps Link / Search, 1: Manual Lat & Lng / GPS
  int _selectedMode = 0;
  bool _isFetchingGps = false;
  String? _detectedCoordsText;

  @override
  void initState() {
    super.initState();
    _checkInitialCoords();
  }

  void _checkInitialCoords() {
    if (widget.mapUrlController.text.isNotEmpty) {
      final coords = LocationHelper.extractLatLng(widget.mapUrlController.text);
      if (coords != null) {
        widget.latController.text = coords['lat']!.toStringAsFixed(6);
        widget.lngController.text = coords['lng']!.toStringAsFixed(6);
        _detectedCoordsText = '${coords['lat']!.toStringAsFixed(4)}, ${coords['lng']!.toStringAsFixed(4)}';
      }
    } else if (widget.latController.text.isNotEmpty && widget.lngController.text.isNotEmpty) {
      _detectedCoordsText = '${widget.latController.text}, ${widget.lngController.text}';
    }
  }

  void _onMapUrlChanged(String val) {
    final coords = LocationHelper.extractLatLng(val);
    setState(() {
      if (coords != null) {
        widget.latController.text = coords['lat']!.toStringAsFixed(6);
        widget.lngController.text = coords['lng']!.toStringAsFixed(6);
        _detectedCoordsText = '${coords['lat']!.toStringAsFixed(4)}, ${coords['lng']!.toStringAsFixed(4)}';
      } else {
        _detectedCoordsText = null;
      }
    });
  }

  Future<void> _searchInGoogleMaps() async {
    final name = widget.masjidNameController?.text.trim() ?? '';
    final city = widget.cityController?.text.trim() ?? '';
    final query = ('$name $city Masjid').trim();

    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _fetchCurrentGps() async {
    setState(() => _isFetchingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS / Location service on your device.')),
          );
        }
        setState(() => _isFetchingGps = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isFetchingGps = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        widget.latController.text = position.latitude.toStringAsFixed(6);
        widget.lngController.text = position.longitude.toStringAsFixed(6);
        _detectedCoordsText = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _isFetchingGps = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text('GPS Coordinates captured successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isFetchingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F432B);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on, size: 16, color: primaryColor),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Masjid Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // THIS OR THAT Segmented Selector (Zero overflow)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedMode = 0),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectedMode == 0 ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link, size: 14, color: _selectedMode == 0 ? Colors.white : Colors.black87),
                          const SizedBox(width: 4),
                          Text(
                            'Maps Link',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedMode == 0 ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedMode = 1),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectedMode == 1 ? primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gps_fixed, size: 14, color: _selectedMode == 1 ? Colors.white : Colors.black87),
                          const SizedBox(width: 4),
                          Text(
                            'Lat/Lng GPS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedMode == 1 ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // MODE 0: Google Maps Link or Search
          if (_selectedMode == 0) ...[
            TextField(
              controller: widget.mapUrlController,
              onChanged: _onMapUrlChanged,
              decoration: InputDecoration(
                labelText: 'Google Maps Link or Coords',
                hintText: 'Paste link or 13.0827, 80.2707',
                prefixIcon: const Icon(Icons.map_outlined, color: primaryColor, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _detectedCoordsText != null
                        ? '✓ Detected: $_detectedCoordsText'
                        : 'Tip: Find in Maps & paste link',
                    style: TextStyle(
                      fontSize: 11,
                      color: _detectedCoordsText != null ? Colors.green.shade800 : Colors.black54,
                      fontWeight: _detectedCoordsText != null ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _searchInGoogleMaps,
                  icon: const Icon(Icons.open_in_new, size: 13),
                  label: const Text('Open Maps', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],

          // MODE 1: Manual Lat & Long / Current GPS
          if (_selectedMode == 1) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      hintText: '13.0604',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      hintText: '80.2496',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _isFetchingGps ? null : _fetchCurrentGps,
              icon: _isFetchingGps
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 16),
              label: const Text('Use Current GPS Location', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
