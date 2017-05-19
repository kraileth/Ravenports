# Handle dependency on PERL 5.x
#
# Feature:     perl-interp
# Usage:       USES=perl-interp
# Valid ARGS:  none
#
# Internal ravenadm makefile may preset this variable:
# PERL5_DEFAULT
#
# The makefile sets the following variables:
# PERL_VERSION   - Full version of perl5
# PERL_VER       - Short version of perl5 (major.minor without patchlevel)
# SITE_PERL      - Absolute path to directory where site-specific perl
#                  packages go.  Added to PLIST_SUB as SITE_PERL_REL
# SITE_PERL_REL  - Same as SITE_PERL, but relative to LOCALBASE
# SITE_ARCH      - Absolute path to directory where arch-specific perl
#                  packages go.  Added to PLIST_SUB as SITE_ARCH_REL
# SITE_ARCH_REL  - Same as SITE_ARCH, but relative to LOCALBASE
# SITE_MAN1      - Absolute path to site-specific man1 pages
#                  Added to PLIST_SUB as SITE_MAN1_REL
# SITE_MAN1_REL  - Same as SITE_MAN1, but relative to LOCALBASE
# SITE_MAN3      - Absolute path to site-specific man3 pages
#                  Added to PLIST_SUB as SITE_MAN3_REL
# SITE_MAN3_REL  - Same as SITE_MAN3, but relative to LOCALBASE
# PERL_ARCH      - Directory name of architecture dependent libraries
# SITE_PERL      - Directory name where site specific perl packages go.
#                  This value is added to PLIST_SUB.
# IAMDEFAULTPERL - Defined if this interpret is the default one
#

.if !defined(_INCLUDE_USES_PERL_INTERP_MK)
_INCLUDE_USES_PERL_INTERP_MK=	yes

PERL_VERSION=	${VERSION}
PERL_VER=	${PERL_VERSION:C/\.[0-9]+$//}
PERL_ARCH=	mach

SITE_PERL_REL=	lib/perl5/site_perl
SITE_PERL=	${LOCALBASE}/${SITE_PERL_REL}
SITE_ARCH_REL=	${SITE_PERL_REL}/${PERL_ARCH}/${PERL_VER}
SITE_ARCH=	${LOCALBASE}/${SITE_ARCH_REL}
SITE_MAN1_REL=	${SITE_PERL_REL}/man/man1
SITE_MAN1=	${PREFIX}/${SITE_MAN1_REL}
SITE_MAN3_REL=	${SITE_PERL_REL}/man/man3
SITE_MAN3=	${PREFIX}/${SITE_MAN3_REL}
_PRIV_LIB=      lib/perl5/${PERL_VER}
_ARCH_LIB=      ${_PRIV_LIB}/${PERL_ARCH}
PMANPREFIX_REL=	${_PRIV_LIB}/perl
PMANPREFIX=	${PREFIX}/${PMANPREFIX_REL}

MANDIRS+=	${PMANPREFIX}/man

PLIST_SUB+=	PERL_VERSION=${PERL_VERSION} \
		PERL_VER=${PERL_VER} \
		PERL_ARCH=${PERL_ARCH} \
		MAN1=${PMANPREFIX_REL}/man/man1 \
		MAN3=${PMANPREFIX_REL}/man/man3 \
		PERLMANPREFIX=${PMANPREFIX_REL} \
		SITEMANPREFIX=${SITE_PERL_REL} \
		SITE_PERL=${SITE_PERL_REL} \
		SITE_ARCH=${SITE_ARCH_REL} \
		PRIV_LIB=${_PRIV_LIB} \
		PKGNAMESUFFIX=${PKGNAMESUFFIX} \
		ARCH_LIB=${_ARCH_LIB}

SUB_FILES=	perl-man.conf

SUB_LIST+=	PERL_VERSION=${PERL_VERSION} \
		PERL_VER=${PERL_VER} \
		SITE_PERL=${SITE_PERL_REL} \
		PRIV_LIB=${_PRIV_LIB} \
		PERLMANPREFIX=${PMANPREFIX_REL} \
		SITEMANPREFIX=${SITE_PERL_REL} \
		PERL_ARCH=${PERL_ARCH}

INSTALL_TARGET=		install-strip
CONFIGURE_ARGS+=	-sde -Dprefix=${PREFIX} \
			-Dlibperl=libperl.so.${PERL_VERSION} \
			-Darchlib=${PREFIX}/${_ARCH_LIB} \
			-Dprivlib=${PREFIX}/${_PRIV_LIB} \
			-Dman3dir=${PREFIX}/${PMANPREFIX_REL}/man/man3 \
			-Dman1dir=${PREFIX}/${PMANPREFIX_REL}/man/man1 \
			-Dsitearch=${SITE_ARCH} \
			-Dsitelib=${SITE_PERL} \
			-Dscriptdir=${PREFIX}/bin \
			-Dsiteman3dir=${SITE_MAN3} \
			-Dsiteman1dir=${SITE_MAN1} \
			-Ui_malloc -Ui_iconv -Uinstallusrbinperl -Dusenm=n \
			-Dcc="${CC}" -Duseshrplib -Dinc_version_list=none \
			#end

# Keep the following two in sync.
# lddlflags is used for all .so linking.  shrpldflags is used for libperl.so,
# so remove all the extra bits inherited from lddlflags.

CONFIGURE_ARGS+=	-Alddlflags='-L${WRKSRC} -L${PREFIX}/${_ARCH_LIB}/CORE -lperl' \
			-Dshrpldflags='$$(LDDLFLAGS:N-L${WRKSRC}:N-L${PREFIX}/${_ARCH_LIB}/CORE:N-lperl) -Wl,-soname,$$(LIBPERL:R)'

# if this port is default due PERL5_DEFAULT
# change PKGNAME to reflect this

.  if ${PERL_VER} == ${PERL5_DEFAULT}
PKGNAMESUFFIX=		5
IAMDEFAULTPERL=		yes
PLIST_SUB+=		DEFAULT="" BINSUFFIX=""
.  else
PKGNAMESUFFIX=		${PERL_VER}
BINSUFFIX=		${PERL_VERSION}
PLIST_SUB+=		DEFAULT="@comment " BINSUFFIX=${PERL_VERSION}
CONFIGURE_ARGS+=	-Dversiononly
.  endif

# http://perl5.git.perl.org/perl.git/commit/b83080de5c4254
# PERLIOBUF_DEFAULT_BUFSIZ size in bytes (default: 8192 bytes)

.  if defined(PERLIOBUF_DEFAULT_BUFSIZ)
CONFIGURE_ARGS+=	-Accflags=-DPERLIOBUF_DEFAULT_BUFSIZ=${PERLIOBUF_DEFAULT_BUFSIZ}
.  endif

# --------------------------------------------------------------------------
# --  standard post targets
# --------------------------------------------------------------------------

_TC=	${LOCALBASE}/toolchain

.  if !target(post-patch)
post-patch:
	${REINPLACE_CMD} -e 's|/usr/local|${LOCALBASE}|g' \
		-e 's/objformat=.*//' \
		${WRKSRC}/Configure \
		${WRKSRC}/hints/${OPSYS:tl:S/sunos/solaris_2/}.sh
.    if !defined(IAMDEFAULTPERL)
	${REINPLACE_CMD} -e '/do_installprivlib = 0 if .versiononly/d; \
		/^if.*nopods.*versiononly || /s/.*/if (1) {/' \
		${WRKSRC}/installperl
.    endif
.  endif

.  if !target(post-extract)
post-extract:
	# Put a symlink to the future libperl.so.x.yy so that -lperl works.
	${LN} -s libperl.so.${PERL_VERSION} ${WRKSRC}/libperl.so
	${LN} -s libperl.so.${PERL_VERSION} ${WRKSRC}/libperl.so.${PERL_VER}
.  endif

.  if !target(post-build)
post-build:
	@${SED} -i'' -e '/^lddlflags/s|-L${WRKSRC} ||' \
		${WRKSRC}/lib/Config_heavy.pl
.  endif

.  if !target(post-install)
post-install:
	${MKDIR} ${STAGEDIR}${SITE_MAN1}
	${MKDIR} ${STAGEDIR}${SITE_MAN3}
	${MKDIR} ${STAGEDIR}${SITE_ARCH}/auto
	${MKDIR} ${STAGEDIR}${SITE_PERL}/auto
.    if defined (IAMDEFAULTPERL)
	${LN} ${STAGEDIR}${PREFIX}/bin/perl${PERL_VERSION} \
		${STAGEDIR}${PREFIX}/bin/perl5
.    endif
	${LN} -sf libperl.so.${PERL_VERSION} \
		${STAGEDIR}${PREFIX}/${_ARCH_LIB}/CORE/libperl.so
	${LN} -sf libperl.so.${PERL_VERSION} \
		${STAGEDIR}${PREFIX}/${_ARCH_LIB}/CORE/libperl.so.${PERL_VER}
	${STRIP_CMD} ${STAGEDIR}${PREFIX}/bin/perl${PERL_VERSION}
	${MKDIR} ${STAGEDIR}${SITE_ARCH}/machine
	${MKDIR} ${STAGEDIR}${SITE_ARCH}/sys

	# h2ph needs perl, but perl is not installed, it's only
	# staged, so, use the one in WRKDIR
	(cd /usr/include && ${SETENV} LD_LIBRARY_PATH=${WRKSRC} \
		${WRKSRC}/perl -I ${WRKSRC}/lib ${STAGEDIR}${PREFIX}/bin/h2ph${BINSUFFIX} \
		-d ${STAGEDIR}${SITE_ARCH} *.h machine/*.h sys/*.h >/dev/null)
	${FIND} ${STAGEDIR}${SITE_ARCH} -name '*.ph' | \
		sed -e 's|${STAGEDIR}${PREFIX}/||' \
		>> ${WRKDIR}/.manifest.primary.mktmp
	${FIND} ${STAGEDIR} -name '*.so*' -type f | while read f; \
		do \
			${CHMOD} 644 $$f; \
			${STRIP_CMD} $$f; \
			${CHMOD} 444 $$f; \
		done
	${MKDIR} ${STAGEDIR}${PREFIX}/etc/man.d
	${INSTALL_DATA} ${WRKDIR}/perl-man.conf \
		${STAGEDIR}${PREFIX}/etc/man.d/perl${PKGNAMESUFFIX}.conf
.  endif

.endif	# defined(_INCLUDE_USES_PERL_INTERP_MK)
