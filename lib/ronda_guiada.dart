import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rondas/models/roteiro_ronda.dart';

const String _chaveRoteiros = 'roteirosRondaGuiadaV1';
const String _chaveRotaPrincipal = 'rotaPrincipalRondaV1';
const String _chaveRondasFeitas = 'rondasFeitasRondaV1';
class RondaGuiadaPage extends StatefulWidget {
  const RondaGuiadaPage({super.key});

  @override
  State<RondaGuiadaPage> createState() => _RondaGuiadaPageState();
}

class _RondaGuiadaPageState extends State<RondaGuiadaPage> {
  List<RoteiroRonda> _roteiros = [];
  RoteiroRonda? _rotaPrincipal;
List<RoteiroRonda> _rondasFeitas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarRoteiros();
  }

  Future<void> _carregarRoteiros() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    List<RoteiroRonda> converterLista(String? salvo) {
      if (salvo == null) return [];
      final dados = jsonDecode(salvo);
      if (dados is! List) return [];

      return dados
          .whereType<Map>()
          .map(
            (item) => RoteiroRonda.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    final roteirosAntigos = converterLista(
      prefs.getString(_chaveRoteiros),
    );

    final rondasSalvas = prefs.getString(_chaveRondasFeitas);
    final rondasCarregadas = converterLista(rondasSalvas);

    RoteiroRonda? rotaPrincipal;
    final rotaSalva = prefs.getString(_chaveRotaPrincipal);

    if (rotaSalva != null) {
      final dados = jsonDecode(rotaSalva);
      if (dados is Map) {
        rotaPrincipal = RoteiroRonda.fromMap(
          Map<String, dynamic>.from(dados),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _roteiros = roteirosAntigos;
      _rondasFeitas =
          rondasSalvas == null ? roteirosAntigos : rondasCarregadas;
      _rotaPrincipal = rotaPrincipal;
      _carregando = false;
    });
  } catch (_) {
    if (!mounted) return;

    setState(() {
      _roteiros = [];
      _rondasFeitas = [];
      _rotaPrincipal = null;
      _carregando = false;
    });
  }
  }

  Future<void> _novaRonda() async {
    final nome = TextEditingController(text: 'Ronda');
    final area = TextEditingController();

    
      final dados = await _mostrarDialogoAguardandoFechar<Map<String, String>>(
      builder: (context) => AlertDialog(
        title: const Text('Nova ronda'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(
                labelText: 'Nome do roteiro',
              ),
            ),
            TextField(
              controller: area,
              decoration: const InputDecoration(
                labelText: 'Área da ronda',
                hintText: 'Ex.: Setor 1 ou Rua A',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nome.text.trim().isEmpty || area.text.trim().isEmpty) {
                return;
              }
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context, {
                'nome': nome.text.trim(),
                'area': area.text.trim(),
              });
            },
            child: const Text('Começar'),
          ),
        ],
      ),
    );

    nome.dispose();
    area.dispose();

    if (dados == null || !mounted) return;

    final roteiro = await Navigator.of(context).push<RoteiroRonda>(
      MaterialPageRoute(
        builder: (_) => RondaEmAndamentoPage(
          nome: dados['nome']!,
          area: dados['area']!,
        ),
      ),
    );

    if (roteiro == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
final salvo = await prefs.setString(
  _chaveRotaPrincipal,
  jsonEncode(roteiro.toMap()),
);

if (!salvo) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Não foi possível salvar o roteiro.'),
    ),
  );
  return;
}

if (!mounted) return;

setState(() {
  _rotaPrincipal = roteiro;
});

ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text('Roteiro principal salvo neste aparelho.'),
  ),
);
  }
    Future<T?> _mostrarDialogoAguardandoFechar<T>({
    required WidgetBuilder builder,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final rotaDialogo = DialogRoute<T>(
      context: context,
      builder: builder,
      themes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierDismissible: true,
    );

    final resultado = await navigator.push<T>(rotaDialogo);
    await rotaDialogo.completed;
    return resultado;
    }
    Future<void> _iniciarExecucao() async {
    final principal = _rotaPrincipal;
    if (principal == null) return;

    final campoNome = TextEditingController();

    final nomeVigilante = await _mostrarDialogoAguardandoFechar<String>(
      
      builder: (context) => AlertDialog(
        title: const Text('Iniciar ronda'),
        content: TextField(
          controller: campoNome,
          decoration: const InputDecoration(
            labelText: 'Nome do vigilante',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
                    FilledButton(
            onPressed: () {
              final nome = campoNome.text.trim();
              if (nome.isEmpty) return;

              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context, nome);
            },
            child: const Text('Começar'),
          ),
                  ],
      ),
    );

    campoNome.dispose();
    if (nomeVigilante == null || !mounted) return;

    final execucao = await Navigator.of(context).push<RoteiroRonda>(
      MaterialPageRoute(
        builder: (_) => RondaEmAndamentoPage(
          nome: nomeVigilante,
          area: principal.area,
          rotaPrincipal: principal,
        ),
      ),
    );

    if (execucao == null || !mounted) return;

    final rondasAtualizadas = [execucao, ..._rondasFeitas];
    final prefs = await SharedPreferences.getInstance();
    final salvo = await prefs.setString(
      _chaveRondasFeitas,
      jsonEncode(
        rondasAtualizadas.map((item) => item.toMap()).toList(),
      ),
    );

    if (!salvo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a ronda feita.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _rondasFeitas = rondasAtualizadas;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ronda feita salva neste aparelho.'),
      ),
    );
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rondas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Grave o percurso e marque cada casa durante a ronda.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
                    Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.route_outlined),
                    title: const Text('Ronda principal'),
                    subtitle: Text(
                      _carregando
                          ? 'Carregando...'
                          : _rotaPrincipal == null
                              ? 'Nenhum roteiro salvo'
                              : '${_rotaPrincipal!.nome} • '
                                  '${_rotaPrincipal!.area}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _carregando ? null : _novaRonda,
                    icon: const Icon(Icons.route),
                    label: Text(
                      _rotaPrincipal == null
                          ? 'Gravar roteiro principal'
                          : 'Gravar novamente o roteiro principal',
                    ),
                  ),
                  if (_rotaPrincipal != null) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _carregando ? null : _iniciarExecucao,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Seguir ronda'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Rondas feitas'),
              subtitle: Text(
                _carregando
                    ? 'Carregando...'
                    : '${_rondasFeitas.length} roteiro(s) salvo(s)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _carregando
                  ? null
                  : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => RondasRegistradasPage(
                            roteiros: _rondasFeitas,
                          ),
                        ),
                      ),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Cada roteiro fica identificado por nome e área, '
                'para organizar percursos diferentes.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RondaEmAndamentoPage extends StatefulWidget {
  const RondaEmAndamentoPage({
    super.key,
    required this.nome,
    required this.area,
    this.rotaPrincipal,
  });

  final String nome;
  final String area;
  final RoteiroRonda? rotaPrincipal;

  @override
  State<RondaEmAndamentoPage> createState() =>
      _RondaEmAndamentoPageState();
}

class _RondaEmAndamentoPageState extends State<RondaEmAndamentoPage> {
  final FlutterTts _fala = FlutterTts();
  final List<PontoRonda> _pontos = [];
  final MapController _mapController = MapController();
  bool _mapaPronto = false;
  StreamSubscription<Position>? _assinatura;
  Position? _ultimaPosicao;
  double _distanciaMetros = 0;
  bool _carregando = true;
  bool _gravando = false;
  bool _podeSair = false;
  String? _erro;
int _indiceProximoPontoRota = 1;
int _ultimaCurvaAnunciada = -1;
String? _instrucaoAtual;
      bool _gpsAgendado = false;
  Animation<double>? _animacaoDaRota;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final animacao = ModalRoute.of(context)?.animation;
    if (identical(animacao, _animacaoDaRota)) return;

    _animacaoDaRota?.removeStatusListener(_esperarFimDaAbertura);
    _animacaoDaRota = animacao;
    _animacaoDaRota?.addStatusListener(_esperarFimDaAbertura);

    if (animacao == null ||
        animacao.status == AnimationStatus.completed) {
      _agendarInicioGps();
    }
  }

  void _esperarFimDaAbertura(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _agendarInicioGps();
    }
  }

  void _agendarInicioGps() {
    if (_gpsAgendado) return;
    _gpsAgendado = true;
    _animacaoDaRota?.removeStatusListener(_esperarFimDaAbertura);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _iniciarGps();
    });
  }

  Future<void> _iniciarGps() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      if (widget.rotaPrincipal != null) {
  await _fala.setLanguage('pt-BR');
  await _fala.setSpeechRate(0.48);
  await _fala.setVolume(1.0);
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Ative a localização do celular para começar.');
      }

      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        throw Exception('Libere a permissão de localização para o app.');
      }

      const configuracao = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      final primeiraPosicao = await Geolocator.getCurrentPosition(
        locationSettings: configuracao,
      );

      _registrarPosicao(primeiraPosicao, forcar: true);

      _assinatura = Geolocator.getPositionStream(
        locationSettings: configuracao,
      ).listen(
        _registrarPosicao,
        onError: (Object erro) {
          if (mounted) {
            setState(() => _erro = 'O GPS parou de atualizar.');
          }
        },
      );

      if (mounted) {
        setState(() {
          _carregando = false;
          _gravando = true;
        });
      }
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _gravando = false;
        _erro = erro.toString().replaceFirst('Exception: ', '');
      });
    }
  }
  List<PontoRonda> get _pontosDaRotaSalva {
  return (widget.rotaPrincipal?.pontos ?? const <PontoRonda>[])
      .where((ponto) => ponto.tipo == TipoPontoRonda.percurso)
      .toList(growable: false);
  }
  Future<void> _anunciarInstrucao(String instrucao, int indice) async {
  if (_ultimaCurvaAnunciada == indice) return;

  _ultimaCurvaAnunciada = indice;
  if (mounted) {
    setState(() {
      _instrucaoAtual = instrucao;
    });
  }

  await _fala.stop();
  await _fala.speak(instrucao);
  }

    void _registrarPosicao(Position posicao, {bool forcar = false}) {
  final anterior = _pontos.isEmpty ? null : _pontos.last;
  var trechoMetros = 0.0;

  if (anterior != null) {
    trechoMetros = Geolocator.distanceBetween(
      anterior.latitude,
      anterior.longitude,
      posicao.latitude,
      posicao.longitude,
    );

    if (!forcar && trechoMetros < 5) {
      if (mounted) {
        setState(() {
          _ultimaPosicao = posicao;
        });
        _acompanharPosicao(posicao);
      }
      return;
    }
  }

  if (!mounted) return;

  setState(() {
    _ultimaPosicao = posicao;
    _distanciaMetros += trechoMetros;
    _pontos.add(
      PontoRonda(
        latitude: posicao.latitude,
        longitude: posicao.longitude,
        dataHora: posicao.timestamp,
        tipo: TipoPontoRonda.percurso,
      ),
    );
  });

  _acompanharPosicao(posicao);
}

void _acompanharPosicao(Position posicao) {
  if (!mounted || !_mapaPronto) return;

  _mapController.move(
    LatLng(posicao.latitude, posicao.longitude),
    16,
  );
}

Future<void> _marcarCasa() async {
  final posicao = _ultimaPosicao;
  if (posicao == null) return;

  var identificacaoCasa = '';

  final nomeCasa = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Marcar casa'),
      content: TextField(
        autofocus: true,
        onChanged: (valor) => identificacaoCasa = valor.trim(),
        decoration: const InputDecoration(
          labelText: 'Identificação da casa',
          hintText: 'Ex.: Casa 25',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final valor = identificacaoCasa.trim();
            if (valor.isNotEmpty) {
              Navigator.pop(context, valor);
            }
          },
          child: const Text('Marcar'),
        ),
      ],
    ),
  );

  if (nomeCasa == null || !mounted) return;

  setState(() {
    _pontos.add(
      PontoRonda(
        latitude: posicao.latitude,
        longitude: posicao.longitude,
        dataHora: DateTime.now(),
        tipo: TipoPontoRonda.casa,
        identificacao: nomeCasa,
      ),
    );
  });
}

  Future<void> _sairSemSalvar() async {
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da gravação?'),
        content: const Text('A ronda atual será descartada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (descartar == true && mounted) {
      await _assinatura?.cancel();
      setState(() => _podeSair = true);
      Navigator.pop(context);
    }
  }

  Future<void> _finalizar() async {
    await _assinatura?.cancel();

    final agora = DateTime.now();
    final roteiro = RoteiroRonda(
      id: agora.microsecondsSinceEpoch.toString(),
      nome: widget.nome,
      area: widget.area,
      criadoEm: agora,
      inicioGravacao: _pontos.isEmpty ? agora : _pontos.first.dataHora,
      fimGravacao: agora,
      distanciaMetros: _distanciaMetros,
      pontos: List<PontoRonda>.unmodifiable(_pontos),
    );

    if (!mounted) return;
    setState(() => _podeSair = true);
    Navigator.pop(context, roteiro);
  }

    @override
  void dispose() {
    _animacaoDaRota?.removeStatusListener(_esperarFimDaAbertura);
    _assinatura?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casas = _pontos
        .where((ponto) => ponto.tipo == TipoPontoRonda.casa)
        .toList();
    final pontosRota = widget.rotaPrincipal?.pontos ?? const <PontoRonda>[];
    final coordenadasRota = pontosRota
        .map((ponto) => LatLng(ponto.latitude, ponto.longitude))
        .toList();
    final coordenadasGravadas = _pontos
        .map((ponto) => LatLng(ponto.latitude, ponto.longitude))
        .toList();
    final centroInicial = coordenadasRota.isNotEmpty
        ? coordenadasRota.first
        : _ultimaPosicao != null
            ? LatLng(
                _ultimaPosicao!.latitude,
                _ultimaPosicao!.longitude,
              )
            : const LatLng(-15.7801, -47.9292);
    return PopScope<RoteiroRonda>(
      canPop: _podeSair,
      onPopInvokedWithResult: (didPop, resultado) {
        if (!didPop) _sairSemSalvar();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gravando ronda'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _sairSemSalvar,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(widget.nome),
                subtitle: Text('Área: ${widget.area}'),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _carregando
                          ? 'Obtendo GPS...'
                          : _gravando
                              ? 'Gravação em andamento'
                              : 'Gravação pausada',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Distância: ${_formatarDistancia(_distanciaMetros)}',
                    ),
                    Text('Casas marcadas: ${casas.length}'),
                    if (_ultimaPosicao != null)
                      Text(
                        'GPS: '
                        '${_ultimaPosicao!.latitude.toStringAsFixed(5)}, '
                        '${_ultimaPosicao!.longitude.toStringAsFixed(5)}',
                      ),
                    if (_erro != null)
                      Text(
                        _erro!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
                        const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: centroInicial,
                    initialZoom: 16,
                                        onMapReady: () {
                                          _mapaPronto = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final posicao = _ultimaPosicao;
                        if (!mounted || posicao == null) return;

                        _mapController.move(
                          LatLng(posicao.latitude, posicao.longitude),
                          16,
                        );
                      });
                    },
                  ),
                  children: [
                    TileLayer(
  urlTemplate:
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'br.com.vigilanterecibos.vigilante_recibos',
),
RichAttributionWidget(
  attributions: [
    TextSourceAttribution('© OpenStreetMap contributors'),
  ],
),
                    if (coordenadasRota.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: coordenadasRota,
                            color: Colors.blue,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    if (coordenadasGravadas.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: coordenadasGravadas,
                            color: Colors.green,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        ...casas.map(
                          (casa) => Marker(
                            point: LatLng(casa.latitude, casa.longitude),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.home,
                              color: Colors.orange,
                              size: 34,
                            ),
                          ),
                        ),
                        if (_ultimaPosicao != null)
                          Marker(
                            point: LatLng(
                              _ultimaPosicao!.latitude,
                              _ultimaPosicao!.longitude,
                            ),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_erro != null && !_gravando)
              FilledButton(
                onPressed: _carregando ? null : _iniciarGps,
                child: const Text('Tentar novamente'),
              ),
            FilledButton.icon(
              onPressed: !_gravando ? null : _marcarCasa,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Marcar casa neste ponto'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: !_gravando ? null : _finalizar,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Finalizar e salvar'),
            ),
            const SizedBox(height: 16),
            Text(
              'Casas marcadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...casas.map(
              (casa) => ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(casa.identificacao),
                subtitle: Text(_formatarHorario(casa.dataHora)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RondasRegistradasPage extends StatelessWidget {
  const RondasRegistradasPage({super.key, required this.roteiros});

  final List<RoteiroRonda> roteiros;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rondas feitas')),
      body: roteiros.isEmpty
          ? const Center(child: Text('Ainda não há rondas salvas.'))
          : ListView.builder(
              itemCount: roteiros.length,
              itemBuilder: (context, index) {
                final roteiro = roteiros[index];
                final casas = roteiro.pontos
                    .where((ponto) => ponto.tipo == TipoPontoRonda.casa)
                    .length;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ExpansionTile(
                    leading: const Icon(Icons.route_outlined),
                    title: Text(roteiro.nome),
                    subtitle: Text(
                      'Área: ${roteiro.area} • $casas casa(s) • '
                      '${_formatarDistancia(roteiro.distanciaMetros)}',
                    ),
                    children: roteiro.pontos.map((ponto) {
                      final ehCasa = ponto.tipo == TipoPontoRonda.casa;

                      return ListTile(
                        leading: Icon(
                          ehCasa ? Icons.home_outlined : Icons.route,
                        ),
                        title: Text(
                          ehCasa
                              ? ponto.identificacao
                              : 'Ponto do percurso',
                        ),
                        subtitle: Text(
                          '${_formatarHorario(ponto.dataHora)} • '
                          '${ponto.latitude.toStringAsFixed(5)}, '
                          '${ponto.longitude.toStringAsFixed(5)}',
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}

String _formatarDistancia(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(2)} km';
}

String _formatarHorario(DateTime dataHora) {
  final hora = dataHora.hour.toString().padLeft(2, '0');
  final minuto = dataHora.minute.toString().padLeft(2, '0');
  return '$hora:$minuto';
}
