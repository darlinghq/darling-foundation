/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

// The XML tree classes keep their tree in libxml2 nodes. Each NSXMLNode object
// stands for one libxml2 node and is found again through the node's _private
// field. Objects are made on demand; every object retains the object of the
// topmost node of its tree, and that topmost object frees the libxml2 tree when
// it goes away. A node that leaves a tree becomes the topmost node of its own.

#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLElement.h>
#import <Foundation/NSXMLDocument.h>
#include <libxml/tree.h>

CF_PRIVATE void _NSXMLInitialize(void);

// The object for a libxml2 node, made if there is none yet (autoreleased then).
CF_PRIVATE NSXMLNode *_NSXMLNodeForXMLNode(xmlNodePtr node);
CF_PRIVATE xmlNodePtr _NSXMLNodeGetXMLNode(NSXMLNode *node);
// The topmost node of the tree that node is in.
CF_PRIVATE xmlNodePtr _NSXMLTopNode(xmlNodePtr node);

// The children as the API shows them (no DTD nodes), and the libxml2 node of one.
CF_PRIVATE NSUInteger _NSXMLChildCount(xmlNodePtr parent);
CF_PRIVATE xmlNodePtr _NSXMLChildAtIndex(xmlNodePtr parent, NSUInteger index);

// Editing of the children of a document or element. These raise like the API
// methods they implement.
CF_PRIVATE void _NSXMLInsertChild(NSXMLNode *parent, NSXMLNode *child, NSUInteger index);
CF_PRIVATE void _NSXMLRemoveChildAtIndex(NSXMLNode *parent, NSUInteger index);
CF_PRIVATE void _NSXMLRemoveAllChildren(NSXMLNode *parent);

// Takes a node that has just been unlinked from its tree: frees it, or, when
// objects still refer to it or its descendants, makes it the top of its own tree.
CF_PRIVATE void _NSXMLDisposeUnlinkedNode(xmlNodePtr node);

// Moves a node that is the top of its tree into the tree that owner tops.
CF_PRIVATE void _NSXMLAdoptIntoTree(NSXMLNode *node, xmlNodePtr top);

// Parses XML data into a libxml2 document the way NSXMLDocument does, with
// whitespace-only text left out and internal entities replaced.
CF_PRIVATE xmlDocPtr _NSXMLParseData(NSData *data, NSUInteger options, const char *encoding, NSError **error);

@interface NSXMLNode (NSXMLNodeInternal)
// Makes the receiver stand for node, which it then owns as the top of its tree.
- (instancetype) _initWithXMLNode: (xmlNodePtr) node;
// Options given at creation that change how the node is written.
- (NSUInteger) _nodeOptions;
@end
