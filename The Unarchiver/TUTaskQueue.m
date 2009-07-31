#import "TUTaskQueue.h"

@implementation TUTaskQueue

-(id)init
{
	if(self=[super init])
	{
		tasks=[NSMutableArray new];
		running=NO;
		stalled=NO;
	}
	return self;
}

-(void)dealloc
{
	[tasks release];
	[super dealloc];
}

-(id)taskWithTarget:(id)target
{
	return [[[TUTaskTrampoline alloc] initWithTarget:target queue:self] autorelease];
}

-(void)newTaskWithTarget:(id)target invocation:(NSInvocation *)invocation
{
	[invocation retainArguments];

	[tasks addObject:target];
	[tasks addObject:invocation];

	[self restart];
}

-(void)stallCurrentTask
{
	if(!running) return;

	stalled=YES;
	running=NO;
}

-(void)finishCurrentTask
{
	if(!running) return;

	[tasks removeObjectAtIndex:0];
	[tasks removeObjectAtIndex:0];
	running=NO;

	[self restart];
}

-(BOOL)isRunning
{
	return running;
}

-(BOOL)isStalled
{
	return stalled;
}

-(void)restart
{
	if(running) return;
	if(![tasks count]) return;

	running=YES;
	stalled=NO;

	[self performSelector:@selector(startTask) withObject:nil afterDelay:0];
}

-(void)startTask
{
	id target=[tasks objectAtIndex:0];
	NSInvocation *invocation=[tasks objectAtIndex:1];

	[invocation retain];
	[invocation invokeWithTarget:target];
	[invocation release];
}

@end


@implementation TUTaskTrampoline

-(id)initWithTarget:(id)target queue:(TUTaskQueue *)queue;
{
	actual=target;
	parent=queue;
	return self;
}

-(void)dealloc
{
	[super dealloc];
}


-(NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [actual methodSignatureForSelector:sel]; 
}

-(void)forwardInvocation:(NSInvocation *)invocation
{
	[parent newTaskWithTarget:actual invocation:invocation];
}

@end
