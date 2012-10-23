# $OpenBSD: Makefile,v 1.1 2010/06/03 16:41:12 reyk Exp $

IKEDDIR=	${.CURDIR}/../iked
COMPAT_DIR=	${.CURDIR}/../openbsd-compat
SSLDIR=		/opt/local/etc/openssl
BINDIR=		/opt/local/sbin
MANDIR=		/opt/local/share/man

.PATH:		${IKEDDIR}

PROG=		ikectl
SRCS=		log.c ikeca.c ikectl.c parser.c
SRCS+=		${COMPAT_DIR}/imsg.c ${COMPAT_DIR}/imsg-buffer.c
SRCS+=		${COMPAT_DIR}/strtonum.c

MAN=		ikectl.8

LDADD=		-lutil -lcrypto
DPADD=		${LIBUTIL}
CFLAGS+=	-Wall -D_GNU_SOURCE
CFLAGS+=	-include ${COMPAT_DIR}/compat.h
CFLAGS+=	-I${.CURDIR} -I${COMPAT_DIR} -I${IKEDDIR}
CFLAGS+=	-I/opt/local/include -I/opt/local/include/libevent1
CFLAGS+=	-DPATH_OPENSSL='"/opt/local/bin/openssl"'
CFLAGS+=	-DPATH_ZIP='"/usr/bin/zip"'
CFLAGS+=	-DPATH_TAR='"/usr/bin/tar"'
CFLAGS+=	-DPREFIX='"/opt/local"'
CFLAGS+=	-DSSLDIR='"${SSLDIR}"'
CFLAGS+=	-Wstrict-prototypes -Wmissing-prototypes
CFLAGS+=	-Wmissing-declarations
CFLAGS+=	-Wshadow -Wpointer-arith -Wcast-qual
CFLAGS+=	-Wsign-compare
CLEANFILES+=	ikectl.cat8

distribution:
	${INSTALL} -C -g wheel -m 0644 ${.CURDIR}/ikeca.cnf \
	    ${DESTDIR}${SSLDIR}/ikeca.cnf

.include <bsd.prog.mk>
