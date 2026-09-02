import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance =
      DatabaseService._internal();

  DatabaseService._internal();

  factory DatabaseService() {
    return instance;
  }

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      'lm_inspect.db',
    );

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inspections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productName TEXT NOT NULL,
            inspectionDate TEXT NOT NULL,
            extractedText TEXT,
            score INTEGER,
            violationCount INTEGER,
            imagePath TEXT,
            evidenceKey TEXT,
            officerId TEXT,
            location TEXT,
            officerRemarks TEXT,
            verified INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE inspections ADD COLUMN evidenceKey TEXT',
          );

          await db.execute(
            'ALTER TABLE inspections ADD COLUMN officerId TEXT',
          );

          await db.execute(
            'ALTER TABLE inspections ADD COLUMN location TEXT',
          );

          await db.execute(
            'ALTER TABLE inspections ADD COLUMN officerRemarks TEXT',
          );

          await db.execute(
            'ALTER TABLE inspections ADD COLUMN verified INTEGER DEFAULT 0',
          );
        }
      },
    );
  }

  // ============================================================
  // SAVE INSPECTION
  // ============================================================

  Future<int> saveInspection({
    required String productName,
    required String inspectionDate,
    required String extractedText,
    required int score,
    required int violationCount,
    required String imagePath,

    // New fields are optional so existing code continues working.
    String? evidenceKey,
    String? officerId,
    String? location,
    String? officerRemarks,
    bool verified = false,
  }) async {
    final db = await database;

    return db.insert(
      'inspections',
      {
        'productName': productName,
        'inspectionDate': inspectionDate,
        'extractedText': extractedText,
        'score': score,
        'violationCount': violationCount,
        'imagePath': imagePath,
        'evidenceKey': evidenceKey,
        'officerId': officerId,
        'location': location,
        'officerRemarks': officerRemarks,
        'verified': verified ? 1 : 0,
      },
    );
  }

  // ============================================================
  // DUPLICATE CHECK
  // ============================================================

  Future<bool> isDuplicateInspection({
    required String imagePath,
    String? extractedText,
    String? evidenceKey,
  }) async {
    final db = await database;

    // First check the generated evidence key when available.
    if (evidenceKey != null &&
        evidenceKey.trim().isNotEmpty) {
      final result = await db.query(
        'inspections',
        columns: ['id'],
        where: 'evidenceKey = ?',
        whereArgs: [evidenceKey],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return true;
      }
    }

    // Also check the original evidence image path.
    if (imagePath.trim().isNotEmpty) {
      final result = await db.query(
        'inspections',
        columns: ['id'],
        where: 'imagePath = ?',
        whereArgs: [imagePath],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return true;
      }
    }

    // Finally compare OCR text for repeated identical evidence.
    if (extractedText != null &&
        extractedText.trim().isNotEmpty) {
      final result = await db.query(
        'inspections',
        columns: ['id'],
        where: 'extractedText = ?',
        whereArgs: [extractedText.trim()],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // GET INSPECTIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getInspections() async {
    final db = await database;

    return db.query(
      'inspections',
      orderBy: 'id DESC',
    );
  }

  // ============================================================
  // GET SINGLE INSPECTION
  // ============================================================

  Future<Map<String, dynamic>?> getInspection(
    int id,
  ) async {
    final db = await database;

    final result = await db.query(
      'inspections',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first;
  }

  // ============================================================
  // DASHBOARD COUNTS
  // ============================================================

  Future<int> getInspectionCount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM inspections',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getViolationCount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(violationCount), 0) as count '
      'FROM inspections',
    );

    return (result.first['count'] as int?) ?? 0;
  }

  // ============================================================
  // VERIFIED INSPECTIONS
  // ============================================================

  Future<int> getVerifiedInspectionCount() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count '
      'FROM inspections '
      'WHERE verified = 1',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<int> deleteInspection(int id) async {
    final db = await database;

    return db.delete(
      'inspections',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<List<Map<String, dynamic>>> searchInspections(
    String query,
  ) async {
    final db = await database;

    final search = '%${query.trim()}%';

    return db.query(
      'inspections',
      where: '''
        productName LIKE ?
        OR extractedText LIKE ?
        OR officerId LIKE ?
        OR location LIKE ?
      ''',
      whereArgs: [
        search,
        search,
        search,
        search,
      ],
      orderBy: 'id DESC',
    );
  }
}