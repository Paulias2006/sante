class ResultatAnalyse {
  final String parametre;
  final String valeur;
  final String unite;
  final String statut; // 'normal' | 'bas' | 'eleve' | 'critique'

  ResultatAnalyse({
    required this.parametre,
    required this.valeur,
    required this.unite,
    required this.statut,
  });

  factory ResultatAnalyse.fromJson(Map<String, dynamic> json) {
    return ResultatAnalyse(
      parametre: json['parametre'] ?? '',
      valeur: json['valeur'] ?? '',
      unite: json['unite'] ?? '',
      statut: json['statut'] ?? 'normal',
    );
  }
}

class Analyse {
  final String id;
  final String type; // 'NFS', 'GE', 'Glycémie à jeun', etc.
  final List<ResultatAnalyse> resultats;
  final DateTime date;
  final String medecinNom;

  Analyse({
    required this.id,
    required this.type,
    required this.resultats,
    required this.date,
    required this.medecinNom,
  });

  factory Analyse.fromJson(Map<String, dynamic> json) {
    return Analyse(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      resultats:
          (json['resultats'] as List?)
              ?.map((r) => ResultatAnalyse.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      medecinNom: json['medecinNom'] ?? 'N/A',
    );
  }
}
