#include <Foundation/Foundation.h>

static inline NSStringEncoding WindowsCodePageToNSStringEncoding(int codepage)
{
	return 0xc0de0000+codepage;
}

static inline BOOL IsNSStringEncodingWindowsCodePage(NSStringEncoding encoding)
{
	return (encoding&0xffff0000)==0xc0de0000;
}

static inline int NSStringEncodingToWindowsCodePage(NSStringEncoding encoding)
{
	if(ISNSStringEncodingWindowsCodePage(encoding)) return encoding&0xffff;
	else return 0;
}

int IANACharSetNameToWindowsCodePage(NSString *name);
