import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class TaskItem {
  final String id;
  final String title;
  final String? description;
  final String status; // 'todo', 'in_progress', 'completed'
  final String priority; // 'low', 'medium', 'high'
  final int? dueDate;
  final int createdAt;

  TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.status = 'todo',
    this.priority = 'medium',
    this.dueDate,
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isTodo => status == 'todo';

  /// Human-readable relative due date label (TSK-002)
  String? get relativeDueDate {
    if (dueDate == null) return null;
    final due = DateTime.fromMillisecondsSinceEpoch(dueDate!);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    final diffDays = target.difference(today).inDays;

    if (diffDays < 0) return 'Overdue';
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Tomorrow';
    if (diffDays < 7) return 'In $diffDays days';
    return '${due.month}/${due.day}/${due.year}';
  }

  /// Check whether task is past due date and uncompleted
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    final due = DateTime.fromMillisecondsSinceEpoch(dueDate!);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    return target.isBefore(today);
  }

  factory TaskItem.fromMap(Map<String, dynamic> map) {
    return TaskItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'todo',
      priority: map['priority'] as String? ?? 'medium',
      dueDate: map['due_date'] as int?,
      createdAt: map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'due_date': dueDate,
      'created_at': createdAt,
    };
  }
}

class TaskService {
  final DatabaseService _dbService;

  TaskService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Create a new task item
  Future<void> createTask(TaskItem task) async {
    final db = _dbService.database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch create multiple tasks (TSK-001)
  Future<void> batchCreateTasks(List<TaskItem> tasks) async {
    final db = _dbService.database;
    final batch = db.batch();
    for (final task in tasks) {
      batch.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Parse actionable tasks from natural language or markdown text (TSK-001)
  static List<TaskItem> parseTasksFromText(String text) {
    final List<TaskItem> parsed = [];
    final lines = text.split('\n');

    final actionRegex = RegExp(
      r'^(?:[-*•]\s*(?:\[\s*\]\s*)?|\d+\.\s*)(.+)$',
      caseSensitive: false,
    );

    int count = 0;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final match = actionRegex.firstMatch(line);
      if (match != null) {
        String title = match.group(1)?.trim() ?? '';
        // Strip bold markdown markers if any
        title = title.replaceAll(RegExp(r'\*\*|__'), '').trim();
        if (title.length < 3) continue;

        // Auto-detect priority
        final lower = title.toLowerCase();
        String priority = 'medium';
        if (lower.contains('urgent') ||
            lower.contains('critical') ||
            lower.contains('blocker') ||
            lower.contains('immediately') ||
            lower.contains('high priority') ||
            lower.contains('p0')) {
          priority = 'high';
        } else if (lower.contains('optional') ||
            lower.contains('minor') ||
            lower.contains('consider') ||
            lower.contains('low priority') ||
            lower.contains('nice to have')) {
          priority = 'low';
        }

        count++;
        parsed.add(TaskItem(
          id: 'task-ai-${DateTime.now().millisecondsSinceEpoch}-$count',
          title: title,
          priority: priority,
          status: 'todo',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
    return parsed;
  }

  /// Get list of tasks with optional status filter (TSK-003)
  Future<List<TaskItem>> getTasks({String? statusFilter}) async {
    final db = _dbService.database;
    final List<Map<String, dynamic>> maps;
    if (statusFilter != null && statusFilter != 'all') {
      maps = await db.query(
        'tasks',
        where: 'status = ?',
        whereArgs: [statusFilter],
        orderBy: 'created_at DESC',
      );
    } else {
      maps = await db.query('tasks', orderBy: 'created_at DESC');
    }
    return maps.map((m) => TaskItem.fromMap(m)).toList();
  }

  /// Update task status: 'todo', 'in_progress', 'completed' (TSK-003)
  Future<void> updateTaskStatus(String id, String newStatus) async {
    final db = _dbService.database;
    await db.update(
      'tasks',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggle task completion (backward-compatible)
  Future<void> toggleTaskStatus(String id, bool completed) async {
    await updateTaskStatus(id, completed ? 'completed' : 'todo');
  }

  /// Update task due date (TSK-002)
  Future<void> updateTaskDueDate(String id, int? dueDate) async {
    final db = _dbService.database;
    await db.update(
      'tasks',
      {'due_date': dueDate},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete task
  Future<void> deleteTask(String id) async {
    final db = _dbService.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}
