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

-(void)drawRect:(NSRect)rect
{
	NSImage *icon=[NSApp applicationIconImage];
	NSSize size=[icon size];
	[icon drawInRect:[self bounds] fromRect:NSMakeRect(0,0,size.width,size.height)
	operation:NSCompositeCopy fraction:1];

	if(progress<0) return;

	NSRect backrect=[self bounds];
	backrect.origin.y+=16;
	backrect.size.height=16;

	NSBezierPath *backpath=[NSBezierPath bezierPathWithRoundedRect:backrect xRadius:7 yRadius:7];
	NSColor *background=[NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:0.66];
	[background setFill];
	[backpath fill];

	if(progress==0) return;

	NSRect progressrect=NSInsetRect(backrect,1,1);
	progressrect.size.width*=progress; // TODO: Better path generation for small values.

	NSBezierPath *progresspath=[NSBezierPath bezierPathWithRoundedRect:progressrect xRadius:7 yRadius:7];
	NSGradient *gradient=[[[NSGradient alloc] initWithColorsAndLocations:
		[NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:(CGFloat[4]){ 0.25,0.57,0.85,1 } count:4],(CGFloat)0,
		[NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:(CGFloat[4]){ 0.20,0.47,0.74,1 } count:4],(CGFloat)0.49,
		[NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:(CGFloat[4]){ 0.17,0.42,0.68,1 } count:4],(CGFloat)0.51,
		[NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:(CGFloat[4]){ 0.17,0.39,0.64,1 } count:4],(CGFloat)1,
	nil] autorelease];

	[gradient drawInBezierPath:progresspath angle:-90];
}

@end
