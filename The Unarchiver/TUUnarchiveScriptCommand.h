#import "TUController.h"

@interface TUUnarchiveScriptCommand : NSScriptCommand
{
	NSTimer *restoringTimer;
	TUController * appController; //Needed for calling the unarchaving methods
	BOOL deleteOriginals;
	BOOL openFolders; //currently not used (at least in Not Legacy)
	BOOL waitUntilFinished;
	int creatingFolder;
	int desttype;
	NSString * extractDestination;
}

-(id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef;
-(id)performDefaultImplementation;

-(BOOL)evalBooleanParameterForKey:(NSString *)parameterKey;
-(id)errorFileDontExist:(NSString *)file;

-(void)unarchiveFile:(NSString *)fileName;
-(void)quitIfPossible;

@end
