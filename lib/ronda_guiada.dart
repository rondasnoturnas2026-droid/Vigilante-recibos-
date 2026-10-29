import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rondas/models/roteiro_ronda.dart';

const String _chaveRoteiros = 'roteirosRondaGuiadaV1';
const String _chaveRotaPrincipal = 'rotaPrincipalRondaV1';
const String _chaveRondasFeitas = 'rondasFeitasRondaV1';
const String _chaveExecucaoPausada = 'execucaoPausadaRondaV1';
const double _distanciaMinimaRoteiroMetros = 50;

bool _roteiroTemPercurso(RoteiroRonda roteiro) {
  final pontosDoPercurso = roteiro.pontos
      .where((ponto) => ponto.tipo == TipoPontoRonda.percurso)
      .length;
  return roteiro.distanciaMetros >= _distanciaMinimaRoteiroMetros &&
      pontosDoPercurso >= 2;
}
class RondaGuiadaPage extends StatefulWidget {
  const RondaGuiadaPage({super.key});

  @override
  State<RondaGuiadaPage> createState() => _RondaGuiadaPageState();
}

class _RondaGuiadaPageState extends State<RondaGuiadaPage> {
  List<RoteiroRonda> _roteiros = [];
  RoteiroRonda? _rotaPrincipal;
List<RoteiroRonda> _rondasFeitas = [];
    Map<String, dynamic>? _execucaoPausada;
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
    ).where(_roteiroTemPercurso).toList();

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
                if (rotaPrincipal != null &&
            !_roteiroTemPercurso(rotaPrincipal)) {
          rotaPrincipal = null;
                }
      }
    }
        Map<String, dynamic>? execucaoPausada;
    final execucaoPausadaSalva =
        prefs.getString(_chaveExecucaoPausada);
    if (execucaoPausadaSalva != null) {
      final dadosPausados = jsonDecode(execucaoPausadaSalva);
      if (dadosPausados is Map) {
        execucaoPausada = Map<String, dynamic>.from(dadosPausados);
      }
    }

        final roteirosCarregados = [...roteirosAntigos];
              if (rotaPrincipal != null &&
                !roteirosCarregados.any((item) => item.id == rotaPrincipal!.id)) {
      roteirosCarregados.insert(0, rotaPrincipal);
    }

    if (!mounted) return;

    setState(() {
      _roteiros = roteirosCarregados;
      _rondasFeitas =
          rondasSalvas == null ? roteirosCarregados : rondasCarregadas;
      _rotaPrincipal = rotaPrincipal;
      _execucaoPausada = execucaoPausada;
      _carregando = false;
    });
  } catch (_) {
    if (!mounted) return;

    setState(() {
      _roteiros = [];
      _rondasFeitas = [];
      _rotaPrincipal = null;
            _execucaoPausada = null;
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

        if (!mounted) return;
    if (roteiro == null) {
      await _carregarRoteiros();
      return;
    }
        if (!_roteiroTemPercurso(roteiro)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Percurso curto demais para salvar. Caminhe pelo trajeto e tente novamente.',
          ),
        ),
      );
      await _carregarRoteiros();
      return;
        }

        final prefs = await SharedPreferences.getInstance();
    final roteirosAtualizados = [
      roteiro,
      ..._roteiros.where((item) => item.id != roteiro.id),
    ];
    final salvoLista = await prefs.setString(
      _chaveRoteiros,
      jsonEncode(roteirosAtualizados.map((item) => item.toMap()).toList()),
    );
    final salvoPrincipal = await prefs.setString(
      _chaveRotaPrincipal,
      jsonEncode(roteiro.toMap()),
    );

    if (!salvoLista || !salvoPrincipal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o roteiro.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _roteiros = roteirosAtualizados;
      _rotaPrincipal = roteiro;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Roteiro salvo. Você pode escolhê-lo para navegar.'),
      ),
    );
  }
    Future<void> _editarRoteiro(RoteiroRonda roteiro) async {
    final nome = TextEditingController(text: roteiro.nome);
    final area = TextEditingController(text: roteiro.area);

    final dados = await _mostrarDialogoAguardandoFechar<Map<String, String>>(
      builder: (context) => AlertDialog(
        title: const Text('Editar roteiro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome do roteiro'),
            ),
            TextField(
              controller: area,
              decoration: const InputDecoration(labelText: 'Área da ronda'),
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
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    nome.dispose();
    area.dispose();
    if (dados == null || !mounted) return;

    final roteiroEditado = RoteiroRonda(
      id: roteiro.id,
      nome: dados['nome']!,
      area: dados['area']!,
      criadoEm: roteiro.criadoEm,
      inicioGravacao: roteiro.inicioGravacao,
      fimGravacao: roteiro.fimGravacao,
      distanciaMetros: roteiro.distanciaMetros,
      pontos: roteiro.pontos,
    );

    final roteirosAtualizados = _roteiros
        .map((item) => item.id == roteiro.id ? roteiroEditado : item)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    final salvo = await prefs.setString(
      _chaveRoteiros,
      jsonEncode(roteirosAtualizados.map((item) => item.toMap()).toList()),
    );

    if (!salvo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível editar o roteiro.')),
        );
      }
      return;
    }

    RoteiroRonda? rotaPrincipalAtualizada = _rotaPrincipal;
    if (_rotaPrincipal?.id == roteiro.id) {
      rotaPrincipalAtualizada = roteiroEditado;
      await prefs.setString(
        _chaveRotaPrincipal,
        jsonEncode(roteiroEditado.toMap()),
      );
    }

    if (!mounted) return;
    setState(() {
      _roteiros = roteirosAtualizados;
      _rotaPrincipal = rotaPrincipalAtualizada;
    });
  }

  Future<void> _excluirRoteiro(RoteiroRonda roteiro) async {
    final confirmado = await _mostrarDialogoAguardandoFechar<bool>(
      builder: (context) => AlertDialog(
        title: const Text('Excluir roteiro?'),
        content: Text(
                    'Deseja excluir "${roteiro.nome}" da área ${roteiro.area}? '
          'As rondas já realizadas continuarão no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final roteirosAtualizados =
        _roteiros.where((item) => item.id != roteiro.id).toList();
    final prefs = await SharedPreferences.getInstance();
    final salvo = await prefs.setString(
      _chaveRoteiros,
      jsonEncode(roteirosAtualizados.map((item) => item.toMap()).toList()),
    );

    if (!salvo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir o roteiro.')),
        );
      }
      return;
    }

    RoteiroRonda? rotaPrincipalAtualizada = _rotaPrincipal;
    if (_rotaPrincipal?.id == roteiro.id) {
      rotaPrincipalAtualizada =
          roteirosAtualizados.isEmpty ? null : roteirosAtualizados.first;
      if (rotaPrincipalAtualizada == null) {
        await prefs.remove(_chaveRotaPrincipal);
      } else {
        await prefs.setString(
          _chaveRotaPrincipal,
          jsonEncode(rotaPrincipalAtualizada.toMap()),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _roteiros = roteirosAtualizados;
      _rotaPrincipal = rotaPrincipalAtualizada;
    });
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
      Future<void> _iniciarExecucao([RoteiroRonda? rotaSelecionada]) async {
    final rota = rotaSelecionada ?? _rotaPrincipal;
    if (rota == null) return;
            if (!_roteiroTemPercurso(rota)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não há percurso suficiente salvo. Grave a ronda caminhando pelo trajeto.',
          ),
        ),
      );
      return;
            }

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
                    area: rota.area,
          rotaPrincipal: rota,
        ),
      ),
    );

        if (!mounted) return;
    if (execucao == null) {
      await _carregarRoteiros();
      return;
    }

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
    Future<void> _retomarExecucao() async {
    final pausa = _execucaoPausada;
    if (pausa == null) return;

    final dadosExecucao = pausa['execucao'];
    if (dadosExecucao is! Map) return;

    final parcial = RoteiroRonda.fromMap(
      Map<String, dynamic>.from(dadosExecucao),
    );

    RoteiroRonda? rotaPausada;
    final dadosRota = pausa['rotaPrincipal'];
    if (dadosRota is Map) {
      rotaPausada = RoteiroRonda.fromMap(
        Map<String, dynamic>.from(dadosRota),
      );
    }

    final resultado = await Navigator.of(context).push<RoteiroRonda>(
      MaterialPageRoute(
        builder: (_) => RondaEmAndamentoPage(
          nome: parcial.nome,
          area: parcial.area,
          rotaPrincipal: rotaPausada,
          execucaoPausada: pausa,
        ),
      ),
    );

    if (!mounted) return;

    if (resultado == null) {
      await _carregarRoteiros();
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (rotaPausada == null) {
      final salvo = await prefs.setString(
        _chaveRotaPrincipal,
        jsonEncode(resultado.toMap()),
      );

      if (!salvo) return;

      await prefs.remove(_chaveExecucaoPausada);
      if (!mounted) return;

      setState(() {
        _rotaPrincipal = resultado;
        _execucaoPausada = null;
      });
      return;
    }

    final rondasAtualizadas = [resultado, ..._rondasFeitas];
    final salvo = await prefs.setString(
      _chaveRondasFeitas,
      jsonEncode(
        rondasAtualizadas.map((item) => item.toMap()).toList(),
      ),
    );

    if (!salvo) return;

    await prefs.remove(_chaveExecucaoPausada);
    if (!mounted) return;

    setState(() {
      _rondasFeitas = rondasAtualizadas;
      _execucaoPausada = null;
    });
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
                                    if (_execucaoPausada != null) ...[
                    FilledButton.icon(
                      onPressed: _carregando ? null : _retomarExecucao,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        _execucaoPausada!['rotaPrincipal'] == null
                            ? 'Continuar gravação'
                            : 'Continuar ronda',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_execucaoPausada == null)
                    OutlinedButton.icon(
                      onPressed: _carregando ? null : _novaRonda,
                      icon: const Icon(Icons.route),
                      label: Text(
                        _rotaPrincipal == null
                            ? 'Gravar roteiro principal'
                            : 'Gravar novamente o roteiro principal',
                      ),
                    ),
                  if (_rotaPrincipal != null &&
                      _execucaoPausada == null) ...[
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
                    if (_roteiros.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Roteiros salvos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            ..._roteiros.map(
              (roteiro) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.route_outlined),
                        title: Text(roteiro.nome),
                        subtitle: Text(
                          '${roteiro.area} • '
                          '${_formatarDistancia(roteiro.distanciaMetros)}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (acao) {
                            if (acao == 'editar') {
                              _editarRoteiro(roteiro);
                            } else if (acao == 'excluir') {
                              _excluirRoteiro(roteiro);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _carregando || _execucaoPausada != null
                              ? null
                              : () => _iniciarExecucao(roteiro),
                          icon: const Icon(Icons.navigation),
                          label: const Text('Navegar nesta ronda'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
        this.execucaoPausada,
  });

  final String nome;
  final String area;
  final RoteiroRonda? rotaPrincipal;
  final Map<String, dynamic>? execucaoPausada;
  @override
  State<RondaEmAndamentoPage> createState() =>
      _RondaEmAndamentoPageState();
}

class _RondaEmAndamentoPageState extends State<RondaEmAndamentoPage>
    with WidgetsBindingObserver {
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
int _indiceProximoPontoRota = 0;
  int? _indiceCurvaEmAndamento;
  int _leiturasForaDaRota = 0;
int _ultimaCurvaAnunciada = -1;
String? _instrucaoAtual;
String? _ultimaChaveInstrucaoFalado;
  int _sequenciaInstrucao = 0;
bool _percursoIniciado = false;
  bool _navegacaoParaInicioEscolhida = false;
  String? _navegacaoEscolhida;
      bool _gpsAgendado = false;
  Animation<double>? _animacaoDaRota;

  @override
  
  void initState() {
    super.initState();
        WidgetsBinding.instance.addObserver(this);

    final pausa = widget.execucaoPausada;
    if (pausa == null) return;

    final dadosExecucao = pausa['execucao'];
    if (dadosExecucao is Map) {
      final execucao = RoteiroRonda.fromMap(
        Map<String, dynamic>.from(dadosExecucao),
      );
      _pontos.addAll(execucao.pontos);
      _distanciaMetros = execucao.distanciaMetros;
    }

    _indiceProximoPontoRota =
        (pausa['indiceProximoPontoRota'] as num?)?.toInt() ?? 0;
    _indiceCurvaEmAndamento =
        (pausa['indiceCurvaEmAndamento'] as num?)?.toInt();
    _percursoIniciado = pausa['percursoIniciado'] == true;
  }
    @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _carregando) return;
    unawaited(_sincronizarGpsAoVoltar());
  }

  Future<void> _sincronizarGpsAoVoltar() async {
    try {
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      if (!mounted) return;
      _registrarPosicao(
        posicao,
        forcar: true,
        ignorarDistancia: true,
      );
    } catch (_) {}
  }
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
  Future<void> _abrirBotaoFlutuante() async {
  try {
    var permitido = await FlutterOverlayWindow.isPermissionGranted();

    if (!permitido) {
      permitido =
          await FlutterOverlayWindow.requestPermission() ?? false;
    }

    if (!permitido) return;

    await FlutterOverlayWindow.showOverlay(
      overlayTitle: 'Ronda Guiada',
      overlayContent: 'Botão flutuante da ronda',
      enableDrag: true,
      height: 80,
      width: 80,
    );
  } catch (_) {}
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

      final configuracao = AndroidSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 5,
  foregroundNotificationConfig: ForegroundNotificationConfig(
    notificationTitle: 'Ronda em andamento',
    notificationText: 'O GPS está acompanhando o percurso.',
    notificationChannelName: 'Ronda guiada',
    enableWakeLock: true,
    setOngoing: true,
  ),
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
    final roteiro = widget.rotaPrincipal;
  if (roteiro == null || !_roteiroTemPercurso(roteiro)) {
    return const <PontoRonda>[];
  }
  return roteiro.pontos
      .where((ponto) => ponto.tipo == TipoPontoRonda.percurso)
      .toList(growable: false);
  }
    final Geocoding _geocoding = Geocoding(
    locale: const Locale('pt', 'BR'),
  );
  String? _nomeRuaAtual;
  DateTime? _ultimaBuscaRua;
  Position? _posicaoUltimaBuscaRua;
  bool _buscandoRua = false;

  Future<String?> _buscarNomeRua(Position posicao) async {
    final agora = DateTime.now();
    final ultimaBusca = _ultimaBuscaRua;
    final posicaoAnterior = _posicaoUltimaBuscaRua;

    final passouTempo = ultimaBusca == null ||
        agora.difference(ultimaBusca).inSeconds >= 15;
    final passouDistancia = posicaoAnterior == null ||
        Geolocator.distanceBetween(
          posicaoAnterior.latitude,
          posicaoAnterior.longitude,
          posicao.latitude,
          posicao.longitude,
        ) >= 30;

    if (_buscandoRua || (!passouTempo && !passouDistancia)) {
      return _nomeRuaAtual;
    }

    _buscandoRua = true;
    _ultimaBuscaRua = agora;
    _posicaoUltimaBuscaRua = posicao;

    try {
      final locais = await _geocoding.placemarkFromCoordinates(
        posicao.latitude,
        posicao.longitude,
      );
      if (locais.isEmpty) return _nomeRuaAtual;

      final local = locais.first;
      final rua = local.thoroughfare?.trim();

      if (rua == null || rua.isEmpty) return _nomeRuaAtual;

      _nomeRuaAtual = rua;
      return rua;
    } catch (_) {
      return _nomeRuaAtual;
    } finally {
      _buscandoRua = false;
    }
  }
    Future<String?> _buscarNomeRuaDoPonto(PontoRonda ponto) async {
    try {
      final locais = await _geocoding.placemarkFromCoordinates(
        ponto.latitude,
        ponto.longitude,
      );

      if (locais.isEmpty) return null;
      return locais.first.thoroughfare?.trim();
    } catch (_) {
      return null;
    }
    }
      Future<void> _anunciarInstrucao(
    String instrucao,
    Object chave, {
    PontoRonda? pontoDaRua,
  }) async {
    if (!mounted) return;

    if (chave is int) {
      if (_ultimaCurvaAnunciada == chave) return;
      _ultimaCurvaAnunciada = chave;
    }

    final chaveTexto = chave.toString();
    if (_ultimaChaveInstrucaoFalado == chaveTexto) return;
    _ultimaChaveInstrucaoFalado = chaveTexto;

    final sequencia = ++_sequenciaInstrucao;
    final rua = pontoDaRua == null
        ? null
        : await _buscarNomeRuaDoPonto(pontoDaRua);

    final instrucaoSemPonto =
        instrucao.replaceFirst(RegExp(r'[.!?]+$'), '');
    final fala = rua == null || rua.isEmpty
        ? instrucao
        : '$instrucaoSemPonto na $rua.';

    if (!mounted || sequencia != _sequenciaInstrucao) return;

    setState(() {
      _instrucaoAtual = fala;
    });

    await _fala.stop();
    if (!mounted || sequencia != _sequenciaInstrucao) return;
    await _fala.speak(fala);
      }

  
}

    void _registrarPosicao(
  Position posicao, {
  bool forcar = false,
  bool ignorarDistancia = false,
}) {
            if (widget.rotaPrincipal != null) {
        _ultimaPosicao = posicao;
        _orientarPelaRota(posicao);
        if (!_percursoIniciado) {
          _acompanharPosicao(posicao);
          return;
        }
            }
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
    _distanciaMetros += ignorarDistancia ? 0 : trechoMetros;
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
        unawaited(_salvarProgressoPausado());
}
    void _pularPontoRota() {
    final rota = _pontosDaRotaSalva;
    if (!_percursoIniciado || _indiceProximoPontoRota >= rota.length - 1) {
      return;
    }

    setState(() {
      _indiceProximoPontoRota =
          (_indiceProximoPontoRota + 1).clamp(0, rota.length - 1).toInt();
      _indiceCurvaEmAndamento = null;
      _leiturasForaDaRota = 0;
    });

    unawaited(_salvarProgressoPausado());
    unawaited(
      _anunciarInstrucao(
        'Ponto pulado por decisão do vigilante. Continue pelo percurso gravado.',
        'ponto-pulado-$_indiceProximoPontoRota',
      ),
    );
    }
    void _iniciarPercursoAqui() {
    if (!mounted) return;
final rota = _pontosDaRotaSalva;
final posicao = _ultimaPosicao;
if (rota.isEmpty || posicao == null) return;

final inicio = rota.first;
final distancia = Geolocator.distanceBetween(
  posicao.latitude,
  posicao.longitude,
  inicio.latitude,
  inicio.longitude,
);
final tolerancia = (posicao.accuracy * 1.5).clamp(50.0, 100.0);

if (distancia > tolerancia) {
  unawaited(
    _anunciarInstrucao(
      'Você ainda está longe do início do percurso. Vá até o início para começar.',
      'inicio-longe',
    ),
  );
  return;
}
    setState(() {
      _percursoIniciado = true;
      _indiceProximoPontoRota = 0;
      _indiceCurvaEmAndamento = null;
      _leiturasForaDaRota = 0;
    });

    unawaited(
      _anunciarInstrucao(
        'Percurso iniciado. Siga pela rota gravada.',
        'inicio-manual',
      ),
    );
    }
  
  Future<void> _abrirNavegacaoAoInicio() async {
  final rota = _pontosDaRotaSalva;
  if (rota.isEmpty) return;

  final inicio = rota.first;
  final uri = Uri.https(
    'www.google.com',
    '/maps/dir/',
    {
      'api': '1',
      'destination': '${inicio.latitude},${inicio.longitude}',
      'travelmode': 'two-wheeler',
    },
  );
      _navegacaoParaInicioEscolhida = true;
  _sequenciaInstrucao++;
  await _fala.stop();

  final abriu = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
if (!abriu) _navegacaoParaInicioEscolhida = false;
  if (!abriu && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível abrir a navegação até o início.'),
      ),
    );
  }
}

void _orientarPelaRota(Position posicao) {
  final rota = _pontosDaRotaSalva;

  if (rota.length < 2) {
    unawaited(
      _anunciarInstrucao(
        'Roteiro sem percurso suficiente. Grave novamente caminhando pelo trajeto.',
        'roteiro-insuficiente',
      ),
    );
    return;
  }

  final inicio = rota.first;
  final distanciaAoInicio = Geolocator.distanceBetween(
    posicao.latitude,
    posicao.longitude,
    inicio.latitude,
    inicio.longitude,
  );

    if (!_percursoIniciado) return;

      final inicioBusca =
      _indiceProximoPontoRota.clamp(0, rota.length - 1).toInt();

    var indiceMaisProximo = inicioBusca;
  var menorDistancia = double.infinity;
  var menorDistanciaDaLinha = double.infinity;

  double distanciaAteSegmento(PontoRonda a, PontoRonda b) {
    const metrosPorGrau = 111320.0;
    final latitudeMedia =
        ((posicao.latitude + a.latitude + b.latitude) / 3) *
            math.pi /
            180;
    final escalaLongitude = metrosPorGrau * math.cos(latitudeMedia);

    final x1 = (a.longitude - posicao.longitude) * escalaLongitude;
    final y1 = (a.latitude - posicao.latitude) * metrosPorGrau;
    final x2 = (b.longitude - posicao.longitude) * escalaLongitude;
    final y2 = (b.latitude - posicao.latitude) * metrosPorGrau;

    final dx = x2 - x1;
    final dy = y2 - y1;
    final comprimentoQuadrado = dx * dx + dy * dy;

    if (comprimentoQuadrado == 0) {
      return math.sqrt(x1 * x1 + y1 * y1);
    }

    final proporcao =
        (-(x1 * dx + y1 * dy) / comprimentoQuadrado).clamp(0.0, 1.0);
    final pontoX = x1 + proporcao * dx;
    final pontoY = y1 + proporcao * dy;

    return math.sqrt(pontoX * pontoX + pontoY * pontoY);
  }

  for (var i = inicioBusca; i < rota.length && i <= inicioBusca + 10; i++) {
    final ponto = rota[i];
    final distancia = Geolocator.distanceBetween(
      posicao.latitude,
      posicao.longitude,
      ponto.latitude,
      ponto.longitude,
    );

    if (distancia < menorDistancia) {
      menorDistancia = distancia;
      indiceMaisProximo = i;
    }
  }

  for (var i = 0; i < rota.length - 1; i++) {
    final distanciaLinha = distanciaAteSegmento(rota[i], rota[i + 1]);
    if (distanciaLinha < menorDistanciaDaLinha) {
      menorDistanciaDaLinha = distanciaLinha;
    }
  }

  final toleranciaForaDaRota =
      (posicao.accuracy * 1.5).clamp(20.0, 35.0).toDouble();

    if (menorDistanciaDaLinha > toleranciaForaDaRota) {
    _leiturasForaDaRota++;
    if (_leiturasForaDaRota == 3) {
      unawaited(
        _anunciarInstrucao(
          'Você saiu do percurso. Volte para a linha azul do mapa.',
          'fora-do-percurso',
        ),
      );
    }
  } else {
    _leiturasForaDaRota = 0;
    }
  if (indiceMaisProximo > _indiceProximoPontoRota) {
  final pontoAtual = rota[inicioBusca];
  final distanciaAoPontoAtual = Geolocator.distanceBetween(
    posicao.latitude,
    posicao.longitude,
    pontoAtual.latitude,
    pontoAtual.longitude,
  );

  final margemAvanco = (posicao.accuracy * 0.5)
      .clamp(5.0, 20.0)
      .toDouble();

  if (distanciaAoPontoAtual - menorDistancia >= margemAvanco) {
    _indiceProximoPontoRota = indiceMaisProximo;
  }
  }
    final pontoFinal = rota.last;
  final distanciaAoFinal = Geolocator.distanceBetween(
    posicao.latitude,
    posicao.longitude,
    pontoFinal.latitude,
    pontoFinal.longitude,
  );

  if (rota.length >= 4 &&
      _indiceProximoPontoRota >= rota.length - 3 &&
      distanciaAoFinal <= 35) {
    unawaited(
      _anunciarInstrucao(
        'Você chegou ao final do percurso gravado.',
        'fim-do-percurso',
      ),
    );
    return;
  }

    final intervalo = rota.length >= 8 ? 3 : 1;

  if (_indiceCurvaEmAndamento != null &&
      _indiceProximoPontoRota > _indiceCurvaEmAndamento!) {
    _indiceCurvaEmAndamento = null;
  }

  if (_indiceCurvaEmAndamento == null) {
    final primeiroIndiceCurva =
        (_indiceProximoPontoRota + intervalo)
            .clamp(0, rota.length - 1)
            .toInt();
    final ultimoIndiceCurva =
        (primeiroIndiceCurva + 40)
            .clamp(0, rota.length - 1)
            .toInt();

    for (var i = primeiroIndiceCurva;
        i + intervalo < rota.length && i <= ultimoIndiceCurva;
        i++) {
      final antes = rota[i - intervalo];
      final curva = rota[i];
      final depois = rota[i + intervalo];

      final rumoAntes = Geolocator.bearingBetween(
        antes.latitude,
        antes.longitude,
        curva.latitude,
        curva.longitude,
      );
      final rumoDepois = Geolocator.bearingBetween(
        curva.latitude,
        curva.longitude,
        depois.latitude,
        depois.longitude,
      );

      var diferenca = rumoDepois - rumoAntes;
      if (diferenca > 180) diferenca -= 360;
      if (diferenca < -180) diferenca += 360;
      if (diferenca.abs() < 45) continue;

      _indiceCurvaEmAndamento = i;
      break;
    }
  }

  final indiceCurva = _indiceCurvaEmAndamento;
  if (indiceCurva != null) {
    final antes = rota[indiceCurva - intervalo];
    final curva = rota[indiceCurva];
    final depois = rota[indiceCurva + intervalo];

    final rumoAntes = Geolocator.bearingBetween(
      antes.latitude,
      antes.longitude,
      curva.latitude,
      curva.longitude,
    );
    final rumoDepois = Geolocator.bearingBetween(
      curva.latitude,
      curva.longitude,
      depois.latitude,
      depois.longitude,
    );

    var diferenca = rumoDepois - rumoAntes;
    if (diferenca > 180) diferenca -= 360;
    if (diferenca < -180) diferenca += 360;

    var distanciaAteCurva = 0.0;
    for (var ponto = _indiceProximoPontoRota;
        ponto < indiceCurva;
        ponto++) {
      distanciaAteCurva += Geolocator.distanceBetween(
        rota[ponto].latitude,
        rota[ponto].longitude,
        rota[ponto + 1].latitude,
        rota[ponto + 1].longitude,
      );
    }

            final lado = diferenca > 0 ? 'direita' : 'esquerda';

        if (distanciaAteCurva <= 10) {
      unawaited(
        _anunciarInstrucao(
          'Vire à $lado agora.',
          'curva-agora-$indiceCurva',
        ),
      );
    } else if (distanciaAteCurva <= 40) {
      unawaited(
        _anunciarInstrucao(
          'Em 30 metros, vire à $lado.',
          'curva-30-$indiceCurva',
        ),
      );
        }
    return;
  }

  unawaited(
    _anunciarInstrucao(
      'Continue pelo percurso gravado. Você está a ${menorDistancia.round()} m da rota.',
      'seguir-percurso',
    ),
  );
}
      void _acompanharPosicao(Position posicao) {
  if (!mounted || !_mapaPronto) return;

  final posicaoAtual = LatLng(posicao.latitude, posicao.longitude);
  _mapController.rotate(0);
  _mapController.move(posicaoAtual, 16);
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
    await _salvarProgressoPausado();
}
    Future<void> _salvarProgressoPausado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final agora = DateTime.now();

      final parcial = RoteiroRonda(
        id: 'pausada-${agora.microsecondsSinceEpoch}',
        nome: widget.nome,
        area: widget.area,
        criadoEm: agora,
        inicioGravacao:
            _pontos.isEmpty ? agora : _pontos.first.dataHora,
        distanciaMetros: _distanciaMetros,
        pontos: List<PontoRonda>.unmodifiable(_pontos),
      );

      await prefs.setString(
        _chaveExecucaoPausada,
        jsonEncode({
          'execucao': parcial.toMap(),
          'rotaPrincipal': widget.rotaPrincipal?.toMap(),
          'indiceProximoPontoRota': _indiceProximoPontoRota,
          'indiceCurvaEmAndamento': _indiceCurvaEmAndamento,
          'percursoIniciado': _percursoIniciado,
        }),
      );
    } catch (_) {}
    }

    Future<void> _sairSemSalvar() async {
    final pausar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pausar ronda?'),
        content: const Text(
          'O progresso será salvo para você continuar depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar ronda'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar e sair'),
          ),
        ],
      ),
    );

    if (pausar != true || !mounted) return;

    await _salvarProgressoPausado();
    await _assinatura?.cancel();

    if (!mounted) return;
    setState(() => _podeSair = true);
    Navigator.pop(context);
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
        WidgetsBinding.instance.removeObserver(this);
    _animacaoDaRota?.removeStatusListener(_esperarFimDaAbertura);
    _assinatura?.cancel();
        FlutterOverlayWindow.closeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final casas = _pontos
        .where((ponto) => ponto.tipo == TipoPontoRonda.casa)
        .toList();
    final pontosRota = _pontosDaRotaSalva;
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
          title: Text(
  widget.rotaPrincipal == null ? 'Gravando roteiro' : 'Seguindo ronda',
),
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
    : widget.rotaPrincipal != null
        ? (_percursoIniciado
    ? 'Seguindo o roteiro salvo'
    : 'A caminho do início do percurso')
        : _gravando
            ? 'Gravação em andamento'
            : 'Gravação pausada',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Distância: ${_formatarDistancia(_distanciaMetros)}',
                    ),
                    Text('Casas marcadas: ${casas.length}'),
                    if (_instrucaoAtual != null)
  Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
  _instrucaoAtual!.toLowerCase().contains('insuficiente')
      ? Icons.warning_amber_rounded
      : _instrucaoAtual!.toLowerCase().contains('direita')
          ? Icons.turn_right
          : _instrucaoAtual!.toLowerCase().contains('esquerda')
              ? Icons.turn_left
              : Icons.straight,
  size: 36,
),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _instrucaoAtual!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
                    if (widget.rotaPrincipal != null && !_percursoIniciado)
  OutlinedButton.icon(
    onPressed: _abrirNavegacaoAoInicio,
    icon: const Icon(Icons.map_outlined),
    label: const Text('Navegar até o início'),
  ),
                                        if (widget.rotaPrincipal != null && !_percursoIniciado)
                      FilledButton.icon(
                        onPressed: _iniciarPercursoAqui,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Já estou no início'),
                      ),
                                        if (widget.rotaPrincipal != null && _percursoIniciado)
                      OutlinedButton.icon(
                        onPressed: _pularPontoRota,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Pular ponto'),
                      ),
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

                                                _acompanharPosicao(posicao);
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
                        if (coordenadasRota.isNotEmpty)
  Marker(
    point: coordenadasRota.first,
    width: 42,
    height: 42,
    child: const Icon(
      Icons.flag,
      color: Colors.green,
      size: 34,
    ),
  ),
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
            if (widget.rotaPrincipal == null)
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
