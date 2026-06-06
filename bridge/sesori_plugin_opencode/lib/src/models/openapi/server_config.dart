// GENERATED FILE - DO NOT EDIT BY HAND


class ServerConfig {
  const ServerConfig({
    this.port,
    this.hostname,
    this.mdns,
    this.mdnsDomain,
    this.cors,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      port: json["port"] as int?,
      hostname: json["hostname"] as String?,
      mdns: json["mdns"] as bool?,
      mdnsDomain: json["mdnsDomain"] as String?,
      cors: (json["cors"] as List<dynamic>?)?.cast<String>(),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "port": port,
      "hostname": hostname,
      "mdns": mdns,
      "mdnsDomain": mdnsDomain,
      "cors": cors,
    };
  }

  final int? port;
  final String? hostname;
  final bool? mdns;
  final String? mdnsDomain;
  final List<String>? cors;
}
