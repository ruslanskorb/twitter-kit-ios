/*
 * Copyright (C) 2017 Twitter, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */
//
//  Legacy wrapper around the SLComposeViewController.
//
//  In Twitter Kit 3.0 this interface was preserved, but the
//  internals were changed to use the shared composer code.
//

#import "TWTRComposer.h"
#import <TwitterCore/TWTRConstants.h>
#import "TWTRComposerViewController.h"
#import "TWTRTwitter.h"

@implementation TWTRComposerResult

- (instancetype)init NS_UNAVAILABLE
{
    assert(0);
}

- (instancetype)initWithError:(NSError *)error isCancelled:(BOOL)isCancelled tweet:(TWTRTweet *)tweet
{
    if ((self = [super init])) {
        _error = error;
        _isCancelled = isCancelled;
        _tweet = tweet;
    }
    return self;
}

@end

@interface TWTRComposer () <TWTRComposerViewControllerDelegate>

@property (nonatomic) UIImage *initialImage;
@property (nonatomic, copy) NSString *initialText;
@property (nonatomic, copy) NSURL *initialURL;
@property (nonatomic, copy) TWTRComposerCompletion completion;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation TWTRComposer
#pragma clang diagnostic pop

static dispatch_once_t onceToken;
+ (TWTRComposer *)sharedInstance
{
    // This shared instance only exists to keep this class from
    // being deallocated once the child TWTRComposerViewController
    // is presented.
    static TWTRComposer *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
    });

    // These should be reset each time this class is used
    sharedInstance.initialImage = nil;
    sharedInstance.initialText = nil;
    sharedInstance.initialURL = nil;

    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)ignore
{
    return [self sharedInstance];
}

- (BOOL)setText:(NSString *)text
{
    self.initialText = [text copy];
    return YES;
}

- (BOOL)setImage:(UIImage *)image
{
    self.initialImage = image;
    return YES;
}

- (BOOL)setURL:(NSURL *)url
{
    self.initialURL = [url copy];
    return YES;
}

- (void)showFromViewController:(UIViewController *)fromController completion:(nullable TWTRComposerCompletion)completion
{
    self.completion = [completion copy];

    if ([[TWTRTwitter sharedInstance].sessionStore hasLoggedInUsers]) {
        [self presentFromViewController:fromController];
    } else {
        [[TWTRTwitter sharedInstance] logInWithCompletion:^(TWTRSession *session, NSError *error) {
            if (session) {
                [self presentFromViewController:fromController];
            } else {
                if (error == nil) {
                    
                    NSLog(@"[TwitterKit] No users for composer.");
                    error = [NSError errorWithDomain:TWTRErrorDomain
                                                code:TWTRErrorCodeNoAuthentication
                                            userInfo:@{ NSLocalizedDescriptionKey: @"Error: No users for composer." }];
                }
                if (self.completion) {
                    TWTRComposerResult *result = [[TWTRComposerResult alloc] initWithError:error isCancelled:NO tweet:nil];
                    self.completion(result);
                }
            }
        }];
    }
}

#pragma mark - Internal

- (void)presentFromViewController:(UIViewController *)controller
{
    TWTRComposerViewController *composer = [[TWTRComposerViewController alloc] initWithInitialText:[self textForComposer] image:self.initialImage videoURL:nil];
    composer.delegate = self;

    [controller presentViewController:composer animated:YES completion:nil];
}

// Chose text based on which properties are set
- (NSString *)textForComposer
{
    NSString *text;
    if (self.initialText && self.initialURL) {
        text = [NSString stringWithFormat:@"%@ %@", self.initialText, self.initialURL.absoluteString];
    } else if (self.initialURL) {
        text = self.initialURL.absoluteString;
    } else {
        text = self.initialText;
    }

    return text;
}

#pragma mark - TWTRComposerViewControllerDelegate Protocol Methods

- (void)composerDidCancel:(TWTRComposerViewController *)controller
{
    if (self.completion) {
        TWTRComposerResult *result = [[TWTRComposerResult alloc] initWithError:nil isCancelled:YES tweet:nil];
        self.completion(result);
    }
}

- (void)composerDidSucceed:(TWTRComposerViewController *)controller withTweet:(TWTRTweet *)tweet
{
    if (self.completion) {
        TWTRComposerResult *result = [[TWTRComposerResult alloc] initWithError:nil isCancelled:NO tweet:tweet];
        self.completion(result);
    }
}

- (void)composerDidFail:(TWTRComposerViewController *)controller withError:(NSError *)error
{
    if (self.completion) {
        NSLog(@"[TwitterKit] Composer did fail: %@", error);
        TWTRComposerResult *result = [[TWTRComposerResult alloc] initWithError:error isCancelled:NO tweet:nil];
        self.completion(result);
    }
}

@end
