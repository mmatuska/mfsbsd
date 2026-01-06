PROG=	roothack
MAN=

# XXX: this Makefile does a fair bit of unnecessary overlinking, but seeing as
# this binary is compiled with -static, this is less of a problem than it
# appears at first blush.
#
# - Specifying `-lpthread` explicitly should not be required by downstream
#   consumers, but it is currently on 15.0-RELEASE (EN worthy if not specific
#   to the static lib implementation).
# - Something appears to be linking both libcrypto and libmd on 15.0-RELEASE
#   in this dependency chain (lzma possibly) instead of just a single crypto
#   implementation.
LDADD=	-larchive -lbz2 -lz -llzma -lcrypto -lbsdxml -lmd -lprivatezstd -lpthread

NO_SHARED=

WARNS=	6

.include <bsd.prog.mk>
