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

#import <Foundation/NSObject.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSDate.h>
#import <dispatch/dispatch.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSBackgroundActivityResult) {
    NSBackgroundActivityResultFinished = 1,
    NSBackgroundActivityResultDeferred = 2,
};

typedef void (^NSBackgroundActivityCompletionHandler)(NSBackgroundActivityResult result);

@interface NSBackgroundActivityScheduler : NSObject {
@private
    NSString *_identifier;
    NSQualityOfService _qualityOfService;
    BOOL _repeats;
    NSTimeInterval _interval;
    NSTimeInterval _tolerance;

    dispatch_queue_t _queue;
    dispatch_source_t _timer;
    void (^_block)(NSBackgroundActivityCompletionHandler);
    NSUInteger _generation;
    BOOL _executing;
}

- (instancetype)initWithIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;

@property (readonly, copy) NSString *identifier;
@property NSQualityOfService qualityOfService;
@property BOOL repeats;
@property NSTimeInterval interval;
@property NSTimeInterval tolerance;

- (void)scheduleWithBlock:(void (^)(NSBackgroundActivityCompletionHandler completionHandler))block;
- (void)invalidate;
@property (readonly) BOOL shouldDefer;

@end

NS_ASSUME_NONNULL_END
