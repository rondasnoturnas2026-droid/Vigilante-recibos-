
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
final ValueNotifier<ThemeMode> temaApp =
    ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBrYerqTWP8wWX8AxMgSn_Zj0n_F8XRl9Y',
      appId: '1:353606198189:android:8f0cd92253fc1273c5b724',
      messagingSenderId: '353606198189',
      projectId: 'vigilante-recibos',
      storageBucket: 'vigilante-recibos.firebasestorage.app',
    ),
  );
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
class AutenticacaoGate extends StatelessWidget {
  const AutenticacaoGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não foi possível verificar a conta. Confira a conexão e tente abrir o app novamente.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.data != null) {
          return const TelaPrincipal();
        }

        return const TelaAcesso();
      },
    );
  }
}

class TelaAcesso extends StatefulWidget {
  const TelaAcesso({super.key});

  @override
  State<TelaAcesso> createState() => _TelaAcessoState();
}

class _TelaAcessoState extends State<TelaAcesso> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _criandoConta = false;
  bool _carregando = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  String? _validarEmail(String? valor) {
    final email = (valor ?? '').trim();

    if (email.isEmpty) return 'Informe seu e-mail.';

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Digite um e-mail válido.';
    }

    return null;
  }

  String? _validarSenha(String? valor) {
    final senha = valor ?? '';

    if (senha.isEmpty) return 'Informe sua senha.';

    if (_criandoConta && senha.length < 6) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }

    return null;
  }

  String _mensagemErro(FirebaseAuthException erro) {
    switch (erro.code) {
      case 'email-already-in-use':
        return 'Este e-mail já tem uma conta. Toque em Entrar.';
      case 'invalid-email':
        return 'O e-mail informado é inválido.';
      case 'weak-password':
        return 'Escolha uma senha com pelo menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha não conferem.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      case 'network-request-failed':
        return 'Confira sua conexão com a internet e tente novamente.';
      case 'operation-not-allowed':
        return 'O acesso por e-mail e senha não está ativado no Firebase.';
      default:
        return 'Não foi possível concluir. Confira os dados e tente novamente.';
    }
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _enviarFormulario() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final email = _emailController.text.trim();
      final senha = _senhaController.text;

      if (_criandoConta) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: senha,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: senha,
        );
                if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
                }
      }
    } on FirebaseAuthException catch (erro) {
      _mostrarMensagem(_mensagemErro(erro));
    } catch (_) {
      _mostrarMensagem(
        'Ocorreu um erro. Confira sua conexão e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recuperarSenha() async {
    FocusScope.of(context).unfocus();

    if (_validarEmail(_emailController.text) != null) {
      _mostrarMensagem('Informe um e-mail válido para recuperar a senha.');
      return;
    }

    setState(() => _carregando = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      _mostrarMensagem(
        'Se houver uma conta com esse e-mail, enviaremos as instruções de recuperação.',
      );
    } on FirebaseAuthException catch (erro) {
      _mostrarMensagem(_mensagemErro(erro));
    } catch (_) {
      _mostrarMensagem(
        'Não foi possível enviar o e-mail. Confira sua conexão e tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _criandoConta ? 'Criar conta' : 'Entrar';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vigilante Recibos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validarEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: !_mostrarSenha,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _enviarFormulario(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _mostrarSenha = !_mostrarSenha);
                          },
                          icon: Icon(
                            _mostrarSenha
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: _validarSenha,
                    ),
                    if (!_criandoConta)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _carregando ? null : _recuperarSenha,
                          child: const Text('Esqueci a senha'),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Use uma senha com pelo menos 6 caracteres.',
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _carregando ? null : _enviarFormulario,
                        child: _carregando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(titulo),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _carregando
                          ? null
                          : () {
                              setState(
                                () => _criandoConta = !_criandoConta,
                              );
                            },
                      child: Text(
                        _criandoConta
                            ? 'Já tenho uma conta — Entrar'
                            : 'Ainda não tenho conta — Criar conta',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A conta ainda não sincroniza os dados do app entre celulares.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
      TelaRelatorio(store: store),
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
    Map<String, dynamic>? _mensalidadeAberta;
    final Set<Map<String, dynamic>> _mensalidadesSelecionadas = {};
  String bairroFiltro = 'Todos os bairros';
  String ruaFiltro = 'Todas as ruas';
  String diaFiltro = 'Todos os dias';
    String buscaMensalidade = '';
    bool buscaAberta = false;
  String pagamentoFiltro = 'Todas as formas';
    bool totalVisivel = true;
    bool _decimoTerceiroDobrado = false;
      Map<String, String> _dadosClienteParaRecibo(
    Map<String, dynamic> mensalidade,
          
          
  ) {
    String normalizar(Object? valor) =>
        (valor ?? '').toString().trim().toLowerCase();

    final nome = normalizar(mensalidade['nome']);
    final bairro = normalizar(mensalidade['bairro']);
    final rua = normalizar(mensalidade['rua']);
    final numero = normalizar(mensalidade['numero']);

    final cliente = widget.store.clientes.firstWhere(
      (cliente) =>
          normalizar(cliente['nome']) == nome &&
          normalizar(cliente['bairro']) == bairro &&
          normalizar(cliente['rua']) == rua &&
          normalizar(cliente['numero']) == numero,
      orElse: () => <String, String>{},
    );

    return <String, String>{
      'bairro': (mensalidade['bairro'] ?? '').toString(),
      'contato': (cliente['telefone'] ?? '').toString(),
      'documento': (cliente['cpf'] ?? '').toString(),
    };
      }
    void _alternarSelecaoMensalidade(Map<String, dynamic> mensalidade) {
  setState(() {
    if (_mensalidadesSelecionadas.contains(mensalidade)) {
      _mensalidadesSelecionadas.remove(mensalidade);
    } else {
      _mensalidadesSelecionadas.add(mensalidade);
    }
  });
    }

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
        final prefsDecimo = await SharedPreferences.getInstance();
  _decimoTerceiroDobrado =
      prefsDecimo.getBool('recibo_decimo_terceiro_dobrado') ?? false;
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
      const SnackBar(
        content: Text('Cadastre a chave Pix nas configurações.'),
      ),
    );
    return;
  }

  final pixCopiaECola =
      ImpressoraBluetoothService._gerarPixCopiaECola(
    chavePix: chavePix,
    nomeVigilante: widget.store.vigilanteNomeFantasia,
    valor: (mensalidade['valor'] ?? '0,00').toString(),
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pagamento Pix',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text('Cliente: ${mensalidade['nome'] ?? 'Cliente'}'),
              const SizedBox(height: 12),
              const Text('QR Code Pix:'),
              const SizedBox(height: 8),
              SizedBox(
                width: 220,
                height: 220,
                child: QrImageView(
                  data: pixCopiaECola,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Chave Pix:'),
              SelectableText(chavePix),
              const SizedBox(height: 8),
              Text(
                'Valor: R\$ ${mensalidade['valor'] ?? '0,00'}',
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fechar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: chavePix),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar chave'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: pixCopiaECola),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar código Pix'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

      pintor.layout(maxWidth: texto == empresa ? 700 : 880);
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
          final prefsRecibo = await SharedPreferences.getInstance();

bool mostrarCampo(String chave, bool padrao) =>
    prefsRecibo.getBool('recibo_$chave') ?? padrao;

final mostrarLogo = mostrarCampo('logo', true);
final caminhoLogo =
    mostrarLogo ? widget.store.vigilanteLogo.trim() : '';

if (caminhoLogo.isNotEmpty) {
  try {
    final bytesLogo = await File(caminhoLogo).readAsBytes();
    final codecLogo = await ui.instantiateImageCodec(bytesLogo);
    final frameLogo = await codecLogo.getNextFrame();
    final imagemLogo = frameLogo.image;

    final larguraOriginal = imagemLogo.width.toDouble();
    final alturaOriginal = imagemLogo.height.toDouble();
    final maiorLado = larguraOriginal > alturaOriginal
        ? larguraOriginal
        : alturaOriginal;
    final escalaLogo = 110 / maiorLado;
    final larguraLogo = larguraOriginal * escalaLogo;
    final alturaLogo = alturaOriginal * escalaLogo;

    canvas.drawImageRect(
      imagemLogo,
      ui.Rect.fromLTWH(0, 0, larguraOriginal, alturaOriginal),
      ui.Rect.fromLTWH(
        910 - larguraLogo / 2,
        180 - alturaLogo / 2,
        larguraLogo,
        alturaLogo,
      ),
      ui.Paint(),
    );
  } catch (_) {}
}

if (mostrarCampo('fantasia', true) && empresa.trim().isNotEmpty) {
  escrever(
    empresa.trim(),
    95,
    tamanho: 44,
    cor: Colors.white,
    peso: FontWeight.bold,
  );
}

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

final clientesEncontrados = widget.store.clientes.where(
  (item) =>
      (item['nome'] ?? '').trim().toLowerCase() ==
      cliente.trim().toLowerCase(),
);
final dadosCliente = clientesEncontrados.isNotEmpty
    ? clientesEncontrados.first
    : <String, String>{};

final campos = <MapEntry<String, String>>[];

void adicionarCampoRecibo(
  String chave,
  String titulo,
  Object? valorCampo,
  bool padrao,
) {
  final texto = (valorCampo ?? '').toString().trim();
  if (mostrarCampo(chave, padrao) && texto.isNotEmpty) {
    campos.add(MapEntry(titulo, texto));
  }
}

adicionarCampoRecibo(
  'segmento',
  'Segmento',
  widget.store.vigilanteSegmentoMercado,
  true,
);

final horarios = [
  widget.store.vigilanteHorarioInicio,
  widget.store.vigilanteHorarioFim,
].where((item) => item.trim().isNotEmpty).join(' às ');

adicionarCampoRecibo('horarios', 'Horário', horarios, true);
adicionarCampoRecibo('site', 'Site', widget.store.vigilanteSite, false);
adicionarCampoRecibo(
  'endereco_vigilante',
  'Endereço',
  widget.store.vigilanteEndereco,
  false,
);
adicionarCampoRecibo(
  'documento_vigilante',
  'CPF/CNPJ do vigilante',
  widget.store.vigilanteCpfCnpj,
  false,
);
      final quantidadeCamposVigilante = campos.length;
adicionarCampoRecibo('cliente_nome', 'Cliente', cliente, true);
adicionarCampoRecibo(
  'cliente_contato',
  'Contato',
  mensalidade['contato'] ??
      mensalidade['telefone'] ??
      dadosCliente['telefone'],
  true,
);
adicionarCampoRecibo(
  'cliente_bairro',
  'Bairro',
  mensalidade['bairro'] ?? dadosCliente['bairro'],
  true,
);
adicionarCampoRecibo(
  'cliente_rua',
  'Rua',
  mensalidade['rua'] ?? dadosCliente['rua'],
  true,
);
adicionarCampoRecibo(
  'cliente_numero',
  'Número',
  mensalidade['numero'] ?? dadosCliente['numero'],
  true,
);
adicionarCampoRecibo(
  'cliente_documento',
  'CPF/CNPJ do cliente',
  mensalidade['cpfCnpj'] ??
      dadosCliente['cpf'] ??
      dadosCliente['cpfCnpj'],
  false,
);
adicionarCampoRecibo(
  'valor',
  'Valor pago',
  'R\$ $valor',
  true,
);
      final valorDecimoTerceiro =
    (mensalidade['valorDecimoTerceiro'] ?? '0,00').toString().trim();
var valorDecimoNumeroTexto = valorDecimoTerceiro.replaceAll('R\$', '').trim();
if (valorDecimoNumeroTexto.contains(',')) {
  valorDecimoNumeroTexto = valorDecimoNumeroTexto
      .replaceAll('.', '')
      .replaceAll(',', '.');
}
final valorDecimoNumero =
    double.tryParse(valorDecimoNumeroTexto) ?? 0.0;

if (valorDecimoNumero > 0) {
  final valorTotalSalvo =
      (mensalidade['valorTotalRecebido'] ?? '').toString().trim();
  var valorBaseNumeroTexto = valor.replaceAll('R\$', '').trim();
  if (valorBaseNumeroTexto.contains(',')) {
    valorBaseNumeroTexto = valorBaseNumeroTexto
        .replaceAll('.', '')
        .replaceAll(',', '.');
  }
  final valorBaseNumero = double.tryParse(valorBaseNumeroTexto) ?? 0.0;
  final valorTotalFormatado = valorTotalSalvo.isNotEmpty
      ? valorTotalSalvo
      : (valorBaseNumero + valorDecimoNumero)
          .toStringAsFixed(2)
          .replaceAll('.', ',');

  adicionarCampoRecibo(
    'decimo_terceiro',
    'Décimo terceiro',
    'R\$ $valorDecimoTerceiro',
    true,
  );
  adicionarCampoRecibo(
    'valor_total_recebido',
    'Total recebido',
    'R\$ $valorTotalFormatado',
    true,
  );
}
adicionarCampoRecibo(
  'forma_pagamento',
  'Forma de pagamento',
  pagamento,
  true,
);
adicionarCampoRecibo(
  'vencimento',
  ehAdiantamento ? 'Período adiantado' : 'Vencimento',
  ehAdiantamento
      ? periodoAdiantamento
      : dataFormatada(
          DateTime(anoVencimento, mesVencimento, diaVencimento),
        ),
  true,
);
adicionarCampoRecibo(
  'data_pagamento',
  'Recebido em',
  dataFormatada(agora),
  true,
);
adicionarCampoRecibo(
  'status',
  'Status',
  'RECEBIDO',
  true,
);
adicionarCampoRecibo(
  'observacao',
  'Observação',
  mensalidade['observacao'],
  true,
);
adicionarCampoRecibo(
  'pix',
  'Chave Pix',
  widget.store.vigilanteChavePix,
  true,
);

void escreverCampoRecibo(String texto, double x, double y) {
  final pintor = TextPainter(
    text: TextSpan(
      text: texto,
      style: const TextStyle(
        color: Color(0xFF202938),
        fontSize: 25,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  );

  pintor.layout(maxWidth: 420);
  pintor.paint(canvas, ui.Offset(x, y));
}

final int linhasVigilante = (quantidadeCamposVigilante + 1) ~/ 2;

for (var i = 0; i < campos.length; i++) {
  final bool campoCliente = i >= quantidadeCamposVigilante;
  final int indiceGrupo =
      campoCliente ? i - quantidadeCamposVigilante : i;

  if (campoCliente && i == quantidadeCamposVigilante) {
    final double yDivisoria =
        350.0 + linhasVigilante * 68.0 - 18.0;

    canvas.drawLine(
      Offset(80.0, yDivisoria),
      Offset(1050.0, yDivisoria),
      Paint()
        ..color = const Color(0xFF202938)
        ..strokeWidth = 2,
    );
  }

  final int coluna = indiceGrupo % 2;
  final int linha = campoCliente
      ? linhasVigilante + 1 + indiceGrupo ~/ 2
      : indiceGrupo ~/ 2;

  final double x = coluna == 0 ? 100.0 : 550.0;
  final double y = 350.0 + linha * 68.0;

  escreverCampoRecibo(
    '${campos[i].key}: ${campos[i].value}',
    x,
    y,
  );
}

final modoQr = prefsRecibo.getString('recibo_modo_qr') ?? 'pendente';
final statusMensalidade =
    (mensalidade['status'] ?? 'recebido').toString().toLowerCase();
final mostrarQr =
    modoQr == 'sempre' ||
    (modoQr == 'pendente' && statusMensalidade.contains('pend'));

final chavePix = widget.store.vigilanteChavePix.trim();

if (mostrarQr && chavePix.isNotEmpty) {
  try {
    final pixCopiaECola =
        ImpressoraBluetoothService._gerarPixCopiaECola(
      chavePix: chavePix,
      nomeVigilante: empresa,
      valor: valor,
    );

    escrever(
      'PAGUE COM PIX',
      1040,
      tamanho: 26,
      cor: const Color(0xFF17365D),
      peso: FontWeight.bold,
    );

        final dadosQr = await QrPainter(
      data: pixCopiaECola,
      version: QrVersions.auto,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: true,
    ).toImageData(200);

    if (dadosQr != null) {
      final codecQr = await ui.instantiateImageCodec(
        dadosQr.buffer.asUint8List(),
      );
      final frameQr = await codecQr.getNextFrame();

      canvas.drawImageRect(
        frameQr.image,
        ui.Rect.fromLTWH(
          0,
          0,
          frameQr.image.width.toDouble(),
          frameQr.image.height.toDouble(),
        ),
        ui.Rect.fromLTWH(440, 1070, 200, 200),
        ui.Paint(),
      );
    }
  } catch (_) {}
}

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
        text: [
  'Pagamento recebido, $cliente. Agradecemos pela confiança no nosso trabalho. '
      'Nosso compromisso com sua segurança continua. Conte sempre conosco.',
  if (mesVencimento == 11 &&
      (prefsRecibo.getBool('recibo_decimo_terceiro_ativo') ?? true))
    (prefsRecibo.getString('recibo_decimo_terceiro_mensagem') ??
            DecimoTerceiroPersonalizacaoTab.mensagemPadrao)
        .replaceAll('{nome do cliente}', cliente),
].join('\n\n'),
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
    Future<void> _avisarCliente(Map<String, dynamic> mensalidade) async {
  final prefs = await SharedPreferences.getInstance();

  final nome = (mensalidade['nome'] ?? 'Cliente').toString();
  final valor = (mensalidade['valor'] ?? '0,00').toString();
  final bairro = (mensalidade['bairro'] ?? '').toString();
  final rua = (mensalidade['rua'] ?? '').toString();
  final numero = (mensalidade['numero'] ?? '').toString();

  Map<String, dynamic> cliente = {};
  for (final item in widget.store.clientes) {
    if ((item['nome'] ?? '').toString().trim().toLowerCase() ==
            nome.trim().toLowerCase() &&
        (item['bairro'] ?? '').toString() == bairro &&
        (item['rua'] ?? '').toString() == rua &&
        (item['numero'] ?? '').toString() == numero) {
      cliente = Map<String, dynamic>.from(item);
      break;
    }
  }

  final tipoAviso = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Avisar cliente'),
      content: const Text('Escolha o tipo de mensagem:'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'texto'),
          child: const Text('Aviso em texto'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'cobranca'),
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Cobrança com QR'),
        ),
      ],
    ),
  );

  if (!mounted || tipoAviso == null) return;

    final telefone = [
    mensalidade['telefone'],
    mensalidade['contato'],
    cliente['telefone'],
  ]
      .map((valor) => (valor ?? '').toString().replaceAll(RegExp(r'\D'), ''))
      .firstWhere((valor) => valor.isNotEmpty, orElse: () => '');

  if (tipoAviso == 'texto' && telefone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este cliente não tem telefone cadastrado.')),
    );
    return;
  }

  final modeloCobranca = prefs.getString('cobranca_mensagem') ??
      '🔔 AVISO DE PAGAMENTO DA MENSALIDADE\n\n'
          'Olá, {nome do cliente}! Este é um aviso sobre a mensalidade de '
          '{mês}, no valor de {valor}, com vencimento em {data}.\n\n'
          'Para pagar pelo Pix:\n'
          'Chave Pix: {chave Pix}\n'
          'Pix copia e cola: {código Pix}\n'
          'O QR Code Pix acompanha o aviso.';

    final modeloTexto = prefs.getString('aviso_texto_mensagem') ??
      'Olá, {nome do cliente}! Tudo bem?\n\n'
      'Passando para lembrar da mensalidade de {mês}, no valor de {valor}, '
      'com vencimento em {data}.\n\n'
      'Para facilitar o pagamento, segue a chave Pix:\n'
      '{chave Pix}\n\n'
      'Se tiver alguma dúvida, estou à disposição. Obrigado!';

    double valorComoNumero(Object? valorOriginal) {
    var texto = (valorOriginal ?? '0').toString().replaceAll('R\$', '').trim();
    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(texto) ?? 0;
  }

  String formatarValor(double valorNumero) =>
      valorNumero.toStringAsFixed(2).replaceAll('.', ',');

  final agora = DateTime.now();
  final dia =
      int.tryParse((mensalidade['dia'] ?? '').toString()) ?? agora.day;
  final mesDaMensalidade =
      int.tryParse((mensalidade['mes'] ?? '').toString()) ?? agora.month;
  final ano =
      int.tryParse((mensalidade['ano'] ?? '').toString()) ?? agora.year;

  final valorMensalidade = valorComoNumero(valor);
  final incluirDecimoEmDezembro =
      mesDaMensalidade == 12 &&
      (prefs.getBool('recibo_decimo_terceiro_dobrado') ?? false);
  final valorDecimoTerceiro =
      incluirDecimoEmDezembro ? valorMensalidade : 0.0;
  final valorTotalCobranca =
      valorMensalidade + valorDecimoTerceiro;
  final valorParaMensagem = incluirDecimoEmDezembro
      ? formatarValor(valorTotalCobranca)
      : valor;

  String mensagem;
  String pixCopiaECola = '';

  if (tipoAviso == 'cobranca') {
    final chavePix = widget.store.vigilanteChavePix.trim();

    if (chavePix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre a chave Pix nas configurações.'),
        ),
      );
      return;
    }

    const meses = [
      '',
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    final mesTexto = mesDaMensalidade >= 1 && mesDaMensalidade <= 12
        ? '${meses[mesDaMensalidade]} de $ano'
        : '$mesDaMensalidade/$ano';

    final vencimento =
        '${dia.toString().padLeft(2, '0')}/'
        '${mesDaMensalidade.toString().padLeft(2, '0')}/$ano';

    final tipoChavePix = widget.store.vigilanteTipoChavePix;
var chavePixParaCodigo = chavePix;

if (tipoChavePix == 'Telefone') {
  final numeros = chavePix.replaceAll(RegExp(r'\D'), '');

  if ((numeros.length == 12 || numeros.length == 13) &&
      numeros.startsWith('55')) {
    chavePixParaCodigo = '+$numeros';
  } else if (numeros.length == 10 || numeros.length == 11) {
    chavePixParaCodigo = '+55$numeros';
  }
}

pixCopiaECola = ImpressoraBluetoothService._gerarPixCopiaECola(
  chavePix: chavePixParaCodigo,
  tipoChavePix: tipoChavePix,
  nomeVigilante: widget.store.vigilanteNomeFantasia,
  valor: valorParaMensagem,
);

    mensagem = modeloCobranca
        .replaceAll('{nome do cliente}', nome)
        .replaceAll('{mês}', mesTexto)
        .replaceAll('{valor}', 'R\$ $valorParaMensagem')
        .replaceAll('{data}', vencimento)
        .replaceAll('{chave Pix}', chavePix)
        .replaceAll('{código Pix}', pixCopiaECola);

    if (incluirDecimoEmDezembro) {
      mensagem +=
          '\n\nMensalidade: R\$ ${formatarValor(valorMensalidade)}'
          '\nDécimo terceiro: R\$ ${formatarValor(valorDecimoTerceiro)}'
          '\nTotal para pagamento: R\$ ${formatarValor(valorTotalCobranca)}';
    }
  } else {
        const mesesAviso = [
      '',
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    final mesTextoAviso =
        mesDaMensalidade >= 1 && mesDaMensalidade <= 12
            ? '${mesesAviso[mesDaMensalidade]} de $ano'
            : '$mesDaMensalidade/$ano';

    final vencimentoAviso =
        '${dia.toString().padLeft(2, '0')}/'
        '${mesDaMensalidade.toString().padLeft(2, '0')}/$ano';

    mensagem = modeloTexto
        .replaceAll('{nome do cliente}', nome)
        .replaceAll('{mês}', mesTextoAviso)
        .replaceAll('{valor}', 'R\$ $valorParaMensagem')
        .replaceAll('{data}', vencimentoAviso)
        .replaceAll(
          '{chave Pix}',
          widget.store.vigilanteChavePix.trim(),
        )
        .replaceAll('{escreva aqui o aviso}', '');
  }

  final avisoDecimoTerceiroAtivo =
      prefs.getBool('recibo_decimo_terceiro_ativo') ?? true;

  if (mesDaMensalidade == 11 && avisoDecimoTerceiroAtivo) {
    final textoDecimoTerceiro =
        (prefs.getString('recibo_decimo_terceiro_mensagem') ??
                DecimoTerceiroPersonalizacaoTab.mensagemPadrao)
            .replaceAll('{nome do cliente}', nome);

    mensagem = '$mensagem\n\n$textoDecimoTerceiro';
  }

  final controlador = TextEditingController(text: mensagem);

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Revisar mensagem'),
      content: TextField(
        controller: controlador,
        minLines: 5,
        maxLines: 10,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
          if (tipoAviso == 'cobranca')
  TextButton.icon(
    onPressed: () async {
      await Clipboard.setData(
        ClipboardData(text: pixCopiaECola),
      );
      if (!dialogContext.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pix copia e cola copiado.'),
        ),
      );
    },
    icon: const Icon(Icons.copy),
    label: const Text('Copiar código Pix'),
  ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            tipoAviso == 'cobranca' ? 'Compartilhar cobrança' : 'Abrir WhatsApp',
          ),
        ),
      ],
    ),
  );

  final textoFinal = controlador.text.trim();
  controlador.dispose();

  if (!mounted || confirmar != true || textoFinal.isEmpty) return;

  if (tipoAviso == 'texto') {
    final telefoneInternacional =
        telefone.startsWith('55') ? telefone : '55$telefone';

    final uri = Uri.parse(
      'https://wa.me/$telefoneInternacional'
      '?text=${Uri.encodeComponent(textoFinal)}',
    );

    final abriu = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!abriu && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
    return;
  }

  try {
      
    const larguraImagem = 1040.0;
    const margem = 56.0;
    const tamanhoQr = 80.0;
const espacoAntesQr = 64.0;

    final textoPintor = TextPainter(
      text: TextSpan(
        text: textoFinal,
        style: const TextStyle(
          color: Color(0xFF202938),
          fontSize: 32,
          height: 1.25,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textoPintor.layout(maxWidth: larguraImagem - margem * 2);

    final painterQr = QrPainter(
      data: pixCopiaECola,
      version: QrVersions.auto,
      color: Colors.black,
      emptyColor: Colors.white,
      gapless: true,
    );
    final dadosQr = await painterQr.toImageData(
      600,
      format: ui.ImageByteFormat.png,
    );

    if (dadosQr == null) {
      throw Exception('Não foi possível gerar o QR Code.');
    }

    final alturaImagem =
        (margem + textoPintor.height + espacoAntesQr + tamanhoQr + margem)
            .ceil();
    final gravador = ui.PictureRecorder();
    final canvas = ui.Canvas(gravador);

    canvas.drawColor(const Color(0xFFF2F4F8), ui.BlendMode.src);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(
          20,
          20,
          larguraImagem - 40,
          alturaImagem - 40,
        ),
        const ui.Radius.circular(28),
      ),
      ui.Paint()..color = Colors.white,
    );
    textoPintor.paint(canvas, const ui.Offset(margem, margem));

    final codecQr = await ui.instantiateImageCodec(
      dadosQr.buffer.asUint8List(
        dadosQr.offsetInBytes,
        dadosQr.lengthInBytes,
      ),
    );
    final frameQr = await codecQr.getNextFrame();
    final posicaoQr = ui.Rect.fromLTWH(
      (larguraImagem - tamanhoQr) / 2,
      margem + textoPintor.height + espacoAntesQr,
      tamanhoQr,
      tamanhoQr,
    );
    canvas.drawImageRect(
      frameQr.image,
      ui.Rect.fromLTWH(
        0,
        0,
        frameQr.image.width.toDouble(),
        frameQr.image.height.toDouble(),
      ),
      posicaoQr,
      ui.Paint()..filterQuality = FilterQuality.high,
    );

    final imagemCobranca = await gravador.endRecording().toImage(
      larguraImagem.toInt(),
      alturaImagem,
    );
    final dadosImagem = await imagemCobranca.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (dadosImagem == null) {
      throw Exception('Não foi possível montar a cobrança com QR.');
    }

    final arquivo = File(
      '${Directory.systemTemp.path}/cobranca_pix_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await arquivo.writeAsBytes(
      dadosImagem.buffer.asUint8List(),
      flush: true,
    );

            await SharePlus.instance.share(
      ShareParams(
        title: 'Cobrança da mensalidade',
        text: pixCopiaECola,
        files: [
          XFile(arquivo.path, mimeType: 'image/png'),
        ],
      ),
    );

    await SharePlus.instance.share(
      ShareParams(
        title: 'Chave Pix',
        text: widget.store.vigilanteChavePix.trim(),
      ),
    );
      } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível preparar a cobrança com QR.'),
      ),
    );
  }
    }
 Future<void> _criarMensalidadesOutroMes() async {
  final clientes = widget.store.clientes.asMap().entries.where(
    (item) =>
        (item.value['ativo'] ?? 'true').toString().toLowerCase() != 'false',
  ).toList();

  if (clientes.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não há Clientes ativos cadastrados.')),
    );
    return;
  }

  final agora = DateTime.now();
  const meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];
  final anos = List.generate(
    41,
    (i) => agora.year - 20 + i,
  );

  var mes = agora.month;
  var ano = agora.year;
  final selecionados = <int>{};

  final confirmou = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, atualizar) => AlertDialog(
        title: const Text('Criar mensalidades em outro mês'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: mes,
              decoration: const InputDecoration(labelText: 'Mês'),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(meses[i]),
                ),
              ),
              onChanged: (valor) {
                if (valor != null) atualizar(() => mes = valor);
              },
            ),
            DropdownButtonFormField<int>(
              value: ano,
              decoration: const InputDecoration(labelText: 'Ano'),
              items: anos.map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text('$item'),
                ),
              ).toList(),
              onChanged: (valor) {
                if (valor != null) atualizar(() => ano = valor);
              },
            ),
            const SizedBox(height: 8),
            ...clientes.map((item) {
              final cliente = item.value;
              return CheckboxListTile(
                dense: true,
                value: selecionados.contains(item.key),
                title: Text((cliente['nome'] ?? 'Sem nome').toString()),
                subtitle: Text(
                  '${cliente['bairro'] ?? ''} • '
                  '${cliente['rua'] ?? ''}, Nº ${cliente['numero'] ?? ''}',
                ),
                onChanged: (marcado) => atualizar(() {
                  if (marcado == true) {
                    selecionados.add(item.key);
                  } else {
                    selecionados.remove(item.key);
                  }
                }),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: selecionados.isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text('Criar mensalidades'),
          ),
        ],
      ),
    ),
  );

  if (confirmou != true) return;

  String normalizar(Object? valor) =>
      (valor ?? '').toString().trim().toLowerCase();

  var criadas = 0;

  for (final indice in selecionados) {
    final cliente = widget.store.clientes[indice];

    final jaExiste = widget.store.mensalidades.any((mensalidade) =>
        normalizar(mensalidade['nome']) == normalizar(cliente['nome']) &&
        normalizar(mensalidade['bairro']) == normalizar(cliente['bairro']) &&
        normalizar(mensalidade['rua']) == normalizar(cliente['rua']) &&
        normalizar(mensalidade['numero']) == normalizar(cliente['numero']) &&
        normalizar(mensalidade['mes']) == mes.toString() &&
        normalizar(mensalidade['ano']) == ano.toString());

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
      'mes': mes,
      'ano': ano,
    });

    criadas++;
  }

  if (criadas > 0) {
    await widget.store.salvarMensalidades();
    await widget.store.carregarMensalidades();
  }

  if (!mounted) return;
  setState(() {});

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$criadas mensalidade(s) criada(s).')),
  );
 }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      
              appBar: AppBar(
        title: Text(
  _mensalidadesSelecionadas.isNotEmpty
      ? '${_mensalidadesSelecionadas.length} selecionada(s)'
      : 'Mensalidades',
),
        
        actions: [
  if (_mensalidadesSelecionadas.isNotEmpty) ...[
    IconButton(
      tooltip: 'Cancelar seleção',
      icon: const Icon(Icons.close),
      onPressed: () {
        setState(() {
          _mensalidadesSelecionadas.clear();
        });
      },
    ),
    IconButton(
      tooltip: 'Excluir selecionadas',
      icon: const Icon(Icons.delete_outline),
      onPressed: _excluirMensalidadesSelecionadas,
    ),
  ] else ...[
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
      tooltip: 'Criar em outro mês',
      icon: const Icon(Icons.calendar_month),
      onPressed: _criarMensalidadesOutroMes,
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
  padding: const EdgeInsets.symmetric(horizontal: 12),
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
double valorParaNumero(Object? valorBruto) {
  var texto = (valorBruto ?? '0').toString()
      .replaceAll('R\$', '')
      .trim();

  if (texto.contains(',')) {
    texto = texto.replaceAll('.', '').replaceAll(',', '.');
  }

  return double.tryParse(texto) ?? 0.0;
}

final totalMensalidades = mensalidadesFiltradas.fold<double>(
  0.0,
  (soma, mensalidade) {
    final valorBase = valorParaNumero(mensalidade['valor']);
    final mes = int.tryParse((mensalidade['mes'] ?? '').toString()) ?? 0;
    final incluirDecimoTerceiro =
        mes == 12 &&
        _decimoTerceiroDobrado &&
        mensalidade['incluirDecimoTerceiro'] != false;

    return soma + (incluirDecimoTerceiro ? valorBase * 2 : valorBase);
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
                    final valorOriginal =
    (mensalidade['valor'] ?? '0,00').toString();
var valorNumeroTexto =
    valorOriginal.replaceAll('R\$', '').trim();

if (valorNumeroTexto.contains(',')) {
  valorNumeroTexto =
      valorNumeroTexto.replaceAll('.', '').replaceAll(',', '.');
}

final valorNumero = double.tryParse(valorNumeroTexto) ?? 0.0;
final mesCartao =
    int.tryParse((mensalidade['mes'] ?? '').toString()) ?? 0;

final valor = mesCartao == 12 &&
        _decimoTerceiroDobrado &&
        mensalidade['incluirDecimoTerceiro'] != false
    ? (valorNumero * 2).toStringAsFixed(2).replaceAll('.', ',')
    : valorOriginal;
                    final nome =
                        (mensalidade['nome'] ?? 'Cliente').toString();
      final cartaoExpandido = identical(_mensalidadeAberta, mensalidade);

                    return GestureDetector(
  onLongPress: () => _alternarSelecaoMensalidade(mensalidade),
  child: Card(
  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: const BorderSide(
      color: Color(0xFFD6AE32),
      width: 0.7,
    ),
  ),
  child: ExpansionTile(
    key: ValueKey<String>(
      '${identityHashCode(mensalidade)}-$cartaoExpandido',
    ),
    initiallyExpanded: cartaoExpandido,
    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
    onExpansionChanged: (expandido) {
  if (_mensalidadesSelecionadas.isNotEmpty) {
    _alternarSelecaoMensalidade(mensalidade);
    return;
  }

  setState(() {
    _mensalidadeAberta = expandido ? mensalidade : null;
  });
},
    leading: Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD6AE32),
        ),
      ),
            child: _mensalidadesSelecionadas.contains(mensalidade)
          ? const Icon(
              Icons.check,
              size: 20,
              color: Color(0xFF242424),
            )
          : Text(
              (mensalidade['dia'] ?? '').toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF242424),
              ),
            ),
    ),
    title: Row(
      children: [
        Expanded(
          child: Text(
            nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          'R\$ $valor',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rua: ${(mensalidade['rua'] ?? '').toString()}, Nº '
          '${(mensalidade['numero'] ?? '').toString()}',
          style: const TextStyle(fontSize: 12),
        ),
        Row(
  children: [
    Tooltip(
      message: (mensalidade['formaPagamento'] ?? '').toString(),
      child: Icon(
  (mensalidade['formaPagamento'] ?? '')
          .toString()
          .toLowerCase()
          .contains('pix')
      ? Icons.pix
      : (mensalidade['formaPagamento'] ?? '')
              .toString()
              .toLowerCase()
              .contains('dinheir')
          ? Icons.money
          : Icons.credit_card,
  color: (mensalidade['formaPagamento'] ?? '')
        .toString()
        .toLowerCase()
        .contains('pix')
    ? const Color(0xFF2196F3)
    : (mensalidade['formaPagamento'] ?? '')
            .toString()
            .toLowerCase()
            .contains('dinheir')
        ? const Color(0xFF4CAF50)
        : const Color(0xFFFF9800),
  size: 22,
),
    ),
    const SizedBox(width: 8),
    if (abaAtual == 0)
      IconButton(
        tooltip: 'Avisar',
        onPressed: () => _avisarCliente(mensalidade),
        icon: Icon(
  Icons.notifications_active_outlined,
  size: 18,
  color: Theme.of(context).colorScheme.onSurface,
),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(
          width: 30,
          height: 28,
        ),
      ),
  ],
),
        if ((mensalidade['retorno'] ?? '').toString().isNotEmpty)
          Text(
            'Retorno: ${mensalidade['retorno']}',
            style: const TextStyle(fontSize: 11),
          ),
      ],
    ),
    trailing: const Icon(Icons.expand_more),
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
                                      double valorParaNumero(Object? valor) {
  var texto = (valor ?? '0').toString().replaceAll('R\$', '').trim();
  if (texto.contains(',')) {
    texto = texto.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(texto) ?? 0;
}

String formatarValor(double valor) =>
    valor.toStringAsFixed(2).replaceAll('.', ',');

final mesParaReceber =
    int.tryParse((mensalidade['mes'] ?? '').toString()) ??
        DateTime.now().month;
final prefsDecimoTerceiro = await SharedPreferences.getInstance();
final incluirDecimoTerceiro =
    mesParaReceber == 12 &&
    (prefsDecimoTerceiro.getBool('recibo_decimo_terceiro_dobrado') ?? false);
final valorMensalidadeBase = (mensalidade['valor'] ?? '0,00').toString();
final valorMensalidadeNumero = valorParaNumero(valorMensalidadeBase);
final valorDecimoTerceiroNumero =
    incluirDecimoTerceiro ? valorMensalidadeNumero : 0.0;
final valorTotalRecebido =
    valorMensalidadeNumero + valorDecimoTerceiroNumero;

final confirmarRecebimento = await showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Confirmar recebimento'),
    content: Text(
      incluirDecimoTerceiro
          ? 'Confirma o recebimento?\n\n'
              'Mensalidade: R\$ ${formatarValor(valorMensalidadeNumero)}\n'
              'Décimo terceiro: R\$ ${formatarValor(valorDecimoTerceiroNumero)}\n'
              'Total: R\$ ${formatarValor(valorTotalRecebido)}'
          : 'Confirma o recebimento desta mensalidade?',
    ),
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

final agora = DateTime.now();
mensalidade['dataRecebimento'] =
    '${agora.day.toString().padLeft(2, '0')}/'
    '${agora.month.toString().padLeft(2, '0')}/'
    '${agora.year}';

mensalidade['status'] = 'recebida';
                                      mensalidade['valorDecimoTerceiro'] =
    incluirDecimoTerceiro
        ? formatarValor(valorDecimoTerceiroNumero)
        : '0,00';

mensalidade['valorTotalRecebido'] =
    formatarValor(valorTotalRecebido);
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

  final dadosCliente = _dadosClienteParaRecibo(mensalidade);

final sucesso = await ImpressoraBluetoothService.imprimirRecibo(
  nomeMorador: (mensalidade['nome'] ?? 'Cliente').toString(),
  valor: (mensalidade['valor'] ?? '0,00').toString(),
  formaPagamento:
      (mensalidade['formaPagamento'] ?? 'Não informado').toString(),
  vencimento: vencimento,
  dataRecebimento: dataRecebimento,
  bairroCliente: dadosCliente['bairro'] ?? '',
  ruaCliente: (mensalidade['rua'] ?? '').toString(),
  numeroCliente: (mensalidade['numero'] ?? '').toString(),
  contatoCliente: dadosCliente['contato'] ?? '',
  documentoCliente: dadosCliente['documento'] ?? '',
      valorDecimoTerceiro:
      (mensalidade['valorDecimoTerceiro'] ?? '0,00').toString(),
  valorTotalRecebido:
      (mensalidade['valorTotalRecebido'] ?? '').toString(),
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

            final dadosCliente = _dadosClienteParaRecibo(mensalidade);

final sucesso = await ImpressoraBluetoothService.imprimirRecibo(
  nomeMorador: (mensalidade['nome'] ?? 'Cliente').toString(),
  valor: (mensalidade['valor'] ?? '0,00').toString(),
  formaPagamento:
      (mensalidade['formaPagamento'] ?? 'Não informado').toString(),
  vencimento: vencimento,
  dataRecebimento: dataRecebimento,
  bairroCliente: dadosCliente['bairro'] ?? '',
  ruaCliente: (mensalidade['rua'] ?? '').toString(),
  numeroCliente: (mensalidade['numero'] ?? '').toString(),
  contatoCliente: dadosCliente['contato'] ?? '',
  documentoCliente: dadosCliente['documento'] ?? '',
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

            final dadosCliente = _dadosClienteParaRecibo(mensalidade);

final sucesso = await ImpressoraBluetoothService.imprimirRecibo(
  nomeMorador: (mensalidade['nome'] ?? 'Cliente').toString(),
  valor: (mensalidade['valor'] ?? '0,00').toString(),
  formaPagamento:
      (mensalidade['formaPagamento'] ?? 'Não informado').toString(),
  vencimento: vencimento,
  dataRecebimento: dataRecebimento,
      bairroCliente:
        (dadosCliente['bairro'] ?? mensalidade['bairro'] ?? '').toString(),
    ruaCliente:
        (dadosCliente['rua'] ?? mensalidade['rua'] ?? '').toString(),
    numeroCliente:
        (dadosCliente['numero'] ?? mensalidade['numero'] ?? '').toString(),
    contatoCliente: (dadosCliente['contato'] ?? '').toString(),
    documentoCliente: (dadosCliente['documento'] ?? '').toString(),
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
      '${selecionados.length} mensalidade(s) criada(s).'
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
                Future<void> _excluirMensalidadesSelecionadas() async {
  final quantidade = _mensalidadesSelecionadas.length;
  if (quantidade == 0) return;

  final confirmado = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Excluir mensalidades?'),
      content: Text(
        'Deseja excluir as $quantidade mensalidades selecionadas?',
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

  widget.store.mensalidades.removeWhere(
    (mensalidade) => _mensalidadesSelecionadas.contains(mensalidade),
  );

  await widget.store.salvarMensalidades();

  if (!mounted) return;

  setState(() {
    _mensalidadesSelecionadas.clear();
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$quantidade mensalidades excluídas.'),
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
    double converterValor(String valor) {
    var texto = valor.replaceAll('R\$', '').trim();
    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(texto) ?? 0.0;
  }

  String formatarValor(double valor) =>
      valor.toStringAsFixed(2).replaceAll('.', ',');

  final mesEdicao =
    int.tryParse((mensalidade['mes'] ?? '').toString()) ?? 0;

final valorBaseAntes = converterValor(
  (mensalidade['valor'] ?? '0,00').toString(),
);

final incluirDecimoNaEdicao =
    mesEdicao == 12 &&
    _decimoTerceiroDobrado &&
    mensalidade['incluirDecimoTerceiro'] != false;

String novoValor = formatarValor(
  incluirDecimoNaEdicao ? valorBaseAntes * 2 : valorBaseAntes,
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
          TextFormField(
            initialValue: novoValor,
            onChanged: (valor) => novoValor = valor,
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

  if (salvou != true) return;

  novoValor = novoValor.trim();
if (novoValor.isEmpty) return;

final valorDigitado = converterValor(novoValor);

if (incluirDecimoNaEdicao && valorDigitado == valorBaseAntes) {
  mensalidade['incluirDecimoTerceiro'] = false;
  mensalidade['valor'] = formatarValor(valorDigitado);
} else if (incluirDecimoNaEdicao) {
  mensalidade['valor'] = formatarValor(valorDigitado / 2);
} else {
  mensalidade['valor'] = formatarValor(valorDigitado);
}

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
    String _formatarReais(double valor) {
  final partes = valor.toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'R\$ $inteiro,${partes[1]}';
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
      Future<List<Map<String, String>>> _lerClientesPdfComPosicoes(
    String caminho,
  ) async {
    await pdfrx.pdfrxFlutterInitialize();
final documento = await pdfrx.PdfDocument.openFile(caminho);
    final clientes = <Map<String, String>>[];
    Map<String, String> clienteAtual = <String, String>{};

    String normalizarTexto(String valor) => valor
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');

    String? campoDoCabecalho(String texto) {
      final valor = normalizarTexto(texto);
      if (valor.contains('bairro')) return 'bairro';
      if (valor.contains('endereco') || valor.contains('rua')) {
        return 'endereco';
      }
      if (valor.contains('numero') || valor == 'nº' || valor == 'n°') {
        return 'numero';
      }
      if (valor == 'dia' || valor.contains('vencimento')) return 'dia';
      if (valor.contains('valor') ||
          valor.contains('mensalidade') ||
          valor.contains(r'$')) {
        return 'valor';
      }
      if (valor.contains('nome') || valor == 'cliente') return 'nome';
      if (valor.contains('telefone') ||
          valor.contains('contato') ||
          valor.contains('whatsapp') ||
          valor.contains('celular')) {
        return 'telefone';
      }
      if (valor.contains('forma') || valor.contains('pagamento')) {
        return 'formaPagamento';
      }
      return null;
    }

    Map<String, String>? montarClienteImportado(
      Map<String, String> campos,
    ) {
      final nome = (campos['nome'] ?? '').trim();
      final bairro = (campos['bairro'] ?? '').trim();
      var endereco = (campos['endereco'] ?? '').trim();
      var numero = (campos['numero'] ?? '').trim();
                  var diaTexto =
          (campos['dia'] ?? '').replaceAll(RegExp(r'\D'), '');

      if (diaTexto.length > 2) {
        final numeroEDia =
            RegExp(r'^(\d+)(0?[1-9]|[12]\d|3[01])$')
                .firstMatch(diaTexto);

        if (numeroEDia != null) {
          if (numero.isEmpty) {
            numero = numeroEDia.group(1)!;
          }
          diaTexto = numeroEDia.group(2)!;
        }
      }

      final diaLido = int.tryParse(diaTexto);
      final dia = diaLido != null && diaLido >= 1 && diaLido <= 31
          ? diaLido
          : null;
      final valor = (campos['valor'] ?? '')
          .replaceAll('R\$', '')
          .replaceAll(' ', '')
          .trim();
      final telefone =
          (campos['telefone'] ?? '').replaceAll(RegExp(r'\D'), '');
      final forma = (campos['formaPagamento'] ?? '').trim();
              final textoImportado = normalizarTexto(campos.values.join(' '));
      final linhaDoPdfNaoECliente =
          textoImportado.contains('total de moradores') ||
          RegExp(r'\bdata\s*:\s*\d{1,2}/\d{1,2}/\d{4}\b')
              .hasMatch(textoImportado) ||
          RegExp(r'\bhora\s*:\s*\d{1,2}:\d{2}\b')
              .hasMatch(textoImportado) ||
          RegExp(r'\bvalor\s*:\s*r?\$?\s*[\d.,]+')
              .hasMatch(textoImportado);

      if (linhaDoPdfNaoECliente) return null;

      if (numero.isEmpty) {
        final encontrado =
            RegExp(r'(?:,|\s)\s*(\d+[A-Za-z]?)\s*$').firstMatch(endereco);
        if (encontrado != null) {
          numero = encontrado.group(1) ?? '';
          endereco = endereco.substring(0, encontrado.start).trim();
        }
      }

            

      return <String, String>{
        'nome': nome,
        'bairro': bairro,
        'rua': endereco,
        'numero': numero,
        'complemento': '',
        'dia': dia == null ? '' : dia.toString().padLeft(2, '0'),
        'valor': valor.isEmpty ? '0,00' : valor,
        'formaPagamento': forma.isEmpty ? 'Não informado' : forma,
        'telefone': telefone.length >= 10 ? telefone : '',
        'contato2Nome': '',
        'contato2Telefone': '',
        'contato2Relacao': '',
        'ativo': 'true',
      };
    }

    void salvarClienteAtual() {
      final cliente = montarClienteImportado(clienteAtual);
      if (cliente != null) clientes.add(cliente);
      clienteAtual = <String, String>{};
    }

    try {
              Map<String, double>? colunasAnteriores;
      for (final pagina in documento.pages) {
        final textoPagina = await pagina.loadStructuredText();
        final linhas = <Map<String, dynamic>>[];

        for (final fragmento in textoPagina.fragments) {
          if (fragmento.text.trim().isEmpty) continue;
          final y = fragmento.bounds.center.y;
          Map<String, dynamic>? linha;

                    double menorDiferencaY = double.infinity;

          for (final candidata in linhas) {
            final fragmentosDaLinha =
                candidata['fragmentos'] as List<dynamic>;

                        final mesmaLinha = fragmentosDaLinha.any((existente) {
  final centroExistente = existente.bounds.center.y;
  final metadeAlturaExistente = existente.bounds.height / 2;
  final metadeAlturaNova = fragmento.bounds.height / 2;

  final topoExistente =
      centroExistente - metadeAlturaExistente;
  final baseExistente =
      centroExistente + metadeAlturaExistente;
  final topoNovo = y - metadeAlturaNova;
  final baseNovo = y + metadeAlturaNova;

  return topoNovo < baseExistente &&
      topoExistente < baseNovo;
});

            if (mesmaLinha) {
              final diferencaY =
                  (y - (candidata['y'] as double)).abs();

              if (diferencaY < menorDiferencaY) {
                menorDiferencaY = diferencaY;
                linha = candidata;
              }
            }
          }
            if (linha == null) {
            linha = <String, dynamic>{
              'y': y,
              'fragmentos': <dynamic>[],
            };
            linhas.add(linha);
          }

          (linha['fragmentos'] as List<dynamic>).add(fragmento);
        }

        linhas.sort(
          (a, b) => (b['y'] as double).compareTo(a['y'] as double),
        );

        Map<String, double>? colunas;
        double yCabecalho = 0;

        for (final linha in linhas) {
          final achadas = <String, double>{};

          for (final fragmento in linha['fragmentos'] as List<dynamic>) {
            final campo = campoDoCabecalho(fragmento.text);
            if (campo != null) {
              achadas.putIfAbsent(
                campo,
                () => fragmento.bounds.center.x,
              );
            }
          }

          if (achadas.length > (colunas?.length ?? 0)) {
            colunas = achadas;
            yCabecalho = linha['y'] as double;
          }
        }

                if (colunas == null ||
            !colunas.containsKey('bairro') ||
            !colunas.containsKey('endereco') ||
            !colunas.containsKey('nome') ||
            !colunas.containsKey('dia') ||
            !colunas.containsKey('valor')) {
          if (colunas == null && colunasAnteriores != null) {
            colunas = colunasAnteriores;
            yCabecalho = double.infinity;
          } else {
            continue;
          }
        } else {
          colunasAnteriores = colunas;
        }

        if (clienteAtual.isNotEmpty) salvarClienteAtual();
          final colunasParaBairro = colunas.entries.toList()
  ..sort((a, b) => a.value.compareTo(b.value));

String? colunaDoFragmento(dynamic fragmento) {
  String? escolhida;
  double menorDistancia = double.infinity;

  for (final coluna in colunasParaBairro) {
    final distancia = (fragmento.bounds.left - coluna.value).abs();
    if (distancia < menorDistancia) {
      menorDistancia = distancia;
      escolhida = coluna.key;
    }
  }

  return escolhida;
}

final yLinhasComCliente = <double>[];

for (final linha in linhas) {
  final y = linha['y'] as double;
  if (y >= yCabecalho - 2.0) continue;

  final fragmentos = linha['fragmentos'] as List<dynamic>;
  final temNome = fragmentos.any(
    (fragmento) =>
        fragmento.text.trim().isNotEmpty &&
        colunaDoFragmento(fragmento) == 'nome',
  );

  if (temNome) yLinhasComCliente.add(y);
}

final bairrosPorCliente = <double, List<String>>{};

for (final linha in linhas) {
  final y = linha['y'] as double;
  if (y >= yCabecalho - 2.0 || yLinhasComCliente.isEmpty) continue;

  final fragmentos = (linha['fragmentos'] as List<dynamic>).toList()
    ..sort((a, b) {
      final diferencaY = b.bounds.center.y.compareTo(a.bounds.center.y);
      if (diferencaY != 0) return diferencaY;
      return a.bounds.left.compareTo(b.bounds.left);
    });

  final textosBairro = fragmentos
      .where((fragmento) => colunaDoFragmento(fragmento) == 'bairro')
      .map((fragmento) => fragmento.text.trim())
      .where((texto) => texto.isNotEmpty)
      .toList();

  if (textosBairro.isEmpty) continue;

  var yClienteMaisProximo = yLinhasComCliente.first;
  var menorDistancia = (y - yClienteMaisProximo).abs();

  for (final yCliente in yLinhasComCliente.skip(1)) {
    final distancia = (y - yCliente).abs();
    if (distancia < menorDistancia) {
      menorDistancia = distancia;
      yClienteMaisProximo = yCliente;
    }
  }

  bairrosPorCliente
      .putIfAbsent(yClienteMaisProximo, () => <String>[])
      .addAll(textosBairro.map((texto) => texto.toString()));
}

        for (final linha in linhas) {
          final y = linha['y'] as double;
          if (y >= yCabecalho - 2.0) continue;

          final fragmentos = linha['fragmentos'] as List<dynamic>
                        ..sort((a, b) {
              final diferencaY =
                  b.bounds.center.y.compareTo(a.bounds.center.y);
              if (diferencaY != 0) return diferencaY;
              return a.bounds.left.compareTo(b.bounds.left);
            });

          final camposDaLinha = <String, List<String>>{};

        

          final colunasOrdenadasPorX = colunas.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value));

                    for (final fragmento in fragmentos) {
            final inicioTexto = fragmento.bounds.left;
            String? colunaEscolhida;
            double menorDistancia = double.infinity;

            for (final coluna in colunasOrdenadasPorX) {
              final distancia = (inicioTexto - coluna.value).abs();

              if (distancia < menorDistancia) {
                menorDistancia = distancia;
                colunaEscolhida = coluna.key;
              }
            }

            if (colunaEscolhida == null) continue;

            final textoFragmento = fragmento.text.trim();
            final ehNumero = RegExp(r'^\d+$').hasMatch(textoFragmento);

            final indiceEndereco = colunasOrdenadasPorX.indexWhere(
              (coluna) => coluna.key == 'endereco',
            );
            final indiceDia = colunasOrdenadasPorX.indexWhere(
              (coluna) => coluna.key == 'dia',
            );

            if (ehNumero &&
                (colunaEscolhida == 'endereco' ||
                    colunaEscolhida == 'dia') &&
                indiceEndereco >= 0 &&
                indiceDia == indiceEndereco + 1) {
              final xEndereco =
                  colunasOrdenadasPorX[indiceEndereco].value;
              final xDia = colunasOrdenadasPorX[indiceDia].value;
              final limiteEnderecoDia = (xEndereco + xDia) / 2;
              final esquerda = fragmento.bounds.left;
              final direita = fragmento.bounds.right;

              if (esquerda < limiteEnderecoDia &&
                  direita > limiteEnderecoDia) {
                final larguraEndereco = limiteEnderecoDia - esquerda;
                final larguraDia = direita - limiteEnderecoDia;

                colunaEscolhida =
                    larguraDia > larguraEndereco ? 'dia' : 'endereco';
              }
            }

            camposDaLinha
                .putIfAbsent(colunaEscolhida, () => <String>[])
                .add(textoFragmento);
          }

                                       final nomeNaLinha =
              (camposDaLinha['nome'] ?? const <String>[])
                  .join(' ')
                  .trim();

                    final nomeAtual =
              (clienteAtual['nome'] ?? '').trim();

          final inicioNovoCliente =
              nomeNaLinha.isNotEmpty && nomeAtual.isNotEmpty;

          if (inicioNovoCliente) {
            salvarClienteAtual();
          }


                    final bairroDoCliente = bairrosPorCliente[y];
          if (bairroDoCliente != null && bairroDoCliente.isNotEmpty) {
            clienteAtual['bairro'] = bairroDoCliente.join(' ').trim();
          }

          for (final campo in camposDaLinha.entries) {
            if (campo.key == 'bairro') continue;

            final texto = campo.value.join(' ').trim();
            if (texto.isEmpty) continue;

            final anterior = clienteAtual[campo.key] ?? '';
clienteAtual[campo.key] =
    anterior.isEmpty ? texto : '$anterior $texto';
          }
        }
      }

      if (clienteAtual.isNotEmpty) salvarClienteAtual();
    } finally {
      await documento.dispose();
    }

        return clientes;
      }
List<Map<String, String>> _lerClientesDoPdf(String texto) {
  final clientesLidos = <Map<String, String>>[];
  Map<String, int> indices = {};

  String normalizar(String valor) => valor.trim().toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c');

  String? identificarCampo(String titulo) {
    final t = normalizar(titulo);
    if (t.contains('nome') || t == 'cliente') return 'nome';
    if (t.contains('bairro')) return 'bairro';
    if (t.contains('numero') ||
    RegExp(r'^n[º°.]?$').hasMatch(t)) return 'numero';
    if (t.contains('endereco') || t.contains('rua')) return 'endereco';
    if (t == 'dia' || t.contains('vencimento')) return 'dia';
    if (t.contains('valor') ||
    t.contains('mensalidade') ||
    t == r'$') return 'valor';
    if (t.contains('telefone') ||
        t.contains('contato') ||
        t.contains('whatsapp') ||
        t.contains('celular')) return 'telefone';
    if (t.contains('forma') || t.contains('pagamento')) {
      return 'formaPagamento';
    }
    return null;
  }

  List<String> separarColunas(String linha) {
    final separador = RegExp(r'\t+| {2,}|[|;]');
    if (!separador.hasMatch(linha)) return [];
    return linha
        .split(separador)
        .map((coluna) => coluna.trim())
        .where((coluna) => coluna.isNotEmpty)
        .toList();
  }

  Map<String, String>? montarCliente(Map<String, String> campos) {
    final nome = (campos['nome'] ?? '').trim();
    final bairro = (campos['bairro'] ?? '').trim();
    var endereco = (campos['endereco'] ?? '').trim();
    var numero = (campos['numero'] ?? '').trim();

    final diaTexto = (campos['dia'] ?? '').replaceAll(RegExp(r'\D'), '');
    final dia = int.tryParse(diaTexto);
    final valor = (campos['valor'] ?? '')
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .trim();
    final telefone =
        (campos['telefone'] ?? '').replaceAll(RegExp(r'\D'), '');
    final forma = (campos['formaPagamento'] ?? '').trim();

    if (numero.isEmpty) {
      final encontrado =
          RegExp(r'(?:,|\s)\s*(\d+[A-Za-z]?)\s*$').firstMatch(endereco);
      if (encontrado != null) {
        numero = encontrado.group(1) ?? '';
        endereco = endereco.substring(0, encontrado.start).trim();
      }
    }

    if (nome.isEmpty ||
        bairro.isEmpty ||
        endereco.isEmpty ||
        numero.isEmpty) {
      return null;
    }
    if (dia != null && (dia < 1 || dia > 31)) return null;

    return {
      'nome': nome,
      'bairro': bairro,
      'rua': endereco,
      'numero': numero,
      'complemento': '',
      'dia': dia == null ? '' : dia.toString().padLeft(2, '0'),
      'valor': valor.isEmpty ? '0,00' : valor,
      'formaPagamento': forma.isEmpty ? 'Não informado' : forma,
      'telefone': telefone.length >= 10 ? telefone : '',
      'contato2Nome': '',
      'contato2Telefone': '',
      'contato2Relacao': '',
      'ativo': 'true',
    };
  }

  Map<String, String>? lerLinhaRotulada(String linha) {
    final rotulos = <Map<String, dynamic>>[];
    const expressoes = <String, String>{
      'nome': r'nome\s+do\s+cliente|nome|cliente',
      'bairro': r'bairro',
      'endereco': r'endereco|rua',
      'numero': r'numero|n[º°.]',
      'dia': r'dia|vencimento',
      'valor': r'valor|mensalidade',
      'telefone': r'telefone|contato|whatsapp|celular',
      'formaPagamento': r'forma\s+de\s+pagamento|pagamento',
    };

    for (final item in expressoes.entries) {
      final regex = RegExp(
        r'(?:^|[|;]\s*|\s)(' +
            item.value +
            r')\s*[:=]\s*',
        caseSensitive: false,
      );
      for (final match in regex.allMatches(linha)) {
        rotulos.add({
          'campo': item.key,
          'inicio': match.start,
          'fim': match.end,
        });
      }
    }

    if (rotulos.length < 3) return null;
    rotulos.sort(
      (a, b) => (a['inicio'] as int).compareTo(b['inicio'] as int),
    );

    final campos = <String, String>{};
    for (var i = 0; i < rotulos.length; i++) {
      final atual = rotulos[i];
      final fim = i + 1 < rotulos.length
          ? rotulos[i + 1]['inicio'] as int
          : linha.length;
      campos[atual['campo'] as String] = linha
          .substring(atual['fim'] as int, fim)
          .replaceAll(RegExp(r'^[|;,\s]+|[|;,\s]+$'), '')
          .trim();
    }

    return montarCliente(campos);
  }
Map<String, String> camposVerticais = <String, String>{};

void salvarClienteVertical() {
  final cliente = montarCliente(camposVerticais);
  if (cliente != null) {
    clientesLidos.add(cliente);
  }
  camposVerticais = <String, String>{};
}

final rotuloVertical = RegExp(
  r'^\s*(nome\s+do\s+cliente|nome|cliente|bairro|endere[cç]o|rua|numero|n[º°.]?|dia|vencimento|valor|mensalidade|telefone|contato|whatsapp|celular|forma\s+de\s+pagamento|pagamento)\s*[:=]\s*(.*?)\s*$',
  caseSensitive: false,
);

for (final original in texto.split(RegExp(r'[\r\n]+'))) {
  final linha = original.trim();
  if (linha.isEmpty) continue;

  final rotulo = rotuloVertical.firstMatch(linha);
  if (rotulo == null) continue;

  final campo = identificarCampo(rotulo.group(1) ?? '');
  if (campo == null) continue;

  if (campo == 'nome' && camposVerticais.containsKey('nome')) {
    salvarClienteVertical();
  }

  camposVerticais[campo] = (rotulo.group(2) ?? '').trim();
}

salvarClienteVertical();
  for (final original in texto.split(RegExp(r'[\r\n]+'))) {
    final linha = original.trim();
    if (linha.isEmpty) continue;

    final rotulado = lerLinhaRotulada(linha);
    if (rotulado != null) {
      clientesLidos.add(rotulado);
      continue;
    }

    final colunas = separarColunas(linha);
    if (colunas.length < 2) continue;

    final novosIndices = <String, int>{};
    for (var i = 0; i < colunas.length; i++) {
      final campo = identificarCampo(colunas[i]);
      if (campo != null) novosIndices[campo] = i;
    }

    final temCabecalho = novosIndices.containsKey('nome') &&
        novosIndices.containsKey('bairro') &&
        novosIndices.containsKey('endereco') &&
        novosIndices.containsKey('valor');

    if (temCabecalho) {
      indices = novosIndices;
      continue;
    }

    final campos = <String, String>{};

        if (indices.isNotEmpty) {
      for (final item in indices.entries) {
        if (item.value < colunas.length) {
          campos[item.key] = colunas[item.value];
        }
      }
        }

    final cliente = montarCliente(campos);
    if (cliente != null) clientesLidos.add(cliente);
  }

  final unicos = <String, Map<String, String>>{};
  for (final cliente in clientesLidos) {
    final chave = [
      cliente['nome'],
      cliente['bairro'],
      cliente['rua'],
      cliente['numero'],
    ].map((valor) => (valor ?? '').trim().toLowerCase()).join('|');
    unicos.putIfAbsent(chave, () => cliente);
  }

  return unicos.values.toList();
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
  actions: [
    IconButton(
  tooltip: 'Importar clientes',
  icon: const Icon(Icons.file_upload_outlined),
    onPressed: () async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (resultado == null || resultado.files.isEmpty || !mounted) {
      return;
    }

    final arquivo = resultado.files.single;

        try {
      final caminho = arquivo.path;

      if (caminho == null || caminho.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir esse arquivo PDF.'),
          ),
        );
        return;
      }

      final clientesEncontrados =
    await _lerClientesPdfComPosicoes(caminho);

if (!mounted) return;

if (clientesEncontrados.isEmpty) {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Diagnóstico da importação'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: const SelectableText(
  'Não encontrei clientes neste PDF. Confira se ele foi gerado pelo app.',
),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  return;
}

final confirmouImportacao = await showDialog<bool>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Importar clientes'),
    content: Text(
      'Encontrei ${clientesEncontrados.length} cliente(s). '
      'A forma de pagamento ficará como “Não informado” '
      'e poderá ser atualizada depois. Quer importar?',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(dialogContext, true),
        child: const Text('Importar'),
      ),
    ],
  ),
);

if (confirmouImportacao != true || !mounted) return;

var importados = 0;
var duplicados = 0;

String normalizar(Object? valor) =>
    (valor ?? '').toString().trim().toLowerCase();

for (final cliente in clientesEncontrados) {
  final nomeBairro = (cliente['bairro'] ?? '').trim();
  final nomeRua = (cliente['rua'] ?? '').trim();

  if (nomeBairro.isNotEmpty) {
    Bairro? bairroCadastrado;

    for (final bairro in widget.store.bairros) {
      if (normalizar(bairro.nome) == normalizar(nomeBairro)) {
        bairroCadastrado = bairro;
        break;
      }
    }

    if (bairroCadastrado == null) {
      await widget.store.adicionarBairro(nomeBairro);

      for (final bairro in widget.store.bairros) {
        if (normalizar(bairro.nome) == normalizar(nomeBairro)) {
          bairroCadastrado = bairro;
          break;
        }
      }
    }

    if (bairroCadastrado != null && nomeRua.isNotEmpty) {
      await widget.store.adicionarRua(bairroCadastrado, nomeRua);
    }
  }

  widget.store.clientes.add(cliente);
  importados++;
}

if (importados > 0) {
  await widget.store.salvarClientes();
}

if (!mounted) return;

setState(() {});

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      '$importados cliente(s) importado(s); '
      '$duplicados duplicado(s) ignorado(s).',
    ),
  ),
);
      } catch (erro) {
  if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível ler esse PDF.'),
        ),
      );
        }
  },
),
  ],
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
            isExpanded: true,
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
                child: Text(
  bairro.nome,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
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
            isExpanded: true,
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
                child: Text(
  rua,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
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
      'Valor: R\$ ${cliente['valor'] ?? '0,00'}',
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
                
class TelaRelatorio extends StatefulWidget {
  final AppStore? store;

  const TelaRelatorio({super.key, this.store});

  @override
  State<TelaRelatorio> createState() => _TelaRelatorioState();
}

class _TelaRelatorioState extends State<TelaRelatorio> {
  int mesSelecionado = DateTime.now().month;
  int anoSelecionado = DateTime.now().year;

  static const meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril',
    'Maio', 'Junho', 'Julho', 'Agosto',
    'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  double _valor(Object? valor) {
    var texto = (valor ?? '0').toString()
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .trim();

    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(texto) ?? 0;
  }

  String _reais(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  Widget _cartao(String titulo, double valor, IconData icone) {
    return Card(
      child: ListTile(
        leading: Icon(icone),
        title: Text(titulo),
        trailing: Text(
          _reais(valor),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  Widget _graficoBalanco(double recebido, double pendente) {
    final total = recebido + pendente;
    final percentual = total == 0 ? 0.0 : recebido / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Balanço do mês',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: percentual,
                    strokeWidth: 16,
                    backgroundColor: Colors.orange.shade200,
                    color: Colors.green,
                  ),
                  Text(
                    '${(percentual * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('Recebido: ${_reais(recebido)}'),
                Text('Pendente: ${_reais(pendente)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
      Widget _crescimentoAnual(Iterable<dynamic> mensalidades, int ano) {
    double totalRecebido(int anoComparado) {
      var total = 0.0;

      for (final item in mensalidades) {
        final anoItem =
            int.tryParse((item['ano'] ?? '').toString()) ?? 0;
        final status =
            (item['status'] ?? '').toString().toLowerCase();

        if (anoItem == anoComparado && status.contains('recebid')) {
          total += _valor(item['valor']);
        }
      }

      return total;
    }

    final recebidoAtual = totalRecebido(ano);
    final recebidoAnterior = totalRecebido(ano - 1);
    final temComparacao = recebidoAnterior > 0;

    final variacao = temComparacao
        ? ((recebidoAtual - recebidoAnterior) / recebidoAnterior) * 100
        : 0.0;

    final cor = !temComparacao
        ? Colors.blue
        : variacao >= 0
            ? Colors.green
            : Colors.red;

    return Card(
      child: ListTile(
        leading: Icon(
          !temComparacao
              ? Icons.info_outline
              : variacao >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
          color: cor,
        ),
        title: const Text('Crescimento anual recebido'),
        subtitle: Text(
          '$ano: ${_reais(recebidoAtual)} | '
          '${ano - 1}: ${_reais(recebidoAnterior)}',
        ),
        trailing: Text(
          temComparacao
              ? '${variacao >= 0 ? '+' : ''}'
                  '${variacao.toStringAsFixed(1)}%'
              : 'Sem base',
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
      }
      Widget _comparativoMensal(Iterable<dynamic> mensalidades, int ano) {
  final totais = List<double>.filled(12, 0.0);

  for (final item in mensalidades) {
    final anoItem =
        int.tryParse((item['ano'] ?? '').toString()) ?? 0;
    final mes =
        int.tryParse((item['mes'] ?? '').toString()) ?? 0;
    final status =
        (item['status'] ?? '').toString().toLowerCase();

    if (anoItem == ano &&
        mes >= 1 &&
        mes <= 12 &&
        status.contains('recebid')) {
      totais[mes - 1] += _valor(item['valor']);
    }
  }

  final maior = totais.reduce((a, b) => a > b ? a : b);

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recebido por mês - $ano',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(12, (i) {
            final valor = totais[i];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(meses[i].substring(0, 3)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: maior == 0 ? 0 : valor / maior,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 88,
                    child: Text(
                      _reais(valor),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final mensalidades = widget.store?.mensalidades ?? [];

    final doMes = mensalidades.where((item) {
      final mes = int.tryParse((item['mes'] ?? '').toString()) ?? 0;
      final ano = int.tryParse((item['ano'] ?? '').toString()) ?? 0;
      final status = (item['status'] ?? '').toString().toLowerCase();

      return mes == mesSelecionado &&
          ano == anoSelecionado &&
          !status.contains('inativo');
    }).toList();

    double recebido = 0;
    double pendente = 0;
    double pix = 0;
    double dinheiro = 0;
    double cartao = 0;

    for (final item in doMes) {
      final valor = _valor(item['valor']);
      final status = (item['status'] ?? '').toString().toLowerCase();
      final forma =
          (item['formaPagamento'] ?? '').toString().toLowerCase();

      if (status.contains('recebid')) {
        recebido += valor;

        if (forma.contains('pix')) pix += valor;
        if (forma.contains('dinheiro')) dinheiro += valor;
        if (forma.contains('cartão') || forma.contains('cartao')) {
          cartao += valor;
        }
      } else if (status.contains('pendente')) {
        pendente += valor;
      }
    }

    final anos = <int>{
      DateTime.now().year,
      ...mensalidades.map(
        (item) => int.tryParse((item['ano'] ?? '').toString()) ?? 0,
      ),
    }..remove(0);

    final listaAnos = anos.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relatório',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: mesSelecionado,
                  decoration: const InputDecoration(labelText: 'Mês'),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(meses[i]),
                    ),
                  ),
                  onChanged: (valor) {
                    if (valor != null) {
                      setState(() => mesSelecionado = valor);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: listaAnos.contains(anoSelecionado)
                      ? anoSelecionado
                      : DateTime.now().year,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  items: listaAnos
                      .map((ano) => DropdownMenuItem(
                            value: ano,
                            child: Text(ano.toString()),
                          ))
                      .toList(),
                  onChanged: (valor) {
                    if (valor != null) {
                      setState(() => anoSelecionado = valor);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _cartao('Total do mês', recebido + pendente, Icons.account_balance),
          _cartao('Recebido', recebido, Icons.check_circle_outline),
          _cartao('Pendente', pendente, Icons.pending_actions),
          const SizedBox(height: 8),
          const Text(
            'Recebido por forma de pagamento',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          _cartao('Pix', pix, Icons.pix),
          _cartao('Dinheiro', dinheiro, Icons.money),
          _cartao('Cartão', cartao, Icons.credit_card),
            _GraficoPizzaRecebidos(
  pix: pix,
  dinheiro: dinheiro,
  cartao: cartao,
),
            _graficoBalanco(recebido, pendente),
            _comparativoMensal(mensalidades, anoSelecionado),
            _crescimentoAnual(mensalidades, anoSelecionado),
        ],
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
  leading: const Icon(Icons.backup_outlined),
  title: const Text('Backup dos clientes'),
  subtitle: const Text('Salvar ou restaurar os cadastros'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        Future<void> fazerBackup() async {
          Navigator.pop(dialogContext);

          try {
            await widget.store.carregarClientes();

            final agora = DateTime.now();
            final data =
                '${agora.year}${agora.month.toString().padLeft(2, '0')}'
                '${agora.day.toString().padLeft(2, '0')}';
            final nomeArquivo = 'backup_clientes_$data.json';

            final pasta = await Directory.systemTemp.createTemp(
              'vigilante_backup_clientes_',
            );
            final arquivo = File('${pasta.path}/$nomeArquivo');

            await arquivo.writeAsString(
              const JsonEncoder.withIndent('  ').convert({
                'formato': 'vigilante_recibos_clientes_v1',
                'versao': 1,
                'dataBackup': agora.toIso8601String(),
                'clientes': widget.store.clientes,
              }),
              encoding: utf8,
              flush: true,
            );

            await SharePlus.instance.share(
              ShareParams(
                title: 'Backup dos clientes',
                text: 'Backup dos clientes do Vigilante Recibos',
                files: [XFile(arquivo.path, mimeType: 'application/json')],
              ),
            );
          } catch (erro) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Não foi possível fazer o backup: $erro')),
            );
          }
        }

        Future<void> restaurarBackup() async {
          Navigator.pop(dialogContext);

          try {
            final selecionado = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['json'],
              withData: true,
            );

            if (selecionado == null || selecionado.files.isEmpty) return;

            final bytes = selecionado.files.single.bytes;
            if (bytes == null) {
              throw const FormatException('Não foi possível ler o arquivo.');
            }

            final conteudo = jsonDecode(utf8.decode(bytes));
            if (conteudo is! Map ||
                conteudo['formato'] != 'vigilante_recibos_clientes_v1' ||
                conteudo['clientes'] is! List) {
              throw const FormatException('Esse arquivo não é um backup válido.');
            }

            final clientesBackup = <Map<String, String>>[];
            for (final item in conteudo['clientes'] as List) {
              if (item is! Map) {
                throw const FormatException('Há um cadastro inválido no arquivo.');
              }
              clientesBackup.add(
                Map<String, String>.fromEntries(
                  item.entries.map(
                    (entrada) => MapEntry(
                      entrada.key.toString(),
                      entrada.value.toString(),
                    ),
                  ),
                ),
              );
            }

            final confirmou = await showDialog<bool>(
              context: context,
              builder: (confirmContext) => AlertDialog(
                title: const Text('Restaurar backup?'),
                content: Text(
                  'O backup tem ${clientesBackup.length} clientes. '
                  'A restauração substituirá os cadastros atuais.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmContext, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(confirmContext, true),
                    child: const Text('Restaurar'),
                  ),
                ],
              ),
            );

            if (confirmou != true) return;

            widget.store.clientes
              ..clear()
              ..addAll(clientesBackup);
            await widget.store.salvarClientes();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Backup restaurado com sucesso.'),
              ),
            );
          } catch (erro) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Não foi possível restaurar o backup: $erro'),
              ),
            );
          }
        }

        return AlertDialog(
          title: const Text('Backup dos clientes'),
          content: const Text('Escolha uma opção.'),
          actions: [
            TextButton(
              onPressed: fazerBackup,
              child: const Text('Fazer backup'),
            ),
            FilledButton(
              onPressed: restaurarBackup,
              child: const Text('Restaurar backup'),
            ),
          ],
        );
      },
    );
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
                    title: Row(
  children: [
    Expanded(child: Text(bairro.nome)),
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (acao) {
        if (acao == 'editar') _editarBairro(bairro);
        if (acao == 'excluir') _excluirBairro(bairro);
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'editar', child: Text('Editar')),
        PopupMenuItem(value: 'excluir', child: Text('Excluir')),
      ],
    ),
  ],
),
                    subtitle: Text('${bairro.ruas.length} rua(s)'),
                    children: [
                      ...bairro.ruas.map((rua) => ListTile(
  leading: const Icon(Icons.signpost_outlined),
  title: Text(rua),
  trailing: PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    onSelected: (acao) {
      if (acao == 'editar') _editarRua(bairro, rua);
      if (acao == 'excluir') _excluirRua(bairro, rua);
    },
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'editar', child: Text('Editar')),
      PopupMenuItem(value: 'excluir', child: Text('Excluir')),
    ],
  ),
)),
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
    Future<String?> _pedirNome(String titulo, String nomeAtual) async {
  var texto = nomeAtual;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(titulo),
      content: TextFormField(
        initialValue: nomeAtual,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome',
        ),
        onChanged: (valor) => texto = valor.trim(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nome = texto.trim();
            if (nome.isNotEmpty) {
              Navigator.of(dialogContext).pop(nome);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

    Future<void> _editarBairro(Bairro bairro) async {
    final nome = await _pedirNome('Editar bairro', bairro.nome);
    if (nome == null || nome.trim().isEmpty) return;

    final existe = widget.store.bairros.any(
      (item) =>
          item.id != bairro.id &&
          item.nome.trim().toLowerCase() == nome.trim().toLowerCase(),
    );

    if (existe) {
      _aviso('Esse bairro já está cadastrado');
      return;
    }

    bairro.nome = nome.trim();
    await widget.store.salvarBairrosERuas();

    if (!mounted) return;
    setState(() {});
    _aviso('Bairro atualizado');
  }

Future<bool> _confirmarExclusao(String tipo, String nome) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Excluir $tipo?'),
      content: Text('Tem certeza que deseja excluir "$nome"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );

  return confirmou ?? false;
}
    Future<void> _excluirBairro(Bairro bairro) async {
  final confirmou = await _confirmarExclusao('bairro', bairro.nome);
  if (!confirmou) return;

  widget.store.bairros.remove(bairro);
  await widget.store.salvarBairrosERuas();

  if (!mounted) return;
  setState(() {});
  _aviso('Bairro excluído');
}

Future<void> _editarRua(Bairro bairro, String rua) async {
  var textoEditado = rua;

  final nome = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Editar rua'),
      content: TextFormField(
        initialValue: rua,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nome'),
        onChanged: (valor) => textoEditado = valor.trim(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (textoEditado.isNotEmpty) {
              Navigator.of(dialogContext).pop(textoEditado);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );

  if (nome == null || nome.trim().isEmpty) return;

  final nomeFinal = nome.trim();
  final existe = bairro.ruas.any(
    (item) =>
        item.trim().toLowerCase() == nomeFinal.toLowerCase() &&
        item.trim().toLowerCase() != rua.trim().toLowerCase(),
  );

  if (existe) {
    _aviso('Essa rua já está cadastrada neste bairro');
    return;
  }

  final indice = bairro.ruas.indexOf(rua);
  if (indice == -1) return;

  bairro.ruas[indice] = nomeFinal;
  await widget.store.salvarBairrosERuas();

  if (!mounted) return;
  setState(() {});
  _aviso('Rua atualizada');
}

Future<void> _excluirRua(Bairro bairro, String rua) async {
  final confirmou = await _confirmarExclusao('rua', rua);
  if (!confirmou) return;

  bairro.ruas.remove(rua);
  await widget.store.salvarBairrosERuas();

  if (!mounted) return;
  setState(() {});
  _aviso('Rua excluída');
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
    static String _campoPix(String id, String valor) {
  final tamanho = utf8.encode(valor).length.toString().padLeft(2, '0');
  return '$id$tamanho$valor';
}

static String _gerarPixCopiaECola({
  required String chavePix,
    String tipoChavePix = 'Telefone',
  required String nomeVigilante,
  required String valor,
}) {
  String nome = nomeVigilante.trim().toUpperCase();
  nome = nome
      .replaceAll('Á', 'A')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Ã', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ô', 'O')
      .replaceAll('Õ', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ç', 'C')
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), '');

  if (nome.isEmpty) nome = 'VIGILANTE';
  if (nome.length > 25) nome = nome.substring(0, 25);

  final valorNumerico = valor.contains(',')
      ? valor.replaceAll('.', '').replaceAll(',', '.')
      : valor;
  final valorPix =
      (double.tryParse(valorNumerico) ?? 0).toStringAsFixed(2);

  final chave = chavePix.trim();
final contaPix = _campoPix('00', 'br.gov.bcb.pix') +
    _campoPix('01', chave);

  final identificador = _campoPix('05', '***');
  var payload = _campoPix('00', '01') +
      _campoPix('01', '11') +
      _campoPix('26', contaPix) +
      _campoPix('52', '0000') +
      _campoPix('53', '986') +
      _campoPix('54', valorPix) +
      _campoPix('58', 'BR') +
      _campoPix('59', nome) +
      _campoPix('60', 'BRASIL') +
      _campoPix('62', identificador) +
      '6304';

  var crc = 0xFFFF;
  for (final byte in utf8.encode(payload)) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021)
          : (crc << 1);
      crc &= 0xFFFF;
    }
  }

  payload += crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  return payload;
}

      static Future<bool> imprimirRecibo({
    required String nomeMorador,
    required String valor,
    required String formaPagamento,
    required String vencimento,
    required String dataRecebimento,
        String observacao = '',
    String bairroCliente = '',
          String ruaCliente = '',
String numeroCliente = '',
    String contatoCliente = '',
    String documentoCliente = '',
          String valorDecimoTerceiro = '0,00',
String valorTotalRecebido = '',
  }) async {
    final conectado =
        await PrintBluetoothThermal.connectionStatus;

    if (!conectado) {
      return false;
    }

    final valorNumerico = valor.contains(',')
        ? valor.replaceAll('.', '').replaceAll(',', '.')
        : valor;

    final valorFormatado =
        double.tryParse(valorNumerico)
                ?.toStringAsFixed(2)
                .replaceAll('.', ',') ??
            valor;

        final prefsRecibo = await SharedPreferences.getInstance();

    bool mostrarCampo(String chave, bool padrao) =>
        prefsRecibo.getBool('recibo_$chave') ?? padrao;

    final List<String> linhasRecibo = <String>[
  '================================',
  '       VIGILANTE RECIBOS',
  '================================',

];

void adicionarCampo(bool mostrar, String titulo, String texto) {
  final valor = texto.trim();
  if (mostrar && valor.isNotEmpty) {
    linhasRecibo.add('$titulo: $valor');
  }
}

adicionarCampo(
  mostrarCampo('fantasia', true),
  'Empresa',
  prefsRecibo.getString('vigilanteNomeFantasia') ?? '',
);

adicionarCampo(
  mostrarCampo('segmento', true),
  'Segmento',
  prefsRecibo.getString('vigilanteSegmentoMercado') ?? '',
);

final inicioHorario =
    prefsRecibo.getString('vigilanteHorarioInicio') ?? '';
final fimHorario =
    prefsRecibo.getString('vigilanteHorarioFim') ?? '';
final horarios = [
  inicioHorario,
  fimHorario,
].where((horario) => horario.trim().isNotEmpty).join(' às ');

adicionarCampo(
  mostrarCampo('horarios', true),
  'Horário',
  horarios,
);

adicionarCampo(
  mostrarCampo('site', false),
  'Site',
  prefsRecibo.getString('vigilanteSite') ?? '',
);

adicionarCampo(
  mostrarCampo('endereco_vigilante', false),
  'Endereço',
  prefsRecibo.getString('vigilanteEndereco') ?? '',
);

adicionarCampo(
  mostrarCampo('documento_vigilante', false),
  'CPF/CNPJ',
  prefsRecibo.getString('vigilanteCpfCnpj') ?? '',
);
          adicionarCampo(
  mostrarCampo('pix', true),
  'Chave Pix',
  prefsRecibo.getString('vigilanteChavePix') ?? '',
);

linhasRecibo
    ..add('--------------------------------');
  

adicionarCampo(
  mostrarCampo('cliente_nome', true),
  'Cliente',
  nomeMorador,
);
              adicionarCampo(
      mostrarCampo('cliente_bairro', true),
      'Bairro',
      bairroCliente,
    );
          

adicionarCampo(true, 'Rua', ruaCliente);
adicionarCampo(true, 'Número', numeroCliente);

adicionarCampo(
  mostrarCampo('cliente_contato', true),
  'Contato',
  contatoCliente,
);

adicionarCampo(
  mostrarCampo('cliente_documento', false),
  'CPF/CNPJ do cliente',
  documentoCliente,
);

if (mostrarCampo('valor', true)) {
  linhasRecibo.add('Valor: R\$ $valorFormatado');
}

final valorDecimoTexto = valorDecimoTerceiro.trim();
final valorDecimoNumero = valorDecimoTexto.contains(',')
    ? valorDecimoTexto.replaceAll('.', '').replaceAll(',', '.')
    : valorDecimoTexto;
final valorDecimoDouble = double.tryParse(valorDecimoNumero) ?? 0;

if (valorDecimoDouble > 0) {
  final totalFormatado = valorTotalRecebido.trim().isNotEmpty
      ? valorTotalRecebido.trim()
      : ((double.tryParse(valorNumerico) ?? 0) + valorDecimoDouble)
          .toStringAsFixed(2)
          .replaceAll('.', ',');

  linhasRecibo.add('Décimo terceiro: R\$ $valorDecimoTexto');
  linhasRecibo.add('Total recebido: R\$ $totalFormatado');
}

adicionarCampo(
  mostrarCampo('forma_pagamento', true),
  'Forma de pagamento',
  formaPagamento,
);

adicionarCampo(
  mostrarCampo('data_pagamento', true),
  'Data do pagamento',
  dataRecebimento,
);

if (mostrarCampo('vencimento', true)) {
  linhasRecibo.add('Vencimento: $vencimento');
}

adicionarCampo(
  mostrarCampo('observacao', true),
  'Observação',
  observacao,
);






if (mostrarCampo('status', true)) {
  linhasRecibo.add('Status: RECEBIDO');
}
final partesVencimento = vencimento.split('/');
final mesVencimento = partesVencimento.length > 1
    ? int.tryParse(partesVencimento[1])
    : null;

final avisoDecimoTerceiroAtivo =
    prefsRecibo.getBool('recibo_decimo_terceiro_ativo') ?? true;

if (mesVencimento == 11 && avisoDecimoTerceiroAtivo) {
  final mensagemDecimoTerceiro =
      (prefsRecibo.getString('recibo_decimo_terceiro_mensagem') ??
              DecimoTerceiroPersonalizacaoTab.mensagemPadrao)
          .replaceAll('{nome do cliente}', nomeMorador);

  linhasRecibo.addAll(
    mensagemDecimoTerceiro
        .split('\n')
        .map((linha) => linha.trim())
        .where((linha) => linha.isNotEmpty),
  );
}


final caminhoLogoTermico =
    prefsRecibo.getString('vigilanteLogoPretoBranco') ?? '';

try {
  if (mostrarCampo('logo', true) &&
      caminhoLogoTermico.isNotEmpty) {
    final arquivoLogo = File(caminhoLogoTermico);

    if (await arquivoLogo.exists()) {
      final bytesImagem = await arquivoLogo.readAsBytes();
      final imagemLogo = img.decodeImage(bytesImagem);

      if (imagemLogo != null) {
        final perfilLogo = await CapabilityProfile.load();
        final geradorLogo = Generator(PaperSize.mm58, perfilLogo);

        final imagemAjustada = imagemLogo.width > 80
    ? img.copyResize(imagemLogo, width: 80)
    : imagemLogo;

        await PrintBluetoothThermal.writeBytes([
          ...geradorLogo.image(
            imagemAjustada,
            align: PosAlign.center,
          ),
        
        ]);
      }
    }
  }
} catch (_) {
  // Se o logo falhar, continua para imprimir o texto do recibo.
}
const Map<String, String> mapaAcentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'Á': 'A', 'À': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
  'ç': 'c', 'Ç': 'C',
};

final textoRecibo = linhasRecibo.join('\n');
final recibo = textoRecibo
    .split('')
    .map((caractere) => mapaAcentos[caractere] ?? caractere)
    .join()
    .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
          final perfilRecibo = await CapabilityProfile.load();
final geradorRecibo = Generator(PaperSize.mm58, perfilRecibo);
final bytesRecibo = <int>[
  ...geradorRecibo.setGlobalCodeTable('CP1252'),
  ...geradorRecibo.text(recibo),
];
final resultado =
    await PrintBluetoothThermal.writeBytes(bytesRecibo);

final chavePixOriginal =
    prefsRecibo.getString('vigilanteChavePix') ?? '';
final tipoChavePixSalvo =
    prefsRecibo.getString('vigilanteTipoChavePix') ?? 'Telefone';

final String chavePixQr;
if (chavePixOriginal.trim().isEmpty) {
  chavePixQr = '';
} else if (tipoChavePixSalvo == 'Telefone') {
  final numeros = chavePixOriginal.replaceAll(RegExp(r'\D'), '');

  if ((numeros.length == 12 || numeros.length == 13) &&
      numeros.startsWith('55')) {
    chavePixQr = '+$numeros';
  } else if (numeros.length == 10 || numeros.length == 11) {
    chavePixQr = '+55$numeros';
  } else {
    chavePixQr = chavePixOriginal.trim();
  }
} else if (tipoChavePixSalvo == 'CPF/CNPJ') {
  chavePixQr =
      chavePixOriginal.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
} else {
  chavePixQr = chavePixOriginal.trim();
}

final modoQrTermico =
    prefsRecibo.getString('recibo_modo_qr') ?? 'pendente';
final mostrarQrTermico = modoQrTermico == 'sempre';

if (mostrarQrTermico &&
    mostrarCampo('pix', true) &&
    chavePixQr.trim().isNotEmpty) {
  final pixCopiaECola =
      ImpressoraBluetoothService._gerarPixCopiaECola(
    chavePix: chavePixQr,
    nomeVigilante:
        prefsRecibo.getString('vigilanteNomeFantasia') ?? 'VIGILANTE',
    valor: valorFormatado,
  );

  final perfilQr = await CapabilityProfile.load();
  final geradorQr = Generator(PaperSize.mm58, perfilQr);

  final bytesQr = <int>[
    ...geradorQr.text(
      'PAGUE COM PIX',
      styles: PosStyles(align: PosAlign.center, bold: true),
    ),
    ...geradorQr.qrcode(pixCopiaECola),
          ...geradorQr.feed(4),
    
  ];

  await PrintBluetoothThermal.writeBytes(bytesQr);
}



return resultado;
  }
}
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

  final Map<String, bool> _camposPadrao = {
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
    'cliente_rua': true,
    'cliente_numero': true,
    'cliente_documento': false,
    'data_pagamento': true,
    'valor': true,
    'forma_pagamento': true,
    'vencimento': true,
    'status': true,
    'observacao': true,
  };

  late final Map<String, bool> _camposTermico =
      Map<String, bool>.from(_camposPadrao);
  late final Map<String, bool> _camposWhatsapp =
      Map<String, bool>.from(_camposPadrao);

  String _modoQrTermico = 'pendente';
  String _modoQrWhatsapp = 'pendente';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

  Future<void> _carregarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();

    for (final chave in _camposPadrao.keys) {
      final valorTermico =
          prefs.getBool('recibo_$chave') ?? _camposPadrao[chave]!;

      _camposTermico[chave] = valorTermico;
      _camposWhatsapp[chave] =
          prefs.getBool('recibo_whatsapp_$chave') ?? valorTermico;

      if (!prefs.containsKey('recibo_whatsapp_$chave')) {
        await prefs.setBool('recibo_whatsapp_$chave', valorTermico);
      }
    }

    final modoTermico = prefs.getString('recibo_modo_qr') ?? 'pendente';
    final modoWhatsapp =
        prefs.getString('recibo_whatsapp_modo_qr') ?? modoTermico;

    if (!prefs.containsKey('recibo_whatsapp_modo_qr')) {
      await prefs.setString('recibo_whatsapp_modo_qr', modoWhatsapp);
    }

    if (!mounted) return;

    setState(() {
      _modoQrTermico = modoTermico;
      _modoQrWhatsapp = modoWhatsapp;
      _carregando = false;
    });
  }

  Future<void> _alterarCampo(
    String chave,
    bool valor, {
    required bool whatsapp,
  }) async {
    final campos = whatsapp ? _camposWhatsapp : _camposTermico;

    setState(() => campos[chave] = valor);

    final prefs = await SharedPreferences.getInstance();
    final prefixo = whatsapp ? 'recibo_whatsapp_' : 'recibo_';

    await prefs.setBool('$prefixo$chave', valor);
  }

  Future<void> _alterarModoQr(
    String? valor, {
    required bool whatsapp,
  }) async {
    if (valor == null) return;

    setState(() {
      if (whatsapp) {
        _modoQrWhatsapp = valor;
      } else {
        _modoQrTermico = valor;
      }
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      whatsapp ? 'recibo_whatsapp_modo_qr' : 'recibo_modo_qr',
      valor,
    );
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

  Widget _opcao(
    String chave,
    String titulo,
    String descricao, {
    required bool whatsapp,
  }) {
    final campos = whatsapp ? _camposWhatsapp : _camposTermico;

    return SwitchListTile(
      value: campos[chave] ?? false,
      activeThumbColor: _dourado,
      title: Text(
        titulo,
        style: const TextStyle(
          color: _azul,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(descricao),
      onChanged: (valor) => _alterarCampo(
        chave,
        valor,
        whatsapp: whatsapp,
      ),
    );
  }

  Widget _conteudo(bool whatsapp) {
    final modoQr = whatsapp ? _modoQrWhatsapp : _modoQrTermico;
    final destino =
        whatsapp ? 'no recibo do WhatsApp' : 'no recibo térmico';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: _azul,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: _dourado,
                  size: 38,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VIGILANTE RECIBOS',
                        style: TextStyle(
                          color: _dourado,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Escolha o que aparecerá $destino.',
                        style: const TextStyle(color: Colors.white),
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
          _opcao(
            'logo',
            'Logo',
            'Exibir a marca no recibo',
            whatsapp: whatsapp,
          ),
          _opcao(
            'fantasia',
            'Nome fantasia',
            'Exibir o nome da empresa',
            whatsapp: whatsapp,
          ),
          _opcao(
            'segmento',
            'Segmento',
            'Exibir o tipo de serviço',
            whatsapp: whatsapp,
          ),
          _opcao(
            'horarios',
            'Horários',
            'Exibir os horários do serviço',
            whatsapp: whatsapp,
          ),
          _opcao(
            'site',
            'Site',
            'Exibir o endereço do site',
            whatsapp: whatsapp,
          ),
          _opcao(
            'endereco_vigilante',
            'Endereço',
            'Exibir o endereço do vigilante',
            whatsapp: whatsapp,
          ),
          _opcao(
            'documento_vigilante',
            'CPF ou CNPJ',
            'Exibir o documento do vigilante',
            whatsapp: whatsapp,
          ),
        ]),
        _secao('Pagamento', [
          _opcao(
            'pix',
            'Chave Pix',
            'Exibir a chave Pix',
            whatsapp: whatsapp,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DropdownButtonFormField<String>(
              value: modoQr,
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
              onChanged: (valor) => _alterarModoQr(
                valor,
                whatsapp: whatsapp,
              ),
            ),
          ),
        ]),
        _secao('Dados do cliente', [
          _opcao(
            'cliente_nome',
            'Nome',
            'Exibir o nome do cliente',
            whatsapp: whatsapp,
          ),
          _opcao(
            'cliente_contato',
            'Contato',
            'Exibir o telefone ou contato',
            whatsapp: whatsapp,
          ),
          _opcao(
            'cliente_bairro',
            'Bairro',
            'Exibir o bairro do cliente',
            whatsapp: whatsapp,
          ),
          _opcao(
            'cliente_rua',
            'Rua',
            'Exibir a rua do cliente',
            whatsapp: whatsapp,
          ),
          _opcao(
            'cliente_numero',
            'Número',
            'Exibir o número do cliente',
            whatsapp: whatsapp,
          ),
          _opcao(
            'data_pagamento',
            'Data do pagamento',
            'Exibir a data do pagamento',
            whatsapp: whatsapp,
          ),
        ]),
      ],
    );
  }

    @override
  Widget build(BuildContext context) {
        return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3EE),
        appBar: AppBar(
          backgroundColor: _azul,
          foregroundColor: Colors.white,
          title: const Text('Personalizar recibos'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: _dourado,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Térmico'),
              Tab(text: 'WhatsApp'),
              Tab(text: 'Aviso de cobrança'),
              Tab(text: 'Décimo terceiro'),
            ],
          ),
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _conteudo(false),
                  _conteudo(true),
                  const CobrancaPersonalizacaoTab(),
                  const DecimoTerceiroPersonalizacaoTab(),
                ],
              ),
      ),
    );
      
  }
}
class DecimoTerceiroPersonalizacaoTab extends StatefulWidget {
  const DecimoTerceiroPersonalizacaoTab({super.key});

  static const String mensagemPadrao =
      'Olá, {nome do cliente}! Este é um aviso sobre o décimo terceiro do vigilante responsável pelo trabalho de segurança no local.\n\n'
      'Pedimos a colaboração de todos com essa contribuição, que ajuda a reconhecer e valorizar o trabalho realizado ao longo do ano. Agradecemos pela compreensão, parceria e apoio de sempre.';

  @override
  State<DecimoTerceiroPersonalizacaoTab> createState() =>
      _DecimoTerceiroPersonalizacaoTabState();
}

class _DecimoTerceiroPersonalizacaoTabState
    extends State<DecimoTerceiroPersonalizacaoTab> {
  final TextEditingController _mensagemController =
      TextEditingController(
    text: DecimoTerceiroPersonalizacaoTab.mensagemPadrao,
  );

  bool _ativo = true;
  bool dobrado = false;
    bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _ativo = prefs.getBool('recibo_decimo_terceiro_ativo') ?? true;
        dobrado = prefs.getBool('recibo_decimo_terceiro_dobrado') ?? false;
      _mensagemController.text =
          prefs.getString('recibo_decimo_terceiro_mensagem') ??
              DecimoTerceiroPersonalizacaoTab.mensagemPadrao;
      _carregando = false;
    });
  }

  @override
  void dispose() {
    _mensagemController.dispose();
    super.dispose();
  }

  Future<void> _salvarMensagem() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'recibo_decimo_terceiro_mensagem',
      _mensagemController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensagem salva.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Exibir aviso no recibo de novembro'),
          subtitle: const Text(
            'O aviso será incluído nos recibos de novembro.',
          ),
          value: _ativo,
          onChanged: (valor) async {
            setState(() => _ativo = valor);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('recibo_decimo_terceiro_ativo', valor);
          },
        ),
                  SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ativar opção do décimo terceiro em dezembro'),
          subtitle: const Text(
            'Você poderá incluir o valor extra ao receber a mensalidade de dezembro.',
          ),
          value: dobrado,
          onChanged: (valor) async {
            setState(() => dobrado = valor);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(
              'recibo_decimo_terceiro_dobrado',
              valor,
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _mensagemController,
          minLines: 6,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Mensagem sobre o décimo terceiro',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _salvarMensagem,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar mensagem'),
        ),
      ],
    );
  }
}
 class CobrancaPersonalizacaoTab extends StatefulWidget {
  const CobrancaPersonalizacaoTab({super.key});

  @override
  State<CobrancaPersonalizacaoTab> createState() =>
      _CobrancaPersonalizacaoTabState();
}

class _CobrancaPersonalizacaoTabState
    extends State<CobrancaPersonalizacaoTab> {
  static const String _mensagemCobrancaPadrao =
      '🔔 AVISO DE PAGAMENTO DA MENSALIDADE\n\n'
      'Olá, {nome do cliente}! Este é um aviso sobre a mensalidade de '
      '{mês}, no valor de {valor}, com vencimento em {data}.\n\n'
      'Para pagar pelo Pix:\n'
      'Chave Pix: {chave Pix}\n'
      'Pix copia e cola: {código Pix}\n'
      'O QR Code Pix acompanha o aviso.';

    static const String _mensagemTextoPadrao =
      'Olá, {nome do cliente}! Tudo bem?\n\n'
      'Passando para lembrar da mensalidade de {mês}, no valor de {valor}, '
      'com vencimento em {data}.\n\n'
      'Para facilitar o pagamento, segue a chave Pix:\n'
      '{chave Pix}\n\n'
      'Se tiver alguma dúvida, estou à disposição. Obrigado!';

  final TextEditingController _cobrancaController =
      TextEditingController(text: _mensagemCobrancaPadrao);

  final TextEditingController _avisoTextoController =
      TextEditingController(text: _mensagemTextoPadrao);

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarMensagens();
  }

  Future<void> _carregarMensagens() async {
    final prefs = await SharedPreferences.getInstance();

    final cobrancaSalva = prefs.getString('cobranca_mensagem');
    final avisoTextoSalvo = prefs.getString('aviso_texto_mensagem');

    if (!mounted) return;

    if (cobrancaSalva != null && cobrancaSalva.isNotEmpty) {
      _cobrancaController.text = cobrancaSalva;
    }

        if (avisoTextoSalvo != null && avisoTextoSalvo.isNotEmpty) {
      const avisoTextoPadraoAntigo =
          'Olá, {nome do cliente}. Este é um aviso importante: '
          '{escreva aqui o aviso}.';

      if (avisoTextoSalvo == avisoTextoPadraoAntigo) {
        _avisoTextoController.text = _mensagemTextoPadrao;
        await prefs.setString(
          'aviso_texto_mensagem',
          _mensagemTextoPadrao,
        );
      } else {
        _avisoTextoController.text = avisoTextoSalvo;
      }
        }

    setState(() => _carregando = false);
  }

  Future<void> _salvarMensagens() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'cobranca_mensagem',
      _cobrancaController.text.trim(),
    );

    await prefs.setString(
      'aviso_texto_mensagem',
      _avisoTextoController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensagens salvas.'),
      ),
    );
  }

  @override
  void dispose() {
    _cobrancaController.dispose();
    _avisoTextoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Configure as mensagens enviadas pelo WhatsApp para informar '
              'o cliente sobre a mensalidade ou enviar um aviso escrito por '
              'você. Confira a mensagem antes de enviá-la.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Cobrança da mensalidade',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Envia um aviso com o mês, o valor e o vencimento da mensalidade. '
          'Inclui a chave Pix e o código Pix copia e cola; o QR Code '
          'acompanha o aviso.',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cobrancaController,
          minLines: 7,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Mensagem de cobrança',
            border: OutlineInputBorder(),
            helperText:
                'Os dados entre chaves serão preenchidos com as informações '
                'do cliente e da mensalidade.',
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Aviso em texto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Permite escrever e salvar um aviso personalizado para enviar ao '
          'cliente. Você pode editar o texto antes de abrir a conversa no '
          'WhatsApp.',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _avisoTextoController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Texto do aviso',
            border: OutlineInputBorder(),
            helperText:
                'Edite o modelo aqui. Depois, você poderá revisar o aviso '
                'do cliente antes de abrir o WhatsApp.',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _salvarMensagens,
            icon: const Icon(Icons.save),
            label: const Text('Salvar mensagens'),
          ),
        ),
      ],
    );
  }
}                 
class _GraficoPizzaRecebidos extends StatelessWidget {
  const _GraficoPizzaRecebidos({
    required this.pix,
    required this.dinheiro,
    required this.cartao,
  });

  final double pix;
  final double dinheiro;
  final double cartao;

  String _reais(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  Widget _legenda(String nome, double valor, Color cor, double total) {
    final percentual =
        total == 0 ? 0 : (valor / total * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: cor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$nome • $percentual%'),
                Text(
                  _reais(valor),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = pix + dinheiro + cartao;
    const cores = [Colors.blue, Colors.green, Colors.orange];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recebidos por forma de pagamento',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (total == 0)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum valor recebido neste mês'),
                ),
              )
            else
              Row(
                children: [
                  CustomPaint(
                    size: const Size(150, 150),
                    painter: _PizzaRecebidosPainter(
                      valores: [pix, dinheiro, cartao],
                      cores: cores,
                    ),
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: FittedBox(
                            child: Text(
                              _reais(total),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _legenda('Pix', pix, cores[0], total),
                        _legenda('Dinheiro', dinheiro, cores[1], total),
                        _legenda('Cartão', cartao, cores[2], total),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PizzaRecebidosPainter extends CustomPainter {
  const _PizzaRecebidosPainter({
    required this.valores,
    required this.cores,
  });

  final List<double> valores;
  final List<Color> cores;

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<double>(0, (soma, valor) => soma + valor);
    final centro = Offset(size.width / 2, size.height / 2);
    final raio = size.shortestSide / 2;
    final area = Rect.fromCircle(center: centro, radius: raio);

    if (total <= 0) return;

    var anguloInicial = -1.5707963267948966;
    const circuloCompleto = 6.283185307179586;

    for (var i = 0; i < valores.length; i++) {
      final valor = valores[i];
      if (valor <= 0) continue;

      final angulo = circuloCompleto * valor / total;
      canvas.drawArc(
        area,
        anguloInicial,
        angulo,
        true,
        Paint()..color = cores[i],
      );
      anguloInicial += angulo;
    }
  }

  @override
  bool shouldRepaint(covariant _PizzaRecebidosPainter oldDelegate) => true;
}
