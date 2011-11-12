#import "TUArchiveController.h"
#import "TUController.h"
#import "TUTaskListView.h"
#import "TUEncodingPopUp.h"
#import <XADMaster/XADRegex.h>




static NSString *globalpassword=nil;
NSStringEncoding globalpasswordencoding=0;


@implementation TUArchiveController

+(void)clearGlobalPassword
{
	[globalpassword release];
	globalpassword=nil;
	globalpasswordencoding=0;
}

-(id)initWithFilename:(NSString *)filename taskView:(TUArchiveTaskView *)taskview
{
	if((self=[super init]))
	{
		view=[taskview retain];
		unarchiver=[[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:NULL] retain];

		archivename=[filename retain];
		destination=nil;
		tmpdest=nil;

		selected_encoding=0;

		finishtarget=nil;
		finishselector=NULL;

		cancelled=NO;
		ignoreall=NO;
	}
	return self;
}

-(void)dealloc
{
	[view release];
	[unarchiver release];
	[archivename release];
	[destination release];
	[tmpdest release];

	[super dealloc];
}



-(BOOL)isCancelled { return cancelled; }

-(NSString *)filename { return [[unarchiver outerArchiveParser] filename]; }

-(NSArray *)allFilenames { return [[unarchiver outerArchiveParser] allFilenames]; }

-(BOOL)caresAboutPasswordEncoding { return [[unarchiver archiveParser] caresAboutPasswordEncoding]; }

-(TUArchiveTaskView *)taskView { return view; }




-(void)setIsCancelled:(BOOL)iscancelled { cancelled=iscancelled; }

-(void)setDestination:(NSString *)newdestination
{
	[destination autorelease];
	destination=[newdestination retain];
}




-(NSString *)currentArchiveName
{
	NSString *currfilename=[[unarchiver archiveParser] currentFilename];
	NSString *currarchivename=[currfilename lastPathComponent];
	return currarchivename;
}

-(NSString *)localizedDescriptionOfError:(XADError)error
{
	NSString *errorstr=[XADException describeXADError:error];
	NSString *localizederror=[[NSBundle mainBundle] localizedStringForKey:errorstr value:errorstr table:nil];
	return localizederror;
}

-(NSString *)stringForXADPath:(XADPath *)path
{
	NSStringEncoding encoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	if(!encoding) encoding=selected_encoding;
	if(!encoding) encoding=[path encoding];
	return [path stringWithEncoding:encoding];
}




-(void)runWithFinishAction:(SEL)selector target:(id)target
{
	finishtarget=target;
	finishselector=selector;
	[self retain];

	[view setCancelAction:@selector(archiveTaskViewCancelled:) target:self];

	//[view setupProgressViewInPreparingMode];

	static int tmpcounter=0;
	NSString *tmpdir=[NSString stringWithFormat:@".TheUnarchiverTemp%d",tmpcounter++];
	tmpdest=[[destination stringByAppendingPathComponent:tmpdir] retain];

	[self rememberTempDirectory:tmpdest];

	[NSThread detachNewThreadSelector:@selector(extractThreadEntry) toTarget:self withObject:nil];
}

-(void)extractThreadEntry
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	[self extract];
	[pool release];
}

-(void)extract
{
	if(!unarchiver)
	{
		[view displayOpenError:[NSString stringWithFormat:
		NSLocalizedString(@"The contents of the file \"%@\" can not be extracted with this program.",@"Error message for files not extractable by The Unarchiver"),
		[archivename lastPathComponent]]];

		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		return;
	}

	int foldermode=[[NSUserDefaults standardUserDefaults] integerForKey:@"createFolder"];
	BOOL copydatepref=[[NSUserDefaults standardUserDefaults] integerForKey:@"folderModifiedDate"]==2;
	BOOL changefilespref=[[NSUserDefaults standardUserDefaults] boolForKey:@"changeDateOfFiles"];

	[unarchiver setDelegate:self];
	[unarchiver setPropagatesRelevantMetadata:YES];
	[unarchiver setAlwaysRenamesFiles:YES];
	[unarchiver setCopiesArchiveModificationTimeToEnclosingDirectory:copydatepref];
	[unarchiver setCopiesArchiveModificationTimeToSoloItems:copydatepref && changefilespref];
	[unarchiver setResetsDateForSoloItems:!copydatepref && changefilespref];

	switch(foldermode)
	{
		case 1: // Enclose multiple items.
		default:
			[unarchiver setDestination:tmpdest];
			[unarchiver setRemovesEnclosingDirectoryForSoloItems:YES];
		break;

		case 2: // Always enclose.
			[unarchiver setDestination:tmpdest];
			[unarchiver setRemovesEnclosingDirectoryForSoloItems:NO];
		break;

		case 3: // Never enclose.
			[unarchiver setDestination:destination];
			[unarchiver setEnclosingDirectoryName:nil];
		break;
	}

	XADError error=[unarchiver parse];
	if(error==XADBreakError)
	{
		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		return;
	}
	else if(error)
	{
		if(![view displayError:[NSString stringWithFormat:
			NSLocalizedString(@"There was a problem while reading the contents of the file \"%@\": %@",@"Error message when encountering an error while parsing an archive"),
			[self currentArchiveName],
			[self localizedDescriptionOfError:error]]
		ignoreAll:&ignoreall])
		{
			[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
			return;
		}
	}

	error=[unarchiver unarchive];
	if(error)
	{
		if(error!=XADBreakError)
		[view displayOpenError:[NSString stringWithFormat:
			NSLocalizedString(@"There was a problem while extracting the contents of the file \"%@\": %@",@"Error message when encountering an error while extracting entries"),
			[self currentArchiveName],
			[self localizedDescriptionOfError:error]]];

		[self performSelectorOnMainThread:@selector(extractFailed) withObject:nil waitUntilDone:NO];
		return;
	}

	[self performSelectorOnMainThread:@selector(extractFinished) withObject:nil waitUntilDone:NO];
}

-(void)extractFinished
{
	BOOL deletearchivepref=[[NSUserDefaults standardUserDefaults] boolForKey:@"deleteExtractedArchive"];
	BOOL openfolderpref=[[NSUserDefaults standardUserDefaults] boolForKey:@"openExtractedFolder"];

	BOOL soloitem=[unarchiver wasSoloItem];

	// Move files out of temporary directory, if we used one.
	NSString *newpath=nil;
	if([unarchiver enclosingDirectoryName])
	{
		NSString *path=[unarchiver createdItem];
		NSString *filename=[path lastPathComponent];
		NSString *newpath=[destination stringByAppendingPathComponent:filename];

		// Check if we accidentally created a package.
		if(!soloitem)
		if([[NSWorkspace sharedWorkspace] isFilePackageAtPath:path])
		{
			newpath=[newpath stringByDeletingPathExtension];
		}

		// Avoid collisions.
		newpath=[unarchiver _findUniquePathForOriginalPath:newpath];

		// Move files into place
		[unarchiver _moveItemAtPath:path toPath:newpath];
		[unarchiver _removeItemAtPath:tmpdest];
	}

	// Remove temporary directory from crash recovery list
	[self forgetTempDirectory:tmpdest];

	// Delete archive if requested
	if(deletearchivepref)
	{
		NSString *directory=[archivename stringByDeletingLastPathComponent];
		NSArray *allpaths=[[unarchiver outerArchiveParser] allFilenames];
		NSMutableArray *allfiles=[NSMutableArray arrayWithCapacity:[allpaths count]];
		NSEnumerator *enumerator=[allpaths objectEnumerator];
		NSString *path;
		while((path=[enumerator nextObject]))
		{
			if([[path stringByDeletingLastPathComponent] isEqual:directory])
			[allfiles addObject:[path lastPathComponent]];
		}

		[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
		source:directory destination:nil files:allfiles tag:nil];
		//[self playSound:@"/System/Library/Components/CoreAudio.component/Contents/Resources/SystemSounds/dock/drag to trash.aif"];
	}

	// Open folder if requested
	if(openfolderpref)
	{
		if(newpath)
		{
			BOOL isdir;
			[[NSFileManager defaultManager] fileExistsAtPath:newpath isDirectory:&isdir];
			if(isdir&&![[NSWorkspace sharedWorkspace] isFilePackageAtPath:newpath])
			{
				[[NSWorkspace sharedWorkspace] openFile:newpath];
			}
			else
			{
				[[NSWorkspace sharedWorkspace] selectFile:newpath inFileViewerRootedAtPath:@""];
			}
		}
		else
		{
			[[NSWorkspace sharedWorkspace] openFile:destination];
		}
	}

	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)extractFailed
{
	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1050
	[[NSFileManager defaultManager] removeItemAtPath:tmpdest error:NULL];
	#else
	[[NSFileManager defaultManager] removeFileAtPath:tmpdest handler:nil];
	#endif

	[self forgetTempDirectory:tmpdest];

	[finishtarget performSelector:finishselector withObject:self];
	[self release];
}

-(void)rememberTempDirectory:(NSString *)tmpdir
{
	NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
	NSArray *tmpdirs=[defs arrayForKey:@"orphanedTempDirectories"];
	if(!tmpdirs) tmpdirs=[NSArray array];
	[defs setObject:[tmpdirs arrayByAddingObject:tmpdir] forKey:@"orphanedTempDirectories"];
	[defs synchronize];
}

-(void)forgetTempDirectory:(NSString *)tmpdir
{
	NSUserDefaults *defs=[NSUserDefaults standardUserDefaults];
	NSMutableArray *tmpdirs=[NSMutableArray arrayWithArray:[defs arrayForKey:@"orphanedTempDirectories"]];
	[tmpdirs removeObject:tmpdir];
	[defs setObject:tmpdirs forKey:@"orphanedTempDirectories"];
	[defs synchronize];
}




-(void)archiveTaskViewCancelled:(TUArchiveTaskView *)taskview
{
	cancelled=YES;
}




-(BOOL)extractionShouldStopForSimpleUnarchiver:(XADSimpleUnarchiver *)unarchiver
{
	return cancelled;
}

-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender encodingNameForXADString:(id <XADString>)string
{
	// TODO: Stop using NSStringEncoding.

	// If the user has set an encoding in the preferences, always use this.
	NSStringEncoding setencoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	if(setencoding) return [XADString encodingNameForEncoding:setencoding];

	// If the user has already been asked for an encoding, try to use it.
	// Otherwise, if the confidence in the guessed encoding is high enough, try that.
	int threshold=[[NSUserDefaults standardUserDefaults] integerForKey:@"autoDetectionThreshold"];

	NSStringEncoding encoding=0;
	if(selected_encoding) encoding=selected_encoding;
	else if([string confidence]*100>=threshold) encoding=[string encoding];

	// If we have an encoding we trust, and it can decode the string, use it.
	if(encoding && [string canDecodeWithEncoding:encoding])
	return [XADString encodingNameForEncoding:encoding];

	// Otherwise, ask the user for an encoding.
	selected_encoding=[view displayEncodingSelectorForXADString:string];
	if(!selected_encoding)
	{
		cancelled=YES;
		return nil;
	}
	return [XADString encodingNameForEncoding:selected_encoding];
}

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)sender
{
	if(globalpassword)
	{
		[sender setPassword:globalpassword];
		if(globalpasswordencoding)
		{
			[[sender archiveParser] setPasswordEncodingName:
			[XADString encodingNameForEncoding:globalpasswordencoding]];
		}
	}
	else
	{
		BOOL applytoall;
		NSStringEncoding encoding;
		NSString *password=[view displayPasswordInputWithApplyToAllPointer:&applytoall
		encodingPointer:&encoding];

		if(password)
		{
			[sender setPassword:password];
			if(encoding)
			{
				[[sender archiveParser] setPasswordEncodingName:
				[XADString encodingNameForEncoding:encoding]];
			}

			if(applytoall)
			{
				globalpassword=[password retain];
				globalpasswordencoding=encoding;
			}
		}
		else
		{
			cancelled=YES;
		}
	}
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	XADPath *name=[dict objectForKey:XADFileNameKey];

	// TODO: Do something prettier here.
	NSStringEncoding encoding=[[NSUserDefaults standardUserDefaults] integerForKey:@"filenameEncoding"];
	if(!encoding) encoding=selected_encoding;
	if(!encoding) encoding=[name encoding];

	if(name) [view setName:[name stringWithEncoding:encoding]];
	else [view setName:@""];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender
extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(off_t)fileprogress of:(off_t)filesize
totalProgress:(off_t)totalprogress of:(off_t)totalsize
{
	[view setProgress:(double)totalprogress/(double)totalsize];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender
estimatedExtractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileProgress:(double)fileprogress totalProgress:(double)totalprogress
{
	[view setProgress:totalprogress];
}

-(void)simpleUnarchiver:(XADSimpleUnarchiver *)sender didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error;
{
	if(ignoreall||cancelled) return;

	if(error)
	{
		XADPath *filename=[dict objectForKey:XADFileNameKey];

		NSNumber *isresfork=[dict objectForKey:XADIsResourceForkKey];
		if(isresfork&&[isresfork boolValue])
		{
			cancelled=![view displayError:[NSString stringWithFormat:
				NSLocalizedString(@"Could not extract the resource fork for the file \"%@\" from the archive \"%@\":\n%@",@"Error message string. The first %@ is the file name, the second the archive name, the third is error message"),
				[self stringForXADPath:filename],
				[self currentArchiveName],
				[self localizedDescriptionOfError:error]]
			ignoreAll:&ignoreall];
		}
		else
		{
			cancelled=![view displayError:[NSString stringWithFormat:
				NSLocalizedString(@"Could not extract the file \"%@\" from the archive \"%@\": %@",@"Error message string. The first %@ is the file name, the second the archive name, the third is error message"),
				[self stringForXADPath:filename],
				[self currentArchiveName],
				[self localizedDescriptionOfError:error]]
			ignoreAll:&ignoreall];
		}
	}
}

/*-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender replacementPathForEntryWithDictionary:(NSDictionary *)dict
originalPath:(NSString *)path suggestedPath:(NSString *)unique;
-(NSString *)simpleUnarchiver:(XADSimpleUnarchiver *)sender deferredReplacementPathForOriginalPath:(NSString *)path
suggestedPath:(NSString *)unique;*/

@end
