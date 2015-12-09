//
//  ContentViewController.m
//  Caneloni
//
//  Created by Antonio Marques on 11/03/15.
//  Copyright (c) 2015 Antonio Marques. All rights reserved.
//

#import "ContentViewController.h"

#import <AssetsLibrary/AssetsLibrary.h>

#include <asl.h>

@interface ContentViewController ()

@property (nonatomic) dispatch_queue_t processingQueue;
@property (nonatomic, strong) ALAssetsLibrary* library;
@property (nonatomic, strong) NSString* folder;
@property (nonatomic, strong) NSArray* unprocessed;
@property (nonatomic, assign) NSInteger currentIndex;

@property (nonatomic, assign) FILE* logStream;

@end

@implementation ContentViewController

- (void) dealloc
{
    _processingQueue = nil;
}

- (void) viewWillAppear:(BOOL)animated
{
    if (!self.processing) {
        [self updateForStoppedState];
        [self listUnprocessed];
    }
}

- (IBAction) didTapProcess:(id)sender
{
    self.vProcess.enabled = NO;
    if (self.processing) {
        self.stopWhenPossible = YES;
    }
    else {
        [self startProcessing];
    }
}

- (IBAction) didTapLog:(id)sender
{
}

- (void) startProcessing
{
    self.processing = YES;
    self.processingQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    self.stopWhenPossible = NO;
    self.library = [ALAssetsLibrary new];
    [self openLog];
    [self updateForRunningState];
    dispatch_async(self.processingQueue, ^{
        [self processNextItem];
    });
}

- (void) stopProcessing
{
    self.processing = NO;
    self.processingQueue = nil;
    self.library = nil;
    [self closeLog];
    [self listUnprocessed];
    [self updateForStoppedState];
}

- (void) updateForStoppedState
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.vProcess setTitle:@"Process" forState:UIControlStateNormal];
        self.vProcess.enabled = YES;
        self.vLog.enabled = YES;
        self.vProcessing.hidden = YES;
        [self.vProcessing stopAnimating];
        self.vCurrentFile.text = @"---";
        self.vCurrentFile.enabled = NO;
    });
}

- (void) updateForRunningState
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.vProcess setTitle:@"Stop" forState:UIControlStateNormal];
        self.vProcess.enabled = YES;
        self.vLog.enabled = NO;
        [self.vProcessing startAnimating];
        self.vProcessing.hidden = NO;
        self.vCurrentFile.enabled = YES;
        self.vLastFile.text = @"";
        self.vLocation.text = @"";
        self.vSaved.text = @"";
        self.vDeleted.text = @"";
    });
}

- (void) updateCurrentFile:(NSString*)currentFile saved:(BOOL)saved assetURL:(NSURL*)assetURL
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.vLastFile.text = currentFile;
        self.vLocation.text = assetURL.absoluteString;
        self.vSaved.text = saved ? @"YES" : @"NO";
        self.vSaved.textColor = saved ? [UIColor greenColor] : [UIColor redColor];
    });
}

- (void) updateDeleted:(BOOL)deleted
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.vDeleted.text = deleted ? @"YES" : @"NO";
        self.vDeleted.textColor = deleted ? [UIColor greenColor] : [UIColor redColor];
    });
}

- (void) updateUnprocessed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.vUnprocessed.text = [NSString stringWithFormat:@"%@ unprocessed file(s)", @(self.unprocessed.count - self.currentIndex)];
    });
}

- (void) listUnprocessed
{
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    self.folder = paths.firstObject;
    self.unprocessed = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.folder error:NULL];
    self.unprocessed = [self.unprocessed filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (NSString* evaluatedObject, NSDictionary* bindings) {
        return ![[evaluatedObject lowercaseString] hasSuffix:@".log"];
    }]];
    self.unprocessed = [self.unprocessed sortedArrayUsingComparator:^NSComparisonResult (NSString* obj1, NSString* obj2) {
        return [obj1 caseInsensitiveCompare:obj2];
    }];
    self.currentIndex = 0;
    [self updateUnprocessed];
}

- (void) processNextItem
{
    if (self.stopWhenPossible) {
        [self stopProcessing];
        return;
    }

    NSData* data;
    NSString* path;
    while (YES) {
        if (self.currentIndex >= self.unprocessed.count) {
            break;
        }
        path = [self.folder stringByAppendingPathComponent:self.unprocessed[self.currentIndex]];
        ++self.currentIndex;
        data = [NSData dataWithContentsOfFile:path];
        UIImage* image = [UIImage imageWithData:data];
        if (image.size.height) {
            break;
        }
        data = nil;
    }

    if (!data) {
        [self stopProcessing];
        return;
    }

    NSString* currentFile = [path lastPathComponent];
    self.vCurrentFile.text = currentFile;

    [self.library writeImageDataToSavedPhotosAlbum:data
                                          metadata:nil
                                   completionBlock:
     ^(NSURL* assetURL, NSError* saveError) {
         BOOL saved = assetURL && !saveError;

         if (saved) {
             [self logFile:currentFile savedToURL:assetURL];
         }

         [self updateCurrentFile:currentFile saved:saved assetURL:assetURL];

         if (!saved) {
             [self stopProcessing];
             return;
         }

         NSError* deleteError;
         BOOL deleted = [[NSFileManager defaultManager] removeItemAtPath:path error:&deleteError];
         if (!deleted) {
             [self stopProcessing];
             return;
         }

         [self updateDeleted:deleted];
         [self updateUnprocessed];

         [self processNextItem];
     }];
}

- (void) logFile:(NSString*)file savedToURL:(NSURL*)url
{
    [self log:[NSString stringWithFormat:@"<td>%@</td><td>%@</td>", file, url.absoluteString]];
}

- (void) log:(NSString*)line
{
    const char* string = [line UTF8String];
    asl_log(NULL, NULL, 6, "%s", string);
    fputs(string, self.logStream);
    fputs([@"\n" UTF8String], self.logStream);
    fflush(self.logStream);
}

- (void) openLog
{
    if (!self.logStream) {
        NSString* path = [self logPath];
        self.logStream = fopen([path UTF8String], "a+");
    }
}

- (void) closeLog
{
    if (self.logStream) {
        fclose(self.logStream);
        self.logStream = NULL;
    }
}

- (NSString*) logPath
{
    return [self.folder stringByAppendingPathComponent:@"processed.log"];
}

@end
