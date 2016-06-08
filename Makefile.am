SUBDIRS=		openbsd-compat iked ikectl
ACLOCAL_AMFLAGS=	-I m4

PRIVKEY=$(DESTDIR)$(sysconfdir)/iked/private/local.key
PUBKEY=$(DESTDIR)$(sysconfdir)/iked/local.pub

install-exec-hook: host-key

host-key:
	@if [ -z "$(DESTDIR)" ] ; then \
		if [ -f $(PRIVKEY) ]; then \
			echo "$(PRIVKEY) already exists, skipping." ; \
		elif $(OPENSSL) genrsa -out $(PRIVKEY) 2048 ; then \
			$(CHMOD) 600 $(PRIVKEY) ; \
			$(OPENSSL) rsa -out $(PUBKEY) -in $(PRIVKEY) -pubout ; \
		else \
			echo "$(PRIVKEY) failed" ; \
		fi ; \
	fi
