#import "TUCancelExtractionScriptCommand.h"

enum taskSelection {
	taskSelectionAll = 'TaAl'
	};

@implementation TUCancelExtractionScriptCommand

-(id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef
{
	self=[super initWithCommandDescription:commandDef];
	appController=[NSApplication sharedApplication].delegate;
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
	for (TUArchiveController *currentArchiveController in [appController archivecontrollers]) {
		[self cancelArchive:currentArchiveController];
	}
}

@end
