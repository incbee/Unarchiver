#import <Cocoa/Cocoa.h>

@class TUTaskView;

@interface TUTaskListView:NSView
{
	float totalheight;

	SEL resizeaction;
	id resizetarget;
}

-(id)initWithFrame:(NSRect)frame;
-(void)dealloc;

-(void)addTaskView:(TUTaskView *)taskview;
-(void)removeTaskView:(TUTaskView *)taskview;
-(BOOL)containsTaskView:(TUTaskView *)taskview;
-(void)setHeight:(float)height forView:(NSView *)view;
-(void)_layoutSubviews;

-(void)setResizeAction:(SEL)action target:(id)target;

-(NSSize)preferredSize;

@end

@interface TUTaskView:NSView
{
}

-(id)init;
-(TUTaskListView *)taskListView;

@end

@interface TUMultiTaskView:TUTaskView
{
}

-(id)init;
-(void)setDisplayedView:(NSView *)dispview;

@end
