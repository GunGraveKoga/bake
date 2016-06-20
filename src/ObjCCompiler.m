#import "ObjCCompiler.h"
#import "Bake.h"

#import "CompilationFailedException.h"
#import "LinkingFailedException.h"

static ObjCCompiler *sharedCompiler = nil;

@implementation ObjCCompiler
+ sharedCompiler
{
	if (sharedCompiler == nil)
		sharedCompiler = [[ObjCCompiler alloc] init];

	return sharedCompiler;
}

- init
{
	self = [super init];

	@try {
		// FIXME!
		program = @"clang";
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)compileFile: (OFString*)file
	     target: (Target*)target
{
	OFMutableString *command = [OFMutableString stringWithFormat: @"%@ -c",
								      program];
	OFString *objectFile = [self objectFileForSource: file
						  target: target];
	OFString *dir = [objectFile stringByDeletingLastPathComponent];

	OFFileManager* fm = [OFFileManager defaultManager];

	if (![fm directoryExistsAtPath: dir])
		[fm createDirectoryAtPath: dir
				createParents: YES];

	if ([target platform] != nil) {
		[command appendString: @" --target="];
		[command appendString: [target platform]];
	}

	if ([target systemIncludes] != nil && [[target systemIncludes] count] > 0) {
		[command appendString: @" -isystem "];
		[command appendString:
		    [[target systemIncludes] componentsJoinedByString: @" -isystem "]];
	}

	if ([target debug])
		[command appendString: @" -g"];

	if ([target includeDirs] != nil && [[target includeDirs] count] > 0) {
		[command appendString: @" -I"];
		[command appendString:
		    [[target includeDirs] componentsJoinedByString: @" -I"]];
	}

	if ([target defines] != nil && [[target defines] count] > 0) {
		[command appendString: @" -D"];
		[command appendString:
		    [[target defines] componentsJoinedByString: @" -D"]];
	}

	if ([target objCFlags] != nil) {
		[command appendString: @" "];
		[command appendString:
		    [[target objCFlags] componentsJoinedByString: @" "]];
	}

	[command appendFormat: @" -o %@ %@", objectFile, file];

	if ([(Bake*)[[OFApplication sharedApplication] delegate] verbose])
		[of_stdout writeLine: command];

	if (system([command lossyCStringWithEncoding:OF_STRING_ENCODING_WINDOWS_1252]))
		@throw [CompilationFailedException
		    exceptionWithClass: [self class]
			       command: command];
}

- (void)linkTarget: (Target*)target
	extraFlags: (OFString*)extraFlags
{
	OFMutableString *command = [OFMutableString stringWithString: program];
	OFString *outputFile = [self outputFileForTarget: target];
	OFString *file, *dir = [outputFile stringByDeletingLastPathComponent];
	OFEnumerator *enumerator;
	OFFileManager* fm = [OFFileManager defaultManager];

	if (![fm directoryExistsAtPath: dir])
		[fm createDirectoryAtPath: dir
				createParents: YES];

	if ([target platform] != nil) {
		[command appendString: @" --target="];
		[command appendString: [target platform]];
	}

	if ([target debug])
		[command appendString: @" -g"];

	if (extraFlags != nil) {
		[command appendString: @" "];
		[command appendString: extraFlags];
	}

	[command appendFormat: @" -o %@", outputFile];

	enumerator = [[target files] objectEnumerator];
	while ((file = [enumerator nextObject]) != nil) {
		[command appendString: @" "];
		[command appendString:
		    [self objectFileForSource: file
				       target: target]];
	}

	if ([target libDirs] != nil && [[target libDirs] count] > 0) {
		[command appendString: @" -L"];
		[command appendString:
		    [[target libDirs] componentsJoinedByString: @" -L"]];
	}

	if ([target libs] != nil && [[target libs] count] > 0) {
		[command appendString: @" -l"];
		[command appendString:
		    [[target libs] componentsJoinedByString: @" -l"]];
	}

	if ([(Bake*)[[OFApplication sharedApplication] delegate] verbose])
		[of_stdout writeLine: command];

	if (system([command lossyCStringWithEncoding:OF_STRING_ENCODING_WINDOWS_1252]))
		@throw [LinkingFailedException exceptionWithClass: [self class]
							  command: command];
}
@end
