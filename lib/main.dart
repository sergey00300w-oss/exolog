import 'package:flutter/material.dart';
import 'database/db_helper.dart';
import 'screens/growth_chart_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExoLogApp());
}

class ExoLogApp extends StatelessWidget {
  const ExoLogApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExoLog',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9F9),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const AnimalListScreen(),
    const TodayPlannerScreen(),
    const InventoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets), label: 'Питомцы'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Сегодня'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Склад корма'),
        ],
      ),
    );
  }
}

// 1. Экран списка животных
class AnimalListScreen extends StatefulWidget {
  const AnimalListScreen({Key? key}) : super(key: key);

  @override
  _AnimalListScreenState createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  List<Map<String, dynamic>> _animals = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('animals');
    setState(() => _animals = res);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Коллекция экзотов')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddAnimalDialog(context),
      ),
      body: ListView.builder(
        itemCount: _animals.length,
        itemBuilder: (context, index) {
          final animal = _animals[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.cruelty_free)),
              title: Text('${animal['name']} (${animal['species']})'),
              subtitle: Text('Морфа: ${animal['morph'] ?? 'Normal'} | Пол: ${animal['sex']}'),
              trailing: IconButton(
                icon: const Icon(Icons.show_chart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => GrowthChartScreen(
                        animalId: animal['id'],
                        animalName: animal['name'],
                      ),
                    ),
                  );
                },
              ),
              onTap: () => _openAnimalDetails(animal),
            ),
          );
        },
      ),
    );
  }

  void _showAddAnimalDialog(BuildContext context) {
    final name = TextEditingController();
    final species = TextEditingController();
    final morph = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить питомца'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Кличка')),
            TextField(controller: species, decoration: const InputDecoration(labelText: 'Вид (напр. Pantherophis guttatus)')),
            TextField(controller: morph, decoration: const InputDecoration(labelText: 'Морфа')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('animals', {
                'name': name.text,
                'species': species.text,
                'morph': morph.text,
                'sex': 'Неизвестно',
                'feeding_interval_days': 7,
              });
              Navigator.pop(ctx);
              _refresh();
            },
            child: const Text('Сохранить'),
          )
        ],
      ),
    );
  }

  void _openAnimalDetails(Map<String, dynamic> animal) {
    // В детальной карточке доступны: Кормление (съел/отказ), Родословная, Зимовка
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(animal['name'], style: Theme.of(context).textTheme.headlineMedium),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.restaurant, color: Colors.green),
              title: const Text('Внести кормление'),
              onTap: () {
                Navigator.pop(ctx);
                _feedDialog(animal['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ac_unit, color: Colors.blue),
              title: const Text('Режим зимовки (Brumation)'),
              subtitle: const Text('Контроль фаз охлаждения и прогрева'),
              onTap: () {
                Navigator.pop(ctx);
                // Открытие параметров фазы зимовки
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree, color: Colors.brown),
              title: const Text('Родословная (Линия разведения)'),
              subtitle: Text('Отец ID: ${animal['father_id'] ?? 'Нет'}, Мать ID: ${animal['mother_id'] ?? 'Нет'}'),
            ),
          ],
        ),
      ),
    );
  }

  void _feedDialog(int animalId) async {
    final db = await DatabaseHelper.instance.database;
    final inventory = await db.query('inventory');
    int? selectedFoodId = inventory.isNotEmpty ? inventory.first['id'] as int : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Отметка кормления'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (inventory.isNotEmpty)
                DropdownButton<int>(
                  value: selectedFoodId,
                  isExpanded: true,
                  items: inventory.map((item) {
                    return DropdownMenuItem<int>(
                      value: item['id'] as int,
                      child: Text('${item['name']} (Остаток: ${item['count']} ${item['unit']})'),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedFoodId = val),
                )
              else
                const Text('Внимание: склад кормов пуст!'),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                label: const Text('Съедено (Списать 1 шт)', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  await DatabaseHelper.instance.logFeeding(
                    animalId: animalId,
                    date: DateTime.now(),
                    foodItemId: selectedFoodId,
                    quantity: 1,
                    status: 'eaten',
                  );
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text('Отказ от корма', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  await DatabaseHelper.instance.logFeeding(
                    animalId: animalId,
                    date: DateTime.now(),
                    foodItemId: selectedFoodId,
                    quantity: 0,
                    status: 'refused',
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}

// 2. Экран-планировщик: выборка животных, требующих кормления "Сегодня"
class TodayPlannerScreen extends StatelessWidget {
  const TodayPlannerScreen({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _getDueAnimals() async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT a.*, MAX(f.date) as last_feed_date
      FROM animals a
      LEFT JOIN feedings f ON a.id = f.animal_id AND f.status = 'eaten'
      GROUP BY a.id
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('План на сегодня')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getDueAnimals(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final now = DateTime.now();
          final dueList = snapshot.data!.where((a) {
            if (a['last_feed_date'] == null) return true;
            final last = DateTime.parse(a['last_feed_date']);
            final interval = a['feeding_interval_days'] as int;
            return now.difference(last).inDays >= interval;
          }).toList();

          if (dueList.isEmpty) {
            return const Center(child: Text('🎉 На сегодня всех покормили!'));
          }

          return ListView.builder(
            itemCount: dueList.length,
            itemBuilder: (ctx, i) {
              final a = dueList[i];
              return ListTile(
                leading: const Icon(Icons.alarm, color: Colors.orange),
                title: Text(a['name']),
                subtitle: Text('Вид: ${a['species']} | Интервал: раз в ${a['feeding_interval_days']} дн.'),
                trailing: const Chip(label: Text('Нужно покормить', style: TextStyle(color: Colors.white)), backgroundColor: Colors.deepOrange),
              );
            },
          );
        },
      ),
    );
  }
}

// 3. Экран Склада Корма
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _items = [];

  void _load() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query('inventory');
    setState(() => _items = res);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Склад кормов')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _addFeedItemDialog,
      ),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final item = _items[i];
          final bool isLow = (item['count'] as int) <= (item['min_threshold'] as int);
          return ListTile(
            leading: Icon(Icons.fastfood, color: isLow ? Colors.red : Colors.teal),
            title: Text(item['name']),
            subtitle: Text('Остаток: ${item['count']} ${item['unit']}'),
            trailing: isLow ? const Chip(label: Text('Заканчивается!'), backgroundColor: Colors.amber) : null,
          );
        },
      ),
    );
  }

  void _addFeedItemDialog() {
    final name = TextEditingController();
    final count = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить кормовые объекты'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Тип (напр. Мыши опушата)')),
            TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Количество')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('inventory', {
                'name': name.text,
                'count': int.tryParse(count.text) ?? 0,
                'unit': 'шт',
              });
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Сохранить'),
          )
        ],
      ),
    );
  }
}