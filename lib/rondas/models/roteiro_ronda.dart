enum TipoPontoRonda {
  percurso,
  casa,
}

class PontoRonda {
  const PontoRonda({
    required this.latitude,
    required this.longitude,
    required this.dataHora,
    this.tipo = TipoPontoRonda.percurso,
    this.identificacao = '',
  });

  final double latitude;
  final double longitude;
  final DateTime dataHora;
  final TipoPontoRonda tipo;
  final String identificacao;

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'dataHora': dataHora.toIso8601String(),
      'tipo': tipo.name,
      'identificacao': identificacao,
    };
  }

  factory PontoRonda.fromMap(Map<String, dynamic> mapa) {
    final tipoSalvo = mapa['tipo']?.toString();

    return PontoRonda(
      latitude: (mapa['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (mapa['longitude'] as num?)?.toDouble() ?? 0,
      dataHora: DateTime.tryParse(mapa['dataHora']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      tipo: TipoPontoRonda.values.firstWhere(
        (tipo) => tipo.name == tipoSalvo,
        orElse: () => TipoPontoRonda.percurso,
      ),
      identificacao: mapa['identificacao']?.toString() ?? '',
    );
  }
}

class RoteiroRonda {
  const RoteiroRonda({
    required this.id,
    required this.nome,
    required this.area,
    required this.criadoEm,
    this.inicioGravacao,
    this.fimGravacao,
    this.distanciaMetros = 0,
    this.pontos = const [],
  });

  final String id;
  final String nome;
  final String area;
  final DateTime criadoEm;
  final DateTime? inicioGravacao;
  final DateTime? fimGravacao;
  final double distanciaMetros;
  final List<PontoRonda> pontos;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'area': area,
      'criadoEm': criadoEm.toIso8601String(),
      'inicioGravacao': inicioGravacao?.toIso8601String(),
      'fimGravacao': fimGravacao?.toIso8601String(),
      'distanciaMetros': distanciaMetros,
      'pontos': pontos.map((ponto) => ponto.toMap()).toList(),
    };
  }

  factory RoteiroRonda.fromMap(Map<String, dynamic> mapa) {
    final pontosSalvos =
        mapa['pontos'] is List ? mapa['pontos'] as List : const [];

    return RoteiroRonda(
      id: mapa['id']?.toString() ?? '',
      nome: mapa['nome']?.toString() ?? '',
      area: mapa['area']?.toString() ?? '',
      criadoEm: DateTime.tryParse(mapa['criadoEm']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      inicioGravacao: mapa['inicioGravacao'] == null
          ? null
          : DateTime.tryParse(mapa['inicioGravacao'].toString()),
      fimGravacao: mapa['fimGravacao'] == null
          ? null
          : DateTime.tryParse(mapa['fimGravacao'].toString()),
      distanciaMetros:
          (mapa['distanciaMetros'] as num?)?.toDouble() ?? 0,
      pontos: pontosSalvos
          .whereType<Map>()
          .map(
            (ponto) => PontoRonda.fromMap(
              Map<String, dynamic>.from(ponto),
            ),
          )
          .toList(growable: false),
    );
  }
}
