/*
 * Copyright (c) 2016 Reyk Floeter <reyk@openbsd.org>
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

#if defined(SOCK_SETFLAGS)
#include <unistd.h>
#include <fcntl.h>

static int
bsd_socket_setflags(int s, int flags)
{
	int	 f;

	if (flags & SOCK_NONBLOCK) {
		if (fcntl(s, F_GETFL, &f) == -1)
			return (-1);
		f |= O_NONBLOCK;
		if (fcntl(s, F_SETFL, &f) == -1)
			return (-1);
	}

	if (flags & SOCK_CLOEXEC) {
		if (fcntl(s, F_GETFD, &f) == -1)
			return (-1);
		f |= FD_CLOEXEC;
		if (fcntl(s, F_SETFD, &f) == -1)
			return (-1);
	}

	return (0);
}
#endif

int
bsd_socket(int domain, int type, int protocol)
{
	int	 s;
#if defined(SOCK_SETFLAGS)
	int	 setfl;

	setfl = type & SOCK_SETFLAGS;
	type &= ~SOCK_SETFLAGS;
#endif

	if ((s = socket(domain, type, protocol)) == -1)
		return (-1);

#if defined(SOCK_SETFLAGS)
	if (bsd_socket_setflags(s, setfl) == -1) {
		close(s);
		return (-1);
	}
#endif

	return (s);
}

int
bsd_socketpair(int d, int type, int protocol, int sv[2])
{
#if defined(SOCK_SETFLAGS)
	int	 setfl;
	int	 i;

	setfl = type & SOCK_SETFLAGS;
	type &= ~SOCK_SETFLAGS;
#endif

	if (socketpair(d, type, protocol, sv) == -1)
		return (-1);

#if defined(SOCK_SETFLAGS)
	for (i = 0; i < 2; i++) {
		if (bsd_socket_setflags(sv[i], setfl) == -1) {
			close(sv[0]);
			close(sv[1]);
			return (-1);
		}
	}
#endif

	return (0);
}

int
bsd_accept4(int s, struct sockaddr *addr, socklen_t *addrlen, int flags)
{
#if !defined(SOCK_SETFLAGS) && defined(HAVE_ACCEPT4)
	return (accept4(s, addr, addrlen, flags));
#else
	int	 c;
	int	 setfl = flags & SOCK_SETFLAGS;

	if ((c = accept(s, addr, addrlen)) == -1)
		return (-1);

	if (bsd_socket_setflags(c, setfl) == -1) {
		close(c);
		return (-1);
	}

	return (c);
#endif
}
