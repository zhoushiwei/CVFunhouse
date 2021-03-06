//
//  CVFMainViewController.m
//  CVFunhouse
//
//  Created by John Brewer on 3/7/12.
//  Copyright (c) 2012 Jera Design LLC. All rights reserved.
//

#import "CVFMainViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "CVFFlipsideViewController.h"

#import "CVFCannyDemo.h"
#import "CVFFaceDetect.h"
#import "CVFFarneback.h"
#import "CVFLaplace.h"
#import "CVFLukasKanade.h"
#import "CVFMotionTemplates.h"

#import "CVFSephiaDemo.h"
#import "CVFPassThru.h"

@interface CVFMainViewController ()

- (void)setupCamera;
- (void)turnCameraOn;
- (void)turnCameraOff;
- (void)resetImageProcessor;

@end

@implementation CVFMainViewController {
    AVCaptureDevice *_cameraDevice;
    AVCaptureSession *_session;
    AVCaptureVideoPreviewLayer *_previewLayer;
    CVFImageProcessor *_imageProcessor;
    NSDate *_lastFrameTime;
    CGPoint _descriptionOffScreenCenter;
    CGPoint _descriptionOnScreenCenter;
    bool _useBackCamera;
}

@synthesize fpsLabel = _fpsLabel;
@synthesize flipCameraButton = _flipCameraButton;
@synthesize descriptionView = _descriptionView;
@synthesize flipsidePopoverController = _flipsidePopoverController;
@synthesize imageView = _imageView;
//@synthesize imageProcessor = _imageProcessor;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self showHideFPS];
    [self initializeDescription];
    [self resetImageProcessor];
    _useBackCamera = [[NSUserDefaults standardUserDefaults] boolForKey:@"useBackCamera"];
    [self setupCamera];
    [self turnCameraOn];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resetImageProcessor)
                                                 name:@"demoNumber"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showHideFPS)
                                                 name:@"showFPS"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showHideDescription)
                                                 name:@"showDescription"
                                               object:nil];
}

- (void)resetImageProcessor {
    int demoNumber = [[NSUserDefaults standardUserDefaults] integerForKey:@"demoNumber"];

    switch (demoNumber) {
        case 0:
            self.imageProcessor = [[CVFCannyDemo alloc] init];
            break;
            
        case 1:
            self.imageProcessor = [[CVFFaceDetect alloc] init];
            break;
            
        case 2:
            self.imageProcessor = [[CVFFarneback alloc] init];
            break;
            
        case 3:
            self.imageProcessor = [[CVFLaplace alloc] init];
            break;
            
        case 4:
            self.imageProcessor = [[CVFLukasKanade alloc] init];
            break;
            
        case 5:
            self.imageProcessor = [[CVFMotionTemplates alloc] init];
            break;
            
        case 6:
            self.imageProcessor = [[CVFSephiaDemo alloc] init];
            break;
            
        case 7:
        default:
            self.imageProcessor = [[CVFPassThru alloc] init];
            break;
    }
    
    NSString *className = NSStringFromClass([self.imageProcessor class]);
    NSURL *descriptionUrl = [[NSBundle mainBundle] URLForResource:className withExtension:@"html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:descriptionUrl];
    [self.descriptionView loadRequest:request];
}

- (void)showHideFPS {
    bool showFPS = [[NSUserDefaults standardUserDefaults] boolForKey:@"showFPS"];
    [self.fpsLabel setHidden:!showFPS];
}

- (void)initializeDescription {
    self.descriptionView.layer.borderColor = [UIColor blackColor].CGColor;
    self.descriptionView.layer.borderWidth = 1.0;
    
    _descriptionOnScreenCenter = self.descriptionView.center;
    _descriptionOffScreenCenter = self.descriptionView.center;
    int descriptionTopY = self.descriptionView.center.y -
    self.descriptionView.bounds.size.height / 2;
    _descriptionOffScreenCenter.y += self.view.bounds.size.height - descriptionTopY;

    bool showDescription = [[NSUserDefaults standardUserDefaults] boolForKey:@"showDescription"];
    self.descriptionView.hidden = !showDescription;
}

- (void)showHideDescription {
    bool showDescription = [[NSUserDefaults standardUserDefaults] boolForKey:@"showDescription"];
    if (showDescription && self.descriptionView.isHidden) {
        self.descriptionView.center = _descriptionOffScreenCenter;
        [self.descriptionView setHidden:false];
        [UIView animateWithDuration:0.5 animations:^{
            self.descriptionView.center = _descriptionOnScreenCenter;
        }];
    } else if (!showDescription && !self.descriptionView.isHidden) {
        [UIView animateWithDuration:0.5 animations:^{
            self.descriptionView.center = _descriptionOffScreenCenter;
        } completion:^(BOOL finished) {
            self.descriptionView.hidden = true;
        }];
    }
}

- (void)setImageProcessor:(CVFImageProcessor *)imageProcessor
{
    if (_imageProcessor != imageProcessor) {
        _imageProcessor.delegate = nil;
        _imageProcessor = imageProcessor;
        _imageProcessor.delegate = self;
    }
}

- (CVFImageProcessor *)imageProcessor {
    return _imageProcessor;
}


- (void)viewDidUnload
{
    [self turnCameraOff];
    [self setImageView:nil];
    [self setFpsLabel:nil];
    [self setFlipCameraButton:nil];
    [self setDescriptionView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Flipside View Controller

- (void)flipsideViewControllerDidFinish:(CVFFlipsideViewController *)controller
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self dismissModalViewControllerAnimated:YES];
    } else {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.flipsidePopoverController = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            UIPopoverController *popoverController = [(UIStoryboardPopoverSegue *)segue popoverController];
            self.flipsidePopoverController = popoverController;
            popoverController.delegate = self;
        }
    }
}

#pragma mark - UIWebViewDelegate methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    if ([[url scheme] isEqual: @"about"]) {
        return YES;
    }
    if ([[url scheme] isEqual:@"file"]) {
        return YES;
    }

    [[UIApplication sharedApplication] openURL:url];
    return NO;
}

#pragma mark - IBAction methods

- (IBAction)flipAction:(id)sender
{
    _useBackCamera = !_useBackCamera;
    [[NSUserDefaults standardUserDefaults] setBool:_useBackCamera forKey:@"useBackCamera"];
    [self turnCameraOff];
    [self setupCamera];
    [self turnCameraOn];
}

- (IBAction)togglePopover:(id)sender
{
    if (self.flipsidePopoverController) {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    } else {
        [self performSegueWithIdentifier:@"showAlternate" sender:sender];
    }
}

- (IBAction)swipeUpAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"showDescription"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showDescription" object:nil];
}

- (IBAction)swipeDownAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"showDescription"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"showDescription" object:nil];
}

#pragma mark - CVFImageProcessorDelegate

-(void)imageProcessor:(CVFImageProcessor*)imageProcessor didCreateImage:(UIImage*)image
{
//    NSLog(@"Image Received");
    [self.imageView setImage:image];
    NSDate *now = [NSDate date];
    NSTimeInterval frameDelay = [now timeIntervalSinceDate:_lastFrameTime];
    double fps = 1.0/frameDelay;
    if (fps != fps) {
        self.fpsLabel.text = @"";
    } else {
        self.fpsLabel.text = [NSString stringWithFormat:@"%05.2f FPS", fps];
    }
    _lastFrameTime = now;
}

#pragma mark - Camera support

- (void)setupCamera {
    _cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSArray *devices = [AVCaptureDevice devices];
    if (devices.count == 1) {
        
    }
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront && !_useBackCamera) {
            
            _cameraDevice = device;
            break;
        }
        if (device.position == AVCaptureDevicePositionBack && _useBackCamera) {
            
            _cameraDevice = device;
            break;
        }
    }
}

- (void)turnCameraOn {
    NSError *error;
    _session = [[AVCaptureSession alloc] init];
    [_session beginConfiguration];
    [_session setSessionPreset:AVCaptureSessionPresetMedium];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:_cameraDevice
                                                                        error:&error];
    if (input == nil) {
        NSLog(@"%@", error);
    }
    
    [_session addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [_session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
    
    // Specify the pixel format
    output.videoSettings = 
    [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    output.alwaysDiscardsLateVideoFrames = YES;
    //kCVPixelFormatType_32BGRA
    
//    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
//    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
//    AVCaptureVideoOrientation orientation = AVCaptureVideoOrientationLandscapeRight;
//    [_previewLayer setOrientation:orientation];
//    _previewLayer.frame = self.previewView.bounds;
//    [self.previewView.layer addSublayer:_previewLayer];
    
    // Start the session running to start the flow of data
    [_session commitConfiguration];
    [_session startRunning];
}

- (void)turnCameraOff {
    [_previewLayer removeFromSuperlayer];
    _previewLayer = nil;
    [_session stopRunning];
    _session = nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        [self.imageProcessor processImageBuffer:imageBuffer
                                  withMirroring:(_cameraDevice.position ==
                                                 AVCaptureDevicePositionFront)];
    }
}

@end
