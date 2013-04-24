//
//  JSONStore.h
//  JSONStoreTypeExample
//
//  Created by Isnan Franseda on 4/22/13.
//  Copyright (c) 2013 Isnan Franseda. All rights reserved.
//

#import <CoreData/CoreData.h>

#ifndef kJSONStoreType
#define kJSONStoreType @"JSONStore"
#endif

@interface JSONStore : NSAtomicStore
{
    NSString *pIdentifier;
    NSMutableDictionary *pRefDataToCacheNodeMap;
}

+ (NSString *)applicationSupportFolder;
+ (void)copyDatabase:(NSString *)databaseName toPath:(NSString *)path;


@end
