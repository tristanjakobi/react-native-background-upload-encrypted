#import "EncryptedOutputStream.h"
#import <CommonCrypto/CommonCryptor.h>

@interface EncryptedOutputStream () {
    CCCryptorRef _cryptor;
    NSOutputStream *_outputStream;
}
@end

@implementation EncryptedOutputStream

- (instancetype)initWithFilePath:(NSString *)filePath
                             key:(NSData *)key
                           nonce:(NSData *)nonce {
    self = [super init];
    if (self) {
        _outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
        [_outputStream open];

        CCCryptorCreateWithMode(kCCDecrypt,
                                kCCModeCTR,
                                kCCAlgorithmAES,
                                ccNoPadding,
                                nonce.bytes,
                                key.bytes,
                                key.length,
                                NULL, 0, 0,
                                kCCModeOptionCTR_BE,
                                &_cryptor);
    }
    return self;
}

- (BOOL)writeData:(NSData *)data error:(NSError **)error {
    if (!_cryptor || !_outputStream) {
        if (error) {
            *error = [NSError errorWithDomain:@"EncryptedOutputStream"
                                         code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Missing cryptor or output stream" }];
        }
        return NO;
    }

    NSMutableData *outBuffer = [NSMutableData dataWithLength:data.length];
    size_t outMoved = 0;

    CCCryptorStatus status = CCCryptorUpdate(_cryptor,
                                             data.bytes,
                                             data.length,
                                             outBuffer.mutableBytes,
                                             outBuffer.length,
                                             &outMoved);

    if (status != kCCSuccess) {
        if (error) {
            *error = [NSError errorWithDomain:@"EncryptedOutputStream"
                                         code:status
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Decryption failed" }];
        }
        return NO;
    }

    NSInteger written = [_outputStream write:outBuffer.bytes maxLength:outMoved];
    if (written != outMoved) {
        if (error) {
            *error = [NSError errorWithDomain:@"EncryptedOutputStream"
                                         code:-2
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Failed to write decrypted data to output stream" }];
        }
        return NO;
    }
    
    return YES;
}

- (void)close {
    if (_cryptor) {
        CCCryptorRelease(_cryptor);
        _cryptor = NULL;
    }
    if (_outputStream) {
        [_outputStream close];
        _outputStream = nil;
    }
}

@end
