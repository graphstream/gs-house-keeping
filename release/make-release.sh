#!/usr/bin/env bash

##################################################################################
#
# This file is part of GraphStream <http://graphstream-project.org>.
# 
# GraphStream is a library whose purpose is to handle static or dynamic
# graph, create them from scratch, file or any source and display them.
# 
# This program is free software distributed under the terms of two licenses, the
# CeCILL-C license that fits European law, and the GNU Lesser General Public
# License. You can  use, modify and/ or redistribute the software under the terms
# of the CeCILL-C license as circulated by CEA, CNRS and INRIA at the following
# URL <http://www.cecill.info> or under the terms of the GNU LGPL as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 
# The fact that you are presently reading this means that you have had
# knowledge of the CeCILL-C and LGPL licenses and that you accept their terms.
#
##################################################################################
#
# @author Guilhelm Savin <guilhelm.savin@graphstream-project.org>
# @author Yoann Pigné <yoann.pigne@graphsteam-project.org>
#
##################################################################################
#
# Utility script to help with the production of graphstream releases.
#
##################################################################################

function checkOrExit {
	if [ "$1" -ne "0" ]; then
		echo $2
		exit $1
	fi
}

function checkFileExists {
	if [ -e "$1" ]; then
		echo -n "\"$1\" already exists, continue [y/N] ? "
		read R
		case $R in
		[yY]) 	echo "\"$1\" will be overwritten"	;;
		*)		exit 1 								;;
		esac
	fi
}

function askYN {
	echo -n "$1 [y/N] "
	read R
	case $R in
	[yY])	return 0 ;;
	*)		return 1 ;;
	esac
}

GITHUB="git@github.com:graphstream/"
MODULE="$1"
IDENTITY="GraphStream Team <team@graphstream-project.org>"

EDITOR="nano"
MVN="mvn -q"
GIT="git"

if [ -z "$MODULE" ]; then
	echo "Usage : $0 module version [release_message]"
	echo "ERROR: no module specified"
	exit 1
fi

URL="$GITHUB$MODULE.git"
VERSION="$2"
TAG_MSG="$3"
LOGFILE="$PWD/$MODULE-$VERSION.log"

NO_DEPS="on"

if [ -z "$VERSION" ]; then
	echo "Usage : $0 module version [release_message]"
	echo "ERROR: no version specified"
	exit 1
fi

if [ -z "$TAG_MSG" ]; then
	TAG_MSG="Release $VERSION"
fi

BUILD_DIR="$MODULE-$VERSION"

#
# BUNDLE is the release made to be submitted to Sonatype, so it is done for
# maven and does not include deps.
#
BUNDLE="$MODULE-$VERSION-bundle.jar"
checkFileExists $BUNDLE

#
# ARCHIVE aims to be distributed out of maven, so it includes deps other than
# GraphStream.
#
ARCHIVE="$MODULE-$VERSION.zip"
checkFileExists $ARCHIVE

function checkScalaDocs {
	if [ "$SCALA" = "on" ]; then
		echo "Creating scala docs..."
		
		$MVN scala:doc
		checkOrExit $? "Failed to create scala docs"
		
		pushd target
		pushd site/scaladocs
		
		jar cf ../../$MODULE-$VERSION-javadoc.jar *
		checkOrExit $? "Failed to create javadoc archive for scaladocs"
		
		popd
		
		gpg -u "$IDENTITY" -ba $MODULE-$VERSION-javadoc.jar 
		checkOrExit $? "Failed to sign javadoc archive for scaladocs"
		
		popd
	fi
}

#
# Step 1 : get the code
#
if [ -e "$BUILD_DIR" ]; then
	if askYN "\"$BUILD_DIR\" already exists, delete it ?"; then
		echo "Delete existing $BUILD_DIR"
		rm -fr $BUILD_DIR
		$GIT clone $URL $BUILD_DIR
		checkOrExit $? "Failed to clone remote git repository"
	else
		echo "using existing $BUILD_DIR"
	fi
else
	$GIT clone $URL $BUILD_DIR
	checkOrExit $? "Failed to clone remote git repository"
fi

pushd $BUILD_DIR

#
# Check if there is scala code.
#
if [ `find . -iname "*.scala" | wc -l` -gt 0 ]; then
	SCALA="on"
else
	SCALA="off"
fi

echo "[INFO] Scala is $SCALA"

#
# Step 2 : make or check the tag
#
if [ `$GIT tag -l | egrep "^$VERSION\$" | wc -l` -gt 0 ]; then
	echo "Tag \"$VERSION\" already exists"
	
	if askYN "Use it ? "; then
		$GIT checkout $VERSION
		checkOrExit $? "Failed to checkout $VERSION"
	else
	# Remove tag :
	#  git tag -d ”tag name”
	#  git push origin :refs/tags/”tag name”
		echo "Exit"
		exit 1
	fi
else
	$GIT tag -s -u "$IDENTITY" -m "$TAG_MSG" $VERSION
	checkOrExit $? "Failed to tag the repository"

	$GIT push --tags
	checkOrExit $? "Failed to push tag to origin"
fi

#
# Step 3 : edit pom.xml
# We need to define the version of this module and the version of deps.
#
cp pom.xml .pom.xml.backup
echo "Now, you have to edit pom.xml to set project and deps versions."
echo "<<< Press any key when ready >>>"
read

$EDITOR pom.xml
checkOrExit $? "Failed to edit pom.xml"

diff .pom.xml.backup pom.xml

if askYN "Here is difference, are you ok with that ?"; then
	rm .pom.xml.backup
else
	mv .pom.xml.backup pom.xml
	exit 1
fi

#
# Step 4 : create bundle
#
$MVN source:jar javadoc:jar package -P release
checkOrExit $? "Failed to create Maven packages (release)"

checkScalaDocs

pushd target

jar cf $BUNDLE 									\
	$MODULE-$VERSION.jar 			$MODULE-$VERSION.jar.asc 	\
	$MODULE-$VERSION-sources.jar 	$MODULE-$VERSION-sources.jar.asc 	\
	$MODULE-$VERSION-javadoc.jar 	$MODULE-$VERSION-javadoc.jar.asc 	\
	$MODULE-$VERSION.pom 			$MODULE-$VERSION.pom.asc

mv $BUNDLE ../..

#
# Step 5 : create archive
#
if [ "$NO_DEPS" = "on" ]; then
	popd

	$MVN source:jar javadoc:jar package -P release,nodeps
	checkOrExit $? "Failed to create Maven packages (release,nodeps)"

	checkScalaDocs

	pushd target
fi

mkdir $MODULE-$VERSION
mv $MODULE-$VERSION.jar 			$MODULE-$VERSION.jar.asc 	\
	$MODULE-$VERSION-sources.jar 	$MODULE-$VERSION-sources.jar.asc 	\
	$MODULE-$VERSION-javadoc.jar 	$MODULE-$VERSION-javadoc.jar.asc 	\
	$MODULE-$VERSION.pom 			$MODULE-$VERSION.pom.asc 	\
	$MODULE-$VERSION/

zip $ARCHIVE $MODULE-$VERSION/*
checkOrExit $? "Failed to create zip \"$MODULE-$VERSION.zip\""

mv $MODULE-$VERSION.zip ../..

popd
popd

if askYN "Delete build dir ?"; then
	rm -rf $MODULE-$VERSION
fi

