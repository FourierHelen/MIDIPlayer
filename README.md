#  MIDIPlayer
MIDIPlayer是一款MIDI文件播放器，可加載多軌道MIDI文件，保證聲音不失真。
包含播放、暫停、調整播放速度、屏蔽音軌、調整音軌音量功能。
    

## 實現
基於AudioToolBox提供的API，構建音頻處理圖和音頻節點。將音頻節點連接到mixer的輸入端，mixer的輸出端連接至揚聲器。加載MIDI文件後，將音樂序列連接到音頻處理圖，由音頻節點處理MIDI事件。  相較於原生的AVMIDIPlayer，分離了文件加載操作和播放操作，可實現低延時播放。加載MIDI文件時也可替換軌道的音色、調整軌道音量大小。

## 使用
初始化
`PlayerEngine* playerEngine = [PlayerEngine alloc] init];`

加載文件
`[playerEngine loadMIDIFileWithString:@"loveteam.mid"];`

播放
`[playerEngine playMIDIFile];`

切換歌曲時，清除上一首歌曲加載的數據
`[playerEngine cleanup];`

## DIY
### 添加歌曲
添加歌曲到MIDI Files文件夾即可，無需修改代碼

### 替換音色庫
將音色庫添加到SoundFont文件夾後，在PlayerEngine.m的CreateGraph中修改音色庫名稱即可
```
bankURL = [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle]
pathForResource:@"TimGM6mb" ofType:@"sf2"]];

```



    



