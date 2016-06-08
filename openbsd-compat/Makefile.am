noinst_LIBRARIES= libopenbsd-compat.a

libopenbsd_compat_a_SOURCES= \
		explicit-bzero.c \
		imsg.c imsg-buffer.c \
		reallocarray.c setresguid.c strtonum.c

EXTRA_DIST=	defines.h imsg.h includes.h \
		openbsd-compat.h sys-queue.h sys-tree.h

CPPFLAGS=	-include $(top_srcdir)/openbsd-compat/includes.h \
		-I$(top_srcdir) -I$(top_srcdir)/openbsd-compat \
		@CPPFLAGS@ @DEFS@
