class Medicament {
  final String nom;
  final String dose;
  final String frequence;
  final String duree;
  final String instructions;

  Medicament({
    required this.nom,
    required this.dose,
    required this.frequence,
    required this.duree,
    required this.instructions,
  });

  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      nom: json['nom'] ?? '',
      dose: json['dose'] ?? '',
      frequence: json['frequence'] ?? '',
      duree: json['duree'] ?? '',
      instructions: json['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'dose': dose,
      'frequence': frequence,
      'duree': duree,
      'instructions': instructions,
    };
  }
}

class Ordonnance {
  final String id;
  final String patientId;
  final String qrToken;
  final List<Medicament> medicaments;
  final String instructionsGenerales;
  final String status; // 'active' | 'delivered' | 'partial' | 'expired'
  final int validiteJours;
  final bool renouvelable;
  final DateTime emiseAt;
  final DateTime expireAt;
  final String medecinNom;
  final String cliniqueNom;

  Ordonnance({
    required this.id,
    required this.patientId,
    required this.qrToken,
    required this.medicaments,
    required this.instructionsGenerales,
    required this.status,
    required this.validiteJours,
    required this.renouvelable,
    required this.emiseAt,
    required this.expireAt,
    required this.medecinNom,
    required this.cliniqueNom,
  });

  factory Ordonnance.fromJson(Map<String, dynamic> json) {
    return Ordonnance(
      id: json['_id'] ?? '',
      patientId: json['patient'] ?? '',
      qrToken: json['qrToken'] ?? '',
      medicaments:
          (json['medicaments'] as List?)
              ?.map((m) => Medicament.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      instructionsGenerales: json['instructionsGenerales'] ?? '',
      status: json['status'] ?? 'active',
      validiteJours: json['validiteJours'] ?? 7,
      renouvelable: json['renouvelable'] ?? false,
      emiseAt: DateTime.parse(
        json['emiseAt'] ?? DateTime.now().toIso8601String(),
      ),
      expireAt: DateTime.parse(
        json['expireAt'] ?? DateTime.now().toIso8601String(),
      ),
      medecinNom: json['medecinNom'] ?? 'N/A',
      cliniqueNom: json['cliniqueNom'] ?? 'N/A',
    );
  }

  bool get isExpired => DateTime.now().isAfter(expireAt);
  bool get isActive => status == 'active' && !isExpired;
}
