class User {
  final String id;
  final String email;
  final String
  role; // 'admin' | 'secretaire' | 'medecin' | 'pharmacien' | 'patient'
  final String nom;
  final String prenom;
  final String? entite;
  final String? entiteType; // 'clinique' | 'pharmacie'
  final String? patientId;
  final bool actif;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.nom,
    required this.prenom,
    this.entite,
    this.entiteType,
    this.patientId,
    this.actif = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      entite: json['entite'],
      entiteType: json['entiteType'],
      patientId: json['patientId'] ?? json['patient_id'],
      actif: json['actif'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'nom': nom,
      'prenom': prenom,
      'entite': entite,
      'entiteType': entiteType,
      'patientId': patientId,
      'actif': actif,
    };
  }

  String get fullName => '$prenom $nom';
  String get initials => '${prenom[0]}${nom[0]}'.toUpperCase();
}
