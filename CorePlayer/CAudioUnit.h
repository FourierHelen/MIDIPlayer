//
//  CAudioUnit.m
//  Sequence
//
//  Created by FourierHelen on 16/4/2020.
//  Copyright (c) 2020 Corporation Holtek. All rights reserved.
//
//


#import <Foundation/Foundation.h>

#import <AudioUnit/AudioUnit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CAudioUnit : NSObject

@property (readwrite) AudioUnit audioUnit;

@end

NS_ASSUME_NONNULL_END
