import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Todoscreen extends StatefulWidget {
  const Todoscreen({super.key});

  @override
  State<Todoscreen> createState() => _TodoscreenState();
}

class _TodoscreenState extends State<Todoscreen> {
  static const _storageKey = 'todo_tasks';
  static const _filters = ['All', 'Pending', 'Completed'];

  final _searchController = TextEditingController();
  List<_TodoTask> _tasks = [];
  String _selectedFilter = 'All';
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTasks = preferences.getString(_storageKey);
    var loadedTasks = _sampleTasks;

    if (savedTasks != null) {
      try {
        final decoded = jsonDecode(savedTasks);
        if (decoded is! List) {
          throw const FormatException('Saved tasks are not a list.');
        }
        loadedTasks = decoded.map(_TodoTask.fromJson).toList();
      } on FormatException {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadError = 'Saved tasks could not be read.';
          });
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _tasks = loadedTasks;
      _isLoading = false;
    });
  }

  List<_TodoTask> get _sampleTasks => [
    _TodoTask(
      id: 'sample-learn-flutter',
      title: 'Learn Flutter',
      description: 'Complete Stateful Widget',
      priority: 'High',
      createdAt: DateTime.now(),
    ),
    _TodoTask(
      id: 'sample-create-ui',
      title: 'Create UI Design',
      description: 'Design Todo App screen',
      priority: 'Low',
      isCompleted: true,
      createdAt: DateTime.now(),
    ),
    _TodoTask(
      id: 'sample-practice-dart',
      title: 'Practice Dart',
      description: 'Practice List and Map',
      priority: 'Medium',
      createdAt: DateTime.now(),
    ),
  ];

  List<_TodoTask> get _visibleTasks {
    final query = _searchController.text.trim().toLowerCase();
    return _tasks.where((task) {
      final matchesFilter = switch (_selectedFilter) {
        'Pending' => !task.isCompleted,
        'Completed' => task.isCompleted,
        _ => true,
      };
      final matchesSearch =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  int get _completedCount => _tasks.where((task) => task.isCompleted).length;
  int get _pendingCount => _tasks.length - _completedCount;

  Future<void> _saveTasks() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(_tasks.map((task) => task.toJson()).toList()),
    );
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tasks could not be saved on this device.')),
      );
    }
  }

  void _retryLoadTasks() {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _loadTasks();
  }

  Future<void> _showTaskDialog({_TodoTask? task}) async {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    var selectedPriority = task?.priority ?? 'Low';
    var titleError = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task == null ? 'Add New Task' : 'Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Task title',
                    hintText: 'What do you need to do?',
                    prefixIcon: const Icon(Icons.task_alt_rounded),
                    errorText: titleError ? 'Please enter a task title' : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    if (titleError) {
                      setDialogState(() => titleError = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add a few details',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedPriority,
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    prefixIcon: const Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedPriority = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  setDialogState(() => titleError = true);
                  return;
                }

                final updatedTask = task == null
                    ? _TodoTask(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        title: title,
                        description: descriptionController.text.trim(),
                        priority: selectedPriority,
                        createdAt: DateTime.now(),
                      )
                    : task.copyWith(
                        title: title,
                        description: descriptionController.text.trim(),
                        priority: selectedPriority,
                      );
                setState(() {
                  if (task == null) {
                    _tasks.insert(0, updatedTask);
                  } else {
                    final index = _tasks.indexWhere(
                      (item) => item.id == task.id,
                    );
                    if (index != -1) _tasks[index] = updatedTask;
                  }
                });
                Navigator.of(dialogContext).pop();
                await _saveTasks();
              },
              child: Text(task == null ? 'Add task' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));
    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _toggleTask(_TodoTask task, bool completed) async {
    setState(() {
      final index = _tasks.indexWhere((item) => item.id == task.id);
      if (index != -1) {
        _tasks[index] = task.copyWith(isCompleted: completed);
      }
    });
    await _saveTasks();
  }

  Future<void> _deleteTask(_TodoTask task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    await _saveTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Tasks',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Stay organized, stay productive',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear search',
                    onPressed: _searchController.text.isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                            setState(() {});
                          },
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total',
                      value: _tasks.length,
                      icon: Icons.list_alt_rounded,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'Completed',
                      value: _completedCount,
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending',
                      value: _pendingCount,
                      icon: Icons.access_time_rounded,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  return ChoiceChip(
                    label: Text(filter),
                    selected: _selectedFilter == filter,
                    onSelected: (_) => setState(() => _selectedFilter = filter),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Today’s Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_visibleTasks.length} tasks',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _retryLoadTasks,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _visibleTasks.isEmpty
                  ? _EmptyTasks(hasTasks: _tasks.isNotEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: _visibleTasks.length,
                      itemBuilder: (context, index) {
                        final task = _visibleTasks[index];
                        return _TaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onToggle: (completed) =>
                              _toggleTask(task, completed),
                          onEdit: () => _showTaskDialog(task: task),
                          onDelete: () => _deleteTask(task),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: _isLoading ? null : () => _showTaskDialog(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

class _TodoTask {
  const _TodoTask({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.createdAt,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String description;
  final String priority;
  final DateTime createdAt;
  final bool isCompleted;

  _TodoTask copyWith({
    String? title,
    String? description,
    String? priority,
    bool? isCompleted,
  }) {
    return _TodoTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'priority': priority,
    'createdAt': createdAt.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory _TodoTask.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid task data.');
    }
    final id = value['id'];
    final title = value['title'];
    final description = value['description'];
    final priority = value['priority'];
    final createdAt = value['createdAt'];
    final isCompleted = value['isCompleted'];
    if (id is! String ||
        title is! String ||
        description is! String ||
        priority is! String ||
        createdAt is! String ||
        isCompleted is! bool) {
      throw const FormatException('Invalid task fields.');
    }
    final parsedDate = DateTime.tryParse(createdAt);
    if (parsedDate == null || !['Low', 'Medium', 'High'].contains(priority)) {
      throw const FormatException('Invalid task values.');
    }
    return _TodoTask(
      id: id,
      title: title,
      description: description,
      priority: priority,
      createdAt: parsedDate,
      isCompleted: isCompleted,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 7),
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.hasTasks});

  final bool hasTasks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 64,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            hasTasks ? 'No matching tasks' : 'No tasks yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            hasTasks
                ? 'Try changing your search or filter'
                : 'Add a task to get started',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final _TodoTask task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (task.priority) {
      'High' => Colors.red,
      'Medium' => Colors.orange,
      _ => Colors.green,
    };
    final dateLabel = task.createdAt.year == DateTime.now().year &&
            task.createdAt.month == DateTime.now().month &&
            task.createdAt.day == DateTime.now().day
        ? 'Today'
        : '${task.createdAt.day}/${task.createdAt.month}/${task.createdAt.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: ValueKey('complete-${task.id}'),
            value: task.isCompleted,
            onChanged: (value) => onToggle(value ?? false),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 7, bottom: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: task.isCompleted ? Colors.grey : Colors.black87,
                    ),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: task.isCompleted
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.priority,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: priorityColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      Text(
                        task.isCompleted ? 'Completed' : dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Task options',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
