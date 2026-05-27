import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_room_app/models/notice.dart';
import 'package:music_room_app/services/notice_service.dart';

class NoticeEditScreen extends ConsumerStatefulWidget {
  final Notice? notice;
  const NoticeEditScreen({super.key, this.notice});

  @override
  ConsumerState<NoticeEditScreen> createState() => _NoticeEditScreenState();
}

class _NoticeEditScreenState extends ConsumerState<NoticeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late bool _isPinned;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.notice?.title ?? '');
    _contentController = TextEditingController(text: widget.notice?.content ?? '');
    _isPinned = widget.notice?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNotice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final noticeService = ref.read(noticeServiceProvider);
      if (widget.notice == null) {
        // 등록
        final newNotice = Notice(
          noticeId: '', // Firestore add에서 자동 생성됨
          title: _titleController.text,
          content: _contentController.text,
          isPinned: _isPinned,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await noticeService.addNotice(newNotice);
      } else {
        // 수정
        final updatedNotice = Notice(
          noticeId: widget.notice!.noticeId,
          title: _titleController.text,
          content: _contentController.text,
          isPinned: _isPinned,
          createdAt: widget.notice!.createdAt,
          updatedAt: DateTime.now(),
        );
        await noticeService.updateNotice(updatedNotice);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 공지사항을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && widget.notice != null) {
      setState(() => _isLoading = true);
      try {
        await ref.read(noticeServiceProvider).deleteNotice(widget.notice!.noticeId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 오류: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.notice != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '공지사항 수정' : '공지사항 등록'),
        actions: [
          if (isEdit)
            IconButton(
              onPressed: _isLoading ? null : _deleteNotice,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          IconButton(
            onPressed: _isLoading ? null : _saveNotice,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? '제목을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: '내용',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                    validator: (value) => (value == null || value.isEmpty) ? '내용을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('상단 고정'),
                    subtitle: const Text('중요 공지로 표시하고 목록 상단에 고정합니다.'),
                    value: _isPinned,
                    onChanged: (value) => setState(() => _isPinned = value),
                  ),
                ],
              ),
            ),
    );
  }
}
