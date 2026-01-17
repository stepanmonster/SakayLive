/// Represents a preloaded and parsed jeepney route for fast lookup.
class CachedRoute {
  final Map<String, dynamic> rawData;
  final int directionIndex;
  final List<List<double>> coordinates; // [lng, lat] pairs

  CachedRoute({
    required this.rawData,
    required this.directionIndex,
    required this.coordinates,
  });

  String get routeNum => rawData['num'] as String;
  String get color => rawData['color'] as String;
  String get destination => rawData['dest'] as String;
  List get directions => rawData['directions'] as List;
}
