#import "TUCancelExtractionScriptCommand.h"

enum taskSelection {
	taskSelectionAll = 'TaAl'
	};

@implementation TUCancelExtractionScriptCommand

-(id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef
{
	self=[super initWithCommandDescription:commandDef];
	if (self) {
		appController=[[NSApplication sharedApplication] delegate];
	}
	return self;
}

-(id)performDefaultImplementation
{
	id tasks=[self directParameter];
	switch ([tasks unsignedLongValue]) {
		case taskSelectionAll:
			[self cancellAllExtractions];
			break;
		default:
			[self setScriptErrorNumber:1];
			[self setScriptErrorString:@"Not implemented"];
			break;
	}
	return nil;
}

-(void)cancelArchive:(TUArchiveController *)archive
{
	TUArchiveTaskView *currentTaskView=[archive view];
	[currentTaskView cancelExtraction:nil];
}

-(void)cancellAllExtractions
{
	NSEnumerator *enumerator=[[appController archivecontrollers] objectEnumerator];
	TUArchiveController *currentArchiveController;
	while((currentArchiveController=[enumerator nextObject])) {
		[self cancelArchive:currentArchiveController];
	}
}

@end
