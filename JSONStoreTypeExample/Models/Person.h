//
//  Person.h
//  JSONStoreTypeExample
//
//  Created by Isnan Franseda on 4/23/13.
//  Copyright (c) 2013 Isnan Franseda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Person : NSManagedObject

@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSString * plan;
@property (nonatomic, retain) NSSet *photos;
@end

@interface Person (CoreDataGeneratedAccessors)

- (void)addPhotosObject:(NSManagedObject *)value;
- (void)removePhotosObject:(NSManagedObject *)value;
- (void)addPhotos:(NSSet *)values;
- (void)removePhotos:(NSSet *)values;

@end
