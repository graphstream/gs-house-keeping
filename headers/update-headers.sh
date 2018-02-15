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
# @since 2018
# @author Yoann Pigné <yoann.pigne@graphsteam-project.org>
#
##################################################################################
#
# Utility script for updating License headers in java files. 
# Optionnaly also add a list of @author tags and a @since tag based on git data.
#
##################################################################################


function checkOrExit {
	if [ "$1" -ne "0" ]; then
		echo $2
		exit $1
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

# Constants
HEADER=$(cat Header.java)
tempfoo=`basename $0`

# parameters
PROJECT_ROOT_PATH="$1"
GIT="git --git-dir=$PROJECT_ROOT_PATH/.git -C $PROJECT_ROOT_PATH --no-pager"

FILE_LIST=`mktemp` || exit 1
checkOrExit $? "Failed to create temp file"
trap "rm -rf $FILE_LIST" EXIT

TMP_NEW_FILE=`mktemp` || exit 1
checkOrExit $? "Failed to create temp file"
trap "rm -rf $TMP_NEW_FILE" EXIT

AUTHORS_TMP_FILE=`mktemp` || exit 1
checkOrExit $? "Failed to create temp file"
trap "rm -rf $AUTHORS_TMP_FILE" EXIT

if [ -z "$PROJECT_ROOT_PATH" ]; then
	echo "Usage : $0 project-root-path "
	echo "ERROR: no project root path provided"
	exit 1
fi

$GIT status 2&> /dev/null
checkOrExit $? "'$PROJECT_ROOT_PATH' Not a git repository."

find $PROJECT_ROOT_PATH -iname "*.java"  > $FILE_LIST
NB_LINES=`cat $FILE_LIST | wc -l` 


if askYN "Also create @author and @since tags?" ; then 
    TAGS="OK"
fi
echo "tags: $TAGS"
if askYN "You are about to Overwite $NB_LINES java files. Ready to proceed ?" ; then 
    for file in `cat $FILE_LIST`; do 
        echo "Working on file: $file"
        
        # New License headers
        echo "$HEADER" > $TMP_NEW_FILE
        if [ $TAGS ]; then 
            # List Authors based on git
            # sorted based on age of first commit 
            # as per javadoc gidelines : http://www.oracle.com/technetwork/articles/java/index-137868.html
            AUTHORS=$($GIT log --no-merges --format="format:%aN <%aE>"  --reverse -- $file)

            declare -A Aseen
            Aunique=()
            while read -r w; do
                token=$(echo $w | cut -d ' ' -f 1)
                [[ ${Aseen[$w]} ]] && continue
                Aunique+=( "$w" )
                Aseen[$w]=x
            done <<< "$AUTHORS"
            Aseen=()
            
            echo "" > $AUTHORS_TMP_FILE
            echo "/**" >> $AUTHORS_TMP_FILE
            SINCE=$($GIT log --follow --format=%ai -- $file | tail -1 | cut -d ' ' -f 1)
            echo " * @since $SINCE" >> $AUTHORS_TMP_FILE
            echo " * " >> $AUTHORS_TMP_FILE
            
            for AUTHOR in "${Aunique[@]}"; do
                echo " * @author $AUTHOR" >> $AUTHORS_TMP_FILE
                echo " * @author $AUTHOR"
            done
            echo " */" >> $AUTHORS_TMP_FILE
            
            cat $AUTHORS_TMP_FILE >> $TMP_NEW_FILE
        fi

        # Remove old header from file
        perl -0777 -i -pe 's/\/\*\s*\n(?:\s\*\s.*\n)*\s\*\/\s*\n//g' $file
        
        # Add rest of the file
        cat $file >> $TMP_NEW_FILE
        
        # overwrite
        cat $TMP_NEW_FILE > $file
    done
    
fi

