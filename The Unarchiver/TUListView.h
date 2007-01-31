#import <Cocoa/Cocoa.h>


@interface TUListView:NSView
{
	float totalheight;

	SEL resizeaction;
	id resizetarget;
}

-(void)dealloc;

-(void)addSubview:(NSView *)subview;
-(void)removeSubview:(NSView *)subview;
-(void)setHeight:(float)height forView:(NSView *)view;
-(void)_layoutSubviews;

-(void)setResizeAction:(SEL)action target:(id)target;

-(NSSize)preferredSize;

@end
