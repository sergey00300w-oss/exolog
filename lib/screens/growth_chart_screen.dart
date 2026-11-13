import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';

class GrowthChartScreen extends StatefulWidget {
  final int animalId;
  final String animalName;

  const GrowthChartScreen({Key? key, required this.animalId, required this.animalName}) : super(key: key);

  @override
  _GrowthChartScreenState createState() => _GrowthChartScreenState();
}

class _GrowthChartScreenState extends State<GrowthChartScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.query(
      'measurements',
      where: 'animal_id = ?',
      whereArgs: [widget.animalId],
      orderBy: 'date ASC',
    );
    setState(() {
      _records = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Динамика роста: ${widget.animalName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(child: Text('Замеров пока нет'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Динамика веса (граммы)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: const FlTitlesData(
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _records.asMap().entries.map((e) {
                                  double val = (e.value['weight_grams'] as num?)?.toDouble() ?? 0.0;
                                  return FlSpot(e.key.toDouble(), val);
                                }).toList(),
                                isCurved: true,
                                color: Colors.teal,
                                barWidth: 3,
                                dotData: const FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить замер'),
                        onPressed: _showAddDialog,
                      )
                    ],
                  ),
                ),
    );
  }

  void _showAddDialog() {
    final weightController = TextEditingController();
    final lengthController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый замер'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Вес (г)')),
            TextField(controller: lengthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Длина (см)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final db = await DatabaseHelper.instance.database;
              await db.insert('measurements', {
                'animal_id': widget.animalId,
                'date': DateTime.now().toIso8601String(),
                'weight_grams': double.tryParse(weightController.text) ?? 0.0,
                'length_cm': double.tryParse(lengthController.text) ?? 0.0,
              });
              Navigator.pop(context);
              _loadMeasurements();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}