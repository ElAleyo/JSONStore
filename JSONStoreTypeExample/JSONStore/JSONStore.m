//
//  JSONStore.m
//  JSONStoreTypeExample
//
//  Created by Isnan Franseda on 4/22/13.
//  Copyright (c) 2013 Isnan Franseda. All rights reserved.
//

#import "JSONStore.h"

@interface JSONStore ()

@property (strong, nonatomic, getter = pDocument) NSMutableDictionary * pDocument;
@property (strong, nonatomic) NSMutableDictionary * pMeta;
@property (strong, nonatomic) NSMutableArray * pTables;

@end

@implementation JSONStore

@synthesize pDocument = _pDocument;


+ (NSString *)applicationSupportFolder
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:kJSONStoreType];
}

+ (void)copyDatabase:(NSString *)databaseName toPath:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    BOOL success = [fileManager fileExistsAtPath:path];
    NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:databaseName];
    
    if(!success)
    {
        if ([fileManager fileExistsAtPath:defaultDBPath])
        {
            success = [fileManager copyItemAtPath:defaultDBPath toPath:path error:&error];
            if (!success) NSLog(@"%@", error.localizedDescription);
        }
    }
}

- (NSMutableDictionary *)pDocument
{
    _pDocument = [NSMutableDictionary dictionaryWithDictionary:_pDocument];
    [_pDocument setObject:_pMeta forKey:@"meta"];
    [_pDocument setObject:_pTables forKey:@"tables"];
    
    return _pDocument;
}

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator configurationName:(NSString *)configurationName URL:(NSURL *)url options:(NSDictionary *)options
{
    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:configurationName URL:url options:options];
    if (self != nil)
    {
        pIdentifier = nil;
        pRefDataToCacheNodeMap = nil;
        
        NSError *error = nil;
        NSData *sourceData = [NSData dataWithContentsOfURL:url];

        _pDocument = [NSJSONSerialization JSONObjectWithData:sourceData options:NSJSONReadingAllowFragments error:&error];
        _pMeta = [NSMutableDictionary dictionaryWithDictionary:[_pDocument objectForKey:@"meta"]];

        _pTables = [NSMutableArray new];
        for (NSDictionary *table in [_pDocument objectForKey:@"tables"]) {
            NSMutableDictionary *mTable = [NSMutableDictionary dictionaryWithDictionary:table];
            NSMutableArray *mRecords = [NSMutableArray arrayWithArray:[mTable valueForKey:@"records"]];

            [mTable setObject:mRecords forKey:@"records"];
            [_pTables addObject:mTable];
        }

        if ((_pDocument == nil) && ([[error domain] isEqualToString:NSURLErrorDomain]) && ([url isFileURL])) {
            
            NSInteger code = [error code];
            if ((code == NSURLErrorCannotOpenFile) || (code == NSURLErrorZeroByteResource)) {
                [[NSFileManager defaultManager] createFileAtPath:[url path] contents:nil attributes:nil];
            }
        }
        
        if (_pDocument != nil) {
            [self loadMetadata];
        } else {
            [[NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"FUCK!!! >> %@", url] userInfo:nil] raise];
        }
    }
    
    return self;
}

- (NSString *)identifier
{
    if (pIdentifier == nil)
    {
        pIdentifier = @"XXX";
    }
    return pIdentifier;
}


- (void)setIdentifier:(NSString *)identifier
{
    if (pIdentifier != identifier)
    {
        pIdentifier = nil;
        pIdentifier = identifier;
    }
}

- (NSString *)type
{
    return kJSONStoreType;
}

// gets the indexes of <objects> in <array>, the indexset is in terms of <array> ordering
// the number of indexes may be smaller than the number of objects in array
// we use this to get the property names from an entity in the same order they appear in in the html
- (NSIndexSet *)indexesOfObjects:(NSArray *)objects inArray:(NSArray *)array
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (id object in objects) {
        NSUInteger index = [array indexOfObject:object];
        if (index != NSNotFound) {
            [indexSet addIndex:index];
        }
    }
    return indexSet;
}

- (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateFormatter = nil;
    if (dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
    }
    return dateFormatter;
}

// Get, or create and remember, a cache node
- (id)cacheNodeForEntity:(NSEntityDescription *)entity withReferenceData:(id)refData
{
    if (pRefDataToCacheNodeMap == nil) {
        pRefDataToCacheNodeMap = [[NSMutableDictionary alloc] init];
    }
    
    id item = [pRefDataToCacheNodeMap objectForKey:refData];
    if (item == nil) {
        NSManagedObjectID *oid = [self objectIDForEntity:entity referenceObject:refData];
        item = [[NSAtomicStoreCacheNode alloc] initWithObjectID:oid];
        [pRefDataToCacheNodeMap setObject:item forKey:refData];
    }
    return item;
}

- (id)cacheNodesForRelationshipData:(id)relationshipData andRelationship:(NSRelationshipDescription *)relationship  fromTable:(NSString *)tableName
{
    id results = [NSMutableSet set];
    
    if ([relationship isToMany] == NO) {
        NSAssert1(([relationshipData count] <= 1), @"More than one destination object described for to-one relationship '%@'", [relationship name]);
    }

    for (NSString *data in relationshipData)
    {
        NSString *destinationID = data;
        NSAssert(((destinationID != nil) && ([destinationID length] > 1)), @"destinationID wasn't set for relationship");
        destinationID = [destinationID substringFromIndex:1]; // drop the # at the beginning of each link href

        // if one was created brand new, we'll end up with a cache node that's mostly empty, when its table is processed later, then the values will be filled out
        [results addObject:[self cacheNodeForEntity:[relationship destinationEntity] withReferenceData:destinationID]];
    }
    
    if ([relationship isToMany] == NO) {
        results = [results anyObject];
    }
    
    return results;
}

- (void)willRemoveCacheNodes:(NSSet *)cacheNodes
{
    for (NSAtomicStoreCacheNode *node in cacheNodes)
    {
        NSManagedObjectID *objectID = [node objectID];
        NSEntityDescription *entity = [objectID entity];
        NSMutableArray *tableRecords = [self recordsFortable:entity.name];
        id rowToDelete = [self rowWithRefData:[self referenceObjectForObjectID:objectID] inTable:entity.name];
        [tableRecords removeObject:rowToDelete];
    }
}


// Gives the store a chance to do any non-dealloc teardown (for example, closing a network connection)
// before removal.  Default implementation just does nothing.
- (void)willRemoveFromPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator
{
    _pDocument = nil;
    [super willRemoveFromPersistentStoreCoordinator:coordinator];
}

- (BOOL)load:(NSError **)error
{
    if (_pDocument != nil)
    {
        NSArray *tables = [self tablesName];
        NSLog(@"%@", tables);
        for (NSString *table in tables) {
            [self loadTable:table];
        }
    }
    
    return (_pDocument != nil);
}

- (BOOL)save:(NSError **)error
{
    BOOL result = NO;
    [self updateMetadata];

    NSData *data = [NSJSONSerialization dataWithJSONObject:[self pDocument] options:NSJSONWritingPrettyPrinted error:error];
    if (data != nil) {
        result = [data writeToURL:[self URL] atomically:YES];
    }
    return result;
}

- (void)loadTable:(NSString *)tableName
{
    NSString *entityName = tableName;
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    NSEntityDescription *entity = [[[coordinator managedObjectModel] entitiesByName] valueForKeyPath:entityName];
    
    if (entity != nil)
    {
        NSDictionary *attributes = [entity attributesByName];
        NSDictionary *relationships = [entity relationshipsByName];
        
        // get the available column names
        NSArray *allRows = [self recordsFortable:tableName];
        NSArray *columnNames = [[self fieldForTable:tableName] allKeys];
        NSArray *columnType = [[self fieldForTable:tableName] allValues];
        
        // get the attribute and relationship names
        NSArray *attributeNames = [attributes allKeys];
        NSArray *relationshipNames = [relationships allKeys];
        
        // convert everything to be in terms of the column ordering and column names
        
        // get the indexes of columns with attribute data
        NSIndexSet *attributeIndexes = [self indexesOfObjects:attributeNames inArray:columnNames];
        
        // get the indexes of columns with relationship data
        NSIndexSet *relationshipIndexes = [self indexesOfObjects:relationshipNames inArray:columnNames];
        
        NSMutableSet *results = [NSMutableSet set];
        NSInteger lastIndex = 1;
        NSUInteger index;
        
        for (NSMutableDictionary *row in allRows)
        {
            id refData = [row valueForKeyPath:@"objectID"];
            
            while (refData == nil) {
                refData = [NSString stringWithFormat:@"%@_%@", entityName, [NSNumber numberWithInt:lastIndex++]];
                id row = [self rowWithRefData:refData inTable:tableName];
                if (row != nil) {
                    refData = nil;
                } else {
                    [row setObject:refData forKey:@"objectID"];
                }
            }
            
            // create the cache node to register
            id item = [self cacheNodeForEntity:entity withReferenceData:refData];

            for (index=[attributeIndexes firstIndex]; index != NSNotFound; index=[attributeIndexes indexGreaterThanIndex:index])
            {
                NSString *attributeName = [columnNames objectAtIndex:index];
                NSAttributeDescription *attribute = [attributes objectForKey:attributeName];
                NSAttributeType attributeType = [attribute attributeType];
                id objectValue = [row objectForKey:attributeName];

                if (attributeType == NSDecimalAttributeType) {
                    objectValue = [NSDecimalNumber decimalNumberWithString:objectValue];
                } else if (attributeType == NSDoubleAttributeType) {
                    objectValue = [NSNumber numberWithDouble:[objectValue doubleValue]];
                } else if (attributeType == NSFloatAttributeType) {
                    objectValue = [NSNumber numberWithFloat:[objectValue floatValue]];
                } else if (attributeType == NSBooleanAttributeType) {
                    objectValue = [NSNumber numberWithBool:[objectValue intValue]];
                } else if (attributeType == NSDateAttributeType) {
                    objectValue = [[self dateFormatter] dateFromString:objectValue];
                } else if ((attributeType == NSInteger16AttributeType) || (attributeType == NSInteger32AttributeType) || (attributeType == NSInteger64AttributeType)) {
                    objectValue = [NSNumber numberWithInteger:[objectValue integerValue]];
                } else if (attributeType == NSBinaryDataAttributeType) {

                }
                
                [item setValue:objectValue forKey:attributeName];
            }
            
            // set relationships values
            for (index=[relationshipIndexes firstIndex]; index != NSNotFound; index=[relationshipIndexes indexGreaterThanIndex:index]) {
                NSString *relationshipName = [columnNames objectAtIndex:index];
                id objectValue = [row objectForKey:relationshipName];
                id destinationCacheNodes = [self cacheNodesForRelationshipData:objectValue andRelationship:[relationships objectForKey:[columnNames objectAtIndex:index]]  fromTable:tableName];
                [item setValue:destinationCacheNodes forKey:[columnNames objectAtIndex:index]];
            }
            [results addObject:item];
            
        }
        
        [self addCacheNodes:results];
    }
}

// called when the PSC generates object IDs for our cachenodes
// This method MUST return a new unique primary key reference data for an instance of entity. This
// primary key value MUST be an id
- (id)newReferenceObjectForManagedObject:(NSManagedObject *)managedObject
{    
    NSEntityDescription *entity = [managedObject entity];
    id refData = nil;
    
    NSMutableDictionary *newRow = [self newRowForEntity:entity inTable:entity.name];
    refData = [[newRow valueForKey:@"objectID"] copy]; // refData is the value of the id attribute
    
    return refData;
}



// creates a new row based on entity and the peer rows that already exist in table. callers have to add it to the table.
- (NSMutableDictionary *)newRowForEntity:(NSEntityDescription *)entity inTable:(NSString *)tableName
{
    NSMutableDictionary *row = [NSMutableDictionary dictionary];
    
    NSMutableDictionary *table = [self tableWithName:tableName];
    NSArray *recordsTable = [self recordsFortable:tableName];
    
    // id = @"entityname_uniquenumber"
    NSString *idString = [entity name];
    
    // does the table have a unique last number attribute?
    id nextIDAttribute = [table objectForKey:@"nextid"];
    NSString *nextIDValue = [nextIDAttribute stringValue];
    unsigned long nextID = 0;
    if (nextIDValue != nil) {
        nextID = [nextIDValue integerValue];
        nextIDValue = [NSString stringWithFormat:@"%@_%ld", idString, nextID];
    } else {
        // make one up
        NSMutableDictionary *lastRow = [recordsTable lastObject];
        nextID = [[[lastRow valueForKey:@"objectID"] stringValue] integerValue];
        
        while (YES) {
            nextIDValue = [NSString stringWithFormat:@"%@_%ld", idString, nextID];
            id row = [self rowWithRefData:nextIDValue inRecordsTable:recordsTable];
            if ((row == nil) || (nextID == NSNotFound)) {
                break;
            }
            nextID++;
        }
    }
    
    NSAssert((nextID != NSNotFound), @"blew past some limit trying to find an unused id for a new row");
    
    // nextIDValue is our new id
    [row setObject:nextIDValue forKey:@"objectID"];
    
    nextID++;
    [table setObject:[NSNumber numberWithUnsignedLong:nextID] forKey:@"nextid"];
    
    return row;
}


- (NSMutableDictionary *)rowWithRefData:(id)refData inTable:(NSString *)tableName
{
    NSMutableArray *table = [self recordsFortable:tableName];
    NSArray *row = [table filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"objectID = %@", refData]];
    
    return (row != nil) && ([row count] == 1) ? [row lastObject] : nil;
}

- (NSMutableDictionary *)rowWithRefData:(id)refData inRecordsTable:(NSArray *)table
{
    NSArray *row = [table filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"objectID = %@", refData]];    
    return (row != nil) && ([row count] == 1) ? [row lastObject] : nil;
}



// Called by PSC during save to create cache nodes for newly inserted objects
- (NSAtomicStoreCacheNode *)newCacheNodeForManagedObject:(NSManagedObject *)managedObject
{
    NSManagedObjectID *oid = [managedObject objectID];
    id refData = [self referenceObjectForObjectID:oid];
    
    // create the cache node
    id item = [[NSAtomicStoreCacheNode alloc] initWithObjectID:oid];
    
    // create a new row in the table
    NSString *tableName = [[managedObject entity] name];
    NSMutableDictionary *newRow = [NSMutableDictionary dictionary];

    // give the table row an id
    [newRow setObject:refData forKey:@"objectID"];
    
    // for each table header column, add a table data element
    NSDictionary *columns = [self fieldForTable:tableName];
    for (NSString *column in [columns allKeys])
    {
        NSString *columnType = [columns valueForKey:column];
        Class columnClass = NSClassFromString(columnType);
        if (columnClass != nil)
        {
            [newRow setObject:[NSNull null] forKey:column];
        }
    }
    
    // finally add the new row
    [self newRecord:newRow forTable:tableName];
    
    // update the cache node's data
    [self updateCacheNode:item fromManagedObject:managedObject];
    
    return item;
}

// The must overriden method for custom store type
- (void)updateCacheNode:(NSAtomicStoreCacheNode *)node fromManagedObject:(NSManagedObject *)managedObject
{
    NSString *tableName = [managedObject entity].name;
    id refData = [self referenceObjectForObjectID:[managedObject objectID]];
    NSMutableDictionary *row = [self rowWithRefData:refData inTable:tableName];

    if (row != nil) {
        NSArray *columnNames = [[self fieldForTable:tableName] allKeys];
        
        [self updateAttributesInCacheNode:node andRow:row fromManagedObject:managedObject usingColumnNames:columnNames];
        [self updateRelationshipsInCacheNode:node andRow:row fromManagedObject:managedObject usingColumnNames:columnNames];
    }
}

- (void)updateAttributesInCacheNode:(NSAtomicStoreCacheNode *)node andRow:(NSMutableDictionary *)row fromManagedObject:(NSManagedObject *)managedObject usingColumnNames:(NSArray *)columnNames
{
    NSArray *attributeKeys = [[[managedObject entity] attributesByName] allKeys];
    NSIndexSet *indexSet = [self indexesOfObjects:attributeKeys inArray:columnNames];
    NSUInteger index;

    for (index=[indexSet firstIndex]; index != NSNotFound; index=[indexSet indexGreaterThanIndex:index])
    {
        NSString *name = [columnNames objectAtIndex:index];
        
        // Recently only support for non transformable type and binary type
//        NSAttributeType attributeType = [[[[managedObject entity] attributesByName] objectForKey:name] attributeType];
        
        id valueToStore = [managedObject valueForKey:name];
        if (valueToStore == nil) valueToStore = [NSNull null];
        
        [row setObject:valueToStore forKey:name];
    }
    
    [node setValuesForKeysWithDictionary:[managedObject dictionaryWithValuesForKeys:attributeKeys]];
}

- (void)updateRelationshipsInCacheNode:(NSAtomicStoreCacheNode *)node andRow:(NSMutableDictionary *)row fromManagedObject:(NSManagedObject *)managedObject usingColumnNames:(NSArray *)columnNames
{
    NSDictionary *relationshipsByName = [[managedObject entity] relationshipsByName];
    NSIndexSet *indexSet = [self indexesOfObjects:[relationshipsByName allKeys] inArray:columnNames];
    NSUInteger index;
    
    // relationships
    for (index=[indexSet firstIndex]; index != NSNotFound; index=[indexSet indexGreaterThanIndex:index])
    {
        NSString *name = [columnNames objectAtIndex:index];
        
        id relatedObjects = [managedObject valueForKey:name];
        NSMutableSet *relatedCacheNodes = [[NSMutableSet alloc] init];
        NSMutableArray *related = [[NSMutableArray alloc] init];
        
        if (([[relationshipsByName objectForKey:name] isToMany] == NO) && (relatedObjects != nil)) {
            //if this is a to-One relationship, relatedObjects will be a managedObject, not a set
            relatedObjects = [NSSet setWithObject:relatedObjects];
        }
        
        for (NSManagedObject *destinationObject in relatedObjects )
        {
            id refData = [self referenceObjectForObjectID:[destinationObject objectID]];
            
            id destinationNode = [self cacheNodeForEntity:[destinationObject entity] withReferenceData:refData];
            [relatedCacheNodes addObject:destinationNode];
            
            NSString *hrefString = [NSString stringWithFormat:@"#%@", refData];
            [related addObject:hrefString];
        }
        
        [row setObject:related forKey:name];
        [node setValue:relatedCacheNodes forKey:name];
        //	[relatedCacheNodes release];
    }
}


- (void)loadMetadata
{
    NSMutableDictionary *metaElement = [NSMutableDictionary dictionary];
    NSMutableDictionary *metadata = [self metaElement];
    
    for (NSString *metaName in [metadata allKeys])
    {
        if ([metadata valueForKeyPath:metaName]) {
            // we'll always try to do propertyList processing since that's what we'll usually want
            @try {
                id metaContent = [metadata objectForKey:metaName];
                [metaElement setObject:metaContent forKey:metaName];
            } @catch (NSException *parseException) {
                // that's fine, we'll treat the content as a plain string then
            }
        }
    }
    [self setMetadata:metaElement];
}

// updates the NSXMLDocument's HTML meta tags
- (void)updateMetadata
{
    NSMutableDictionary *metaElement = [self metaElement];
    
    NSDictionary *metadata = [self metadata];
    for (NSString *name in [metadata allKeys]) {
        [metaElement setObject:[[metadata objectForKey:name] description] forKey:name];
    }
}

- (NSMutableDictionary *)metaElement
{
    return _pMeta;
}

- (NSMutableArray *)tableElement
{
    return _pTables;
}

- (NSArray *)tablesName
{
    return [[self tableElement] valueForKeyPath:@"name"];
}

- (NSMutableDictionary *)tableWithEntity:(NSEntityDescription *)entity
{
    NSString *tableName = [entity name];
    return [self tableWithName:tableName];
}

- (NSMutableDictionary *)tableWithName:(NSString *)tableName
{
    NSMutableArray *tables = [[self tableElement] mutableCopy];
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"name == %@", tableName];
    [tables filterUsingPredicate:filter];

    NSLog(@"%i %@", [tables count], filter);
    
//    NSAssert1(([tables count] > 1), @"There are more than one table with same identifier %@", tableName);
//    NSAssert1([[tables lastObject] isKindOfClass:[NSMutableDictionary class]], @"Found an invalid table '%@'", tableName);
    
//    return [NSMutableDictionary dictionaryWithDictionary:[tables lastObject]];
    return [tables lastObject];
}

- (BOOL)newRecord:(NSMutableDictionary *)record forTable:(NSString *)tableName
{
    NSMutableArray *records = [self recordsFortable:tableName];
    NSInteger initialCount = [records count];
    [records addObject:record];
    
    if (records.count > initialCount)
        return YES;
    else
        return NO;
}

- (NSMutableArray *)recordsFortable:(NSString *)tableName
{
    NSMutableArray *records = [[self tableWithName:tableName] objectForKey:@"records"];
    if (records == nil) {
        records = [NSMutableArray array];
    }
    
    return records;
}

- (NSDictionary *)fieldForTable:(NSString *)tableName
{
    return [[self tableWithName:tableName] objectForKey:@"fields"];
}

@end
