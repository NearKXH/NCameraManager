//
//  NSFileManager+NFileOperationManager.m
//  NearCameraManager
//
//  Created by NearKong on 16/7/22.
//  Copyright © 2016年 NearKong. All rights reserved.
//

#import "NSFileManager+NFileOperationManager.h"

#import "NCMFileDetailImformationModel.h"
#import "NCameraManagerHeader.h"
#import "NSError+NCustomErrorInstance.h"

@implementation NSFileManager (NFileOperationManager)

#pragma mark - Clear File Operate
/**
 *  删除 document 文件夹下的文件
 *
 *  @param filePath document 下的相对文件路径
 *  @param block
 */
+ (BOOL)NCM_clearFileWithRelativePath:(NCMFilePathInDirectory)relativePath fileName:(NSString *)fileName error:(NSError **)error {
    NSString *path = [NSFileManager NCM_fullPathWithRelativePath:relativePath error:error];
    if (!path || (*error)) {
        return false;
    }
    NSString *fullPath = [path stringByAppendingPathComponent:fileName];
    return [NSFileManager NCM_clearFileWithFullFilePath:fullPath error:error];
}

/**
 *  删除文件
 *
 *  @param fullPath 全路径
 *  @param block
 */
+ (BOOL)NCM_clearFileWithFullFilePath:(NSString *)fullPath error:(NSError **)error {
    return [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:fullPath ?: @""] error:error];
}

/**
 *  返回 document 路径下的所有文件，包括文件夹
 *
 *  @param directoryPath document 下的相对路径文件夹
 */
+ (NSArray<NCMFileDetailImformationModel *> *)NCM_allFilesWithRelativePath:(NCMFilePathInDirectory)relativePath error:(NSError **)error {
    NSString *fullPath = [NSFileManager NCM_fullPathWithRelativePath:relativePath error:error];
    if (!fullPath || (*error)) {
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *filesNameArray = [fileManager contentsOfDirectoryAtPath:fullPath error:error];
    if (*error) {
        return nil;
    }

    NSMutableArray *sourceArray = [[NSMutableArray alloc] initWithCapacity:filesNameArray.count];
    for (NSString *fileName in filesNameArray) {
        NCMFileDetailImformationModel *model =
            [[NCMFileDetailImformationModel alloc] initWithFullPathFileName:[fullPath stringByAppendingPathComponent:fileName]];
        [sourceArray addObject:model];
    }

    return sourceArray;
}

#pragma mark - Move Or Copy File
/**
 *  移动或复制文件
 *
 *  @param originalPath
 *  @param originalFileName
 *  @param toPath
 *  @param toFileName
 *  @param isCopy
 *  @param block
 */
+ (void)NCM_moveFileFromOriginalPath:(NCMFilePathInDirectory)originalPath
                    originalFileName:(NSString *)originalFileName
                              toPath:(NCMFilePathInDirectory)toPath
                          toFileName:(NSString *)toFileName
                              isCopy:(BOOL)isCopy
                               block:(NSFileManagerMoveFileBlock)block {
    NSError *error = nil;

    if (!originalFileName || [originalFileName isEqualToString:@""]) {
        error = [NSError NCM_errorWithCode:NCameraManagerResultFileFailWithNonExistent message:@"File Non-existent"];
        if (block) {
            block(NCameraManagerResultFileFailWithNonExistent, nil, error);
        }
        return;
    }
    NSString *originalFullPath = [NSFileManager NCM_fullPathWithRelativePath:originalPath fileName:originalFileName error:&error];
    if (!originalFullPath || error) {
        if (block) {
            block(NCameraManagerResultFileFailWithNonExistent, nil, error);
        }
        return;
    }

    NSString *toFullPath = [NSFileManager NCM_fullPathWithRelativePath:toPath fileName:toFileName error:&error];
    if (!toFullPath || error) {
        if (block) {
            block(NCameraManagerResultFileFail, nil, error);
        }
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *toUrl = [NSURL fileURLWithPath:toFullPath];
        NSURL *fromUrl = [NSURL fileURLWithPath:originalFullPath];

        NSError *error = nil;
        NCameraManagerResult result = NCameraManagerResultSuccess;
        BOOL scuess = true;
        if (isCopy) {
            scuess = [fileManager copyItemAtURL:fromUrl toURL:toUrl error:&error];
        } else {
            scuess = [fileManager moveItemAtURL:fromUrl toURL:toUrl error:&error];
        }

        if (!scuess || error) {
            result = NCameraManagerResultFileFailWithMoveOrCopy;
        }

        if (block) {
            block(result, toFullPath, error);
        }
    });
}

#pragma mark - File Name
/**
 *  通过相对参数，返回绝对路径
 *
 *  @param originalPath 相对参数
 *  @param fileName     文件名，包括后缀
 *  @param error
 *
 *  @return 绝对路径
 */
+ (NSString *)NCM_fullPathWithRelativePath:(NCMFilePathInDirectory)relativePath fileName:(NSString *)fileName error:(NSError **)error {

    NSString *filePath = [NSFileManager NCM_fullPathWithRelativePath:relativePath error:error];
    if (!filePath) {
        return nil;
    }

    /**
     *  初始化文件名
     */
    if (!fileName || [fileName isEqualToString:@""]) {
        NSInteger time = (NSInteger)[[NSDate date] timeIntervalSince1970];
        fileName = [NSString stringWithFormat:@"%@_%@", NCameraManagerFileNamePrefix, @(time)];
    }

    NSString *fullPath = [filePath stringByAppendingPathComponent:fileName];
    return fullPath;
}


+ (NSString *)NCM_fullPathWithRelativePath:(NCMFilePathInDirectory)relativePath prefix:(NSString *)prefix error:(NSError **)error {
    if (!prefix || [prefix isEqualToString:@""]) {
        prefix = NCameraManagerFileNamePrefix;
    }
    NSInteger time = (NSInteger)[[NSDate date] timeIntervalSince1970];
    NSString *fileName = [NSString stringWithFormat:@"%@_%@", prefix, @(time)];
    return [NSFileManager NCM_fullPathWithRelativePath:relativePath fileName:fileName error:error];
}

#pragma mark - Private
/**
 *  返回文件夹绝对位置，文件夹不存在就创建，只有1级
 *
 *  @param relativePath
 *  @param error
 *
 *  @return
 */
static NSString *NCameraManagerDocumentOriginalFileDirectory = @"NCM_Original";
static NSString *NCameraManagerDocumentConverFileDirectory = @"NCM_Conver";
+ (NSString *)NCM_fullPathWithRelativePath:(NCMFilePathInDirectory)relativePath error:(NSError **)error {
    NSString *filePath = nil;

    if (relativePath == NCMFilePathInDirectoryDocument) {
        filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

    } else if (relativePath == NCMFilePathInDirectoryDocumentOriginal) {
        filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        filePath = [filePath stringByAppendingPathComponent:NCameraManagerDocumentOriginalFileDirectory];
        if (![NSFileManager NCM_createDirectoryWithPath:filePath error:error]) {
            return nil;
        }

    } else if (relativePath == NCMFilePathInDirectoryDocumentConver) {
        filePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        filePath = [filePath stringByAppendingPathComponent:NCameraManagerDocumentConverFileDirectory];
        if (![NSFileManager NCM_createDirectoryWithPath:filePath error:error]) {
            return nil;
        }

    } else if (relativePath == NCMFilePathInDirectoryTemp) {
        filePath = NSTemporaryDirectory();
    }

    return filePath;
}

/**
 *  检测、创建文件夹
 *
 *  @param path  文件夹绝对位置
 *  @param error
 *
 *  @return
 */
+ (BOOL)NCM_createDirectoryWithPath:(NSString *)path error:(NSError **)error {
    BOOL directory = false;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path isDirectory:&directory] || !directory) {
        if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:false attributes:nil error:error] || (*error)) {
            return false;
        }
    }
    return true;
}

@end
