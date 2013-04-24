//
//  AppDelegate.m
//  JSONStoreTypeExample
//
//  Created by Isnan Franseda on 4/22/13.
//  Copyright (c) 2013 Isnan Franseda. All rights reserved.
//

#import "AppDelegate.h"

#import "Person.h"
#import "Photo.h"

@implementation AppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self persistentStoreCoordinator];
    [self managedObjectContext];

    
    NSArray *source = @[
                      @{@"first":@"Isnan", @"last":@"Franseda", @"plan":@"Striker"},
                      @{@"first":@"Alexander", @"last":@"Polalo", @"plan":@"Midfielder", @"photos":@[@{@"url":@"http://google.com", @"label":@"Alexander Polalo Goal"}]},
                      @{@"first":@"Bambang", @"last":@"Pemangkas", @"plan":@"Striker", @"photos":@[@{@"url":@"http://yahoo.com", @"label":@"Victory Goal"}, @{@"url":@"http://yahoo.com", @"label":@"Fucked up!!"}]}
                      ];

    for (NSDictionary *data in source)
    {
        Person *newPerson = [[Person alloc] initWithEntity:[NSEntityDescription entityForName:@"Person" inManagedObjectContext:_managedObjectContext] insertIntoManagedObjectContext:_managedObjectContext];
        newPerson.firstName = [data valueForKey:@"first"];
        newPerson.lastName = [data valueForKey:@"last"];
        newPerson.plan = [data valueForKey:@"plan"];
        
        if ([data valueForKey:@"photos"]) {
            NSArray *photos = [data valueForKey:@"photos"];
            for (NSDictionary *photo in photos)
            {
                Photo *newPhoto = [[Photo alloc] initWithEntity:[NSEntityDescription entityForName:@"Photo" inManagedObjectContext:_managedObjectContext] insertIntoManagedObjectContext:_managedObjectContext];
                newPhoto.url = [photo valueForKey:@"url"];
                newPhoto.label = [photo valueForKey:@"label"];
                [newPerson addPhotosObject:newPhoto];
            }
        }
    }

    [_managedObjectContext save:nil];

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"Person" inManagedObjectContext:[self managedObjectContext]]];
    id results = [[self managedObjectContext] executeFetchRequest:request error:nil];
    
    NSLog(@"%@", results);
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark - Core Data

- (NSManagedObjectModel *)managedObjectModel {
    
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    NSMutableSet *allBundles = [[NSMutableSet alloc] init];
    [allBundles addObject: [NSBundle mainBundle]];
    [allBundles addObjectsFromArray: [NSBundle allFrameworks]];
    
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]];
    
    return _managedObjectModel;
}

- (NSURL *)sourceDataURL
{
    
    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [JSONStore applicationSupportFolder];
    if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
        [fileManager createDirectoryAtPath:applicationSupportFolder withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    NSString *dbPath = [applicationSupportFolder stringByAppendingPathComponent:@"SourceData.json"];
    [JSONStore copyDatabase:@"SourceData.json" toPath:dbPath];
    
    url = [NSURL fileURLWithPath:dbPath];
    return url;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{    
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }

    NSError *error;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    
    [NSPersistentStoreCoordinator registerStoreClass:[JSONStore self] forStoreType:kJSONStoreType];
    NSLog(@"JSONStore done.  Registered store types are now:  %@", [NSPersistentStoreCoordinator registeredStoreTypes] );
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:kJSONStoreType configuration:nil URL:[self sourceDataURL] options:nil error:&error]){
        NSLog(@"%@", error);
    }
    
    return _persistentStoreCoordinator;
}

- (NSManagedObjectContext *) managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return _managedObjectContext;
}


@end
