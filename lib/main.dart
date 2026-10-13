
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
final ValueNotifier<ThemeMode> temaApp =
    ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setEnabledSystemUIMode(
  SystemUiMode.immersiveSticky,
);

  final prefs = await SharedPreferences.getInstance();
  final temaSalvo = prefs.getString('temaApp') ?? 'automatico';

  if (temaSalvo == 'escuro') {
    temaApp.value = ThemeMode.dark;
  } else if (temaSalvo == 'claro') {
    temaApp.value = ThemeMode.light;
  } else {
    temaApp.value = ThemeMode.system;
  }

  runApp(const VigilanteRecibosApp());
}

class VigilanteRecibosApp extends StatelessWidget {
  const VigilanteRecibosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaApp,
      builder: (context, modoTema, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Vigilante Recibos',
            locale: const Locale('pt', 'BR'),
supportedLocales: const [
  Locale('pt', 'BR'),
],
localizationsDelegates: const [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
],

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          themeMode: modoTema,

          home: const TelaPrincipal(),
        );
      },
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal>
    with WidgetsBindingObserver {
  int paginaAtual = 0;

  final AppStore store = AppStore();
  late final List<Widget> paginas;
  bool _reconectandoImpressora = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    store.carregarDadosVigilante();
    store.carregarBairrosERuas();

    paginas = [
      TelaMensalidades(store: store),
      TelaClientes(store: store),
      const TelaRelatorio(),
      TelaConfiguracoes(store: store),
    ];

    _reconectarImpressora();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconectarImpressora();
    }
  }

  Future<void> _reconectarImpressora() async {
  if (_reconectandoImpressora) return;
  _reconectandoImpressora = true;

  try {
    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final macSalvo = prefs.getString('impressoraMac');

    if (macSalvo == null || macSalvo.isEmpty) return;

    final bluetoothLigado =
        await PrintBluetoothThermal.bluetoothEnabled;
    if (!bluetoothLigado) return;

    for (var tentativa = 0; tentativa < 3; tentativa++) {
      if (await PrintBluetoothThermal.connectionStatus) return;

      try {
        await ImpressoraBluetoothService.conectar(macSalvo);
      } catch (_) {
        // Tenta novamente se a conexão falhar.
      }

      await Future.delayed(const Duration(seconds: 1));
      if (await PrintBluetoothThermal.connectionStatus) return;
    }
  } catch (_) {
    // Mantém o app aberto mesmo se o Bluetooth falhar.
  } finally {
    _reconectandoImpressora = false;
    if (mounted) {
  setState(() {
    if (paginaAtual == 0) {
      paginas[0] = TelaMensalidades(store: store);
    }
  });
    }
  }
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: paginas[paginaAtual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: paginaAtual,
        onDestinationSelected: (index) {
          setState(() {
            paginaAtual = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Mensalidades',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Relatório',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config.',
          ),
        ],
      ),
    );
  }
}

class TelaMensalidades extends StatefulWidget {
  final AppStore store;

  const TelaMensalidades({super.key, required this.store});

  @override
  State<TelaMensalidades> createState() => _TelaMensalidadesState();
}

class _TelaMensalidadesState extends State<TelaMensalidades> {
    int abaAtual = 0;
  String bairroFiltro = 'Todos os bairros';
  String ruaFiltro = 'Todas as ruas';
  String diaFiltro = 'Todos os dias';
    String buscaMensalidade = '';
    bool buscaAberta = false;
  String pagamentoFiltro = 'Todas as formas';
    bool totalVisivel = true;

  List<String> _valoresUnicos(String chave) {
    final valores = widget.store.mensalidades
        .map((mensalidade) => (mensalidade[chave] ?? '').toString().trim())
        .where((valor) => valor.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return valores;
  }

  List<String> get bairrosDisponiveis => _valoresUnicos('bairro');

  List<String> get ruasDisponiveis {
    final ruas = widget.store.mensalidades
        .where((mensalidade) =>
            bairroFiltro == 'Todos os bairros' ||
            (mensalidade['bairro'] ?? '').toString() == bairroFiltro)
        .map((mensalidade) => (mensalidade['rua'] ?? '').toString().trim())
        .where((rua) => rua.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ruas;
  }

  List<String> get diasDisponiveis {
    final dias = _valoresUnicos('dia');
    dias.sort((a, b) =>
        (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    return dias;
  }

  List<String> get formasPagamentoDisponiveis =>
      _valoresUnicos('formaPagamento');
  @override
  void initState() {
    super.initState();
    _carregarMensalidades();
  }

  Future<void> _carregarMensalidades() async {
  await widget.store.carregarClientes();
  await widget.store.carregarMensalidades();
  if (!mounted) return;
      await _gerarMensalidadesAutomaticas();
  setState(() {});
  }
      Future<void> _gerarMensalidadesAutomaticas() async {
  final prefs = await SharedPreferences.getInstance();
  final modo =
      prefs.getString('modoGeracaoMensalidade') ?? 'ao_longo_do_mes';
  final diasAntes =
      prefs.getInt('diasAntecedenciaMensalidade') ?? 0;
  final gerarMesInteiro = modo == 'mes_completo';

  if (!gerarMesInteiro && (diasAntes < 1 || diasAntes > 31)) {
    return;
  }

  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);
  bool alterou = false;

  String normalizar(Object? valor) =>
      (valor ?? '').toString().trim().toLowerCase();

  for (final cliente in widget.store.clientes) {
    final dia = int.tryParse((cliente['dia'] ?? '').toString());
    if (dia == null || dia < 1 || dia > 31) continue;

    final quantidadeMeses = gerarMesInteiro ? 1 : 2;

    for (var deslocamentoMes = 0;
        deslocamentoMes < quantidadeMeses;
        deslocamentoMes++) {
      final mesBase = DateTime(
        hoje.year,
        hoje.month + deslocamentoMes,
        1,
      );

      final ultimoDia = DateTime(
        mesBase.year,
        mesBase.month + 1,
        0,
      ).day;

      final vencimento = DateTime(
        mesBase.year,
        mesBase.month,
        dia > ultimoDia ? ultimoDia : dia,
      );

      final dataGeracao =
          vencimento.subtract(Duration(days: diasAntes));

      if (!gerarMesInteiro && hoje.isBefore(dataGeracao)) {
        continue;
      }

      final jaExiste = widget.store.mensalidades.any((mensalidade) {
        return normalizar(mensalidade['nome']) ==
                normalizar(cliente['nome']) &&
            normalizar(mensalidade['bairro']) ==
                normalizar(cliente['bairro']) &&
            normalizar(mensalidade['rua']) ==
                normalizar(cliente['rua']) &&
            normalizar(mensalidade['numero']) ==
                normalizar(cliente['numero']) &&
            normalizar(mensalidade['mes']) ==
                vencimento.month.toString() &&
            normalizar(mensalidade['ano']) ==
                vencimento.year.toString();
      });

      if (jaExiste) continue;

      widget.store.mensalidades.add({
        'nome': cliente['nome'] ?? '',
        'bairro': cliente['bairro'] ?? '',
        'rua': cliente['rua'] ?? '',
        'numero': cliente['numero'] ?? '',
        'dia': cliente['dia'] ?? '',
        'valor': cliente['valor'] ?? '0,00',
        'formaPagamento': cliente['formaPagamento'] ?? 'Pix',
        'status': 'pendente',
        'mes': vencimento.month,
        'ano': vencimento.year,
      });

      alterou = true;
    }
  }

  if (alterou) {
    await widget.store.salvarMensalidades();
  }
}
    Future<void> _mostrarQrPix(Map<String, dynamic> mensalidade) async {
  final chavePix = widget.store.vigilanteChavePix.trim();

  if (chavePix.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastre a chave Pix nas configurações.')),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Pagamento Pix'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cliente: ${mensalidade['nome'] ?? 'Cliente'}'),
          const SizedBox(height: 8),
          const Text('Chave Pix:'),
          SelectableText(chavePix),
          const SizedBox(height: 8),
          Text('Valor: R\$ ${mensalidade['valor'] ?? '0,00'}'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: chavePix));
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chave Pix copiada.')),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar chave'),
        ),
      ],
    ),
  );
    }
    Future<void> _compartilharReciboWhatsApp(
  Map<String, dynamic> mensalidade,
) async {
  try {
    final agora = DateTime.now();

    final empresa = widget.store.vigilanteNomeFantasia.trim().isNotEmpty
        ? widget.store.vigilanteNomeFantasia.trim()
        : widget.store.vigilanteNome.trim().isNotEmpty
            ? widget.store.vigilanteNome.trim()
            : 'VIGILANTE RECIBOS';

    final cliente = (mensalidade['nome'] ?? 'Cliente').toString();
    final valor = (mensalidade['valor'] ?? '0,00').toString();
        final pagamento =
        (mensalidade['formaPagamento'] ?? 'Não informado').toString();
    final periodoAdiantamento =
        (mensalidade['periodoAdiantamento'] ?? '').toString().trim();
    final ehAdiantamento = periodoAdiantamento.isNotEmpty;

    String dataFormatada(DateTime data) =>
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';

    final diaVencimento =
        int.tryParse((mensalidade['dia'] ?? '').toString()) ?? agora.day;
    final mesVencimento =
        int.tryParse((mensalidade['mes'] ?? '').toString()) ?? agora.month;
    final anoVencimento =
        int.tryParse((mensalidade['ano'] ?? '').toString()) ?? agora.year;

    const largura = 1080;
    const altura = 1450;

    final gravador = ui.PictureRecorder();
    final canvas = ui.Canvas(gravador);

    canvas.drawColor(const Color(0xFFF2F4F8), ui.BlendMode.src);

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(40, 40, 1000, 1370),
        const ui.Radius.circular(36),
      ),
      ui.Paint()..color = Colors.white,
    );

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(40, 40, 1000, 290),
        const ui.Radius.circular(36),
      ),
      ui.Paint()..color = const Color(0xFF17365D),
    );

    void escrever(
      String texto,
      double y, {
      double tamanho = 38,
      Color cor = const Color(0xFF202938),
      FontWeight peso = FontWeight.normal,
    }) {
      final pintor = TextPainter(
        text: TextSpan(
          text: texto,
          style: TextStyle(
            color: cor,
            fontSize: tamanho,
            fontWeight: peso,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      );

      pintor.layout(maxWidth: 880);
      pintor.paint(canvas, ui.Offset(100, y));
    }

    void separador(double y) {
      canvas.drawLine(
        ui.Offset(100, y),
        ui.Offset(980, y),
        ui.Paint()
          ..color = const Color(0xFFE1E6ED)
          ..strokeWidth = 3,
      );
    }

    escrever(
      empresa,
      95,
      tamanho: 44,
      cor: Colors.white,
      peso: FontWeight.bold,
    );
    escrever(
      'RECIBO DE PAGAMENTO',
      165,
      tamanho: 38,
      cor: const Color(0xFFFFD166),
      peso: FontWeight.bold,
    );
    escrever(
      'PAGAMENTO RECEBIDO',
      225,
      tamanho: 30,
      cor: Colors.white,
    );

    escrever('CLIENTE', 390, tamanho: 28, cor: Colors.blueGrey);
    escrever(cliente, 435, tamanho: 44, peso: FontWeight.bold);
    separador(520);

    escrever('VALOR PAGO', 560, tamanho: 28, cor: Colors.blueGrey);
    escrever(
      'R\$ $valor',
      605,
      tamanho: 54,
      cor: const Color(0xFF17365D),
      peso: FontWeight.bold,
    );
    separador(700);

    escrever('FORMA DE PAGAMENTO', 740, tamanho: 28, cor: Colors.blueGrey);
    escrever(pagamento, 785, tamanho: 40, peso: FontWeight.bold);
    separador(865);

    escrever(
  ehAdiantamento ? 'PERÍODO ADIANTADO' : 'VENCIMENTO',
  905,
  tamanho: 28,
  cor: Colors.blueGrey,
);
escrever(
  ehAdiantamento
      ? periodoAdiantamento
      : dataFormatada(DateTime(anoVencimento, mesVencimento, diaVencimento)),
  950,
  tamanho: 40,
  peso: FontWeight.bold,
);
    separador(1030);

    escrever('RECEBIDO EM', 1070, tamanho: 28, cor: Colors.blueGrey);
    escrever(dataFormatada(agora), 1115, tamanho: 40, peso: FontWeight.bold);
    escrever(
      'Obrigado pela confiança!',
      1270,
      tamanho: 34,
      cor: const Color(0xFF17365D),
      peso: FontWeight.bold,
    );

    final imagem = await gravador.endRecording().toImage(largura, altura);
    final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);

    if (dados == null) {
      throw Exception('Não foi possível criar a imagem do recibo.');
    }

    final arquivo = File(
      '${Directory.systemTemp.path}/recibo_${agora.millisecondsSinceEpoch}.png',
    );

    await arquivo.writeAsBytes(
      dados.buffer.asUint8List(),
      flush: true,
    );

    await SharePlus.instance.share(
      ShareParams(
        title: 'Recibo de pagamento',
        text: 'Recibo de pagamento de $cliente',
        files: [
          XFile(arquivo.path, mimeType: 'image/png'),
        ],
      ),
    );
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível preparar o recibo para compartilhar.'),
      ),
    );
  }
    }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
              appBar: AppBar(
        title: const Text('Mensalidades'),
        
        actions: [
                      FutureBuilder<bool>(
            future: ImpressoraBluetoothService.estaConectada(),
            builder: (context, snapshot) {
              final conectada = snapshot.data ?? false;
              return Tooltip(
                message: conectada
                    ? 'Impressora pronta'
                    : 'Impressora desconectada',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.print_rounded,
size: 18,
                    color: conectada ? Colors.green : Colors.red,
                  ),
                ),
              );
            },
          ),
          IconButton(
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Colors.blue.shade100,
              minimumSize: const Size(44, 44),
            ),
            icon: Icon(buscaAberta ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                buscaAberta = !buscaAberta;
                if (!buscaAberta) buscaMensalidade = '';
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
              body: Column(
                  children: [
                  if (buscaAberta)
  Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: TextField(
      autofocus: true,
      onChanged: (texto) {
        setState(() {
          buscaMensalidade = texto;
        });
      },
      decoration: InputDecoration(
        hintText: 'Buscar mensalidade por nome, bairro ou rua',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
      ),
    ),
  ),
        Padding(
          
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Pendentes'),
                    selected: abaAtual == 0,
                    onSelected: (_) {
                      setState(() {
                        abaAtual = 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Recebidas'),
                    selected: abaAtual == 1,
                    onSelected: (_) {
                      setState(() {
                        abaAtual = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Inativos'),
                    selected: abaAtual == 2,
                    onSelected: (_) {
                      setState(() {
                        abaAtual = 2;
                      });
                    },
                  ),
                ),
              ],
                      ),
            ),
          Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  child: Column(
    children: [
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: bairroFiltro,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Bairro',
                border: OutlineInputBorder(),
              ),
              items: [
                'Todos os bairros',
                ...bairrosDisponiveis,
              ].toSet().map((bairro) {
                return DropdownMenuItem(
                  value: bairro,
                  child: Text(bairro, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (valor) {
                if (valor == null) return;
                setState(() {
                  bairroFiltro = valor;
                  ruaFiltro = 'Todas as ruas';
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: ruaFiltro,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Rua',
                border: OutlineInputBorder(),
              ),
              items: [
                'Todas as ruas',
                ...ruasDisponiveis,
              ].toSet().map((rua) {
                return DropdownMenuItem(
                  value: rua,
                  child: Text(rua, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (valor) {
                if (valor == null) return;
                setState(() {
                  ruaFiltro = valor;
                });
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: diaFiltro,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Dia',
                border: OutlineInputBorder(),
              ),
              items: [
                'Todos os dias',
                ...diasDisponiveis,
              ].toSet().map((dia) {
                return DropdownMenuItem(
                  value: dia,
                  child: Text(dia, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (valor) {
                if (valor == null) return;
                setState(() {
                  diaFiltro = valor;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: pagamentoFiltro,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pagamento',
                border: OutlineInputBorder(),
              ),
              items: [
                'Todas as formas',
                ...formasPagamentoDisponiveis,
              ].toSet().map((forma) {
                return DropdownMenuItem(
                  value: forma,
                  child: Text(forma, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (valor) {
                if (valor == null) return;
                setState(() {
                  pagamentoFiltro = valor;
                });
              },
            ),
          ),
        ],
      ),
    ],
  ),
          ),    
                    Expanded(
            child: Builder(
              builder: (context) {
                final statusDesejado = abaAtual == 0
                    ? 'pendente'
                    : abaAtual == 1
                        ? 'recebida'
                        : 'inativo';

                final mensalidadesFiltradas =
                    widget.store.mensalidades.where((mensalidade) {
                  final status =
                      (mensalidade['status'] ?? '').toString().toLowerCase();
                  final bairro =
                      (mensalidade['bairro'] ?? '').toString();
                  final rua = (mensalidade['rua'] ?? '').toString();
                  final numero =
                      (mensalidade['numero'] ?? '').toString();
                  final nome = (mensalidade['nome'] ?? '').toString();
                  final dia = (mensalidade['dia'] ?? '').toString();
                  final pagamento =
                      (mensalidade['formaPagamento'] ?? '').toString();
                  final busca = buscaMensalidade.trim().toLowerCase();

                  final correspondeBusca = busca.isEmpty ||
                      nome.toLowerCase().contains(busca) ||
                      rua.toLowerCase().contains(busca) ||
                      numero.toLowerCase().contains(busca) ||
                      bairro.toLowerCase().contains(busca);

                  return status == statusDesejado &&
    correspondeBusca &&
    (bairroFiltro == 'Todos os bairros' ||
        bairro == bairroFiltro) &&
    (ruaFiltro == 'Todas as ruas' ||
        rua == ruaFiltro) &&
    (diaFiltro == 'Todos os dias' ||
        int.tryParse(dia) == int.tryParse(diaFiltro)) &&
    (pagamentoFiltro == 'Todas as formas' ||
        pagamento == pagamentoFiltro);
                }).toList();
                  if (abaAtual == 0) {
  mensalidadesFiltradas.sort((a, b) {
    final diaA = int.tryParse((a['dia'] ?? '0').toString()) ?? 0;
    final diaB = int.tryParse((b['dia'] ?? '0').toString()) ?? 0;
    return diaA.compareTo(diaB);
  });
                  }

                if (mensalidadesFiltradas.isEmpty) {
                  return Center(
                    child: Text(
                      abaAtual == 0
                          ? 'Nenhuma mensalidade pendente'
                          : abaAtual == 1
                              ? 'Nenhuma mensalidade recebida'
                              : 'Nenhuma mensalidade inativa',
                    ),
                  );
                }
final totalMensalidades = mensalidadesFiltradas.fold<double>(
  0.0,
  (soma, mensalidade) {
    final valorBruto = mensalidade['valor'];
    final valor = valorBruto is num
        ? valorBruto.toDouble()
        : (double.tryParse(
              valorBruto
                  .toString()
                  .replaceAll('R\$', '')
                  .replaceAll('.', '')
                  .replaceAll(',', '.')
                  .trim(),
            ) ??
            0.0);

    return soma + valor;
  },
);
                  if (abaAtual == 0 || abaAtual == 1) {
  mensalidadesFiltradas.sort((a, b) {
    final anoA = int.tryParse((a['ano'] ?? '0').toString()) ?? 0;
    final anoB = int.tryParse((b['ano'] ?? '0').toString()) ?? 0;
    final compararAno = anoB.compareTo(anoA);
    if (compararAno != 0) return compararAno;

    final mesA = int.tryParse((a['mes'] ?? '0').toString()) ?? 0;
    final mesB = int.tryParse((b['mes'] ?? '0').toString()) ?? 0;
    final compararMes = mesB.compareTo(mesA);
    if (compararMes != 0) return compararMes;

    final diaA = int.tryParse((a['dia'] ?? '0').toString()) ?? 0;
    final diaB = int.tryParse((b['dia'] ?? '0').toString()) ?? 0;
    return diaA.compareTo(diaB);
  });
                  }

final listaAgrupada = <Map<String, dynamic>>[];
String? mesAnterior;

for (final mensalidade in mensalidadesFiltradas) {
  final mes = int.tryParse((mensalidade['mes'] ?? '').toString()) ?? 0;
  final ano = (mensalidade['ano'] ?? '').toString();
  final mesAno = '${mes.toString().padLeft(2, '0')}/$ano';

  if (mesAno != mesAnterior) {
    listaAgrupada.add({'separadorMes': mesAno});
    mesAnterior = mesAno;
  }

  listaAgrupada.add({'mensalidade': mensalidade});
}

return ListView.builder(
  itemCount: listaAgrupada.length + 1,
  itemBuilder: (context, index) {
    if (index == 0) {
      return Card(
        child: ListTile(
          title: const Text('Total das mensalidades'),
          subtitle: Text(
            totalVisivel
                ? 'R\$ ${totalMensalidades.toStringAsFixed(2).replaceAll('.', ',')}'
                : 'R\$ •••••',
          ),
          trailing: IconButton(
            icon: Icon(
              totalVisivel ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                totalVisivel = !totalVisivel;
              });
            },
          ),
        ),
      );
    }

    final itemLista = listaAgrupada[index - 1];

    if (itemLista.containsKey('separadorMes')) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'MÊS ${itemLista['separadorMes']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
      );
    }

    final mensalidade =
        itemLista['mensalidade'] as Map<String, dynamic>;
                    final valor =
                        (mensalidade['valor'] ?? '0,00').toString();
                    final nome =
                        (mensalidade['nome'] ?? 'Cliente').toString();

                    return Card(
                      child: ExpansionTile(
                        key: PageStorageKey<int>(index),
                        title: Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(
  'Mês/Ano: ${(mensalidade['mes'] ?? '').toString().padLeft(2, '0')}/${mensalidade['ano'] ?? ''}',
  style: const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
  ),
),
const SizedBox(height: 2),
                            Text(
                              'Rua: ' +
                                  (mensalidade['rua'] ?? '').toString() +
                                  ', Nº ' +
                                  (mensalidade['numero'] ?? '').toString(),
                              style: const TextStyle(fontSize: 17),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  (mensalidade['dia'] ?? '')
                                      .toString()
                                      .padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Pagamento: ' +
                                        (mensalidade['formaPagamento'] ?? '')
                                            .toString(),
                                    style: const TextStyle(fontSize: 17),
                                  ),
                                ),
                              ],
                            ),
                              if ((mensalidade['retorno'] ?? '').toString().isNotEmpty)
  Text(
    'Retorno: ${mensalidade['retorno']}',
    style: const TextStyle(fontSize: 15),
  ),
                          ],
                        ),
                        trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'R\$ ' + valor,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(width: 8),
    const Icon(Icons.expand_more),
  ],
),
children: [
  if (abaAtual == 2)
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _reativarCliente(mensalidade),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Reativar cliente'),
          ),
          OutlinedButton.icon(
            onPressed: () => _excluirMensalidade(mensalidade),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir mensalidade'),
          ),
            OutlinedButton.icon(
  onPressed: () async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cliente'),
        content: Text(
          'Atenção: o cadastro de ${mensalidade['nome'] ?? 'este cliente'} '
          'será excluído da aba Clientes. As mensalidades e os recibos já '
          'registrados serão mantidos no histórico. Para gerar novas '
          'mensalidades para esse cliente, será necessário cadastrá-lo '
          'novamente. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final nome = (mensalidade['nome'] ?? '').toString();
    final bairro = (mensalidade['bairro'] ?? '').toString();
    final rua = (mensalidade['rua'] ?? '').toString();
    final numero = (mensalidade['numero'] ?? '').toString();

    widget.store.clientes.removeWhere(
      (cliente) =>
          (cliente['nome'] ?? '').toString() == nome &&
          (cliente['bairro'] ?? '').toString() == bairro &&
          (cliente['rua'] ?? '').toString() == rua &&
          (cliente['numero'] ?? '').toString() == numero,
    );

    await widget.store.salvarClientes();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cliente excluído da lista. Histórico das mensalidades mantido.',
        ),
      ),
    );
  },
  icon: const Icon(Icons.person_remove_alt_1),
  label: const Text('Excluir cliente'),
),
        ],
      ),
    ),
                                  if (abaAtual == 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () async {
                                      final confirmarRecebimento = await showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Confirmar recebimento'),
    content: const Text('Confirma o recebimento desta mensalidade?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: const Text('Confirmar'),
      ),
    ],
  ),
);

if (confirmarRecebimento != true) return;
                                    mensalidade['status'] = 'recebida';
                                    await widget.store.salvarMensalidades();

                                    if (!mounted) return;
                                    setState(() {});

                                    final acaoRecibo = await showDialog<String>(
                                      context: context,
                                      builder: (dialogContext) =>
                                          AlertDialog(
                                        title: const Text(
                                          'Recibo da mensalidade',
                                        ),
                                        content: const Text(
                                          'Recebimento confirmado. O que deseja fazer com o recibo?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                              dialogContext,
                                              'nao',
                                            ),
                                            child: const Text('Não'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(
                                              dialogContext,
                                              'whatsapp',
                                            ),
                                            child: const Text(
                                              'Enviar pelo WhatsApp',
                                            ),
                                          ),
                                          FilledButton.icon(
                                            onPressed: () =>
                                                Navigator.pop(
                                              dialogContext,
                                              'imprimir',
                                            ),
                                            icon: const Icon(Icons.print),
                                            label: const Text('Imprimir'),
                                          ),
                                        ],
                                      ),
                                    );
                                      if (acaoRecibo == 'whatsapp') {
  await _compartilharReciboWhatsApp(mensalidade);
} else if (acaoRecibo == 'imprimir') {
  final agora = DateTime.now();

  final dia =
      int.tryParse((mensalidade['dia'] ?? '').toString()) ?? agora.day;
  final mes =
      int.tryParse((mensalidade['mes'] ?? '').toString()) ?? agora.month;
  final ano =
      int.tryParse((mensalidade['ano'] ?? '').toString()) ?? agora.year;

  final periodo =
      (mensalidade['periodoAdiantamento'] ?? '').toString().trim();

  final vencimento = periodo.isNotEmpty
      ? periodo
      : '${dia.toString().padLeft(2, '0')}/'
          '${mes.toString().padLeft(2, '0')}/$ano';

  final dataRecebimento =
      '${agora.day.toString().padLeft(2, '0')}/'
      '${agora.month.toString().padLeft(2, '0')}/'
      '${agora.year}';

  final sucesso = await ImpressoraBluetoothService.imprimirRecibo(
    nomeMorador: (mensalidade['nome'] ?? 'Cliente').toString(),
    valor: (mensalidade['valor'] ?? '0,00').toString(),
    formaPagamento:
        (mensalidade['formaPagamento'] ?? 'Não informado').toString(),
    vencimento: vencimento,
    dataRecebimento: dataRecebimento,

 );

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sucesso
            ? 'Recibo impresso.'
            : 'Não foi possível imprimir. Confira se a impressora está conectada.',
      ),
    ),
  );
}
                                  },
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                  ),
                                  label: const Text('Receber'),
                                ),
                              ),
                            ),

                                
                            if (abaAtual == 0)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _mostrarQrPix(mensalidade),
          icon: const Icon(Icons.qr_code_2),
          label: const Text('QR Pix'),
        ),
        OutlinedButton.icon(
          onPressed: () => _marcarRetorno(mensalidade),
          icon: const Icon(Icons.event),
          label: const Text('Retorno'),
        ),
        OutlinedButton.icon(
          onPressed: () => _editarMensalidade(mensalidade),
          icon: const Icon(Icons.edit),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          onPressed: () => _receberMesesAdiantados(mensalidade),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Meses adiantados'),
        ),
        OutlinedButton.icon(
          onPressed: () => _inativarCliente(mensalidade),
          icon: const Icon(Icons.person_off_outlined),
          label: const Text('Inativar Cliente'),
        ),
        OutlinedButton.icon(
          onPressed: () => _excluirMensalidade(mensalidade),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir'),
        ),
                  OutlinedButton.icon(
          onPressed: () async {
              final confirmarImpressao = await showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Confirmar impressão'),
    content: const Text('Deseja imprimir este recibo?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: const Text('Imprimir'),
      ),
    ],
  ),
);

if (confirmarImpressao != true) return;
            final agora = DateTime.now();
            final dia =
                int.tryParse((mensalidade['dia'] ?? '').toString()) ??
                    agora.day;
            final mes =
                int.tryParse((mensalidade['mes'] ?? '').toString()) ??
                    agora.month;
            final ano =
                int.tryParse((mensalidade['ano'] ?? '').toString()) ??
                    agora.year;

            final periodo =
                (mensalidade['periodoAdiantamento'] ?? '')
                    .toString()
                    .trim();

            final vencimento = periodo.isNotEmpty
                ? periodo
                : '${dia.toString().padLeft(2, '0')}/'
                    '${mes.toString().padLeft(2, '0')}/$ano';

            final dataRecebimento =
                '${agora.day.toString().padLeft(2, '0')}/'
                '${agora.month.toString().padLeft(2, '0')}/'
                '${agora.year}';

            final sucesso =
                await ImpressoraBluetoothService.imprimirRecibo(
              nomeMorador:
                  (mensalidade['nome'] ?? 'Cliente').toString(),
              valor: (mensalidade['valor'] ?? '0,00').toString(),
              formaPagamento:
                  (mensalidade['formaPagamento'] ?? 'Não informado')
                      .toString(),
              vencimento: vencimento,
              dataRecebimento: dataRecebimento,
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sucesso
                      ? 'Recibo impresso.'
                      : 'Não foi possível imprimir. Confira se a impressora está conectada.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.print),
          label: const Text('Imprimir'),
        ),
      ],
    ),
  ),
                            if (abaAtual == 1)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final agora = DateTime.now();
            final dia = int.tryParse(
                  (mensalidade['dia'] ?? '').toString(),
                ) ??
                agora.day;
            final mes = int.tryParse(
                  (mensalidade['mes'] ?? '').toString(),
                ) ??
                agora.month;
            final ano = int.tryParse(
                  (mensalidade['ano'] ?? '').toString(),
                ) ??
                agora.year;

            final vencimento =
                (mensalidade['periodoAdiantamento'] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty
                ? mensalidade['periodoAdiantamento'].toString()
                : '${dia.toString().padLeft(2, '0')}/'
                    '${mes.toString().padLeft(2, '0')}/$ano';

            final dataRecebimento =
                '${agora.day.toString().padLeft(2, '0')}/'
                '${agora.month.toString().padLeft(2, '0')}/'
                '${agora.year}';

            final sucesso =
                await ImpressoraBluetoothService.imprimirRecibo(
              nomeMorador:
                  (mensalidade['nome'] ?? 'Cliente').toString(),
              valor: (mensalidade['valor'] ?? '0,00').toString(),
              formaPagamento:
                  (mensalidade['formaPagamento'] ?? 'Não informado')
                      .toString(),
              vencimento: vencimento,
              dataRecebimento: dataRecebimento,
            );

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  sucesso
                      ? 'Recibo impresso.'
                      : 'Não foi possível imprimir. Confira se a impressora está conectada.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.print),
          label: const Text('Imprimir'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmarDesfazer = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Desfazer recebimento?'),
                content: const Text(
                  'A mensalidade voltará para Pendentes. Confirma?',
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(dialogContext, true),
                    child: const Text('Desfazer'),
                  ),
                ],
              ),
            );

            if (confirmarDesfazer != true) return;

            mensalidade['status'] = 'pendente';
            await widget.store.salvarMensalidades();

            if (!mounted) return;
            setState(() {});

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Recebimento desfeito. A mensalidade voltou para Pendentes.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.undo),
          label: const Text('Desfazer recebimento'),
        ),
      ],
    ),
  ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
            await widget.store.carregarClientes();
  if (widget.store.clientes.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Cadastre um cliente primeiro.')),
  );
  return;
}

final selecionados = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
                final clientesMarcados = <int>{};
        String bairroSelecionado = 'Todos os bairros';
        String ruaSelecionada = 'Todas as ruas';
        String diaSelecionado = 'Todos os dias';

        

            return StatefulBuilder(
  builder: (context, atualizarDialogo) {
      final bairros = widget.store.bairros
    .map((bairro) => bairro.nome)
    .toSet()
    .toList()
  ..sort();

final ruas = widget.store.bairros
    .where((bairro) =>
        bairroSelecionado == 'Todos os bairros' ||
        bairro.nome == bairroSelecionado)
    .expand((bairro) => bairro.ruas)
    .toSet()
    .toList()
  ..sort();
  

final clientesFiltrados =
    widget.store.clientes.asMap().entries.where((entrada) {
  final cliente = entrada.value;
  final bairroCliente = (cliente['bairro'] ?? '').toString();
  final ruaCliente = (cliente['rua'] ?? '').toString();
  final diaCliente = (cliente['dia'] ?? '').toString();

  return (bairroSelecionado == 'Todos os bairros' ||
          bairroCliente == bairroSelecionado) &&
      (ruaSelecionada == 'Todas as ruas' ||
          ruaCliente == ruaSelecionada) &&
      (diaSelecionado == 'Todos os dias' ||
    int.tryParse(diaCliente.replaceAll(RegExp(r'[^0-9]'), '')) ==
        int.tryParse(diaSelecionado.replaceAll(RegExp(r'[^0-9]'), '')));
}).toList();
        
                    return AlertDialog(
                    title: const Text('Selecionar clientes'),
                    scrollable: true,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: bairroSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Bairro',
                          ),
                            
                          items: [
                            'Todos os bairros',
                            ...bairros,
                          ].map((bairro) {
                            return DropdownMenuItem(
                              value: bairro,
                              child: Text(bairro),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            if (valor == null) return;
                            atualizarDialogo(() {
                              bairroSelecionado = valor;
                              ruaSelecionada = 'Todas as ruas';
                            });
                          },
                        ),
                        DropdownButtonFormField<String>(
                          value: ruaSelecionada,
                          decoration: const InputDecoration(
                            labelText: 'Rua',
                          ),
                          items: [
                            'Todas as ruas',
                            ...ruas,
                          ].map((rua) {
                            return DropdownMenuItem(
                              value: rua,
                              child: Text(rua),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            if (valor == null) return;
                            atualizarDialogo(() {
                              ruaSelecionada = valor;
                            });
                          },
                        ),
                          DropdownButtonFormField<String>(
  value: diaSelecionado,
  decoration: const InputDecoration(
    labelText: 'Dia',
  ),
  items: [
    'Todos os dias',
    ...List.generate(31, (index) => 'Dia ${index + 1}'),
  ].map((dia) {
    return DropdownMenuItem<String>(
      value: dia,
      child: Text(dia),
    );
  }).toList(),
  onChanged: (valor) {
    if (valor == null) return;
    atualizarDialogo(() {
      diaSelecionado = valor;
    });
  },
),
                        FutureBuilder<String>(
                          future: SharedPreferences.getInstance().then(
                            (prefs) =>
                                prefs.getString('modoGeracaoMensalidade') ??
                                'ao_longo_do_mes',
                          ),
                          builder: (context, snapshotModo) {
                            if (!snapshotModo.hasData) {
                              return const SizedBox(height: 56);
                            }

                            final modo = snapshotModo.data!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: modo,
                                  decoration: const InputDecoration(
                                    labelText: 'Modo de geração automática',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'ao_longo_do_mes',
                                      child: Text('Ao longo do mês'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'mes_completo',
                                      child: Text('Mês inteiro de uma vez'),
                                    ),
                                  ],
                                  onChanged: (valor) async {
                                    if (valor == null) return;
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setString(
                                      'modoGeracaoMensalidade',
                                      valor,
                                    );
                                    atualizarDialogo(() {});
                                  },
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  modo == 'mes_completo'
                                      ? 'Gera agora as mensalidades de todos os Clientes para o mês atual.'
                                      : 'Gera cada mensalidade quando faltarem os dias configurados para o vencimento.',
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<int>(
                          future: SharedPreferences.getInstance().then(
                            (prefs) =>
                                prefs.getInt('diasAntecedenciaMensalidade') ??
                                0,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox(height: 56);
                            }

                            return TextFormField(
                              initialValue: '${snapshot.data}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText:
                                    'Dias antes do vencimento para gerar automaticamente',
                                helperText:
                                    'Exemplo: 4 dias gera a mensalidade 4 dias antes do vencimento.',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (valor) async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setInt(
                                  'diasAntecedenciaMensalidade',
                                  int.tryParse(valor) ?? 0,
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: diaSelecionado,
                          decoration: const InputDecoration(
                            labelText: 'Dia de vencimento',
                          ),
                          items: [
                            'Todos os dias',
                            ...List.generate(31, (index) => '${index + 1}'),
                          ].map((dia) {
                            return DropdownMenuItem(
                              value: dia,
                              child: Text(dia),
                            );
                          }).toList(),
                          onChanged: (valor) {
                            if (valor == null) return;
                            atualizarDialogo(() {
                              diaSelecionado = valor;
                            });
                          },
                        ),
                        TextButton(
                          onPressed: () {
                            atualizarDialogo(() {
                              final todosMarcados = clientesFiltrados.every(
                                (entrada) =>
                                    clientesMarcados.contains(entrada.key),
                              );

                              if (todosMarcados) {
                                for (final entrada in clientesFiltrados) {
                                  clientesMarcados.remove(entrada.key);
                                }
                              } else {
                                for (final entrada in clientesFiltrados) {
                                  clientesMarcados.add(entrada.key);
                                }
                              }
                            });
                          },
                          child: const Text('Selecionar todos deste filtro'),
                        ),
                        if (clientesFiltrados.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Nenhum cliente neste filtro.'),
                          )
                        else
                          ...clientesFiltrados.map((entrada) {
                            final cliente = entrada.value;

                            return CheckboxListTile(
                              value: clientesMarcados.contains(entrada.key),
                              title: Text(
                                (cliente['nome'] ?? 'Sem nome').toString(),
                              ),
                              subtitle: Text(
                                '${cliente['rua'] ?? ''}, '
                                '${cliente['numero'] ?? ''} • '
                                '${cliente['bairro'] ?? ''}',
                              ),
                              onChanged: (marcado) {
                                atualizarDialogo(() {
                                  if (marcado == true) {
                                    clientesMarcados.add(entrada.key);
                                  } else {
                                    clientesMarcados.remove(entrada.key);
                                  }
                                });
                              },
                            );
                          }),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(
                            dialogContext,
                            Set<int>.from(clientesMarcados),
                          );
                        },
                        child: const Text('Criar mensalidades'),
                      ),
                    ],
                  );      
          
                },
    );
                      
                        },
      );
     if (selecionados == null || selecionados.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Selecione pelo menos um cliente.'),
    ),
  );
  return;
}

final agora = DateTime.now();
final prefs = await SharedPreferences.getInstance();
final modoSalvo =
    prefs.getString('modoGeracaoMensalidade') ?? 'ao_longo_do_mes';
final diasAntes =
    prefs.getInt('diasAntecedenciaMensalidade') ?? 0;
final hoje = DateTime(agora.year, agora.month, agora.day);
for (final indiceCliente in selecionados) {

  final cliente = widget.store.clientes[indiceCliente];

  final mensalidadeJaExiste =
      widget.store.mensalidades.any((mensalidade) {
    String normalizar(Object? valor) =>
        (valor ?? '').toString().trim().toLowerCase();

    return normalizar(mensalidade['nome']) ==
            normalizar(cliente['nome']) &&
        normalizar(mensalidade['bairro']) ==
            normalizar(cliente['bairro']) &&
        normalizar(mensalidade['rua']) ==
            normalizar(cliente['rua']) &&
        normalizar(mensalidade['numero']) ==
            normalizar(cliente['numero']) &&
        normalizar(mensalidade['mes']) ==
            agora.month.toString() &&
        normalizar(mensalidade['ano']) ==
            agora.year.toString();
  });

  if (mensalidadeJaExiste) continue;

  widget.store.mensalidades.add({
    'nome': cliente['nome'] ?? '',
    'bairro': cliente['bairro'] ?? '',
    'rua': cliente['rua'] ?? '',
    'numero': cliente['numero'] ?? '',
    'dia': cliente['dia'] ?? '',
    'valor': cliente['valor'] ?? '0,00',
    'formaPagamento': cliente['formaPagamento'] ?? 'Pix',
    'status': 'pendente',
    'mes': agora.month,
    'ano': agora.year,
  });
}

await widget.store.salvarMensalidades();
await widget.store.carregarMensalidades();

if (!mounted) return;
setState(() {});
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      '${selecionados.length} mensalidade(s) criada(s).',
    ),
  ),
);
},
        icon: const Icon(Icons.add),
        label: const Text('Nova mensalidade'),
      ),
    );
  }
      Future<void> _excluirMensalidade(
    Map<String, dynamic> mensalidade,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir mensalidade'),
        content: const Text(
          'Deseja excluir esta mensalidade?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    widget.store.mensalidades.remove(mensalidade);
    await widget.store.salvarMensalidades();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensalidade excluída.'),
      ),
    );
      }
      Future<void> _marcarRetorno(
    Map<String, dynamic> mensalidade,
  ) async {
    final hoje = DateTime.now();

    final data = await showDatePicker(
      context: context,
      initialDate: DateTime(hoje.year, hoje.month, hoje.day),
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: DateTime(2100),
    );

    if (data == null) return;

    mensalidade['retorno'] =
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';

    await widget.store.salvarMensalidades();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retorno marcado para ${mensalidade['retorno']}.'),
      ),
    );
  }

  Future<void> _editarMensalidade(
    Map<String, dynamic> mensalidade,
  ) async {
    final valorController = TextEditingController(
      text: (mensalidade['valor'] ?? '0,00').toString(),
    );
    String formaPagamento =
        (mensalidade['formaPagamento'] ?? 'Pix').toString();

    final salvou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar mensalidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: formaPagamento,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
              ),
              items: const [
                DropdownMenuItem(value: 'Pix', child: Text('Pix')),
                DropdownMenuItem(
                  value: 'Dinheiro',
                  child: Text('Dinheiro'),
                ),
                DropdownMenuItem(value: 'Cartão', child: Text('Cartão')),
              ],
              onChanged: (valor) {
                if (valor != null) formaPagamento = valor;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (salvou != true) {
      valorController.dispose();
      return;
    }

    final novoValor = valorController.text.trim();
    valorController.dispose();

    if (novoValor.isEmpty) return;

    mensalidade['valor'] = novoValor;
    mensalidade['formaPagamento'] = formaPagamento;

    await widget.store.salvarMensalidades();

    if (!mounted) return;
    setState(() {});
  }

    Future<void> _receberMesesAdiantados(
    Map<String, dynamic> mensalidade,
  ) async {
        String quantidadeTexto = '1';

    final quantidade = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Meses adiantados'),
        content: TextFormField(
          initialValue: '1',
          keyboardType: TextInputType.number,
          onChanged: (valor) {
            quantidadeTexto = valor;
          },
          decoration: const InputDecoration(
            labelText: 'Quantidade de meses',
            helperText: 'Informe de 1 a 12, começando no próximo mês.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              FocusScope.of(dialogContext).unfocus();
              Navigator.pop(
                dialogContext,
                int.tryParse(quantidadeTexto),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (quantidade == null) return;

    if (quantidade < 1 || quantidade > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade de 1 a 12.')),
      );
      return;
    }
final confirmarPagamento = await showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Confirmar pagamento'),
    content: Text(
      'Confirma o recebimento de $quantidade mensalidade(s) adiantada(s)?',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: const Text('Confirmar pagamento'),
      ),
    ],
  ),
);

if (confirmarPagamento != true) return;
    final mesBase =
        int.tryParse((mensalidade['mes'] ?? '').toString()) ??
            DateTime.now().month;
    final anoBase =
        int.tryParse((mensalidade['ano'] ?? '').toString()) ??
            DateTime.now().year;

    String normalizar(Object? valor) =>
        (valor ?? '').toString().trim().toLowerCase();

    double converterValor(Object? valor) {
      var texto = (valor ?? '0')
          .toString()
          .replaceAll('R', '')
          .replaceAll('\$', '')
          .trim();

      if (texto.contains(',')) {
        texto = texto.replaceAll('.', '').replaceAll(',', '.');
      }

      return double.tryParse(texto) ?? 0;
    }

    final mensalidadesAdiantadas = <Map<String, dynamic>>[];
        mensalidade['status'] = 'recebida';
mensalidadesAdiantadas.add(mensalidade);

    for (var i = 0; i < quantidade; i++) {
      // +1 começa pelo próximo mês e deixa o mês atual de fora.
      final data = DateTime(anoBase, mesBase + i + 1, 1);

      final existente = widget.store.mensalidades.where((item) {
        return normalizar(item['nome']) == normalizar(mensalidade['nome']) &&
            normalizar(item['bairro']) ==
                normalizar(mensalidade['bairro']) &&
            normalizar(item['rua']) == normalizar(mensalidade['rua']) &&
            normalizar(item['numero']) ==
                normalizar(mensalidade['numero']) &&
            normalizar(item['mes']) == data.month.toString() &&
            normalizar(item['ano']) == data.year.toString();
      }).firstOrNull;

      if (existente != null) {
        existente['status'] = 'recebida';
        mensalidadesAdiantadas.add(existente);
      } else {
        final adiantada = Map<String, dynamic>.from(mensalidade);
        adiantada['mes'] = data.month;
        adiantada['ano'] = data.year;
        adiantada['status'] = 'recebida';
        widget.store.mensalidades.add(adiantada);
        mensalidadesAdiantadas.add(adiantada);
      }
    }

    await widget.store.salvarMensalidades();

    if (!mounted) return;
    setState(() {});

    final valorTotal = mensalidadesAdiantadas.fold<double>(
      0,
      (total, item) => total + converterValor(item['valor']),
    );
    final valorTotalFormatado =
        valorTotal.toStringAsFixed(2).replaceAll('.', ',');

    String dataFormatada(DateTime data) =>
        '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';

    final diaInformado =
        int.tryParse((mensalidade['dia'] ?? '').toString()) ?? 1;
    final diaVencimento =
        diaInformado < 1 ? 1 : (diaInformado > 31 ? 31 : diaInformado);

    // O período também começa no próximo mês.
    final primeiroMes = DateTime(anoBase, mesBase + 1, 1);
    final ultimoMes = DateTime(anoBase, mesBase + quantidade, 1);

    final ultimoDiaPrimeiroMes =
        DateTime(primeiroMes.year, primeiroMes.month + 1, 0).day;
    final ultimoDiaUltimoMes =
        DateTime(ultimoMes.year, ultimoMes.month + 1, 0).day;

    final primeiroVencimento = DateTime(
      primeiroMes.year,
      primeiroMes.month,
      diaVencimento > ultimoDiaPrimeiroMes
          ? ultimoDiaPrimeiroMes
          : diaVencimento,
    );
    final ultimoVencimento = DateTime(
      ultimoMes.year,
      ultimoMes.month,
      diaVencimento > ultimoDiaUltimoMes
          ? ultimoDiaUltimoMes
          : diaVencimento,
    );

    final periodoAdiantamento =
        '${dataFormatada(primeiroVencimento)} a '
        '${dataFormatada(ultimoVencimento)}';

    final reciboAdiantamento = Map<String, dynamic>.from(mensalidade)
      ..['valor'] = valorTotalFormatado
      ..['periodoAdiantamento'] = periodoAdiantamento;

    final acaoRecibo = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recibo do adiantamento'),
        content: Text(
          'Adiantamento de $quantidade mensalidade(s) confirmado. '
          'O que deseja fazer?',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'imprimir'),
            icon: const Icon(Icons.print),
            label: const Text('Imprimir'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'enviar'),
            icon: const Icon(Icons.share),
            label: const Text('Enviar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'nao'),
            child: const Text('Não'),
          ),
        ],
      ),
    );

    if (!mounted || acaoRecibo == null || acaoRecibo == 'nao') return;

    if (acaoRecibo == 'enviar') {
      await _compartilharReciboWhatsApp(reciboAdiantamento);
      return;
    }

    if (acaoRecibo == 'imprimir') {
      final sucesso = await ImpressoraBluetoothService.imprimirRecibo(
        nomeMorador: (mensalidade['nome'] ?? 'Cliente').toString(),
        valor: valorTotalFormatado,
        formaPagamento:
            (mensalidade['formaPagamento'] ?? 'Não informado').toString(),
        vencimento: periodoAdiantamento,
        dataRecebimento: dataFormatada(DateTime.now()),
        observacao: 'Adiantamento de $quantidade mensalidade(s)',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sucesso
                ? 'Recibo do adiantamento impresso.'
                : 'Não foi possível imprimir. Confira se a impressora está conectada.',
          ),
        ),
      );
    }
  }
      Future<void> _reativarCliente(
    Map<String, dynamic> mensalidade,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reativar cliente?'),
        content: const Text(
          'O cliente voltará a ficar ativo e as mensalidades inativas '
          'voltarão para Pendentes. Confirma?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reativar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    String normalizar(Object? valor) =>
        (valor ?? '').toString().trim().toLowerCase();

    bool mesmoCliente(Map item) {
      return normalizar(item['nome']) ==
              normalizar(mensalidade['nome']) &&
          normalizar(item['bairro']) ==
              normalizar(mensalidade['bairro']) &&
          normalizar(item['rua']) ==
              normalizar(mensalidade['rua']) &&
          normalizar(item['numero']) ==
              normalizar(mensalidade['numero']);
    }

    for (final cliente in widget.store.clientes) {
      if (mesmoCliente(cliente)) {
        cliente['ativo'] = 'true';
      }
    }

    for (final registro in widget.store.mensalidades) {
      if (mesmoCliente(registro) &&
          normalizar(registro['status']) == 'inativo') {
        registro['status'] = 'pendente';
      }
    }

    await widget.store.salvarClientes();
    await widget.store.salvarMensalidades();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cliente reativado. As mensalidades voltaram para Pendentes.',
        ),
      ),
    );
      }

    Future<void> _inativarCliente(
    Map<String, dynamic> mensalidade,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Inativar cliente'),
        content: const Text(
          'As mensalidades pendentes deste cliente irão para Inativos. '
          'Os recebimentos serão mantidos. Confirma?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Inativar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    String normalizar(Object? valor) =>
        (valor ?? '').toString().trim().toLowerCase();

    bool mesmoCliente(Map item) {
      return normalizar(item['nome']) ==
              normalizar(mensalidade['nome']) &&
          normalizar(item['bairro']) ==
              normalizar(mensalidade['bairro']) &&
          normalizar(item['rua']) ==
              normalizar(mensalidade['rua']) &&
          normalizar(item['numero']) ==
              normalizar(mensalidade['numero']);
    }

    for (final cliente in widget.store.clientes) {
      if (mesmoCliente(cliente)) {
        cliente['ativo'] = 'false';
      }
    }

    for (final registro in widget.store.mensalidades) {
      if (mesmoCliente(registro) &&
          normalizar(registro['status']) == 'pendente') {
        registro['status'] = 'inativo';
      }
    }

    await widget.store.salvarClientes();
    await widget.store.salvarMensalidades();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Cliente inativado. Os recebimentos foram mantidos.',
        ),
      ),
    );
  }
}


        
class TelaClientes extends StatefulWidget {
  final AppStore store;

  const TelaClientes({
    super.key,
    required this.store,
  });

  @override
  State<TelaClientes> createState() => _TelaClientesState();
}

class _TelaClientesState extends State<TelaClientes> {
      bool totalVisivel = true;
String buscaCliente = '';
String bairroFiltro = 'Todos os bairros';
    String ruaFiltro = 'Todas as ruas';
String dataFiltro = 'Todas as datas';
  double get totalMensal {
  final busca = buscaCliente.trim().toLowerCase();

  return widget.store.clientes
      .where((cliente) {
        final nome = (cliente['nome'] ?? '').toString().toLowerCase();
        final bairro = (cliente['bairro'] ?? '').toString().trim();
        final rua = (cliente['rua'] ?? '').toString().trim();

        final endereco = [
          bairro,
          rua,
          cliente['numero'] ?? '',
          cliente['complemento'] ?? '',
        ].join(' ').toLowerCase();

        final correspondeBusca =
            busca.isEmpty || '$nome $endereco'.contains(busca);

        final correspondeBairro =
            bairroFiltro == 'Todos os bairros' || bairro == bairroFiltro;

        final correspondeRua =
            ruaFiltro == 'Todas as ruas' || rua == ruaFiltro;

        return correspondeBusca && correspondeBairro && correspondeRua;
      })
      .fold<double>(0, (soma, cliente) {
        final texto = (cliente['valor'] ?? '0')
            .toString()
            .replaceAll('.', '')
            .replaceAll(',', '.');

        return soma + (double.tryParse(texto) ?? 0);
      });
  }
  @override
  void initState() {
    super.initState();
    _carregarClientes();
  }

  Future<void> _carregarClientes() async {
    await widget.store.carregarClientes();

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
      final clientesFiltrados = widget.store.clientes.where((cliente) {
  final busca = buscaCliente.trim().toLowerCase();
  final dadosCliente = cliente.values.join(' ').toLowerCase();
        final bairroCliente = (cliente['bairro'] ?? '').trim();
      final ruaCliente = (cliente['rua'] ?? '').trim();

      final correspondeBusca = dadosCliente.contains(busca);
      final correspondeBairro =
          bairroFiltro == 'Todos os bairros' ||
          bairroCliente == bairroFiltro;
      final correspondeRua =
          ruaFiltro == 'Todas as ruas' ||
          ruaCliente == ruaFiltro;

      return correspondeBusca && correspondeBairro && correspondeRua;
}).toList();
      final ruasDisponiveis = widget.store.bairros
    .where((bairro) =>
        bairroFiltro == 'Todos os bairros' ||
        bairro.nome == bairroFiltro)
    .expand((bairro) => bairro.ruas)
    .toSet()
    .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
      ),
                  body: Column(
        children: [
            Padding(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
  child: TextField(
    onChanged: (texto) {
      setState(() {
        buscaCliente = texto;
      });
    },
    decoration: InputDecoration(
      hintText: 'Buscar cliente por nome ou endereço',
      prefixIcon: const Icon(Icons.search, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      filled: true,
    ),
  ),
),Padding(
  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
  child: Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          value: bairroFiltro,
          decoration: const InputDecoration(
            labelText: 'Bairro',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: 'Todos os bairros',
              child: Text('Todos os bairros'),
            ),
            ...widget.store.bairros.map(
              (bairro) => DropdownMenuItem(
                value: bairro.nome,
                child: Text(bairro.nome),
              ),
            ),
          ],
          onChanged: (valor) {
            if (valor == null) return;
            setState(() {
              bairroFiltro = valor;
              ruaFiltro = 'Todas as ruas';
            });
          },
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: DropdownButtonFormField<String>(
          value: ruaFiltro == 'Todas as ruas' ||
                  ruasDisponiveis.contains(ruaFiltro)
              ? ruaFiltro
              : 'Todas as ruas',
          decoration: const InputDecoration(
            labelText: 'Rua',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
              value: 'Todas as ruas',
              child: Text('Todas as ruas'),
            ),
            ...ruasDisponiveis.map(
              (rua) => DropdownMenuItem(
                value: rua,
                child: Text(rua),
              ),
            ),
          ],
          onChanged: (valor) {
            if (valor == null) return;
            setState(() {
              ruaFiltro = valor;
            });
          },
        ),
      ),
    ],
  ),
),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total mensal dos clientes',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalVisivel
                                ? 'R\$ ${totalMensal.toStringAsFixed(2).replaceAll('.', ',')}'
                                : '••••••',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: totalVisivel
                          ? 'Ocultar total'
                          : 'Mostrar total',
                      onPressed: () {
                        setState(() {
                          totalVisivel = !totalVisivel;
                        });
                      },
                      icon: Icon(
  totalVisivel
      ? Icons.visibility_off_outlined
      : Icons.visibility_outlined,
  size: 20,
  color: Colors.white,
),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
  child: clientesFiltrados.isEmpty
      ? const Center(
          child: Text('Nenhum cliente cadastrado'),
        )
      : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: clientesFiltrados.length,
                    itemBuilder: (context, index) {
                      final cliente = clientesFiltrados[index];

                      final endereco = <String>[
  cliente['rua']?.toString() ?? '',
  cliente['numero']?.toString() ?? '',
  cliente['complemento']?.toString() ?? '',
].where((parte) => parte.trim().isNotEmpty).join(', ');

final detalhes = <String>[
  if ((cliente['bairro']?.toString() ?? '').isNotEmpty)
    cliente['bairro'].toString(),
  if (endereco.isNotEmpty) endereco,
  if ((cliente['telefone']?.toString() ?? '').isNotEmpty)
    'Tel: ${cliente['telefone']}',
  'Dia: ${cliente['dia'] ?? '?'} | Pagamento: ${cliente['formaPagamento'] ?? '?'}',
].join('\n');

                      return Card(
                        child: ListTile(
                          title: Text(cliente['nome'] ?? 'Sem nome'),
                          subtitle: Text(detalhes),
                        


                          trailing: PopupMenuButton<String>(
  onSelected: (acao) async {
    final indiceOriginal = widget.store.clientes.indexOf(cliente);
    if (indiceOriginal < 0) return;

    if (acao == 'editar') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CadastroClientePage(
            store: widget.store,
            indiceEdicao: indiceOriginal,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {});
      return;
    }

    if (acao != 'excluir') return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text(
          'Deseja excluir ${cliente['nome'] ?? 'este cliente'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    widget.store.clientes.removeAt(indiceOriginal);
    await widget.store.salvarClientes();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cliente excluído com sucesso'),
      ),
    );
  },
  itemBuilder: (context) => const [
    PopupMenuItem<String>(
      value: 'editar',
      child: Text('Editar'),
    ),
    PopupMenuItem<String>(
      value: 'excluir',
      child: Text('Excluir'),
    ),
  ],
),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CadastroClientePage(store: widget.store),
            ),
          );

          if (!mounted) return;
          setState(() {});
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Novo cliente'),
      ),
    );
  }
}
class CadastroClientePage extends StatefulWidget {
  const CadastroClientePage({
    super.key,
    required this.store,
    this.indiceEdicao,
  });

  final AppStore store;
  final int? indiceEdicao;

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}


class _CadastroClientePageState extends State<CadastroClientePage> {
    final formKey = GlobalKey<FormState>();

  final nome = TextEditingController();
  final numero = TextEditingController();
  final complemento = TextEditingController();
  final dia = TextEditingController();
  final valor = TextEditingController();
  final telefone = TextEditingController();
  final contato2Nome = TextEditingController();
  final contato2Telefone = TextEditingController();
  final contato2Relacao = TextEditingController();
    final cpf = TextEditingController();
final email = TextEditingController();

  String? bairro;
  String? rua;
  String formaPagamento = 'Pix';
    DateTime? dataEntrada;


  String get dataEntradaFormatada {
    final data = dataEntrada;
    if (data == null) return '';

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }
  List<String> get ruasDoBairro {
    for (final b in widget.store.bairros) {
      if (b.nome == bairro) return b.ruas;
    }
    return [];
  }
  @override
  void initState() {
    super.initState();

    final indice = widget.indiceEdicao;
    if (indice == null ||
        indice < 0 ||
        indice >= widget.store.clientes.length) {
      return;
    }

    final cliente = widget.store.clientes[indice];

    nome.text = (cliente['nome'] ?? '').toString();
    numero.text = (cliente['numero'] ?? '').toString();
    complemento.text = (cliente['complemento'] ?? '').toString();
    dia.text = (cliente['dia'] ?? '').toString();
    valor.text = (cliente['valor'] ?? '').toString();
    telefone.text = (cliente['telefone'] ?? '').toString();
    contato2Nome.text = (cliente['contato2Nome'] ?? '').toString();
    contato2Telefone.text =
        (cliente['contato2Telefone'] ?? '').toString();
    contato2Relacao.text =
        (cliente['contato2Relacao'] ?? '').toString();
      cpf.text = (cliente['cpf'] ?? '').toString();
email.text = (cliente['email'] ?? '').toString();

    bairro = cliente['bairro']?.toString();
    rua = cliente['rua']?.toString();

    final formaSalva = cliente['formaPagamento']?.toString();
    if (['Pix', 'Dinheiro', 'Cartão'].contains(formaSalva)) {
      formaPagamento = formaSalva!;
    }
  }
  @override
  void dispose() {
    nome.dispose();
    numero.dispose();
    complemento.dispose();
    dia.dispose();
    valor.dispose();
    telefone.dispose();
    contato2Nome.dispose();
    contato2Telefone.dispose();
    contato2Relacao.dispose();
      cpf.dispose();
email.dispose();
    super.dispose();
  }

  Widget _tituloSecao(
    BuildContext context,
    IconData icone,
    String titulo,
    String subtitulo,
  ) {
    final cores = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cores.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icone,
              color: cores.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required BuildContext context,
    required Widget child,
  }) {
    final cores = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cores.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cores.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: child,
    );
  }
  Future<void> _salvarCliente({required bool cadastrarOutro}) async {
    if (!formKey.currentState!.validate()) return;

    final indice = widget.indiceEdicao;
    final nomeNovo = nome.text.trim().toLowerCase();
    final bairroNovo = (bairro ?? '').trim().toLowerCase();
    final ruaNova = (rua ?? '').trim().toLowerCase();
    final numeroNovo = numero.text.trim().toLowerCase();

    final clienteJaCadastrado =
        widget.store.clientes.asMap().entries.any((entrada) {
      if (indice != null && entrada.key == indice) return false;
      final cliente = entrada.value;

      return (cliente['nome'] ?? '').trim().toLowerCase() == nomeNovo &&
          (cliente['bairro'] ?? '').trim().toLowerCase() == bairroNovo &&
          (cliente['rua'] ?? '').trim().toLowerCase() == ruaNova &&
          (cliente['numero'] ?? '').trim().toLowerCase() == numeroNovo;
    });

    if (clienteJaCadastrado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esse cliente já existe')),
      );
      return;
    }

    final dadosCliente = <String, String>{
      'nome': nome.text.trim(),
      'bairro': bairro ?? '',
      'rua': rua ?? '',
      'numero': numero.text.trim(),
      'complemento': complemento.text.trim(),
      'dia': dia.text.trim(),
      'valor': valor.text.trim(),
      'formaPagamento': formaPagamento,
      'telefone': telefone.text.trim(),
      'contato2Nome': contato2Nome.text.trim(),
      'contato2Telefone': contato2Telefone.text.trim(),
      'contato2Relacao': contato2Relacao.text.trim(),
    };

    if (indice != null &&
        indice >= 0 &&
        indice < widget.store.clientes.length) {
      widget.store.clientes[indice] = dadosCliente;
    } else {
      widget.store.clientes.add(dadosCliente);
    }

    await widget.store.salvarClientes();

    if (!mounted) return;

    if (cadastrarOutro) {ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Salvo com sucesso')),
);

if (cadastrarOutro) {
  Navigator.pushReplacement<void, void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CadastroClientePage(store: widget.store),
    ),
  );
} else {
  Navigator.pop(context);
}
      

      setState(() {
        bairro = null;
        rua = null;
        formaPagamento = 'Pix';
        dataEntrada = null;
      });

      formKey.currentState?.reset();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente salvo. Cadastre o próximo.')),
      );
    } else {
      Navigator.pop(context);
    }
  }
@override

  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Novo cliente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cores.primaryContainer,
                    cores.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: cores.surface,
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 28,
                      color: cores.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cadastrar novo cliente',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Organize os dados para facilitar cobranças e recibos.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _card(
              context: context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tituloSecao(
                    context,
                    Icons.badge_outlined,
                    'Dados do cliente',
                    'Informações principais',
                  ),
                  TextFormField(
  controller: nome,
  textCapitalization: TextCapitalization.words,
  decoration: const InputDecoration(
    labelText: 'Nome do cliente',
    hintText: 'Ex.: João da Silva',
    prefixIcon: Icon(Icons.person_outline),
    border: OutlineInputBorder(),
  ),
  
),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                    
  TextInputFormatter.withFunction((oldValue, newValue) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 11) return oldValue;

    var texto = digitos;
    if (digitos.length > 2) {
      final ddd = digitos.substring(0, 2);
      final numero = digitos.substring(2);
      final tamanhoInicio = digitos.length == 11
          ? 5
          : (numero.length > 4 ? 4 : numero.length);

      texto = '($ddd) ${numero.substring(0, tamanhoInicio)}';
      if (numero.length > tamanhoInicio) {
        texto += '-${numero.substring(tamanhoInicio)}';
      }
    }

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }),
],
                    
                    decoration: const InputDecoration(
                      labelText: 'Telefone / WhatsApp',
                      hintText: '(DD) 99999-9999',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),const SizedBox(height: 12),
TextFormField(
  controller: cpf,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(14),
  ],
  decoration: const InputDecoration(
    labelText: 'CPF (opcional)',
    hintText: 'Somente números',
    prefixIcon: Icon(Icons.badge_outlined),
    border: OutlineInputBorder(),
  ),
),
const SizedBox(height: 12),
TextFormField(
  controller: email,
  keyboardType: TextInputType.emailAddress,
  decoration: const InputDecoration(
    labelText: 'E-mail (opcional)',
    hintText: 'Ex.: cliente@email.com',
    prefixIcon: Icon(Icons.email_outlined),
    border: OutlineInputBorder(),
  ),
),
                  const SizedBox(height: 16),
                  const Text(
                    'Segundo contato (opcional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: contato2Nome,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome do contato',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contato2Relacao,
                    decoration: const InputDecoration(
                      labelText: 'Relação com o cliente',
                      hintText: 'Ex.: esposa, filho, responsável',
                      prefixIcon: Icon(Icons.group_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: contato2Telefone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Telefone / WhatsApp do segundo contato',
                      hintText: '(DD) 99999-9999',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            _card(
              context: context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tituloSecao(
                    context,
                    Icons.location_on_outlined,
                    'Endereço',
                    'Selecione o bairro e a rua cadastrados',
                  ),
                  DropdownButtonFormField<String>(
                    value: bairro,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Bairro *',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.store.bairros
                        .map(
                          (b) => DropdownMenuItem(
                            value: b.nome,
                            child: Text(b.nome),
                          ),
                        )
                        .toList(),
                    onChanged: (valor) {
                      setState(() {
                        bairro = valor;
                        rua = null;
                      });
                    },
                    validator: (v) =>
                        v == null ? 'Selecione o bairro' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value:
                        ruasDoBairro.contains(rua) ? rua : null,
                    isExpanded: true,
                                    decoration: const InputDecoration(
                      labelText: 'Rua *',
                      prefixIcon: Icon(Icons.signpost_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: ruasDoBairro
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          ),
                        )
                        .toList(),
                    onChanged: bairro == null
                        ? null
                        : (valor) => setState(() => rua = valor),
                    validator: (v) =>
                        v == null ? 'Selecione a rua' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
  children: [
    Expanded(
      child: TextFormField(
        controller: numero,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: const InputDecoration(
          labelText: 'Número da casa *',
          prefixIcon: Icon(Icons.numbers),
          border: OutlineInputBorder(),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return 'Informe o número da casa';
          }
          return null;
        },
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: TextFormField(
        controller: complemento,
        decoration: const InputDecoration(
          labelText: 'Complemento',
          hintText: 'Casa, bloco...',
          border: OutlineInputBorder(),
        ),
      ),
    ),
  ],
),
],           ),
           ),

            _card(
              context: context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tituloSecao(
                    context,
                    Icons.payments_outlined,
                    'Cobrança',
                    'Dados usados nas faturas do cliente',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: dia,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Dia *',
                            hintText: '10',
                            prefixIcon:
                                Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final d = int.tryParse(v ?? '');
                            if (d == null || d < 1 || d > 31) {
                              return 'Informe um dia de 1 a 31';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                                        child: TextFormField(
                          controller: valor,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) {
                                if (newValue.text.isEmpty) {
                                  return newValue;
                                }

                                final cursorNoTexto = newValue.selection.baseOffset
                                    .clamp(0, newValue.text.length)
                                    .toInt();

                                final digitosAntesCursor = newValue.text
                                    .substring(0, cursorNoTexto)
                                    .replaceAll(RegExp(r'\D'), '')
                                    .length;

                                final parteInteira = newValue.text.contains(',')
                                    ? newValue.text.substring(
                                        0,
                                        newValue.text.indexOf(','),
                                      )
                                    : newValue.text;

                                final digitos =
                                    parteInteira.replaceAll(RegExp(r'\D'), '');

                                if (digitos.isEmpty) {
                                  return const TextEditingValue(
                                    text: '',
                                    selection: TextSelection.collapsed(offset: 0),
                                  );
                                }

                                final textoFormatado = '$digitos,00';
                                final cursor = digitosAntesCursor
                                    .clamp(0, digitos.length)
                                    .toInt();

                                return TextEditingValue(
                                  text: textoFormatado,
                                  selection: TextSelection.collapsed(
                                    offset: cursor,
                                  ),
                                  composing: TextRange.empty,
                                );
                              },
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Valor mensal *',
                            hintText: 'R\$ 0,00',
                            prefixIcon:
                                Icon(Icons.attach_money_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = double.tryParse(
                              (v ?? '').replaceAll(',', '.'),
                            );
                            if (n == null || n <= 0) {
                              return 'Informe um valor válido';
                            }
                            return null;
                          },
                        ),

                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: formaPagamento,
                    decoration: const InputDecoration(
                      labelText: 'Forma de pagamento habitual',
                      prefixIcon:
                          Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: ['Pix', 'Dinheiro', 'Cartão']
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p,
                            child: Text(p),
                          ),
                        )
                        .toList(),
                    onChanged: (p) {
                      if (p != null) {
                        setState(() {
                          formaPagamento = p ?? formaPagamento;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

   const SizedBox(height: 24),

            

FilledButton.icon(
  onPressed: () {
    _salvarCliente(
      cadastrarOutro: widget.indiceEdicao == null,
    );
  },
  icon: const Icon(Icons.save),
  label: Text(
    widget.indiceEdicao == null
        ? 'Salvar e cadastrar próximo'
        : 'Salvar alterações',

),
            ),
          ],
        ),
      ),
    );
  }
}
                
class TelaRelatorio extends StatelessWidget {
  const TelaRelatorio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relatório mensal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Recebido'),
                trailing: Text(
                  'R\$ 0,00',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.pending_actions),
                title: Text('Pendente'),
                trailing: Text(
                  'R\$ 0,00',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.pix),
                title: Text('Pix'),
                trailing: Text('R\$ 0,00'),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.money),
                title: Text('Dinheiro'),
                trailing: Text('R\$ 0,00'),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.credit_card),
                title: Text('Cartão'),
                trailing: Text('R\$ 0,00'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TelaConfiguracoes extends StatefulWidget {
  const TelaConfiguracoes({super.key, required this.store});

  final AppStore store;

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  String get nomeTema {
  switch (temaApp.value) {
    case ThemeMode.light:
      return 'Claro';
    case ThemeMode.dark:
      return 'Escuro';
    case ThemeMode.system:
      return 'Automático';
  }
}

Future<void> _abrirTema() async {
  final temaAtual = temaApp.value;

  final novoTema = await showDialog<ThemeMode>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Tema do aplicativo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('Automático'),
              subtitle: const Text('Usar o tema do celular'),
              trailing: temaAtual == ThemeMode.system
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () {
                Navigator.pop(context, ThemeMode.system);
              },
            ),
            ListTile(
              subtitle: const Text('Usar o tema do celular'),
              title: const Text('Claro'),
              trailing: temaAtual == ThemeMode.light
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () {
                Navigator.pop(context, ThemeMode.light);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Escuro'),
              trailing: temaAtual == ThemeMode.dark
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () {
                Navigator.pop(context, ThemeMode.dark);
              },
            ),
          ],
        ),
      );
    },
  );

  if (novoTema == null || novoTema == temaAtual) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  if (novoTema == ThemeMode.dark) {
    await prefs.setString('temaApp', 'escuro');
  } else if (novoTema == ThemeMode.light) {
    await prefs.setString('temaApp', 'claro');
  } else {
    await prefs.setString('temaApp', 'automatico');
  }

  temaApp.value = novoTema;

  if (!mounted) return;

  setState(() {});

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Salvo com sucesso'),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.security),
            title: Text('Dados do vigilante'),
            subtitle: Text('Nome e contato'),
            trailing: Icon(Icons.chevron_right),
      onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DadosVigilantePage(store: widget.store)
    ),
  );
},
),
          const Divider(),
ListTile(
  leading: const Icon(Icons.location_on_outlined),
  title: const Text('Bairros e Ruas'),
  subtitle: const Text('Cadastrar bairros e ruas'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BairrosRuasPage(store: widget.store),
      ),
    );
    setState(() {});
  },
),
const Divider(),
          ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('Impressora térmica'),
            subtitle: Text('Impressora Bluetooth 58 mm'),
   onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>  TelaImpressora(),
    ),
  );
  }, 

            trailing: FutureBuilder<bool>(
  future: PrintBluetoothThermal.connectionStatus,
  builder: (context, snapshot) {
    final conectada = snapshot.data ?? false;

    return Icon(
      Icons.chevron_right,
      color: conectada ? Colors.green : null,
    );
  },
),
            




          ),
          const Divider(),
            ListTile(
  leading: const Icon(Icons.receipt_long_outlined),
  title: const Text('Personalizar recibo'),
  subtitle: const Text('Escolha o que será impresso no recibo'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PersonalizarReciboTermicoPage(),
      ),
    );
  },
),
const Divider(),
          ListTile(
  leading: const Icon(Icons.palette_outlined),
  title: const Text('Tema do aplicativo'),
  subtitle: Text(nomeTema),
  trailing: const Icon(Icons.chevron_right),
  onTap: _abrirTema,
),
  
               
          
        ],
      ),
    );
  }
}       


  class BairrosRuasPage extends StatefulWidget {
  const BairrosRuasPage({super.key, required this.store});

  final AppStore store;

  @override
  State<BairrosRuasPage> createState() => _BairrosRuasPageState();
}

class _BairrosRuasPageState extends State<BairrosRuasPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bairros e Ruas'),
      ),
      body: widget.store.bairros.isEmpty
          ? const Center(
              child: Text('Nenhum bairro cadastrado'),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
              itemCount: widget.store.bairros.length,
              itemBuilder: (context, index) {
                final bairro = widget.store.bairros[index];

                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(bairro.nome),
                    subtitle: Text('${bairro.ruas.length} rua(s)'),
                    children: [
                      ...bairro.ruas.map(
                        (rua) => ListTile(
                          leading: const Icon(Icons.signpost_outlined),
                          title: Text(rua),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_road),
                        title: const Text('Adicionar rua'),
                        onTap: () => _adicionarRua(bairro),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarBairro,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Adicionar novo bairro'),
      ),
    );
  }

  Future<void> _adicionarBairro() async {
    final controller = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo bairro'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome do bairro',
            hintText: 'Ex.: Centro',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final texto = controller.text.trim();

              if (texto.isNotEmpty) {
                Navigator.pop(context, texto);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (nome == null || nome.isEmpty) return;

    final existe = widget.store.bairros.any(
      (bairro) => bairro.nome.toLowerCase() == nome.toLowerCase(),
    );

    if (existe) {
      _aviso('Esse bairro já está cadastrado');
      return;
    }

    await widget.store.adicionarBairro(nome);

if (!mounted) return;

setState(() {});

_aviso('Salvo com sucesso');
}
  Future<void> _adicionarRua(Bairro bairro) async {
    final controller = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nova rua em ${bairro.nome}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome da Rua',
            hintText: 'Ex.: Av. Principal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final texto = controller.text.trim();

              if (texto.isNotEmpty) {
                Navigator.pop(context, texto);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (nome == null || nome.isEmpty) return;

    await widget.store.adicionarRua(bairro, nome);

if (!mounted) return;

setState(() {});

_aviso('Salvo com sucesso');
}
  void _aviso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }
}
  

class DadosVigilantePage extends StatefulWidget {
  const DadosVigilantePage({super.key, required this.store});

  final AppStore store;

  @override
  State<DadosVigilantePage> createState() => _DadosVigilantePageState();
}
  

class _DadosVigilantePageState extends State<DadosVigilantePage> {
  late final TextEditingController nome;
late final TextEditingController contato;
late final TextEditingController cpfCnpj;
late final TextEditingController endereco;
late final TextEditingController chavePix;
late final TextEditingController tipoChavePix;

late final TextEditingController nomeFantasia;
late final TextEditingController segmentoMercado;
late final TextEditingController servicoPrestado;
late final TextEditingController site;
late final TextEditingController credencial;

late final TextEditingController horarioInicio;
late final TextEditingController horarioFim;
late final TextEditingController observacaoHorario;

@override
void initState() {
  super.initState();

  nome = TextEditingController(
    text: widget.store.vigilanteNome,
  );

  contato = TextEditingController(
    text: widget.store.vigilanteContato,
  );

  cpfCnpj = TextEditingController(
    text: widget.store.vigilanteCpfCnpj,
  );

  endereco = TextEditingController(
      
    text: widget.store.vigilanteEndereco,
  );

  chavePix = TextEditingController(
    text: widget.store.vigilanteChavePix,
  );

  tipoChavePix = TextEditingController(
    text: widget.store.vigilanteTipoChavePix,
  );

  nomeFantasia = TextEditingController(
    text: widget.store.vigilanteNomeFantasia,
  );

  segmentoMercado = TextEditingController(
    text: widget.store.vigilanteSegmentoMercado,
  );

  servicoPrestado = TextEditingController(
    text: widget.store.vigilanteServicoPrestado,
  );

  site = TextEditingController(
    text: widget.store.vigilanteSite,
  );

  credencial = TextEditingController(
    text: widget.store.vigilanteCredencial,
  );

  horarioInicio = TextEditingController(
    text: widget.store.vigilanteHorarioInicio,
  );

  horarioFim = TextEditingController(
    text: widget.store.vigilanteHorarioFim,
  );

  observacaoHorario = TextEditingController(
    text: widget.store.vigilanteObservacaoHorario,
  );
}

@override
void dispose() {
  nome.dispose();
  contato.dispose();
  cpfCnpj.dispose();
  endereco.dispose();
  chavePix.dispose();
  tipoChavePix.dispose();

  nomeFantasia.dispose();
  segmentoMercado.dispose();
  servicoPrestado.dispose();
  site.dispose();
  credencial.dispose();

  horarioInicio.dispose();
  horarioFim.dispose();
  observacaoHorario.dispose();

  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados do vigilante')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // ===============================
// DADOS GERAIS DO SERVIÇO
// ===============================
const Text(
  'Dados Geral do serviço',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 16),



TextField(
  controller: segmentoMercado,
  decoration: const InputDecoration(
    labelText: 'Segmento de mercado',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: servicoPrestado,
  decoration: const InputDecoration(
    labelText: 'Serviço prestado',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: site,
  keyboardType: TextInputType.url,
  decoration: const InputDecoration(
    labelText: 'Site (opcional)',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: endereco,
  decoration: const InputDecoration(
    labelText: 'Endereço (opcional)',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 28),
            TextField(
  controller: nomeFantasia,
  decoration: const InputDecoration(
    labelText: 'Nome da empresa ou nome fantasia',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextFormField(
  initialValue: widget.store.vigilanteCnpjEmpresa,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(14),
  ],
  onChanged: (valor) {
    widget.store.vigilanteCnpjEmpresa = valor;
  },
  decoration: const InputDecoration(
    labelText: 'CNPJ da empresa (opcional)',
    helperText: 'Deixe em branco se não tiver CNPJ.',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

// ===============================
// HORÁRIO DE SERVIÇO
// ===============================
const Text(
  'Horário de Serviço (opcional)',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 16),

Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    FilterChip(
      label: const Text('Seg'),
      selected: widget.store.vigilanteSegunda,
      onSelected: (valor) {
        setState(() {
          widget.store.vigilanteSegunda = valor;
        });
      },
    ),
    FilterChip(
      label: const Text('Ter'),
      selected: widget.store.vigilanteTerca,
      onSelected: (valor) {
        setState(() {
          widget.store.vigilanteTerca = valor;
        });
      },
    ),
    FilterChip(
      label: const Text('Qua'),
      selected: widget.store.vigilanteQuarta,
      onSelected: (valor) {
        setState(() {
          widget.store.vigilanteQuarta = valor;
        });
      },
    ),
    FilterChip(
      label: const Text('Qui'),
      selected: widget.store.vigilanteQuinta,
      onSelected: (valor) {
        setState(() {
          widget.store.vigilanteQuinta = valor;
        });
      },
    ),
    FilterChip(
      label: const Text('Sáb'),
      selected: widget.store.vigilanteSabado,
      onSelected: (valor) {
        setState(() {
          widget.store.vigilanteSabado = valor;
        });
      },
    ),
    FilterChip(
      label: const Text('Dom'),
      selected: widget.store.vigilanteDomingo,
      onSelected: (valor) {
        setState(() {
          widget.store.vigilanteDomingo = valor;
        });
      },
    ),
  ],
),

const SizedBox(height: 16),

TextField(
  controller: horarioInicio,
  decoration: const InputDecoration(
    labelText: 'Horário de início',
    hintText: 'Ex.: 18:00',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: horarioFim,
  decoration: const InputDecoration(
    labelText: 'Horário de fim',
    hintText: 'Ex.: 06:00',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: observacaoHorario,
  maxLines: 2,
  decoration: const InputDecoration(
    labelText: 'Observação (opcional)',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 28),

// ===============================
// PERFIL 1
// ===============================
const Text(
  'Perfil 1 (obrigatório)',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 16),

TextField(
  controller: nome,
  decoration: const InputDecoration(
    labelText: 'Nome do vigilante',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: cpfCnpj,
  keyboardType: TextInputType.number,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(14),
  ],
  decoration: const InputDecoration(
    labelText: 'CPF ou CNPJ',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: contato,
  keyboardType: TextInputType.phone,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(11),
  ],
  decoration: const InputDecoration(
    labelText: 'Telefone',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

DropdownButtonFormField<String>(
  initialValue: widget.store.vigilanteTipoWhatsapp,
  decoration: const InputDecoration(
    labelText: 'Tipo de WhatsApp',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(
      value: 'WhatsApp Padrão',
      child: Text('WhatsApp Padrão'),
    ),
    DropdownMenuItem(
      value: 'WhatsApp Business',
      child: Text('WhatsApp Business'),
    ),
  ],
  onChanged: (valor) {
    if (valor != null) {
      widget.store.vigilanteTipoWhatsapp = valor;
    }
  },
),

const SizedBox(height: 12),

TextField(
  controller: chavePix,
  decoration: const InputDecoration(
    labelText: 'Chave Pix',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

DropdownButtonFormField<String>(
  initialValue:
      tipoChavePix.text.isEmpty ? 'Telefone' : tipoChavePix.text,
  decoration: const InputDecoration(
    labelText: 'Tipo da chave Pix',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(
      value: 'Telefone',
      child: Text('Telefone'),
    ),
    DropdownMenuItem(
      value: 'CPF/CNPJ',
      child: Text('CPF/CNPJ'),
    ),
    DropdownMenuItem(
      value: 'E-mail',
      child: Text('E-mail'),
    ),
    DropdownMenuItem(
      value: 'Aleatória',
      child: Text('Aleatória'),
    ),
  ],
  onChanged: (valor) {
    if (valor != null) {
      tipoChavePix.text = valor;
    }
  },
),

const SizedBox(height: 12),

TextField(
  controller: credencial,
  decoration: const InputDecoration(
    labelText: 'Número da credencial/carteirinha (opcional)',
    border: OutlineInputBorder(),
  ),
),
  const SizedBox(height: 28),

const Text(
  'Imagem padrão (Logo)',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 12),

Card(
  child: ListTile(
    onTap: () async {
  final ImagePicker picker = ImagePicker();
  final XFile? imagem =
      await picker.pickImage(source: ImageSource.gallery);

  if (imagem != null) {
    setState(() {
      widget.store.vigilanteLogo = imagem.path;
    });
  }
},
    leading: widget.store.vigilanteLogo.isEmpty
    ? const Icon(Icons.image_outlined)
    : ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(widget.store.vigilanteLogo),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image_outlined);
          },
        ),
      ),
    title: const Text('Escolher imagem'),
    subtitle: Text(
      widget.store.vigilanteLogo.isEmpty
          ? 'Nenhuma imagem selecionada'
          : 'Imagem selecionada',
    ),
    trailing: const Icon(Icons.chevron_right),
  ),
),

const SizedBox(height: 20),

const Text(
  'Imagem em Preto e Branco (Impressão)',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 12),

Card(
  child: ListTile(
    onTap: () async {
      final ImagePicker picker = ImagePicker();
      final XFile? imagem =
          await picker.pickImage(source: ImageSource.gallery);

      if (imagem != null) {
        setState(() {
          widget.store.vigilanteLogoPretoBranco = imagem.path;
        });
      }
    },
    leading: widget.store.vigilanteLogoPretoBranco.isEmpty
    ? const Icon(Icons.monochrome_photos_outlined)
    : ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(widget.store.vigilanteLogoPretoBranco),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image_outlined);
          },
        ),
      ),
    title: const Text('Escolher imagem'),
    subtitle: Text(
      widget.store.vigilanteLogoPretoBranco.isEmpty
          ? 'Nenhuma imagem selecionada'
          : 'Imagem selecionada',
    ),
    trailing: const Icon(Icons.chevron_right),
  ),
),
  


const SizedBox(height: 24),
          
          
          FilledButton.icon(

            onPressed: () async {  String? erro;

  if (nome.text.trim().isEmpty) {
    erro = 'Preencha o nome do vigilante';
  } else if (cpfCnpj.text.trim().isEmpty) {
    erro = 'Preencha o CPF ou CNPJ';
  } else if (cpfCnpj.text.trim().length != 11 &&
      cpfCnpj.text.trim().length != 14) {
    erro = 'Digite um CPF com 11 números ou CNPJ com 14 números';
  } else if (contato.text.trim().isEmpty) {
    erro = 'Preencha o telefone';
  } else if (contato.text.trim().length < 10) {
    erro = 'Digite um telefone válido com DDD';
  } else if (widget.store.vigilanteTipoWhatsapp.trim().isEmpty) {
    erro = 'Escolha o tipo de WhatsApp';
  } else if (chavePix.text.trim().isEmpty) {
    erro = 'Preencha a Chave Pix';
  } else if (tipoChavePix.text.trim().isEmpty) {
    erro = 'Escolha o tipo da Chave Pix';
  }

  if (erro != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(erro)),
    );
    return;
  }
  widget.store.vigilanteNome = nome.text.trim();
  widget.store.vigilanteContato = contato.text.trim();
  widget.store.vigilanteCpfCnpj = cpfCnpj.text.trim();
  widget.store.vigilanteEndereco = endereco.text.trim();
  widget.store.vigilanteChavePix = chavePix.text.trim();
  widget.store.vigilanteTipoChavePix = tipoChavePix.text.trim();
  widget.store.vigilanteNomeFantasia = nomeFantasia.text.trim();
  widget.store.vigilanteSegmentoMercado = segmentoMercado.text.trim();
  widget.store.vigilanteServicoPrestado = servicoPrestado.text.trim();
  widget.store.vigilanteSite = site.text.trim();
  widget.store.vigilanteCredencial = credencial.text.trim();

  widget.store.vigilanteHorarioInicio = horarioInicio.text.trim();
  widget.store.vigilanteHorarioFim = horarioFim.text.trim();
  widget.store.vigilanteObservacaoHorario =
      observacaoHorario.text.trim();
  await widget.store.salvarDadosVigilante();

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Dados salvos com sucesso'),
    ),
  );

  Navigator.pop(context);
},
            icon: const Icon(Icons.save),
            label: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

  class TelaImpressora extends StatefulWidget {
  const TelaImpressora({super.key});

  @override
  State<TelaImpressora> createState() => _TelaImpressoraState();
}

class _TelaImpressoraState extends State<TelaImpressora> {
  List<BluetoothInfo> impressoras = [];
  bool carregando = false;
  bool conectada = false;
  String? macConectado;

  @override
  void initState() {
    super.initState();
    _verificarConexao();
    _buscarImpressoras();
  }

  Future<void> _verificarConexao() async {
  final prefs = await SharedPreferences.getInstance();
  final macSalvo = prefs.getString('impressoraMac');

  bool status =
      await ImpressoraBluetoothService.estaConectada();

  if (!status &&
      macSalvo != null &&
      macSalvo.isNotEmpty) {
    status =
        await ImpressoraBluetoothService.conectar(
      macSalvo,
    );
  }

  if (!mounted) return;

  setState(() {
    conectada = status;

    if (status && macSalvo != null) {
      macConectado = macSalvo;
    }
  });
  }

  Future<void> _buscarImpressoras() async {
  if (carregando) return;

  setState(() {
    carregando = true;
  });

  try {
    final lista = await ImpressoraBluetoothService
        .buscarImpressoras()
        .timeout(const Duration(seconds: 10));

    if (!mounted) return;

    setState(() {
      impressoras = lista;
    });

    if (lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhuma impressora pareada foi encontrada.',
          ),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível buscar as impressoras. Verifique o Bluetooth.',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        carregando = false;
      });
    }
  }
  }
    Future<void> _conectar(BluetoothInfo impressora) async {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Conectando em ${impressora.name}...',
      ),
    ),
  );

  final sucesso =
      await ImpressoraBluetoothService.conectar(
    impressora.macAdress,
  );

  if (!mounted) return;

  if (sucesso) {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'impressoraMac',
      impressora.macAdress,
    );

    await prefs.setString(
      'impressoraNome',
      impressora.name,
    );

    if (!mounted) return;

    setState(() {
      conectada = true;
      macConectado = impressora.macAdress;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Impressora ${impressora.name} conectada e salva com sucesso',
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível conectar à impressora',
        ),
      ),
    );
  }
}
          
  

  Future<void> _desconectar() async {
    final sucesso =
        await ImpressoraBluetoothService.desconectar();

    if (!mounted) return;

    if (sucesso) {
      setState(() {
        conectada = false;
        macConectado = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impressora desconectada'),
        ),
      );
    }
  }

  Future<void> _testeImpressao() async {
    final sucesso =
        await ImpressoraBluetoothService.imprimirRecibo(
      nomeMorador: 'TESTE',
      valor: '10,00',
      formaPagamento: 'Pix',
      vencimento: 'Teste',
      dataRecebimento: 'Teste',
      observacao: 'Impressao de teste',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sucesso
              ? 'Teste enviado para a impressora'
              : 'Impressora não conectada',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressora térmica'),
      ),
      body: RefreshIndicator(
        onRefresh: _buscarImpressoras,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  conectada
                      ? Icons.print
                      : Icons.print_outlined,
                  color: conectada ? Colors.green : null,
                ),
                title: Text(
                  conectada
                      ? 'Impressora conectada'
                      : 'Nenhuma impressora conectada',
                ),
                subtitle: const Text(
                  'Bluetooth 58 mm',
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (conectada) ...[
              FilledButton.icon(
                onPressed: _testeImpressao,
                icon: const Icon(Icons.receipt_long),
                label: const Text('Imprimir teste'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _desconectar,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Desconectar'),
              ),
              const SizedBox(height: 20),
            ],

            const Text(
              'Impressoras pareadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (carregando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (impressoras.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nenhum dispositivo Bluetooth pareado encontrado.\n\n'
                    'Pareie primeiro a impressora nas configurações '
                    'Bluetooth do celular.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...impressoras.map(
                (impressora) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(
                      impressora.name.isEmpty
                          ? 'Dispositivo Bluetooth'
                          : impressora.name,
                    ),
                    subtitle: Text(impressora.macAdress),
                    trailing:
                        macConectado == impressora.macAdress &&
                                conectada
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.chevron_right),
                    onTap: () => _conectar(impressora),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: _buscarImpressoras,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar lista'),
            ),
          ],
        ),
      ),
    );
  }
}
class ImpressoraBluetoothService {
  static Future<List<BluetoothInfo>> buscarImpressoras() async {
    final bluetoothLigado =
        await PrintBluetoothThermal.bluetoothEnabled;

    if (!bluetoothLigado) {
      return [];
    }

    return await PrintBluetoothThermal.pairedBluetooths;
  }

    static Future<bool>? _conexaoEmAndamento;
  static String? _macEmConexao;

  static Future<bool> conectar(String enderecoMac) {
    final tentativaAtual = _conexaoEmAndamento;

    if (tentativaAtual != null) {
      if (_macEmConexao == enderecoMac) {
        return tentativaAtual;
      }
      return tentativaAtual.then((_) => conectar(enderecoMac));
    }

    final tentativa = _conectarAgora(enderecoMac);
    _macEmConexao = enderecoMac;
    _conexaoEmAndamento = tentativa;

    return tentativa.whenComplete(() {
      if (identical(_conexaoEmAndamento, tentativa)) {
        _conexaoEmAndamento = null;
        _macEmConexao = null;
      }
    });
  }

  static Future<bool> _conectarAgora(String enderecoMac) async {
    try {
      return await PrintBluetoothThermal.connect(
        macPrinterAddress: enderecoMac,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> estaConectada() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  static Future<bool> desconectar() async {
    return await PrintBluetoothThermal.disconnect;
  }

  static Future<bool> imprimirRecibo({

    class Bairro {
  Bairro({
    required this.id,
    required this.nome,
  });

  final int id;
  String nome;
  final List<String> ruas = [];
}

class Morador {
  Morador({
    required this.id,
    required this.nome,
    required this.bairro,
    required this.rua,
    required this.numero,
  });

  final int id;
  String nome;
  String bairro;
  String rua;
  String numero;
}

class AppStore {
  String vigilanteNome = '';
String vigilanteEndereco = '';
String vigilanteContato = '';
String vigilanteCpfCnpj = '';
String vigilanteTipoWhatsapp = 'WhatsApp Padrão';
String vigilanteChavePix = '';
String vigilanteTipoChavePix = 'Telefone';
String vigilanteLogo = '';
  String vigilanteNomeFantasia = '';
    String vigilanteCnpjEmpresa = '';
String vigilanteSegmentoMercado = '';
String vigilanteServicoPrestado = '';
String vigilanteSite = '';
String vigilanteCredencial = '';

String vigilanteHorarioInicio = '';
String vigilanteHorarioFim = '';
String vigilanteObservacaoHorario = '';

bool vigilanteSegunda = false;
bool vigilanteTerca = false;
bool vigilanteQuarta = false;
bool vigilanteQuinta = false;
bool vigilanteSexta = false;
bool vigilanteSabado = false;
bool vigilanteDomingo = false;

String vigilanteLogoPretoBranco = '';
  final List<Bairro> bairros = [];
  final List<Morador> moradores = [];
    final List<Map<String, String>> clientes = [];
    final List<Map<String, dynamic>> mensalidades = [];
    bool geracaoAutomaticaAtiva = false;
int diasAntecedenciaGeracao = 0;
int? diaVencimentoGeracaoAutomatica;

Future<void> salvarClientes() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('clientes', jsonEncode(clientes));
}

Future<void> carregarClientes() async {
  final prefs = await SharedPreferences.getInstance();
  final texto = prefs.getString('clientes');

  if (texto == null || texto.isEmpty) return;

  final List<dynamic> dados = jsonDecode(texto);
  clientes
    ..clear()
    ..addAll(
      dados.map((item) => Map<String, String>.from(item as Map)),
    );
}
  Future<void> salvarMensalidades() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('mensalidades', jsonEncode(mensalidades));
}

Future<void> carregarMensalidades() async {
  final prefs = await SharedPreferences.getInstance();
  final texto = prefs.getString('mensalidades');

  mensalidades.clear();

  if (texto == null || texto.isEmpty) return;

  final List<dynamic> dados = jsonDecode(texto);
  final indicesPorChave = <String, int>{};

  String normalizar(Object? valor) =>
      (valor ?? '').toString().trim().toLowerCase();

  for (final item in dados) {
    final mensalidade = Map<String, dynamic>.from(item as Map);

    final chave = [
      normalizar(mensalidade['nome']),
      normalizar(mensalidade['bairro']),
      normalizar(mensalidade['rua']),
      normalizar(mensalidade['numero']),
      normalizar(mensalidade['mes']),
      normalizar(mensalidade['ano']),
    ].join('|');

    final indiceExistente = indicesPorChave[chave];

    if (indiceExistente == null) {
      indicesPorChave[chave] = mensalidades.length;
      mensalidades.add(mensalidade);
      continue;
    }

    final anterior = mensalidades[indiceExistente];
    final anteriorRecebida =
        normalizar(anterior['status']).contains('recebid');
    final novaRecebida =
        normalizar(mensalidade['status']).contains('recebid');

    if (!anteriorRecebida && novaRecebida) {
      mensalidades[indiceExistente] = mensalidade;
    }
  }

  if (mensalidades.length != dados.length) {
    await salvarMensalidades();
  }
}
  Future<void> salvarBairrosERuas() async {
  final prefs = await SharedPreferences.getInstance();

  final dados = bairros.map((bairro) {
    return {
      'id': bairro.id,
      'nome': bairro.nome,
      'ruas': bairro.ruas,
    };
  }).toList();

  await prefs.setString('bairros_ruas', jsonEncode(dados));
  }

Future<void> carregarBairrosERuas() async {
  final prefs = await SharedPreferences.getInstance();

  final texto = prefs.getString('bairros_ruas');

  if (texto == null || texto.isEmpty) {
    return;
  }

  final List<dynamic> dados = jsonDecode(texto);

  bairros.clear();

  int maiorId = 0;

  for (final item in dados) {
    final bairro = Bairro(
      id: item['id'],
      nome: item['nome'],
    );

    final ruas = item['ruas'];

    if (ruas != null) {
      bairro.ruas.addAll(
        List<String>.from(ruas),
      );
    }

    bairros.add(bairro);

    if (bairro.id > maiorId) {
      maiorId = bairro.id;
    }
  }

  proximoBairroId = maiorId + 1;
}

  int proximoBairroId = 1;
  int proximoMoradorId = 1;
Future<void> salvarDadosVigilante() async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString('vigilanteNome', vigilanteNome);
  await prefs.setString('vigilanteEndereco', vigilanteEndereco);
  await prefs.setString('vigilanteContato', vigilanteContato);
  await prefs.setString('vigilanteCpfCnpj', vigilanteCpfCnpj);
  await prefs.setString('vigilanteTipoWhatsapp', vigilanteTipoWhatsapp);
  await prefs.setString('vigilanteChavePix', vigilanteChavePix);
  await prefs.setString('vigilanteTipoChavePix', vigilanteTipoChavePix);
  await prefs.setString('vigilanteLogo', vigilanteLogo);await prefs.setString('vigilanteNomeFantasia', vigilanteNomeFantasia);
await prefs.setString('vigilanteSegmentoMercado', vigilanteSegmentoMercado);
await prefs.setString('vigilanteServicoPrestado', vigilanteServicoPrestado);
await prefs.setString('vigilanteSite', vigilanteSite);
await prefs.setString('vigilanteCredencial', vigilanteCredencial);

await prefs.setString('vigilanteHorarioInicio', vigilanteHorarioInicio);
await prefs.setString('vigilanteHorarioFim', vigilanteHorarioFim);
await prefs.setString('vigilanteObservacaoHorario', vigilanteObservacaoHorario);

await prefs.setBool('vigilanteSegunda', vigilanteSegunda);
await prefs.setBool('vigilanteTerca', vigilanteTerca);
await prefs.setBool('vigilanteQuarta', vigilanteQuarta);
await prefs.setBool('vigilanteQuinta', vigilanteQuinta);
await prefs.setBool('vigilanteSexta', vigilanteSexta);
await prefs.setBool('vigilanteSabado', vigilanteSabado);
await prefs.setBool('vigilanteDomingo', vigilanteDomingo);

await prefs.setString(
  'vigilanteLogoPretoBranco',
  vigilanteLogoPretoBranco,
);
}

Future<void> carregarDadosVigilante() async {
  final prefs = await SharedPreferences.getInstance();

  vigilanteNome = prefs.getString('vigilanteNome') ?? '';
  vigilanteEndereco = prefs.getString('vigilanteEndereco') ?? '';
  vigilanteContato = prefs.getString('vigilanteContato') ?? '';
  vigilanteCpfCnpj = prefs.getString('vigilanteCpfCnpj') ?? '';
  vigilanteTipoWhatsapp =
      prefs.getString('vigilanteTipoWhatsapp') ?? 'WhatsApp Padrão';
  vigilanteChavePix = prefs.getString('vigilanteChavePix') ?? '';
  vigilanteTipoChavePix =
      prefs.getString('vigilanteTipoChavePix') ?? 'Telefone';
  vigilanteLogo = prefs.getString('vigilanteLogo') ?? '';    vigilanteNomeFantasia =
        prefs.getString('vigilanteNomeFantasia') ?? '';
    vigilanteSegmentoMercado =
        prefs.getString('vigilanteSegmentoMercado') ?? '';
    vigilanteServicoPrestado =
        prefs.getString('vigilanteServicoPrestado') ?? '';
    vigilanteSite =
        prefs.getString('vigilanteSite') ?? '';
    vigilanteCredencial =
        prefs.getString('vigilanteCredencial') ?? '';

    vigilanteHorarioInicio =
        prefs.getString('vigilanteHorarioInicio') ?? '';
    vigilanteHorarioFim =
        prefs.getString('vigilanteHorarioFim') ?? '';
    vigilanteObservacaoHorario =
        prefs.getString('vigilanteObservacaoHorario') ?? '';

    vigilanteSegunda =
        prefs.getBool('vigilanteSegunda') ?? false;
    vigilanteTerca =
        prefs.getBool('vigilanteTerca') ?? false;
    vigilanteQuarta =
        prefs.getBool('vigilanteQuarta') ?? false;
    vigilanteQuinta =
        prefs.getBool('vigilanteQuinta') ?? false;
    vigilanteSexta =
        prefs.getBool('vigilanteSexta') ?? false;
    vigilanteSabado =
        prefs.getBool('vigilanteSabado') ?? false;
    vigilanteDomingo =
        prefs.getBool('vigilanteDomingo') ?? false;

    vigilanteLogoPretoBranco =
        prefs.getString('vigilanteLogoPretoBranco') ?? '';
}

Future<void> adicionarBairro(String nome) async {
  bairros.add(
    Bairro(
      id: proximoBairroId++,
      nome: nome,
    ),
  );

  await salvarBairrosERuas();
}

Future<void> adicionarRua(Bairro bairro, String nome) async {
  final existe = bairro.ruas.any(
    (rua) => rua.toLowerCase() == nome.toLowerCase(),
  );

  if (!existe) {
    bairro.ruas.add(nome);
    await salvarBairrosERuas();
  }
}

}
class PersonalizarReciboTermicoPage extends StatefulWidget {
  const PersonalizarReciboTermicoPage({super.key});

  @override
  State<PersonalizarReciboTermicoPage> createState() =>
      _PersonalizarReciboTermicoPageState();
}

class _PersonalizarReciboTermicoPageState
    extends State<PersonalizarReciboTermicoPage> {
  static const Color _azul = Color(0xFF10243A);
  static const Color _dourado = Color(0xFFD6AE52);

  final Map<String, bool> _campos = {
    'logo': true,
    'fantasia': true,
    'segmento': true,
    'horarios': true,
    'site': false,
    'endereco_vigilante': false,
    'documento_vigilante': false,
    'pix': true,
    'cliente_nome': true,
    'cliente_contato': true,
    'cliente_bairro': true,
    'cliente_documento': false,
    'data_pagamento': true,
  };

  String _modoQr = 'pendente';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

  Future<void> _carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();

    for (final chave in _campos.keys.toList()) {
      _campos[chave] = prefs.getBool('recibo_$chave') ?? _campos[chave]!;
    }

    if (!mounted) return;
    setState(() {
      _modoQr = prefs.getString('recibo_modo_qr') ?? 'pendente';
      _carregando = false;
    });
  }

  Future<void> _alterarCampo(String chave, bool valor) async {
    setState(() => _campos[chave] = valor);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('recibo_$chave', valor);
  }

  Future<void> _alterarModoQr(String? valor) async {
    if (valor == null) return;

    setState(() => _modoQr = valor);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recibo_modo_qr', valor);
  }

  Widget _secao(String titulo, List<Widget> itens) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8E1D2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                titulo.toUpperCase(),
                style: const TextStyle(
                  color: _azul,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            ...itens,
          ],
        ),
      ),
    );
  }

  Widget _opcao(String chave, String titulo, String descricao) {
    return SwitchListTile(
      value: _campos[chave] ?? false,
      activeThumbColor: _dourado,
      title: Text(
        titulo,
        style: const TextStyle(
          color: _azul,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(descricao),
      onChanged: (valor) => _alterarCampo(chave, valor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        title: const Text('Personalizar recibo'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: _azul,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: _dourado,
                          size: 38,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VIGILANTE RECIBOS',
                                style: TextStyle(
                                  color: _dourado,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Escolha o que será impresso no recibo.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _secao('Dados do vigilante', [
                  _opcao('logo', 'Logo', 'Exibir a marca no recibo'),
                  _opcao('fantasia', 'Nome fantasia', 'Exibir o nome da empresa'),
                  _opcao('segmento', 'Segmento', 'Exibir o tipo de serviço'),
                  _opcao('horarios', 'Horários', 'Exibir os horários do serviço'),
                  _opcao('site', 'Site', 'Exibir o endereço do site'),
                  _opcao(
                    'endereco_vigilante',
                    'Endereço',
                    'Exibir o endereço do vigilante',
                  ),
                  _opcao(
                    'documento_vigilante',
                    'CPF ou CNPJ',
                    'Exibir o documento do vigilante',
                  ),
                ]),
                _secao('Pagamento', [
                  _opcao('pix', 'Chave Pix', 'Exibir a chave Pix'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: DropdownButtonFormField<String>(
                      value: _modoQr,
                      decoration: const InputDecoration(
                        labelText: 'QR Code Pix',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'nunca',
                          child: Text('Não exibir'),
                        ),
                        DropdownMenuItem(
                          value: 'sempre',
                          child: Text('Exibir sempre'),
                        ),
                        DropdownMenuItem(
                          value: 'pendente',
                          child: Text('Exibir somente se estiver pendente'),
                        ),
                      ],
                      onChanged: _alterarModoQr,
                    ),
                  ),
                ]),
                _secao('Dados do cliente', [
                  _opcao('cliente_nome', 'Nome', 'Exibir o nome do cliente'),
                  _opcao(
                    'cliente_contato',
                    'Contato',
                    'Exibir o telefone ou contato',
                  ),
                  _opcao(
                    'cliente_bairro',
                    'Bairro',
                    'Exibir o bairro do cliente',
                  ),
                  _opcao(
                    'cliente_documento',
                    'CPF ou CNPJ',
                    'Exibir o documento do cliente',
                  ),
                  _opcao(
                    'data_pagamento',
                    'Data do pagamento',
                    'Exibir a data do pagamento',
                  ),
                ]),
              ],
            ),
    );
  }
}

