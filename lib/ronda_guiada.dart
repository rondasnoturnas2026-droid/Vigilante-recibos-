import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'rondas/models/roteiro_ronda.dart';

const String _chaveRoteiros = 'roteirosRondaGuiadaV1';
const String _chaveRotaPrincipal = 'rotaPrincipalRondaV1';
const String _chaveRondasFeitas = 'rondasFeitasRondaV1';
const String _colecaoRondasCompartilhadas = 'rondas_compartilhadas';
const String _chaveSessaoRondaCompartilhada =
    'sessaoRondaCompartilhadaV1';
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
    Future<String> _criarSessaoCompartilhada() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw StateError('Entre na sua conta para compartilhar uma ronda.');
    }

    final sessao = FirebaseFirestore.instance
        .collection(_colecaoRondasCompartilhadas)
        .doc();

    await sessao.set({
      'principalUid': usuario.uid,
      'novatoUid': null,
      'status': 'aguardando',
      'criadoEm': FieldValue.serverTimestamp(),
      'expiraEm': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 12)),
      ),
    });

    return sessao.id;
    }
      Future<void> _solicitarAcompanhamento(
    String sessaoId,
    String nomeVigilante,
  ) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw StateError('Entre na sua conta para solicitar acompanhamento.');
    }

    final pedido = FirebaseFirestore.instance
        .collection(_colecaoRondasCompartilhadas)
        .doc(sessaoId)
        .collection('solicitacoes')
        .doc(usuario.uid);

    await pedido.set({
      'novatoUid': usuario.uid,
      'nomeVigilante': nomeVigilante,
      'status': 'aguardando',
      'solicitadaEm': FieldValue.serverTimestamp(),
    });
      }
      Future<void> _abrirAcompanhamentoNovato() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final sessaoId =
          prefs.getString(_chaveSessaoRondaCompartilhada);

      if (usuario == null || sessaoId == null || sessaoId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compartilhe uma rota antes de acompanhar.'),
          ),
        );
        return;
      }

      final sessao = await FirebaseFirestore.instance
          .collection(_colecaoRondasCompartilhadas)
          .doc(sessaoId)
          .get();

      if (sessao.data()?['principalUid'] != usuario.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Somente o vigilante principal pode acompanhar.'),
          ),
        );
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AcompanharNovatoPage(sessaoId: sessaoId),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o acompanhamento.'),
        ),
      );
    }
      }
      Future<void> _mostrarPedidoAcompanhamento() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final sessaoId =
          prefs.getString(_chaveSessaoRondaCompartilhada);

      if (usuario == null || sessaoId == null || sessaoId.isEmpty) {
        return;
      }

      final sessao = FirebaseFirestore.instance
          .collection(_colecaoRondasCompartilhadas)
          .doc(sessaoId);

      final dadosSessao = await sessao.get();

            if (!dadosSessao.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão de acompanhamento não encontrada.')),
        );
        return;
      }

      if (dadosSessao.data()?['principalUid'] != usuario.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Somente quem compartilhou a rota pode aprovar o pedido.',
            ),
          ),
        );
        return;
      }

      final pedidos = await sessao
          .collection('solicitacoes')
          .where('status', isEqualTo: 'aguardando')
          .limit(1)
          .get();

      if (pedidos.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não há pedido de acompanhamento pendente.'),
          ),
        );
        return;
      }

      final pedido = pedidos.docs.first;
      final nome = pedido.data()['nomeVigilante']?.toString() ?? 'Vigilante';

      final aprovado = await _mostrarDialogoAguardandoFechar<bool>(
        builder: (context) => AlertDialog(
          title: const Text('Pedido de acompanhamento'),
          content: Text('$nome pediu para compartilhar a localização.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Recusar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aprovar'),
            ),
          ],
        ),
      );

      if (aprovado == null || !mounted) return;

      final lote = FirebaseFirestore.instance.batch();

      if (aprovado) {
        lote.update(sessao, {
          'novatoUid': pedido.id,
          'status': 'aprovado',
        });
        lote.update(pedido.reference, {'status': 'aprovado'});
      } else {
        lote.update(pedido.reference, {'status': 'recusado'});
      }

      await lote.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aprovado
                ? 'Pedido de $nome aprovado.'
                : 'Pedido de $nome recusado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível verificar o pedido.'),
        ),
      );
    }
      }
    Future<void> _compartilharRotaPrincipal() async {
    final rota = _rotaPrincipal;

    if (rota == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salve uma rota principal antes de compartilhar.'),
        ),
      );
      return;
    }

        try {
      final sessaoId = await _criarSessaoCompartilhada();
                  final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveSessaoRondaCompartilhada, sessaoId);
      final dadosDaRota = {
        'formato': 'vigilante_recibos_rota',
        'versao': 1,
        'sessaoId': sessaoId,
        'nome': rota.nome,
        'area': rota.area,
        'distanciaMetros': rota.distanciaMetros,
        'pontos': rota.pontos.map((ponto) {
          return {
            'latitude': ponto.latitude,
            'longitude': ponto.longitude,
            'tipo': ponto.tipo.name,
            if (ponto.tipo == TipoPontoRonda.casa)
              'identificacao': ponto.identificacao,
          };
        }).toList(),
      };

      final pasta = await Directory.systemTemp.createTemp('rota_vigilante_');
      final arquivo = File('${pasta.path}/roteiro_ronda.json');

      await arquivo.writeAsString(
        jsonEncode(dadosDaRota),
        encoding: utf8,
      );

      await SharePlus.instance.share(
        ShareParams(
          title: 'Compartilhar roteiro',
          text: 'Roteiro da ronda: ${rota.nome}',
          files: [XFile(arquivo.path)],
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível compartilhar o roteiro.'),
        ),
      );
    }
    }
    Future<void> _importarRoteiro() async {
    try {
      final escolha = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (escolha == null) return;

      final bytes = escolha.files.single.bytes;
      if (bytes == null) throw const FormatException();

      final conteudo = jsonDecode(utf8.decode(bytes));
      if (conteudo is! Map) throw const FormatException();

      final dados = Map<String, dynamic>.from(conteudo);

      if (dados['formato'] != 'vigilante_recibos_rota' ||
          dados['versao'] != 1) {
        throw const FormatException();
      }

      final nome = dados['nome']?.toString().trim() ?? '';
      final area = dados['area']?.toString().trim() ?? '';
      final distancia =
          (dados['distanciaMetros'] as num?)?.toDouble() ?? 0;
      final pontosRecebidos = dados['pontos'];

      if (nome.isEmpty || area.isEmpty || pontosRecebidos is! List) {
        throw const FormatException();
      }

      final pontos = <PontoRonda>[];

      for (final item in pontosRecebidos) {
        if (item is! Map) continue;

        final ponto = Map<String, dynamic>.from(item);
        final latitude = (ponto['latitude'] as num?)?.toDouble();
        final longitude = (ponto['longitude'] as num?)?.toDouble();

        if (latitude == null ||
            longitude == null ||
            latitude < -90 ||
            latitude > 90 ||
            longitude < -180 ||
            longitude > 180) {
          throw const FormatException();
        }

        final tipo = TipoPontoRonda.values.firstWhere(
          (valor) => valor.name == ponto['tipo']?.toString(),
          orElse: () => TipoPontoRonda.percurso,
        );

        pontos.add(
          PontoRonda(
            latitude: latitude,
            longitude: longitude,
            dataHora: DateTime.now(),
            tipo: tipo,
            identificacao: tipo == TipoPontoRonda.casa
                ? ponto['identificacao']?.toString() ?? ''
                : '',
          ),
        );
      }

      final rotaImportada = RoteiroRonda(
        id: dados['sessaoId']?.toString() ??
    DateTime.now().microsecondsSinceEpoch.toString(),
        nome: nome,
        area: area,
        criadoEm: DateTime.now(),
        distanciaMetros: distancia,
        pontos: pontos,
      );

      if (!_roteiroTemPercurso(rotaImportada)) {
        throw const FormatException();
      }

      if (_rotaPrincipal != null) {
        final substituir = await _mostrarDialogoAguardandoFechar<bool>(
          builder: (context) => AlertDialog(
            title: const Text('Substituir rota principal?'),
            content: const Text(
              'A rota recebida será definida como a nova rota principal.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Substituir'),
              ),
            ],
          ),
        );

        if (substituir != true || !mounted) return;
      }

      final prefs = await SharedPreferences.getInstance();
              final sessaoId = dados['sessaoId']?.toString() ?? '';

      if (sessaoId.isEmpty) {
        await prefs.remove(_chaveSessaoRondaCompartilhada);
      } else {
        await prefs.setString(
          _chaveSessaoRondaCompartilhada,
          sessaoId,
        );
      }
      final roteirosAtualizados = [
        rotaImportada,
        ..._roteiros.where((item) => item.id != rotaImportada.id),
      ];

      final salvouLista = await prefs.setString(
        _chaveRoteiros,
        jsonEncode(roteirosAtualizados.map((item) => item.toMap()).toList()),
      );
      final salvouPrincipal = await prefs.setString(
        _chaveRotaPrincipal,
        jsonEncode(rotaImportada.toMap()),
      );

      if (!salvouLista || !salvouPrincipal) {
        throw StateError('Não foi possível salvar a rota.');
      }

      if (!mounted) return;

      setState(() {
        _roteiros = roteirosAtualizados;
        _rotaPrincipal = rotaImportada;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Roteiro importado como rota principal.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível importar esse arquivo de roteiro.',
          ),
        ),
      );
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
              String? sessaoIdParaAcompanhar;
              final prefsSessao = await SharedPreferences.getInstance();
    final sessaoId =
        prefsSessao.getString(_chaveSessaoRondaCompartilhada);
    final rotaRecebida =
        sessaoId != null && sessaoId == rota.id;

    if (rotaRecebida) {
      final permitir = await _mostrarDialogoAguardandoFechar<bool>(
        builder: (context) => AlertDialog(
          title: const Text('Compartilhar localização?'),
          content: const Text(
            'Se permitir, o vigilante principal poderá acompanhar '
            'sua posição durante esta ronda. Você também pode seguir '
            'sem compartilhar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir sem compartilhar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Permitir'),
            ),
          ],
        ),
      );

      if (permitir == true) {
        try {
          await _solicitarAcompanhamento(sessaoId!, nomeVigilante);
                      sessaoIdParaAcompanhar = sessaoId;
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível enviar o pedido de acompanhamento.',
              ),
            ),
          );
        }
      }
    }

    final execucao = await Navigator.of(context).push<RoteiroRonda>(
      MaterialPageRoute(
        builder: (_) => RondaEmAndamentoPage(
          nome: nomeVigilante,
                    area: rota.area,
          rotaPrincipal: rota,
                      sessaoCompartilhadaId: sessaoIdParaAcompanhar,
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
                                      const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _carregando || _execucaoPausada != null
                          ? null
                          : _importarRoteiro,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Importar roteiro recebido'),
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
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _carregando
                          ? null
                          : _compartilharRotaPrincipal,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartilhar roteiro'),
                    ),
                                          const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _carregando
                          ? null
                          : _mostrarPedidoAcompanhamento,
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('Pedidos de acompanhamento'),
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
    this.sessaoCompartilhadaId,
  });

  final String nome;
  final String area;
  final RoteiroRonda? rotaPrincipal;
  final Map<String, dynamic>? execucaoPausada;
  final String? sessaoCompartilhadaId;
  @override
  State<RondaEmAndamentoPage> createState() =>
      _RondaEmAndamentoPageState();
}

class _RondaEmAndamentoPageState extends State<RondaEmAndamentoPage>
    with WidgetsBindingObserver {
  final FlutterTts _fala = FlutterTts();
  final List<PontoRonda> _pontos = [];
  int _indiceInicioTrechoVerde = 0;
  final MapController _mapController = MapController();
  bool _mapaPronto = false;
    StreamSubscription<Position>? _assinatura;
  Position? _ultimaPosicao;
  DateTime? _ultimaAtualizacaoCompartilhada;
  double _distanciaMetros = 0;
  int? _distanciaAteProximaCurva;
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
    _indiceInicioTrechoVerde =
    (pausa['indiceInicioTrechoVerde'] as num?)?.toInt() ?? 0;
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
  distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
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

  

  Future<void> _enviarLocalizacaoCompartilhada(
    Position posicao,
  ) async {
    final sessaoId = widget.sessaoCompartilhadaId;
    final usuario = FirebaseAuth.instance.currentUser;

    if (sessaoId == null || usuario == null) return;

    final agora = DateTime.now();
    final ultimaAtualizacao = _ultimaAtualizacaoCompartilhada;

    if (ultimaAtualizacao != null &&
        agora.difference(ultimaAtualizacao) <
            const Duration(seconds: 10)) {
      return;
    }

    _ultimaAtualizacaoCompartilhada = agora;

    try {
      final sessao = await FirebaseFirestore.instance
          .collection(_colecaoRondasCompartilhadas)
          .doc(sessaoId)
          .get();

      final dados = sessao.data();

      if (!sessao.exists ||
          dados?['status'] != 'aprovado' ||
          dados?['novatoUid'] != usuario.uid) {
        return;
      }

      await FirebaseFirestore.instance
          .collection(_colecaoRondasCompartilhadas)
          .doc(sessaoId)
          .collection('localizacoes')
          .doc(usuario.uid)
          .set({
        'novatoUid': usuario.uid,
        'latitude': posicao.latitude,
        'longitude': posicao.longitude,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _ultimaAtualizacaoCompartilhada = null;
    }
  }
    void _registrarPosicao(
  Position posicao, {
  bool forcar = false,
  bool ignorarDistancia = false,
}) {
            unawaited(_enviarLocalizacaoCompartilhada(posicao));
            if (widget.rotaPrincipal != null) {
        _ultimaPosicao = posicao;
        _orientarPelaRota(posicao);
        if (!_percursoIniciado) {
          _acompanharPosicao(posicao);
          return;
        }
            }
  final anterior = _pontos.isEmpty ? null : _pontos.last;
      if (anterior == null && posicao.accuracy > 25) {
    _ultimaPosicao = posicao;
    _acompanharPosicao(posicao);
    return;
  }
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
      _indiceInicioTrechoVerde = _pontos.length;
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
    _indiceProximoPontoRota =
    (_indiceProximoPontoRota + 1).clamp(0, rota.length - 1).toInt();
  }
  }
      final curvaEmAndamento = _indiceCurvaEmAndamento;
  if (curvaEmAndamento != null &&
      curvaEmAndamento + 1 < rota.length &&
      indiceMaisProximo > curvaEmAndamento &&
      posicao.hasHeading &&
      posicao.speed >= 1) {
    final rumoDaSaida = Geolocator.bearingBetween(
      rota[curvaEmAndamento].latitude,
      rota[curvaEmAndamento].longitude,
      rota[curvaEmAndamento + 1].latitude,
      rota[curvaEmAndamento + 1].longitude,
    );

    var diferencaRumo = posicao.heading - rumoDaSaida;
    if (diferencaRumo > 180) diferencaRumo -= 360;
    if (diferencaRumo < -180) diferencaRumo += 360;

    if (diferencaRumo.abs() <= 45) {
      if (_indiceProximoPontoRota < curvaEmAndamento) {
        _indiceProximoPontoRota = curvaEmAndamento;
      }
      _indiceCurvaEmAndamento = null;
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
      (_indiceProximoPontoRota >= rota.length - 3 ||
          indiceMaisProximo >= rota.length - 3) &&
      distanciaAoFinal <= 35) {
    setState(() {
      _percursoIniciado = false;
      _navegacaoParaInicioEscolhida = false;
      _indiceProximoPontoRota = 0;
      _indiceCurvaEmAndamento = null;
      _leiturasForaDaRota = 0;
      _ultimaChaveInstrucaoFalado = null;
    });

    unawaited(
      _anunciarInstrucao(
        'Fim do percurso. Volte ao início da primeira ronda para repetir o mesmo roteiro.',
        'fim-do-percurso',
      ),
    );
    return;
      }
  

    const intervalo = 2;

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
      if (diferenca.abs() < 30) continue;

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
    final distanciaNoCartao =
    distanciaAteCurva.round().clamp(0, 999999).toInt();

if (_distanciaAteProximaCurva != distanciaNoCartao && mounted) {
  setState(() {
    _distanciaAteProximaCurva = distanciaNoCartao;
  });
}
    final ehRetornoNaMesmaRua = diferenca.abs() >= 150;

                final lado = diferenca > 0 ? 'direita' : 'esquerda';
    var curvasProximas = false;
    var ladoProxima = '';

    for (var i = indiceCurva + (intervalo * 2) + 1;
        i + intervalo < rota.length && i <= indiceCurva + 40;
        i++) {
      final antesProxima = rota[i - intervalo];
      final curvaProxima = rota[i];
      final depoisProxima = rota[i + intervalo];

      final rumoAntesProxima = Geolocator.bearingBetween(
        antesProxima.latitude,
        antesProxima.longitude,
        curvaProxima.latitude,
        curvaProxima.longitude,
      );
      final rumoDepoisProxima = Geolocator.bearingBetween(
        curvaProxima.latitude,
        curvaProxima.longitude,
        depoisProxima.latitude,
        depoisProxima.longitude,
      );

      var diferencaProxima = rumoDepoisProxima - rumoAntesProxima;
      if (diferencaProxima > 180) diferencaProxima -= 360;
      if (diferencaProxima < -180) diferencaProxima += 360;
      if (diferencaProxima.abs() < 30) continue;

      var distanciaEntreCurvas = 0.0;
      for (var ponto = indiceCurva; ponto < i; ponto++) {
        distanciaEntreCurvas += Geolocator.distanceBetween(
          rota[ponto].latitude,
          rota[ponto].longitude,
          rota[ponto + 1].latitude,
          rota[ponto + 1].longitude,
        );
      }

      if (distanciaEntreCurvas <= 40) {
        curvasProximas = true;
        ladoProxima =
            diferencaProxima > 0 ? 'direita' : 'esquerda';
      }
      break;
    }

    final instrucaoAgora = ehRetornoNaMesmaRua
    ? 'Retorne pela mesma rua.'
    : 'Vire à $lado agora.';

final instrucaoAntes = ehRetornoNaMesmaRua
    ? 'Retorne pela mesma rua até a próxima orientação.'
    : curvasProximas
        ? 'Próxima curva: à $lado; depois, à $ladoProxima.'
        : 'Próxima curva: à $lado.';

    if (distanciaAteCurva <= 10) {
      unawaited(
        _anunciarInstrucao(
          instrucaoAgora,
          'curva-agora-$indiceCurva',
          pontoDaRua: curvasProximas ? null : depois,
        ),
      );
    } else if (distanciaAteCurva <= 70) {
      unawaited(
        _anunciarInstrucao(
          instrucaoAntes,
          'curva-antes-$indiceCurva',
          pontoDaRua: curvasProximas ? null : depois,
        ),
      );
    }

    return;
  }
  if (_distanciaAteProximaCurva != null && mounted) {
  setState(() {
    _distanciaAteProximaCurva = null;
  });
  }

  unawaited(
    _anunciarInstrucao(
      'Continue pelo percurso gravado.',
      'seguir-percurso',
    ),
  );
}
      void _acompanharPosicao(Position posicao) {
  if (!mounted || !_mapaPronto) return;

  final posicaoAtual = LatLng(posicao.latitude, posicao.longitude);
  if (posicao.hasHeading && posicao.speed >= 1) {
  _mapController.rotate(-posicao.heading);
  }
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
          'indiceInicioTrechoVerde': _indiceInicioTrechoVerde,
        }),
      );
    } catch (_) {}
    }
      Future<void> _encerrarAcompanhamento() async {
    final sessaoId = widget.sessaoCompartilhadaId;
    if (sessaoId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection(_colecaoRondasCompartilhadas)
          .doc(sessaoId)
          .update({
        'status': 'encerrado',
        'encerradoEm': FieldValue.serverTimestamp(),
      });
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
            await _encerrarAcompanhamento();
    await _assinatura?.cancel();

    if (!mounted) return;
    setState(() => _podeSair = true);
    Navigator.pop(context);
    }

  Future<void> _finalizar() async {
          await _encerrarAcompanhamento();
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
    .skip(_indiceInicioTrechoVerde)
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
                    if (widget.rotaPrincipal != null &&
    _percursoIniciado &&
    _distanciaAteProximaCurva != null)
  Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          Icons.navigation,
          size: 28,
          color: Theme.of(context).colorScheme.onTertiaryContainer,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Próxima curva',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_distanciaAteProximaCurva!} m',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
  Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      'Próxima curva: ${_distanciaAteProximaCurva} m',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
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
  size: 32,
),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _instrucaoAtual!,
              style: const TextStyle(
                fontSize: 16,
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
              height: (MediaQuery.sizeOf(context).height * 0.50)
    .clamp(360.0, 520.0)
    .toDouble(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
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
                    if (_percursoIniciado && coordenadasGravadas.length > 1)
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
class AcompanharNovatoPage extends StatelessWidget {
  const AcompanharNovatoPage({
    super.key,
    required this.sessaoId,
  });

  final String sessaoId;

  @override
  Widget build(BuildContext context) {
    final sessaoRef = FirebaseFirestore.instance
        .collection(_colecaoRondasCompartilhadas)
        .doc(sessaoId);

    return Scaffold(
      appBar: AppBar(title: const Text('Acompanhar novato')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: sessaoRef.snapshots(),
        builder: (context, sessaoSnapshot) {
          if (sessaoSnapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar a sessão.'),
            );
          }

          if (!sessaoSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final dadosSessao = sessaoSnapshot.data!.data();

          if (dadosSessao == null) {
            return const Center(child: Text('Sessão não encontrada.'));
          }

          if (dadosSessao['status'] != 'aprovado') {
            final encerrada = dadosSessao['status'] == 'encerrado';
            return Center(
              child: Text(
                encerrada
                    ? 'A ronda foi encerrada.'
                    : 'Aguardando aprovação do acompanhamento.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final novatoUid = dadosSessao['novatoUid']?.toString();

          if (novatoUid == null || novatoUid.isEmpty) {
            return const Center(
              child: Text('Ainda não há vigilante nesta sessão.'),
            );
          }

          final localizacaoRef = sessaoRef
              .collection('localizacoes')
              .doc(novatoUid);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: localizacaoRef.snapshots(),
            builder: (context, localizacaoSnapshot) {
              if (localizacaoSnapshot.hasError) {
                return const Center(
                  child: Text('Não foi possível carregar a localização.'),
                );
              }

              if (!localizacaoSnapshot.hasData ||
                  !localizacaoSnapshot.data!.exists) {
                return const Center(
                  child: Text('Aguardando a primeira localização do novato.'),
                );
              }

              final dados = localizacaoSnapshot.data!.data();
              final latitude = (dados?['latitude'] as num?)?.toDouble();
              final longitude = (dados?['longitude'] as num?)?.toDouble();

              if (latitude == null || longitude == null) {
                return const Center(
                  child: Text('Localização inválida.'),
                );
              }

              final ponto = LatLng(latitude, longitude);

              return FlutterMap(
                key: ValueKey('${latitude}_$longitude'),
                options: MapOptions(
                  initialCenter: ponto,
                  initialZoom: 16,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'br.com.vigilanterecibos.vigilante_recibos',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: ponto,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.red,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
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
