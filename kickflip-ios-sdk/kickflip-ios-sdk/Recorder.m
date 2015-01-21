//
//  Recorder.m based on KFRecorder, CameraServer
//  kickflip-ios-sdk, encoderdemo
//
//  Created by Paul on 1/21/15.
//  Copyright (c) 2015 Paul. All rights reserved.
//

#import "Recorder.h"
#import "AVEncoder.h"
#import "KFAACEncoder.h"
#import "KFFrame.h"

static Recorder* theRecorder;

@interface Recorder () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, KFEncoderDelegate>
{
    AVCaptureSession* _session;
    AVCaptureVideoPreviewLayer* _preview;
    AVCaptureVideoDataOutput* _videoOutput;
    AVCaptureAudioDataOutput* _audioOutput;
    dispatch_queue_t _videoQueue;
    dispatch_queue_t _audioQueue;
    AVCaptureConnection *_videoConnection;
    AVCaptureConnection *_audioConnection;
    
    AVEncoder* _h264Encoder;
    KFAACEncoder *_aacEncoder;
}
@end

@implementation Recorder

+ (void) initialize
{
    // test recommended to avoid duplicate init via subclass
    if (self == [Recorder class])
    {
        theRecorder = [[Recorder alloc] init];
    }
}

+ (Recorder*) recorder
{
    return theRecorder;
}

- (void) startup
{
    if (_session == nil)
    {
        NSLog(@"Starting up server");
        
        _session = [[AVCaptureSession alloc] init];
        
        [self setupVideoCapture];
        [self setupAudioCapture];
        
        [self setupVideoEncoder];
        [self setupAudioEncoder];
        
        // start capture and a preview layer
        [_session startRunning];
        
        
        _preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
        _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
    }
}

- (void)setupVideoCapture
{
    AVCaptureDevice* dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:nil];
    if ([_session canAddInput:input]) {
        [_session addInput:input];
    }
    _videoQueue = dispatch_queue_create("uk.co.gdcl.avencoder.capture", DISPATCH_QUEUE_SERIAL);
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setSampleBufferDelegate:self queue:_videoQueue];
    NSDictionary* setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                    nil];
    _videoOutput.videoSettings = setcapSettings;
    if ([_session canAddOutput:_videoOutput]) {
        [_session addOutput:_videoOutput];
    }
    _videoConnection = [_audioOutput connectionWithMediaType:AVMediaTypeVideo];
}

- (void)setupAudioCapture
{
    AVCaptureDevice* dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput* input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:nil];
    if ([_session canAddInput:input]) {
        [_session addInput:input];
    }
    _audioQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [_audioOutput setSampleBufferDelegate:self queue:_audioQueue];
    if ([_session canAddOutput:_audioOutput]) {
        [_session addOutput:_audioOutput];
    }
    _audioConnection = [_audioOutput connectionWithMediaType:AVMediaTypeAudio];
}

- (void)setupVideoEncoder
{
    _h264Encoder = [AVEncoder encoderForHeight:480 andWidth:720];
    [_h264Encoder encodeWithBlock:^int(NSArray* data, double pts) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(recorder:onVideoData:time:)]) {
            [self.delegate recorder:self onVideoData:data time:pts];
        }
        return 0;
    } onParams:^int(NSData *data) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(recorder:onConfig:)]) {
            [self.delegate recorder:self onConfig:data];
        }
        return 0;
    }];
}

- (void)setupAudioEncoder
{
    int audioBitrate = 64 * 1000; // 64 Kbps
    _aacEncoder = [[KFAACEncoder alloc] initWithBitrate:audioBitrate sampleRate:44100 channels:1];
    _aacEncoder.delegate = self;
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // pass frame to encoder
    if (connection == _videoConnection) {
        [_h264Encoder encodeFrame:sampleBuffer];
    }
    else if (connection == _audioConnection) {
        [_aacEncoder encodeSampleBuffer:sampleBuffer];
    }
}

- (void) shutdown
{
    NSLog(@"shutting down server");
    if (_session)
    {
        [_session stopRunning];
        _session = nil;
    }
    if (_h264Encoder)
    {
        [ _h264Encoder shutdown];
    }
}

- (AVCaptureVideoPreviewLayer*) getPreviewLayer
{
    return _preview;
}

#pragma mark - KFEncoderDelegate

- (void)encoder:(KFEncoder *)encoder encodedFrame:(KFFrame *)frame
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(recorder:onAudioData:time:)]) {
        [self.delegate recorder:self onAudioData:@[frame.data] time:((double)frame.pts.value/(double)frame.pts.timescale)];
    }
}

@end
