# Provide support to use the GNU make
#
# Feature:		gmake
# Usage:		USES=gmake
#

.if !defined(_INCLUDE_USES_GMAKE_MK)
_INCLUDE_USES_GMAKE_MK=	yes

.if !empty(gmake_ARGS)
IGNORE=	Incorrect 'USES+= gmake:${gmake_ARGS}' gmake takes no arguments
.endif

# -----------------------------------------------
# Incorporated in ravenadm
# -----------------------------------------------
# BUILD_DEPENDS+=	gmake:single:lite
# -----------------------------------------------
CONFIGURE_ENV+=		MAKE=gmake
MAKE_CMD=		gmake

.endif