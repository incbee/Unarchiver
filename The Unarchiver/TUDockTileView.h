#import <Cocoa/Cocoa.h>

@interface TUDockTileView : NSView
{
	double progress;
}

-(id)initWithFrame:(NSRect)frame;
-(void)dealloc;

-(void)setCount:(int)count;
-(void)setProgress:(double)fraction;
-(void)hideProgress;

-(void)drawRect:(NSRect)rect;

@end
