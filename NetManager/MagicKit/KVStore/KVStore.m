

#import "KVStore.h"
#import <libkern/OSAtomic.h>
#import <time.h>
#import <UIKit/UIKit.h>

#if __has_include(<sqlite3.h>)
#import <sqlite3.h>
#else
#import "sqlite3.h"
#endif



// 静态变量
static NSString *const kDBFileName = @"KVStore.sqlite";
static NSString *const kDBShmFileName = @"KVStore.sqlite-shm"; //内存共享索引文件
static NSString *const kDBWalFileName = @"KVStore.sqlite-wal"; //数据库操作日志文件
static NSString *const kDataDirectoryName = @"KVStoreData";
static NSString *const kTrashDirectoryName = @"KVStoreTrash"; //被淘汰的数据会被首先存放在这里，确认不再使用时移除。(在后台线程中执行)


@implementation KVStoreItem

@end


@implementation KVStore{
    dispatch_queue_t _trashQueue;
    
    NSString *_path;
    NSString *_dbPath;
    NSString *_dataPath;
    NSString *_trashPath;
    
    
    sqlite3 *_db;
    CFMutableDictionaryRef _dbStmtCache;
    
    BOOL _invalidated; // 当为YES时，数据库不会被再次打开，所有读写操作将被忽略
    BOOL _dbIsClosing;  // 数据库是否正在关闭中
    OSSpinLock _dbStateLock;  //锁
}


#pragma mark --   Database  Operation

- (BOOL)openDB{
    BOOL shouldOpen = YES;
    
    //加锁
    OSSpinLockLock(&_dbStateLock);
    
    // 检查当前状态是否应该打开数据库
    if (_invalidated) {
        shouldOpen = NO;
    }else if (_dbIsClosing){
        shouldOpen = NO;
    }else if (_db){
        shouldOpen = NO;
    }
    
    //解锁
    OSSpinLockUnlock(&_dbStateLock);
    
    if (!shouldOpen) {
        return YES;
    }
    
    int result = sqlite3_open(_dbPath.UTF8String, &_db);
    if (result == SQLITE_OK) {
        
        //句柄缓存
        //取出数据表中的key、value进行缓存，以便后续使用时快速使用
        CFDictionaryKeyCallBacks keyCallBacks = kCFTypeDictionaryKeyCallBacks;
        CFDictionaryValueCallBacks valueCallBacks = {0};
        _dbStmtCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &keyCallBacks, &valueCallBacks);
        
        return YES;
    }else{
        NSLog(@"%s line:%d sqlite open failed (%d).", __FUNCTION__, __LINE__, result);
        return NO;
    }
}


- (BOOL)closeDB{
    BOOL needClose = YES;
    
    //加锁
    OSSpinLockLock(&_dbStateLock);
    
    if (!_db) {
        needClose = NO;
    }else if (_invalidated){
        needClose = NO;
    }else if (_dbIsClosing){
        needClose = NO;
    }else{
        needClose = YES;
    }
    
    //解锁
    OSSpinLockUnlock(&_dbStateLock);
    
    
    if (!needClose) {
        return YES;
    }
    
    int result = 0;
    BOOL retry = NO;
    BOOL stmtFinalized = NO;
    
    //释放句柄缓存
    if(_dbStmtCache){
        CFRelease(_dbStmtCache);
        _dbStmtCache = NULL;
    }
    
    do {
        
        retry = NO;
        result = sqlite3_close(_db);
        
        if (result == SQLITE_BUSY || result == SQLITE_LOCKED) {
            if (!stmtFinalized) {
                stmtFinalized = YES;
                sqlite3_stmt *stmt;
                while (stmt == sqlite3_next_stmt(_db, nil) != 0) {
                    sqlite3_finalize(stmt);
                    retry = YES;
                }
            }
        }else if (result != SQLITE_OK){
            NSLog(@"%s line:%d sqlite close failed (%d).", __FUNCTION__, __LINE__, result);
        }
        
    } while (retry);
    
    _db = NULL;
    
    OSSpinLockLock(&_dbStateLock);
    _dbIsClosing = NO;
    OSSpinLockUnlock(&_dbStateLock);
    
    return YES;
}

- (BOOL)dbIsReady {
    return (_db && !_dbIsClosing && !_invalidated);
}

- (BOOL)dbInitialize {
    NSString *sql = @"pragma journal_mode = wal; pragma synchronous = normal; create table if not exists KVStore (key text, filename text, size integer, inline_data blob, modification_time integer, last_access_time integer, extended_data blob, primary key(key)); create index if not exists last_access_time_idx on KVStore(last_access_time);";
    return [self dbExecute:sql];
}

- (BOOL)dbExecute:(NSString *)sql{
    if (sql.length == 0) {
        return NO;
    }
    
    if (![self dbIsReady]) {
        return NO;
    }
    
    char *error = NULL;
    int result = sqlite3_exec(_db, sql.UTF8String, NULL, NULL, &error);
    if (error) {
        if (_errorLogsEnabled) {
             NSLog(@"%s line:%d sqlite exec error (%d): %s", __FUNCTION__, __LINE__, result, error);
        }
        sqlite3_free(error);
    }
    return result == SQLITE_OK;
}

//句柄准备
- (sqlite3_stmt *)dbPrepareStmt:(NSString *)sql{
    if (![self dbIsReady]) {
        return NULL;
    }
    
    sqlite3_stmt *stmt = (sqlite3_stmt *)CFDictionaryGetValue(_dbStmtCache, (__bridge const void *)(sql));
    //如果没有缓存，则新建
    if (!stmt) {
        int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
        if (result != SQLITE_OK) {
            if (_errorLogsEnabled) {
                NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            }
            return NULL;
        }
        
        CFDictionarySetValue(_dbStmtCache, (__bridge const void *)(sql), stmt);
    }else{
        sqlite3_reset(stmt);
    }
    return stmt;
}

//bind value  with  value type
- (BOOL)dbSaveWithKey:(NSString *)key value:(NSData *)value fileName:(NSString *)fileName extentionData:(NSData *)exData {
    NSString *sql = @"insert or replace into KVStore (key, filename, size, inline_data, modification_time, last_access_time, extended_data) values (?1, ?2, ?3, ?4, ?5, ?6, ?7);";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) {
        return NO;
    }
    
    int timestamp = (int)time(NULL);
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 2, fileName.UTF8String, -1, NULL);
    sqlite3_bind_int(stmt, 3, (int)value.length);
    if (fileName.length == 0) {
        sqlite3_bind_blob(stmt, 4, value.bytes, (int)value.length, 0);
    }else{
        sqlite3_bind_blob(stmt, 4, NULL, 0, 0);
    }
    
    sqlite3_bind_int(stmt, 5, timestamp);
    sqlite3_bind_int(stmt, 6, timestamp);
    sqlite3_bind_blob(stmt, 7, exData.bytes, (int)exData.length, 0);
    
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite insert error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    return YES;
}


- (BOOL)updateAccessTimeWithKey:(NSString *)key{
    NSString *sql = @"update KVStore set last_access_time = ?1 where key = ?2;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) {
        return NO;
    }
    
    sqlite3_bind_int(stmt, 1, (int)time(NULL));
    sqlite3_bind_text(stmt, 2, key.UTF8String, -1, NULL);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite update error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    return YES;
}


- (BOOL)updateAccessTimeWithKeys:(NSArray *)keys{
    
    if (![self dbIsReady]) {
        return NO;
    }
    int timestamp = (int)time(NULL);
    NSString *sql = [NSString stringWithFormat:@"update KVStore set last_access_time = %d where key in (%@);", timestamp, [keys componentsJoinedByString:@","]];
    
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    
    result = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled){
            NSLog(@"%s line:%d sqlite update error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    return YES;
}

- (BOOL)deleteItemWithKey:(NSString *)key{
    NSString *sql = @"delete from KVStore where key = ?1;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return NO;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d db delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    return YES;
}

- (BOOL)deleteItemsWithKeys:(NSArray *)keys{
    if (![self dbIsReady]) {
        return NO;
    }
    NSString *sql =  [NSString stringWithFormat:@"delete from KVStore where key in (%@);", [keys componentsJoinedByString:@","]];
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled){
            NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    
    result = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    if (result == SQLITE_ERROR) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    return YES;
}

- (BOOL)deleteItemsWithSizeLargerThan:(int)size {
    NSString *sql = @"delete from KVStore where size > ?1;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return NO;
    sqlite3_bind_int(stmt, 1, size);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    return YES;
}

- (BOOL)deleteItemsWithTimeEarlierThan:(int)time {
    NSString *sql = @"delete from KVStore where last_access_time < ?1;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return NO;
    sqlite3_bind_int(stmt, 1, time);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return NO;
    }
    return YES;
}


- (KVStoreItem *)getItemFromStmt:(sqlite3_stmt *)stmt excludeInlineData:(BOOL)excludeInlineData{
    int i = 0;
    char *key = (char *)sqlite3_column_text(stmt, i++);
    char *filename = (char *)sqlite3_column_text(stmt, i++);
    int size = sqlite3_column_int(stmt, i++);
    const void *inline_data = excludeInlineData ? NULL : sqlite3_column_blob(stmt, i);
    int inline_data_bytes = excludeInlineData ? 0 : sqlite3_column_bytes(stmt, i++);
    int modification_time = sqlite3_column_int(stmt, i++);
    int last_access_time = sqlite3_column_int(stmt, i++);
    const void *extended_data = sqlite3_column_blob(stmt, i);
    int extended_data_bytes = sqlite3_column_bytes(stmt, i++);
    
    KVStoreItem *item = [KVStoreItem new];
    if (key) {
        item.key = [NSString stringWithUTF8String:key];
    }
    if (filename && *filename != 0) {
        item.fileName = [NSString stringWithUTF8String:filename];
    }
    item.size = size;
    if (inline_data_bytes > 0 && inline_data) {
        item.value = [NSData dataWithBytes:inline_data length:inline_data_bytes];
    }
    item.modTime = modification_time;
    item.accessTime = last_access_time;
    if (extended_data_bytes > 0 && extended_data) {
        item.extentionData = [NSData dataWithBytes:extended_data length:extended_data_bytes];
    }
    return item;
}



- (KVStoreItem *)getItemWithKey:(NSString *)key excludeInlineData:(BOOL)excludeInlinData {
    NSString *sql = excludeInlinData ? @"select key, filename, size, modification_time, last_access_time, extended_data from KVStore where key = ?1;" : @"select key, filename, size, inline_data, modification_time, last_access_time, extended_data from KVStore where key = ?1;";

    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) {
        return nil;
    }
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    
    KVStoreItem *item = nil;
    int result = sqlite3_step(stmt);
    if (result == SQLITE_ROW) {
        item = [self getItemFromStmt:stmt excludeInlineData:excludeInlinData];
    }else{
        if (result != SQLITE_DONE) {
            if (_errorLogsEnabled){
                NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            }
        }
    }
    return item;
}


- (NSMutableArray *)getItemWithKeys:(NSArray *)keys excludeInlineData:(BOOL)excludeInlineData {
    if (![self dbIsReady]) {
        return nil;
    }
    
    //分开创建sql语句，并且指定所查找的字段，目的是为了提高查找效率
    NSString *sql;
    if (excludeInlineData) {
        sql = [NSString stringWithFormat:@"select key, filename, size, modification_time, last_access_time, extended_data from KVStore where key in (%@);", [keys componentsJoinedByString:@","]];
    } else {
        sql = [NSString stringWithFormat:@"select key, filename, size, inline_data, modification_time, last_access_time, extended_data from KVStore where key in (%@)", [keys componentsJoinedByString:@","]];
    }
    
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return nil;
    }
    
    NSMutableArray *items = [NSMutableArray new];
    do {
        result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            KVStoreItem *item = [self getItemFromStmt:stmt excludeInlineData:excludeInlineData];
            if (item) [items addObject:item];
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) {
                NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            }
            items = nil;
            break;
        }
    } while (1);
    sqlite3_finalize(stmt);
    return items;
}


- (NSData *)getValueWithKey:(NSString *)key{
    NSString *sql = @"select inline_data from KVStore where key = ?1;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) {
        return nil;
    }
    
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    
    int result = sqlite3_step(stmt);
    if (result == SQLITE_ROW) {
        const void *inline_data = sqlite3_column_blob(stmt, 0);
        int inline_data_bytes = sqlite3_column_bytes(stmt, 0);
        if (!inline_data || inline_data_bytes <= 0) {
            return nil;
        }
        return [NSData dataWithBytes:inline_data length:inline_data_bytes];
    }else{
        if (result != SQLITE_DONE) {
            if (_errorLogsEnabled) {
                NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            }
        }
        return nil;
    }
}

- (NSString *)getFilenameWithKey:(NSString *)key {
    NSString *sql = @"select filename from KVStore where key = ?1;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    int result = sqlite3_step(stmt);
    if (result == SQLITE_ROW) {
        char *filename = (char *)sqlite3_column_text(stmt, 0);
        if (filename && *filename != 0) {
            return [NSString stringWithUTF8String:filename];
        }
    } else {
        if (result != SQLITE_DONE) {
            if (_errorLogsEnabled) {
                NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            }
        }
    }
    return nil;
}

- (NSMutableArray *)getFilenameWithKeys:(NSArray *)keys {
    if (![self dbIsReady]) return nil;
    NSString *sql = [NSString stringWithFormat:@"select filename from KVStore where key in (%@);", [keys componentsJoinedByString:@","]];
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return nil;
    }
    
    NSMutableArray *filenames = [NSMutableArray new];
    do {
        result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *filename = (char *)sqlite3_column_text(stmt, 0);
            if (filename && *filename != 0) {
                NSString *name = [NSString stringWithUTF8String:filename];
                if (name) [filenames addObject:name];
            }
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            filenames = nil;
            break;
        }
    } while (1);
    sqlite3_finalize(stmt);
    return filenames;
}

- (NSMutableArray *)getFilenamesWithSizeLargerThan:(int)size {
    NSString *sql = @"select filename from KVStore where size > ?1 and filename is not null;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_int(stmt, 1, size);
    
    NSMutableArray *filenames = [NSMutableArray new];
    do {
        int result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *filename = (char *)sqlite3_column_text(stmt, 0);
            if (filename && *filename != 0) {
                NSString *name = [NSString stringWithUTF8String:filename];
                if (name) [filenames addObject:name];
            }
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            filenames = nil;
            break;
        }
    } while (1);
    return filenames;
}

- (NSMutableArray *)getFilenamesWithTimeEarlierThan:(int)time {
    NSString *sql = @"select filename from KVStore where last_access_time < ?1 and filename is not null;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_int(stmt, 1, time);
    
    NSMutableArray *filenames = [NSMutableArray new];
    do {
        int result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *filename = (char *)sqlite3_column_text(stmt, 0);
            if (filename && *filename != 0) {
                NSString *name = [NSString stringWithUTF8String:filename];
                if (name) [filenames addObject:name];
            }
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            filenames = nil;
            break;
        }
    } while (1);
    return filenames;
}

- (NSMutableArray *)getItemSizeInfoOrderByTimeDescWithLimit:(int)count {
    NSString *sql = @"select key, filename, size from KVStore order by last_access_time desc limit ?1;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_int(stmt, 1, count);
    
    NSMutableArray *items = [NSMutableArray new];
    do {
        int result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *key = (char *)sqlite3_column_text(stmt, 0);
            char *filename = (char *)sqlite3_column_text(stmt, 1);
            int size = sqlite3_column_int(stmt, 2);
            KVStoreItem *item = [KVStoreItem new];
            item.key = key ? [NSString stringWithUTF8String:key] : nil;
            item.fileName = filename ? [NSString stringWithUTF8String:filename] : nil;
            item.size = size;
            [items addObject:item];
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            items = nil;
            break;
        }
    } while (1);
    return items;
}

- (int)getItemCountWithKey:(NSString *)key {
    NSString *sql = @"select count(key) from KVStore where key = ?1;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return -1;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_ROW) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return -1;
    }
    return sqlite3_column_int(stmt, 0);
}

- (int)getTotalItemSize {
    NSString *sql = @"select sum(size) from KVStore;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return -1;
    int result = sqlite3_step(stmt);
    if (result != SQLITE_ROW) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return -1;
    }
    return sqlite3_column_int(stmt, 0);
}

- (int)getTotalItemCount {
    NSString *sql = @"select count(*) from KVStore;";
    sqlite3_stmt *stmt = [self dbPrepareStmt:sql];
    if (!stmt) return -1;
    int result = sqlite3_step(stmt);
    if (result != SQLITE_ROW) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return -1;
    }
    return sqlite3_column_int(stmt, 0);
}


#pragma mark --  File  Operation

- (BOOL)fileWriteWithName:(NSString *)fileName data:(NSData *)data {
    if (_invalidated) {
        return NO;
    }
    
    NSString *path = [_dataPath stringByAppendingPathComponent:fileName];
    return [data writeToFile:path atomically:NO];
}

- (NSData *)fileReadWithName:(NSString *)fileName {
    if (_invalidated) {
        return NO;
    }
    NSString *path = [_dataPath stringByAppendingPathComponent:fileName];
    return [NSData dataWithContentsOfFile:path];
}

- (BOOL)fileDeleteWithName:(NSString *)fileName {
    if (_invalidated) {
        return NO;
    }
    NSString *path = [_dataPath stringByAppendingPathComponent:fileName];
    return [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

- (BOOL)fileMoveAllToTrash {
    if (_invalidated) {
        return NO;
    }
    
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuid = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    
    NSString *tempPath = [_trashPath stringByAppendingPathComponent:(__bridge NSString *)(uuid)];
    BOOL success = [[NSFileManager defaultManager] moveItemAtPath:_dataPath toPath:tempPath error:NULL];
    if (success) {
        success = [[NSFileManager defaultManager] createDirectoryAtPath:_dataPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    CFRelease(uuid);
    return success;
}


- (void)fileEmptyTrashInBackground {
    if (_invalidated) return;
    NSString *trashPath = _trashPath;
    dispatch_queue_t queue = _trashQueue;
    dispatch_async(queue, ^{
        NSFileManager *manager = [NSFileManager new];
        NSArray *directoryContents = [manager contentsOfDirectoryAtPath:trashPath error:NULL];
        for (NSString *path in directoryContents) {
            NSString *fullPath = [trashPath stringByAppendingPathComponent:path];
            [manager removeItemAtPath:fullPath error:NULL];
        }
    });
}

#pragma mark - private

/**
 Delete all files and empty in background.
 Make sure the db is closed.
 */
- (void)reset {
    [[NSFileManager defaultManager] removeItemAtPath:[_path stringByAppendingPathComponent:kDBFileName] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[_path stringByAppendingPathComponent:kDBShmFileName] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[_path stringByAppendingPathComponent:kDBWalFileName] error:nil];
    [self fileMoveAllToTrash];
    [self fileEmptyTrashInBackground];
}

- (void)appWillBeTerminated {
    OSSpinLockLock(&_dbStateLock);
    _invalidated = YES;
    OSSpinLockUnlock(&_dbStateLock);
}



#pragma mark - Public  Methods

- (instancetype)init{
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) firstObject];
    return [self initWithPath:[basePath stringByAppendingPathComponent:@"KVStoreSQLite"] storeType:KVStoreTypeSQLite];
}

- (instancetype)initWithPath:(NSString *)path storeType:(KVStoreType)type{
    if (path.length == 0) {
        NSLog(@"KVStore path: invalid path: [%@].", path);
    }
    
    if (type > KVStoreTypeMixed) {
        NSLog(@"KVStore init error: invalid type: %lu.", (unsigned long)type);
        return nil;
    }
    
    self = [super init];
    
    _path = path.copy;
    _type = type;
    _dataPath = [path stringByAppendingPathComponent:kDataDirectoryName];
    _trashPath = [path stringByAppendingPathComponent:kTrashDirectoryName];
    _trashQueue = dispatch_queue_create("com.kvstore.cache.disk.trash", DISPATCH_QUEUE_SERIAL);
    _dbPath = [path stringByAppendingPathComponent:kDBFileName];
    _dbStateLock = OS_SPINLOCK_INIT;
    _errorLogsEnabled = YES;

    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error] ||
        ![[NSFileManager defaultManager] createDirectoryAtPath:_dataPath withIntermediateDirectories:YES attributes:nil error:&error] ||
        ![[NSFileManager defaultManager] createDirectoryAtPath:_trashPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"KVStore init error:%@", error);
        return nil;
    }
    
    if (![self openDB] || ![self dbInitialize]) {
        [self closeDB];
        [self reset];
        if (![self openDB] || ![self dbInitialize]) {
            [self closeDB];
            NSLog(@"KVStore init error: fail to open sqlite db.");
        }
        return nil;
    }
    
    [self fileEmptyTrashInBackground];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillBeTerminated) name:UIApplicationWillTerminateNotification object:nil];
    
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [self closeDB];
}


- (BOOL)saveItem:(KVStoreItem *)item{
    return [self saveItemWithKey:item.key value:item.value fileName:item.fileName extentionData:item.extentionData];
}

- (BOOL)saveItemWithKey:(NSString *)key value:(NSData *)value{
    return [self saveItemWithKey:key value:value fileName:nil extentionData:nil];
}

- (BOOL)saveItemWithKey:(NSString *)key value:(NSData *)value fileName:(NSString *)fileName extentionData:(NSData *)exData{
    if (key.length == 0 || value.length == 0) {
        return NO;
    }
    
    if (_type == KVStoreTypeFile && fileName.length == 0) {
        return NO;
    }
    
    if (fileName.length) {
        if (![self fileWriteWithName:fileName data:value]) {
            return NO;
        }
        if (![self dbSaveWithKey:key value:value fileName:fileName extentionData:exData]) {
            [self fileDeleteWithName:fileName];
            return NO;
        }
        
        return YES;
    }else{
        if (_type != KVStoreTypeSQLite) {
            NSString *fileName = [self getFilenameWithKey:key];
            if (fileName) {
                [self fileDeleteWithName:fileName];
            }
        }
        return [self dbSaveWithKey:key value:value fileName:fileName extentionData:exData];
    }
}

- (BOOL)removeItemWithKey:(NSString *)key{
    if (key.length == 0) {
        return NO;
    }
    
    switch (_type) {
        case KVStoreTypeSQLite:
            return [self deleteItemWithKey:key];
            break;
        case KVStoreTypeFile:
        case KVStoreTypeMixed:{
            NSString *fileName = [self getFilenameWithKey:key];
            if (fileName) {
                [self fileDeleteWithName:fileName];
            }
            return [self deleteItemWithKey:key];
        }
            break;
        default:
            return NO;
            break;
    }
}

- (BOOL)removeItemWithKeys:(NSArray *)keys{
    if (keys.count == 0) {
        return NO;
    }
    
    switch (_type) {
        case KVStoreTypeSQLite:
            return [self deleteItemsWithKeys:keys];
            break;
        case KVStoreTypeFile:
        case KVStoreTypeMixed:{
            NSArray *fileNames = [self getFilenameWithKeys:keys];
            for (NSString *fileName in fileNames) {
                [self fileDeleteWithName:fileName];
            }
            return [self deleteItemsWithKeys:keys];
        }
            break;
        default:
            return NO;
            break;
    }
}

- (BOOL)removeItemsWhenLargerThanSize:(NSUInteger)size{
    if (size == INT_MAX) {
        return YES;
    }
    if (size <= 0) {
        return [self removeAllItems];
    }
    
    switch (_type) {
        case KVStoreTypeSQLite:
            return [self deleteItemsWithSizeLargerThan:size];
            break;
        case KVStoreTypeFile:
        case KVStoreTypeMixed:{
            NSArray *fileNames = [self getFilenamesWithSizeLargerThan:size];
            for (NSString *fileName in fileNames) {
                [self fileDeleteWithName:fileName];
            }
            return [self deleteItemsWithSizeLargerThan:size];
        }
            break;
        default:
            return NO;
            break;
    }
}

- (BOOL)removeItemsWhenEarlierThanTime:(NSUInteger)time{
    if (time <= 0) return YES;
    if (time == INT_MAX) return [self removeAllItems];
    
    switch (_type) {
        case KVStoreTypeSQLite: {
            return [self deleteItemsWithTimeEarlierThan:time];
        } break;
        case KVStoreTypeFile:
        case KVStoreTypeMixed: {
            NSArray *filenames = [self getFilenamesWithTimeEarlierThan:time];
            for (NSString *name in filenames) {
                [self fileDeleteWithName:name];
            }
            return [self deleteItemsWithTimeEarlierThan:time];
        } break;
    }
    return NO;
}


- (BOOL)removeItemsToFitSize:(NSUInteger)maxSize {
    if (maxSize == INT_MAX) return YES;
    if (maxSize <= 0) return [self removeAllItems];
    
    int total = [self getTotalItemSize];
    if (total < 0) return NO;
    if (total <= maxSize) return YES;
    
    NSArray *items = nil;
    BOOL suc = NO;
    do {
        int perCount = 16;
        items = [self getItemSizeInfoOrderByTimeDescWithLimit:perCount];
        for (KVStoreItem *item in items) {
            if (total > maxSize) {
                if (item.fileName) {
                    [self fileDeleteWithName:item.fileName];
                }
                suc = [self deleteItemWithKey:item.key];
                total -= item.size;
            } else {
                break;
            }
            if (!suc) break;
        }
    } while (total > maxSize && items.count > 0 && suc);
    return suc;
}

- (BOOL)removeItemsToFitCount:(NSUInteger)maxCount {
    if (maxCount == INT_MAX) return YES;
    if (maxCount <= 0) return [self removeAllItems];
    
    int total = [self getTotalItemCount];
    if (total < 0) return NO;
    if (total <= maxCount) return YES;
    
    NSArray *items = nil;
    BOOL suc = NO;
    do {
        int perCount = 16;
        items = [self getItemSizeInfoOrderByTimeDescWithLimit:perCount];
        for (KVStoreItem *item in items) {
            if (total > maxCount) {
                if (item.fileName) {
                    [self fileDeleteWithName:item.fileName];
                }
                suc = [self deleteItemWithKey:item.key];
                total--;
            } else {
                break;
            }
            if (!suc) break;
        }
    } while (total > maxCount && items.count > 0 && suc);
    return suc;
}

- (BOOL)removeAllItems {
    if (![self closeDB]) return NO;
    [self reset];
    if (![self openDB]) return NO;
    if (![self dbInitialize]) return NO;
    return YES;
}

- (void)removeAllItemsWithProgress:(void(^)(NSUInteger removedCount, NSUInteger totalCount))progress finished:(void(^)(BOOL error))finished{
    
    int total = [self getTotalItemCount];
    if (total <= 0) {
        if (finished) finished(total < 0);
    } else {
        int left = total;
        int perCount = 32;
        NSArray *items = nil;
        BOOL suc = NO;
        do {
            items = [self getItemSizeInfoOrderByTimeDescWithLimit:perCount];
            for (KVStoreItem *item in items) {
                if (left > 0) {
                    if (item.fileName) {
                        [self fileDeleteWithName:item.fileName];
                    }
                    suc = [self deleteItemWithKey:item.key];
                    left--;
                } else {
                    break;
                }
                if (!suc) break;
            }
            if (progress) progress(total - left, total);
        } while (left > 0 && items.count > 0 && suc);
        if (finished) finished(!suc);
    }
}

- (KVStoreItem *)getItemForKey:(NSString *)key {
    if (key.length == 0) return nil;
    KVStoreItem *item = [self getItemWithKey:key excludeInlineData:NO];
    if (item) {
        [self updateAccessTimeWithKey:key];
        if (item.fileName) {
            item.value = [self fileReadWithName:item.fileName];
            if (!item.value) {
                [self deleteItemWithKey:key];
                item = nil;
            }
        }
    }
    return item;
}



- (NSData *)getItemValueForKey:(NSString *)key {
    if (key.length == 0) return nil;
    NSData *value = nil;
    switch (_type) {
        case KVStoreTypeFile: {
            NSString *filename = [self getFilenameWithKey:key];
            if (filename) {
                value = [self fileReadWithName:filename];
                if (!value) {
                    [self deleteItemWithKey:key];
                    value = nil;
                }
            }
        } break;
        case KVStoreTypeSQLite: {
            value = [self getValueWithKey:key];
        } break;
        case KVStoreTypeMixed: {
            NSString *filename = [self getFilenameWithKey:key];
            if (filename) {
                value = [self fileReadWithName:filename];
                if (!value) {
                    [self deleteItemWithKey:key];
                    value = nil;
                }
            } else {
                value = [self getValueWithKey:key];
            }
        } break;
    }
    if (value) {
        [self updateAccessTimeWithKey:key];
    }
    return value;
}

- (NSArray *)getItemsForKeys:(NSArray *)keys {
    if (keys.count == 0) return nil;
    NSMutableArray *items = [self getItemWithKeys:keys excludeInlineData:NO];
    if (_type != KVStoreTypeSQLite) {
        for (NSInteger i = 0, max = items.count; i < max; i++) {
            KVStoreItem *item = items[i];
            if (item.fileName) {
                item.value = [self fileReadWithName:item.fileName];
                if (!item.value) {
                    if (item.key) [self deleteItemWithKey:item.key];
                    [items removeObjectAtIndex:i];
                    i--;
                    max--;
                }
            }
        }
    }
    if (items.count > 0) {
        [self updateAccessTimeWithKeys:keys];
    }
    return items.count ? items : nil;
}


- (NSDictionary *)getItemValueForKeys:(NSArray *)keys {
    NSMutableArray *items = (NSMutableArray *)[self getItemsForKeys:keys];
    NSMutableDictionary *kv = [NSMutableDictionary new];
    for (KVStoreItem *item in items) {
        if (item.key && item.value) {
            [kv setObject:item.value forKey:item.key];
        }
    }
    return kv.count ? kv : nil;
}

- (BOOL)itemExistsForKey:(NSString *)key {
    if (key.length == 0) return NO;
    return [self getItemCountWithKey:key] > 0;
}

- (NSUInteger)getItemsCount {
    return [self getTotalItemCount];
}

- (NSUInteger)getItemsSize {
    return [self getTotalItemSize];
}


@end
