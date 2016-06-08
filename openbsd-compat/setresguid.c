/* Subset of uidswap.c from portable OpenSSH */

/* $OpenBSD: uidswap.c,v 1.35 2006/08/03 03:34:42 deraadt Exp $ */
/*
 * Author: Tatu Ylonen <ylo@cs.hut.fi>
 * Copyright (c) 1995 Tatu Ylonen <ylo@cs.hut.fi>, Espoo, Finland
 *                    All rights reserved
 * Code for uid-swapping.
 *
 * As far as I am concerned, the code I have written for this software
 * can be used freely for any purpose.  Any derived versions of this
 * software must be clearly marked as such, and if the derived work is
 * incompatible with the protocol description in the RFC file, it must be
 * called by a name other than "ssh" or "Secure Shell".
 */

#include "includes.h"

#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif

#ifndef HAVE_SETRESGID
int setresgid(uid_t rgid, uid_t egid, uid_t sgid)
{

#if defined(HAVE_SETRESGID) && !defined(BROKEN_SETRESGID)
	if (setresgid(rgid, egid, sgid) < 0)
		err(1, "setresgid %u", (u_int)rgid);
#elif defined(HAVE_SETREGID) && !defined(BROKEN_SETREGID)
	if (setregid(rgid, egid) < 0)
		err(1, "setregid %u", (u_int)rgid);
#else
	if (setegid(egid) < 0)
		err(1, "setegid %u", (u_int)egid);
	if (setgid(rgid) < 0)
		err(1, "setgid %u", (u_int)rgid);
#endif
	return (0);
}
#endif /* HAVE_SETRESGID */



#ifndef HAVE_SETRESUID
int setresuid(uid_t ruid, uid_t euid, uid_t suid)
{

#if defined(HAVE_SETRESUID) && !defined(BROKEN_SETRESUID)
	if (setresuid(ruid, euid, suid) < 0)
		err(1, "setresuid %u", (u_int)ruid);
#elif defined(HAVE_SETREUID) && !defined(BROKEN_SETREUID)
	if (setreuid(ruid, euid) < 0)
		err(1, "setreuid %u", (u_int)ruid);
#else
# ifndef SETEUID_BREAKS_SETUID
	if (seteuid(euid) < 0)
		err(1, "seteuid %u", (u_int)euid);
# endif
	if (setuid(ruid) < 0)
		err(1, "setuid %u", (u_int)ruid);
#endif
	return (0);
}
#endif /* HAVE_SETRESUID */
