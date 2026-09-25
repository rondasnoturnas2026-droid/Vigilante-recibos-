import 'package:flutter/material.dart';

void main() {
  runApp(const VigilanteRecibosApp());
}

class VigilanteRecibosApp extends StatelessWidget {
  const VigilanteRecibosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vigilante Recibos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
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

  final List<Widget> paginas = const [
    TelaFaturas(),
    TelaMoradores(),
    TelaRelatorio(),
    TelaConfiguracoes(),
  ];

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
            label: 'Moradores',
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

class TelaMoradores extends StatelessWidget {
  const TelaMoradores({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Moradores',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 70,
              color: Colors.grey,
            ),
            SizedBox(height: 15),
            Text(
              'Nenhum morador cadastrado',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.person_add),
        label: const Text('Novo morador'),
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
  const TelaConfiguracoes({super.key});

  @override
  State<TelaConfiguracoes> createState() => _TelaConfiguracoesState();
}

class _TelaConfiguracoesState extends State<TelaConfiguracoes> {
  bool temaEscuro = false;

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
          const ListTile(
            leading: Icon(Icons.security),
            title: Text('Dados do vigilante'),
            subtitle: Text('Nome e contato'),
            trailing: Icon(Icons.chevron_right),
          onPressed: () {
  if (fatura['status'] == 'RECEBIDO') {
    gerarRecibo(fatura);
  }
},
          const Divider(),
          const ListTile(
            leading: Icon(Icons.print_outlined),
            title: Text('Impressora térmica'),
            subtitle: Text('Impressora Bluetooth 58 mm'),
            trailing: Icon(Icons.chevron_right),
          ),
          const Divider(),
          SwitchListTile(
  title: const Text('Tema escuro'),
  subtitle: const Text('Ativar ou desativar'),
  value: temaEscuro,
  onChanged: (valor) {
    setState(() {
      temaEscuro = valor;
    });
               },
          ),
        ],
      ),
    );
  }
}       

