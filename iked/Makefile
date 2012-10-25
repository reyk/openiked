# $OpenBSD: Makefile,v 1.7 2012/09/25 21:50:41 brad Exp $

COMPAT_DIR=	${.CURDIR}/../openbsd-compat
BINDIR=		/opt/local/sbin
MANDIR=		/opt/local/share/man

PROG=		iked
SRCS=		ca.c chap_ms.c config.c control.c crypto.c dh.c \
		eap.c iked.c ikev1.c ikev2.c ikev2_msg.c ikev2_pld.c \
		log.c pfkey.c policy.c proc.c timer.c util.c imsg_util.c
SRCS+=		${.OBJDIR}/eap_map.c ${.OBJDIR}/ikev2_map.c
SRCS+=		${COMPAT_DIR}/imsg.c ${COMPAT_DIR}/imsg-buffer.c
SRCS+=		${COMPAT_DIR}/strtonum.c
SRCS+=		${COMPAT_DIR}/setproctitle.c
SRCS+=		parse.y
MAN=		iked.conf.5 iked.8
#NOMAN=		yes

LDADD=		-lutil -levent -lcrypto
DPADD=		${LIBUTIL} ${LIBEVENT} ${LIBCRYPTO}
CFLAGS+=	-Wall -D_GNU_SOURCE
CFLAGS+=	-include ${COMPAT_DIR}/compat.h
CFLAGS+=	-I${.CURDIR} -I${.CURDIR}/.. -I${COMPAT_DIR}
CFLAGS+=	-I/opt/local/include -I/opt/local/include/libevent1
CFLAGS+=	-Wstrict-prototypes -Wmissing-prototypes
CFLAGS+=	-Wmissing-declarations
CFLAGS+=	-Wshadow -Wpointer-arith -Wcast-qual
CFLAGS+=	-Wsign-compare
LDADD+=		-L/opt/local/lib -L/opt/local/lib/libevent1
CLEANFILES+=	y.tab.h ikev2_map.c eap_map.c
CLEANFILES+=	iked.conf.cat5 iked.cat8 parse.c
GENERATED=	ikev2_map.c eap_map.c

ikev2_map.c: genmap.sh ikev2.h
	/bin/sh ${.CURDIR}/genmap.sh ${.CURDIR}/ikev2.h ikev2 > $@
	@touch $@

eap_map.c: genmap.sh eap.h
	/bin/sh ${.CURDIR}/genmap.sh ${.CURDIR}/eap.h eap > $@
	@touch $@

${PROG} beforedepend: ${GENERATED}

.include <bsd.prog.mk>
