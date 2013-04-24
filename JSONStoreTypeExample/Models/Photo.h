//
//  Photo.h
//  JSONStoreTypeExample
//
//  Created by Isnan Franseda on 4/23/13.
//  Copyright (c) 2013 Isnan Franseda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Person;

@interface Photo : NSManagedObject

@property (nonatomic, retain) NSString * label;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) Person *owner;

@end
