//
//  main.m
//  PhotoTool
//
//  Created by GuanChe on 2019/1/21.
//  Copyright © 2019 GuanChe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>

void calculateMd5ForPath(NSString *, NSMutableDictionary *, NSMutableDictionary *, NSMutableDictionary *);
NSString *hashOfFile(NSString *path);
NSString *metadataOfFile(NSString *path);

void findDuplicateFiles(NSDictionary *dict, BOOL shouldRemove) {
    NSMutableDictionary *md5ToPath = [NSMutableDictionary dictionary];
    NSMutableDictionary *duplicateFiles = [NSMutableDictionary dictionary];
    for (NSString *key in dict) {
        NSString *md5 = [dict objectForKey:key];
        if ([md5ToPath objectForKey:md5] != nil) {
            NSMutableArray *array = [duplicateFiles objectForKey:md5];
            if (array == nil) {
                array = [NSMutableArray array];
                [array addObject:[md5ToPath objectForKey:md5]];
                [array addObject:key];
                [duplicateFiles setObject:array forKey:md5];
            } else {
                [array addObject:key];
            }
        } else {
            [md5ToPath setObject:key forKey:md5];
        }
    }
    
    for (NSString *key in duplicateFiles) {
        NSArray *array = [duplicateFiles objectForKey:key];
        NSLog(@"duplicate files: %@", array);
        if (shouldRemove) {
            for (NSString *path in array) {
                if (![path hasPrefix:@"/Volumes/Mac/photos.photoslibrary/Masters"]) {
                    NSLog(@"removing file %@", path);
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }
            }
        }
    }
}

NSInteger diffOfString1(NSString *str1, NSString *str2) {
    NSInteger count = 0;
    for (NSInteger i = 0; i < str1.length; i++) {
        if ([str1 characterAtIndex:i] != [str2 characterAtIndex:i]) {
            count++;
        }
    }
    return count;
}

NSMutableArray *findArrayForKey(NSArray *array, NSString *key) {
    for (NSMutableArray *result in array) {
        if ([result containsObject:key]) {
            return result;
        }
    }
    return [NSMutableArray arrayWithObject:key];
}

void findSimilarPhotos(NSDictionary *dict, NSDictionary *pathToDate) {
    NSArray *keys = dict.allKeys;
    NSMutableArray *finalResult = [NSMutableArray array];
    for (NSInteger i = 0; i < keys.count; i++) {
        NSString *key = keys[i];
//        @autoreleasepool {
//            NSString *metadata = [pathToDate objectForKey:key];
//            if (metadata.length > 0) {
//                NSLog(@"skip %td %@", i, key);
//                continue;
//            }
//        }
        NSLog(@"finding %td %@", i, key);
        NSString *hash = [dict objectForKey:key];
        
        NSMutableArray *result = findArrayForKey(finalResult, key);
        for (NSInteger j = i + 1; j < keys.count; j++) {
            NSString *key2 = keys[j];
            if ([result containsObject:key2]) {
                continue;
            }
            NSString *hash2 = [dict objectForKey:key2];
            if (diffOfString1(hash, hash2) <= 5) {
                [result addObject:key2];
            }
        }
        
        if (result.count > 1 && ![finalResult containsObject:result]) {
            [finalResult addObject:result];
        }
    }
    
    for (NSArray *array in finalResult) {
        BOOL shouldOutput = NO;
        for (NSString *path in array) {
            NSString *date = [pathToDate objectForKey:path];
            if (date.length == 0) {
                shouldOutput = YES;
                break;
            }
        }
        if (shouldOutput) {
            NSLog(@"%@", array);
        }
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSMutableDictionary *pathToMd5 = [NSMutableDictionary dictionaryWithContentsOfFile:@"/Users/guanche/Documents/pathToMd5.plist"];
        if (pathToMd5 == nil) {
            pathToMd5 = [NSMutableDictionary dictionary];
        }
        
        NSMutableDictionary *pathToHash = [NSMutableDictionary dictionaryWithContentsOfFile:@"/Users/guanche/Documents/pathToHash.plist"];
        if (pathToHash == nil) {
            pathToHash = [NSMutableDictionary dictionary];
        }
        
        NSMutableDictionary *pathToDate = [NSMutableDictionary dictionaryWithContentsOfFile:@"/Users/guanche/Documents/pathToDate.plist"];
        if (pathToDate == nil) {
            pathToDate = [NSMutableDictionary dictionary];
        }
        calculateMd5ForPath(@"/Volumes/Mac/photos.photoslibrary/Masters", pathToMd5, pathToHash, pathToDate);
        NSLog(@"calculateMd5 finished.");
        NSMutableArray *deletedFiles = [NSMutableArray array];
        for (NSString *key in pathToMd5) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:key]) {
                [deletedFiles addObject:key];
            }
        }
        for (NSString *key in pathToHash) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:key]) {
                [deletedFiles addObject:key];
            }
        }
        for (NSString *key in pathToDate) {
            if (![[NSFileManager defaultManager] fileExistsAtPath:key]) {
                [deletedFiles addObject:key];
            }
        }
        NSLog(@"find deleted files:%@", deletedFiles);
        [pathToMd5 removeObjectsForKeys:deletedFiles];
        [pathToHash removeObjectsForKeys:deletedFiles];
        [pathToDate removeObjectsForKeys:deletedFiles];
        [pathToMd5 writeToFile:@"/Users/guanche/Documents/pathToMd5.plist" atomically:YES];
        [pathToHash writeToFile:@"/Users/guanche/Documents/pathToHash.plist" atomically:YES];
        [pathToDate writeToFile:@"/Users/guanche/Documents/pathToDate.plist" atomically:YES];
        NSLog(@"Data save finished, files count:%tu/%tu/%tu", pathToMd5.count, pathToHash.count, pathToDate.count);
        
        findSimilarPhotos(pathToHash, pathToDate);
    }
    return 0;
}

NSString *md5OfFile(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle == nil) {
        return nil;
    }
    
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    while(YES) {
        NSData* fileData = [handle readDataOfLength:256];
        CC_MD5_Update(&md5, [fileData bytes], (CC_LONG)[fileData length]);
        if ([fileData length] == 0) {
            break;
        }
    }
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString *fileMD5 = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                         digest[0], digest[1],
                         digest[2], digest[3],
                         digest[4], digest[5],
                         digest[6], digest[7],
                         digest[8], digest[9],
                         digest[10], digest[11],
                         digest[12], digest[13],
                         digest[14], digest[15]];
    
    [handle closeFile];
    return fileMD5;
}

NSString *hashOfFile(NSString *path) {
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
    if (image == nil) {
        return nil;
    }
    
    NSRect rect = NSMakeRect(0, 0, 8, 8);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceLinearGray);
    char data[128];
    CGContextRef ctx = CGBitmapContextCreate(data,
                                             8,
                                             8,
                                             8,
                                             16,
                                             colorSpace,
                                             kCGImageAlphaPremultipliedLast);
    NSGraphicsContext* gctx = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext setCurrentContext:gctx];
    [image drawInRect:rect];

    NSMutableString *result = [NSMutableString string];
    for (int i = 0; i < 64; i++) {
        char c = data[i * 2];
        [result appendFormat:@"%01X", ((Byte)c>>4)];
    }
    
    [NSGraphicsContext setCurrentContext:nil];
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    
    if (result.length != 64) {
        [NSException raise:@"" format:@""];
    }
    return [result copy];
}

NSString *metadataOfFile(NSString *path) {
    NSData *data = [[NSData alloc] initWithContentsOfFile:path];
    if (data == nil) {
        return nil;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    NSDictionary *metadata = (NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    return [[metadata objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
}

void calculateMd5ForPath(NSString *path, NSMutableDictionary *pathToMd5, NSMutableDictionary *pathToHash, NSMutableDictionary *pathToDate) {
    NSFileManager *fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        if (isDir) {
            NSArray *dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            for (NSString * str in dirArray) {
                NSString *subPath = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                calculateMd5ForPath(subPath, pathToMd5, pathToHash, pathToDate);
            }
        } else {
            NSLog(@"processing file:%@", path);
//            if (pathToMd5 && [pathToMd5 objectForKey:path] == nil) {
//                @autoreleasepool {
//                    [pathToMd5 setObject:md5OfFile(path) forKey:path];
//                }
//                NSLog(@"calculateMd5ForFile:%@", path);
//            }
//
//            if (pathToHash && [pathToHash objectForKey:path] == nil) {
//                @autoreleasepool {
//                    NSString *hash = hashOfFile(path);
//                    if (hash) {
//                        [pathToHash setObject:hash forKey:path];
//                        NSLog(@"calculateHashForFile:%@\nhash:%@", path, hash);
//                    }
//                }
//            }
            
//            if ([pathToDate objectForKey:path] == nil) {
//                @autoreleasepool {
//                    NSString *date = metadataOfFile(path);
//                    if (date == nil) {
//                        date = @"";
//                    }
//                    [pathToDate setObject:date forKey:path];
//                    NSLog(@"calculateHashForFile:%@\ndate:%@", path, date);
//                }
//            }
        }
    }
}
