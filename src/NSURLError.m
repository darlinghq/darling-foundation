//
//  NSURLError.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSURLError.h>
#import <Foundation/NSError.h>

NSString *const NSURLErrorDomain = @"NSURLErrorDomain";
NSString *const NSURLErrorFailingURLErrorKey = @"NSErrorFailingURLKey";
NSString *const NSURLErrorFailingURLStringErrorKey = @"NSErrorFailingURLStringKey";
NSString *const NSErrorFailingURLStringKey = @"NSErrorFailingURLStringKey";
NSString *const NSURLErrorFailingURLPeerTrustErrorKey = @"NSURLErrorFailingURLPeerTrustErrorKey";

// A private subclass of NSError (macOS has one of this name in Foundation, observed on macOS 26.7.3).
// It adds nothing; errors in NSURLErrorDomain are plain NSErrors, as on macOS. Coders such as
// WebKit's list it among the classes they accept. Test: tests/nsurlerror-class.m.
@interface NSURLError : NSError
@end

@implementation NSURLError
@end
