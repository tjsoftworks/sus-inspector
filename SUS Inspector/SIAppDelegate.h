//
//  SIAppDelegate.h
//  SUS Inspector
//
//  Created by Juutilainen Hannes on 4.3.2013.
//  Copyright (c) 2013 Hannes Juutilainen. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


#import <Cocoa/Cocoa.h>
#import "SIOperationManager.h"
#import "SIReposadoConfigurationController.h"

@class SIMainWindowController;
@class SIPreferencesController;
@class SIReposadoInstanceMO;

@interface SIAppDelegate : NSObject <NSApplicationDelegate, SIOperationManagerDelegate, SIReposadoConfigurationControllerDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSArrayController *productsArrayController;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (strong) SIMainWindowController *mainWindowController;
@property (strong) SIPreferencesController *preferencesController;
@property (strong) SIReposadoInstanceMO *defaultReposadoInstance;
@property (weak) IBOutlet NSArrayController *catalogsArrayController;
@property (weak) IBOutlet NSTreeController *sourceListTreeController;

- (IBAction)saveAction:(id)sender;
- (IBAction)reposyncAction:(id)sender;
- (IBAction)openPreferencesAction:(id)sender;
- (BOOL)createDirectoriesForReposadoAtURL:(NSURL *)url;

// SIOperationManager delegates
- (void)willStartOperations:(id)sender;
- (void)willEndOperations:(id)sender;

// SIReposadoConfigurationController delegates
- (void)reposadoConfigurationDidFinish:(id)sender returnCode:(int)returnCode object:(SIReposadoInstanceMO *)object;

@end
