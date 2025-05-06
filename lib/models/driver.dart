class Driver {
  final String name;
  final List<dynamic> attributes; // Consider creating a more specific Attribute class if structure is fixed
  final String contract;

  Driver({
    required this.name,
    required this.attributes,
    required this.contract,
  });

  // Method to convert a Driver object to a JSON map (if needed for storage or other purposes)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'attributes': attributes,
      'contract': contract,
    };
  }

  // Factory constructor to create a Driver from a JSON map (if needed for storage or other purposes)
  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      name: json['name'],
      attributes: List<dynamic>.from(json['attributes']), // Ensure it's a List
      contract: json['contract'],
    );
  }

  @override
  String toString() {
    return 'Driver{name: $name, attributes: $attributes, contract: $contract}';
  }
}