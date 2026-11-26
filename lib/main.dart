
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VaalmoApp());
}

class VaalmoApp extends StatelessWidget {
  const VaalmoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaalmo Controls',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// SMART DEVICE MODEL

class SmartDevice {
  String id;
  String name;
  String roomName;
  int gangCount;
  List<String> relayNames;
  List<bool> relayStates;

  SmartDevice({
    required this.id,
    required this.name,
    required this.roomName,
    required this.gangCount,
    List<String>? relayNames,
    List<bool>? relayStates,
  })  : relayNames = relayNames ??
            List.generate(gangCount, (index) => 'Switch ${index + 1}'),
        relayStates = relayStates ??
            List.generate(gangCount, (index) => false);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roomName': roomName,
      'gangCount': gangCount,
      'relayNames': relayNames,
      'relayStates': relayStates,
    };
  }

  factory SmartDevice.fromJson(Map<String, dynamic> json) {
    final count = json['gangCount'] as int? ?? 1;

    return SmartDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      roomName: json['roomName'] as String,
      gangCount: count,
      relayNames: (json['relayNames'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          List.generate(count, (index) => 'Switch ${index + 1}'),
      relayStates: (json['relayStates'] as List?)
              ?.map((item) => item as bool)
              .toList() ??
          List.generate(count, (index) => false),
    );
  }
}

// MAIN HOME SCREEN

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? homeName;
  List<String> rooms = [];
  List<SmartDevice> devices = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedHome = prefs.getString('homeName');
    final savedRooms = prefs.getStringList('rooms') ?? [];
    final savedDevices = prefs.getStringList('devices') ?? [];

    final loadedDevices = <SmartDevice>[];

    for (final item in savedDevices) {
      try {
        loadedDevices.add(
          SmartDevice.fromJson(jsonDecode(item)),
        );
      } catch (_) {
        // Ignore an invalid saved device entry.
      }
    }

    if (!mounted) return;

    setState(() {
      homeName = savedHome;
      rooms = savedRooms;
      devices = loadedDevices;
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('homeName', homeName ?? '');
    await prefs.setStringList('rooms', rooms);

    final encodedDevices = devices
        .map((device) => jsonEncode(device.toJson()))
        .toList();

    await prefs.setStringList('devices', encodedDevices);
  }

  Future<void> createHome() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Home'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Home name',
            hintText: 'Example: My Home',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();

              if (name.isEmpty) return;

              setState(() {
                homeName = name;
              });

              saveData();
              Navigator.pop(dialogContext);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> addRoom() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Room'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Room name',
            hintText: 'Example: Bedroom',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();

              if (name.isEmpty) return;

              if (rooms.any(
                (room) => room.toLowerCase() == name.toLowerCase(),
              )) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room already exists')),
                );
                return;
              }

              setState(() {
                rooms.add(name);
              });

              saveData();
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  void openRoom(String room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailsScreen(
          roomName: room,
          getDevices: () => devices
              .where((device) => device.roomName == room)
              .toList(),
          onAddDevice: (device) {
            setState(() {
              devices.add(device);
            });
            saveData();
          },
          onUpdate: saveData,
          onDeleteDevice: (device) {
            setState(() {
              devices.removeWhere((item) => item.id == device.id);
            });
            saveData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaalmo Controls'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: homeName == null || homeName!.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_outlined, size: 70),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to Vaalmo Controls',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    const Text('Create your home to get started'),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: createHome,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Home'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homeName!,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${rooms.length} rooms'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Rooms',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: addRoom,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Room'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: rooms.isEmpty
                        ? const Center(
                            child: Text('No rooms added yet'),
                          )
                        : ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final room = rooms[index];
                              final count = devices
                                  .where((d) => d.roomName == room)
                                  .length;

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.meeting_room),
                                  title: Text(room),
                                  subtitle: Text('$count devices'),
                                  trailing:
                                      const Icon(Icons.chevron_right),
                                  onTap: () => openRoom(room),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ROOM DETAILS

class RoomDetailsScreen extends StatefulWidget {
  final String roomName;
  final List<SmartDevice> Function() getDevices;
  final Function(SmartDevice) onAddDevice;
  final Function() onUpdate;
  final Function(SmartDevice) onDeleteDevice;

  const RoomDetailsScreen({
    super.key,
    required this.roomName,
    required this.getDevices,
    required this.onAddDevice,
    required this.onUpdate,
    required this.onDeleteDevice,
  });

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  Future<void> addDevice() async {
    final device = await Navigator.push<SmartDevice>(
      context,
      MaterialPageRoute(
        builder: (_) => AddDeviceScreen(roomName: widget.roomName),
      ),
    );

    if (device != null) {
      widget.onAddDevice(device);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomDevices = widget.getDevices();

    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addDevice,
        icon: const Icon(Icons.add),
        label: const Text('Add Switch'),
      ),
      body: roomDevices.isEmpty
          ? const Center(
              child: Text('No smart switches in this room yet'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: roomDevices.length,
              itemBuilder: (context, index) {
                final device = roomDevices[index];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.power),
                    title: Text(device.name),
                    subtitle: Text(
                      '${device.gangCount}-gang • Not paired',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceControlScreen(
                            device: device,
                            onUpdate: () {
                              widget.onUpdate();
                              setState(() {});
                            },
                            onDelete: () {
                              widget.onDeleteDevice(device);
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ADD DEVICE SCREEN

class AddDeviceScreen extends StatefulWidget {
  final String roomName;

  const AddDeviceScreen({
    super.key,
    required this.roomName,
  });

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final nameController = TextEditingController();
  int gangCount = 1;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void saveDevice() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a switch name')),
      );
      return;
    }

    final device = SmartDevice(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      roomName: widget.roomName,
      gangCount: gangCount,
    );

    Navigator.pop(context, device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Smart Switch')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Switch name',
                hintText: 'Example: Bedroom Switch',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Gang Count',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: gangCount,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: [1, 2, 4].map((count) {
                return DropdownMenuItem(
                  value: count,
                  child: Text('$count Gang'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    gangCount = value;
                  });
                }
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saveDevice,
                child: const Text('Save Switch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// DEVICE CONTROL SCREEN

class DeviceControlScreen extends StatefulWidget {
  final SmartDevice device;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const DeviceControlScreen({
    super.key,
    required this.device,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<DeviceControlScreen> createState() =>
      _DeviceControlScreenState();
}

class _DeviceControlScreenState
    extends State<DeviceControlScreen> {

  Future<void> renameRelay(int index) async {
    final controller = TextEditingController(
      text: widget.device.relayNames[index],
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rename Relay ${index + 1}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Relay name',
            hintText: 'Example: Main Light',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();

              if (name.isEmpty) return;

              setState(() {
                widget.device.relayNames[index] = name;
              });

              widget.onUpdate();
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Switch?'),
        content: const Text(
          'This will remove this switch from the app.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      widget.onDelete();
      Navigator.pop(context);
    }
  }

  IconData relayIcon(String name) {
    final value = name.toLowerCase();

    if (value.contains('fan')) return Icons.toys_outlined;
    if (value.contains('light')) return Icons.lightbulb_outline;
    if (value.contains('socket')) return Icons.power_outlined;
    if (value.contains('tv')) return Icons.tv_outlined;
    if (value.contains('motor')) return Icons.settings_outlined;

    return Icons.electrical_services_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;

    final activeCount =
        device.relayStates.where((state) => state).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          IconButton(
            onPressed: confirmDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete switch',
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // DEVICE INFORMATION

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.power,
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${device.gangCount}-Gang Smart Switch',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Hardware not connected',
                              style: TextStyle(
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 28),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Connection'),
                      Chip(
                        avatar: const Icon(
                          Icons.wifi_off,
                          size: 16,
                        ),
                        label: const Text('Not paired'),
                        backgroundColor:
                            Colors.orange.withValues(alpha: 0.15),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '$activeCount of ${device.gangCount} relays ON',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  LinearProgressIndicator(
                    value: activeCount / device.gangCount,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // RELAY HEADING

          const Text(
            'Individual Relay Controls',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // RELAY CARDS

          ...List.generate(device.gangCount, (index) {

            final isOn = device.relayStates[index];
            final relayName = device.relayNames[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [

                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isOn
                            ? Colors.amber.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Icon(
                        relayIcon(relayName),
                        size: 28,
                        color: isOn
                            ? Colors.amber
                            : Colors.grey,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            relayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Relay ${index + 1} • '
                            '${isOn ? "ON" : "OFF"}',
                            style: TextStyle(
                              color: isOn
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      tooltip: 'Rename relay',
                      onPressed: () => renameRelay(index),
                      icon: const Icon(Icons.edit_outlined),
                    ),

                    Switch(
                      value: isOn,
                      onChanged: (value) {
                        setState(() {
                          device.relayStates[index] = value;
                        });

                        widget.onUpdate();
                      },
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // DEMO MODE WARNING

          Card(
            color: Colors.orange.withValues(alpha: 0.10),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Simulation mode\n\n'
                      'Relay controls currently update '
                      'the application locally. No commands '
                      'are sent to physical Vaalmo switches. '
                      'The displayed states are not '
                      'hardware-confirmed.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
