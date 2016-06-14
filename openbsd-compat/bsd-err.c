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

#if !defined(HAVE_ERRC) || !defined(HAVE_WARNC)
#include <stdarg.h>
#include <errno.h>
#include <err.h>
#endif

#ifndef HAVE_ERRC
void
errc(int eval, int code, const char *fmt, ...)
{
	va_list	 ap;
	int	 saved_errno = errno;

	errno = code;

	va_start(ap, fmt);
	verr(eval, fmt, ap);
	va_end(ap);

	/* NOTREACHED */
	errno = saved_errno;
}
#endif

#ifndef HAVE_WARNC
void
warnc(int code, const char *fmt, ...)
{
	va_list	 ap;
	int	 saved_errno = errno;

	errno = code;

	va_start(ap, fmt);
	vwarn(fmt, ap);
	va_end(ap);

	errno = saved_errno;
}
#endif
