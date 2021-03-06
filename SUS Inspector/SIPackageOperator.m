//
//  SIPackageOperator.m
//  SUS Inspector
//
//  Created by Juutilainen Hannes on 20.5.2013.
//  Copyright (c) 2013 Hannes Juutilainen. All rights reserved.
//

#import "SIPackageOperator.h"
#import "DataModelHeaders.h"
#import "SIOperationManager.h"

@implementation SIPackageOperator

- (NSURL *)showSavePanelForExpand:(NSString *)fileName
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.nameFieldStringValue = fileName;
    savePanel.title = @"Save expanded package";
	if ([savePanel runModal] == NSFileHandlingPanelOKButton)
	{
		return [savePanel URL];
	} else {
		return nil;
	}
}

- (NSURL *)showSavePanelForCopy:(NSString *)fileName
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.nameFieldStringValue = fileName;
    savePanel.title = @"Save the original package";
	if ([savePanel runModal] == NSFileHandlingPanelOKButton)
	{
		return [savePanel URL];
	} else {
		return nil;
	}
}


- (NSURL *)chooseFolder
{
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	openPanel.title = @"Select a folder for extracted items";
	openPanel.allowsMultipleSelection = NO;
	openPanel.canChooseDirectories = YES;
	openPanel.canChooseFiles = NO;
	openPanel.resolvesAliases = YES;
	
	if ([openPanel runModal] == NSFileHandlingPanelOKButton)
	{
		return [[openPanel URLs] objectAtIndex:0];
	} else {
		return nil;
	}
}

- (NSURL *)cacheURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [[[fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:@"SUS Inspector"];
    if (![fileManager fileExistsAtPath:[url path]]) {
        [fileManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return url;
}


- (void)willStartOperation
{
    [[SIOperationManager sharedManager] setCurrentOperationType:SIOperationTypePackageOperation];
    [[SIOperationManager sharedManager] willStartOperations];
}

- (void)willEndOperation
{
    [[SIOperationManager sharedManager] willEndOperations];
}

- (BOOL)copyPackage:(SIPackageMO *)aPackage
{
    NSURL *userChosenOutputURL = [self showSavePanelForCopy:aPackage.packageFilename];
    if (!userChosenOutputURL) {
        return FALSE;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *sourcePath = aPackage.objectCachedPath;
    NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
    if (![fileManager fileExistsAtPath:sourcePath]) {
        return FALSE;
    }
    
    [self willStartOperation];
    [SIOperationManager sharedManager].currentOperationTitle = [NSString stringWithFormat:@"Copying package..."];
    BOOL didCopy = [fileManager copyItemAtURL:sourceURL toURL:userChosenOutputURL error:nil];
    [self willEndOperation];
    if (didCopy) {
        return TRUE;
    } else {
        return FALSE;
    }
}

- (BOOL)pkgutilExpandSource:(NSString *)sourcePath outPath:(NSString *)outputPath
{
    NSTask *pkgutilTask = [[NSTask alloc] init];
    NSPipe *outPipe = [NSPipe pipe];
    NSString *launchPath = @"/usr/sbin/pkgutil";
	[pkgutilTask setLaunchPath:launchPath];
    NSArray *args = [NSArray arrayWithObjects:@"--expand", sourcePath, outputPath, nil];
	[pkgutilTask setArguments:args];
	[pkgutilTask setStandardOutput:outPipe];
    
    [pkgutilTask launch];
    [pkgutilTask waitUntilExit];
    int status = [pkgutilTask terminationStatus];
    
    if (status == 0) {
        return TRUE;
    } else {
        return FALSE;
    }
}

- (BOOL)expandPackage:(SIPackageMO *)aPackage
{
    NSURL *userChosenOutputURL = [self showSavePanelForExpand:aPackage.packageFilename];
    if (!userChosenOutputURL) {
        return FALSE;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *sourcePath = aPackage.objectCachedPath;
    if (![fileManager fileExistsAtPath:sourcePath]) {
        return FALSE;
    }
    
    [self willStartOperation];
    [SIOperationManager sharedManager].currentOperationTitle = [NSString stringWithFormat:@"Expanding package..."];
    NSString *outputPath = [userChosenOutputURL path];
    BOOL didExpand = [self pkgutilExpandSource:sourcePath outPath:outputPath];
    [self willEndOperation];
    if (didExpand) {
        return TRUE;
    } else {
        return FALSE;
    }
}

- (NSString *)fileTypeString:(NSString *)aPath
{
    NSString *fileType = nil;
    NSTask *task = [[NSTask alloc] init];
	NSPipe *outpipe = [NSPipe pipe];
    NSFileHandle *filehandle = [outpipe fileHandleForReading];
	[task setLaunchPath:@"/usr/bin/file"];
    NSArray *paxArgs = [NSArray arrayWithObjects:@"--brief", aPath, nil];
    [task setArguments:paxArgs];
    [task setStandardOutput:outpipe];
    
    [task launch];
    [task waitUntilExit];
    
    NSData *makepkginfoTaskData = [filehandle readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:makepkginfoTaskData encoding:NSUTF8StringEncoding];
    fileType = [NSString stringWithString:output];
    return fileType;
}

- (BOOL)extractPackagePayload:(SIPackageMO *)aPackage
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *userChosenOutputURL = [self chooseFolder];
    if (!userChosenOutputURL) {
        return FALSE;
    }
    
    [self willStartOperation];
    
    NSString *outputPath = [userChosenOutputURL path];
    
    
    // Create a temp directory and expand
    [SIOperationManager sharedManager].currentOperationTitle = [NSString stringWithFormat:@"Expanding package..."];
    
    NSString *tempFileName = [NSString stringWithFormat:@"%@-temporary-expand", aPackage.packageFilename];
    NSString *expandTemp = [[[self cacheURL] path] stringByAppendingPathComponent:tempFileName];
    
    // Clear existing cached files
    [fileManager removeItemAtPath:expandTemp error:nil];
    
    
    NSString *sourcePath = aPackage.objectCachedPath;
    if (![fileManager fileExistsAtPath:sourcePath]) {
        return FALSE;
    }
    
    if (![self pkgutilExpandSource:sourcePath outPath:expandTemp]) {
        [self willEndOperation];
        return FALSE;
    }
    
    // Find a Payload
    NSString *payloadPath = [expandTemp stringByAppendingPathComponent:@"Payload"];
    if (![fileManager fileExistsAtPath:payloadPath]) {
        [self willEndOperation];
        return FALSE;
    }
    
    NSString *fileType = [self fileTypeString:payloadPath];
    NSLog(@"fileType: %@", fileType);
    
    [SIOperationManager sharedManager].currentOperationTitle = [NSString stringWithFormat:@"Extracting package payload..."];
    
    // Extract the payload using "ditto -x" (thanks for the tip @magervalp)
    NSTask *dittoTask = [[NSTask alloc] init];
    NSString *launchPath = @"/usr/bin/ditto";
    [dittoTask setLaunchPath:launchPath];
    NSArray *gunzipArgs = [NSArray arrayWithObjects:@"-x", payloadPath, outputPath, nil];
    [dittoTask setArguments:gunzipArgs];
    [dittoTask setCurrentDirectoryPath:outputPath];
    
    // Launch the task and get the exit code
    [dittoTask launch];
    [dittoTask waitUntilExit];
    int exitCode = [dittoTask terminationStatus];
    
    
    // Remove temporary files
    [SIOperationManager sharedManager].currentOperationTitle = [NSString stringWithFormat:@"Cleaning temporary files..."];
    [fileManager removeItemAtPath:expandTemp error:nil];
    
    [self willEndOperation];
    
    if (exitCode == 0) {
        return TRUE;
    } else {
        NSLog(@"extractPackagePayload failed");
        return FALSE;
    }
    
    return TRUE;
}


# pragma mark -
# pragma mark Singleton methods

static SIPackageOperator *sharedOperator = nil;
static dispatch_queue_t serialQueue;

+ (id)allocWithZone:(NSZone *)zone {
    static dispatch_once_t onceQueue;
    
    dispatch_once(&onceQueue, ^{
        serialQueue = dispatch_queue_create("fi.obsolete.sus-inspector.packageoperator.serialqueue", NULL);
        if (sharedOperator == nil) {
            sharedOperator = (SIPackageOperator *) [super allocWithZone:zone];
        }
    });
    
    return sharedOperator;
}

+ (SIPackageOperator *)sharedOperator {
    static dispatch_once_t onceQueue;
    
    dispatch_once(&onceQueue, ^{
        sharedOperator = [[SIPackageOperator alloc] init];
    });
    
    return sharedOperator;
}

- (id)init {
    id __block obj;
    
    dispatch_sync(serialQueue, ^{
        obj = [super init];
        if (obj) {
            //self.operationQueue = [[[NSOperationQueue alloc] init] autorelease];
            //[self.operationQueue setMaxConcurrentOperationCount:4];
        }
    });
    
    self = obj;
    return self;
}


@end
