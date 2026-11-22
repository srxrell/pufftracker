class DeviceModel {
  final String id;
  final String type;
  final String name;
  final String brand;
  final String subtitle;
  final String image;
  final String? tobacco;
  final String? flavor;
  final double strength;

  const DeviceModel({
    required this.id,
    required this.type,
    required this.name,
    required this.brand,
    required this.subtitle,
    required this.image,
    this.tobacco,
    this.flavor,
    this.strength = 3.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'brand': brand,
    'subtitle': subtitle,
    'image': image,
    if (tobacco != null) 'tobacco': tobacco,
    if (flavor != null) 'flavor': flavor,
    'strength': strength,
  };

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id']?.toString() ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
      type: json['type']?.toString() ?? 'vape',
      name: json['name']?.toString() ?? 'Девайс',
      brand: json['brand']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      image: json['image']?.toString() ?? 'assets/images/devices/lost_mary_os5000.png',
      tobacco: json['tobacco']?.toString(),
      flavor: json['flavor']?.toString(),
      strength: (json['strength'] is num) ? (json['strength'] as num).toDouble() : 3.0,
    );
  }

  DeviceModel copyWith({
    String? id,
    String? type,
    String? name,
    String? brand,
    String? subtitle,
    String? image,
    String? tobacco,
    String? flavor,
    double? strength,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      subtitle: subtitle ?? this.subtitle,
      image: image ?? this.image,
      tobacco: tobacco ?? this.tobacco,
      flavor: flavor ?? this.flavor,
      strength: strength ?? this.strength,
    );
  }
}
