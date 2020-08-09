//
//  PlayerEngine.m
//  Sequence
//
//  Created by FourierHelen on 16/4/2020.
//  Copyright (c) 2020 Corporation Holtek. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudioTypes.h>
#import "CoreAudioUtils.h"
#import "PlayerEngine.h"
#import "GCDTimer.h"

@interface PlayerEngine()

@property (readwrite) AUGraph processingGraph;
@property (readwrite) AUNode samplerNode;
@property (readwrite) AUNode ioNode;
@property (readwrite) AUNode mixerNode;
@property (readwrite) AudioUnit samplerUnit;
@property (readwrite) AudioUnit mixerUnit;
@property (readwrite) AudioUnit ioUnit;
@property (nonatomic) NSMutableArray* samplerNodeList;
@property (nonatomic) NSMutableArray* samplerUnitList;
@property (nonatomic) MusicPlayer musicPlayer;
@property (nonatomic) MusicSequence musicSequence;
@property (nonatomic) MusicTrack musicTrack;
@property (nonatomic) UInt32 trackCount;
@property (nonatomic) BOOL playing;
@property (readwrite) double totalTime;
@property (nonatomic) double currentTime;
@property (nonatomic) Boolean isMute;
@property (nonatomic) Boolean muteDrum;
@property (nonatomic) NSMutableArray* instrumentArray;
@property (nonatomic) float timeRatio;


@end

@implementation PlayerEngine

@synthesize playing = _playing;
@synthesize processingGraph = _processingGraph;
@synthesize samplerNode = _samplerNode;
@synthesize mixerNode = _mixerNode;
@synthesize ioNode = _ioNode;
@synthesize ioUnit = _ioUnit;
@synthesize mixerUnit = _mixerUnit;
@synthesize samplerUnit = _samplerUnit;
//@synthesize presetNumber = _presetNumber;
@synthesize trackCount=_trackCount;
@synthesize totalTime=_totalTime;
@synthesize currentTime=_currentTime;
@synthesize isMute=_isMute;
@synthesize muteDrum=_muteDrum;

@synthesize musicSequence = _musicSequence;
@synthesize musicTrack = _musicTrack;
@synthesize musicPlayer = _musicPlayer;


-(id)init{
    if(self=[super init]){
        self.isMute=NO;
        self.muteDrum=NO;
        self.timeRatio = 1.0;
    }
    return self;
}



#pragma mark - Audio setup
- (BOOL) createAUGraph
{
    
    //新增一张音频处理图
    CheckError(NewAUGraph(&_processingGraph),
			   "NewAUGraph");
    
    

    /*
        创建节点：
        1.添加音频器件描述
        2.音频处理图根据器件描述生成1个节点
        节点数=track数
     */
    AudioComponentDescription cd = {};
    cd.componentType = kAudioUnitType_MusicDevice;
    /* MIDI合成器，多声道器件*/
    cd.componentSubType = kAudioUnitSubType_MIDISynth;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;

    for(int i=0;i<self.trackCount;i++){
        CheckError(AUGraphAddNode(self.processingGraph,
                                  &cd,
                                  &_samplerNode),
                                "AUGraphAddNode");
        [self.samplerNodeList addObject:[NSString stringWithFormat:@"%d",(int)_samplerNode]];
        
    }
    

    /*
        创建混合器节点
     */
    AudioComponentDescription mixerUnitDescription;
    mixerUnitDescription.componentType          = kAudioUnitType_Mixer;
    mixerUnitDescription.componentSubType       = kAudioUnitSubType_MultiChannelMixer;
    mixerUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    mixerUnitDescription.componentFlags         = 0;
    mixerUnitDescription.componentFlagsMask     = 0;

    CheckError(AUGraphAddNode(self.processingGraph,
                              &mixerUnitDescription,
                              &_mixerNode),
                            "AUGraphAddNode");



    
    
    // I/O unit
    /*
        创建输出节点
     */
    AudioComponentDescription iOUnitDescription;
    iOUnitDescription.componentType          = kAudioUnitType_Output;
    iOUnitDescription.componentSubType       = kAudioUnitSubType_RemoteIO;
    iOUnitDescription.componentManufacturer  = kAudioUnitManufacturer_Apple;
    iOUnitDescription.componentFlags         = 0;
    iOUnitDescription.componentFlagsMask     = 0;
    
    CheckError(AUGraphAddNode(self.processingGraph,
                              &iOUnitDescription,
                              &_ioNode),
                            "AUGraphAddNode");
    
 
    /*
        打开AUGraph才能调用AUGraphNodeInfo获取节点对应的audio unit
     */
	CheckError(AUGraphOpen(self.processingGraph), "AUGraphOpen");
    
    
    /*
        保存sampler对应的audio unit
     */
    for(int i=0;i<self.trackCount;i++){
        CAudioUnit* sampleUnit = [[CAudioUnit alloc] init];
        AudioUnit audioUnit = sampleUnit.audioUnit;
        CheckError(AUGraphNodeInfo(self.processingGraph,
                                   [self.samplerNodeList[i] intValue],
                                   NULL,
                                   &audioUnit),
                                "AUGraphNodeInfo");
        sampleUnit.audioUnit = audioUnit;
        [self.samplerUnitList addObject:sampleUnit];
        
        
        NSURL *bankURL;
        /*
            音色库
         */
         bankURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle]
         pathForResource:@"TimGM6mb" ofType:@"sf2"]];


         // load sound bank
         CheckError(AudioUnitSetProperty(audioUnit,
                                         kMusicDeviceProperty_SoundBankURL,
                                         kAudioUnitScope_Global,
                                         0,
                                         &bankURL,
                                         sizeof(bankURL)),
                                 "kAUSamplerProperty_LoadPresetFromBank");
        
        
         

        
    }
    
    /*
        保存mixer对应的audio unit
     */
    CheckError(AUGraphNodeInfo(self.processingGraph,
                               self.mixerNode,
                               NULL,
                               &_mixerUnit),
                            "AUGraphNodeInfo");
    
    /*
        保存输出对应的audio unit
     */
    CheckError(AUGraphNodeInfo(self.processingGraph,
                               self.ioNode,
                               NULL,
                               &_ioUnit),
               "AUGraphNodeInfo");
    
    /*
        设置mixer输入的数量
     */
    UInt32 busCount = self.trackCount;
    //set the mixer unit`s bus count
    CheckError(AudioUnitSetProperty(_mixerUnit,
                                    kAudioUnitProperty_ElementCount,
                                    kAudioUnitScope_Input,
                                    0,
                                    &busCount,
                                    sizeof(busCount)),
               "AudioUnitSetProperty_SetMixerInputCount");
    
    /*
        设置mixer的采样率，44.1kHz是标准采样率
     */
    Float64 graphSampleRate = 44100.0;
    //set mixer unit`s output sample rate format
    CheckError(AudioUnitSetProperty(_mixerUnit,
                                    kAudioUnitProperty_SampleRate,
                                    kAudioUnitScope_Output,
                                    0,
                                    &graphSampleRate,
                                    sizeof(graphSampleRate)),
               "AudioUnitSetProperty_SetMixerSampleRate");

    //connect samplers to mixer unit
    /*
        将sampler unit的输出连到mixer的输入
     */
    for(int i=0;i<self.trackCount;i++){
        CheckError(AUGraphConnectNodeInput(self.processingGraph,
                                           [self.samplerNodeList[i] intValue],
                                           0,
                                           self.mixerNode,
                                           i),
                   "AUGraphConnectNodeInput_ConnectSamplersToMixerUnit");
    }

    //connect mixer to output unit
    /*
      将mixer的输出连到remote I/O的输入
     */
    CheckError(AUGraphConnectNodeInput(self.processingGraph,
                                       self.mixerNode,
                                       0,
                                       self.ioNode,
                                       0),
                    "AUGraphConnectNodeInput_ConnectMixerToOutput");
    
    
    
	NSLog (@"AUGraph is configured");
	CAShow(self.processingGraph);
    
    return YES;
}

- (void) startGraph
{
    /*
       音频处理图的初始化和开启
     */
    if (self.processingGraph) {

        Boolean outIsInitialized;
        CheckError(AUGraphIsInitialized(self.processingGraph,
                                        &outIsInitialized), "AUGraphIsInitialized");
        if(!outIsInitialized)
            CheckError(AUGraphInitialize(self.processingGraph), "AUGraphInitialize");
        
        Boolean isRunning;
        CheckError(AUGraphIsRunning(self.processingGraph,
                                    &isRunning), "AUGraphIsRunning");
        if(!isRunning)
            CheckError(AUGraphStart(self.processingGraph), "AUGraphStart");
    }
}
- (void) stopAUGraph {
    
    NSLog (@"Stopping audio processing graph");
    Boolean isRunning = false;
    CheckError(AUGraphIsRunning (self.processingGraph, &isRunning), "AUGraphIsRunning");
    
    if (isRunning) {
        CheckError(AUGraphStop(self.processingGraph), "AUGraphStop");
        self.playing = NO;
    }
}


#pragma mark --- Audio control

- (void) loadMIDIFileWithString:(NSString*)string
{

    
    NSString* stringPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"MIDI Files/%@.mid",string]];
    
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:stringPath];
    
    if(isExist){
        NSURL* midiFileURL = [[NSURL alloc] initFileURLWithPath:stringPath];
            
        //新建MusicSequence
        CheckError(NewMusicSequence(&_musicSequence), "NewMusicSequence");
         
        //把文件加載到MusicSequence
        CheckError(MusicSequenceFileLoad(self.musicSequence,
                                         (__bridge CFURLRef) midiFileURL,
                                         0,
                                         kMusicSequenceLoadSMF_ChannelsToTracks), "MusicSequenceFileLoad");
        
         
        CAShow(self.musicSequence);
        
        
        //讀取MIDI文件軌道數量
        CheckError(MusicSequenceGetTrackCount(self.musicSequence, &_trackCount), "MusicSequenceGetTrackCount");
        
        
        [self createAUGraph];
        
        [self startGraph];
        
        
        CheckError(NewMusicPlayer(&_musicPlayer), "NewMusicPlayer");
        
        CheckError(MusicPlayerSetSequence(self.musicPlayer, self.musicSequence), "MusicPlayerSetSequence");
        
        //關聯Sequence和AUGraph
        CheckError(MusicSequenceSetAUGraph(self.musicSequence, self.processingGraph),
        "MusicSequenceSetAUGraph");
        
       
        
        MusicTrack track;
        MusicTimeStamp maxTrackLength = 0;
        for(int i = 0; i < self.trackCount; i++)
        {
            CheckError(MusicSequenceGetIndTrack (self.musicSequence, i, &track), "MusicSequenceGetIndTrack");
            
            MusicTimeStamp track_length;
            UInt32 tracklength_size = sizeof(MusicTimeStamp);
            CheckError(MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &track_length, &tracklength_size), "kSequenceTrackProperty_TrackLength");

            
            MusicTimeStamp track_offset = 0;
            UInt32 trackoffset_size = sizeof(track_offset);
            CheckError(MusicTrackGetProperty(track, kSequenceTrackProperty_OffsetTime, &track_offset, &trackoffset_size), "kSequenceTrackProperty_OffsetTime_TrackOffset");
            
            MusicTimeStamp trackLength = track_length + track_offset;
            if(trackLength>maxTrackLength) maxTrackLength = trackLength;
            
            
            
            MusicTrackLoopInfo loopInfo;
            UInt32 lisize = sizeof(MusicTrackLoopInfo);
            CheckError(MusicTrackGetProperty(track,kSequenceTrackProperty_LoopInfo, &loopInfo, &lisize ), "kSequenceTrackProperty_LoopInfo");
            NSLog(@"Loop info: duration %f", loopInfo.loopDuration);
            
            
            [self iterate:track TrackIndex:i];
            
            CheckError(MusicTrackSetDestNode(track, [self.samplerNodeList[i] intValue]), "MusicTrackSetDestNode");
        }
        
        
        CheckError(MusicSequenceGetSecondsForBeats(self.musicSequence, maxTrackLength, &_totalTime), "MusicSequenceGetSecondsForBeats");
        NSLog(@"Music total time is: %f",self.totalTime);
        
        __weak typeof(self) weakSelf=self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if([weakSelf.delegate respondsToSelector:@selector(GetMusicTotalTime:)]){
                            [weakSelf.delegate GetMusicTotalTime:weakSelf.totalTime];
                        }
                            
        });
        

        /*
            播放准备
         */

        self.currentTime=0;
        

    }
    else{
        NSLog(@"文件不存在！");
    }
    

}



- (void) iterate: (MusicTrack) track TrackIndex:(int)index
{
	MusicEventIterator	iterator;
	CheckError(NewMusicEventIterator (track, &iterator), "NewMusicEventIterator");
    
    
    MusicEventType eventType;
	MusicTimeStamp eventTimeStamp;
    UInt32 eventDataSize;
    const void *eventData;
    
    Boolean	hasCurrentEvent = NO;
    CheckError(MusicEventIteratorHasCurrentEvent(iterator, &hasCurrentEvent), "MusicEventIteratorHasCurrentEvent");
    while (hasCurrentEvent)
    {
        MusicEventIteratorGetEventInfo(iterator, &eventTimeStamp, &eventType, &eventData, &eventDataSize);
        NSLog(@"event timeStamp %f ", eventTimeStamp);
        switch (eventType) {
                
            case kMusicEventType_ExtendedNote : {
                ExtendedNoteOnEvent* ext_note_evt = (ExtendedNoteOnEvent*)eventData;
                NSLog(@"extended note event, instrumentID %u", (unsigned int)ext_note_evt->instrumentID);

            }
                break ;
                
            case kMusicEventType_ExtendedTempo : {
                ExtendedTempoEvent* ext_tempo_evt = (ExtendedTempoEvent*)eventData;
                NSLog(@"ExtendedTempoEvent, bpm %f", ext_tempo_evt->bpm);

            }
                break ;
                
            case kMusicEventType_User : {
                MusicEventUserData* user_evt = (MusicEventUserData*)eventData;
                NSLog(@"MusicEventUserData, data length %u", (unsigned int)user_evt->length);
            }
                break ;
                
            case kMusicEventType_Meta : {
                MIDIMetaEvent* meta_evt = (MIDIMetaEvent*)eventData;
                NSLog(@"MIDIMetaEvent, event type %d", meta_evt->metaEventType);

            }
                break ;
                
            case kMusicEventType_MIDINoteMessage : {
                MIDINoteMessage* note_evt = (MIDINoteMessage*)eventData;
                NSLog(@"note event channel %d", note_evt->channel);
                NSLog(@"note event note %d", note_evt->note);
                NSLog(@"note event duration %f", note_evt->duration);
                NSLog(@"note event velocity %d", note_evt->velocity);
                
            }
                break ;
                
            case kMusicEventType_MIDIChannelMessage : {
                MIDIChannelMessage* channel_evt = (MIDIChannelMessage*)eventData;
                NSLog(@"channel event status %X", channel_evt->status);
                NSLog(@"channel event d1 %X", channel_evt->data1);
                NSLog(@"channel event d2 %X", channel_evt->data2);
                
                if((channel_evt->status& 0xF0) == 0xC0 ) {
                    /*
                        静音处理
                     */
                Boolean isSet = NO; /* 判断轨道是否设置静音 */
                if(self.isMute){
                    
                    for(int i=0;i<self.instrumentArray.count;i++){
                        int instrument = [self.instrumentArray[i] intValue];
                        if(channel_evt->data1==instrument){
                            isSet=YES;
                            CheckError(MusicTrackSetProperty(track, kSequenceTrackProperty_MuteStatus, &_isMute, sizeof(_isMute)), "SetMusicTrackMute");
                        }

                     }

                    }
                     if(self.muteDrum&&((channel_evt->status& 0x0F)==9)){
                        isSet=YES;
                        CheckError(MusicTrackSetProperty(track, kSequenceTrackProperty_MuteStatus, &_muteDrum, sizeof(_muteDrum)), "SetMusicTrackMuteDrum");

                    }
                    

                }
            }
                break ;
                
            case kMusicEventType_MIDIRawData : {
//                MIDIRawData* raw_data_evt = (MIDIRawData*)eventData;
//                NSLog(@"MIDIRawData, length %lu", raw_data_evt->length);

            }
                break ;
                
            case kMusicEventType_Parameter : {
//                ParameterEvent* parameter_evt = (ParameterEvent*)eventData;
//                NSLog(@"ParameterEvent, parameterid %lu", parameter_evt->parameterID);

            }
                break ;
                
            default :
                break ;
        }
        
        CheckError(MusicEventIteratorHasNextEvent(iterator, &hasCurrentEvent), "MusicEventIteratorHasCurrentEvent");
        CheckError(MusicEventIteratorNextEvent(iterator), "MusicEventIteratorNextEvent");
    }
}

- (void) playMIDIFile
{
    CheckError(MusicPlayerPreroll(self.musicPlayer), "MusicPlayerPreroll");
    
    CheckError(MusicPlayerSetPlayRateScalar(self.musicPlayer, self.timeRatio), "MusicPlayerSetPlayRateScalar");
    
    CheckError(MusicPlayerStart(self.musicPlayer), "MusicPlayerStart");
    self.playing = YES;
    
    __weak typeof(self) weakSelf=self;
    dispatch_queue_t queue = dispatch_queue_create("Timer", DISPATCH_QUEUE_SERIAL);
    [[GCDTimer shared] scheduleGCDTimerWithName:@"MusicPlayerTimer" Interval:10 Queue:queue Repeats:YES Action:^{
        

        
        MusicTimeStamp currentStamp;
        CheckError(MusicPlayerGetTime(weakSelf.musicPlayer, &currentStamp), "MusicPlayerGetTime_CurrentTimeStamp");
        CheckError(MusicSequenceGetSecondsForBeats(weakSelf.musicSequence, currentStamp, &_currentTime), "MusicSequencself->eGetSecondsForBeats_CurrentTime");
                
        
        
        
        if(weakSelf.currentTime>=weakSelf.totalTime){
            
            weakSelf.currentTime=weakSelf.totalTime;
            dispatch_async(dispatch_get_main_queue(), ^{
                            if([weakSelf.delegate respondsToSelector:@selector(ProgressUpdated:)]){
                    [weakSelf.delegate ProgressUpdated:weakSelf.currentTime/weakSelf.totalTime];
                }

            });
            
            [[GCDTimer shared] cancelAllTimer];
            CheckError(MusicPlayerStop(weakSelf.musicPlayer), "MusicPlayerStop");

            weakSelf.playing=NO;
            weakSelf.currentTime=0;
            CheckError(MusicSequenceGetBeatsForSeconds(weakSelf.musicSequence, weakSelf.currentTime, &currentStamp), "MusicSequenceGetBeatsForSeconds_SetCurrentStamp");
            CheckError(MusicPlayerSetTime(weakSelf.musicPlayer, currentStamp), "MusicPlayerSetTime_SetZero");
                        
        }
        else{
            dispatch_async(dispatch_get_main_queue(), ^{
                            if([weakSelf.delegate respondsToSelector:@selector(ProgressUpdated:)]){
                    [weakSelf.delegate ProgressUpdated:weakSelf.currentTime/weakSelf.totalTime];
                }

            });


        }
        
        
    }];
}

- (void)stopPlayingMIDIFile
{
    
    CheckError(MusicPlayerStop(self.musicPlayer), "MusicPlayerStop");
    self.playing = NO;
    [[GCDTimer shared] cancelAllTimer];
}

-(Boolean)setMusicPlayerSpeed:(float)speed{
    if(speed<0) return false;
    else{
        self.timeRatio = speed;
        if(self.musicPlayer){
            
            CheckError(MusicPlayerSetPlayRateScalar(self.musicPlayer, self.timeRatio), "MusicPlayerSetPlayRateScalar");

        }
        return true;
    }
}

-(void)setProgress:(float)progress{
    if(progress>1||progress<0) return;
    
    self.currentTime = self.totalTime*progress;
    MusicTimeStamp currentStamp;
    CheckError(MusicSequenceGetBeatsForSeconds(self.musicSequence, self.currentTime, &currentStamp), "MusicSequenceGetBeatsForSeconds_SetCurrentStamp");
    CheckError(MusicPlayerSetTime(self.musicPlayer, currentStamp), "MusicPlayerSetTime_SetZero");
    
    [self stopPlayingMIDIFile];
    
    [self playMIDIFile];

    
}

-(void)muteWithInstrument:(UInt8)instrument{
    if(instrument<0||instrument>127) return;
    
    NSNumber* numIns = [NSNumber numberWithInt:instrument];
    [self.instrumentArray addObject:numIns];
    
    self.isMute = YES;
}

-(void)muteWithDrum{
    self.muteDrum=YES;
    
}



-(Boolean)isPlayingFile{
    
    return self.playing;
}

-(double)musicTotalTime{
    return self.totalTime;
}

-(double)musicCurrentTime{
    return self.currentTime;
}


-(void)volume:(float)volume WithTrack:(UInt32)trackNum{
    
    if(volume<0||volume>1) return;
    if(trackNum<0||trackNum>self.trackCount) return;
    
    
    CheckError(AudioUnitSetParameter(_mixerUnit,
                                     kMultiChannelMixerParam_Volume,
                                     kAudioUnitScope_Input,
                                     trackNum,
                                     volume,
                                     0),
                                "AudioUnitSetMixerInputVolume");
    
}


-(void) cleanup
{
    if(self.musicPlayer){
       
        //當前在播放，先暫停
        if([self isPlayingFile]){

            [self stopPlayingMIDIFile];
        }

        CheckError(MusicSequenceGetTrackCount(self.musicSequence, &_trackCount), "MusicSequenceGetTrackCount");
        MusicTrack track;
        for(int i = 0;i < self.trackCount; i++)
        {
            CheckError(MusicSequenceGetIndTrack (self.musicSequence,0,&track), "MusicSequenceGetIndTrack");
            CheckError(MusicSequenceDisposeTrack(self.musicSequence, track), "MusicSequenceDisposeTrack");
        }
        
        CheckError(DisposeMusicPlayer(self.musicPlayer), "DisposeMusicPlayer");
        CheckError(DisposeMusicSequence(self.musicSequence), "DisposeMusicSequence");
        CheckError(DisposeAUGraph(self.processingGraph), "DisposeAUGraph");
        
        
        self.playing=NO;
        
        [self.samplerNodeList removeAllObjects];
        [self.samplerUnitList removeAllObjects];
        [self.instrumentArray removeAllObjects];
        
        self.isMute=NO;
        self.muteDrum=NO;

        NSLog(@"CleanUp!");
        
    }
    

    
}




#pragma mark --- Lazyload
-(NSMutableArray*)samplerNodeList{
    if(!_samplerNodeList){
        _samplerNodeList=[[NSMutableArray alloc] init];
    }
    return _samplerNodeList;
}

-(NSMutableArray*)samplerUnitList{
    if(!_samplerUnitList){
        _samplerUnitList=[[NSMutableArray alloc] init];
    }
    return _samplerUnitList;
}

-(NSMutableArray*)instrumentArray{
    if(!_instrumentArray){
        _instrumentArray=[[NSMutableArray alloc] init];
    }
    return _instrumentArray;
}


/*
 物理连接
  ____________
 |            |
 |  Sampler   |-------
 |            |       |
  ------------        |
                      |
  ____________        |       ----------------------                ------------
 |            |        ----->|                      |              |            |
 |  Sampler   |------------->|  MultiChannel Mixer  |------------->|    I/O     |
 |            |        ----->|                      |              |            |
  ------------        |       ----------------------                ------------
                      |
  ____________        |
 |            |       |
 |  Sampler   |-------
 |            |
  ------------
 
 
 
 
 
 
  ---------------------          -------------------------------------------------
 |    MusicSequence    |        |                    AUGraph                      |
 |                     |        |                                                 |
 |     MusicTrack1  ---|--------| ->MIDISynth1                                    |
 |                     |        |               --->MixerNode ------->  OutputNode|
 |     MusicTrack2  ---|--------| ->MIDISynth2                                    |
 |                     |        |                                                 |
  ---------------------          -------------------------------------------------
 
 
 */


@end
    
