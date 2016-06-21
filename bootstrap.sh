#!/bin/sh
echo "Looking for ObjFW..."
TRIPLE="$(gcc -dumpmachine)"
OBJFW_COMPILE="$TRIPLE-objfw-compile"
if ! which $OBJFW_COMPILE >/dev/null 2>&1; then
	echo
	echo "ERROR: You need ObjFW in order to boostrap bake!"
	echo "       Get it from https://webkeks.org/objfw/ and install it!"
	exit 1
fi
echo "Found objfw-compile!"

echo
echo "Bootstrapping bake using objfw-compile:"
$OBJFW_COMPILE -Wall -Werror -g -Isrc -Isrc/exceptions -o bootstrap_bake \
	src/*.m src/exceptions/*.m || exit 1
rm src/*.o src/exceptions/*.o

echo
echo "Generating ingredient file for ObjFW..."
OBJFW_CONFIG="$TRIPLE-objfw-config"
mkdir -p ingredients
./bootstrap_bake --produce-ingredient \
	`$OBJFW_CONFIG --cppflags --objcflags --libs` \
	>ingredients/objfw.ingredient || exit 1
echo "Successfully generated!"

echo
echo "bake was successfully bootstrapped!"
echo "You can now:"
echo "* change the prefix using ./bootstrap_bake --set prefix=/some/path"
echo "* build bake using ./bootstrap_bake"
echo "* install bake using ./pastries/bake/bake --install"
