//
//  NIMTransformFormatter.m
//  TransformTest
//
//  Created by Jonathan Wight on 3/6/14.
//  Copyright (c) 2014 schwa. All rights reserved.
//

#import "NIMTransformFormatter.h"

#import <QuartzCore/QuartzCore.h>

static NSCache *gCache = NULL;

@interface NIMTransformFormatter ()
@property (readwrite, nonatomic, copy) NSString *format;
@property (readwrite, nonatomic, copy) NSString *formattedString;
@end

@implementation NIMTransformFormatter

+ (void)initialize
    {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gCache = [[NSCache alloc] init];
        });
    }

//+ (instancetype)formatterWithFormat:(NSString *)inFormat;
//    {
//    return([(NIMTransformFormatter *)[self alloc] initWithFormat:inFormat]);
//    }

- (instancetype)initWithFormat:(NSString *)inFormat, ...
    {
    va_list argList;
    va_start(argList, inFormat);
    self = [self initWithFormat:inFormat arguments:argList];
    va_end(argList);
    return self;
    }

- (instancetype)initWithFormat:(NSString *)inFormat arguments:(va_list)argList
    {
    if ((self = [super init]) != NULL)
        {
        _format = inFormat;
        _formattedString = [[NSString alloc] initWithFormat:_format arguments:argList];
        }
    return self;
    }

- (CATransform3D)CATransform3D
    {
    NSValue *theValue = [gCache objectForKey:self.format];
    if (theValue != NULL)
        {
        return([theValue CATransform3DValue]);
        }

    CATransform3D theTransform;
    NSError *theError = NULL;
    if ([self _transform:&theTransform error:&theError] == NO)
        {
        NSLog(@"%@", theError);
        }

    if ([self.format isEqualToString:self.formattedString] == YES)
        {
        [gCache setObject:[NSValue valueWithCATransform3D:theTransform] forKey:self.format];
        }

    return(theTransform);
    }

- (NSValue *)CATransform3DValue
    {
    return([NSValue valueWithCATransform3D:[self CATransform3D]]);
    }

- (BOOL)_transform:(CATransform3D *)outTransform error:(NSError **)outError
    {
    CATransform3D theTransform = CATransform3DIdentity;

    NSScanner *theScanner = [NSScanner scannerWithString:self.formattedString];

    while ([theScanner isAtEnd] == NO)
        {
        NSDictionary *theFunction = NULL;

        if ([theScanner scanString:@"identity" intoString:NULL])
            {
            theTransform = CATransform3DIdentity;
            }

        if ([self scanner:theScanner scanFunction:&theFunction] == YES)
            {
            NSString *theName = [theFunction[@"name"] lowercaseString];
            if ([theName isEqualToString:@"translate"])
                {
                NSArray *theParameters = theFunction[@"parameters"];
                theTransform = CATransform3DTranslate(theTransform,
                    theParameters.count >= 1 ? [theParameters[0] doubleValue] : 0.0,
                    theParameters.count >= 2 ? [theParameters[1] doubleValue] : 0.0,
                    theParameters.count >= 3 ? [theParameters[2] doubleValue] : 0.0
                    );
                }
            else if ([theName isEqualToString:@"scale"])
                {
                NSArray *theParameters = theFunction[@"parameters"];
                theTransform = CATransform3DScale(theTransform,
                    theParameters.count >= 1 ? [theParameters[0] doubleValue] : 1.0,
                    theParameters.count >= 2 ? [theParameters[1] doubleValue] : 1.0,
                    theParameters.count >= 3 ? [theParameters[2] doubleValue] : 1.0
                    );
                }
            else if ([theName isEqualToString:@"rotate"])
                {
                NSArray *theParameters = theFunction[@"parameters"];
                theTransform = CATransform3DRotate(theTransform,
                    [theParameters[0] doubleValue],
                    [theParameters[1] doubleValue],
                    [theParameters[2] doubleValue],
                    [theParameters[3] doubleValue]
                    );
                }
            else
                {
                if (outError)
                    {
                    *outError = [NSError errorWithDomain:@"TODO" code:-1 userInfo:NULL];
                    }
                return(NO);
                }
            }
        else if ([theScanner scanString:@"|" intoString:NULL] == NO)
            {
            break;
            }
        }

    if (outTransform)
        {
        *outTransform = theTransform;
        }

    return(YES);
    }

- (BOOL)scanner:(NSScanner *)inScanner scanFunction:(NSDictionary **)outFunction
    {
    NSUInteger theSavedLocation = inScanner.scanLocation;

    NSString *theName = NULL;
    if ([inScanner scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&theName] == NO)
        {
        inScanner.scanLocation = theSavedLocation;
        return(NO);
        }

    if ([inScanner scanString:@"(" intoString:NULL] == NO)
        {
        inScanner.scanLocation = theSavedLocation;
        return(NO);
        }

    NSArray *theArray = NULL;
    if ([self scanner:inScanner scanArrayOfNumbers:&theArray] == NO)
        {
        inScanner.scanLocation = theSavedLocation;
        return(NO);
        }

    if ([inScanner scanString:@")" intoString:NULL] == NO)
        {
        inScanner.scanLocation = theSavedLocation;
        return(NO);
        }

    if (outFunction != NULL)
        {
        *outFunction = @{ @"name": theName, @"parameters": theArray };
        }

    return(YES);
    }

- (BOOL)scanner:(NSScanner *)inScanner scanArrayOfNumbers:(NSArray **)outNumbers
    {
    BOOL theResult = NO;

    NSMutableArray *theArray = [NSMutableArray array];

    NSUInteger theSavedLocation = inScanner.scanLocation;

    while (inScanner.isAtEnd == NO)
        {
        double theDouble;
        if ([inScanner scanDouble:&theDouble] == NO)
            {
            break;
            }

        [theArray addObject:@(theDouble)];

        if ([inScanner scanString:@"," intoString:NULL] == NO)
            {
            theResult = YES;
            break;
            }
        }

    if (theResult == NO)
        {
        inScanner.scanLocation = theSavedLocation;
        }

    if (theResult == YES && outNumbers != NULL)
        {
        *outNumbers = theArray;
        }

    return(theResult);
    }

@end

CATransform3D CATransform3DWithStringFormat(NSString *inFormat, ...)
    {
    va_list argList;
    va_start(argList, inFormat);
    NIMTransformFormatter *theFormatter = [[NIMTransformFormatter alloc] initWithFormat:inFormat arguments:argList];
    va_end(argList);
    return([theFormatter CATransform3D]);
    }

NSValue *CATransform3DValueWithStringFormat(NSString *inFormat, ...)
    {
    va_list argList;
    va_start(argList, inFormat);
    NIMTransformFormatter *theFormatter = [[NIMTransformFormatter alloc] initWithFormat:inFormat arguments:argList];
    va_end(argList);
    return([theFormatter CATransform3DValue]);
    }

