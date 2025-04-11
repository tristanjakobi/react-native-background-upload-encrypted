#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

@interface TristanFileStreamer : RCTEventEmitter <RCTBridgeModule>

@property (nonatomic, strong) NSMutableDictionary *responsesData;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary *uploadTasks;
@property (nonatomic, strong) NSMutableDictionary *downloadTasks;

@end 