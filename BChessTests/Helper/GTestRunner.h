//
//  GTestRunner.h
//  BChessTests
//
//  Runs the GoogleTest cases one at a time so that Swift Testing can report each as its own case.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** One failed assertion of a GoogleTest case. */
NS_SWIFT_SENDABLE
@interface GTestFailure : NSObject

@property (nonatomic, readonly) NSString *file;
@property (nonatomic, readonly) NSInteger line;
@property (nonatomic, readonly) NSString *message;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFile:(NSString *)file line:(NSInteger)line message:(NSString *)message NS_DESIGNATED_INITIALIZER;

@end

@interface GTestRunner : NSObject

/** Every registered `Suite.Name` that is not disabled. Initializes GoogleTest on first use. */
+ (NSArray<NSString *> *)testNames;

/** Runs exactly the named case and returns its failures (empty when it passed). */
+ (NSArray<GTestFailure *> *)run:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
