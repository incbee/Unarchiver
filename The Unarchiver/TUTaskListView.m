#import "TUTaskListView.h"


@implementation TUTaskListView

-(id)initWithFrame:(NSRect)frame
{
	if((self=[super initWithFrame:frame]))
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

-(void)addTaskView:(TUTaskView *)taskview
{
	[taskview setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];
	[self addSubview:taskview];
	[self _layoutSubviews];
}

-(void)removeTaskView:(TUTaskView *)taskview
{
//	[self _markAsResizable:subview];
//	[self _calcTotalHeightExcluding:subview];
//	[self _notifySizeChange];
	[taskview removeFromSuperview];
	[self _layoutSubviews];
}

-(BOOL)containsTaskView:(TUTaskView *)taskview
{
	return [[self subviews] indexOfObjectIdenticalTo:taskview]!=NSNotFound;
}

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
	while((subview=[enumerator nextObject])) totalheight+=[subview frame].size.height+1;
	if(totalheight) totalheight-=1;

	NSRect listframe=[self frame];
	float y=listframe.size.height-totalheight;

	enumerator=[[self subviews] reverseObjectEnumerator];
	while((subview=[enumerator nextObject]))
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

	while((subview=[enumerator nextObject]))
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



@implementation TUTaskView

-(id)init
{
	if((self=[super init]))
	{
	}
	return self;
}

-(TUTaskListView *)taskListView
{
	id superview=[self superview];
	if(!superview) return nil;
	if(![superview isKindOfClass:[TUTaskListView class]]) return nil;

	return superview;
}

@end



@implementation TUMultiTaskView

-(id)init
{
	if((self=[super init]))
	{
		[self setAutoresizesSubviews:YES];
	}
	return self;
}

-(void)setDisplayedView:(NSView *)dispview
{
	NSEnumerator *enumerator=[[self subviews] objectEnumerator];
	NSView *subview;
	while((subview=[enumerator nextObject])) [subview removeFromSuperview];

	NSSize viewsize=[dispview frame].size;
	NSSize selfsize=[self frame].size;

	if(!selfsize.height)
	{
		selfsize=viewsize;
		[self setFrame:NSMakeRect(0,0,selfsize.width,selfsize.height)];
	}

	[dispview setAutoresizingMask:NSViewWidthSizable|NSViewMaxYMargin];
	[dispview setFrame:NSMakeRect(0,0,selfsize.width,viewsize.height)];
	[self addSubview:dispview];

	[[self taskListView] setHeight:viewsize.height forView:self];
}

@end
