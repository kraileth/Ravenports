# Provide support fir Meson-based projects
#
# Feature:		meson
# Usage:		USES=meson
#
# Ravenadm sets meson:single:standard and
#               ninja:single:standard
#
# The following files are bundled in source tar files.
# meson.build		Instructions for meson like autoconf configure,
#			there is no changeable parts in the file.
# meson_options.txt	All the options meson understands
#
# Variables for ports:
# MESON_ARGS		Arguments passed to meson
#			format: -Denable_foo=true
# MESON_BUILD_DIR	Path to the build directory
#			Default: ${WRKSRC}/_build
# MESON_INSERT_RPATH	List path relative to WRKSRC for meson.build files that
#			require rpath adjustments, list.  e.g.
#			src/meson.build data/meson.build
#

.if !defined(_INCLUDE_USES_MESON_MK)
_INCLUDE_USES_MESON_MK=	yes

HAS_CONFIGURE=		yes
CONFIGURE_CMD=		meson
CONFIGURE_ENV+=		LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
CONFIGURE_ARGS+=	--prefix ${PREFIX} \
			--mandir share/man

MAKE_ENV+=		LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

MESON_BUILD_DIR?=	_build
BUILD_WRKSRC=		${WRKSRC}/${MESON_BUILD_DIR}
INSTALL_WRKSRC=		${WRKSRC}/${MESON_BUILD_DIR}
TEST_WRKSRC=		${WRKSRC}/${MESON_BUILD_DIR}

INSTALL_TARGET=		install	# meson has it own strip mechanic
TEST_TARGET=		test

CONFIGURE_LOG=		${MESON_BUILD_DIR}/meson-logs/meson-log.txt

.  if defined(WITH_DEBUG)
CONFIGURE_ARGS+=	--buildtype debug
.  else
CONFIGURE_ARGS+=	--buildtype release --strip
.  endif

# Add meson build dir at the end.
CONFIGURE_ARGS+=	${MESON_ARGS} ${MESON_BUILD_DIR}

# meson uses ninja
.include "${USESDIR}/ninja.mk"

.  if defined(GNU_CONFIGURE)
_USES_configure+=	250:meson_badconfig

meson_badconfig:
	@${ECHO_MSG} "===> MUST_CONFIGURE=gnu detected.  Remove this line to fix meson build"
	@${FALSE}

.  endif

.  if defined(MESON_INSERT_RPATH)
_USES_patch+=		875:meson_build_rpath

# Hardcode RPATH, must follow CURRENT_GCC in raven.information.mk
COMP_RPATH=		${PREFIX}/toolchain/gcc8/${ASLIB}:${PREFIX}/lib

meson_build_rpath:
	(cd ${WRKSRC} && ${REINPLACE_CMD} \
	-E "s|install[ ]?: true|install : true, install_rpath : '${COMP_RPATH}'|"\
	${MESON_INSERT_RPATH})

.  endif

.endif
