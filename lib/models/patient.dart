class Patient {
  final String id;
  final String dossierNumber;
  final String nom;
  final String prenom;
  final DateTime dateNaissance;
  final String sexe; // 'M' | 'F'
  final String telephone;
  final String adresse;
  final String groupeSanguin;
  final List<String> allergies;
  final String carteStatus;
  final String qrToken;
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.dossierNumber,
    required this.nom,
    required this.prenom,
    required this.dateNaissance,
    required this.sexe,
    required this.telephone,
    required this.adresse,
    required this.groupeSanguin,
    required this.allergies,
    required this.carteStatus,
    required this.qrToken,
    required this.createdAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['_id'] ?? '',
      dossierNumber: json['dossierNumber'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      dateNaissance: DateTime.parse(
        json['dateNaissance'] ?? DateTime.now().toIso8601String(),
      ),
      sexe: json['sexe'] ?? 'M',
      telephone: json['telephone'] ?? '',
      adresse: json['adresse'] ?? '',
      groupeSanguin: json['groupeSanguin'] ?? '',
      allergies: List<String>.from(json['allergies'] ?? []),
      carteStatus: json['carteStatus'] ?? 'pending',
      qrToken: json['qrToken'] ?? '',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  String get fullName => '$prenom $nom';

  int get age {
    final now = DateTime.now();
    return now.year - dateNaissance.year;
  }

  String get initials => '${prenom[0]}${nom[0]}'.toUpperCase();
}
