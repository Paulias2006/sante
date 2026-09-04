class Constantes {
  final String tension;
  final double? temperature;
  final double? poids;
  final int? frequenceCardiaque;

  Constantes({
    required this.tension,
    this.temperature,
    this.poids,
    this.frequenceCardiaque,
  });

  factory Constantes.fromJson(Map<String, dynamic> json) {
    return Constantes(
      tension: json['tension'] ?? '',
      temperature: (json['temperature'] as num?)?.toDouble(),
      poids: (json['poids'] as num?)?.toDouble(),
      frequenceCardiaque: json['frequenceCardiaque'] as int?,
    );
  }
}

class Consultation {
  final String id;
  final String patientId;
  final String motif;
  final String diagnostic;
  final String notes;
  final Constantes constantes;
  final String medecinNom;
  final String cliniqueNom;
  final DateTime date;

  Consultation({
    required this.id,
    required this.patientId,
    required this.motif,
    required this.diagnostic,
    required this.notes,
    required this.constantes,
    required this.medecinNom,
    required this.cliniqueNom,
    required this.date,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['_id'] ?? '',
      patientId: json['patient'] ?? '',
      motif: json['motif'] ?? '',
      diagnostic: json['diagnostic'] ?? '',
      notes: json['notes'] ?? '',
      constantes: Constantes.fromJson(json['constantes'] ?? {}),
      medecinNom: json['medecinNom'] ?? 'N/A',
      cliniqueNom: json['cliniqueNom'] ?? 'N/A',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    );
  }
}
