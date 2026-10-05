//
//  GTestRunner.mm
//  BChessTests
//
//  The enumeration, the DISABLED_ filtering and the filtered execution follow the former
//  GoogleTests.mm, which Matthew Stevens wrote (MIT, 2013). The XCTest classes and the
//  bundle-load notification are gone: the names are handed to Swift Testing instead.
//

#import "GTestRunner.h"

#import <gtest/gtest.h>

#import "UnitTestHelper.hpp"

using testing::TestPartResult;
using testing::UnitTest;

static NSString * const GoogleTestDisabledPrefix = @"DISABLED_";

@implementation GTestFailure

- (instancetype)initWithFile:(NSString *)file line:(NSInteger)line message:(NSString *)message {
    if (self = [super init]) {
        _file = [file copy];
        _line = line;
        _message = [message copy];
    }
    return self;
}

@end

/** Collects the failed parts of the test that is running. */
class FailureCollector : public testing::EmptyTestEventListener {
public:
    NSMutableArray<GTestFailure *> *failures = [NSMutableArray array];

    void OnTestPartResult(const TestPartResult& result) override {
        if (result.passed()) {
            return;
        }
        const char *fileName = result.file_name();
        [failures addObject:[[GTestFailure alloc] initWithFile:(fileName ? @(fileName) : @"")
                                                           line:result.line_number()
                                                        message:@(result.message())]];
    }
};

@implementation GTestRunner

+ (NSArray<NSString *> *)testNames {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UnitTestHelper::pathToResources = std::string([[NSBundle bundleForClass:self] resourcePath].UTF8String);

        // Pass the command-line arguments to GoogleTest to support the --gtest options.
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        int argc = (int)arguments.count;
        const char **argv = (const char **)calloc((size_t)argc + 1, sizeof(const char *));
        int i = 0;
        for (NSString *arg in arguments) {
            argv[i++] = arg.UTF8String;
        }
        testing::InitGoogleTest(&argc, (char **)argv);
        free(argv);

        UnitTest *googleTest = UnitTest::GetInstance();
        testing::TestEventListeners& listeners = googleTest->listeners();
        delete listeners.Release(listeners.default_result_printer());

        BOOL runDisabledTests = testing::GTEST_FLAG(also_run_disabled_tests);
        NSMutableArray<NSString *> *result = [NSMutableArray array];
        for (int caseIndex = 0; caseIndex < googleTest->total_test_case_count(); caseIndex++) {
            const testing::TestCase *testCase = googleTest->GetTestCase(caseIndex);
            NSString *caseName = @(testCase->name());
            // For typed tests '/' is used to separate the parts of the test case name.
            BOOL caseDisabled = NO;
            for (NSString *component in [caseName componentsSeparatedByString:@"/"]) {
                if ([component hasPrefix:GoogleTestDisabledPrefix]) {
                    caseDisabled = YES;
                }
            }
            if (!runDisabledTests && caseDisabled) {
                continue;
            }
            for (int testIndex = 0; testIndex < testCase->total_test_count(); testIndex++) {
                NSString *testName = @(testCase->GetTestInfo(testIndex)->name());
                if (!runDisabledTests && [testName hasPrefix:GoogleTestDisabledPrefix]) {
                    continue;
                }
                [result addObject:[NSString stringWithFormat:@"%@.%@", caseName, testName]];
            }
        }
        names = result;
    });
    return names;
}

+ (NSArray<GTestFailure *> *)run:(NSString *)name {
    (void)[self testNames];

    UnitTest *googleTest = UnitTest::GetInstance();
    FailureCollector *collector = new FailureCollector();
    googleTest->listeners().Append(collector);
    testing::GTEST_FLAG(filter) = name.UTF8String;
    (void)RUN_ALL_TESTS();
    NSMutableArray<GTestFailure *> *failures = collector->failures;
    delete googleTest->listeners().Release(collector);

    int totalTestsRun = googleTest->successful_test_count() + googleTest->failed_test_count();
    if (totalTestsRun != 1) {
        [failures addObject:[[GTestFailure alloc] initWithFile:@""
                                                           line:0
                                                        message:[NSString stringWithFormat:@"Expected to run a single test for filter \"%@\", ran %d", name, totalTestsRun]]];
    }
    return failures;
}

@end
