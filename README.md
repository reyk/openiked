OpenIKED
========

This is a development mirror of OpenBSD's iked.

iked is a lean Internet Key Exchange (IKEv2) daemon which performs
mutual authentication and which establishes and maintains IPsec VPN
flows and security associations (SAs) between the two peers.  The
IKEv2 protocol is defined in RFC 5996, which combines and updates the
previous standards: ISAKMP/Oakley (RFC 2408), IKE (RFC 2409), and the
Internet DOI (RFC 2407).  iked only supports the IKEv2 protocol;
support for ISAKMP/Oakley and IKEv1 is provided by OpenBSD's
isakmpd(8) or other implementations on non-OpenBSD platforms.

iked supports mutual authentication using RSA public keys and X.509
certificates, it also support responder/server-side authentication of
clients using the EAP-MSCHAPv2 protocol over IKEv2.  It interconnects
with other IKEv2 implementations like the native IKEv2 implementation
of Windows 7 or newer (aka Agile VPN) or strongSwan.

The main development of iked is being done for OpenBSD and the source
tree is found in OpenBSD's CVS repository.  Like most of the projects
from the OpenBSD repository, the original source code does not include
any portability glue (#ifdefs) and is specifically developed for
OpenBSD.

The main development tree is found in the src/sbin/iked and
src/usr.sbin/ikectl directories of the OpenBSD CVS repository:

* http://www.openbsd.org/cgi-bin/cvsweb/src/sbin/iked/
* http://www.openbsd.org/cgi-bin/cvsweb/src/usr.sbin/ikectl/
* See also: http://www.openiked.org/

Supported Platforms
-------------------

Original version:

* OpenBSD 4.8 or newer

The portable version has been suspended and is not available at
present.  It previously supported the following platforms:

* Darwin (Apple OS X Mountain Lion 10.8) - DEPRECATED
* Linux (Ubuntu 12.10 GNU/Linux 3.5.0-19-generic) - DEPRECATED
* FreeBSD (FreeBSD 9.0-RELEASE with IPSEC kernel) - DEPRECATED
* NetBSD (NetBSD 6.0 with IPSEC kernel) - DEPRECATED

Authors
-------

* Reyk Floeter <reyk@openbsd.org>
* Mike Belopuhov <mikeb@openbsd.org>

See [`LICENSE.md`](https://github.com/reyk/openiked/blob/master/LICENSE.md)
for information about copyright and licensing.

Reyk

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/thing/1038961/reykopeniked-on-GitHub)
