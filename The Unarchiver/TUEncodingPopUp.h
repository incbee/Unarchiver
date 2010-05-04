#import <Cocoa/Cocoa.h>

@interface TUEncodingPopUp:NSPopUpButton
{
}

-(id)initWithFrame:(NSRect)frame;
-(id)initWithCoder:(NSCoder *)coder;

-(void)buildEncodingList;
-(void)buildEncodingListWithAutoDetect;
-(void)buildEncodingListMatchingData:(NSData *)data;

+(NSArray *)encodings;
+(float)maximumEncodingNameWidthWithAttributes:(NSDictionary *)attrs;

@end
