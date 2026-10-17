import 'package:sqflite/sqflite.dart';
import '../core/constants.dart';
import 'database_service.dart';

/// Local Fact Memory Engine (Mem0 Pattern)
class MemoryService {
  final DatabaseService _dbService;

  MemoryService({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  /// Extract and store fact into local memory
  Future<void> saveFact(String id, String factText, {String category = 'general'}) async {
    final sanitizedFact = AppConstants.sanitizeText(factText);

    final db = _dbService.database;
    await db.insert(
      'memories',
      {
        'id': id,
        'fact': sanitizedFact,
        'category': category,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update existing fact memory (MEM-002)
  Future<void> updateMemory(String id, String newFact, {required String category}) async {
    final sanitizedFact = AppConstants.sanitizeText(newFact);
    final db = _dbService.database;
    await db.update(
      'memories',
      {
        'fact': sanitizedFact,
        'category': category,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Token-based Jaccard similarity for deduplication (MEM-003)
  static double calculateSimilarity(String s1, String s2) {
    final words1 = s1.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    final words2 = s2.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 2).toSet();
    if (words1.isEmpty || words2.isEmpty) return 0.0;
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    return union > 0 ? (intersection / union) : 0.0;
  }

  /// Check if an equivalent memory already exists (MEM-003)
  Future<Map<String, dynamic>?> findDuplicate(String candidateFact, {double threshold = 0.75}) async {
    final existing = await getMemories();
    for (final mem in existing) {
      final text = mem['fact'] as String? ?? '';
      if (calculateSimilarity(text, candidateFact) >= threshold) {
        return mem;
      }
    }
    return null;
  }

  /// Save fact with automated semantic deduplication (MEM-003)
  Future<String> saveFactWithDedup(String factText, {String category = 'general'}) async {
    final dup = await findDuplicate(factText);
    if (dup != null) {
      // Update existing record with refined wording
      final existingId = dup['id'] as String;
      await updateMemory(existingId, factText, category: category);
      return existingId;
    } else {
      final newId = 'mem-${DateTime.now().millisecondsSinceEpoch}';
      await saveFact(newId, factText, category: category);
      return newId;
    }
  }

  /// Retrieve stored facts
  Future<List<Map<String, dynamic>>> getMemories({String? category}) async {
    final db = _dbService.database;
    if (category != null && category.isNotEmpty) {
      return db.query('memories', where: 'category = ?', whereArgs: [category], orderBy: 'created_at DESC');
    }
    return db.query('memories', orderBy: 'created_at DESC');
  }

  /// Delete fact memory ("Forget Fact")
  Future<void> deleteMemory(String id) async {
    final db = _dbService.database;
    await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }
}
