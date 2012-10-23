openiked
========

Internet Key Exchange version 2 (IKEv2) daemon - portable version of
OpenBSD iked.

This code is from the OpenBSD operating system and is included in the
releases since version 4.8.  You can find the source code in OpenBSD's
CVS repository, see:

* http://www.openbsd.org/cgi-bin/cvsweb/src/sbin/iked/
* http://www.openbsd.org/cgi-bin/cvsweb/src/usr.sbin/ikectl/

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
* TODO: more KAME-based platforms, maybe Linux.

Authors
-------

* Reyk Floeter <reyk@openbsd.org>
* Mike Belopuhov <mikeb@openbsd.org>

WARNING
-------

This is work in progress!
