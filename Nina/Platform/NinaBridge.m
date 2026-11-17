#import <React/RCTEventEmitter.h>
#import <React/RCTViewManager.h>
#import "Nina-Swift.h"

@interface NinaDevice : RCTEventEmitter
@property(nonatomic, strong) NinaPlatform *platform;
@end

@implementation NinaDevice

RCT_EXPORT_MODULE(NinaDevice)

+ (BOOL)requiresMainQueueSetup { return NO; }

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"NinaWindowLayout", @"NinaFilmState", @"NinaPurchase", @"NinaAppleRevoked", @"NinaCallStopped"];
}

- (void)startObserving
{
  for (NSString *name in self.supportedEvents) {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observed:) name:name object:nil];
  }
}

- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observed:(NSNotification *)notification
{
  [self sendEventWithName:notification.name body:notification.userInfo ?: @{}];
}

RCT_EXPORT_METHOD(perform:(NSString *)operation
                  inputs:(NSDictionary *)inputs
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    if (!self.platform) {
      self.platform = [NinaPlatform new];
    }
    [self.platform perform:operation inputs:inputs completion:^(id value, NSError *error) {
      if (error) {
        reject(@"nina_platform", error.localizedDescription, error);
      } else {
        resolve(value);
      }
    }];
  });
}

@end

@interface NinaSurfaceManager : RCTViewManager
@end

@implementation NinaSurfaceManager

RCT_EXPORT_MODULE(NinaSurface)
RCT_EXPORT_VIEW_PROPERTY(kind, NSString)
RCT_EXPORT_VIEW_PROPERTY(enabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(page, NSString)
RCT_EXPORT_VIEW_PROPERTY(revision, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(onSignal, RCTDirectEventBlock)

- (UIView *)view
{
  return [NinaSurfaceView new];
}

@end

@interface NinaCommunityManager : RCTViewManager
@end

@implementation NinaCommunityManager

RCT_EXPORT_MODULE(NinaCommunity)
RCT_EXPORT_VIEW_PROPERTY(onSignal, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(reply, NSDictionary)

- (UIView *)view
{
  return [[NinaCommunityView alloc] initWithFrame:CGRectZero];
}

@end
