import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VaalmoApp());
}

// ============================================================
// APP
// ============================================================

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

// ============================================================
// MODELS
// ============================================================

class VaalmoHome {
  String id;
  String name;
  List<String> rooms;

  VaalmoHome({
    required this.id,
    required this.name,
    List<String>? rooms,
  }) : rooms = rooms ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rooms': rooms,
      };

  factory VaalmoHome.fromJson(Map<String, dynamic> json) {
    return VaalmoHome(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'My Home',
      rooms: List<String>.from(json['rooms'] ?? []),
    );
  }
}

class SmartDevice {
  String id;
  String name;
  String homeId;
  String roomName;
  int gangCount;
  List<String> relayNames;
  List<bool> relayStates;

  SmartDevice({
    required this.id,
    required this.name,
    required this.homeId,
    required this.roomName,
    required this.gangCount,
    required this.relayNames,
    required this.relayStates,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'homeId': homeId,
        'roomName': roomName,
        'gangCount': gangCount,
        'relayNames': relayNames,
        'relayStates': relayStates,
      };

  factory SmartDevice.fromJson(Map<String, dynamic> json) {
    final count = (json['gangCount'] as num?)?.toInt() ?? 1;
    final safeCount = count > 0 ? count : 1;

    final names = List<String>.from(json['relayNames'] ?? []);
    final states = List<bool>.from(json['relayStates'] ?? []);

    while (names.length < safeCount) {
      names.add('Relay ${names.length + 1}');
    }

    while (states.length < safeCount) {
      states.add(false);
    }

    return SmartDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Switch',
      homeId: json['homeId']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
      gangCount: safeCount,
      relayNames: names.take(safeCount).toList(),
      relayStates: states.take(safeCount).toList(),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<VaalmoHome> homes = [];
  List<SmartDevice> devices = [];

  String? selectedHomeId;
  bool isLoading = true;

  VaalmoHome? get selectedHome {
    for (final home in homes) {
      if (home.id == selectedHomeId) return home;
    }
    return null;
  }

  String createId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ------------------------------------------------------------
  // LOAD DATA AND MIGRATE OLD VERSION
  // ------------------------------------------------------------

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedHomes = prefs.getStringList('vaalmoHomes');
    final savedDevices = prefs.getStringList('devices');

    final loadedHomes = <VaalmoHome>[];
    final loadedDevices = <SmartDevice>[];

    if (savedHomes != null) {
      for (final entry in savedHomes) {
        try {
          loadedHomes.add(
            VaalmoHome.fromJson(jsonDecode(entry)),
          );
        } catch (error) {
          debugPrint('Could not load home: $error');
        }
      }
    }

    if (savedDevices != null) {
      for (final entry in savedDevices) {
        try {
          loadedDevices.add(
            SmartDevice.fromJson(jsonDecode(entry)),
          );
        } catch (error) {
          debugPrint('Could not load device: $error');
        }
      }
    }

    // Remove empty or duplicate home IDs.
    final usedIds = <String>{};
    loadedHomes.removeWhere((home) {
      if (home.id.isEmpty || usedIds.contains(home.id)) {
        return true;
      }
      usedIds.add(home.id);
      return false;
    });

    // Migrate previous single-home data if no multi-home data exists.
    if (loadedHomes.isEmpty) {
      final oldHomeName = prefs.getString('homeName');
      final oldRooms = prefs.getStringList('rooms') ?? [];

      if (oldHomeName != null && oldHomeName.isNotEmpty) {
        final migratedHome = VaalmoHome(
          id: createId(),
          name: oldHomeName,
          rooms: oldRooms,
        );

        loadedHomes.add(migratedHome);

        for (final device in loadedDevices) {
          device.homeId = migratedHome.id;
        }
      }
    }

    // Repair devices with an empty home ID when only one home exists.
    if (loadedHomes.length == 1) {
      for (final device in loadedDevices) {
        if (device.homeId.isEmpty) {
          device.homeId = loadedHomes.first.id;
        }
      }
    }

    String? savedSelection = prefs.getString('selectedHomeId');

    if (loadedHomes.isNotEmpty) {
      if (!loadedHomes.any((home) => home.id == savedSelection)) {
        savedSelection = loadedHomes.first.id;
      }
    } else {
      savedSelection = null;
    }

    if (!mounted) return;

    setState(() {
      homes = loadedHomes;
      devices = loadedDevices;
      selectedHomeId = savedSelection;
      isLoading = false;
    });

    await saveData();
  }

  // ------------------------------------------------------------
  // SAVE DATA
  // ------------------------------------------------------------

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'vaalmoHomes',
      homes.map((home) => jsonEncode(home.toJson())).toList(),
    );

    await prefs.setString(
      'selectedHomeId',
      selectedHomeId ?? '',
    );

    await prefs.setStringList(
      'devices',
      devices.map((device) => jsonEncode(device.toJson())).toList(),
    );

    await prefs.remove('homeName');
    await prefs.remove('rooms');
  }

  // ------------------------------------------------------------
  // CREATE HOME
  // ------------------------------------------------------------

  Future<void> createHome() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Home'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Home name',
            hintText: 'e.g. My House',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    final newHome = VaalmoHome(
      id: createId(),
      name: name,
    );

    setState(() {
      homes.add(newHome);
      selectedHomeId = newHome.id;
    });

    await saveData();
  }

  // ------------------------------------------------------------
  // RENAME HOME
  // ------------------------------------------------------------

  Future<void> renameHome(VaalmoHome home) async {
    final controller = TextEditingController(text: home.name);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Home'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Home name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    setState(() {
      home.name = name;
    });

    await saveData();
  }

  // ------------------------------------------------------------
  // DELETE HOME
  // ------------------------------------------------------------

  Future<void> deleteHome(VaalmoHome home) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Home?'),
        content: Text(
          'Delete "${home.name}" and all its rooms and devices?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      homes.removeWhere((item) => item.id == home.id);
      devices.removeWhere((item) => item.homeId == home.id);

      if (selectedHomeId == home.id) {
        selectedHomeId = homes.isNotEmpty ? homes.first.id : null;
      }
    });

    await saveData();
  }

  // ------------------------------------------------------------
  // CREATE ROOM
  // ------------------------------------------------------------

  Future<void> addRoom() async {
    final home = selectedHome;
    if (home == null) return;

    final controller = TextEditingController();

    final roomName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Room name',
            hintText: 'e.g. Living Room',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (roomName == null || roomName.isEmpty) return;

    if (home.rooms.any(
      (room) => room.toLowerCase() == roomName.toLowerCase(),
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room already exists')),
      );
      return;
    }

    setState(() {
      home.rooms.add(roomName);
    });

    await saveData();
  }

  // ------------------------------------------------------------
  // RENAME ROOM
  // ------------------------------------------------------------

  Future<void> renameRoom(String oldName) async {
    final home = selectedHome;
    if (home == null) return;

    final controller = TextEditingController(text: oldName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Room'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Room name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newName == null || newName.isEmpty || newName == oldName) {
      return;
    }

    if (home.rooms.any(
      (room) => room.toLowerCase() == newName.toLowerCase(),
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room already exists')),
      );
      return;
    }

    setState(() {
      final index = home.rooms.indexOf(oldName);
      if (index != -1) {
        home.rooms[index] = newName;
      }

      for (final device in devices) {
        if (device.homeId == home.id && device.roomName == oldName) {
          device.roomName = newName;
        }
      }
    });

    await saveData();
  }

  // ------------------------------------------------------------
  // DELETE ROOM
  // ------------------------------------------------------------

  Future<void> deleteRoom(String roomName) async {
    final home = selectedHome;
    if (home == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text('Delete "$roomName" and all devices inside it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      home.rooms.remove(roomName);
      devices.removeWhere(
        (device) =>
            device.homeId == home.id && device.roomName == roomName,
      );
    });

    await saveData();
  }

  // ------------------------------------------------------------
  // DEVICE OPERATIONS
  // ------------------------------------------------------------

  Future<void> addDevice(SmartDevice device) async {
    setState(() {
      devices.add(device);
    });
    await saveData();
  }

  Future<void> updateDevice(SmartDevice updatedDevice) async {
    final index = devices.indexWhere(
      (device) => device.id == updatedDevice.id,
    );

    if (index == -1) return;

    setState(() {
      devices[index] = updatedDevice;
    });

    await saveData();
  }

  Future<void> deleteDevice(String deviceId) async {
    setState(() {
      devices.removeWhere((device) => device.id == deviceId);
    });
    await saveData();
  }

  // ------------------------------------------------------------
  // MAIN UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final home = selectedHome;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaalmo Controls'),
        actions: [
          if (home != null)
            IconButton(
              tooltip: 'Rename Home',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => renameHome(home),
            ),
          if (home != null)
            IconButton(
              tooltip: 'Delete Home',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => deleteHome(home),
            ),
        ],
      ),
      body: home == null ? _buildEmptyHomes() : _buildHomeDashboard(home),
      floatingActionButton: home != null
          ? FloatingActionButton.extended(
              onPressed: addRoom,
              icon: const Icon(Icons.add),
              label: const Text('Add Room'),
            )
          : null,
    );
  }

  // ------------------------------------------------------------
  // EMPTY HOMES
  // ------------------------------------------------------------

  Widget _buildEmptyHomes() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.home_outlined,
              size: 90,
              color: Colors.teal,
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to Vaalmo Controls',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a home to get started.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: createHome,
              icon: const Icon(Icons.add_home),
              label: const Text('Add Your First Home'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HOME DASHBOARD
  // ------------------------------------------------------------

  Widget _buildHomeDashboard(VaalmoHome home) {
    final homeDevices = devices
        .where((device) => device.homeId == home.id)
        .toList();

    final totalRelays = homeDevices.fold<int>(
      0,
      (sum, device) => sum + device.gangCount,
    );

    final activeRelays = homeDevices.fold<int>(
      0,
      (sum, device) =>
          sum + device.relayStates.where((state) => state).length,
    );

    // The home list is validated during loading, so IDs are unique.
    final dropdownValue = homes.any((item) => item.id == selectedHomeId)
        ? selectedHomeId
        : homes.first.id;

    return Column(
      children: [
        // HOME SELECTOR
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(dropdownValue),
                  initialValue: dropdownValue,
                  decoration: const InputDecoration(
                    labelText: 'Select Home',
                    border: OutlineInputBorder(),
                  ),
                  items: homes.map((item) {
                    return DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.name),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value == null) return;

                    setState(() {
                      selectedHomeId = value;
                    });

                    await saveData();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Add Home',
                onPressed: createHome,
                icon: const Icon(Icons.add_home),
              ),
            ],
          ),
        ),

        // HOME SUMMARY
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.home, size: 40, color: Colors.teal),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        home.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${home.rooms.length} rooms'),
                      Text('${homeDevices.length} switches'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // RELAY SUMMARY
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Relay Overview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Relays'),
                    Text('$activeRelays / $totalRelays'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalRelays == 0 ? 0 : activeRelays / totalRelays,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ),

        // ROOM LIST
        Expanded(
          child: home.rooms.isEmpty
              ? _buildEmptyRooms()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: home.rooms.length,
                  itemBuilder: (context, index) {
                    final roomName = home.rooms[index];

                    final roomDevices = devices
                        .where(
                          (device) =>
                              device.homeId == home.id &&
                              device.roomName == roomName,
                        )
                        .toList();

                    final roomRelayCount = roomDevices.fold<int>(
                      0,
                      (sum, device) => sum + device.gangCount,
                    );

                    final roomActiveCount = roomDevices.fold<int>(
                      0,
                      (sum, device) =>
                          sum +
                          device.relayStates.where((state) => state).length,
                    );

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.meeting_room_outlined),
                        ),
                        title: Text(roomName),
                        subtitle: Text(
                          '${roomDevices.length} switches • '
                          '$roomActiveCount/$roomRelayCount relays ON',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') {
                              renameRoom(roomName);
                            } else if (value == 'delete') {
                              deleteRoom(roomName);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined),
                                  SizedBox(width: 8),
                                  Text('Rename Room'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline),
                                  SizedBox(width: 8),
                                  Text('Delete Room'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomDetailsScreen(
                                homeId: home.id,
                                roomName: roomName,
                                devices: devices,
                                onAddDevice: addDevice,
                                onUpdateDevice: updateDevice,
                                onDeleteDevice: deleteDevice,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // EMPTY ROOMS
  // ------------------------------------------------------------

  Widget _buildEmptyRooms() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.meeting_room_outlined,
              size: 70,
              color: Colors.teal,
            ),
            const SizedBox(height: 16),
            const Text(
              'No rooms added yet',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add rooms to organize your switches.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: addRoom,
              icon: const Icon(Icons.add),
              label: const Text('Add Room'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ROOM DETAILS
// ============================================================

class RoomDetailsScreen extends StatefulWidget {
  final String homeId;
  final String roomName;
  final List<SmartDevice> devices;

  final Future<void> Function(SmartDevice) onAddDevice;
  final Future<void> Function(SmartDevice) onUpdateDevice;
  final Future<void> Function(String) onDeleteDevice;

  const RoomDetailsScreen({
    super.key,
    required this.homeId,
    required this.roomName,
    required this.devices,
    required this.onAddDevice,
    required this.onUpdateDevice,
    required this.onDeleteDevice,
  });

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  List<SmartDevice> get roomDevices {
    return widget.devices
        .where(
          (device) =>
              device.homeId == widget.homeId &&
              device.roomName == widget.roomName,
        )
        .toList();
  }

  Future<void> addSwitch() async {
    final newDevice = await Navigator.push<SmartDevice>(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceScreen(
          homeId: widget.homeId,
          roomName: widget.roomName,
        ),
      ),
    );

    if (newDevice != null) {
      await widget.onAddDevice(newDevice);
      if (mounted) setState(() {});
    }
  }

  Future<void> openDevice(SmartDevice device) async {
    final deletedId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceControlScreen(
          device: device,
          onUpdate: widget.onUpdateDevice,
        ),
      ),
    );

    if (deletedId != null) {
      await widget.onDeleteDevice(deletedId);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentDevices = roomDevices;

    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: currentDevices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.power_outlined,
                      size: 80,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No switches in this room',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: addSwitch,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Switch'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: currentDevices.length,
              itemBuilder: (context, index) {
                final device = currentDevices[index];
                final activeCount =
                    device.relayStates.where((state) => state).length;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          activeCount > 0 ? Colors.teal : Colors.grey,
                      child: const Icon(Icons.power),
                    ),
                    title: Text(device.name),
                    subtitle: Text(
                      '${device.gangCount} gang • '
                      '$activeCount relays ON',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openDevice(device),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addSwitch,
        icon: const Icon(Icons.add),
        label: const Text('Add Switch'),
      ),
    );
  }
}

// ============================================================
// ADD DEVICE
// ============================================================

class AddDeviceScreen extends StatefulWidget {
  final String homeId;
  final String roomName;

  const AddDeviceScreen({
    super.key,
    required this.homeId,
    required this.roomName,
  });

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final TextEditingController nameController = TextEditingController();
  int selectedGangCount = 1;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void createDevice() {
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
      homeId: widget.homeId,
      roomName: widget.roomName,
      gangCount: selectedGangCount,
      relayNames: List.generate(
        selectedGangCount,
        (index) => 'Relay ${index + 1}',
      ),
      relayStates: List.generate(selectedGangCount, (_) => false),
    );

    Navigator.pop(context, device);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Switch')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Switch name',
                hintText: 'e.g. Living Room Switch',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Switch Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...[1, 2, 4].map((gang) {
              return Card(
                child: RadioListTile<int>(
                  value: gang,
                  groupValue: selectedGangCount,
                  title: Text('$gang-Gang Switch'),
                  subtitle: Text(
                    '$gang independent relay${gang > 1 ? 's' : ''}',
                  ),
                  secondary: Icon(
                    Icons.power,
                    color: selectedGangCount == gang ? Colors.teal : null,
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedGangCount = value;
                      });
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: createDevice,
              icon: const Icon(Icons.add),
              label: const Text('Create Switch'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DEVICE CONTROL
// ============================================================

class DeviceControlScreen extends StatefulWidget {
  final SmartDevice device;
  final Future<void> Function(SmartDevice) onUpdate;

  const DeviceControlScreen({
    super.key,
    required this.device,
    required this.onUpdate,
  });

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  late SmartDevice device;

  @override
  void initState() {
    super.initState();
    device = widget.device;
  }

  Future<void> persist() async {
    await widget.onUpdate(device);
  }

  // ------------------------------------------------------------
  // RENAME SWITCH
  // ------------------------------------------------------------

  Future<void> renameSwitch() async {
    final controller = TextEditingController(text: device.name);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Switch'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Switch name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    setState(() {
      device.name = name;
    });

    await persist();
  }

  // ------------------------------------------------------------
  // RENAME RELAY
  // ------------------------------------------------------------

  Future<void> renameRelay(int index) async {
    final controller = TextEditingController(
      text: device.relayNames[index],
    );

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename ${device.relayNames[index]}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Relay name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (name == null || name.isEmpty) return;

    setState(() {
      device.relayNames[index] = name;
    });

    await persist();
  }

  // ------------------------------------------------------------
  // RELAY TOGGLE
  // ------------------------------------------------------------

  Future<void> toggleRelay(int index, bool value) async {
    setState(() {
      device.relayStates[index] = value;
    });

    await persist();
  }

  // ------------------------------------------------------------
  // DELETE SWITCH
  // ------------------------------------------------------------

  Future<void> deleteSwitch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Switch?'),
        content: Text('Delete "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Return the device ID to RoomDetailsScreen, which deletes it
    // through the HomeScreen callback.
    Navigator.pop(context, device.id);
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final activeCount =
        device.relayStates.where((state) => state).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') {
                renameSwitch();
              } else if (value == 'delete') {
                deleteSwitch();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: Text('Rename Switch'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Switch'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SUMMARY
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    activeCount > 0 ? Icons.power : Icons.power_outlined,
                    size: 60,
                    color: activeCount > 0 ? Colors.teal : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$activeCount / ${device.gangCount} Relays ON'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: device.gangCount == 0
                        ? 0
                        : activeCount / device.gangCount,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // RELAY CONTROLS
          ...List.generate(device.gangCount, (index) {
            final isOn = device.relayStates[index];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isOn ? Colors.teal : Colors.grey,
                          child: Icon(
                            isOn
                                ? Icons.lightbulb
                                : Icons.lightbulb_outline,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.relayNames[index],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(isOn ? 'ON' : 'OFF'),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rename Relay',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => renameRelay(index),
                        ),
                        Switch(
                          value: isOn,
                          onChanged: (value) => toggleRelay(index, value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => toggleRelay(index, !isOn),
                        child: Text(isOn ? 'Turn OFF' : 'Turn ON'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // SIMULATION NOTICE
          Card(
            color: Colors.orange.withOpacity(0.12),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Simulation Mode\n'
                      'These relay controls currently operate locally '
                      'inside the app. No physical switch is connected yet.',
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