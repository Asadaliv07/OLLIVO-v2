import 'package:flutter/material.dart';
import '../../components/ollivo_components.dart';
import '../../services/task_service.dart';
import '../../theme.dart';

class TasksView extends StatefulWidget {
  final TaskService taskService;
  final Function(String prompt)? onAskOllivo;

  const TasksView({
    super.key,
    required this.taskService,
    this.onAskOllivo,
  });

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final TextEditingController _taskInputController = TextEditingController();
  List<TaskItem> _tasks = [];
  bool _isLoading = false;
  String _selectedFilter = 'all'; // 'all', 'todo', 'in_progress', 'completed'
  String _selectedPriority = 'medium';
  DateTime? _selectedNewTaskDueDate;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _taskInputController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.taskService.getTasks(statusFilter: _selectedFilter);
      setState(() {
        _tasks = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addNewTask() async {
    final title = _taskInputController.text.trim();
    if (title.isEmpty) return;

    _taskInputController.clear();
    final newTask = TaskItem(
      id: 'task-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      status: 'todo',
      priority: _selectedPriority,
      dueDate: _selectedNewTaskDueDate?.millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() => _selectedNewTaskDueDate = null);
    await widget.taskService.createTask(newTask);
    await _loadTasks();
  }

  Future<void> _cycleTaskStatus(TaskItem task) async {
    String nextStatus;
    if (task.status == 'todo') {
      nextStatus = 'in_progress';
    } else if (task.status == 'in_progress') {
      nextStatus = 'completed';
    } else {
      nextStatus = 'todo';
    }
    await widget.taskService.updateTaskStatus(task.id, nextStatus);
    await _loadTasks();
  }

  Future<void> _pickDueDateForNewTask() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedNewTaskDueDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: OllivoTheme.oliveEmerald,
            surface: OllivoTheme.surfaceDark,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedNewTaskDueDate = picked);
    }
  }

  Future<void> _pickDueDateForTask(TaskItem task) async {
    final now = DateTime.now();
    final initialDate = task.dueDate != null ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!) : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: OllivoTheme.oliveEmerald,
            surface: OllivoTheme.surfaceDark,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      await widget.taskService.updateTaskDueDate(task.id, picked.millisecondsSinceEpoch);
      await _loadTasks();
    }
  }

  Future<void> _deleteTask(String id) async {
    await widget.taskService.deleteTask(id);
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Task Input Bar & Settings
        OllivoCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OllivoTextField(
                      controller: _taskInputController,
                      hintText: 'Add an action item or project milestone...',
                      onSubmitted: (_) => _addNewTask(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Due date selector for new task (TSK-002)
                  OutlinedButton.icon(
                    onPressed: _pickDueDateForNewTask,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _selectedNewTaskDueDate != null ? OllivoTheme.oliveEmerald : OllivoTheme.textSecondaryDark,
                      side: BorderSide(
                        color: _selectedNewTaskDueDate != null ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      _selectedNewTaskDueDate != null
                          ? '${_selectedNewTaskDueDate!.month}/${_selectedNewTaskDueDate!.day}'
                          : 'Due Date',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_selectedNewTaskDueDate != null) ...[
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: OllivoTheme.textSecondaryDark),
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() => _selectedNewTaskDueDate = null),
                    ),
                  ],
                  const SizedBox(width: 10),
                  OllivoPrimaryButton(
                    label: 'Add Task',
                    icon: Icons.add_task,
                    onPressed: _addNewTask,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Priority: ', style: TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark)),
                  const SizedBox(width: 8),
                  _buildPriorityChip('low', 'Low', Colors.blue),
                  const SizedBox(width: 6),
                  _buildPriorityChip('medium', 'Medium', OllivoTheme.oliveEmerald),
                  const SizedBox(width: 6),
                  _buildPriorityChip('high', 'High', OllivoTheme.statusError),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter Tabs Row (TSK-003)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildFilterChip('all', 'All Tasks'),
                const SizedBox(width: 8),
                _buildFilterChip('todo', 'To Do'),
                const SizedBox(width: 8),
                _buildFilterChip('in_progress', 'In Progress'),
                const SizedBox(width: 8),
                _buildFilterChip('completed', 'Completed'),
              ],
            ),
            Text(
              '${_tasks.where((t) => t.isCompleted).length} / ${_tasks.length} Completed',
              style: const TextStyle(fontSize: 13, color: OllivoTheme.textSecondaryDark),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Task List
        Expanded(
          child: _isLoading
              ? const OllivoLoadingIndicator(label: 'Loading task list...')
              : _tasks.isEmpty
                  ? OllivoCard(
                      child: OllivoEmptyState(
                        icon: Icons.task_alt_outlined,
                        title: 'No tasks found',
                        description: 'Add a new action item above or generate tasks automatically from AI conversations.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final isDone = task.isCompleted;
                        final isInProgress = task.isInProgress;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: OllivoCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                // 3-state Status Toggle Button (TSK-003)
                                IconButton(
                                  icon: Icon(
                                    isDone
                                        ? Icons.check_circle_rounded
                                        : isInProgress
                                            ? Icons.timelapse_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                    color: isDone
                                        ? OllivoTheme.oliveEmerald
                                        : isInProgress
                                            ? Colors.orangeAccent
                                            : OllivoTheme.textSecondaryDark,
                                    size: 22,
                                  ),
                                  tooltip: isDone
                                      ? 'Completed (Click to reset)'
                                      : isInProgress
                                          ? 'In Progress (Click to complete)'
                                          : 'To Do (Click to start)',
                                  onPressed: () => _cycleTaskStatus(task),
                                ),
                                const SizedBox(width: 8),

                                // Title and Meta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                          color: isDone
                                              ? OllivoTheme.textSecondaryDark
                                              : OllivoTheme.textPrimaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          // Status Label
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isDone
                                                      ? OllivoTheme.oliveEmerald
                                                      : isInProgress
                                                          ? Colors.orangeAccent
                                                          : OllivoTheme.textSecondaryDark)
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              task.status.replaceAll('_', ' ').toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: isDone
                                                    ? OllivoTheme.oliveEmerald
                                                    : isInProgress
                                                        ? Colors.orangeAccent
                                                        : OllivoTheme.textSecondaryDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // Due Date Pill (TSK-002)
                                          if (task.dueDate != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: task.isOverdue
                                                    ? OllivoTheme.statusError.withValues(alpha: 0.15)
                                                    : OllivoTheme.cardDark,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: task.isOverdue
                                                      ? OllivoTheme.statusError.withValues(alpha: 0.4)
                                                      : OllivoTheme.borderDark,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.schedule,
                                                    size: 11,
                                                    color: task.isOverdue
                                                        ? OllivoTheme.statusError
                                                        : OllivoTheme.textSecondaryDark,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    task.relativeDueDate ?? '',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                                                      color: task.isOverdue
                                                          ? OllivoTheme.statusError
                                                          : OllivoTheme.textSecondaryDark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Priority Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getPriorityColor(task.priority).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _getPriorityColor(task.priority).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    task.priority.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getPriorityColor(task.priority),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // Set Due Date Action (TSK-002)
                                IconButton(
                                  icon: const Icon(Icons.event_outlined, size: 17, color: OllivoTheme.textSecondaryDark),
                                  tooltip: 'Set Due Date',
                                  onPressed: () => _pickDueDateForTask(task),
                                ),

                                // "Ask Ollivo" Action Item Planner
                                if (widget.onAskOllivo != null) ...[
                                  IconButton(
                                    icon: const Icon(Icons.auto_awesome, size: 17, color: OllivoTheme.oliveEmerald),
                                    tooltip: 'Ask Ollivo to break down this task',
                                    onPressed: () => widget.onAskOllivo!(
                                      'Help me plan and execute this task: "${task.title}". Provide clear steps and recommendations.',
                                    ),
                                  ),
                                ],

                                // Delete Action
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: OllivoTheme.textSecondaryDark),
                                  tooltip: 'Delete task',
                                  onPressed: () => _deleteTask(task.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPriorityChip(String pKey, String label, Color color) {
    final isSelected = _selectedPriority == pKey;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : OllivoTheme.textSecondaryDark)),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.3),
      backgroundColor: OllivoTheme.surfaceDark,
      side: BorderSide(color: isSelected ? color : OllivoTheme.borderDark),
      onSelected: (val) => setState(() => _selectedPriority = pKey),
    );
  }

  Widget _buildFilterChip(String fKey, String label) {
    final isSelected = _selectedFilter == fKey;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: OllivoTheme.oliveEmerald.withValues(alpha: 0.2),
      checkmarkColor: OllivoTheme.oliveEmerald,
      backgroundColor: OllivoTheme.cardDark,
      side: BorderSide(color: isSelected ? OllivoTheme.oliveEmerald : OllivoTheme.borderDark),
      onSelected: (val) {
        setState(() => _selectedFilter = fKey);
        _loadTasks();
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return OllivoTheme.statusError;
      case 'medium':
        return OllivoTheme.oliveEmerald;
      case 'low':
        return Colors.blue;
      default:
        return OllivoTheme.oliveEmerald;
    }
  }
}
