#!/bin/sh

set -e

. "${dp_SCRIPTSDIR}/functions.sh"

validate_env dp_DISTDIR dp_DISTINFO_FILE dp_DISABLE_CHECKSUM dp_DISABLE_SIZE \
	dp_DIST_SUBDIR dp_ECHO_MSG dp_FETCH_CMD dp_FORCE_FETCH_ALL \
	dp_FORCE_FETCH_LIST dp_MASTER_SITE_BACKUP dp_MASTER_SITE_OVERRIDE \
	dp_MASTER_SORT_AWK dp_TARGET dp_FETCH_ENV

[ -n "${DEBUG_MK_SCRIPTS}" -o -n "${DEBUG_MK_SCRIPTS_DO_FETCH}" ] && set -x

. "${dp_SCRIPTSDIR}/sites.sh"

set -u

if [ ! -d "${dp_DISTDIR}" ]; then
	mkdir -p "${dp_DISTDIR}"
fi
cd "${dp_DISTDIR}"

for _file in "${@}"; do
	file=${_file%%:*}

	# If this files has groups
	if [ "$_file" = "$file" ]; then
		${dp_ECHO_MSG} "===> /!\\ Error /!\\"
		${dp_ECHO_MSG} "     The $file is missing the mandatory :group"
		exit 1
	else
		select=$(echo "${_file##*:}" | sed -e 's/,/ /g')
	fi

	filebasename=${file##*/}
	if [ -n "${dp_FORCE_FETCH_ALL}" ]; then
		force_fetch=true
	else
		force_fetch=false
		for afile in ${dp_FORCE_FETCH_LIST}; do
			afile=${afile##*/}
			if [ "x$afile" = "x$filebasename" ]; then
				force_fetch=true
			fi
		done
	fi
	if [ -f "${file}" -a "$force_fetch" != "true" ]; then
		continue
	fi
	full_file="${dp_DIST_SUBDIR:+${dp_DIST_SUBDIR}/}${file}"
	if [ -L "$file" ]; then
		${dp_ECHO_MSG} "=> ${dp_DISTDIR}/$file is a broken symlink."
		${dp_ECHO_MSG} "=> Perhaps a filesystem (most likely a CD) isn't mounted?"
		${dp_ECHO_MSG} "=> Please correct this problem and try again."
		exit 1
	fi
	if [ -f "${dp_DISTINFO_FILE}" -a -z "${dp_DISABLE_CHECKSUM}" ]; then
		_sha256sum=$(distinfo_data SHA256 "${full_file}")
		if [ -z "$_sha256sum" ]; then
			${dp_ECHO_MSG} "=> ${dp_DIST_SUBDIR:+$dp_DIST_SUBDIR/}$file is not in ${dp_DISTINFO_FILE}."
			${dp_ECHO_MSG} "=> Either ${dp_DISTINFO_FILE} is out of date, or"
			${dp_ECHO_MSG} "=> ${dp_DIST_SUBDIR:+$dp_DIST_SUBDIR/}$file is spelled incorrectly."
			exit 1
		fi
	fi
	case ${dp_TARGET} in
		do-fetch|makesum)
			${dp_ECHO_MSG} "=> $file doesn't seem to exist in ${dp_DISTDIR}."
			if [ ! -w "${dp_DISTDIR}" ]; then
				${dp_ECHO_MSG} "=> ${dp_DISTDIR} is not writable by you; cannot fetch."
				exit 1
			fi
			;;
	esac
	__MASTER_SITES_TMP=
	for group in $select; do
		# Disable nounset for this, it may come up empty, but
		# we don't want to fail with a strange error here.
		set +u
		eval __MASTER_SITES_TMP3="\${_DOWNLOAD_SITES_${group}}"
		set -u
		if [ -n "${__MASTER_SITES_TMP3}" ] ; then
			__MASTER_SITES_TMP4="$(process_site ${__MASTER_SITES_TMP3})"
			__MASTER_SITES_TMP="${__MASTER_SITES_TMP} ${__MASTER_SITES_TMP4}"
		else
			case ${dp_TARGET} in
				do-fetch|makesum)
					${dp_ECHO_MSG} "===> /!\\ Error /!\\"
					${dp_ECHO_MSG} "     DL_SITES_${group} group is not defined."
					${dp_ECHO_MSG} "     Check for typos, or errors."
					exit 1
					;;
			esac

		fi
	done
	__MASTER_SITES_TMP3=
	__MASTER_SITES_TMP4=
	SORTED_MASTER_SITES_CMD_TMP="echo ${dp_MASTER_SITE_OVERRIDE} $(echo -n "${__MASTER_SITES_TMP}" | awk "${dp_MASTER_SORT_AWK}") ${dp_MASTER_SITE_BACKUP}"
	case ${dp_TARGET} in
		fetch-list)
			echo -n "mkdir -p ${dp_DISTDIR} && "
			echo -n "cd ${dp_DISTDIR} && { "
			;;
	esac
	sites_remaining=0
	sites="$(${SORTED_MASTER_SITES_CMD_TMP})"
	for site in ${sites}; do
		sites_remaining=$((sites_remaining + 1))
	done
	for site in ${sites}; do
		sites_remaining=$((sites_remaining - 1))
		CKSIZE=$(distinfo_data SIZE "${full_file}")
		# There is a lot of escaping, but the " needs to survive echo/eval.
		case ${file} in
			*/*)
				mkdir -p "${file%/*}"
				args="-o ${file} ${site}${file}"
				;;
			*)
				args="${site}${file}"
				;;
		esac
		if [ -z "${dp_DISABLE_SIZE}" -a -n "${CKSIZE}" ]; then
			_fetch_cmd="${dp_FETCH_CMD} --require-size ${CKSIZE} ${args}"
		else
			_fetch_cmd="${dp_FETCH_CMD} ${args}"
		fi
		case ${dp_TARGET} in
			do-fetch|makesum)
				${dp_ECHO_MSG} "=> Attempting to fetch ${site}${file}"
				if env ${dp_FETCH_ENV} ${_fetch_cmd}; then
					actual_size=$(stat -f %z "${file}")
					if [ -n "${dp_DISABLE_SIZE}" ] || [ -z "${CKSIZE}" ] || [ "${actual_size}" -eq "${CKSIZE}" ]; then
						continue 2
					else
						${dp_ECHO_MSG} "=> Fetched file size mismatch (expected ${CKSIZE}, actual ${actual_size})"
						if [ ${sites_remaining} -gt 0 ]; then
							${dp_ECHO_MSG} "=> Trying next site"
							rm -f "${file}"
						fi
					fi
				fi
				;;
			fetch-list)
				echo -n "env $(escape "${_fetch_cmd}") || "
				;;
			fetch-url-list-int)
				echo ${args}
				;;
		esac
	done
	case ${dp_TARGET} in
		do-fetch|makesum)
			${dp_ECHO_MSG} "=> Couldn't fetch it - please try to retrieve this"
			${dp_ECHO_MSG} "=> port manually into ${dp_DISTDIR} and try again."
			exit 1
			;;
		fetch-list)
			echo "echo \"${file}\" not fetched; }"
			;;
	esac
done

