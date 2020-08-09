//
//  GCDTimer.h
//  GCD
//
//  Created by Corporation Holtek on 25/3/2020.
//  Copyright © 2020 Corporation Holtek. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GCDTimer : NSObject


+(GCDTimer*)shared;


-(void)scheduleGCDTimerWithName:(NSString*)timerName Interval:(uint64_t)interval Queue:(dispatch_queue_t)queue Repeats:(BOOL)repeats  Action:(dispatch_block_t)action;

-(void)cancelTimerWithName:(NSString*)name;

-(void)cancelAllTimer;


@end

NS_ASSUME_NONNULL_END
