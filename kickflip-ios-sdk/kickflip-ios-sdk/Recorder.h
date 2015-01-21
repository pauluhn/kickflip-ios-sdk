//
//  Recorder.h based on KFRecorder, CameraServer
//  kickflip-ios-sdk, encoderdemo
//
//  Created by Paul on 1/21/15.
//  Copyright (c) 2015 Paul. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class Recorder;
@protocol RecorderDelegate <NSObject>
- (void)recorder:(Recorder *)recorder onConfig:(NSData *)config;
- (void)recorder:(Recorder *)recorder onVideoData:(NSArray *)data time:(double)pts;
- (void)recorder:(Recorder *)recorder onAudioData:(NSArray *)data time:(double)pts;
@end

@interface Recorder : NSObject

@property (nonatomic, weak) id<RecorderDelegate> delegate;

+ (Recorder*) recorder;
- (void) startup;
- (void) shutdown;
- (AVCaptureVideoPreviewLayer*) getPreviewLayer;

@end
