
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
// REUSABLE TEXT DIALOG
// ============================================================

Future<String?> showNameDialog({
  required BuildContext context,
  required String title,
  required String label,
  String initialValue = '',
  String buttonText = 'Save',
}) async {
  String enteredName = initialValue;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            enteredName = value.trim();
          },
          onFieldSubmitted: (value) {
            Navigator.pop(dialogContext, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, enteredName);
            },
            child: Text(buttonText),
          ),
        ],
      );
    },
  );
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

// ============================================================
// SMART DEVICE MODEL
// ============================================================

class SmartDevice {
  String id;
  String deviceUid;
  String name;
  String homeId;
  String roomName;
  int gangCount;

  List<String> relayNames;
  List<bool> relayStates;

  String deviceType;
  String connectionStatus;
  String firmwareVersion;
  String? lastSeen;

  SmartDevice({
    required this.id,
    required this.deviceUid,
    required this.name,
    required this.homeId,
    required this.roomName,
    required this.gangCount,
    required this.relayNames,
    required this.relayStates,
    this.deviceType = 'Wi-Fi Smart Switch',
    this.connectionStatus = 'Not Connected',
    this.firmwareVersion = 'Unknown',
    this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceUid': deviceUid,
        'name': name,
        'homeId': homeId,
        'roomName': roomName,
        'gangCount': gangCount,
        'relayNames': relayNames,
        'relayStates': relayStates,
        'deviceType': deviceType,
        'connectionStatus': connectionStatus,
        'firmwareVersion': firmwareVersion,
        'lastSeen': lastSeen,
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

    final internalId = json['id']?.toString() ?? '';

    return SmartDevice(
      id: internalId,
      deviceUid: json['deviceUid']?.toString() ?? 'VAALMO-$internalId',
      name: json['name']?.toString() ?? 'Switch',
      homeId: json['homeId']?.toString() ?? '',
      roomName: json['roomName']?.toString() ?? '',
      gangCount: safeCount,
      relayNames: names.take(safeCount).toList(),
      relayStates: states.take(safeCount).toList(),
      deviceType:
          json['deviceType']?.toString() ?? 'Wi-Fi Smart Switch',
      connectionStatus:
          json['connectionStatus']?.toString() ?? 'Not Connected',
      firmwareVersion:
          json['firmwareVersion']?.toString() ?? 'Unknown',
      lastSeen: json['lastSeen']?.toString(),
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

    final usedIds = <String>{};

    loadedHomes.removeWhere((home) {
      if (home.id.isEmpty || usedIds.contains(home.id)) {
        return true;
      }
      usedIds.add(home.id);
      return false;
    });

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
    final name = await showNameDialog(
      context: context,
      title: 'Add New Home',
      label: 'Home name',
      buttonText: 'Create',
    );

    if (!mounted || name == null || name.isEmpty) return;

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
    final name = await showNameDialog(
      context: context,
      title: 'Rename Home',
      label: 'Home name',
      initialValue: home.name,
    );

    if (!mounted || name == null || name.isEmpty) return;

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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Home?'),
        content: Text(
          'Delete "${home.name}" and all its rooms and devices?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

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

    final roomName = await showNameDialog(
      context: context,
      title: 'Add Room',
      label: 'Room name',
      buttonText: 'Add',
    );

    if (!mounted || roomName == null || roomName.isEmpty) return;

    if (home.rooms.any(
      (room) => room.toLowerCase() == roomName.toLowerCase(),
    )) {
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

    final newName = await showNameDialog(
      context: context,
      title: 'Rename Room',
      label: 'Room name',
      initialValue: oldName,
    );

    if (!mounted ||
        newName == null ||
        newName.isEmpty ||
        newName == oldName) {
      return;
    }

    if (home.rooms.any(
      (room) => room.toLowerCase() == newName.toLowerCase(),
    )) {
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text('Delete "$roomName" and all devices inside it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

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

    final dropdownValue = homes.any((item) => item.id == selectedHomeId)
        ? selectedHomeId
        : homes.first.id;

    return Column(
      children: [
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
                      '$activeCount relays ON\n'
                      '${device.deviceUid}',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chevron_right),
                        Text(
                          device.connectionStatus,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
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

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final device = SmartDevice(
      id: id,
      deviceUid: 'VAALMO-$id',
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
    final name = await showNameDialog(
      context: context,
      title: 'Rename Switch',
      label: 'Switch name',
      initialValue: device.name,
    );

    if (!mounted || name == null || name.isEmpty) return;

    setState(() {
      device.name = name;
    });

    await persist();
  }

  // ------------------------------------------------------------
  // RENAME RELAY
  // ------------------------------------------------------------

  Future<void> renameRelay(int index) async {
    final name = await showNameDialog(
      context: context,
      title: 'Rename ${device.relayNames[index]}',
      label: 'Relay name',
      initialValue: device.relayNames[index],
    );

    if (!mounted || name == null || name.isEmpty) return;

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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Switch?'),
        content: Text('Delete "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    Navigator.pop(context, device.id);
  }

  // ------------------------------------------------------------
  // DEVICE SETTINGS
  // ------------------------------------------------------------

  Future<void> openDeviceSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceSettingsScreen(
          device: device,
          onUpdate: (updatedDevice) async {
            if (!mounted) return;

            setState(() {
              device = updatedDevice;
            });

            await persist();
          },
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
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
          IconButton(
            tooltip: 'Device Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: openDeviceSettings,
          ),
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

// ============================================================
// DEVICE SETTINGS SCREEN
// ============================================================

class DeviceSettingsScreen extends StatefulWidget {
  final SmartDevice device;
  final Future<void> Function(SmartDevice) onUpdate;

  const DeviceSettingsScreen({
    super.key,
    required this.device,
    required this.onUpdate,
  });

  @override
  State<DeviceSettingsScreen> createState() =>
      _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  late SmartDevice device;

  @override
  void initState() {
    super.initState();
    device = widget.device;
  }

  Future<void> updateDevice() async {
    await widget.onUpdate(device);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device information saved')),
    );
  }

  // ------------------------------------------------------------
  // RENAME DEVICE - FIXED
  // ------------------------------------------------------------

  Future<void> renameDevice() async {
    final name = await showNameDialog(
      context: context,
      title: 'Rename Device',
      label: 'Device name',
      initialValue: device.name,
    );

    if (!mounted || name == null || name.isEmpty) return;

    setState(() {
      device.name = name;
    });

    await updateDevice();
  }

  // ------------------------------------------------------------
  // DEVICE INFORMATION ROW
  // ------------------------------------------------------------

  Widget informationRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final statusColor = device.connectionStatus == 'Online'
        ? Colors.green
        : device.connectionStatus == 'Offline'
            ? Colors.red
            : Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.developer_board_outlined,
                    size: 64,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        device.connectionStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  informationRow('Device Name', device.name),
                  const Divider(height: 1),
                  informationRow('Device UID', device.deviceUid),
                  const Divider(height: 1),
                  informationRow('Device Type', device.deviceType),
                  const Divider(height: 1),
                  informationRow('Gang Count', '${device.gangCount} Gang'),
                  const Divider(height: 1),
                  informationRow('Home ID', device.homeId),
                  const Divider(height: 1),
                  informationRow('Room', device.roomName),
                  const Divider(height: 1),
                  informationRow('Firmware', device.firmwareVersion),
                  const Divider(height: 1),
                  informationRow(
                    'Last Seen',
                    device.lastSeen ?? 'Not available',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename Device'),
                  subtitle: const Text('Change the device display name'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: renameDevice,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                      'Device information is currently simulated. '
                      'Connection status and firmware details will be '
                      'provided by the ESP32 hardware after integration.',
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
