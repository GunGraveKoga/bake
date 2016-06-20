#import "Bake.h"
#import "Compiler.h"
#import "DependencySolver.h"
#import "ObjCCompiler.h"
#import "Target.h"
#import "IngredientProducer.h"

#import "CompilationFailedException.h"
#import "LinkingFailedException.h"
#import "MissingDependencyException.h"
#import "MissingIngredientException.h"
#import "WrongVersionException.h"

OF_APPLICATION_DELEGATE(Bake)

@implementation Bake
- (void)applicationDidFinishLaunching
{
	OFArray *arguments;
	OFSet *conditions;
	DependencySolver *dependencySolver;
	OFEnumerator *enumerator;
	Target *target;
	OFArray *targetOrder;
	BOOL install;
	OFString *prefix = @"/usr/local";
	OFString *bindir = [prefix stringByAppendingString: @"/bin"];
	OFString *includedir = [prefix stringByAppendingString: @"/include"];
	OFString *libdir = [prefix stringByAppendingString: @"/lib"];

	arguments = [OFApplication arguments];
	install = [arguments containsObject: @"--install"];

	if ([arguments containsObject:@"--prefix"]) {
		size_t idx = [arguments indexOfObject:@"--prefix"];
		OFString* oldprefix = prefix;
		OFString* oldbindir = bindir;
		OFString* oldlibdir = libdir;
		OFString* oldincdir = includedir;
		prefix = [arguments objectAtIndex: idx + 1];
		bindir = [prefix stringByAppendingString: @"/bin"];
		includedir = [prefix stringByAppendingString: @"/include"];
		libdir = [prefix stringByAppendingString: @"/lib"];
		of_log(@"Find prefix %@", prefix);
		[oldprefix release];
		[oldbindir release];
		[oldincdir release];
		[oldlibdir release];
	}

	if ([arguments containsObject: @"--produce-ingredient"]) {
		IngredientProducer *producer;
		OFEnumerator *enumerator;
		OFString *argument;

		producer = [[IngredientProducer alloc] init];

		arguments = [arguments
		    arrayByRemovingObject: @"--produce-ingredient"];
		enumerator = [arguments objectEnumerator];
		while ((argument = [enumerator nextObject]) != nil)
			[producer parseArgument: argument];

		[of_stdout writeLine:
		    [[producer ingredient] JSONRepresentation]];

		[OFApplication terminate];
	}

	[self findRecipe];

	@try {
		recipe = [[Recipe alloc] init];
	} @catch (OFOpenItemFailedException *e) {
		[of_stderr writeLine: @"Error: Could not find Recipe!"];
		[OFApplication terminateWithStatus: 1];
	} @catch (OFInvalidJSONException *e) {
		[of_stderr writeFormat: @"Error: Malformed Recipe in line "
					@"%zd!\n", [e line]];
		[OFApplication terminateWithStatus: 1];
	} @catch (WrongVersionException *e) {
		[of_stderr writeLine: @"Error: Recipe version too new!"];
		[OFApplication terminateWithStatus: 1];
	}

	// FIXME
	conditions = [OFSet setWithObjects: @"objc_gcc_compatible",
					    @"true",
					    nil];

	verbose = ([arguments containsObject: @"--verbose"] ||
	    [arguments containsObject: @"-v"]);
	rebake = ([arguments containsObject: @"--rebake"] ||
	    [arguments containsObject: @"-r"]);

	dependencySolver = [[[DependencySolver alloc] init] autorelease];

	enumerator = [[recipe targets] objectEnumerator];
	while ((target = [enumerator nextObject]) != nil)
		[dependencySolver addTarget: target];

	@try {
		[dependencySolver solve];
	} @catch (MissingDependencyException *e) {
		[of_stderr writeFormat: @"Error: Target %@ is missing, but "
					@"specified as dependency!\n",
					[e dependencyName]];
		[OFApplication terminateWithStatus: 1];
	}

	targetOrder = [dependencySolver targetOrder];

	enumerator = [targetOrder objectEnumerator];
	while ((target = [enumerator nextObject]) != nil) {
		OFEnumerator *fileEnumerator;
		OFString *file;
		size_t i = 0;
		BOOL link = NO;
		OFFileManager* fm = [OFFileManager defaultManager];

		[target resolveConditionals: conditions];

		@try {
			[target addIngredients];
		} @catch (MissingIngredientException *e) {
			[of_stderr writeFormat: @"Error: Ingredient %@ "
						@"missing!\n",
						[e ingredientName]];
			[OFApplication terminateWithStatus: 1];
		}

		fileEnumerator = [[target files] objectEnumerator];
		while ((file = [fileEnumerator nextObject]) != nil) {
			if (![self shouldRebuildFile: file
					      target: target]) {
				i++;
				continue;
			}

			link = YES;

			if (!verbose)
				[of_stdout writeFormat: @"\r%@: %zd/%zd",
							[target name], i,
							[[target files] count]];

			@try {
				Compiler *compiler =
				    [Compiler compilerForFile: file
						       target: target];

				[compiler compileFile: file
					       target: target];
			} @catch (CompilationFailedException *e) {
				[of_stdout writeString: @"\n"];
				[of_stderr writeFormat:
				    @"Failed to compile file %@!\n"
				    @"Command was:\n%@\n", file, [e command]];
				[OFApplication terminateWithStatus: 1];
			}

			i++;

			if (!verbose)
				[of_stdout writeFormat: @"\r%@: %zd/%zd",
							[target name], i,
							[[target files] count]];
		}

		if (link || ([[target files] count] > 0 &&
		    ![fm fileExistsAtPath: [[ObjCCompiler sharedCompiler]
		    outputFileForTarget: target]])) {
			if (!verbose)
				[of_stdout writeFormat:
				    @"\r%@: %zd/%zd (linking)",
				    [target name], i, [[target files] count]];

			@try {
				/*
				 * FIXME: Need to find out which compiler a
				 *	  target needs to link!
				 */
				[[ObjCCompiler sharedCompiler]
				    linkTarget: target
				    extraFlags: nil];
			} @catch (LinkingFailedException *e) {
				[of_stdout writeString: @"\n"];
				[of_stderr writeFormat:
				    @"Failed to link target %@!"
				    @"Command was:\n%@\n",
				    [target name], [e command]];
				[OFApplication terminateWithStatus: 1];
			}

			if (!verbose)
				[of_stdout writeFormat:
				    @"\r%@: %zd/%zd (successful)\n",
				    [target name], i, [[target files] count]];
		} else
			[of_stdout writeFormat: @"%@: Already up to date\n",
						[target name]];

		if (install && [[target files] count] > 0) {
			OFString *file = [[ObjCCompiler sharedCompiler]
			    outputFileForTarget: target];
			OFString *destination = [OFString pathWithComponents:
			    @[bindir, [file lastPathComponent]]];


			[of_stdout writeFormat: @"Installing: %@ -> %@\n",
						file, [destination stringByStandardizingPath]];

			if (![fm directoryExistsAtPath: bindir]) {
				[of_stdout writeFormat: @"Creating directory: %@\n",
						[destination stringByStandardizingPath]];
				@try {
					[fm createDirectoryAtPath: [bindir stringByStandardizingPath]
						createParents: NO];
				}@catch(OFCreateDirectoryFailedException* e) {
					[of_stdout writeFormat: @"Faild creating directory: %@\n",
						[e path]];
					[OFApplication terminateWithStatus:-1];
				}
			}
			@try {
				[fm copyItemAtPath: file
					toPath: [destination stringByStandardizingPath]];
			}@catch(OFCopyItemFailedException* e) {
				[of_stdout writeFormat: @"Faild copy %@ to directory: %@ (Error: %d)\n",
						[e sourcePath], [e destinationPath], [e errNo]];
					[OFApplication terminateWithStatus:-1];
			}
		}
	}

	[OFApplication terminate];
}

- (void)findRecipe
{
	OFFileManager* fm = [OFFileManager defaultManager];
	OFString *oldPath = [fm currentDirectoryPath];

	while (![fm fileExistsAtPath: @"Recipe"]) {
		[fm changeCurrentDirectoryPath: OF_PATH_PARENT_DIRECTORY];

		/* We reached the file system root */
		if ([[fm currentDirectoryPath] isEqual: oldPath])
			break;

		oldPath = [fm currentDirectoryPath];
	}
}

- (BOOL)shouldRebuildFile: (OFString*)file
		   target: (Target*)target
{
	Compiler *compiler;
	OFString *objectFile;
	OFDate *sourceDate, *objectDate;

	OFFileManager* fm = [OFFileManager defaultManager];

	if (rebake)
		return YES;

	compiler = [Compiler compilerForFile: file
				      target: target];
	objectFile = [compiler objectFileForSource: file
					    target: target];

	if (![fm fileExistsAtPath: objectFile])
		return YES;

	sourceDate = [fm statusChangeTimeOfItemAtPath: file];
	objectDate = [fm statusChangeTimeOfItemAtPath: objectFile];

	return ([objectDate compare: sourceDate] == OF_ORDERED_ASCENDING);
}

- (BOOL)verbose
{
	return verbose;
}
@end
