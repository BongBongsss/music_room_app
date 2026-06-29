import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room_app/models/room.dart';
import 'package:music_room_app/models/room_map_layout.dart';
import 'package:music_room_app/services/room_service.dart';
import 'package:music_room_app/services/settings_service.dart';
import 'package:music_room_app/widgets/room_map_view.dart';

final roomMapRoomsProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(roomServiceProvider).getRooms();
});

final roomMapLayoutProvider = StreamProvider<RoomMapLayout>((ref) {
  return ref.watch(settingsServiceProvider).watchRoomMapLayout();
});

class RoomMapScreen extends ConsumerWidget {
  const RoomMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomMapRoomsProvider);
    final layoutAsync = ref.watch(roomMapLayoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('연습실 안내도'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: '홈',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF6F7F4),
      body: roomsAsync.when(
        data: (rooms) => layoutAsync.when(
          data: (layout) => Column(
            children: [
              const _Legend(),
              Expanded(
                child: _MapViewport(layout: layout, rooms: rooms),
              ),
              _FacilityLegend(layout: layout),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  '방을 누르면 상세 정보를 볼 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('안내도 설정을 불러오지 못했습니다.\n$error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('방 정보를 불러오지 못했습니다.\n$error')),
      ),
    );
  }
}

class _MapViewport extends StatelessWidget {
  final RoomMapLayout layout;
  final List<Room> rooms;

  const _MapViewport({
    required this.layout,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = layout.fitToWidth ? 24.0 : 0.0;
        final maxWidth = constraints.maxWidth - horizontalPadding;
        final scale = layout.fitToWidth && maxWidth > 0
            ? (maxWidth / layout.width).clamp(0.75, 1.8).toDouble()
            : 1.0;
        final scaledWidth = layout.width * scale;
        final scaledHeight = layout.height * scale;
        final viewportWidth = constraints.maxWidth > scaledWidth
            ? constraints.maxWidth
            : scaledWidth;
        final viewportHeight = constraints.maxHeight > scaledHeight
            ? constraints.maxHeight
            : scaledHeight;

        return InteractiveViewer(
          minScale: 0.75,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(80),
          constrained: false,
          child: SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: scaledWidth,
                height: scaledHeight,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: RoomMapView(layout: layout, rooms: rooms),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FacilityLegend extends StatelessWidget {
  final RoomMapLayout layout;

  const _FacilityLegend({required this.layout});

  @override
  Widget build(BuildContext context) {
    final kinds = <RoomMapFacilityKind>[];
    for (final item in layout.items) {
      final kind = facilityKindForItem(item);
      if (kind != RoomMapFacilityKind.none && !kinds.contains(kind)) {
        kinds.add(kind);
      }
    }

    if (kinds.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: kinds.map((kind) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE3E8EF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FacilityMapIcon(kind: kind, size: 17),
                const SizedBox(width: 5),
                Text(
                  _facilityLabel(kind),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _facilityLabel(RoomMapFacilityKind kind) {
    return switch (kind) {
      RoomMapFacilityKind.none => '',
      RoomMapFacilityKind.toilet => '화장실',
      RoomMapFacilityKind.extinguisher => '소화기',
      RoomMapFacilityKind.waterPurifier => '정수기',
      RoomMapFacilityKind.microwave => '전자렌지',
      RoomMapFacilityKind.fridge => '냉장고',
      RoomMapFacilityKind.vacuum => '청소기',
    };
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: const [
          _LegendItem(color: Color(0xFFDDF3E4), label: '공실'),
          _LegendItem(color: Color(0xFFF1F5F9), label: '계약중'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E8EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1A000000)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}
