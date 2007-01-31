#import "TUListView.h"


@implementation TUListView

-(id)initWithFrame:(NSRect)frame
{
	if(self=[super initWithFrame:frame])
	{
		resizetarget=nil;
		totalheight=-1;
		[self setAutoresizesSubviews:YES];
	}
	return self;
}

-(void)dealloc
{
	[resizetarget release];
	[super dealloc];
}

-(void)addSubview:(NSView *)subview
{
	[subview setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];
	[super addSubview:subview];
	[self _layoutSubviews];
}

-(void)removeSubview:(NSView *)subview;
{
//	[self _markAsResizable:subview];
//	[self _calcTotalHeightExcluding:subview];
//	[self _notifySizeChange];
	[subview removeFromSuperview];
	[self _layoutSubviews];
}

/*-(void)willRemoveSubview:(NSView *)subview
{
	[super willRemoveSubview:subview];
	[self performSelector:@selector(_layoutSubviews) withObject:nil afterDelay:0];
}*/

-(void)setHeight:(float)height forView:(NSView *)view
{
	NSRect frame=[view frame];
	frame.size.height=height;
	[view setFrame:frame];
	[self _layoutSubviews];
}

-(void)_layoutSubviews
{
	NSEnumerator *enumerator;
	NSView *subview;

	float oldheight=totalheight;

	totalheight=0;
	enumerator=[[self subviews] reverseObjectEnumerator];
	while(subview=[enumerator nextObject]) totalheight+=[subview frame].size.height+1;
	if(totalheight) totalheight-=1;

	NSRect listframe=[self frame];
	float y=listframe.size.height-totalheight;

	enumerator=[[self subviews] reverseObjectEnumerator];
	while(subview=[enumerator nextObject])
	{
		NSRect frame=[subview frame];

		frame.origin.x=0;
		frame.origin.y=y;
		frame.size.width=listframe.size.width;

		[subview setFrame:frame];

		y+=frame.size.height+1;
	}

	if(oldheight!=totalheight)
	{
		if(resizetarget&&[resizetarget respondsToSelector:resizeaction])
		[resizetarget performSelector:resizeaction withObject:self];
	}

//	float newheight=y;
//	float newy=listframe.origin.y+newheight-listframe.size.height;
//	[self setFrame:NSMakeRect(listframe.origin.x,newy,listframe.size.width,newheight)];
//	[self setNeedsDisplay:YES];
}

-(void)drawRect:(NSRect)rect
{
	NSEnumerator *enumerator=[[self subviews] objectEnumerator];
	NSView *subview;
	BOOL isblue=NO;

	NSColor *whitecol=[NSColor whiteColor];
	NSColor *bluecol=[NSColor colorWithCalibratedRed:237.0/255.0 green:242.0/255.0 blue:1 alpha:1];

	while(subview=[enumerator nextObject])
	{
		NSRect frame=[subview frame];

		if(isblue) [bluecol set];
		else [whitecol set];
		isblue=!isblue;

		[NSBezierPath fillRect:frame];

		[[NSColor lightGrayColor] set];
		[NSBezierPath fillRect:NSMakeRect(frame.origin.x,frame.origin.y+frame.size.height,frame.size.width,1)];
	}
}

-(void)setResizeAction:(SEL)action target:(id)target
{
	resizeaction=action;
	[resizetarget autorelease];
	resizetarget=[target retain];
}

-(NSSize)preferredSize
{
	return NSMakeSize([self frame].size.width,totalheight);
}

@end
