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

#if !defined(HAVE_PLEDGE)
#include <unistd.h>

extern void log_debug(const char *, ...)
    __attribute__((__format__ (printf, 1, 2)));

/*
 * XXX Implement pledge using other sandbox methods?
 */
int
pledge(const char *promises, const char *paths[])
{
	int	i;

	log_debug("%s: pid %d promises: %s", __func__, getpid(), promises);
	for (i = 0; paths != NULL && paths[i] != NULL; i++)
		log_debug("%s: pid %d paths[%d]: %s",
		    __func__, getpid(), i, paths[i]);

	return (0);
}
#endif
