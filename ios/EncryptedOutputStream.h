#import <Foundation/Foundation.h>

@interface EncryptedOutputStream : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath
                             key:(NSData *)key
                           nonce:(NSData *)nonce;

- (BOOL)writeData:(NSData *)data error:(NSError **)error;

- (void)close;

@end
