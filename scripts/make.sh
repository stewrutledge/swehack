#!/bin/bash
# Generate HTML for swehack.se
# by Stefan Midjich
# One might say, 'hey Stefan, why don't you fix all those TODOs?'. 
# Why don't you fix them? I only wrote this to have a working website, 
# if I wanted others to enjoy it I would fix it up. 

# TODO: Stop using all caps in own variable names. 
DEBUG=0

function debugMsg () {
	if [[ $DEBUG -ne 0 ]]; then echo $1 >&2; fi
}

function closeFiles () {
	# Close files and restore stdout, stderr
	exec 1>&3 3>&- 4>&-
}

# Add location of markdown binary
PATH=$PATH:$HOME/bin

# TODO: Don't hardcode the markdown binary location. 
if [[ ! -x "$HOME/bin/markdown" ]]; then echo "Markdown binary not found or not executable." && exit; fi

# Default page title
DEFTITLE="Swehack.se"

# Name of src dir
SRCDIR=src

if [[ ! -d "$PWD/${SRCDIR}" ]]; then
	debugMsg "$0: ${SRCDIR}/ directory does not exist or is not directory. Verify that you are in correct current working directory."
	exit 1
fi

i=0 # Reset index counter.
for FILENAME in `find "${SRCDIR}" -name "*.md" -type f -print`; do
	# Get names of usual suspects
	_DSTFILE=`basename -s .md "${FILENAME}"`
	_DSTFILE="${_DSTFILE}.html"
	_FILEPATH=`dirname "${FILENAME}"`          
	_FILEPATH=`sed -e "s/^${SRCDIR}\(.*\)/.\1/" <<< "${_FILEPATH}"`
	DSTFILEPATH="${_FILEPATH}/${_DSTFILE}"
	TMPDSTFILEPATH=`mktemp "/tmp/swehack-${_DSTFILE}.tmpXXXX"`

	debugMsg "Finished preprocessing of ${FILENAME}"

	# Copy stdout to safe location
	exec 3>&1 4>"${TMPDSTFILEPATH}" 1>&4

	if [ ! -f "${FILENAME}" ]; then
		debugMsg "$0: ${FILENAME}: File not found"
		closeFiles
		exit 1
	else # Get pandoc headers
		debugMsg "Getting pandoc headers from ${FILENAME}"

		exec 5<"${FILENAME}"
		read -r -u 5 HDR_TITLE[$i]
		read -r -u 5 HDR_AUTHOR[$i]
		read -r -u 5 HDR_DATE[$i]
		exec 5<&-

		debugMsg "Generating meta info"

		# TODO: Think of a better way to store and retrieve pandoc headers.
		# TODO: New pandoc header with date of last update. 
		HDR_TITLE[$i]=`sed '1s/% \(.*\)/\1/' <<<"${HDR_TITLE[$i]}"`
		HDR_AUTHOR[$i]=`sed '1s/% \(.*\)/\1/' <<<"${HDR_AUTHOR[$i]}"`
		HDR_DATE[$i]=`sed '1s/% \(.*\)/\1/'<<<"${HDR_DATE[$i]}"`
	fi

	debugMsg "Writing header to ${TMPDSTFILEPATH}"

	# TODO: Header and footer should be in their own files for easier editing. 
	cat <<EOF
<!DOCTYPE html><html lang="sv">
	<head>
		<meta charset="UTF-8" />
		<title>${DEFTITLE} - ${HDR_TITLE[$i]}</title>
		<link rel="stylesheet" href="/style/style.css" type="text/css" media="screen" />
		<link rel="stylesheet" href="/style/print.css" type="text/css" media="print" />
		<link rel="icon" href="/glider-icon.png" type="image/png" />
		<script type="text/javascript" src="/js/jquery-1.7.1.js"></script>
	</head>
	<body>

	<header id="Top">
		<h1>${HDR_TITLE[$i]}</h1>
		<hgroup><h2>av ${HDR_AUTHOR[$i]}</h2></hgroup>
	</header>
EOF

	debugMsg "Writing body to ${TMPDSTFILEPATH}"

	markdown < "${FILENAME}" 2>/dev/null

	if [[ $? != 0 ]]; then
		debugMsg "$0: Failed to read file."
		closeFiles
		exit 1
	fi

	debugMsg "Writing footer to ${TMPDSTFILEPATH}"

	cat <<EOF
	<footer>
	<nav>
		<ul>
			<li><mark>sidan skrevs ${HDR_DATE[$i]}</mark></li>
			<li><a href="http://swehack.se" title="Swehack.se">Swehack.se</a></li>
			<li><a href="#Top" title="Gå till toppen av sidan">Toppen av sidan</a></li>
			<li><a href="http://validator.w3.org/check/referer" title="Validera dokumentet som HTML5">Förmodat Giltig HTML5</a></li>
			<li><a href="http://kopimi.com/kopimi/" title="Kopimist" class="noDecoration"><img src="/images/kopimist.png" alt="Kopimist" /></a>
		</ul>
	</nav>
	</footer>
	</body>
</html>
EOF

	if [[ -f "${DSTFILEPATH}" ]]; then
		diff "${TMPDSTFILEPATH}" "${DSTFILEPATH}" >/dev/null
		if [[ $? -ne 0 ]]; then
			debugMsg "Moving ${TMPDSTFILEPATH} to destination ${DSTFILEPATH}"
			mv "${TMPDSTFILEPATH}" "${DSTFILEPATH}"
			if [ $? -ne 0 ]; then debugMsg "$0: Error moving file ${TMPDSTFILEPATH} => ${DSTFILEPATH}"; fi
		else 
			debugMsg "No change to ${DSTFILEPATH}, not updating"
		fi
	else 
		mv "${TMPDSTFILEPATH}" "${DSTFILEPATH}"
	fi

	if [[ -w "${TMPFILEPATH}" ]]; then
		rm "${TMPFILEPATH}"
	fi

	i=$(($i+1))
	closeFiles
done

exit 0
