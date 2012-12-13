#import <Cocoa/Cocoa.h>

@interface TUDockTileView : NSView
{
	double progress,lastupdate,lastwidth;
}

-(id)initWithFrame:(NSRect)frame;
-(void)dealloc;

-(void)setCount:(int)count;
-(void)setProgress:(double)fraction;
-(void)hideProgress;

-(void)drawRect:(NSRect)rect;

-(NSRect)progressBarOuterFrame;
-(NSRect)progressBarFrameForFraction:(double)fraction;

@end
