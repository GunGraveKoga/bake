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

@synthesize verbose = _verbose;
@synthesize rebake = _rebake;
@synthesize recipe = _recipe;
@synthesize install = _install;
@synthesize produceIngredient = _produceIngredient;
@synthesize prefix = _prefix;

- (instancetype)init
{
	self = [super init];
	_recipe = nil;
	_prefix = nil;
	_verbose = NO;
	_rebake = NO;
	_install = NO;
	_produceIngredient = NO;

	return self;
}

- (void)applicationDidFinishLaunching
{
	OFSet *conditions;
	DependencySolver *dependencySolver;

	OFArray *targetOrder;

	OFString *bindir = nil;
	OFString *includedir = nil;
	OFString *libdir = nil;

	OFString* prefix_ = nil;

	const of_options_parser_option_t options[] = {
		{ 'h', @"help", 0, NULL, NULL },
		{ 'v', @"verbose", 0, (bool *)&_verbose, NULL},
		{ 'r', @"rebake", 0, (bool *)&_rebake, NULL},
		{ '\0', @"produce-ingredient", 0, (bool *)&_produceIngredient, NULL},
		{ '\0', @"prefix", 1, NULL, &prefix_},
		{ '\0', @"install", 0, (bool *)&_install, NULL},
		{ '\0', nil, 0, NULL, NULL }
	};

	OFOptionsParser* optionParser = [OFOptionsParser parserWithOptions:options];

	of_unichar_t option = '\0';

	while ((option = [optionParser nextOption]) != '\0') {
		switch (option) {
			case 'h':
				[of_stdout writeLine:@"Help message."];
				[OFApplication terminateWithStatus:0];
				break;
			case '=':
				[of_stderr writeFormat:@"%@: Option --%@ takes no argument!\n",
					[OFApplication programName],
					[optionParser lastLongOption]];
				[OFApplication terminateWithStatus:1];
				break;
			case '?':
				if (self.produceIngredient)
					[self produceIngredientWithArguments:[optionParser remainingArguments]];

				if ([optionParser lastLongOption] != nil)
					[of_stderr writeFormat:@"%@: Unknown option: --%@\n",
						[OFApplication programName],
						[optionParser lastLongOption]];
				else
					[of_stderr writeFormat:@"%@: Unknown option: -%C\n",
						[OFApplication programName],
						[optionParser lastOption]];

				[OFApplication terminateWithStatus:1];
				break;
		}
	}

	if (prefix_ != nil)
		self.prefix = prefix_;
	else
		self.prefix = @"/usr/local";

	bindir = [self.prefix stringByAppendingString:@"/bin"];
	includedir = [self.prefix stringByAppendingString:@"/include"];
	libdir = [self.prefix stringByAppendingString:@"/lib"];

	of_log(@"Find prefix %@", self.prefix);

	[self findRecipe];

	@try {
		self.recipe = [[[Recipe alloc] init] autorelease];
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


	dependencySolver = [[[DependencySolver alloc] init] autorelease];

	@autoreleasepool {
		for (Target* target in [[self.recipe targets] allObjects]) {
			[dependencySolver addTarget:target];
		}
	}

	@try {
		[dependencySolver solve];
	} @catch (MissingDependencyException *e) {
		[of_stderr writeFormat: @"Error: Target %@ is missing, but "
					@"specified as dependency!\n",
					[e dependencyName]];
		[OFApplication terminateWithStatus: 1];
	}

	targetOrder = [dependencySolver targetOrder];

	OFAutoreleasePool* pool = [OFAutoreleasePool new];
	OFFileManager* fm = [OFFileManager defaultManager];

	for (Target* target in targetOrder) {
		size_t i = 0;
		BOOL link = NO;

		[target resolveConditionals:conditions];

		@try {
			[target addIngredients];
		}@catch (MissingIngredientException *e) {
			[of_stderr writeFormat:@"Error: Ingredient %@ missing!\n",
				[e ingredientName]];
			[OFApplication terminateWithStatus:1];
		}

		@autoreleasepool {
			for (OFString* file in [target files]) {
				if (![self shouldRebuildFile:file target:target]) {
					i++;
					continue;
				}

				link = YES;

				if (!self.verbose)
					[of_stdout writeFormat:@"\r%@: %zd/%zd",
						[target name], i,
						[[target files] count]];

				@try {
					Compiler* compiler = [Compiler compilerForFile:file target:target];

					[compiler compileFile:file target:target];

				} @catch (CompilationFailedException *e) {
					[of_stdout writeString:@"\n"];

					[of_stderr writeFormat:
						@"Faild to compile file %@!\n"
						@"Command was:\n%@\n",
						file, [e command]];

					[OFApplication terminateWithStatus:1];

				}

				i++;

				if (!self.verbose)
					[of_stdout writeFormat:@"\r%@: %zd/%zd",
						[target name], i,
						[[target files] count]];
			}
		}

		if (link || ([[target files] count] > 0 && ![fm fileExistsAtPath:[[ObjCCompiler sharedCompiler] outputFileForTarget:target]])) {
			if (!self.verbose)
				[of_stdout writeFormat:@"\r%@: %zd/%zd (linking)",
					[target name], i, [[target files] count]];

			@try {
				/*
				 * FIXME: Need to find out which compiler a
				 *	  target needs to link!
				 */

				 [[ObjCCompiler sharedCompiler] linkTarget:target extraFlags:nil];

			} @catch (LinkingFailedException *e) {
				[of_stdout writeString:@"\n"];
				[of_stderr writeFormat:
					@"Faild to link target %@!\n"
					@"Command was:\n%@\n",
					[target name], [e command]];

				[OFApplication terminateWithStatus:1];

			}

			if (!self.verbose)
				[of_stdout writeFormat:
					@"\r%@: %zd/%zd (success)\n",
					[target name], i, [[target files] count]];

		} else {
			[of_stdout writeFormat:@"\r%@: Already up to date\n", [target name]];
		}

		if (self.install && [[target files] count] > 0) {
			bindir = [bindir stringByStandardizingPath];
			libdir = [libdir stringByStandardizingPath];
			includedir = [includedir stringByStandardizingPath];

			OFString* file = [[ObjCCompiler sharedCompiler] outputFileForTarget:target];
			OFString* destination = [OFString pathWithComponents:@[bindir, [file lastPathComponent]]];
			destination = [destination stringByStandardizingPath];

			[of_stdout writeFormat:@"Installing: %@ -> %@\n",
				file, destination];

			if (![fm directoryExistsAtPath:bindir]) {
				[of_stdout writeFormat:@"Creating directory: %@\n", bindir];

				@try {
					[fm createDirectoryAtPath:bindir createParents:YES];

				}@catch(OFCreateDirectoryFailedException* e) {
					[of_stderr writeFormat:@"%@", e];

					[OFApplication terminateWithStatus:1];
				}
			}

			@try {
				[fm copyItemAtPath:file toPath:destination];

			} @catch (OFCopyItemFailedException* e) {
				[of_stderr writeFormat:@"%@", e];

				[OFApplication terminateWithStatus:1];
			}
		}

		[pool releaseObjects];
	}

	[pool release];

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

	if (self.rebake)
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

- (void)produceIngredientWithArguments:(OFArray OF_GENERIC(OFString*) *)arguments
{
	if (arguments.count <= 0) {
		[of_stderr writeLine:@"Empty ingredient argument!\n"];
		[OFApplication terminateWithStatus:1];
	}

	IngredientProducer* producer = [IngredientProducer new];

	for (OFString* argument in arguments) {
		[producer parseArgument:argument];
	}

	[of_stdout writeLine:[[producer ingredient] JSONRepresentation]];

	[OFApplication terminate];
}

@end
