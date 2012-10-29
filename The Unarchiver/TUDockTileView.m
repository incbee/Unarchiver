#import "TUDockTileView.h"

@implementation TUDockTileView

-(id)initWithFrame:(NSRect)frame
{
	if((self=[super initWithFrame:frame]))
	{
		progress=-1;
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(void)setCount:(int)count
{
	NSDockTile *dock=[NSApp dockTile];

	[[NSApp dockTile] display];
	if(count)
	{
		[dock setBadgeLabel:[NSString stringWithFormat:@"%d",count]];
	}
	else
	{
		[dock setBadgeLabel:nil];
	}
}

-(void)setProgress:(double)fraction
{
	if(fraction<0) progress=0;
	else if(fraction>1) progress=1;
	else progress=fraction;

	[[NSApp dockTile] display];
}

-(void)hideProgress
{
	progress=-1;
	[[NSApp dockTile] display];
}

#define RADIUS 10

-(void)drawRect:(NSRect)rect
{
	NSImage *icon=[NSApp applicationIconImage];
	NSSize size=[icon size];
	[icon drawInRect:[self bounds] fromRect:NSMakeRect(0,0,size.width,size.height)
	operation:NSCompositeCopy fraction:1];

	if(progress<0) return;

	NSRect backrect=[self bounds];
	backrect.origin.y+=15;
	backrect.size.height=20;

	NSRect progressrect=backrect;
	progressrect.size.width*=(progress*0.8)+0.2;

	NSBezierPath *backpath=[NSBezierPath bezierPathWithRoundedRect:backrect xRadius:RADIUS yRadius:RADIUS];
	NSBezierPath *progresspath=[NSBezierPath bezierPathWithRoundedRect:progressrect xRadius:RADIUS yRadius:RADIUS];
	
	[[NSColor blackColor] setFill];
	[backpath fill];

	[[NSColor whiteColor] setFill];
    [progresspath fill];
}

@end
