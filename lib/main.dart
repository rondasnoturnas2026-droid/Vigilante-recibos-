
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
final ValueNotifier<ThemeMode> temaApp =
    ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class _TelaPrincipalState extends State<TelaPrincipal> {
  int paginaAtual = 0;

final AppStore store = AppStore();
late final List<Widget> paginas;

@override
void initState() {
  super.initState();
store.carregarDadosVigilante();
 store.carregarBairrosERuas(); 
    
  paginas = [
  const TelaFaturas(),
  TelaClientes(store: store),
  const TelaRelatorio(),
  TelaConfiguracoes(store: store),
];
  
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
            label: 'Faturas',
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

class TelaFaturas extends StatefulWidget {
  const TelaFaturas({super.key});

  @override
  State<TelaFaturas> createState() => _TelaFaturasState();
}

class _TelaFaturasState extends State<TelaFaturas> {
  int abaAtual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vigilante Recibos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(Icons.location_on_outlined),
                          Text('Bairro'),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_outlined),
                          Text('Dia'),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(Icons.payments_outlined),
                          Text('Pagamento'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    abaAtual == 0
                        ? Icons.receipt_long_outlined
                        : abaAtual == 1
                            ? Icons.check_circle_outline
                            : Icons.person_off_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    abaAtual == 0
                        ? 'Nenhuma fatura pendente'
                        : abaAtual == 1
                            ? 'Nenhuma fatura recebida'
                            : 'Nenhum cliente inativo',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nova fatura'),
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
String dataFiltro = 'Todas as datas';
  double get totalMensal {
    return widget.store.clientes.fold<double>(0, (soma, cliente) {
      final texto = (cliente['valor'] ?? '0')
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
  return dadosCliente.contains(busca);
}).toList();
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
      prefixIcon: const Icon(Icons.search),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      filled: true,
    ),
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

                      final endereco = [
                        cliente['rua'],
                        cliente['numero'],
                        cliente['complemento'],
                      ]
                          .where(
                            (parte) =>
                                parte != null && parte.trim().isNotEmpty,
                          )
                          .join(', ');

                      final detalhes = [
                        if ((cliente['bairro'] ?? '').isNotEmpty)
                          cliente['bairro'],
                        if (endereco.isNotEmpty) endereco,
                        if ((cliente['telefone'] ?? '').isNotEmpty)
                          'Tel: ${cliente['telefone']}',
                        'Dia: ${cliente['dia'] ?? ''} | Pagamento: ${cliente['formaPagamento'] ?? ''}',
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
  validator: (v) {
    if (v == null || v.trim().isEmpty) {
      return 'Informe o nome do cliente';
    }
    return null;
  },
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
              leading: const Icon(Icons.light_mode_outlined),
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
  controller: nomeFantasia,
  decoration: const InputDecoration(
    labelText: 'Nome Fantasia',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

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
      label: const Text('Sex'),
      selected: widget.store.vigilanteSexta,
      onSelected: (valor) {
        setState(() {
          widget.store.vigilanteSexta = valor;
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

  static Future<bool> conectar(String enderecoMac) async {
    try {
      return await PrintBluetoothThermal.connect(
        macPrinterAddress: enderecoMac,
      );
    } catch (e) {
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
    required String nomeMorador,
    required String valor,
    required String formaPagamento,
    required String vencimento,
    required String dataRecebimento,
    String observacao = '',
  }) async {
    final conectado =
        await PrintBluetoothThermal.connectionStatus;

    if (!conectado) {
      return false;
    }

    final recibo = '''
================================
       VIGILANTE RECIBOS
================================

Morador: $nomeMorador

Valor: R\$ $valor

Pagamento: $formaPagamento

Vencimento: $vencimento

Recebido em: $dataRecebimento

Status: RECEBIDO

${observacao.isNotEmpty ? 'Observacao: $observacao\n' : ''}
--------------------------------
        PAGAMENTO RECEBIDO
--------------------------------


''';

    final resultado =
        await PrintBluetoothThermal.writeString(
      printText: PrintTextSize(
        size: 1,
        text: recibo,
      ),
    );

    await PrintBluetoothThermal.writeBytes(
  '\n\n\n'.codeUnits,
);

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
  Future<void> salvarBairrosERuas() async {
  final prefs = await SharedPreferences.getInstance();

  final dados = bairros.map((bairro) {
    return {
      'id': bairro.id,
      'nome': bairro.nome,
      'ruas': bairro.ruas,
    };
  }).toList();

  await prefs.setString(
    'bairros_ruas',
    jsonEncode(dados),
  );
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

