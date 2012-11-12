sbin_PROGRAMS=	iked

iked_MAPS=	eap_map.c ikev2_map.c
iked_MAPS_IN=	eap.h ikev2.h
iked_SOURCES=	ca.c chap_ms.c config.c control.c crypto.c dh.c \
		eap.c iked.c ikev1.c ikev2.c ikev2_msg.c ikev2_pld.c \
		log.c pfkey.c policy.c proc.c timer.c util.c imsg_util.c \
		parse.y $(iked_MAPS)
iked_CFLAGS=

LIBCOMPAT=	$(top_builddir)/openbsd-compat/libopenbsd-compat.a
LDADD=		$(LIBCOMPAT)
CPPFLAGS=	-include $(top_srcdir)/openbsd-compat/includes.h \
		-I$(top_srcdir)/openbsd-compat \
		-I$(srcdir) @CPPFLAGS@ @DEFS@
MANPAGES=	iked.8.out iked.conf.5.out
MANPAGES_IN=	iked.8 iked.conf.5
CONFIGFILES=	iked.conf.out
CONFIGFILES_IN=	iked.conf
EXTRA_DIST=	$(CONFIGFILES_IN) $(MANPAGES_IN)
CLEANFILES=	$(iked_MAPS) $(CONFIGFILES) $(MANPAGES)
PATHSUBS=	-e 's|/etc/iked/|$(sysconfdir)/iked/|g'			\
		-e 's|/usr/libexec|$(libexecdir)|g'			\
		-e 's|/var/run/iked.sock|$(sockdir)/iked.sock|g'
FIXPATHSCMD=	$(SED) $(PATHSUBS)

$(iked_MAPS): genmap.sh $(iked_MAPS_IN)
	mapname=`echo $@ | sed 's/_map\.c$$//'`; \
	hdrname=$${mapname}.h; \
	$(SH) genmap.sh $${hdrname} $${mapname} > $@
	@touch $@

$(MANPAGES): $(MANPAGES_IN)
	if test "$(MANTYPE)" = "cat"; then \
		manpage=$(srcdir)/`echo $@ | sed 's/\.[1-9]\.out$$/\.0/'`; \
	else \
		manpage=$(srcdir)/`echo $@ | sed 's/\.out$$//'`; \
	fi; \
	if test "$(MANTYPE)" = "man"; then \
		$(FIXPATHSCMD) $${manpage} | $(AWK) -f $(top_srcdir)/mdoc2man.awk > $@; \
	else \
		$(FIXPATHSCMD) $${manpage} > $@; \
	fi

$(CONFIGFILES): $(CONFIGFILES_IN)
	conffile=`echo $@ | sed 's/.out$$//'`; \
	$(FIXPATHSCMD) $(srcdir)/$${conffile} > $@

install-exec-hook: $(CONFIGFILES) $(MANPAGES)
	$(MKDIR_P) $(DESTDIR)$(sysconfdir)/iked/
	$(MKDIR_P) $(DESTDIR)$(sbindir)
	$(MKDIR_P) $(DESTDIR)$(mandir)/$(mansubdir)8
	$(MKDIR_P) $(DESTDIR)$(mandir)/$(mansubdir)5

	@if [ ! -f $(DESTDIR)$(sysconfdir)/iked.conf ]; then \
		$(INSTALL) -m 644 iked.conf.out $(DESTDIR)$(sysconfdir)/iked.conf; \
	else \
		echo "$(DESTDIR)$(sysconfdir)/iked.conf already exists, install will not overwrite"; \
	fi

	$(INSTALL) -m 644 iked.8.out		$(DESTDIR)$(mandir)/$(mansubdir)8/iked.8
	$(INSTALL) -m 644 iked.conf.5.out	$(DESTDIR)$(mandir)/$(mansubdir)5/iked.conf.5
