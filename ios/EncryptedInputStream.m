
#import "EncryptedInputStream.h"
#import <CommonCrypto/CommonCryptor.h>

@interface EncryptedInputStream () {
    CCCryptorRef _cryptor;
    NSInputStream *_sourceStream;
    NSMutableData *_readBuffer;
    uint8_t *_internalBuffer;
    NSUInteger _bufferPos;
    NSUInteger _bufferLen;
}

@end

@implementation EncryptedInputStream

- (instancetype)initWithInputStream:(NSInputStream *)stream key:(NSData *)key nonce:(NSData *)nonce {
    self = [super init];
    if (self) {
        _sourceStream = stream;
        _readBuffer = [NSMutableData dataWithLength:4096];
        _internalBuffer = malloc(4096);
        _bufferPos = 0;
        _bufferLen = 0;

        CCCryptorCreateWithMode(kCCEncrypt,
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

- (void)dealloc {
    if (_cryptor) {
        CCCryptorRelease(_cryptor);
    }
    if (_internalBuffer) {
        free(_internalBuffer);
    }
}

- (void)open {
    [_sourceStream open];
}

- (void)close {
    [_sourceStream close];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    if (_bufferPos >= _bufferLen) {
        NSInteger bytesRead = [_sourceStream read:_internalBuffer maxLength:4096];
        if (bytesRead <= 0) {
            return bytesRead;
        }

        size_t outMoved = 0;
        CCCryptorStatus status = CCCryptorUpdate(_cryptor,
                                                 _internalBuffer, bytesRead,
                                                 _readBuffer.mutableBytes, _readBuffer.length,
                                                 &outMoved);
        if (status != kCCSuccess) {
            return -1;
        }

        _bufferLen = outMoved;
        _bufferPos = 0;
    }

    NSUInteger available = _bufferLen - _bufferPos;
    NSUInteger toCopy = MIN(len, available);
    memcpy(buffer, _readBuffer.bytes + _bufferPos, toCopy);
    _bufferPos += toCopy;

    return toCopy;
}

- (BOOL)hasBytesAvailable {
    return YES;
}

@end
