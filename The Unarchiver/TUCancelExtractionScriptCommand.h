#import "TUController.h"

@interface TUCancelExtractionScriptCommand : NSScriptCommand
{
	TUController *appController;
}

-(id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef;
-(id)performDefaultImplementation;

-(void)cancelArchive:(TUArchiveController *)archive;
-(void)cancellAllExtractions;

@end
