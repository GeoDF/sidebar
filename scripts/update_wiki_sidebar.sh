#!/bin/bash
#
# dF 2025
#
# Usage: update_wiki_sidebar.sh [options] 'page1' 'page2' page3' ...'
# where 'page1' is the name of a wiki page you want to put as first level menu item
# exemple : update_wiki_sidebar.sh [options] 'Install & run' 'Screenshots' 'FAQ'
#
# if there is no pages as parameters, read pages from a hidden file saved by the first run
# or from ".md" files not beginning by "_" in the working directory if the hidden file _last_menu_pages 
# was not created before

VALID_ARGS=$(getopt -o t:f:o:s:d: --long title:,footer:,opened:,size: -- "$@")
if [[ $? -ne 0 ]]; then
	exit 1;
fi
eval set -- "$VALID_ARGS"

# Test if value is in list
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

# Create and return the github wikiname of a page or an anchor:
# replace ' ' by '-' and '?' by ''
function wikiname {
	echo "$(</dev/stdin)" | sed -E 's/ /-/g' | sed -E 's/\?//g'
}

# Read args
while [ : ]; do
	case "$1" in
		-t | --title)
			title="$2"
			shift 2
			;;
		-f | --footer)
			footer="$2"
			shift 2
			;;
		-o | --opened)
			opened="$2"
			shift 2
			;;
		-s | --size)
			if isInList "$2" '1 2 3 4 5'; then
				size="$2"
			fi
			shift 2
			;;
		--) shift;
			argc=$#
			argv=("$@")
			for (( j=0; j<argc; j++ )); do
				menuTitles+=("${argv[j]}") # storing untransformed titles for display
			done
			break
			;;
	esac
done

declare -a menu
declare -a menuTitles # desired menu titles, untransformed
declare -A menuOptions
declare -A menuIndex
declare -A menuItems

len_menuTitles="${#menuTitles[@]}"
if [ "$len_menuTitles" = 0 ]; then
	if [ -f '_last_menu_pages' ]; then
		readarray -t menuTitles < _last_menu_pages
	else
		# Read all pages
		for file in *; do
			if [ ! "${file##*.}" = 'md' ] || [ "${file:0:1}" = '_' ] ; then
				continue
			fi
			menuTitles+=("$(echo ${file%.*} | sed -e 's/-/ /g')")
		done
	fi
fi

# Save the 1st level pages names and global options (TODO) in a hidden file
printf "%s\n" "${menuTitles[@]}" > '_last_menu_pages'

OPTIONS_REGEX='\|_([^_][^|]+)_\|'
# Create menu index and extract options
len_menuTitles="${#menuTitles[@]}"
for (( i=0; i<$len_menuTitles; i++ )); do
	if [[ ${menuTitles[$i]} =~ $OPTIONS_REGEX ]]; then
		m_title="${menuTitles[$i]%%|_*}"
		page=$(echo "$m_title" | wikiname)
		menuOptions["$page"]="|_${menuTitles[$i]#*|_}" # store all menu options
		menuTitles[$i]="$m_title"
	fi
	page="$(echo ${menuTitles[$i]} | wikiname)"
	menuIndex["$page"]="true"
	menu+=("$page")
done

# Read requested pages and find level 1 titles
for file in *; do
	if [ ! "${file##*.}" = 'md' ] || [ "${file:0:1}" = '_' ] ; then
		continue
	fi
	page="${file%.*}"
	if [ ! "${menuIndex[$page]}" ]; then
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
	menuItems+=(["$page"]="${submenus[@]}")
done

rm_star1='s/(^|[^\\\*])\*([^\*]+)\*([^\*]|$)/\1\2\3/g'
rm_star2='s/(^|[^\\\*])\*{2}([^\*]+)\*{2}([^\*]|$)/\1\2\3/g'
rm_star3='s/(^|[^\\\*])\*{3}([^\*]+)\*{3}([^\*]|$)/\1\2\3/g'
rm_underscore1='s/(^|[^\\_])_([^_]+)_([^_]|$)/\1\2\3/g'
rm_underscore2='s/(^|[^\\_])_{2}([^\_]+)_{2}([^_]|$)/\1\2\3/g'
rm_underscore3='s/(^|[^\\_])_{3}([^_]+)_{3}([^_]|$)/\1\2\3/g'

# Remove some markdown
function removeMD {
	echo "$1" | \
		sed -E $rm_star1 | \
		sed -E $rm_star2 | \
		sed -E $rm_star3 | \
		sed -E $rm_underscore1 | \
		sed -E $rm_underscore2 | \
		sed -E $rm_underscore3
}

FORMAT_MENU='<details%s><summary>[[%s]]</summary>\n\n%s\n\n</details>\n'
FORMAT_SUBMENU='- %s\n'
function draw_menu {
	printf $FORMAT_MENU "$3" "$1" "$2"
}
function draw_submenu {
	# format an anchor in the github wiki format
	anchor="$(removeMD $2 | tr '[:upper:]' '[:lower:]' | wikiname)"
	link="$1#$anchor"
	printf -- $FORMAT_SUBMENU "[$2]($link)"
} 

# Write menu
echo "$(
	[ "$title" ] && echo "$title"
	len_menu="${#menu[@]}"
	if [ $len_menu -gt 0 ]; then
		[ "$size" ] && echo "<h$size>"
		for (( i=0; i<$len_menu; i++ )); do
			# defaults options for this menu item
			[ "$opened" ] && open=' open' || open=''
	
			item="${menu[$i]}"
			# Process options
			if [ "${menuOptions[$item]}" ]; then
				declare -A options=()
				options_string="${menuOptions[$item]}"
				while [[ $options_string =~ $OPTIONS_REGEX ]]; do
					opt="${BASH_REMATCH[1]}"
					options["${opt%=*}"]="${opt#*=}"
					options_string="${options_string##*${opt}_|}"
				done
				for option_name in ${!options[@]}; do
					value="${options[$option_name]}"
					case $option_name in
						'open')
							open=' open'
						;;
						'close')
							open=''
						;;
					esac
				done
			fi
			# Process submenus
			IFS=$'\n' subs=( $(xargs -n1 <<<"${menuItems[$item]}") )
			if [ "$subs" ]; then
				len_subs="${#subs[@]}"
				submenus=$(
					for (( j=0; j<$len_subs; j++ )); do
						draw_submenu "$item" "${subs[$j]}"
					done
				)
				draw_menu "${menuTitles[$i]}" "$submenus" "$open"
			else
				echo "- [[${menuTitles[$i]}]]"
			fi
		done
		[ "$size" ] && echo "</h$size>"
	else
		echo "Empty wiki"
	fi
	[ "$footer" ] && echo "$footer"
)" > _Sidebar.md

