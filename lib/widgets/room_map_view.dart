import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/room_map_layout.dart';

class VacantPulseScope extends StatefulWidget {
  final Widget child;

  const VacantPulseScope({
    super.key,
    required this.child,
  });

  static double valueOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_VacantPulseData>()
            ?.value ??
        0;
  }

  @override
  State<VacantPulseScope> createState() => _VacantPulseScopeState();
}

class _VacantPulseScopeState extends State<VacantPulseScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return _VacantPulseData(
          value: Curves.easeInOut.transform(_controller.value),
          child: child!,
        );
      },
    );
  }
}

class _VacantPulseData extends InheritedWidget {
  final double value;

  const _VacantPulseData({
    required this.value,
    required super.child,
  });

  @override
  bool updateShouldNotify(_VacantPulseData oldWidget) {
    return oldWidget.value != value;
  }
}

class RoomMapView extends StatelessWidget {
  final RoomMapLayout layout;
  final List<Room> rooms;
  final bool editable;
  final bool showTitle;
  final double itemYOffset;
  final Widget Function(BuildContext context, RoomMapItem item, Room? room)?
      roomContentBuilder;
  final String? selectedItemId;
  final ValueChanged<String>? onSelectItem;
  final VoidCallback? onClearSelection;
  final void Function(String id, Offset delta)? onMoveItem;

  const RoomMapView({
    super.key,
    required this.layout,
    required this.rooms,
    this.editable = false,
    this.showTitle = true,
    this.itemYOffset = 0,
    this.roomContentBuilder,
    this.selectedItemId,
    this.onSelectItem,
    this.onClearSelection,
    this.onMoveItem,
  });

  @override
  Widget build(BuildContext context) {
    final items = [...layout.items]..sort(_paintOrder);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editable ? onClearSelection : null,
      child: Container(
        width: layout.width,
        height: layout.height,
        decoration: BoxDecoration(
          color: const Color(0xFFFEFEFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD8DEE4), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (showTitle && layout.title.trim().isNotEmpty)
              Positioned(
                left: 12,
                right: 12,
                top: 14,
                child: _MapTitle(
                  title: layout.title.trim(),
                ),
              ),
            ...items.map((item) {
              return _MapItemWidget(
                key: ValueKey(item.id),
                item: item,
                room: _findRoom(rooms, item),
                editable: editable,
                yOffset: itemYOffset,
                roomContentBuilder: roomContentBuilder,
                selected: selectedItemId == item.id,
                onSelect:
                    onSelectItem == null ? null : () => onSelectItem!(item.id),
                onMove: onMoveItem == null
                    ? null
                    : (delta) => onMoveItem!(item.id, delta),
              );
            }),
          ],
        ),
      ),
    );
  }

  int _paintOrder(RoomMapItem a, RoomMapItem b) {
    int rank(RoomMapItem item) {
      return switch (item.type) {
        RoomMapItemType.corridor => 0,
        RoomMapItemType.utility => 1,
        RoomMapItemType.room => 2,
        RoomMapItemType.entrance => 3,
      };
    }

    return rank(a).compareTo(rank(b));
  }

  Room? _findRoom(List<Room> rooms, RoomMapItem item) {
    if (item.roomId != null && item.roomId!.isNotEmpty) {
      for (final room in rooms) {
        if (room.roomId == item.roomId) return room;
      }
    }

    final number = item.roomNumber;
    if (number == null) return null;
    for (final room in rooms) {
      final idMatch = RegExp(r'(\d+)$').firstMatch(room.roomId);
      if (idMatch != null && int.tryParse(idMatch.group(1)!) == number) {
        return room;
      }

      final nameMatch =
          RegExp(r'(^|\D)(\d{1,2})(번|호|호실|$)').firstMatch(room.name);
      if (nameMatch != null && int.tryParse(nameMatch.group(2)!) == number) {
        return room;
      }
    }
    return null;
  }
}

class _MapTitle extends StatelessWidget {
  final String title;

  const _MapTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
    );

    if (!title.contains('공실')) {
      return Text(
        title,
        textAlign: TextAlign.center,
        style: style.copyWith(color: const Color(0xFF1F2937)),
      );
    }

    final pulse = VacantPulseScope.valueOf(context);
    return Text(
      title,
      textAlign: TextAlign.center,
      style: style.copyWith(
        color: Color.lerp(
          const Color(0xFF287A4B),
          const Color(0xFF55A96F),
          pulse,
        ),
      ),
    );
  }
}

class _MapItemWidget extends StatelessWidget {
  final RoomMapItem item;
  final Room? room;
  final bool editable;
  final double yOffset;
  final Widget Function(BuildContext context, RoomMapItem item, Room? room)?
      roomContentBuilder;
  final bool selected;
  final VoidCallback? onSelect;
  final ValueChanged<Offset>? onMove;

  const _MapItemWidget({
    super.key,
    required this.item,
    required this.room,
    required this.editable,
    this.yOffset = 0,
    this.roomContentBuilder,
    required this.selected,
    this.onSelect,
    this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorsFor(item, room);
    final child = Positioned(
      left: item.x,
      top: item.y + yOffset,
      width: item.width,
      height: item.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: editable
            ? () {
                onSelect?.call();
              }
            : item.type == RoomMapItemType.room && room != null
                ? () => context.push('/rooms/${room!.roomId}')
                : null,
        onPanStart: editable ? (_) => onSelect?.call() : null,
        onPanUpdate: editable ? (details) => onMove?.call(details.delta) : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _MapItemSurface(
              item: item,
              room: room,
              selected: selected,
              colors: color,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: roomContentBuilder != null &&
                        item.type == RoomMapItemType.room
                    ? roomContentBuilder!(context, item, room)
                    : _DefaultMapItemContent(
                        item: item,
                        room: room,
                        color: color.foreground,
                      ),
              ),
            ),
            _DoorGap(side: item.doorSide, position: item.doorPosition),
          ],
        ),
      ),
    );

    return child;
  }
}

class _MapItemSurface extends StatelessWidget {
  final RoomMapItem item;
  final Room? room;
  final bool selected;
  final _MapItemColors colors;
  final Widget child;

  const _MapItemSurface({
    required this.item,
    required this.room,
    required this.selected,
    required this.colors,
    required this.child,
  });

  bool get _isVacantRoom =>
      item.type == RoomMapItemType.room && room?.status == 'vacant';

  @override
  Widget build(BuildContext context) {
    final pulse = VacantPulseScope.valueOf(context);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _isVacantRoom
            ? Color.lerp(
                const Color(0xFFDDF3E4),
                const Color(0xFFC4EACF),
                pulse,
              )
            : colors.background,
        borderRadius: BorderRadius.circular(
          item.type == RoomMapItemType.corridor ? 2 : 5,
        ),
        border: Border.all(
          color: selected ? const Color(0xFF2563EB) : colors.border,
          width: selected ? 2.2 : colors.borderWidth,
        ),
        boxShadow: item.type == RoomMapItemType.room
            ? const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

class _DefaultMapItemContent extends StatelessWidget {
  final RoomMapItem item;
  final Room? room;
  final Color color;

  const _DefaultMapItemContent({
    required this.item,
    required this.room,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.type == RoomMapItemType.entrance)
            const Icon(
              Icons.door_front_door_outlined,
              size: 18,
              color: Color(0xFF1F2937),
            ),
          if (_facilityKind(item) != RoomMapFacilityKind.none)
            FacilityMapIcon(
              kind: _facilityKind(item),
              size: (item.fontSize + 8).clamp(18, 30).toDouble(),
            )
          else
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: item.fontSize,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.15,
              ),
            ),
          if (room != null &&
              item.type == RoomMapItemType.room &&
              room!.dimensions.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                room!.dimensions.trim(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: (item.fontSize - 4).clamp(8, 14).toDouble(),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4B5563),
                  height: 1.1,
                ),
              ),
            ),
          if (room == null && item.type == RoomMapItemType.room)
            const Text(
              '미등록',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
        ],
      ),
    );
  }
}

class FacilityMapIcon extends StatelessWidget {
  final RoomMapFacilityKind kind;
  final double size;

  const FacilityMapIcon({
    super.key,
    required this.kind,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      RoomMapFacilityKind.toilet => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.woman, size: size, color: const Color(0xFFE53935)),
            Icon(Icons.man, size: size, color: const Color(0xFF1D4ED8)),
          ],
        ),
      RoomMapFacilityKind.extinguisher => Icon(
          Icons.fire_extinguisher,
          size: size,
          color: const Color(0xFFDC2626),
        ),
      RoomMapFacilityKind.waterPurifier => Icon(
          Icons.water_drop_outlined,
          size: size,
          color: const Color(0xFF0284C7),
        ),
      RoomMapFacilityKind.microwave => Icon(
          Icons.microwave_outlined,
          size: size,
          color: const Color(0xFFF97316),
        ),
      RoomMapFacilityKind.fridge => Icon(
          Icons.kitchen_outlined,
          size: size,
          color: const Color(0xFF0891B2),
        ),
      RoomMapFacilityKind.vacuum => Icon(
          Icons.cleaning_services,
          size: size,
          color: const Color(0xFF7C3AED),
        ),
      RoomMapFacilityKind.none => const SizedBox.shrink(),
    };
  }
}

RoomMapFacilityKind facilityKindForItem(RoomMapItem item) {
  if (item.type != RoomMapItemType.utility) return RoomMapFacilityKind.none;
  if (item.facilityKind != RoomMapFacilityKind.none) return item.facilityKind;
  final label = item.label.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  if (label.contains('wc') ||
      label.contains('화장실') ||
      label.contains('toilet')) {
    return RoomMapFacilityKind.toilet;
  }
  if (label.contains('전자렌지') ||
      label.contains('전자레인지') ||
      label.contains('렌지') ||
      label.contains('레인지') ||
      label.contains('microwave')) {
    return RoomMapFacilityKind.microwave;
  }
  if (label.contains('정수기') || label.contains('water')) {
    return RoomMapFacilityKind.waterPurifier;
  }
  if (label.contains('냉장고') ||
      label.contains('냉장') ||
      label.contains('fridge')) {
    return RoomMapFacilityKind.fridge;
  }
  if (label.contains('소화기') || label.contains('extinguisher')) {
    return RoomMapFacilityKind.extinguisher;
  }
  if (label.contains('청소기') || label.contains('vacuum')) {
    return RoomMapFacilityKind.vacuum;
  }
  return RoomMapFacilityKind.none;
}

RoomMapFacilityKind _facilityKind(RoomMapItem item) =>
    facilityKindForItem(item);

class _MapItemColors {
  final Color background;
  final Color border;
  final Color foreground;
  final double borderWidth;

  const _MapItemColors({
    required this.background,
    required this.border,
    required this.foreground,
    this.borderWidth = 1,
  });
}

_MapItemColors _colorsFor(RoomMapItem item, Room? room) {
  return switch (item.type) {
    RoomMapItemType.corridor => const _MapItemColors(
        background: Color(0xFFF5F1E8),
        border: Color(0xFFE4DDD0),
        foreground: Color(0xFF8A8172),
        borderWidth: 0.8,
      ),
    RoomMapItemType.entrance => const _MapItemColors(
        background: Colors.white,
        border: Color(0xFF9CA3AF),
        foreground: Color(0xFF1F2937),
        borderWidth: 1,
      ),
    RoomMapItemType.utility => const _MapItemColors(
        background: Colors.white,
        border: Color(0xFFD1D5DB),
        foreground: Color(0xFF374151),
        borderWidth: 1,
      ),
    RoomMapItemType.room => _MapItemColors(
        background: room?.status == 'vacant'
            ? const Color(0xFFDDF3E4)
            : const Color(0xFFF1F5F9),
        border: room?.status == 'vacant'
            ? const Color(0xFF6CB982)
            : const Color(0xFFCBD5E1),
        foreground: const Color(0xFF1F2937),
        borderWidth: 1.1,
      ),
  };
}

class _DoorGap extends StatelessWidget {
  final RoomMapDoorSide side;
  final RoomMapDoorPosition position;

  const _DoorGap({
    required this.side,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    if (side == RoomMapDoorSide.none) return const SizedBox.shrink();

    return Positioned.fill(
      child: CustomPaint(
        painter: _DoorPainter(side, position),
      ),
    );
  }
}

class _DoorPainter extends CustomPainter {
  final RoomMapDoorSide side;
  final RoomMapDoorPosition position;

  const _DoorPainter(this.side, this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final gapPaint = Paint()
      ..color = const Color(0xFF667085)
      ..style = PaintingStyle.fill;

    const markerStroke = 3.0;
    const margin = 8.0;
    final horizontalDoorLength = (size.width - margin * 2).clamp(12.0, 20.0);
    final verticalDoorLength = (size.height - margin * 2).clamp(12.0, 20.0);

    switch (side) {
      case RoomMapDoorSide.top:
        final left = _axisOffset(size.width, horizontalDoorLength);
        canvas.drawRect(
          Rect.fromLTWH(left, 0, horizontalDoorLength, markerStroke),
          gapPaint,
        );
        break;
      case RoomMapDoorSide.right:
        final top = _axisOffset(size.height, verticalDoorLength);
        canvas.drawRect(
          Rect.fromLTWH(
            size.width - markerStroke,
            top,
            markerStroke,
            verticalDoorLength,
          ),
          gapPaint,
        );
        break;
      case RoomMapDoorSide.bottom:
        final left = _axisOffset(size.width, horizontalDoorLength);
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            size.height - markerStroke,
            horizontalDoorLength,
            markerStroke,
          ),
          gapPaint,
        );
        break;
      case RoomMapDoorSide.left:
        final top = _axisOffset(size.height, verticalDoorLength);
        canvas.drawRect(
          Rect.fromLTWH(0, top, markerStroke, verticalDoorLength),
          gapPaint,
        );
        break;
      case RoomMapDoorSide.none:
        break;
    }
  }

  double _axisOffset(double total, double marker) {
    const inset = 8.0;
    return switch (position) {
      RoomMapDoorPosition.start => inset.clamp(0.0, total - marker).toDouble(),
      RoomMapDoorPosition.center =>
        ((total - marker) / 2).clamp(0.0, total - marker).toDouble(),
      RoomMapDoorPosition.end =>
        (total - marker - inset).clamp(0.0, total - marker).toDouble(),
    };
  }

  @override
  bool shouldRepaint(covariant _DoorPainter oldDelegate) {
    return oldDelegate.side != side || oldDelegate.position != position;
  }
}
