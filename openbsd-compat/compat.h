/*
 * Copyright (c) 2012 Reyk Floeter <reyk@openbsd.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef _OPENBSD_COMPAT_H
#define _OPENBSD_COMPAT_H

/*
 * XXX this is hardcoded for OSX/Darwin and will be replaced
 * XXX by (awful) autoconf stuff later.
 */

#define IKED_USER	"_unknown"
#define IKED_PREFIX	"/opt/local"
#define IKED_CONFIG	IKED_PREFIX "/etc/iked.conf"
#define IKED_CA		IKED_PREFIX "/etc/iked/"

#if !defined(__packed)
#define __packed __attribute__((packed))
#endif

/* Apple misses sys/endian.h */
#include <libkern/OSByteOrder.h>
#define betoh16				OSSwapBigToHostInt16
#define betoh32				OSSwapBigToHostInt32
#define betoh64				OSSwapBigToHostInt64
#define htobe16				OSSwapHostToBigInt16
#define htobe32				OSSwapHostToBigInt32
#define htobe64				OSSwapHostToBigInt64

/* Defined in OpenBSD's <netinet/ip_ipsp.h> */
#define IPSP_DIRECTION_IN		IPSEC_DIR_INBOUND
#define IPSP_DIRECTION_OUT		IPSEC_DIR_OUTBOUND

/* IPv6 compatibility (XXX use post-RFC-3542 API) */
#define __APPLE_USE_RFC_3542		1

/* pfkeyv2.h */
#define SADB_X_EALG_BLF			SADB_X_EALG_BLOWFISHCBC
#define SADB_X_EALG_CAST		SADB_X_EALG_CAST128CBC
/* NATT is not declared in the public pfkeyv2.h header but in XNU */
#define SADB_X_EXT_NATT			0x0002
#define SADB_X_EXT_NATT_KEEPALIVE	0x0004
#define SADB_X_EXT_NATT_MULTIPLEUSERS	0x0008
#define SADB_X_EXT_NATT_DETECTED_PEER	0x0010

#define YYSTYPE_IS_DECLARED 1

#define setresgid(_rgid, _egid, _sgid)	setregid(_rgid, _egid)
#define setresuid(_ruid, _euid, _suid)	setregid(_ruid, _euid)
#define setproctitle(_x, ...) 		do { } while(0)

long long	 strtonum(const char *, long long, long long, const char **);

#endif /* _OPENBSD_COMPAT_H */
