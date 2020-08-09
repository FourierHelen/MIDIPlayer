//
//  GCDTimer.m
//  GCD
//
//  Created by Corporation Holtek on 25/3/2020.
//  Copyright © 2020 Corporation Holtek. All rights reserved.
//

#import "GCDTimer.h"

@interface GCDTimer()

@property(nonatomic,strong)NSMutableDictionary* timerContainer;

@end

@implementation GCDTimer


+(GCDTimer*)shared{
    static GCDTimer* shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared=[[GCDTimer alloc] init];
        
    });
    return shared;
}


-(void)scheduleGCDTimerWithName:(NSString*)timerName Interval:(uint64_t)interval Queue:(dispatch_queue_t)queue Repeats:(BOOL)repeats  Action:(dispatch_block_t)action{
    
    if(timerName==nil){
        return;
    }
    
    if(queue==nil){
        //queue=dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        queue=dispatch_queue_create("timer", DISPATCH_QUEUE_SERIAL);
        
    }
    
    dispatch_source_t timer=[self.timerContainer objectForKey:timerName];
    if(!timer){
        
        timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        [self.timerContainer setObject:timer forKey:timerName];
        //启动定时器
        dispatch_resume(timer);
    }
    
    /*
    第一个参数:定时器对象
    第二个参数:DISPATCH_TIME_NOW 表示从现在开始计时
    第三个参数:间隔时间 GCD里面的时间最小单位为 纳秒, 以毫秒为单位
    第四个参数:精准度(表示允许的误差,0表示绝对精准)
    */
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, interval*NSEC_PER_MSEC), interval*NSEC_PER_MSEC, 0);
    
    
    __weak typeof(self) weakSelf= self;
    
           
            
    dispatch_source_set_event_handler(timer, ^{
        action();
                
        if(!repeats){
            [weakSelf cancelTimerWithName:timerName];
                }
            });
        
            
    
    
}

-(NSMutableDictionary*)timerContainer{
    
    if(!_timerContainer){
        _timerContainer=[[NSMutableDictionary alloc] init];
    }
    return _timerContainer;
}


-(void)cancelTimerWithName:(NSString*)name{
    
    dispatch_source_t timer=[self.timerContainer objectForKey:name];
    
    if(!timer){
        return;
    }
    
    [self.timerContainer removeObjectForKey:name];
    dispatch_source_cancel(timer);
    
}



-(void)cancelAllTimer{
    
    [self.timerContainer enumerateKeysAndObjectsUsingBlock:^(NSString* timerName, dispatch_source_t timer, BOOL * stop) {
        [self.timerContainer removeObjectForKey:timerName];
        dispatch_source_cancel(timer);
    }];
}




@end
