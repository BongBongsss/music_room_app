import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/room_map_layout.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/settings_service.dart';
import 'package:music_room_app/widgets/room_map_view.dart';

final roomMapEditorRoomsProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(roomServiceProvider).getRooms();
});

class RoomMapEditorScreen extends ConsumerStatefulWidget {
  const RoomMapEditorScreen({super.key});

  @override
  ConsumerState<RoomMapEditorScreen> createState() =>
      _RoomMapEditorScreenState();
}

class _RoomMapEditorScreenState extends ConsumerState<RoomMapEditorScreen> {
  RoomMapLayout _layout = defaultRoomMapLayout;
  String? _selectedId;
  bool _loading = true;
  bool _saving = false;
  bool _snapToGrid = true;

  final _labelController = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadLayout() async {
    try {
      final layout = await ref.read(settingsServiceProvider).getRoomMapLayout();
      if (!mounted) return;
      setState(() {
        _layout = layout;
        _titleController.text = layout.title;
        _selectedId = layout.items.isEmpty ? null : layout.items.first.id;
        _syncControllers();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('도면 설정을 불러오지 못했습니다: $e')),
      );
    }
  }

  Future<void> _saveLayout() async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsServiceProvider).updateRoomMapLayout(_layout);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('도면 배치가 저장되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  RoomMapItem? get _selectedItem {
    for (final item in _layout.items) {
      if (item.id == _selectedId) return item;
    }
    return null;
  }

  void _selectItem(String id) {
    setState(() {
      _selectedId = id;
      _syncControllers();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedId = null;
      _syncControllers();
    });
  }

  void _syncControllers() {
    final item = _selectedItem;
    _labelController.text = item?.label ?? '';
  }

  void _moveItem(String id, Offset delta) {
    _updateItem(id, (item) {
      final nextX = item.x + delta.dx;
      final nextY = item.y + delta.dy;
      final x = (_snapToGrid ? _snap(nextX) : nextX)
          .clamp(0.0, _layout.width - item.width)
          .toDouble();
      final y = (_snapToGrid ? _snap(nextY) : nextY)
          .clamp(0.0, _layout.height - item.height)
          .toDouble();
      return item.copyWith(x: x, y: y);
    });
  }

  double _snap(double value) => (value / 4).round() * 4;

  void _updateSelected(RoomMapItem Function(RoomMapItem item) update) {
    final id = _selectedId;
    if (id == null) return;
    _updateItem(id, update);
  }

  void _updateItem(String id, RoomMapItem Function(RoomMapItem item) update) {
    setState(() {
      _layout = RoomMapLayout(
        title: _layout.title,
        width: _layout.width,
        height: _layout.height,
        items: _layout.items.map((item) {
          if (item.id != id) return item;
          final next = update(item);
          return next.copyWith(
            x: next.x.clamp(0.0, _layout.width - next.width).toDouble(),
            y: next.y.clamp(0.0, _layout.height - next.height).toDouble(),
          );
        }).toList(),
      );
    });
  }

  void _addItem(RoomMapItemType type) {
    final id = '${type.name}-${DateTime.now().microsecondsSinceEpoch}';
    final item = RoomMapItem(
      id: id,
      type: type,
      label: switch (type) {
        RoomMapItemType.room => '새 방',
        RoomMapItemType.corridor => '복도',
        RoomMapItemType.utility => '시설',
        RoomMapItemType.entrance => '출입문',
      },
      x: 24,
      y: 72,
      width: type == RoomMapItemType.corridor ? 120 : 76,
      height: type == RoomMapItemType.corridor ? 56 : 54,
      fontSize: type == RoomMapItemType.room ? 16 : 13,
      doorSide: type == RoomMapItemType.corridor
          ? RoomMapDoorSide.none
          : RoomMapDoorSide.right,
    );

    setState(() {
      _layout = RoomMapLayout(
        title: _layout.title,
        width: _layout.width,
        height: _layout.height,
        items: [..._layout.items, item],
      );
      _selectedId = id;
      _syncControllers();
    });
  }

  void _deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    setState(() {
      final items = _layout.items.where((item) => item.id != id).toList();
      _layout = RoomMapLayout(
        title: _layout.title,
        width: _layout.width,
        height: _layout.height,
        items: items,
      );
      _selectedId = items.isEmpty ? null : items.first.id;
      _syncControllers();
    });
  }

  void _resetDefault() {
    setState(() {
      _layout = defaultRoomMapLayout;
      _titleController.text = _layout.title;
      _selectedId = _layout.items.first.id;
      _syncControllers();
    });
  }

  RoomMapItem? _nearestReference(
    RoomMapItem selected,
    bool Function(RoomMapItem item) matches,
  ) {
    RoomMapItem? best;
    double? bestDistance;

    for (final item in _layout.items) {
      if (item.id == selected.id || !matches(item)) continue;
      final dx = (item.x + item.width / 2) - (selected.x + selected.width / 2);
      final dy =
          (item.y + item.height / 2) - (selected.y + selected.height / 2);
      final distance = dx * dx + dy * dy;
      if (bestDistance == null || distance < bestDistance) {
        best = item;
        bestDistance = distance;
      }
    }

    return best;
  }

  void _alignSelected(_AlignAction action) {
    final selected = _selectedItem;
    if (selected == null) return;

    final refItem = _nearestReference(selected, (item) {
      return switch (action) {
        _AlignAction.top ||
        _AlignAction.bottom ||
        _AlignAction.height =>
          item.type == selected.type,
        _AlignAction.left ||
        _AlignAction.right ||
        _AlignAction.width =>
          item.type == selected.type,
      };
    });

    if (refItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('맞출 기준 항목이 없습니다.')),
      );
      return;
    }

    _updateSelected((item) {
      return switch (action) {
        _AlignAction.top => item.copyWith(y: refItem.y),
        _AlignAction.bottom =>
          item.copyWith(y: refItem.y + refItem.height - item.height),
        _AlignAction.left => item.copyWith(x: refItem.x),
        _AlignAction.right =>
          item.copyWith(x: refItem.x + refItem.width - item.width),
        _AlignAction.width => item.copyWith(width: refItem.width),
        _AlignAction.height => item.copyWith(height: refItem.height),
      };
    });
  }

  void _nudgeSelected(double dx, double dy) {
    final id = _selectedId;
    if (id == null) return;
    _updateItem(id, (item) {
      return item.copyWith(
        x: (item.x + dx).clamp(0.0, _layout.width - item.width).toDouble(),
        y: (item.y + dy).clamp(0.0, _layout.height - item.height).toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomMapEditorRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('연습실 도면 편집'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _resetDefault,
            icon: const Icon(Icons.restart_alt),
            tooltip: '기본 도면으로 되돌리기',
          ),
          IconButton(
            onPressed: _saving ? null : _saveLayout,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            tooltip: '저장',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : roomsAsync.when(
              data: (rooms) => Column(
                children: [
                  _Toolbar(
                    onAddRoom: () => _addItem(RoomMapItemType.room),
                    onAddCorridor: () => _addItem(RoomMapItemType.corridor),
                    onAddUtility: () => _addItem(RoomMapItemType.utility),
                    onAddEntrance: () => _addItem(RoomMapItemType.entrance),
                    snapToGrid: _snapToGrid,
                    onSnapChanged: (value) {
                      setState(() => _snapToGrid = value);
                    },
                  ),
                  _CanvasSettingsBar(
                    titleController: _titleController,
                    width: _layout.width,
                    height: _layout.height,
                    fitToWidth: _layout.fitToWidth,
                    onTitleChanged: (title) {
                      setState(() {
                        _layout = _layout.copyWith(title: title);
                      });
                    },
                    onSizeChanged: (width, height) {
                      setState(() {
                        final maxRight = _layout.items.fold<double>(
                          0,
                          (max, item) => item.x + item.width > max
                              ? item.x + item.width
                              : max,
                        );
                        final maxBottom = _layout.items.fold<double>(
                          0,
                          (max, item) => item.y + item.height > max
                              ? item.y + item.height
                              : max,
                        );
                        _layout = _layout.copyWith(
                          width: width.clamp(maxRight + 8, 900).toDouble(),
                          height: height.clamp(maxBottom + 8, 900).toDouble(),
                        );
                      });
                    },
                    onFitToWidthChanged: (value) {
                      setState(() {
                        _layout = _layout.copyWith(fitToWidth: value);
                      });
                    },
                  ),
                  Expanded(
                    flex: _selectedItem == null ? 1 : 3,
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.7,
                        maxScale: 3,
                        boundaryMargin: const EdgeInsets.all(120),
                        constrained: false,
                        child: RoomMapView(
                          layout: _layout,
                          rooms: rooms,
                          editable: true,
                          selectedItemId: _selectedId,
                          onSelectItem: _selectItem,
                          onClearSelection: _clearSelection,
                          onMoveItem: _moveItem,
                        ),
                      ),
                    ),
                  ),
                  if (_selectedItem != null)
                    Flexible(
                      flex: 2,
                      child: _Inspector(
                        item: _selectedItem,
                        rooms: rooms,
                        labelController: _labelController,
                        onChangedType: (type) {
                          _updateSelected((item) => item.copyWith(
                                type: type,
                                clearRoomId: type != RoomMapItemType.room,
                                clearRoomNumber: type != RoomMapItemType.room,
                                facilityKind: type == RoomMapItemType.utility
                                    ? item.facilityKind
                                    : RoomMapFacilityKind.none,
                              ));
                        },
                        onChangedLabel: (label) {
                          _updateSelected(
                              (item) => item.copyWith(label: label));
                        },
                        onChangedRoom: (room) {
                          _updateSelected((item) {
                            final shouldUseRoomLabel = item.label == '새 방' ||
                                item.label.trim().isEmpty;
                            return item.copyWith(
                              roomId: room?.roomId,
                              clearRoomId: room == null,
                              roomNumber: _roomNumber(room),
                              clearRoomNumber: room == null,
                              label: room != null && shouldUseRoomLabel
                                  ? _roomLabel(room)
                                  : item.label,
                            );
                          });
                          if (room != null &&
                              (_labelController.text == '새 방' ||
                                  _labelController.text.trim().isEmpty)) {
                            _labelController.text = _roomLabel(room);
                          }
                        },
                        onChangedFacilityKind: (kind) {
                          _updateSelected((item) => item.copyWith(
                                facilityKind: kind,
                                label: kind == RoomMapFacilityKind.none
                                    ? item.label
                                    : _facilityLabel(kind),
                              ));
                          if (kind != RoomMapFacilityKind.none) {
                            _labelController.text = _facilityLabel(kind);
                          }
                        },
                        onNudge: _nudgeSelected,
                        onChangedDoor: (door) {
                          _updateSelected(
                              (item) => item.copyWith(doorSide: door));
                        },
                        onChangedDoorPosition: (position) {
                          _updateSelected(
                            (item) => item.copyWith(doorPosition: position),
                          );
                        },
                        onSizeChanged: (width, height) {
                          _updateSelected(
                            (item) =>
                                item.copyWith(width: width, height: height),
                          );
                        },
                        onFontSizeChanged: (fontSize) {
                          _updateSelected(
                            (item) => item.copyWith(fontSize: fontSize),
                          );
                        },
                        onAlign: _alignSelected,
                        onDelete: _deleteSelected,
                      ),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('방 정보를 불러오지 못했습니다.\n$error')),
            ),
    );
  }

  int? _roomNumber(Room? room) {
    if (room == null) return null;
    final idMatch = RegExp(r'(\d+)$').firstMatch(room.roomId);
    if (idMatch != null) return int.tryParse(idMatch.group(1)!);

    final nameMatch =
        RegExp(r'(^|\D)(\d{1,2})(번|호|호실|$)').firstMatch(room.name);
    if (nameMatch != null) return int.tryParse(nameMatch.group(2)!);
    return null;
  }

  String _roomLabel(Room room) {
    final number = _roomNumber(room);
    return number == null ? room.name : '$number번';
  }

  String _facilityLabel(RoomMapFacilityKind kind) {
    return switch (kind) {
      RoomMapFacilityKind.none => '시설',
      RoomMapFacilityKind.toilet => '화장실',
      RoomMapFacilityKind.extinguisher => '소화기',
      RoomMapFacilityKind.waterPurifier => '정수기',
      RoomMapFacilityKind.microwave => '전자렌지',
      RoomMapFacilityKind.fridge => '냉장고',
      RoomMapFacilityKind.vacuum => '청소기',
    };
  }
}

enum _AlignAction { top, bottom, left, right, width, height }

class _Toolbar extends StatelessWidget {
  final VoidCallback onAddRoom;
  final VoidCallback onAddCorridor;
  final VoidCallback onAddUtility;
  final VoidCallback onAddEntrance;
  final bool snapToGrid;
  final ValueChanged<bool> onSnapChanged;

  const _Toolbar({
    required this.onAddRoom,
    required this.onAddCorridor,
    required this.onAddUtility,
    required this.onAddEntrance,
    required this.snapToGrid,
    required this.onSnapChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          _ToolButton(
            icon: Icons.meeting_room_outlined,
            label: '방',
            onPressed: onAddRoom,
          ),
          _ToolButton(
            icon: Icons.timeline,
            label: '복도',
            onPressed: onAddCorridor,
          ),
          _ToolButton(
            icon: Icons.category_outlined,
            label: '시설',
            onPressed: onAddUtility,
          ),
          _ToolButton(
            icon: Icons.door_front_door_outlined,
            label: '출입문',
            onPressed: onAddEntrance,
          ),
          const SizedBox(width: 4),
          FilterChip(
            selected: snapToGrid,
            onSelected: onSnapChanged,
            avatar: const Icon(Icons.grid_4x4, size: 16),
            label: const Text('스냅'),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _CanvasSettingsBar extends StatelessWidget {
  final TextEditingController titleController;
  final double width;
  final double height;
  final bool fitToWidth;
  final ValueChanged<String> onTitleChanged;
  final void Function(double width, double height) onSizeChanged;
  final ValueChanged<bool> onFitToWidthChanged;

  const _CanvasSettingsBar({
    required this.titleController,
    required this.width,
    required this.height,
    required this.fitToWidth,
    required this.onTitleChanged,
    required this.onSizeChanged,
    required this.onFitToWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '도면 제목',
                  hintText: '빈칸이면 숨김',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onTitleChanged,
              ),
            ),
            const SizedBox(width: 8),
            _CompactStepper(
              label: '가로',
              value: width,
              onChanged: (value) => onSizeChanged(value, height),
            ),
            const SizedBox(width: 8),
            _CompactStepper(
              label: '세로',
              value: height,
              onChanged: (value) => onSizeChanged(width, value),
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: fitToWidth,
              onSelected: onFitToWidthChanged,
              avatar: const Icon(Icons.fit_screen, size: 16),
              label: const Text('폭 맞춤'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactStepper extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _CompactStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBDBDBD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '$label ${value.round()}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => onChanged((value - 4).clamp(120, 900).toDouble()),
            icon: const Icon(Icons.remove, size: 16),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => onChanged((value + 4).clamp(120, 900).toDouble()),
            icon: const Icon(Icons.add, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Inspector extends StatelessWidget {
  final RoomMapItem? item;
  final List<Room> rooms;
  final TextEditingController labelController;
  final ValueChanged<RoomMapItemType> onChangedType;
  final ValueChanged<String> onChangedLabel;
  final ValueChanged<Room?> onChangedRoom;
  final ValueChanged<RoomMapFacilityKind> onChangedFacilityKind;
  final void Function(double dx, double dy) onNudge;
  final ValueChanged<RoomMapDoorSide> onChangedDoor;
  final ValueChanged<RoomMapDoorPosition> onChangedDoorPosition;
  final void Function(double width, double height) onSizeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<_AlignAction> onAlign;
  final VoidCallback onDelete;

  const _Inspector({
    required this.item,
    required this.rooms,
    required this.labelController,
    required this.onChangedType,
    required this.onChangedLabel,
    required this.onChangedRoom,
    required this.onChangedFacilityKind,
    required this.onNudge,
    required this.onChangedDoor,
    required this.onChangedDoorPosition,
    required this.onSizeChanged,
    required this.onFontSizeChanged,
    required this.onAlign,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final selected = item;
    if (selected == null) {
      return const SizedBox(
        height: 72,
        child: Center(child: Text('항목을 선택하세요.')),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<RoomMapItemType>(
                      key:
                          ValueKey('type-${selected.id}-${selected.type.name}'),
                      initialValue: selected.type,
                      decoration: const InputDecoration(
                        labelText: '종류',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: RoomMapItemType.room,
                          child: Text('방'),
                        ),
                        DropdownMenuItem(
                          value: RoomMapItemType.corridor,
                          child: Text('복도'),
                        ),
                        DropdownMenuItem(
                          value: RoomMapItemType.utility,
                          child: Text('시설'),
                        ),
                        DropdownMenuItem(
                          value: RoomMapItemType.entrance,
                          child: Text('출입문'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onChangedType(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: '표시명',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: onChangedLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '삭제',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RoomDropdown(
                      item: selected,
                      rooms: rooms,
                      onChanged: onChangedRoom,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<RoomMapDoorSide>(
                      key: ValueKey(
                          'door-${selected.id}-${selected.doorSide.name}'),
                      initialValue: selected.doorSide,
                      decoration: const InputDecoration(
                        labelText: '문 위치',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: RoomMapDoorSide.none,
                          child: Text('없음'),
                        ),
                        DropdownMenuItem(
                          value: RoomMapDoorSide.top,
                          child: Text('위'),
                        ),
                        DropdownMenuItem(
                          value: RoomMapDoorSide.right,
                          child: Text('오른쪽'),
                        ),
                        DropdownMenuItem(
                          value: RoomMapDoorSide.bottom,
                          child: Text('아래'),
                        ),
                        DropdownMenuItem(
                          value: RoomMapDoorSide.left,
                          child: Text('왼쪽'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) onChangedDoor(value);
                      },
                    ),
                  ),
                ],
              ),
              if (selected.type == RoomMapItemType.utility) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<RoomMapFacilityKind>(
                  key: ValueKey(
                      'facility-${selected.id}-${selected.facilityKind.name}'),
                  initialValue: selected.facilityKind,
                  decoration: const InputDecoration(
                    labelText: '시설 종류',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RoomMapFacilityKind.none,
                      child: Text('일반 시설'),
                    ),
                    DropdownMenuItem(
                      value: RoomMapFacilityKind.toilet,
                      child: Text('화장실'),
                    ),
                    DropdownMenuItem(
                      value: RoomMapFacilityKind.extinguisher,
                      child: Text('소화기'),
                    ),
                    DropdownMenuItem(
                      value: RoomMapFacilityKind.waterPurifier,
                      child: Text('정수기'),
                    ),
                    DropdownMenuItem(
                      value: RoomMapFacilityKind.microwave,
                      child: Text('전자렌지'),
                    ),
                    DropdownMenuItem(
                      value: RoomMapFacilityKind.fridge,
                      child: Text('냉장고'),
                    ),
                    DropdownMenuItem(
                      value: RoomMapFacilityKind.vacuum,
                      child: Text('청소기'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onChangedFacilityKind(value);
                  },
                ),
              ],
              const SizedBox(height: 8),
              DropdownButtonFormField<RoomMapDoorPosition>(
                key: ValueKey(
                    'door-position-${selected.id}-${selected.doorPosition.name}-${selected.doorSide.name}'),
                initialValue: selected.doorPosition,
                decoration: const InputDecoration(
                  labelText: '문 상세',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _doorPositionItems(selected.doorSide),
                onChanged: selected.doorSide == RoomMapDoorSide.none
                    ? null
                    : (value) {
                        if (value != null) onChangedDoorPosition(value);
                      },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SizeStepper(
                      label: '가로',
                      value: selected.width,
                      onChanged: (value) =>
                          onSizeChanged(value, selected.height),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SizeStepper(
                      label: '세로',
                      value: selected.height,
                      onChanged: (value) =>
                          onSizeChanged(selected.width, value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SizeStepper(
                label: '글씨',
                value: selected.fontSize,
                min: 8,
                max: 28,
                onChanged: onFontSizeChanged,
              ),
              const SizedBox(height: 8),
              _NudgePad(onNudge: onNudge),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AlignButton(
                      icon: Icons.vertical_align_top,
                      label: '위 맞춤',
                      onPressed: () => onAlign(_AlignAction.top),
                    ),
                    _AlignButton(
                      icon: Icons.vertical_align_bottom,
                      label: '아래 맞춤',
                      onPressed: () => onAlign(_AlignAction.bottom),
                    ),
                    _AlignButton(
                      icon: Icons.format_align_left,
                      label: '왼쪽 맞춤',
                      onPressed: () => onAlign(_AlignAction.left),
                    ),
                    _AlignButton(
                      icon: Icons.format_align_right,
                      label: '오른쪽 맞춤',
                      onPressed: () => onAlign(_AlignAction.right),
                    ),
                    _AlignButton(
                      icon: Icons.swap_horiz,
                      label: '가로 같게',
                      onPressed: () => onAlign(_AlignAction.width),
                    ),
                    _AlignButton(
                      icon: Icons.swap_vert,
                      label: '세로 같게',
                      onPressed: () => onAlign(_AlignAction.height),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DropdownMenuItem<RoomMapDoorPosition>> _doorPositionItems(
    RoomMapDoorSide side,
  ) {
    final labels = switch (side) {
      RoomMapDoorSide.left || RoomMapDoorSide.right => const {
          RoomMapDoorPosition.start: '위',
          RoomMapDoorPosition.center: '가운데',
          RoomMapDoorPosition.end: '아래',
        },
      RoomMapDoorSide.top || RoomMapDoorSide.bottom => const {
          RoomMapDoorPosition.start: '왼쪽',
          RoomMapDoorPosition.center: '가운데',
          RoomMapDoorPosition.end: '오른쪽',
        },
      RoomMapDoorSide.none => const {
          RoomMapDoorPosition.start: '시작',
          RoomMapDoorPosition.center: '가운데',
          RoomMapDoorPosition.end: '끝',
        },
    };

    return RoomMapDoorPosition.values.map((position) {
      return DropdownMenuItem(
        value: position,
        child: Text(labels[position]!),
      );
    }).toList();
  }
}

class _RoomDropdown extends StatelessWidget {
  final RoomMapItem item;
  final List<Room> rooms;
  final ValueChanged<Room?> onChanged;

  const _RoomDropdown({
    required this.item,
    required this.rooms,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = item.type == RoomMapItemType.room;
    final selectedRoomId =
        rooms.any((room) => room.roomId == item.roomId) ? item.roomId : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('room-${item.id}-$selectedRoomId-${rooms.length}'),
      initialValue: selectedRoomId,
      decoration: const InputDecoration(
        labelText: '연결 방',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('선택 안 함'),
        ),
        ...rooms.map((room) {
          return DropdownMenuItem<String>(
            value: room.roomId,
            child: Text(
              room.name,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: enabled
          ? (roomId) {
              if (roomId == null || roomId.isEmpty) {
                onChanged(null);
                return;
              }
              for (final room in rooms) {
                if (room.roomId == roomId) {
                  onChanged(room);
                  return;
                }
              }
            }
          : null,
    );
  }
}

class _AlignButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _AlignButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        ),
      ),
    );
  }
}

class _NudgePad extends StatelessWidget {
  final void Function(double dx, double dy) onNudge;

  const _NudgePad({required this.onNudge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '위치',
          style:
              TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151)),
        ),
        const SizedBox(width: 8),
        _NudgeButton(
          icon: Icons.keyboard_arrow_left,
          tooltip: '왼쪽으로 1 이동',
          onPressed: () => onNudge(-1, 0),
        ),
        _NudgeButton(
          icon: Icons.keyboard_arrow_up,
          tooltip: '위로 1 이동',
          onPressed: () => onNudge(0, -1),
        ),
        _NudgeButton(
          icon: Icons.keyboard_arrow_down,
          tooltip: '아래로 1 이동',
          onPressed: () => onNudge(0, 1),
        ),
        _NudgeButton(
          icon: Icons.keyboard_arrow_right,
          tooltip: '오른쪽으로 1 이동',
          onPressed: () => onNudge(1, 0),
        ),
        const SizedBox(width: 8),
        Text(
          '1px',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NudgeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton.outlined(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      ),
    );
  }
}

class _SizeStepper extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SizeStepper({
    required this.label,
    required this.value,
    this.min = 24,
    this.max = 500,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFBDBDBD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label ${value.round()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => onChanged((value - 1).clamp(min, max).toDouble()),
            icon: const Icon(Icons.remove, size: 18),
          ),
          IconButton(
            onPressed: () => onChanged((value + 1).clamp(min, max).toDouble()),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
