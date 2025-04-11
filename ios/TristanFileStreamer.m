#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>
#import <Photos/Photos.h>
#import "EncryptedInputStream.h"
#import "EncryptedOutputStream.h"
#import "TristanFileStreamer.h"
#import <React/RCTLog.h>
#import <React/RCTUtils.h>

@interface TristanFileStreamer () <RCTBridgeModule, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@end

@implementation TristanFileStreamer

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;
static int uploadId = 0;
static RCTEventEmitter* staticEventEmitter = nil;
static NSString *BACKGROUND_SESSION_ID = @"ReactNativeBackgroundUpload";
NSURLSession *_urlSession = nil;

+ (BOOL)requiresMainQueueSetup {
    return NO;
}

-(id) init {
  self = [super init];
  if (self) {
    staticEventEmitter = self;
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"com.tristan.filestreamer"];
    config.sessionSendsLaunchEvents = YES;
    config.discretionary = NO;
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.uploadTasks = [NSMutableDictionary dictionary];
    self.downloadTasks = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)_sendEventWithName:(NSString *)eventName body:(id)body {
  if (staticEventEmitter == nil)
    return;
  [staticEventEmitter sendEventWithName:eventName body:body];
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"TristanFileStreamer-progress",
        @"TristanFileStreamer-error",
        @"TristanFileStreamer-cancelled",
        @"TristanFileStreamer-completed"
    ];
}

/*
 Gets file information for the path specified.  Example valid path is: file:///var/mobile/Containers/Data/Application/3C8A0EFB-A316-45C0-A30A-761BF8CCF2F8/tmp/trim.A5F76017-14E9-4890-907E-36A045AF9436.MOV
 Returns an object such as: {mimeType: "video/quicktime", size: 2569900, exists: true, name: "trim.AF9A9225-FC37-416B-A25B-4EDB8275A625.MOV", extension: "MOV"}
 */
RCT_EXPORT_METHOD(getFileInfo:(NSString *)path resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
    @try {
        // Escape non latin characters in filename
        NSString *escapedPath = [path stringByAddingPercentEncodingWithAllowedCharacters: NSCharacterSet.URLQueryAllowedCharacterSet];
       
        NSURL *fileUri = [NSURL URLWithString:escapedPath];
        NSString *pathWithoutProtocol = [fileUri path];
        NSString *name = [fileUri lastPathComponent];
        NSString *extension = [name pathExtension];
        bool exists = [[NSFileManager defaultManager] fileExistsAtPath:pathWithoutProtocol];
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys: name, @"name", nil];
        [params setObject:extension forKey:@"extension"];
        [params setObject:[NSNumber numberWithBool:exists] forKey:@"exists"];

        if (exists)
        {
            [params setObject:[self guessMIMETypeFromFileName:name] forKey:@"mimeType"];
            NSError* error;
            NSDictionary<NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:pathWithoutProtocol error:&error];
            if (error == nil)
            {
                unsigned long long fileSize = [attributes fileSize];
                [params setObject:[NSNumber numberWithLong:fileSize] forKey:@"size"];
            }
        }
        resolve(params);
    }
    @catch (NSException *exception) {
        reject(@"RN Uploader", exception.name, nil);
    }
}

/*
 Borrowed from http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database
*/
- (NSString *)guessMIMETypeFromFileName: (NSString *)fileName {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[fileName pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    
    if (UTI) {
        CFRelease(UTI);
    }
  
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType);
}

/*
 Utility method to copy a PHAsset file into a local temp file, which can then be uploaded.
 */
- (void)copyAssetToFile: (NSString *)assetUrl completionHandler: (void(^)(NSString *__nullable tempFileUrl, NSError *__nullable error))completionHandler {
    NSURL *url = [NSURL URLWithString:assetUrl];
    PHAsset *asset = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil].lastObject;
    if (!asset) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"Asset could not be fetched.  Are you missing permissions?" forKey:NSLocalizedDescriptionKey];
        completionHandler(nil,  [NSError errorWithDomain:@"RNUploader" code:5 userInfo:details]);
        return;
    }
    PHAssetResource *assetResource = [[PHAssetResource assetResourcesForAsset:asset] firstObject];
    NSString *pathToWrite = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSURL *pathUrl = [NSURL fileURLWithPath:pathToWrite];
    NSString *fileURI = pathUrl.absoluteString;

    PHAssetResourceRequestOptions *options = [PHAssetResourceRequestOptions new];
    options.networkAccessAllowed = YES;

    [[PHAssetResourceManager defaultManager] writeDataForAssetResource:assetResource toFile:pathUrl options:options completionHandler:^(NSError * _Nullable e) {
        if (e == nil) {
            completionHandler(fileURI, nil);
        }
        else {
            completionHandler(nil, e);
        }
    }];
}

/*
 * Starts a file upload.
 * Options are passed in as the first argument as a js hash:
 * {
 *   url: string.  url to post to.
 *   path: string.  path to the file on the device
 *   headers: hash of name/value header pairs
 * }
 *
 * Returns a promise with the string ID of the upload.
 */
RCT_EXPORT_METHOD(startUpload:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    int thisUploadId;
    @synchronized(self.class)
    {
        thisUploadId = uploadId++;
    }

    NSString *uploadUrl = options[@"url"];
    __block NSString *fileURI = options[@"path"];
    NSString *method = options[@"method"] ?: @"POST";
    NSString *customTransferId = options[@"customTransferId"];
    NSString *appGroup = options[@"appGroup"];
    NSDictionary *headers = options[@"headers"];

    NSDictionary *encryption = options[@"encryption"];
    NSString *base64Key = encryption[@"key"];
    NSString *base64Nonce = encryption[@"nonce"];

    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
    NSData *nonceData = [[NSData alloc] initWithBase64EncodedString:base64Nonce options:0];

    @try {
        NSURL *requestUrl = [NSURL URLWithString: uploadUrl];
        if (requestUrl == nil) {
            return reject(@"RN Uploader", @"URL not compliant with RFC 2396", nil);
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestUrl];
        [request setHTTPMethod: method];

        [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull val, BOOL * _Nonnull stop) {
            if ([val respondsToSelector:@selector(stringValue)]) {
                val = [val stringValue];
            }
            if ([val isKindOfClass:[NSString class]]) {
                [request setValue:val forHTTPHeaderField:key];
            }
        }];

        // asset library files have to be copied over to a temp file.  they can't be uploaded directly
        if ([fileURI hasPrefix:@"assets-library"]) {
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            [self copyAssetToFile:fileURI completionHandler:^(NSString * _Nullable tempFileUrl, NSError * _Nullable error) {
                if (error) {
                    dispatch_group_leave(group);
                    reject(@"RN Uploader", @"Asset could not be copied to temp file.", nil);
                    return;
                }
                fileURI = tempFileUrl;
                dispatch_group_leave(group);
            }];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }

        NSInputStream *encryptedStream = [self encryptedInputStreamFromFile:fileURI key:keyData nonce:nonceData];
        [request setHTTPBodyStream:encryptedStream];

        NSURLSessionDataTask *uploadTask = [[self urlSession:appGroup] uploadTaskWithStreamedRequest:request];
        uploadTask.taskDescription = customTransferId ? customTransferId : [NSString stringWithFormat:@"%i", thisUploadId];

        [uploadTask resume];
        resolve(uploadTask.taskDescription);
    }
    @catch (NSException *exception) {
        reject(@"RN Uploader", exception.name, nil);
    }
}

/*
 * Cancels file upload
 * Accepts upload ID as a first argument, this upload will be cancelled
 * Event "cancelled" will be fired when upload is cancelled.
 */
RCT_EXPORT_METHOD(cancelUpload:(NSString *)uploadId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    NSURLSessionUploadTask *task = self.uploadTasks[uploadId];
    if (task) {
        [task cancel];
        [self.uploadTasks removeObjectForKey:uploadId];
        resolve(@YES);
    } else {
        reject(@"E_INVALID_ARGUMENT", @"Invalid upload ID", nil);
    }
}

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                         path:(NSString *)path
                         parameters:(NSDictionary *)parameters
                         fieldName:(NSString *)fieldName {

    NSMutableData *httpBody = [NSMutableData data];

    // Escape non latin characters in filename
    NSString *escapedPath = [path stringByAddingPercentEncodingWithAllowedCharacters: NSCharacterSet.URLQueryAllowedCharacterSet];

    // resolve path
    NSURL *fileUri = [NSURL URLWithString: escapedPath];
    
    NSError* error = nil;
    NSData *data = [NSData dataWithContentsOfURL:fileUri options:NSDataReadingMappedAlways error: &error];

    if (data == nil) {
        NSLog(@"Failed to read file %@", error);
    }

    NSString *filename  = [path lastPathComponent];
    NSString *mimetype  = [self guessMIMETypeFromFileName:path];

    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *parameterKey, NSString *parameterValue, BOOL *stop) {
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"%@\r\n", parameterValue] dataUsingEncoding:NSUTF8StringEncoding]];
    }];

    [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fieldName, filename] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBody appendData:data];
    [httpBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];

    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    return httpBody;
}

- (NSURLSession *)urlSession: (NSString *) groupId {
    if (_urlSession == nil) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:BACKGROUND_SESSION_ID];
        if (groupId != nil && ![groupId isEqualToString:@""]) {
            sessionConfiguration.sharedContainerIdentifier = groupId;
        }
        _urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
    }

    return _urlSession;
}

#pragma NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    NSMutableDictionary *data = [NSMutableDictionary dictionaryWithObjectsAndKeys:task.taskDescription, @"id", nil];
    NSURLSessionDataTask *uploadTask = (NSURLSessionDataTask *)task;
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)uploadTask.response;
    if (response != nil)
    {
        [data setObject:[NSNumber numberWithInteger:response.statusCode] forKey:@"responseCode"];
    }
    //Add data that was collected earlier by the didReceiveData method
    NSMutableData *responseData = self.responsesData[@(task.taskIdentifier)];
    if (responseData) {
        [self.responsesData removeObjectForKey:@(task.taskIdentifier)];
        NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        [data setObject:response forKey:@"responseBody"];
    } else {
        [data setObject:[NSNull null] forKey:@"responseBody"];
    }

    if (error == nil)
    {
        [self _sendEventWithName:@"TristanFileStreamer-completed" body:data];
    }
    else
    {
        [data setObject:error.localizedDescription forKey:@"error"];
        if (error.code == NSURLErrorCancelled) {
            [self _sendEventWithName:@"TristanFileStreamer-cancelled" body:data];
        } else {
            [self _sendEventWithName:@"TristanFileStreamer-error" body:data];
        }
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    float progress = -1;
    if (totalBytesExpectedToSend > 0) //see documentation.  For unknown size it's -1 (NSURLSessionTransferSizeUnknown)
    {
        progress = 100.0 * (float)totalBytesSent / (float)totalBytesExpectedToSend;
    }
    [self _sendEventWithName:@"TristanFileStreamer-progress" body:@{ @"id": task.taskDescription, @"progress": [NSNumber numberWithFloat:progress] }];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!data.length) {
        return;
    }
    //Hold returned data so it can be picked up by the didCompleteWithError method later
    NSMutableData *responseData = self.responsesData[@(dataTask.taskIdentifier)];
    if (!responseData) {
        responseData = [NSMutableData dataWithData:data];
        self.responsesData[@(dataTask.taskIdentifier)] = responseData;
    } else {
        [responseData appendData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler {

    NSInputStream *inputStream = task.originalRequest.HTTPBodyStream;

    if (completionHandler) {
        completionHandler(inputStream);
    }
}


- (NSInputStream *)encryptedInputStreamFromFile:(NSString *)fileURI key:(NSData *)key nonce:(NSData *)nonce {
    NSURL *fileURL = [NSURL URLWithString:fileURI];
    NSInputStream *inputStream = [NSInputStream inputStreamWithURL:fileURL];
    return [[EncryptedInputStream alloc] initWithInputStream:inputStream key:key nonce:nonce];
}

RCT_EXPORT_METHOD(downloadAndDecrypt:(NSDictionary *)options
                  resolve:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    NSLog(@"[downloadAndDecrypt] Starting download with options: %@", options);
    
    NSString *urlStr = options[@"url"];
    NSString *destination = options[@"destination"];
    NSDictionary *encryption = options[@"encryption"];
    NSString *base64Key = encryption[@"key"];
    NSString *base64Nonce = encryption[@"nonce"];
    NSDictionary *headers = options[@"headers"];

    if (!urlStr || !destination || !base64Key || !base64Nonce) {
        NSLog(@"[downloadAndDecrypt] Missing required parameters");
        reject(@"invalid_args", @"Missing required parameters", nil);
        return;
    }

    NSData *keyData = [[NSData alloc] initWithBase64EncodedString:base64Key options:0];
    NSData *nonceData = [[NSData alloc] initWithBase64EncodedString:base64Nonce options:0];
    NSURL *url = [NSURL URLWithString:urlStr];
    
    NSLog(@"[downloadAndDecrypt] Starting download from URL: %@", urlStr);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    // Add headers if provided
    if (headers) {
        [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull val, BOOL * _Nonnull stop) {
            if ([val respondsToSelector:@selector(stringValue)]) {
                val = [val stringValue];
            }
            if ([val isKindOfClass:[NSString class]]) {
                [request setValue:val forHTTPHeaderField:key];
            }
        }];
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
      dataTaskWithRequest:request
      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        if (error) {
            NSLog(@"[downloadAndDecrypt] Download failed with error: %@", error);
            reject(@"download_failed", error.localizedDescription, error);
            return;
        }
        
        NSLog(@"[downloadAndDecrypt] Download completed successfully. Data size: %lu bytes", (unsigned long)data.length);

        // Clean the destination path by removing file:// prefix if present
        NSString *cleanedPath = [destination stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        NSLog(@"[downloadAndDecrypt] Writing to cleaned path: %@", cleanedPath);

        EncryptedOutputStream *stream = [[EncryptedOutputStream alloc] initWithFilePath:cleanedPath
                                                                                     key:keyData
                                                                                   nonce:nonceData];
        
        NSLog(@"[downloadAndDecrypt] Starting decryption to path: %@", cleanedPath);

        NSError *writeErr = nil;
        BOOL ok = [stream writeData:data error:&writeErr];
        [stream close];

        if (!ok) {
            NSLog(@"[downloadAndDecrypt] Decryption failed with error: %@", writeErr);
            reject(@"decryption_failed", writeErr.localizedDescription, writeErr);
        } else {
            NSLog(@"[downloadAndDecrypt] Decryption completed successfully");
            resolve(@{ @"path": destination });
        }
    }];

    [task resume];
}

RCT_EXPORT_METHOD(startDownload:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    NSString *url = options[@"url"];
    NSString *path = options[@"path"];
    NSString *method = options[@"method"] ?: @"GET";
    NSString *customTransferId = options[@"customTransferId"];
    NSString *appGroup = options[@"appGroup"];
    NSDictionary *headers = options[@"headers"];
    
    if (!url || !path) {
        reject(@"E_INVALID_ARGUMENT", @"URL and path are required", nil);
        return;
    }
    
    NSURL *fileURL = [NSURL URLWithString:path];
    NSURL *downloadURL = [NSURL URLWithString:url];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL];
    [request setHTTPMethod:method];
    
    if (headers) {
        [headers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if ([value respondsToSelector:@selector(stringValue)]) {
                value = [value stringValue];
            }
            if ([value isKindOfClass:[NSString class]]) {
                [request setValue:value forHTTPHeaderField:key];
            }
        }];
    }
    
    NSURLSessionDownloadTask *task = [[self urlSession:appGroup] downloadTaskWithRequest:request];
    NSString *taskId = customTransferId ? customTransferId : [[NSUUID UUID] UUIDString];
    task.taskDescription = taskId;
    self.downloadTasks[taskId] = task;
    
    [task resume];
    resolve(taskId);
}

RCT_EXPORT_METHOD(cancelDownload:(NSString *)downloadId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  NSURLSessionDownloadTask *task = self.downloadTasks[downloadId];
  if (task) {
    [task cancel];
    [self.downloadTasks removeObjectForKey:downloadId];
    resolve(@YES);
  } else {
    reject(@"E_INVALID_ARGUMENT", @"Invalid download ID", nil);
  }
}

@end