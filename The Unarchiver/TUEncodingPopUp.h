#import <Cocoa/Cocoa.h>

@interface TUEncodingPopUp:NSPopUpButton
{
}

-(id)initWithFrame:(NSRect)frame;
-(id)initWithCoder:(NSCoder *)coder;

-(void)buildEncodingList;
-(void)buildEncodingListWithAutoDetect;
-(void)buildEncodingListMatchingBytes:(const char *)bytes;

+(NSArray *)encodings;
+(NSString *)nameOfEncoding:(CFStringEncoding)encoding;

@end
