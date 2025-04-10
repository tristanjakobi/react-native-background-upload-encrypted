
#import <Foundation/Foundation.h>

@interface EncryptedInputStream : NSInputStream

- (instancetype)initWithInputStream:(NSInputStream *)stream
                                key:(NSData *)key
                              nonce:(NSData *)nonce;

@end
