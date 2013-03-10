#import "TUUnarchiveScriptCommand.h"

//User defaults keys:

/*
 Keys -> type
 //importants:
 @"deleteExtractedArchive"
 @"openExtractedArchive"
 @"extractionDestinationPath" string
 
 @"createFolder" integer:
	1 : only …
	2 : always
	3 : never
 @"extractionDestination" integer
 @"changeDateOfFiles"
 */

#define UDKdelete  @"deleteExtractedArchive"
#define UDKopen  @"openExtractedFolder"
#define UDKdestination @"extractionDestination"
#define UDKdestinationPath @"extractionDestinationPath"
#define UDKcreateFolderMode @"createFolder"

//keys for the parameters of the command
#define PKdestination @"destination"
#define PKdeleting  @"deletingOriginal"
#define PKopening @"opening"
#define PKcreatingFolder @"creatingFolder"
#define PKwaitUntilFinished @"waitUntilFinished"

//Enum for the AppleScript enumerarion "File Destination"
enum destinationFolder {
	destinationFolderDesktop = 'Desk',
	destinationFolderAskUser = 'AskU',
	destinationFolderOriginal = 'Orig',
	destinationFolderUserDefault = 'UDef'
	};

//Enum for the AppleScript enumerarion "Create new folder"
enum creatingFolderEnum {
	creatingFolderNever = 'NevE',
	creatingFolderOnly = 'OnlY',
	creatingFolderAlways = 'AlwA'
	};

enum creatingFolderUD {
	creatingFolderUDOnly = 1,
	creatingFolderUDAlways = 2,
	creatingFolderUDNever = 3
	};

enum extracionDestination {
	extractionDestinationCurrentFolderDestination = 1,
	extractionDestinationDesktopDestination = 2, //selected by user at pref panel, maybe other than ~/Desktop
	extractionDestinationSelectedDestination = 3,
	extractionDestinationUnintializedDestination = 4,
	extractionDestinationCustomPath=10,
	};

@implementation TUUnarchiveScriptCommand

#pragma mark Overriding methods:
-(id)initWithCommandDescription:(NSScriptCommandDescription *)commandDef
{
	self=[super initWithCommandDescription:commandDef];
	if (self) {
		extractDestination = [[NSUserDefaults standardUserDefaults] stringForKey:UDKdestinationPath];
		appController = [[NSApplication sharedApplication] delegate];
	}
	return self;
}

-(id)performDefaultImplementation
{
	/*
	 The commands will be something like:
	 unarchive listOfArchives(orPaths?) [to destination] [deleting yes] [opening yes]
	 */
#ifdef DEBUG
	NSLog(@"Running default implementation of command \"unarchive\"");
#endif
	
	//Get the files to unarchive (an array) and the arguments
	NSArray *files=[self directParameter];
	NSDictionary *evaluatedArgs = [self evaluatedArguments];

	//We check that all the files exists
	NSFileManager *fileManager=[NSFileManager defaultManager];
	NSEnumerator *enumerator=[files objectEnumerator];
	NSString *file;
	while((file=[enumerator nextObject])) {
		if (![fileManager fileExistsAtPath:file])
		{
			return [self errorFileDontExist:file];
		}
	}
	//Check and evaluate the parameter "destination"
	id destination=[evaluatedArgs objectForKey:PKdestination];
	int destinationIntValue;
	if (destination)
	{
		if ([destination isKindOfClass:[NSString class]] && [fileManager fileExistsAtPath:destination])
		{
			extractDestination = destination;
			destinationIntValue = extractionDestinationCustomPath;
		}
		else
		{
			unsigned long destinationLongValue=[destination unsignedLongValue];
			switch (destinationLongValue)
			{
				case destinationFolderDesktop:
					destinationIntValue = extractionDestinationCustomPath;
					extractDestination = [@"~/Desktop" stringByExpandingTildeInPath];
					break;
				case destinationFolderOriginal:
					destinationIntValue = extractionDestinationCurrentFolderDestination;
					break;
				case destinationFolderAskUser:
					destinationIntValue = extractionDestinationSelectedDestination;
					break;
				case destinationFolderUserDefault:
					destinationIntValue = extractionDestinationDesktopDestination;
					break;
				default:
					//If there is no parameter we use the user defaults
					destinationIntValue = [[NSUserDefaults standardUserDefaults] integerForKey:UDKdestination];
					break;
			}
		}
	}
	else {
		destinationIntValue = [[NSUserDefaults standardUserDefaults] integerForKey:UDKdestination];
	}
	desttype=destinationIntValue;
	
	//Get the rest of optional parameters
	deleteOriginals = [self evalBooleanParameterForKey:PKdeleting];
	openFolders = [self evalBooleanParameterForKey:PKopening];
	waitUntilFinished =[self evalBooleanParameterForKey:PKwaitUntilFinished];
	
	unsigned long creatingFolderValue  = [[evaluatedArgs objectForKey:PKcreatingFolder] unsignedLongValue];
	switch (creatingFolderValue) {
		case creatingFolderNever:
			creatingFolder = creatingFolderUDNever;
			break;
		case creatingFolderOnly:
			creatingFolder = creatingFolderUDOnly;
			break;
		case creatingFolderAlways:
			creatingFolder = creatingFolderUDAlways;
			break;
		default:
			creatingFolder = [[NSUserDefaults standardUserDefaults] integerForKey:UDKcreateFolderMode];
			break;
	}
	
	enumerator=[files objectEnumerator];
	NSString *filename;
	while((filename=[enumerator nextObject])) {
		[self unarchiveFile:filename];
	}
	
	if (waitUntilFinished) {
		restoringTimer=[[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:0.5] interval:0.5 target:self selector:@selector(quitIfPossible) userInfo:nil repeats:YES];
		NSRunLoop *mainLoop =[NSRunLoop currentRunLoop];
		[mainLoop addTimer:restoringTimer forMode:NSDefaultRunLoopMode];
		[self suspendExecution];
	}
	return nil;
}

#pragma mark Custom methods

-(BOOL)evalBooleanParameterForKey:(NSString *)parameterKey
{
	NSDictionary *evaluatedArgs = [self evaluatedArguments];
	id parameter = [evaluatedArgs objectForKey:parameterKey];
	if (! parameter) {
		if ([parameterKey isEqualToString:PKdeleting]) {
			return [[NSUserDefaults standardUserDefaults] boolForKey:UDKdelete];
		}
		if ([parameterKey isEqualToString:PKopening]) {
			return [[NSUserDefaults standardUserDefaults] boolForKey:UDKopen];
		}
		if ([parameterKey isEqualToString:PKwaitUntilFinished]) {
			return YES;
		}
	}
	return [parameter boolValue];
}

-(id)errorFileDontExist:(NSString *)file
{
	// TODO: choose a correct error number
	[self setScriptErrorNumber:1];
	NSString *errorMessage = [NSString stringWithFormat:@"The file %@ doesn't exist.",file];
	[self setScriptErrorString:errorMessage];
	return nil;
}

-(void)quitIfPossible
{
	if ([appController hasRunningExtractions]) {
		return;
	}
	[self resumeExecutionWithResult:nil];
}

-(void)unarchiveFile:(NSString *)fileName
{
	if([appController archiveControllerForFilename:fileName]) return;
	TUArchiveController *archiveController=[[[TUArchiveController alloc] initWithFilename:fileName] autorelease];
	NSString *destination;
	switch (desttype) {
		default:
		case extractionDestinationCurrentFolderDestination:
		case extractionDestinationDesktopDestination:
			destination =[appController destinationForFilename:fileName type:desttype];
			break;
		case extractionDestinationCustomPath:
			destination=extractDestination;
			break;
	}
	[archiveController setDestination:destination];
	[archiveController setDeleteArchive:deleteOriginals];
	[archiveController setFolderCreationMode:creatingFolder];
	[archiveController setOpenExctractedItem:openFolders];
	
	if (archiveController) {
		[appController addArchiveController:archiveController];
	}
}

@end
