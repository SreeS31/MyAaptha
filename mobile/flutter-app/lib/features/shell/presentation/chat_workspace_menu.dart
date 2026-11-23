import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class ChatWorkspaceMenu extends StatefulWidget {
  const ChatWorkspaceMenu(
      {super.key,
      required this.api,
      required this.kind,
      required this.target,
      required this.onSearch,
      required this.onSelect,
      required this.onCleared,
      required this.onTheme,
      this.onInfo,
      this.onAdd});
  final MyAapthaApi api;
  final String kind;
  final int target;
  final VoidCallback onSearch, onSelect, onCleared;
  final ValueChanged<String> onTheme;
  final VoidCallback? onInfo, onAdd;
  @override
  State<ChatWorkspaceMenu> createState() => _ChatWorkspaceMenuState();
}

class _ChatWorkspaceMenuState extends State<ChatWorkspaceMenu> {
  Map<String, dynamic>? options;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final value = await widget.api.chatOptions(widget.kind, widget.target);
      if (mounted) {
        setState(() => options = value);
        widget.onTheme(value['theme'] as String? ?? 'DEFAULT');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (c) =>
              AlertDialog(title: Text(title), content: Text(text), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Confirm'))
              ])) ??
      false;
  Future<String?> choose(String title, Map<String, String> choices) =>
      showDialog<String>(
          context: context,
          builder: (c) => SimpleDialog(title: Text(title), children: [
                for (final entry in choices.entries)
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(c, entry.key),
                      child: Text(entry.value))
              ]));
  Future<void> run(String action) async {
    if (busy) return;
    if (action == 'info') {
      widget.onInfo?.call();
      return;
    }
    if (action == 'add') {
      widget.onAdd?.call();
      return;
    }
    if (action == 'search') {
      widget.onSearch();
      return;
    }
    if (action == 'select') {
      widget.onSelect();
      return;
    }
    if (action == 'close') {
      Navigator.pop(context);
      return;
    }
    setState(() => busy = true);
    try {
      await refresh();
      if (!mounted) return;
      Map<String, dynamic>? change;
      if (action == 'mute') {
        final value = await choose('Mute notifications', {
          '0': 'Unmute',
          '28800': '8 hours',
          '604800': '1 week',
          '2147483647': 'Always'
        });
        if (value != null) change = {'muteSeconds': int.parse(value)};
      }
      if (action == 'timer') {
        if (options?['canManage'] != true) {
          throw StateError('Only circle admins can change the timer');
        }
        final value = await choose('Disappearing messages (new messages)', {
          '0': 'Off',
          '86400': '24 hours',
          '604800': '7 days',
          '7776000': '90 days'
        });
        if (value != null) change = {'disappearingSeconds': int.parse(value)};
      }
      if (action == 'theme') {
        final value = await choose('Chat theme', {
          'DEFAULT': 'Default',
          'SAGE': 'Sage',
          'OCEAN': 'Ocean',
          'ROSE': 'Rose',
          'DARK': 'Dark'
        });
        if (value != null) change = {'theme': value};
      }
      if (action == 'favourite') {
        change = {'favourite': options?['favourite'] != true};
      }
      if (action == 'list') {
        if (!mounted) return;
        final text =
            TextEditingController(text: options?['listName'] as String? ?? '');
        final value = await showDialog<String>(
            context: context,
            builder: (c) => AlertDialog(
                    title: const Text('Add to list'),
                    content: TextField(
                        controller: text,
                        maxLength: 60,
                        decoration: const InputDecoration(
                            labelText: 'List name (blank to remove)')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, text.text.trim()),
                          child: const Text('Save'))
                    ]));
        text.dispose();
        if (value != null) change = {'listName': value};
      }
      if (change != null) {
        final next = await widget.api
            .saveChatOptions(widget.kind, widget.target, change);
        if (mounted) {
          setState(() => options = next);
          widget.onTheme(next['theme'] as String? ?? 'DEFAULT');
        }
      }
      if (action == 'clear' &&
          await confirm('Clear chat?',
              'Remove existing messages for you. Other members keep their messages.')) {
        await widget.api.clearChat(widget.kind, widget.target);
        widget.onCleared();
      }
      if (action == 'export' &&
          await confirm('Export chat',
              'Save your visible text history and attachment names as JSON. Media files are not included.')) {
        final rows = await widget.api.exportChat(widget.kind, widget.target);
        await FilePicker.platform.saveFile(
            dialogTitle: 'Export chat',
            fileName: 'MyAaptha-chat.json',
            type: FileType.custom,
            allowedExtensions: ['json'],
            bytes: Uint8List.fromList(utf8.encode(jsonEncode({
              'exportedAt': DateTime.now().toUtc().toIso8601String(),
              'messages': rows
            }))));
      }
      if (action == 'exit') {
        int? successor;
        if (options?['creator'] == true && options?['solo'] != true) {
          final circle = (await widget.api.circles())
              .firstWhere((c) => c.id == widget.target);
          final choices = {
            for (final m in circle.members.where((m) => m.admin && !m.creator))
              '${m.person.id}': m.person.displayName
          };
          if (choices.isEmpty) {
            throw StateError(
                'Make another member an admin in Circle info before exiting');
          }
          if (!mounted) return;
          final value = await choose('Transfer creator role', choices);
          if (value == null) return;
          successor = int.parse(value);
        }
        if (!mounted) return;
        if (await confirm(
            'Exit circle?',
            options?['solo'] == true
                ? 'You are the only member. This removes the circle and its messages. Your private contacts are kept.'
                : 'You will lose access to this circle and its calls.')) {
          await widget.api.exitCircle(widget.target, successor,
              deleteEmptyCircle: options?['solo'] == true);
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
      tooltip: widget.kind == 'CIRCLE' ? 'Circle options' : 'Contact options',
      enabled: !busy,
      onSelected: run,
      itemBuilder: (_) => [
            if (widget.kind == 'CIRCLE' &&
                options?['canManage'] == true &&
                widget.onAdd != null)
              const PopupMenuItem(value: 'add', child: Text('Add member')),
            if (widget.onInfo != null)
              PopupMenuItem(
                  value: 'info',
                  child: Text(widget.kind == 'CIRCLE'
                      ? 'Circle info'
                      : 'Contact info')),
            const PopupMenuItem(value: 'search', child: Text('Search')),
            const PopupMenuItem(
                value: 'select', child: Text('Select messages')),
            const PopupMenuItem(
                value: 'mute', child: Text('Mute notifications')),
            const PopupMenuItem(
                value: 'timer', child: Text('Disappearing messages')),
            const PopupMenuItem(value: 'theme', child: Text('Chat theme')),
            PopupMenuItem(
                value: 'favourite',
                child: Text(options?['favourite'] == true
                    ? 'Remove from favourites'
                    : 'Add to favourites')),
            const PopupMenuItem(value: 'list', child: Text('Add to list')),
            const PopupMenuItem(value: 'export', child: Text('Export chat')),
            const PopupMenuItem(value: 'close', child: Text('Close chat')),
            const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            if (widget.kind == 'CIRCLE')
              const PopupMenuItem(value: 'exit', child: Text('Exit circle'))
          ]);
}
