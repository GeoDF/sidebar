#!/bin/bash
#
# dF 2025
#
# Usage: update_wiki_sidebar.sh [options] 'page1' 'page2' page3' ...'
# where 'page1' is the name of a wiki page you want to put as first level menu item
# exemple : update_wiki_sidebar.sh 'Install & run' 'Screenshots' 'FAQ'
#
# if there is no pages as parameters, read pages from ".md" files not beginning by "_" in the working directory

VALID_ARGS=$(getopt -o sc:d: --long size:,color: -- "$@")
if [[ $? -ne 0 ]]; then
	exit 1;
fi
eval set -- "$VALID_ARGS"

function isInList {
	local item="$1"
	local list="$2"
	if [[ $list =~ (^|[[:space:]])"$item"($|[[:space:]]) ]] ; then
	  result=0
	else
	  result=1
	fi
	return $result
}


while [ : ]; do
	case "$1" in
		-s | --size)
			if isInList "$2" "1 2 3"; then
				size="$2"
			fi
			shift 2
			;;
		-c | --color)
			color="$2"
			shift 2
			;;
		--) shift;
			break
			;;
	esac
done

declare -a menu
declare -a menuTitles
declare -A menuIndex
declare -A menuItems

argc=$#
argv=("$@")

# Create and return the github wikiname of a page or an anchor:
# replace ' ' by '-' and '?' by ''
function wikiname {
	if test -n "$1"; then
		md="$1"
	elif test ! -t 0; then
		md="$(</dev/stdin)"
	else
		echo "No standard input." # this should not happen
		exit 1
	fi
	echo "$md" | sed -E 's/ /-/g' | sed -E 's/\?//g'
}


for (( j=0; j<argc; j++ )); do
	menu+=("$(echo ${argv[j]} | wikiname)")
	menuTitles+=("${argv[j]}") # storing untransformed titles for display
done

len_menu="${#menu[@]}"
if [ "$len_menu" = 0 ]; then
	pick_all_files=true
else
	pick_all_files=false
	for (( i=0; i<$len_menu; i++ )); do
		menuIndex["${menu[$i]}"]="1"
	done
fi


# Read pages and find level 1 titles
for file in *; do
	if [ ! "${file##*.}" = 'md' ] || [ "${file:0:1}" = '_' ]; then
		continue
	fi
	declare -a submenus=()
	while IFS= read -r line; do
		if [ ${#line} = 0 ]; then
			continue
		fi
		if [ "${line:0:1}" = '#' ] && [ "${line:1:1}" != '#' ]; then
			line=${line:2}
			submenus+=("'$line'")
		fi
	done < $file
	page="${file%.*}"
	if [ "${menuIndex[$page]}" ]; then
		menuItems+=(["$page"]="${submenus[@]}")
	fi
	if $pick_all_files; then
		menu+=("$page")
		menuTitles+=("$(echo $page | sed -E 's/-/ /g')")
		menuItems+=(["$page"]="${submenus[@]}")
	fi
done

rm_star1='s/(^|[^\\\*])\*([^\*]+)\*([^\*]|$)/\1\2\3/g'
rm_star2='s/(^|[^\\\*])\*{2}([^\*]+)\*{2}([^\*]|$)/\1\2\3/g'
rm_star3='s/(^|[^\\\*])\*{3}([^\*]+)\*{3}([^\*]|$)/\1\2\3/g'

function removeMD {
	echo "$1" | sed -E $rm_star1 | sed -E $rm_star2 | sed -E $rm_star3
}

function submenu {
	# format an anchor in the github wiki format
	# anchor="$(removeMD $2 | tr '[:upper:]' '[:lower:]' | sed -E 's/ /-/g' | sed -E 's/\?//g')"
	anchor="$(removeMD $2 | tr '[:upper:]' '[:lower:]' | wikiname)"
	link="$1#$anchor"
	echo "- [$2]($link)"
} 

len_menu="${#menu[@]}"
if [ $len_menu > 0 ]; then
	if [ "$size" ]; then
		echo "<h$size>"
	fi
	for (( i=0; i<$len_menu; i++ )); do
		item="${menu[$i]}"
		submenus="${menuItems[$item]}"
		IFS=$'\n' subs=( $(xargs -n1 <<<"$submenus") )
		if [ "$subs" ]; then
			len_subs="${#subs[@]}"
			echo "<details><summary>[[${menuTitles[$i]}]]</summary>"
			echo ''
			for (( j=0; j<$len_subs; j++ )); do
				submenu "$item" "${subs[$j]}"
			done
			echo ''
			echo "</details>"
		else
			echo "- [[${menuTitles[$i]}]]"
		fi
	done
	if [ "$size" ]; then
		echo "</h$size>"
	fi
else
	echo "Empty wiki."
fi



