#import "Compiler.h"
#import "ObjCCompiler.h"

@implementation Compiler
+ (Compiler*)compilerForFile: (OFString*)file
		      target: (OFString*)target
{
	if ([file hasSuffix: @".m"])
		return [ObjCCompiler sharedCompiler];

	return nil;
}

- (OFString*)objectFileForSource: (OFString*)file
			  target: (Target*)target
{
	file = [file stringByAppendingString: @".o"];
	return [OFString pathWithComponents: @[@"pastries", [target name], file]];
}

- (OFString*)outputFileForTarget: (Target*)target
{
	OFString *last = [[target name] lastPathComponent];
	return [OFString pathWithComponents: @[@"pastries", [target name], last]];
}

- (void)compileFile: (OFString*)file
	     target: (Target*)target
{
	@throw [OFNotImplementedException exceptionWithSelector: _cmd object: self];
}

- (void)linkTarget: (Target*)target
	extraFlags: (OFString*)extraFlags
{
	@throw [OFNotImplementedException exceptionWithSelector: _cmd object: self];
}
@end
