//
//  ViewController.m
//  MIDIPlayer
//
//  Created by Corporation Holtek on 2/8/2020.
//  Copyright © 2020 Corporation Holtek. All rights reserved.
//

#import "ViewController.h"
#import "PlayerEngine.h"

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource,PlayerEngineDelegate>{
    
    int slowCount;
    int fastCount;
    int musicProgress;
    float musicTotalTime;

}

@property (weak, nonatomic) IBOutlet UITableView *songTableView;

@property (weak, nonatomic) IBOutlet UISlider *progressSlider;

@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;

@property (weak, nonatomic) IBOutlet UILabel *totalTimeLabel;

@property (weak, nonatomic) IBOutlet UIButton *playButton;


@property (weak, nonatomic) IBOutlet UIButton *slowButton;

@property (weak, nonatomic) IBOutlet UIButton *fastButton;

@property (nonatomic,strong) PlayerEngine* playerEngine;

@property (nonatomic,copy) NSString* currentSong;

@property(nonatomic)NSArray* songList;





@end

@implementation ViewController



- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.playerEngine=[[PlayerEngine alloc] init];
//    self.queue = dispatch_queue_create("LoadFile", DISPATCH_QUEUE_SERIAL);

    
    
    self.songTableView.delegate=self;
    self.songTableView.dataSource=self;
    
    self.playerEngine.delegate=self;
    
    slowCount=0;
    fastCount=0;
    
    self.currentSong=nil;
    
    self.progressSlider.value=0;
    [self.progressSlider addTarget:self action:@selector(ChangeProgress) forControlEvents:UIControlEventValueChanged];

    
  

        
    
}






- (IBAction)StopPlay:(id)sender {
    
    if(self.currentSong==nil){
        return;
    }
    
    if([self.playerEngine isPlayingFile]){
        [self.playerEngine stopPlayingMIDIFile];
        [self.playButton setImage:[UIImage imageNamed:@"Start"] forState:UIControlStateNormal];
    }
    else{
        [self.playerEngine playMIDIFile];
        [self.playButton setImage:[UIImage imageNamed:@"Stop"] forState:UIControlStateNormal];
    }
}



- (IBAction)SlowPlay:(id)sender {
    slowCount++;
    switch (slowCount) {
        case 1:{
            [self.slowButton setTitle:@"0.7" forState:UIControlStateNormal];
            [self.playerEngine setMusicPlayerSpeed:0.7];
        }
            break;
        case 2:{
            [self.slowButton setTitle:@"0.5" forState:UIControlStateNormal];
            [self.playerEngine setMusicPlayerSpeed:0.5];
        }
            break;
        default:{
            slowCount=0;
            [self.slowButton setTitle:@"Slow" forState:UIControlStateNormal];
            [self.playerEngine setMusicPlayerSpeed:1.0];
        }
            break;
    }
    
}



- (IBAction)FastPlay:(id)sender {
    fastCount++;
    switch (fastCount) {
        case 1:{
            [self.fastButton setTitle:@"1.5" forState:UIControlStateNormal];
            [self.playerEngine setMusicPlayerSpeed:1.5];
        }
            break;
        case 2:{
            [self.fastButton setTitle:@"2.0" forState:UIControlStateNormal];
            [self.playerEngine setMusicPlayerSpeed:2.0];
        }
            break;
        default:{
            fastCount=0;
            [self.fastButton setTitle:@"Fast" forState:UIControlStateNormal];
            [self.playerEngine setMusicPlayerSpeed:1.0];
        }
            break;
    }

}

//更新播放進度
-(void)ProgressUpdated:(float)progress{
    
    if(progress==1.0){
        [self.playButton setImage:[UIImage imageNamed:@"Start"] forState:UIControlStateNormal];
        
        [self.playerEngine stopPlayingMIDIFile];

    }

    float musicCurrentTime = progress*musicTotalTime;
    int currentTime = (int)(musicCurrentTime+0.5);
    if((currentTime-(currentTime/60*60))<10){
       self.currentTimeLabel.text=[NSString stringWithFormat:@"%d:0%d",currentTime/60,currentTime-(currentTime/60*60)];
    }
    else{
        self.currentTimeLabel.text=[NSString stringWithFormat:@"%d:%d",currentTime/60,currentTime-(currentTime/60*60)];
    }
    
    
    self.progressSlider.value=progress;
    
    
}

//調整播放進度
-(void)ChangeProgress{
    
    if(self.currentSong==nil){
        self.progressSlider.value=0;
        return;
    }
    [self.playerEngine setProgress:self.progressSlider.value];
    
}


//獲取歌曲長度
-(void)GetMusicTotalTime:(float)time{
    
    musicTotalTime = time;
    self.progressSlider.userInteractionEnabled=YES;
    
    int totalTime = (int)(time+0.5);
    if((totalTime-(totalTime/60*60))<10){
       self.totalTimeLabel.text=[NSString stringWithFormat:@"%d:0%d",totalTime/60,totalTime-(totalTime/60*60)];
    }
    else{
        self.totalTimeLabel.text=[NSString stringWithFormat:@"%d:%d",totalTime/60,totalTime-(totalTime/60*60)];

    }
    
    [self.playButton setImage:[UIImage imageNamed:@"Stop"] forState:UIControlStateNormal];
    
    
    
}


-(NSInteger)tableView:(UITableView*) tableView numberOfRowsInSection:(NSInteger)section{
    
    return self.songList.count;
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if(!cell) {

    cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    
    cell.textLabel.text=self.songList[indexPath.row];
    
    return cell;
    
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    [self.playButton setImage:[UIImage imageNamed:@"Start"] forState:UIControlStateNormal];
    self.progressSlider.value=0;
    
    __weak typeof(self) weakSelf=self;
    dispatch_queue_t queue = dispatch_queue_create("LoadFile", DISPATCH_QUEUE_SERIAL);

    if(self.songList[indexPath.row]!=self.currentSong){

        self.totalTimeLabel.text=[NSString stringWithFormat:@"0:00"];
        self.currentTimeLabel.text=[NSString stringWithFormat:@"0:00"];
        self.progressSlider.userInteractionEnabled=NO;

        dispatch_async(queue, ^{
            
                if([weakSelf.playerEngine isPlayingFile]){
                   [weakSelf.playerEngine stopPlayingMIDIFile];
                }
                if(self.currentSong!=nil){
                  [weakSelf.playerEngine cleanup];
                }

            //[weakSelf.PlayerEngine muteWithInstrument:100];
            //[weakSelf.PlayerEngine muteWithInstrument:30];
             //[weakSelf.PlayerEngine muteWithDrum];

                [weakSelf.playerEngine loadMIDIFileWithString:weakSelf.songList[indexPath.row]];

                weakSelf.currentSong=weakSelf.songList[indexPath.row];
                [weakSelf.playerEngine playMIDIFile];


        });



    }
    else{

        [self.playButton setImage:[UIImage imageNamed:@"Stop"] forState:UIControlStateNormal];
        if([self.playerEngine isPlayingFile]){
            return;
        }
        else{
            __weak typeof(self) weakSelf=self;
            dispatch_async(queue, ^{
  
                [weakSelf.playerEngine playMIDIFile];

            });

        }
    }

    
    


    
    
}




-(NSArray*)songList{
    if(!_songList){
        
        NSString* path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"MIDI Files"];
        NSFileManager* maneger = [NSFileManager defaultManager];
        NSArray* contentArray = [maneger contentsOfDirectoryAtPath:path error:nil];
        
        NSMutableArray* tempArray = [[NSMutableArray alloc] init];
        
        
        for(int i = 0;i<contentArray.count;i++){
            
            NSString* name = [contentArray[i] stringByDeletingPathExtension];
            [tempArray addObject:name];
        }
        
        
        _songList = [[NSArray alloc] initWithArray:tempArray];
        
    }
    return _songList;
}





@end
