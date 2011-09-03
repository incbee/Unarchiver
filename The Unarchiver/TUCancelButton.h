#import <Cocoa/Cocoa.h>


@interface TUCancelButton:NSButton
{
	NSImage *normal,*hover,*press;
	NSTrackingRectTag trackingtag;
}

-(id)initWithCoder:(NSCoder *)coder;
-(void)dealloc;

-(void)mouseEntered:(NSEvent *)event;
-(void)mouseExited:(NSEvent *)event;

@end
