import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:every_door/models/imagery.dart';
import 'package:every_door/providers/imagery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class TileCacheManager {
  static const key = 'tileCache';
  static CacheManager instance = CacheManager(Config(
    key,
    maxNrOfCacheObjects: 10000,
    stalePeriod: Duration(days: 120),
  ));
}

class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    // print(url);
    return CachedNetworkImageProvider(
      url,
      cacheManager: TileCacheManager.instance,
      headers: headers,
    );
  }
}

class CachedBingTileProvider extends TileProvider {
  CachedBingTileProvider();

  String _tileToQuadkey(int x, int y, int z) {
    String quad = '';
    for (int i = z; i > 0; i--) {
      int digit = 0;
      int mask = 1 << (i - 1);
      if ((x & mask) != 0) digit += 1;
      if ((y & mask) != 0) digit += 2;
      quad += digit.toString();
    }
    return quad;
  }

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    final quadkey =
        _tileToQuadkey(coordinates.x.round(), coordinates.y.round(), coordinates.z.round());
    final tileUrl = super.getTileUrl(coordinates, options);
    return tileUrl
        .replaceFirst('_QUADKEY_', quadkey)
        .replaceFirst('_CULTURE_', 'en');
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheManager: TileCacheManager.instance,
      headers: headers,
    );
  }
}

const kOSMImagery = Imagery(
  id: 'openstreetmap',
  type: ImageryType.tms,
  name: 'OpenStreetMap',
  url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  attribution: '© OpenStreetMap contributors',
  minZoom: 0,
  maxZoom: 19,
);

WMSTileLayerOptions _buildWMSOptions(String url, Imagery imagery) {
  final uri = Uri.parse(url);
  final baseUrl = uri.origin + uri.path + '?';
  final Map<String, String> other = {};
  final params = uri.queryParameters
      .map((key, value) => MapEntry(key.toLowerCase(), value));
  final version = params['version'] ?? '1.3.0';
  final layers = params['layers']!.split(',');
  final style = params['styles'] ?? '';
  final format = params['format'] ?? 'image/jpeg';
  final transparent = params['transparent']?.toLowerCase() == 'true';
  final crs = imagery.wms4326 ? const Epsg4326() : const Epsg3857();

  /*const kRequiredKeys = ['width', 'height', 'bbox', 'service', 'request'];
  for (final k in kRequiredKeys) {
    if (!params.containsKey(k))
      throw ArgumentError('Missing WMS required parameter $k');
  }*/
  const kAllKeys = [
    'service',
    'request',
    'layers',
    'styles',
    'format',
    'crs',
    'srs',
    'version',
    'transparent',
    'width',
    'height',
    'bbox'
  ];
  for (final kv in uri.queryParameters.entries) {
    if (!kAllKeys.contains(kv.key.toLowerCase())) other[kv.key] = kv.value;
  }

  return WMSTileLayerOptions(
    baseUrl: baseUrl,
    version: version,
    layers: layers,
    styles: style.isEmpty ? [] : [style],
    otherParameters: other,
    format: format,
    transparent: transparent,
    crs: crs,
  );
}

class TileLayerOptions {
  String? urlTemplate;
  WMSTileLayerOptions? wmsOptions;
  late final TileProvider tileProvider;
  late final int minNativeZoom;
  late final int maxNativeZoom;
  final double maxZoom = 22;
  late final double tileSize;
  bool tms = false;
  final List<String> subdomains = [];
  final Map<String, String> additionalOptions = const {'a': 'b'};
  final String userAgentPackageName = 'info.zverev.ilya.every_door.mn';

  TileLayerOptions(Imagery imagery) {
    String url = imagery.url.replaceAll('{zoom}', '{z}');

    if (imagery.type == ImageryType.bing) {
      url = ImageryProvider.bingUrlTemplate
              ?.replaceFirst('{quadkey}', '_QUADKEY_')
              .replaceFirst('{culture}', '_CULTURE_') ??
          '';
    }

    switch (imagery.type) {
      case ImageryType.tms:
      case ImageryType.bing:
        if (url.contains('{-y}')) {
          url = url.replaceFirst('{-y}', '{y}');
          tms = true;
        }

        if (url.contains('{switch:')) {
          final match = RegExp(r'\{switch:([^}]+)\}').firstMatch(url)!;
          subdomains.addAll(match.group(1)!.split(',').map((e) => e.trim()));
          url = url.substring(0, match.start) + '{s}' + url.substring(match.end);
        }
        urlTemplate = url;
        break;
      case ImageryType.wms:
        wmsOptions = _buildWMSOptions(url, imagery);
        break;
    }

    tileProvider = imagery.type == ImageryType.bing
        ? CachedBingTileProvider()
        : CachedTileProvider();

    minNativeZoom = imagery.minZoom;
    maxNativeZoom = imagery.maxZoom;
    tileSize = imagery.tileSize.toDouble();
  }

  TileLayer buildTileLayer() {
    return TileLayer(
      urlTemplate: urlTemplate,
      wmsOptions: wmsOptions,
      tileProvider: tileProvider,
      minNativeZoom: minNativeZoom,
      maxNativeZoom: maxNativeZoom,
      maxZoom: maxZoom,
      tileSize: tileSize,
      tms: tms,
      subdomains: subdomains,
      additionalOptions: additionalOptions,
      userAgentPackageName: userAgentPackageName,
    );
  }
}