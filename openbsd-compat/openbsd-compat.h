/* $Id: openbsd-compat.h,v 1.51 2010/10/07 10:25:29 djm Exp $ */

/*
 * Copyright (c) 1999-2003 Damien Miller.  All rights reserved.
 * Copyright (c) 2003 Ben Lindstrom. All rights reserved.
 * Copyright (c) 2002 Tim Rice.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _OPENBSD_COMPAT_H
#define _OPENBSD_COMPAT_H

#include "includes.h"

#include <sys/types.h>

#include <sys/socket.h>
#include <netinet/in.h>

#ifndef AI_MASK
/* valid flags for addrinfo */
#define AI_MASK \
	    (AI_PASSIVE | AI_CANONNAME | AI_NUMERICHOST | AI_NUMERICSERV)
#ifdef AI_FQDN
#define AI_MASK (AI_MASK | AI_FQDN)
#endif
#endif

#ifndef AI_FQDN
#define AI_FQDN AI_CANONNAME
#endif

#include "sys-queue.h"
#include "sys-tree.h"
#include "vis.h"

#ifdef HAVE_SYS_TIME_H
#include <sys/time.h>
#endif

#ifndef SIZE_MAX
#include <stdint.h>
#endif

/* From OpenNTPD portable */
#if !defined(SA_LEN)
# if defined(HAVE_STRUCT_SOCKADDR_SA_LEN)
#  define SA_LEN(x)	((x)->sa_len)
# else
#  define SA_LEN(x)     ((x)->sa_family == AF_INET6 ? \
			sizeof(struct sockaddr_in6) : \
			sizeof(struct sockaddr_in))
# endif
#endif

#if !defined(SET_SA_LEN)
# if defined(HAVE_STRUCT_SOCKADDR_SA_LEN)
#  define SET_SA_LEN(sa, len)	((sa)->sa_len = (len))
# else
#  define SET_SA_LEN(sa, len)	(void)0
# endif
#endif

/* From OpenBGPD portable */
#if !defined(SS_LEN)
# if defined(HAVE_STRUCT_SOCKADDR_STORAGE_SS_LEN)
#  define SS_LEN(x)  ((x)->ss_len)
# else
#  define SS_LEN(x)  SA_LEN((struct sockaddr *)(x))
# endif
#endif

#if !defined(SET_SS_LEN)
# if defined(HAVE_STRUCT_SOCKADDR_STORAGE_SS_LEN)
#  define SET_SS_LEN(ss, len)	((ss)->ss_len = (len))
# else
#  define SET_SS_LEN(ss, len)	SET_SA_LEN((struct sockaddr *)(ss), len)
# endif
#endif

#ifndef HAVE_CLOSEFROM
void closefrom(int);
#endif

#ifndef HAVE_STRLCPY
size_t strlcpy(char *dst, const char *src, size_t size);
#endif

#ifndef HAVE_STRLCAT
size_t strlcat(char *dst, const char *src, size_t size);
#endif

#ifndef HAVE_STRMODE
void strmode(int mode, char *p);
#endif

#ifndef HAVE_DIRNAME
char *dirname(const char *path);
#endif

#ifndef HAVE_STRSEP
char *strsep(char **stringp, const char *delim);
#endif

#ifndef HAVE_SETPROCTITLE
void setproctitle(const char *fmt, ...);
void compat_init_setproctitle(int argc, char *argv[]);
#endif

#ifndef HAVE_SETRESGID
int setresgid(uid_t rgid, uid_t egid, uid_t sgid);
#endif

#ifndef HAVE_SETRESUID
int setresuid(uid_t ruid, uid_t euid, uid_t suid);
#endif

#if !defined(HAVE_GETOPT) || !defined(HAVE_GETOPT_OPTRESET)
int BSDgetopt(int argc, char * const *argv, const char *opts);
char	*BSDoptarg;		/* argument associated with option */
int	BSDoptind;		/* index into parent argv vector */
#endif

#ifndef HAVE_GETPEEREID
int getpeereid(int , uid_t *, gid_t *);
#endif 

#ifndef HAVE_ARC4RANDOM
unsigned int arc4random(void);
void arc4random_stir(void);
#endif /* !HAVE_ARC4RANDOM */

#ifndef HAVE_ARC4RANDOM_BUF
void arc4random_buf(void *, size_t);
#endif

#ifndef HAVE_ARC4RANDOM_UNIFORM
u_int32_t arc4random_uniform(u_int32_t);
#endif

#ifndef HAVE_FGETLN
#include <stdio.h>
#include <string.h>
char * fgetln(FILE *stream, size_t *len);
#endif

#ifndef HAVE_FPARSELN
char * fparseln(FILE *fp, size_t *size, size_t *lineno, const char str[3], int flags);
#endif

#ifndef HAVE_STRTONUM
long long strtonum(const char *nptr, long long minval, long long maxval, const char **errstr);
#endif

#ifndef HAVE_STRMODE
void strmode(int mode, char *p);
#endif

#ifndef HAVE_FMT_SCALED
#define	FMT_SCALED_STRSIZE	7
int scan_scaled(char *scaled, long long *result);
int fmt_scaled(long long number, char *result);
#endif

#ifndef HAVE_REALLOCARRAY
void *reallocarray(void *, size_t , size_t);
#endif

#ifndef HAVE_EXPLICIT_BZERO
void explicit_bzero(void *buf, size_t len);
#endif

#ifndef HAVE_PLEDGE
int pledge(const char *promises, const char *paths[]);
#endif

#ifndef HAVE_ERRC
void errc(int eval, int code, const char *fmt, ...);
#endif

#ifndef HAVE_WARNC
void warnc(int code, const char *fmt, ...);
#endif

int bsd_socket(int domain, int type, int protocol);
int bsd_socketpair(int d, int type, int protocol, int sv[2]);
int bsd_accept4(int s, struct sockaddr *addr, socklen_t *addrlen, int flags);

#endif /* _OPENBSD_COMPAT_H */
