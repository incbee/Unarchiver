#import <Cocoa/Cocoa.h>
#import <XADMaster/XADString.h>

@interface TUEncodingPopUp:NSPopUpButton
{
}

-(id)initWithFrame:(NSRect)frame;
-(id)initWithCoder:(NSCoder *)coder;

-(void)buildEncodingList;
-(void)buildEncodingListWithAutoDetect;
-(void)buildEncodingListMatchingXADString:(id <XADString>)string;

+(NSArray *)encodings;
+(float)maximumEncodingNameWidthWithAttributes:(NSDictionary *)attrs;

@end
