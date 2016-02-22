//
//  NCDgmItemsTreeController.m
//  Neocom
//
//  Created by Артем Шиманский on 22.02.16.
//  Copyright © 2016 Shimanski Artem. All rights reserved.
//

#import "NCDgmItemsTreeController.h"
#import "NCDatabase.h"

@interface NCDgmItemNode : NSObject
@property (readonly) NSString* title;
@property (readonly) NSSet* items;
@property (readonly) NSImage* image;
@property (readonly, getter=isLeaf) BOOL leaf;
@property (strong) NCDBDgmppItemGroup* group;
@property (strong) NCDBDgmppItem* item;
@property (nonatomic, strong) NSPredicate* predicate;
@property (nonatomic, strong) NCDgmItemNode* node;

- (id) initWithGroup:(NCDBDgmppItemGroup*) group;
- (id) initWithItem:(NCDBDgmppItem*) item;
- (id) initWithNode:(NCDgmItemNode*) node predicate:(NSPredicate*) predicate;

@end

@implementation NCDgmItemNode
@synthesize items = _items;

- (id) initWithGroup:(NCDBDgmppItemGroup*) group {
	if (self = [super init]) {
		self.group = group;
	}
	return self;
}

- (id) initWithItem:(NCDBDgmppItem*) item {
	if (self = [super init]) {
		self.item = item;
	}
	return self;
}

- (id) initWithNode:(NCDgmItemNode*) node predicate:(NSPredicate*) predicate {
	if (self = [super init]) {
		self.node = node;
		self.predicate = predicate;
	}
	return self;
}


- (NSSet*) items {
	if (!_items) {
		if (self.group.subGroups.count > 0) {
			NSMutableSet* items = [NSMutableSet new];
			for (NCDBDgmppItemGroup* subGroup in self.group.subGroups)
				[items addObject:[[NCDgmItemNode alloc] initWithGroup:subGroup]];
			_items = items;
		}
		else if (self.group.items.count > 0) {
			NSMutableSet* items = [NSMutableSet new];
			for (NCDBDgmppItem* item in self.group.items)
				[items addObject:[[NCDgmItemNode alloc] initWithItem:item]];
			_items = items;
		}
		else if (self.node && self.predicate) {
			NSMutableSet* items = [NSMutableSet new];
			for (NCDgmItemNode* node in self.node.items) {
				if (node.item && [self.predicate evaluateWithObject:node])
					[items addObject:node];
				else {
					NCDgmItemNode* filteredNode = [[NCDgmItemNode alloc] initWithNode:node predicate:self.predicate];
					if (filteredNode.items.count > 0)
						[items addObject:filteredNode];
				}
			}
			_items = items;
		}
	}
	return _items;
}

- (NSString*) title {
	if (self.group)
		return self.group.groupName;
	else if (self.item)
		return self.item.type.typeName;
	else if (self.node)
		return self.node.title;
	else
		return nil;
}

- (NSImage*) image {
	if (self.group)
		return self.group.icon.image.image ?: [self.group.managedObjectContext defaultGroupIcon].image.image;
	else if (self.item)
		return self.item.type.icon.image.image ?: [self.item.type.managedObjectContext defaultTypeIcon].image.image;
	else if (self.node)
		return self.node.image;
	else
		return nil;
}

- (BOOL) isLeaf {
	return self.item != nil;
}

@end

@interface NCDgmItemRootNode : NCDgmItemNode {
	NSSet* _rootItems;
}
@property (strong) NCDBInvType* type;

- (id) initWithType:(NCDBInvType*) type;

@end

@implementation NCDgmItemRootNode

- (id) initWithType:(NCDBInvType*) type {
	if (self = [super init]) {
		self.type = type;
	}
	return self;
}

- (NSSet*) items {
	if (!_rootItems) {
		NSMutableSet* items = [NSMutableSet new];
		NSManagedObjectContext* context = [[NCDatabase sharedDatabase] managedObjectContext];
		
		NSFetchRequest* request = [NSFetchRequest fetchRequestWithEntityName:@"DgmppItemGroup"];
		request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"groupName" ascending:YES]];
		NSArray* categories = @[[context categoryWithSlot:NCDBDgmppItemSlotHi size:0 race:nil],
								[context categoryWithSlot:NCDBDgmppItemSlotMed size:0 race:nil],
								[context categoryWithSlot:NCDBDgmppItemSlotLow size:0 race:nil],
								[context categoryWithSlot:NCDBDgmppItemSlotRig size:0 race:nil],
								[context categoryWithSlot:NCDBDgmppItemSlotSubsystem size:0 race:self.type.race]
								];
		
		request.predicate = [NSPredicate predicateWithFormat:@"category IN %@ AND parentGroup == NULL", categories];
		NSSet* results = [NSSet setWithArray:[context executeFetchRequest:request error:nil]];
		while (results.count == 1) {
			NCDBDgmppItemGroup* group = [results anyObject];
			if (group.subGroups.count > 0)
				results = group.subGroups;
		}
		
		for (NCDBDgmppItemGroup* group in results)
			[items addObject:[[NCDgmItemNode alloc] initWithGroup:group]];

		_rootItems = items;
	}
	return _rootItems;
}

- (NSString*) title {
	return nil;
}

- (NSImage*) image {
	return nil;
}


@end

@interface NCDgmItemsTreeController()
@property (strong) NCDgmItemRootNode* dgmItemRootNode;
@end


@implementation NCDgmItemsTreeController

- (void) awakeFromNib {
	self.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]];
}

- (void) setType:(NCDBInvType *)type {
	_type = type;
	self.dgmItemRootNode = [[NCDgmItemRootNode alloc] initWithType:type];
	self.content = self.dgmItemRootNode.items;
}

@end
