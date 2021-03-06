#!/bin/sh

if [ -z "${STAGEDIR}" -o -z "${PREFIX}" -o -z "${LOCALBASE}" ]; then
	echo "STAGEDIR, PREFIX, LOCALBASE required in environment." >&2
	exit 1
fi

[ -n "${DEBUG_MK_SCRIPTS}" -o -n "${DEBUG_MK_SCRIPTS_QA}" ] && set -x

notice() {
	echo "Notice: $@" >&2
}

warn() {
	echo "Warning: $@" >&2
}

err() {
	echo "Error: $@" >&2
}

list_stagedir_elfs() {
	cd ${STAGEDIR} && find . -type f \( -perm /111 -o -name '*.so*' \) "$@" | sort
}

shebangonefile() {
	local f interp interparg badinterp rc

	f="$@"
	rc=0

	# whitelist some files
	case "${f}" in
	*.pm | *.pod | *.txt)
		return 0
		;;
	esac

	interp=$(sed -n -e '1s/^#![[:space:]]*\([^[:space:]]*\).*/\1/p;2q' "${f}")
	badinterp=""
	case "${interp}" in
	"") ;;
	${LOCALBASE}/bin/python | ${PREFIX}/bin/python)
		badinterp="${interp}"
		;;
	${LOCALBASE}/bin/perl5.* | ${PREFIX}/bin/perl5.*)
		# perl ports are allowed to have these shebangs.
		if [ "${NAMEBASE}" != "perl-5.26" -a "${NAMEBASE}" != "perl-5.28" -a "${VARIANT}" != "526" -a "${VARIANT}" != "528" ]; then
			err "'${interp}' is an invalid shebang for '${f#${STAGEDIR}${PREFIX}/}' you must use ${LOCALBASE}/bin/perl."
			err "Either pass \${PERL} to the build or use USES=shebangfix"
			rc=1
		fi
		;;
	${LOCALBASE}/*) ;;
	${PREFIX}/*) ;;
	/bin/sh) ;;
	/bin/csh) ;;	# not in ravensys-root
	/bin/tcsh) ;;	# not in ravensys-root
	/bin/dash | /bin/bash)
		# Only valid for linux
		if [ "${OPSYS}" != "Linux" -a "${OPSYS}" != "SunOS" ]; then
			badinterp="${interp}"
		fi
		;;
	/usr/bin/awk) ;;
	/usr/bin/env)
		interparg=$(sed -n -e '1s/^#![[:space:]]*[^[:space:]]*[[:space:]]*\([^[:space:]]*\).*/\1/p;2q' "${f}")
		case "${interparg}" in
		python)
			badinterp="${interp} ${interparg}"
			;;
		esac
		;;
	/usr/bin/sed) ;;
	*)
		badinterp="${interp}"
		;;
	esac

	if [ -n "${badinterp}" ]; then
		err "'${badinterp}' is an invalid shebang you need USES=shebangfix for '${f#${STAGEDIR}${PREFIX}/}'"
		rc=1
	fi

	return ${rc}
}

shebang() {
	local f l link rc

	rc=0

	while read f; do
		# No results presents a blank line from heredoc.
		[ -z "${f}" ] && continue
		shebangonefile "${f}" || rc=1
	# Use heredoc to avoid losing rc from find|while subshell
	done <<-EOF
	$(find ${STAGEDIR}${PREFIX} \
	    -type f -perm /111 2>/dev/null)
	EOF

	# Split stat(1) result into 2 lines and read each line separately to
	# retain spaces in filenames.
	while read l; do
		# No results presents a blank line
		[ -z "${l}" ] && continue
		read link

		case "${link}" in
		/*) f="${STAGEDIR}${link}" ;;
		*) f="${l%/*}/${link}" ;;
		esac
		if [ -f "${f}" ]; then
			shebangonefile "${f}" || rc=1
		fi
	# Use heredoc to avoid losing rc from find|while subshell
	done <<-EOF
	$(find ${STAGEDIR} -type l -print0 | xargs -0 -i sh -c 'echo "{}" && readlink "{}"')
	EOF

	return ${rc}
}

symlinks() {
	local rc

	rc=0

	# Split stat(1) result into 2 lines and read each line separately to
	# retain spaces in filenames.
	while read l; do
		# No results presents a blank line from heredoc.
		[ -z "${l}" ] && continue
		read link
		case "${link}" in
			${STAGEDIR}*)
				err "Bad symlink '${l#${STAGEDIR}${PREFIX}/}' pointing inside the stage directory"
				rc=1
				;;
			/*)
				# Only warn for symlinks within the package.
				if [ -e "${STAGEDIR}${link}" ]; then
					warn "Absolute symlink '${l#${STAGEDIR}}' pointing to an absolute pathname '${link}'"
				fi
				# Also warn if the symlink exists nowhere.
				if [ ! -e "${STAGEDIR}${link}" -a ! -e "${link}" ]; then
					warn "Bad symlink '${l#${STAGEDIR}}' pointing to '${link}' which does not exist in the stage directory or in localbase"
				fi
				;;
		esac
	# Use heredoc to avoid losing rc from find|while subshell.
	done <<-EOF
	$(find ${STAGEDIR} -type l -print0 | xargs -0 -i sh -c 'echo "{}" && readlink "{}"')
	EOF

	return ${rc}
}

paths() {
	local rc

	rc=0

	while read f; do
		# No results presents a blank line from heredoc.
		[ -z "${f}" ] && continue
		# Ignore false-positive/harmless files
		case "${f}" in
			*/lib/ruby/gems/*) continue ;;
			*/share/texmf-var/web2c/*/*.fmt) continue ;;
			*/share/texmf-var/web2c/*/*.log) continue ;;
		esac
		err "'${f#${STAGEDIR}${PREFIX}/}' is referring to ${STAGEDIR}"
		rc=1
	# Use heredoc to avoid losing rc from find|while subshell
	done <<-EOF
	$(find ${TMPPLIST} ${STAGEDIR} -type f -exec grep -l "${STAGEDIR}" {} +)
	EOF

	return ${rc}
}

desktopfileutils() {
	if [ -z "${USESDESKTOPUTILS}" ]; then
		grep -q MimeType= ${STAGEDIR}${PREFIX}/share/applications/*.desktop 2>/dev/null &&
		warn "you need USES=desktop-utils:<subpackage>"
	else
		grep -q MimeType= ${STAGEDIR}${PREFIX}/share/applications/*.desktop 2>/dev/null ||
		warn "you may not need USES=desktop-utils"
	fi
	return 0
}

sharedmimeinfo() {
	local f found

	found=0
	for f in ${STAGEDIR}${PREFIX}/share/mime/packages/*.xml; do
		[ "${f}" = "${STAGEDIR}${PREFIX}/share/mime/packages/*.xml" ] && break #no matches
		[ "${f}" = "${STAGEDIR}${PREFIX}/share/mime/packages/freedesktop.org.xml" ] && continue
		found=1
		break
	done
	if [ -z "${USESMIMEINFO}" -a ${found} -eq 1 ]; then
		warn "you need USES=mime-info:<subpackage>"
	elif [ -n "${USESMIMEINFO}" -a ${found} -eq 0 ]; then
		warn "you may not need USES=mime-info"
	fi
	return 0
}

suidfiles() {
	local filelist

	filelist=`find ${STAGEDIR} -type f \
		\( -perm -u+x -or -perm -g+x -or -perm -o+x \) \
		\( -perm -u+s -or -perm -g+s \)`
	if [ -n "${filelist}" ]; then
		warn "setuid files in the stage directory (are these necessary?):"
		if [ "${OPSYS}" = "Linux" -o "${OPSYS}" = "SunOS" ]; then
		   ls -lid --time-style=long-iso ${filelist}
		else
		   ls -lidT ${filelist}
		fi
	fi
	return 0
}

libtool() {
	if [ -z "${USESLIBTOOL}" ]; then
		find ${STAGEDIR} -name '*.la' | while read f; do
			grep -q 'libtool library' "${f}" &&
				err ".la libraries found, port needs USES=libtool" &&
				return 1 || true
		done
		# The return above continues here.
	fi
}

prefixvar() {
	if [ -d ${STAGEDIR}${PREFIX}/var ]; then
		warn "port uses ${PREFIX}/var instead of /var"
	fi
}

terminfo() {
	local f found

	for f in ${STAGEDIR}${PREFIX}/share/misc/*.terminfo; do
		[ "${f}" = "${STAGEDIR}${PREFIX}/share/misc/*.terminfo" ] && break #no matches
		found=1
		break
	done
	for f in ${STAGEDIR}${PREFIX}/share/misc/terminfo.db*; do
		[ "${f}" = "${STAGEDIR}${PREFIX}/share/misc/terminfo.db*" ] && break #no matches
		found=1
		break
	done
	if [ -z "${USESTERMINFO}" -a -n "${found}" ]; then
		warn "you need USES=terminfo:<subpackage>"
	elif [ -n "${USESTERMINFO}" -a -z "${found}" ]; then
		warn "you may not need USES=terminfo"
	fi
	return 0
}

listcontains() {
	local str lst elt
	str=$1
	lst=$2

	for elt in ${lst} ; do
		if [ ${elt} = ${str} ]; then
			return 0
		fi
	done
	return 1
}

sonames() {
	[ ! -d ${STAGEDIR}${PREFIX}/lib -o -n "${BUNDLE_LIBS}" ] && return 0
	while read f; do
		# No results presents a blank line from heredoc.
		[ -z "${f}" ] && continue
		# Ignore symlinks
		[ -f "${f}" -a ! -L "${f}" ] || continue
		if ! readelf -d ${f} | grep -q SONAME; then
			warn "${f} doesn't have a SONAME."
			warn "pkg(8) will not register it as being provided by the port."
			warn "If another port depend on it, pkg will not be able to know where it comes from."
			case "${f}" in
				${STAGEDIR}${PREFIX}/lib/*/*)
					warn "It is in a subdirectory, it may not be used in another port."
					;;
				*)
					warn "It is directly in ${PREFIX}/lib, it is probably used by other ports."
					;;
			esac
		fi
	# Use heredoc to avoid losing rc from find|while subshell
	done <<-EOT
	$(find ${STAGEDIR}${PREFIX}/lib -name '*.so.*')
	EOT
}

licterms() {
	local rc comlic cl suffix licdir terms

	rc=0
	comlic="APACHE10 APACHE11 APACHE20"
	comlic="$comlic GPLv1 GPLv1+ GPLv2 GPLv2+ GPLv3 GPLv3+"
	comlic="$comlic GPLv3RLE AGPLv3 AGPLv3+ GMGPL GMGPL3"
	comlic="$comlic LGPL20 LGPL20+ LGPL21 LGPL21+ LGPL3 LGPL3+"
	licdir="${STAGEDIR}${PREFIX}/share/licenses/${NAMEBASE}"

	if [ ! -d "${licdir}" ]; then
	  notice "This ravenport is missing its license definition."
	  return 0
	fi

	for cl in ${comlic}; do
	  if [ -f "${licdir}/${cl}.${VARIANT}" ]; then
	    terms=$(ls ${licdir}/Terms.*.${VARIANT} 2>/dev/null)
	    if [ -n "${terms}" ]; then
	      case "${cl}" in
	        GPLv1|GPLv2|GPLv3|LGPL20|LGPL21|LGPL3|AGLv3)
	          grep --quiet "option) any later version" ${terms}
	          if [ $? -eq 0 ]; then
		    warn "Terms contain 'any later version' clause.  Should ${cl} license be changed to ${cl}+?"
		  fi
		  ;;
		*) ;;
	      esac
	    else
	      rc=1
	      err "${cl} license used without an accompanying Terms file"
	    fi
	  fi
	done
	return ${rc}
}

checks="shebang symlinks paths desktopfileutils sharedmimeinfo"
checks="$checks suidfiles libtool prefixvar terminfo"
checks="$checks sonames licterms"

ret=0
cd ${STAGEDIR}
for check in ${checks}; do
	${check} || ret=1
done

exit ${ret}
