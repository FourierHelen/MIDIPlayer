//
//  PlayerEngine.h
//  Sequence
//
//  Created by FourierHelen on 16/4/2020.
//  Copyright (c) 2020 Corporation Holtek. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "CAudioUnit.h"

@protocol PlayerEngineDelegate <NSObject>

@optional
/*    范围：[0,1],每10ms更新一次   */
-(void)ProgressUpdated:(float)progress;

/* 歌曲数据加载完,可返回歌曲总时长  */
-(void)GetMusicTotalTime:(float)time;

@end


@interface PlayerEngine : NSObject<PlayerEngineDelegate>

@property (nonatomic,weak)id<PlayerEngineDelegate> delegate;

//@property (nonatomic) BOOL playing;
//@property (nonatomic) UInt8 presetNumber;
//@property (nonatomic) MusicPlayer musicPlayer;
//@property (nonatomic) MusicSequence musicSequence;
//@property (nonatomic) MusicTrack musicTrack;

/*  加载MIDI文件  */
- (void)loadMIDIFileWithString:(NSString*)string;

/*  播放 */
- (void)playMIDIFile;
/*  暂停 */
- (void)stopPlayingMIDIFile;

/* 清空加载的音乐数据 */
- (void)cleanup;

/* 获取当前音乐的播放时间，单位：秒 */
- (double)musicTotalTime;

/* 获取当前音乐的播放时间，单位:秒 */
-(double)musicCurrentTime;

/* 播放器当前状态 */
-(Boolean)isPlayingFile;

/*  设置播放速度,快播:(1,+∞),慢放:(0,1)   */
-(Boolean)setMusicPlayerSpeed:(float)speed;

/* 设置播放进度 progress的设置范围[0，1] */
-(void)setProgress:(float)progress;

/* 屏蔽具体一种乐器的声音。注意：屏蔽操作需要在加载MIDI文件之前调用！！！  */
-(void)muteWithInstrument:(UInt8)instrument;

/* 屏蔽鼓组。注意：屏蔽操作需要在加载MIDI文件之前调用！！！ */
-(void)muteWithDrum;

/*  調節某一軌的音量  範圍:[0,1] */
-(void)volume:(float)volume WithTrack:(UInt32)trackNum;


@end
