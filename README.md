OpenIKEd
========

This is the port of OpenBSD's iked to Darwin/OSX and other systems in
the future (see "Supported Platforms").

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
tree is found in OpenBSD's CVS repository.  This port adds
replacements for OpenBSD-specific library functions and portability
code for other platforms.  Like most of the projects from the OpenBSD
repository, the original source code does not include any portability
glue (#ifdefs) and is specifically developed for OpenBSD.  This
external repository adds all the portable extensions to run it on
other supported platforms.

The main development tree is found in the src/sbin/iked and
src/usr.sbin/ikectl directories of the OpenBSD CVS repository:

* http://www.openbsd.org/cgi-bin/cvsweb/src/sbin/iked/
* http://www.openbsd.org/cgi-bin/cvsweb/src/usr.sbin/ikectl/
* See also: http://www.openbsd.org/anoncvs.html

Installation
------------

TODO!

(This portable version of iked currently compiles on OSX 10.8
with MacPorts using the ports openssl, libevent1 and bmake.  The
Makefiles are written for BSD make, aka. bmake.)

Supported Platforms
-------------------

Original version:

* OpenBSD 4.8 or newer

Portable version:

* Darwin (OSX Mountain Lion 10.8)
* TODO: more PFKEYv2/KAME-based platforms, maybe Linux.

Authors
-------

* Reyk Floeter <reyk@openbsd.org>
* Mike Belopuhov <mikeb@openbsd.org>

WARNING
-------

This is work in progress!
