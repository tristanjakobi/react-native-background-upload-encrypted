#import <Foundation/Foundation.h>

@interface EncryptedInputStream : NSInputStream <NSStreamDelegate>

- (instancetype)initWithInputStream:(NSInputStream *)stream
                                key:(NSData *)key
                              nonce:(NSData *)nonce;

@end
