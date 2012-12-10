OpenIKED
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
* See also: http://www.openiked.org/

Installation
------------

The portable version of OpenIKED uses the GNU autoconf environment to
build and install from the sources.  As usual, follow these basic
steps to install OpenIKED:

1. Requirements:
    - Make sure that the external libraries OpenSSL (version 1.0 or newer)
and libevent (version 1.4 or newer) with their header files are
installed.
    - If you're checking out the sources from the Git repository, you will
also need GNU automake, autoconf (version 2.69 or newer) and libtool.
2. Enter the top directory of the extracted sources.
3. If you checked out the sources from the Git repository, run
`sh bootstrap` to generate the required build files.
4. Run `./configure` in this directory to generate the Makefiles.
    - `./configure --help` will show you some available build options.
    - For example, you can run the following when building on Apple OSX
with MacPorts:
```
    ./configure --with-ssl-dir=/opt/local/
        --with-libevent-dir=/opt/local/lib/libevent1/
        --prefix=/opt/local/
```
5. Type `make` to build all parts of OpenIKED including iked and ikectl.
6. Type `make install` to install OpenIKED, or `sudo make install` if
you didn't compile OpenIKED as root.

Supported Platforms
-------------------

Original version:

* OpenBSD 4.8 or newer

Portable version:

* Apple Darwin (OSX Mountain Lion 10.8)
* TODO: more PFKEYv2/KAME-based platforms, maybe Linux.

Development
-----------

The source tree of OpenIKED contains the following directories:

* `openiked/`:
    Build scripts for automake/autoconf and README files.
* `openiked/ikectl/`:
    The control and status utility for iked.
* `openiked/iked/`:
    The IKEv2 daemon itself and some files that are shared with ikectl.
* `openiked/openbsd-compat/`:
    Portability glue and API functions for non-OpenBSD platforms.

You can checkout the portable code from GitHub:

```
$ git clone git://github.com/reyk/openiked.git
```

And compare the contents of the `iked` and `ikectl` directories in
the git repository with the original sources in OpenBSD's
(Anon)CVS repository by running the `cvs diff` command in these
subdirectories. This will show you the differences between the portable
version and the unpatched OpenBSD version:

```
$ cd openiked/iked/
$ cvs diff -Nup | tee ../iked.diff
$ cd ../ikectl/
$ cvs diff -Nup | tee ../ikectl.diff
```

Before you continue with looking at the code or writing any diffs, you
should study OpenBSD's source style guide; or the "KNF". You can
find it in OpenBSD's style(9) manpage or online at:
http://www.openbsd.org/cgi-bin/man.cgi?query=style&sektion=9.
Please also note that each line should be at most 80 characters long.

Authors
-------

* Reyk Floeter <reyk@openbsd.org>
* Mike Belopuhov <mikeb@openbsd.org>

Caveats, bugs and limitations
-----------------------------

This is work in progress!  OpenIKED is not yet finished and is missing
some important security features.  It should not yet be used in
production networks.

OpenIKED might have a few limitations on operating systems other than
the most recent versions of OpenBSD.  A major difference between
OpenBSD and other systems is the API and availability of the IPsec
PFKEYv2 flow implementation (SADB) and message passing between kernel
and iked.  Current known limitations are:

* Acquire Mode:
The SADB_ACQUIRE PFKEYv2 message is not implemented for KAME-based stacks.

* VPN traffic leakage prevention:
Automatic blocking of IPv6 traffic is not working on KAME-bases stacks.

* NAT-T:
NAT-T is only supported on OpenBSD and Darwin (OS X).  The NAT-T API
is not standardized in PFKEYv2, not even on a semi-level, and differs
in most operating systems, if supported at all. 

Reyk

[![Flattr this git repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/thing/1038961/reykopeniked-on-GitHub)
