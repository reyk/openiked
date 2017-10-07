/*	$OpenBSD: parse.y,v 1.54 2015/12/09 21:41:49 naddy Exp $	*/

/*
 * Copyright (c) 2010-2013 Reyk Floeter <reyk@openbsd.org>
 * Copyright (c) 2004, 2005 Hans-Joerg Hoexer <hshoexer@openbsd.org>
 * Copyright (c) 2002, 2003, 2004 Henning Brauer <henning@openbsd.org>
 * Copyright (c) 2001 Markus Friedl.  All rights reserved.
 * Copyright (c) 2001 Daniel Hartmeier.  All rights reserved.
 * Copyright (c) 2001 Theo de Raadt.  All rights reserved.
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

%{
#include <sys/types.h>
#include <sys/ioctl.h>

#include <sys/socket.h>
#include <sys/stat.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <ifaddrs.h>
#include <limits.h>
#include <netdb.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>
#include <netdb.h>
#include <event.h>

#include "iked.h"
#include "ikev2.h"
#include "eap.h"

TAILQ_HEAD(files, file)		 files = TAILQ_HEAD_INITIALIZER(files);
static struct file {
	TAILQ_ENTRY(file)	 entry;
	FILE			*stream;
	char			*name;
	int			 lineno;
	int			 errors;
} *file;
struct file	*pushfile(const char *, int);
int		 popfile(void);
int		 check_file_secrecy(int, const char *);
int		 check_pubkey(char *, int );
int		 yyparse(void);
int		 yylex(void);
int		 yyerror(const char *, ...)
    __attribute__((__format__ (printf, 1, 2)))
    __attribute__((__nonnull__ (1)));
int		 kw_cmp(const void *, const void *);
int		 lookup(char *);
int		 lgetc(int);
int		 lungetc(int);
int		 findeol(void);

TAILQ_HEAD(symhead, sym)	 symhead = TAILQ_HEAD_INITIALIZER(symhead);
struct sym {
	TAILQ_ENTRY(sym)	 entry;
	int			 used;
	int			 persist;
	char			*nam;
	char			*val;
};
int		 symset(const char *, const char *, int);
char		*symget(const char *);

#define KEYSIZE_LIMIT	1024

static struct iked	*env = NULL;
static int		 debug = 0;
static int		 rules = 0;
static int		 passive = 0;
static int		 decouple = 0;
static char		*ocsp_url = NULL;

struct ipsec_xf {
	const char	*name;
	unsigned int	 id;
	unsigned int	 length;
	unsigned int	 keylength;
	unsigned int	 nonce;
	unsigned int	 noauth;
};

struct ipsec_transforms {
	const struct ipsec_xf *authxf;
	const struct ipsec_xf *prfxf;
	const struct ipsec_xf *encxf;
	const struct ipsec_xf *groupxf;
	const struct ipsec_xf *esnxf;
};

struct ipsec_mode {
	struct ipsec_transforms	*xfs;
	uint8_t			 ike_exch;
};

struct iked_transform ikev2_default_ike_transforms[] = {
	{ IKEV2_XFORMTYPE_ENCR, IKEV2_XFORMENCR_AES_CBC, 256 },
	{ IKEV2_XFORMTYPE_ENCR, IKEV2_XFORMENCR_AES_CBC, 192 },
	{ IKEV2_XFORMTYPE_ENCR, IKEV2_XFORMENCR_AES_CBC, 128 },
	{ IKEV2_XFORMTYPE_ENCR, IKEV2_XFORMENCR_3DES },
	{ IKEV2_XFORMTYPE_PRF,	IKEV2_XFORMPRF_HMAC_SHA2_256 },
	{ IKEV2_XFORMTYPE_PRF,	IKEV2_XFORMPRF_HMAC_SHA1 },
	{ IKEV2_XFORMTYPE_INTEGR, IKEV2_XFORMAUTH_HMAC_SHA2_256_128 },
	{ IKEV2_XFORMTYPE_INTEGR, IKEV2_XFORMAUTH_HMAC_SHA1_96 },
	{ IKEV2_XFORMTYPE_DH,	IKEV2_XFORMDH_MODP_2048_256 },
	{ IKEV2_XFORMTYPE_DH,	IKEV2_XFORMDH_MODP_2048 },
	{ IKEV2_XFORMTYPE_DH,	IKEV2_XFORMDH_MODP_1536 },
	{ IKEV2_XFORMTYPE_DH,	IKEV2_XFORMDH_MODP_1024 },
	{ 0 }
};
size_t ikev2_default_nike_transforms = ((sizeof(ikev2_default_ike_transforms) /
    sizeof(ikev2_default_ike_transforms[0])) - 1);

struct iked_transform ikev2_default_esp_transforms[] = {
	{ IKEV2_XFORMTYPE_ENCR, IKEV2_XFORMENCR_AES_CBC, 256 },
	{ IKEV2_XFORMTYPE_ENCR, IKEV2_XFORMENCR_AES_CBC, 192 },
	{ IKEV2_XFORMTYPE_ENCR, IKEV2_XFORMENCR_AES_CBC, 128 },
	{ IKEV2_XFORMTYPE_INTEGR, IKEV2_XFORMAUTH_HMAC_SHA2_256_128 },
	{ IKEV2_XFORMTYPE_INTEGR, IKEV2_XFORMAUTH_HMAC_SHA1_96 },
	{ IKEV2_XFORMTYPE_ESN,	IKEV2_XFORMESN_ESN },
	{ IKEV2_XFORMTYPE_ESN,	IKEV2_XFORMESN_NONE },
	{ 0 }
};
size_t ikev2_default_nesp_transforms = ((sizeof(ikev2_default_esp_transforms) /
    sizeof(ikev2_default_esp_transforms[0])) - 1);

const struct ipsec_xf authxfs[] = {
	{ "hmac-md5",		IKEV2_XFORMAUTH_HMAC_MD5_96,		16 },
	{ "hmac-sha1",		IKEV2_XFORMAUTH_HMAC_SHA1_96,		20 },
	{ "hmac-sha2-256",	IKEV2_XFORMAUTH_HMAC_SHA2_256_128,	32 },
	{ "hmac-sha2-384",	IKEV2_XFORMAUTH_HMAC_SHA2_384_192,	48 },
	{ "hmac-sha2-512",	IKEV2_XFORMAUTH_HMAC_SHA2_512_256,	64 },
	{ NULL }
};

const struct ipsec_xf prfxfs[] = {
	{ "hmac-md5",		IKEV2_XFORMPRF_HMAC_MD5,	16 },
	{ "hmac-sha1",		IKEV2_XFORMPRF_HMAC_SHA1,	20 },
	{ "hmac-sha2-256",	IKEV2_XFORMPRF_HMAC_SHA2_256,	32 },
	{ "hmac-sha2-384",	IKEV2_XFORMPRF_HMAC_SHA2_384,	48 },
	{ "hmac-sha2-512",	IKEV2_XFORMPRF_HMAC_SHA2_512,	64 },
	{ NULL }
};

const struct ipsec_xf *encxfs = NULL;

const struct ipsec_xf ikeencxfs[] = {
	{ "3des",		IKEV2_XFORMENCR_3DES,		24 },
	{ "3des-cbc",		IKEV2_XFORMENCR_3DES,		24 },
	{ "aes-128",		IKEV2_XFORMENCR_AES_CBC,	16, 16 },
	{ "aes-192",		IKEV2_XFORMENCR_AES_CBC,	24, 24 },
	{ "aes-256",		IKEV2_XFORMENCR_AES_CBC,	32, 32 },
	{ NULL }
};

const struct ipsec_xf ipsecencxfs[] = {
	{ "3des",		IKEV2_XFORMENCR_3DES,		24 },
	{ "3des-cbc",		IKEV2_XFORMENCR_3DES,		24 },
	{ "aes-128",		IKEV2_XFORMENCR_AES_CBC,	16, 16 },
	{ "aes-192",		IKEV2_XFORMENCR_AES_CBC,	24, 24 },
	{ "aes-256",		IKEV2_XFORMENCR_AES_CBC,	32, 32 },
	{ "aes-128-ctr",	IKEV2_XFORMENCR_AES_CTR,	16, 16, 4 },
	{ "aes-192-ctr",	IKEV2_XFORMENCR_AES_CTR,	24, 24, 4 },
	{ "aes-256-ctr",	IKEV2_XFORMENCR_AES_CTR,	32, 32, 4 },
	{ "aes-128-gcm",	IKEV2_XFORMENCR_AES_GCM_16,	16, 16, 4, 1 },
	{ "aes-192-gcm",	IKEV2_XFORMENCR_AES_GCM_16,	24, 24, 4, 1 },
	{ "aes-256-gcm",	IKEV2_XFORMENCR_AES_GCM_16,	32, 32, 4, 1 },
	{ "aes-128-gmac",	IKEV2_XFORMENCR_NULL_AES_GMAC,	16, 16, 4, 1 },
	{ "aes-192-gmac",	IKEV2_XFORMENCR_NULL_AES_GMAC,	24, 24, 4, 1 },
	{ "aes-256-gmac",	IKEV2_XFORMENCR_NULL_AES_GMAC,	32, 32, 4, 1 },
	{ "blowfish",		IKEV2_XFORMENCR_BLOWFISH,	20, 20 },
	{ "cast",		IKEV2_XFORMENCR_CAST,		16, 16 },
	{ "chacha20-poly1305",	IKEV2_XFORMENCR_CHACHA20_POLY1305,
								32, 32, 4, 1 },
	{ "null",		IKEV2_XFORMENCR_NULL,		0, 0 },
	{ NULL }
};

const struct ipsec_xf groupxfs[] = {
	{ "modp768",		IKEV2_XFORMDH_MODP_768 },
	{ "grp1",		IKEV2_XFORMDH_MODP_768 },
	{ "modp1024",		IKEV2_XFORMDH_MODP_1024 },
	{ "grp2",		IKEV2_XFORMDH_MODP_1024 },
	{ "ec2n155",		IKEV2_XFORMDH_EC2N_155 },
	{ "grp3",		IKEV2_XFORMDH_EC2N_155 },
	{ "ec2n185",		IKEV2_XFORMDH_EC2N_185 },
	{ "grp4",		IKEV2_XFORMDH_EC2N_185 },
	{ "modp1536",		IKEV2_XFORMDH_MODP_1536 },
	{ "grp5",		IKEV2_XFORMDH_MODP_1536 },
	{ "modp2048",		IKEV2_XFORMDH_MODP_2048 },
	{ "grp14",		IKEV2_XFORMDH_MODP_2048 },
	{ "modp3072",		IKEV2_XFORMDH_MODP_3072 },
	{ "grp15",		IKEV2_XFORMDH_MODP_3072 },
	{ "modp4096",		IKEV2_XFORMDH_MODP_4096 },
	{ "grp16",		IKEV2_XFORMDH_MODP_4096 },
	{ "modp6144",		IKEV2_XFORMDH_MODP_6144 },
	{ "grp17",		IKEV2_XFORMDH_MODP_6144 },
	{ "modp8192",		IKEV2_XFORMDH_MODP_8192 },
	{ "grp18",		IKEV2_XFORMDH_MODP_8192 },
	{ "ecp256",		IKEV2_XFORMDH_ECP_256 },
	{ "grp19",		IKEV2_XFORMDH_ECP_256 },
	{ "ecp384",		IKEV2_XFORMDH_ECP_384 },
	{ "grp20",		IKEV2_XFORMDH_ECP_384 },
	{ "ecp521",		IKEV2_XFORMDH_ECP_521 },
	{ "grp21",		IKEV2_XFORMDH_ECP_521 },
	{ "modp1024-160",	IKEV2_XFORMDH_MODP_1024_160 },
	{ "grp22",		IKEV2_XFORMDH_MODP_1024_160 },
	{ "modp2048-224",	IKEV2_XFORMDH_MODP_2048_224 },
	{ "grp23",		IKEV2_XFORMDH_MODP_2048_224 },
	{ "modp2048-256",	IKEV2_XFORMDH_MODP_2048_256 },
	{ "grp24",		IKEV2_XFORMDH_MODP_2048_256 },
	{ "ecp192",		IKEV2_XFORMDH_ECP_192 },
	{ "grp25",		IKEV2_XFORMDH_ECP_192 },
	{ "ecp224",		IKEV2_XFORMDH_ECP_224 },
	{ "grp26",		IKEV2_XFORMDH_ECP_224 },
	{ "brainpool224",	IKEV2_XFORMDH_BRAINPOOL_P224R1 },
	{ "grp27",		IKEV2_XFORMDH_BRAINPOOL_P224R1 },
	{ "brainpool256",	IKEV2_XFORMDH_BRAINPOOL_P256R1 },
	{ "grp28",		IKEV2_XFORMDH_BRAINPOOL_P256R1 },
	{ "brainpool384",	IKEV2_XFORMDH_BRAINPOOL_P384R1 },
	{ "grp29",		IKEV2_XFORMDH_BRAINPOOL_P384R1 },
	{ "brainpool512",	IKEV2_XFORMDH_BRAINPOOL_P512R1 },
	{ "grp30",		IKEV2_XFORMDH_BRAINPOOL_P512R1 },
	{ "curve25519",		IKEV2_XFORMDH_X_CURVE25519 },
	{ NULL }
};

const struct ipsec_xf methodxfs[] = {
	{ "rsa",		IKEV2_AUTH_RSA_SIG },
	{ "dss",		IKEV2_AUTH_DSS_SIG },
	{ "ecdsa-256",		IKEV2_AUTH_ECDSA_256 },
	{ "ecdsa-384",		IKEV2_AUTH_ECDSA_384 },
	{ "ecdsa-521",		IKEV2_AUTH_ECDSA_521 },
	{ NULL }
};

const struct ipsec_xf saxfs[] = {
	{ "esp",		IKEV2_SAPROTO_ESP },
	{ "ah",			IKEV2_SAPROTO_AH },
	{ NULL }
};

const struct ipsec_xf cpxfs[] = {
	{ "address", IKEV2_CFG_INTERNAL_IP4_ADDRESS,		AF_INET },
	{ "netmask", IKEV2_CFG_INTERNAL_IP4_NETMASK,		AF_INET },
	{ "name-server", IKEV2_CFG_INTERNAL_IP4_DNS,		AF_INET },
	{ "netbios-server", IKEV2_CFG_INTERNAL_IP4_NBNS,	AF_INET },
	{ "dhcp-server", IKEV2_CFG_INTERNAL_IP4_DHCP,		AF_INET },
	{ "address", IKEV2_CFG_INTERNAL_IP6_ADDRESS,		AF_INET6 },
	{ "name-server", IKEV2_CFG_INTERNAL_IP6_DNS,		AF_INET6 },
	{ "netbios-server", IKEV2_CFG_INTERNAL_IP6_NBNS,	AF_INET6 },
	{ "dhcp-server", IKEV2_CFG_INTERNAL_IP6_DHCP,		AF_INET6 },
	{ "protected-subnet", IKEV2_CFG_INTERNAL_IP4_SUBNET,	AF_INET },
	{ "protected-subnet", IKEV2_CFG_INTERNAL_IP6_SUBNET,	AF_INET6 },
	{ "access-server", IKEV2_CFG_INTERNAL_IP4_SERVER,	AF_INET },
	{ "access-server", IKEV2_CFG_INTERNAL_IP6_SERVER,	AF_INET6 },
	{ NULL }
};

const struct iked_lifetime deflifetime = {
	IKED_LIFETIME_BYTES,
	IKED_LIFETIME_SECONDS
};

struct ipsec_addr_wrap {
	struct sockaddr_storage	 address;
	uint8_t			 mask;
	int			 netaddress;
	unsigned int		 type;
	unsigned int		 action;
	char			*name;
	struct ipsec_addr_wrap	*next;
	struct ipsec_addr_wrap	*tail;
	struct ipsec_addr_wrap	*srcnat;
};

struct ipsec_hosts {
	struct ipsec_addr_wrap	*src;
	struct ipsec_addr_wrap	*dst;
	uint16_t		 sport;
	uint16_t		 dport;
};

struct ipsec_filters {
	char			*tag;
	unsigned int		 tap;
};

struct ipsec_addr_wrap	*host(const char *);
struct ipsec_addr_wrap	*host_v6(const char *, int);
struct ipsec_addr_wrap	*host_v4(const char *, int);
struct ipsec_addr_wrap	*host_dns(const char *, int);
struct ipsec_addr_wrap	*host_if(const char *, int);
struct ipsec_addr_wrap	*host_any(void);
void			 ifa_load(void);
int			 ifa_exists(const char *);
struct ipsec_addr_wrap	*ifa_lookup(const char *ifa_name);
struct ipsec_addr_wrap	*ifa_grouplookup(const char *);
void			 set_ipmask(struct ipsec_addr_wrap *, uint8_t);
const struct ipsec_xf	*parse_xf(const char *, unsigned int,
			    const struct ipsec_xf *);
const char		*print_xf(unsigned int, unsigned int,
			    const struct ipsec_xf *);
void			 copy_transforms(unsigned int, const struct ipsec_xf *,
			    const struct ipsec_xf *,
			    struct iked_transform *, size_t,
			    unsigned int *, struct iked_transform *, size_t);
int			 create_ike(char *, int, uint8_t, struct ipsec_hosts *,
			    struct ipsec_hosts *, struct ipsec_mode *,
			    struct ipsec_mode *, uint8_t,
			    uint8_t, char *, char *,
			    uint32_t, struct iked_lifetime *,
			    struct iked_auth *, struct ipsec_filters *,
			    struct ipsec_addr_wrap *);
int			 create_user(const char *, const char *);
int			 get_id_type(char *);
uint8_t			 x2i(unsigned char *);
int			 parsekey(unsigned char *, size_t, struct iked_auth *);
int			 parsekeyfile(char *, struct iked_auth *);

struct ipsec_transforms *ipsec_transforms;
struct ipsec_filters *ipsec_filters;

typedef struct {
	union {
		int64_t			 number;
		uint8_t			 ikemode;
		uint8_t			 dir;
		uint8_t			 satype;
		uint8_t			 proto;
		char			*string;
		uint16_t		 port;
		struct ipsec_hosts	*hosts;
		struct ipsec_hosts	 peers;
		struct ipsec_addr_wrap	*anyhost;
		struct ipsec_addr_wrap	*host;
		struct ipsec_addr_wrap	*cfg;
		struct {
			char		*srcid;
			char		*dstid;
		} ids;
		char			*id;
		uint8_t			 type;
		struct iked_lifetime	 lifetime;
		struct iked_auth	 ikeauth;
		struct iked_auth	 ikekey;
		struct ipsec_transforms	*transforms;
		struct ipsec_filters	*filters;
		struct ipsec_mode	*mode;
	} v;
	int lineno;
} YYSTYPE;

%}

%token	FROM ESP AH IN PEER ON OUT TO SRCID DSTID RSA PSK PORT
%token	FILENAME AUTHXF PRFXF ENCXF ERROR IKEV2 IKESA CHILDSA
%token	PASSIVE ACTIVE ANY TAG TAP PROTO LOCAL GROUP NAME CONFIG EAP USER
%token	IKEV1 FLOW SA TCPMD5 TUNNEL TRANSPORT COUPLE DECOUPLE SET
%token	INCLUDE LIFETIME BYTES INET INET6 QUICK SKIP DEFAULT
%token	IPCOMP OCSP IKELIFETIME
%token	<v.string>		STRING
%token	<v.number>		NUMBER
%type	<v.string>		string
%type	<v.satype>		satype
%type	<v.proto>		proto
%type	<v.number>		protoval
%type	<v.hosts>		hosts hosts_list
%type	<v.port>		port
%type	<v.number>		portval af
%type	<v.peers>		peers
%type	<v.anyhost>		anyhost
%type	<v.host>		host host_spec
%type	<v.ids>			ids
%type	<v.id>			id
%type	<v.transforms>		transforms
%type	<v.filters>		filters
%type	<v.ikemode>		ikeflags ikematch ikemode ipcomp
%type	<v.ikeauth>		ikeauth
%type	<v.ikekey>		keyspec
%type	<v.mode>		ike_sa child_sa
%type	<v.lifetime>		lifetime
%type	<v.number>		byte_spec time_spec ikelifetime
%type	<v.string>		name
%type	<v.cfg>			cfg ikecfg ikecfgvals
%%

grammar		: /* empty */
		| grammar include '\n'
		| grammar '\n'
		| grammar set '\n'
		| grammar user '\n'
		| grammar ikev2rule '\n'
		| grammar varset '\n'
		| grammar otherrule skipline '\n'
		| grammar error '\n'		{ file->errors++; }
		;

comma		: ','
		| /* empty */
		;

include		: INCLUDE STRING		{
			struct file	*nfile;

			if ((nfile = pushfile($2, 0)) == NULL) {
				yyerror("failed to include file %s", $2);
				free($2);
				YYERROR;
			}
			free($2);

			file = nfile;
			lungetc('\n');
		}
		;

set		: SET ACTIVE	{ passive = 0; }
		| SET PASSIVE	{ passive = 1; }
		| SET COUPLE	{ decouple = 0; }
		| SET DECOUPLE	{ decouple = 1; }
		| SET OCSP STRING		{
			if ((ocsp_url = strdup($3)) == NULL) {
				yyerror("cannot set ocsp_url");
				YYERROR;
			}
		}
		;

user		: USER STRING STRING		{
			if (create_user($2, $3) == -1)
				YYERROR;
		}
		;

ikev2rule	: IKEV2 name ikeflags satype af proto hosts_list peers
		    ike_sa child_sa ids ikelifetime lifetime ikeauth ikecfg
		    filters {
			if (create_ike($2, $5, $6, $7, &$8, $9, $10, $4, $3,
			    $11.srcid, $11.dstid, $12, &$13, &$14,
			    $16, $15) == -1)
				YYERROR;
		}
		;

ikecfg		: /* empty */			{ $$ = NULL; }
		| ikecfgvals			{ $$ = $1; }
		;

ikecfgvals	: cfg				{ $$ = $1; }
		| ikecfgvals cfg		{
			if ($2 == NULL)
				$$ = $1;
			else if ($1 == NULL)
				$$ = $2;
			else {
				$1->tail->next = $2;
				$1->tail = $2->tail;
				$$ = $1;
			}
		}
		;

cfg		: CONFIG STRING host_spec	{
			const struct ipsec_xf	*xf;

			xf = parse_xf($2, $3->address.ss_family, cpxfs);
			if (xf == NULL) {
				yyerror("not a valid ikecfg option");
				free($2);
				free($3);
				YYERROR;
			}
			$$ = $3;
			$$->type = xf->id;
			$$->action = IKEV2_CP_REPLY;	/* XXX */
		}
		;

name		: /* empty */			{ $$ = NULL; }
		| STRING			{
			$$ = $1;
		}

satype		: /* empty */			{ $$ = IKEV2_SAPROTO_ESP; }
		| ESP				{ $$ = IKEV2_SAPROTO_ESP; }
		| AH				{ $$ = IKEV2_SAPROTO_AH; }
		;

af		: /* empty */			{ $$ = AF_UNSPEC; }
		| INET				{ $$ = AF_INET; }
		| INET6				{ $$ = AF_INET6; }
		;

proto		: /* empty */			{ $$ = 0; }
		| PROTO protoval		{ $$ = $2; }
		| PROTO ESP			{ $$ = IPPROTO_ESP; }
		| PROTO AH			{ $$ = IPPROTO_AH; }
		;

protoval	: STRING			{
			struct protoent *p;

			p = getprotobyname($1);
			if (p == NULL) {
				yyerror("unknown protocol: %s", $1);
				YYERROR;
			}
			$$ = p->p_proto;
			free($1);
		}
		| NUMBER			{
			if ($1 > 255 || $1 < 0) {
				yyerror("protocol outside range");
				YYERROR;
			}
		}
		;

hosts_list	: hosts				{ $$ = $1; }
		| hosts_list comma hosts	{
			if ($3 == NULL)
				$$ = $1;
			else if ($1 == NULL)
				$$ = $3;
			else {
				$1->src->tail->next = $3->src;
				$1->src->tail = $3->src->tail;
				$1->dst->tail->next = $3->dst;
				$1->dst->tail = $3->dst->tail;
				$$ = $1;
			}
		}
		;

hosts		: FROM host port TO host port		{
			struct ipsec_addr_wrap *ipa;
			for (ipa = $5; ipa; ipa = ipa->next) {
				if (ipa->srcnat) {
					yyerror("no flow NAT support for"
					    " destination network: %s",
					    ipa->name);
					YYERROR;
				}
			}

			if (($$ = calloc(1, sizeof(*$$))) == NULL)
				err(1, "hosts: calloc");

			$$->src = $2;
			$$->sport = $3;
			$$->dst = $5;
			$$->dport = $6;
		}
		| TO host port FROM host port		{
			struct ipsec_addr_wrap *ipa;
			for (ipa = $2; ipa; ipa = ipa->next) {
				if (ipa->srcnat) {
					yyerror("no flow NAT support for"
					    " destination network: %s",
					    ipa->name);
					YYERROR;
				}
			}
			if (($$ = calloc(1, sizeof(*$$))) == NULL)
				err(1, "hosts: calloc");

			$$->src = $5;
			$$->sport = $6;
			$$->dst = $2;
			$$->dport = $3;
		}
		;

port		: /* empty */				{ $$ = 0; }
		| PORT portval				{ $$ = $2; }
		;

portval		: STRING				{
			struct servent *s;

			if ((s = getservbyname($1, "tcp")) != NULL ||
			    (s = getservbyname($1, "udp")) != NULL) {
				$$ = s->s_port;
			} else {
				yyerror("unknown port: %s", $1);
				YYERROR;
			}
		}
		| NUMBER				{
			if ($1 > USHRT_MAX || $1 < 0) {
				yyerror("port outside range");
				YYERROR;
			}
			$$ = htons($1);
		}
		;

peers		: /* empty */				{
			$$.dst = NULL;
			$$.src = NULL;
		}
		| PEER anyhost LOCAL anyhost		{
			$$.dst = $2;
			$$.src = $4;
		}
		| LOCAL anyhost PEER anyhost		{
			$$.dst = $4;
			$$.src = $2;
		}
		| PEER anyhost				{
			$$.dst = $2;
			$$.src = NULL;
		}
		| LOCAL anyhost				{
			$$.dst = NULL;
			$$.src = $2;
		}
		;

anyhost		: host_spec			{ $$ = $1; }
		| ANY				{
			$$ = host_any();
		}

host_spec	: STRING			{
			if (($$ = host($1)) == NULL) {
				free($1);
				yyerror("could not parse host specification");
				YYERROR;
			}
			free($1);
		}
		| STRING '/' NUMBER		{
			char	*buf;

			if (asprintf(&buf, "%s/%lld", $1,
			    (long long int)$3) == -1)
				err(1, "host: asprintf");
			free($1);
			if (($$ = host(buf)) == NULL)	{
				free(buf);
				yyerror("could not parse host specification");
				YYERROR;
			}
			free(buf);
		}
		;

host		: host_spec			{ $$ = $1; }
		| host_spec '(' host_spec ')'   {
			if (($1->address.ss_family != AF_UNSPEC) &&
			    ($3->address.ss_family != AF_UNSPEC) &&
			    ($3->address.ss_family != $1->address.ss_family)) {
				yyerror("Flow NAT address family mismatch");
				YYERROR;
			}
			$$ = $1;
			$$->srcnat = $3;
		}
		| ANY				{
			$$ = host_any();
		}
		;

ids		: /* empty */			{
			$$.srcid = NULL;
			$$.dstid = NULL;
		}
		| SRCID id DSTID id		{
			$$.srcid = $2;
			$$.dstid = $4;
		}
		| SRCID id			{
			$$.srcid = $2;
			$$.dstid = NULL;
		}
		| DSTID id			{
			$$.srcid = NULL;
			$$.dstid = $2;
		}
		;

id		: STRING			{ $$ = $1; }
		;

transforms	:					{
			if ((ipsec_transforms = calloc(1,
			    sizeof(struct ipsec_transforms))) == NULL)
				err(1, "transforms: calloc");
		}
		    transforms_l			{
			$$ = ipsec_transforms;
		}
		| /* empty */				{
			$$ = NULL;
		}
		;

transforms_l	: transforms_l transform
		| transform
		;

transform	: AUTHXF STRING			{
			if (ipsec_transforms->authxf)
				yyerror("auth already set");
			else {
				ipsec_transforms->authxf = parse_xf($2, 0,
				    authxfs);
				if (!ipsec_transforms->authxf)
					yyerror("%s not a valid transform", $2);
			}
		}
		| ENCXF STRING			{
			if (ipsec_transforms->encxf)
				yyerror("enc already set");
			else {
				ipsec_transforms->encxf = parse_xf($2, 0,
				    encxfs);
				if (!ipsec_transforms->encxf)
					yyerror("%s not a valid transform",
					    $2);
			}
		}
		| PRFXF STRING			{
			if (ipsec_transforms->prfxf)
				yyerror("prf already set");
			else {
				ipsec_transforms->prfxf = parse_xf($2, 0,
				    prfxfs);
				if (!ipsec_transforms->prfxf)
					yyerror("%s not a valid transform",
					    $2);
			}
		}
		| GROUP STRING			{
			if (ipsec_transforms->groupxf)
				yyerror("group already set");
			else {
				ipsec_transforms->groupxf = parse_xf($2, 0,
				    groupxfs);
				if (!ipsec_transforms->groupxf)
					yyerror("%s not a valid transform",
					    $2);
			}
		}
		;

ike_sa		: /* empty */	{
			$$ = NULL;
		}
		| IKESA		{
			encxfs = ikeencxfs;
		} transforms	{
			if (($$ = calloc(1, sizeof(*$$))) == NULL)
				err(1, "ike_sa: calloc");
			$$->xfs = $3;
		}
		;

child_sa	: /* empty */	{
			$$ = NULL;
		}
		| CHILDSA	{
			encxfs = ipsecencxfs;
		} transforms	{
			if (($$ = calloc(1, sizeof(*$$))) == NULL)
				err(1, "child_sa: calloc");
			$$->xfs = $3;
		}
		;

ikeflags	: ikematch ikemode ipcomp	{ $$ = $1 | $2 | $3; }
		;

ikematch	: /* empty */			{ $$ = 0; }
		| QUICK				{ $$ = IKED_POLICY_QUICK; }
		| SKIP				{ $$ = IKED_POLICY_SKIP; }
		| DEFAULT			{ $$ = IKED_POLICY_DEFAULT; }
		;

ikemode		: /* empty */			{ $$ = IKED_POLICY_PASSIVE; }
		| PASSIVE			{ $$ = IKED_POLICY_PASSIVE; }
		| ACTIVE			{ $$ = IKED_POLICY_ACTIVE; }
		;

ipcomp		: /* empty */			{ $$ = 0; }
		| IPCOMP			{ $$ = IKED_POLICY_IPCOMP; }
		;

ikeauth		: /* empty */			{
			$$.auth_method = IKEV2_AUTH_RSA_SIG;
			$$.auth_length = 0;
		}
		| RSA				{
			$$.auth_method = IKEV2_AUTH_RSA_SIG;
			$$.auth_length = 0;
		}
		| PSK keyspec			{
			memcpy(&$$, &$2, sizeof($$));
			$$.auth_method = IKEV2_AUTH_SHARED_KEY_MIC;
		}
		| EAP STRING			{
			unsigned int i;

			for (i = 0; i < strlen($2); i++)
				if ($2[i] == '-')
					$2[i] = '_';

			if (strcasecmp("mschap_v2", $2) != 0) {
				yyerror("unsupported EAP method: %s", $2);
				free($2);
				YYERROR;
			}
			free($2);

			$$.auth_method = IKEV2_AUTH_RSA_SIG;
			$$.auth_eap = EAP_TYPE_MSCHAP_V2;
			$$.auth_length = 0;
		}
		;

byte_spec	: NUMBER			{
			$$ = $1;
		}
		| STRING			{
			uint64_t	 bytes = 0;
			char		 unit = 0;

			if (sscanf($1, "%llu%c", &bytes, &unit) != 2) {
				yyerror("invalid byte specification: %s", $1);
				YYERROR;
			}
			switch (toupper((unsigned char)unit)) {
			case 'K':
				bytes *= 1024;
				break;
			case 'M':
				bytes *= 1024 * 1024;
				break;
			case 'G':
				bytes *= 1024 * 1024 * 1024;
				break;
			default:
				yyerror("invalid byte unit");
				YYERROR;
			}
			$$ = bytes;
		}
		;

time_spec	: NUMBER			{
			$$ = $1;
		}
		| STRING			{
			uint64_t	 seconds = 0;
			char		 unit = 0;

			if (sscanf($1, "%llu%c", &seconds, &unit) != 2) {
				yyerror("invalid time specification: %s", $1);
				YYERROR;
			}
			switch (tolower((unsigned char)unit)) {
			case 'm':
				seconds *= 60;
				break;
			case 'h':
				seconds *= 60 * 60;
				break;
			default:
				yyerror("invalid time unit");
				YYERROR;
			}
			$$ = seconds;
		}
		;

lifetime	: /* empty */				{
			$$ = deflifetime;
		}
		| LIFETIME time_spec			{
			$$.lt_seconds = $2;
			$$.lt_bytes = deflifetime.lt_bytes;
		}
		| LIFETIME time_spec BYTES byte_spec	{
			$$.lt_seconds = $2;
			$$.lt_bytes = $4;
		}
		;

ikelifetime	: /* empty */				{
			$$ = 0;
		}
		| IKELIFETIME time_spec			{
			$$ = $2;
		}

keyspec		: STRING			{
			uint8_t		*hex;

			bzero(&$$, sizeof($$));

			hex = $1;
			if (strncmp(hex, "0x", 2) == 0) {
				hex += 2;
				if (parsekey(hex, strlen(hex), &$$) != 0) {
					free($1);
					YYERROR;
				}
			} else {
				if (strlen($1) > sizeof($$.auth_data)) {
					yyerror("psk too long");
					free($1);
					YYERROR;
				}
				strlcpy($$.auth_data, $1,
				    sizeof($$.auth_data));
				$$.auth_length = strlen($1);
			}
			free($1);
		}
		| FILENAME STRING		{
			if (parsekeyfile($2, &$$) != 0) {
				free($2);
				YYERROR;
			}
			free($2);
		}
		;

filters		:					{
			if ((ipsec_filters = calloc(1,
			    sizeof(struct ipsec_filters))) == NULL)
				err(1, "filters: calloc");
		}
		    filters_l			{
			$$ = ipsec_filters;
		}
		| /* empty */				{
			$$ = NULL;
		}
		;

filters_l	: filters_l filter
		| filter
		;

filter		: TAG STRING
		{
			ipsec_filters->tag = $2;
		}
		| TAP STRING
		{
			const char	*errstr = NULL;
			size_t		 len;

			len = strcspn($2, "0123456789");
			if (strlen("enc") != len ||
			    strncmp("enc", $2, len) != 0) {
				yyerror("invalid tap interface name: %s", $2);
				free($2);
				YYERROR;
			}
			ipsec_filters->tap =
			    strtonum($2 + len, 0, UINT_MAX, &errstr);
			free($2);
			if (errstr != NULL) {
				yyerror("invalid tap interface unit: %s",
				    errstr);
				YYERROR;
			}
		}
		;

string		: string STRING
		{
			if (asprintf(&$$, "%s %s", $1, $2) == -1)
				err(1, "string: asprintf");
			free($1);
			free($2);
		}
		| STRING
		;

varset		: STRING '=' string
		{
			log_debug("%s = \"%s\"\n", $1, $3);
			if (symset($1, $3, 0) == -1)
				err(1, "cannot store variable");
			free($1);
			free($3);
		}
		;

/*
 * ignore IKEv1/manual keying rules in ipsec.conf
 */
otherrule	: IKEV1
		| sarule
		| FLOW
		| TCPMD5
		;

/* manual keying SAs might start with the following keywords */
sarule		: SA
		| FROM
		| TO
		| TUNNEL
		| TRANSPORT
		;

/* ignore everything to the end of the line */
skipline	:
		{
			int	 c;

			while ((c = lgetc(0)) != '\n' && c != EOF)
				; /* nothing */
			if (c == '\n')
				lungetc(c);
		}
		;
%%

struct keywords {
	const char	*k_name;
	int		 k_val;
};

int
yyerror(const char *fmt, ...)
{
	va_list		 ap;

	file->errors++;
	va_start(ap, fmt);
	fprintf(stderr, "%s: %d: ", file->name, yylval.lineno);
	vfprintf(stderr, fmt, ap);
	fprintf(stderr, "\n");
	va_end(ap);
	return (0);
}

int
kw_cmp(const void *k, const void *e)
{
	return (strcmp(k, ((const struct keywords *)e)->k_name));
}

int
lookup(char *s)
{
	/* this has to be sorted always */
	static const struct keywords keywords[] = {
		{ "active",		ACTIVE },
		{ "ah",			AH },
		{ "any",		ANY },
		{ "auth",		AUTHXF },
		{ "bytes",		BYTES },
		{ "childsa",		CHILDSA },
		{ "config",		CONFIG },
		{ "couple",		COUPLE },
		{ "decouple",		DECOUPLE },
		{ "default",		DEFAULT },
		{ "dstid",		DSTID },
		{ "eap",		EAP },
		{ "enc",		ENCXF },
		{ "esp",		ESP },
		{ "file",		FILENAME },
		{ "flow",		FLOW },
		{ "from",		FROM },
		{ "group",		GROUP },
		{ "ike",		IKEV1 },
		{ "ikelifetime",	IKELIFETIME },
		{ "ikesa",		IKESA },
		{ "ikev2",		IKEV2 },
		{ "include",		INCLUDE },
		{ "inet",		INET },
		{ "inet6",		INET6 },
		{ "ipcomp",		IPCOMP },
		{ "lifetime",		LIFETIME },
		{ "local",		LOCAL },
		{ "name",		NAME },
		{ "ocsp",		OCSP },
		{ "passive",		PASSIVE },
		{ "peer",		PEER },
		{ "port",		PORT },
		{ "prf",		PRFXF },
		{ "proto",		PROTO },
		{ "psk",		PSK },
		{ "quick",		QUICK },
		{ "rsa",		RSA },
		{ "sa",			SA },
		{ "set",		SET },
		{ "skip",		SKIP },
		{ "srcid",		SRCID },
		{ "tag",		TAG },
		{ "tap",		TAP },
		{ "tcpmd5",		TCPMD5 },
		{ "to",			TO },
		{ "transport",		TRANSPORT },
		{ "tunnel",		TUNNEL },
		{ "user",		USER }
	};
	const struct keywords	*p;

	p = bsearch(s, keywords, sizeof(keywords)/sizeof(keywords[0]),
	    sizeof(keywords[0]), kw_cmp);

	if (p) {
		if (debug > 1)
			fprintf(stderr, "%s: %d\n", s, p->k_val);
		return (p->k_val);
	} else {
		if (debug > 1)
			fprintf(stderr, "string: %s\n", s);
		return (STRING);
	}
}

#define MAXPUSHBACK	128

unsigned char	*parsebuf;
int		 parseindex;
unsigned char	 pushback_buffer[MAXPUSHBACK];
int		 pushback_index = 0;

int
lgetc(int quotec)
{
	int		c, next;

	if (parsebuf) {
		/* Read character from the parsebuffer instead of input. */
		if (parseindex >= 0) {
			c = parsebuf[parseindex++];
			if (c != '\0')
				return (c);
			parsebuf = NULL;
		} else
			parseindex++;
	}

	if (pushback_index)
		return (pushback_buffer[--pushback_index]);

	if (quotec) {
		if ((c = getc(file->stream)) == EOF) {
			yyerror("reached end of file while parsing "
			    "quoted string");
			if (popfile() == EOF)
				return (EOF);
			return (quotec);
		}
		return (c);
	}

	while ((c = getc(file->stream)) == '\\') {
		next = getc(file->stream);
		if (next != '\n') {
			c = next;
			break;
		}
		yylval.lineno = file->lineno;
		file->lineno++;
	}

	while (c == EOF) {
		if (popfile() == EOF)
			return (EOF);
		c = getc(file->stream);
	}
	return (c);
}

int
lungetc(int c)
{
	if (c == EOF)
		return (EOF);
	if (parsebuf) {
		parseindex--;
		if (parseindex >= 0)
			return (c);
	}
	if (pushback_index < MAXPUSHBACK-1)
		return (pushback_buffer[pushback_index++] = c);
	else
		return (EOF);
}

int
findeol(void)
{
	int	c;

	parsebuf = NULL;

	/* skip to either EOF or the first real EOL */
	while (1) {
		if (pushback_index)
			c = pushback_buffer[--pushback_index];
		else
			c = lgetc(0);
		if (c == '\n') {
			file->lineno++;
			break;
		}
		if (c == EOF)
			break;
	}
	return (ERROR);
}

int
yylex(void)
{
	unsigned char	 buf[8096];
	unsigned char	*p, *val;
	int		 quotec, next, c;
	int		 token;

top:
	p = buf;
	while ((c = lgetc(0)) == ' ' || c == '\t')
		; /* nothing */

	yylval.lineno = file->lineno;
	if (c == '#')
		while ((c = lgetc(0)) != '\n' && c != EOF)
			; /* nothing */
	if (c == '$' && parsebuf == NULL) {
		while (1) {
			if ((c = lgetc(0)) == EOF)
				return (0);

			if (p + 1 >= buf + sizeof(buf) - 1) {
				yyerror("string too long");
				return (findeol());
			}
			if (isalnum(c) || c == '_') {
				*p++ = c;
				continue;
			}
			*p = '\0';
			lungetc(c);
			break;
		}
		val = symget(buf);
		if (val == NULL) {
			yyerror("macro '%s' not defined", buf);
			return (findeol());
		}
		parsebuf = val;
		parseindex = 0;
		goto top;
	}

	switch (c) {
	case '\'':
	case '"':
		quotec = c;
		while (1) {
			if ((c = lgetc(quotec)) == EOF)
				return (0);
			if (c == '\n') {
				file->lineno++;
				continue;
			} else if (c == '\\') {
				if ((next = lgetc(quotec)) == EOF)
					return (0);
				if (next == quotec || c == ' ' || c == '\t')
					c = next;
				else if (next == '\n') {
					file->lineno++;
					continue;
				} else
					lungetc(next);
			} else if (c == quotec) {
				*p = '\0';
				break;
			} else if (c == '\0') {
				yyerror("syntax error");
				return (findeol());
			}
			if (p + 1 >= buf + sizeof(buf) - 1) {
				yyerror("string too long");
				return (findeol());
			}
			*p++ = c;
		}
		yylval.v.string = strdup(buf);
		if (yylval.v.string == NULL)
			err(1, "yylex: strdup");
		return (STRING);
	}

#define allowed_to_end_number(x) \
	(isspace(x) || x == ')' || x ==',' || x == '/' || x == '}' || x == '=')

	if (c == '-' || isdigit(c)) {
		do {
			*p++ = c;
			if ((unsigned)(p-buf) >= sizeof(buf)) {
				yyerror("string too long");
				return (findeol());
			}
		} while ((c = lgetc(0)) != EOF && isdigit(c));
		lungetc(c);
		if (p == buf + 1 && buf[0] == '-')
			goto nodigits;
		if (c == EOF || allowed_to_end_number(c)) {
			const char *errstr = NULL;

			*p = '\0';
			yylval.v.number = strtonum(buf, LLONG_MIN,
			    LLONG_MAX, &errstr);
			if (errstr) {
				yyerror("\"%s\" invalid number: %s",
				    buf, errstr);
				return (findeol());
			}
			return (NUMBER);
		} else {
nodigits:
			while (p > buf + 1)
				lungetc(*--p);
			c = *--p;
			if (c == '-')
				return (c);
		}
	}

#define allowed_in_string(x) \
	(isalnum(x) || (ispunct(x) && x != '(' && x != ')' && \
	x != '{' && x != '}' && x != '<' && x != '>' && \
	x != '!' && x != '=' && x != '/' && x != '#' && \
	x != ','))

	if (isalnum(c) || c == ':' || c == '_' || c == '*') {
		do {
			*p++ = c;
			if ((unsigned)(p-buf) >= sizeof(buf)) {
				yyerror("string too long");
				return (findeol());
			}
		} while ((c = lgetc(0)) != EOF && (allowed_in_string(c)));
		lungetc(c);
		*p = '\0';
		if ((token = lookup(buf)) == STRING)
			if ((yylval.v.string = strdup(buf)) == NULL)
				err(1, "yylex: strdup");
		return (token);
	}
	if (c == '\n') {
		yylval.lineno = file->lineno;
		file->lineno++;
	}
	if (c == EOF)
		return (0);
	return (c);
}

int
check_file_secrecy(int fd, const char *fname)
{
	struct stat	st;

	if (fstat(fd, &st)) {
		warn("cannot stat %s", fname);
		return (-1);
	}
	if (st.st_uid != 0 && st.st_uid != getuid()) {
		warnx("%s: owner not root or current user", fname);
		return (-1);
	}
	if (st.st_mode & (S_IWGRP | S_IXGRP | S_IRWXO)) {
		warnx("%s: group writable or world read/writable", fname);
		return (-1);
	}
	return (0);
}

struct file *
pushfile(const char *name, int secret)
{
	struct file	*nfile;

	if ((nfile = calloc(1, sizeof(struct file))) == NULL) {
		warn("malloc");
		return (NULL);
	}
	if ((nfile->name = strdup(name)) == NULL) {
		warn("malloc");
		free(nfile);
		return (NULL);
	}
	if (TAILQ_FIRST(&files) == NULL && strcmp(nfile->name, "-") == 0) {
		nfile->stream = stdin;
		free(nfile->name);
		if ((nfile->name = strdup("stdin")) == NULL) {
			warn("strdup");
			free(nfile);
			return (NULL);
		}
	} else if ((nfile->stream = fopen(nfile->name, "r")) == NULL) {
		warn("%s", nfile->name);
		free(nfile->name);
		free(nfile);
		return (NULL);
	} else if (secret &&
	    check_file_secrecy(fileno(nfile->stream), nfile->name)) {
		fclose(nfile->stream);
		free(nfile->name);
		free(nfile);
		return (NULL);
	}
	nfile->lineno = 1;
	TAILQ_INSERT_TAIL(&files, nfile, entry);
	return (nfile);
}

int
popfile(void)
{
	struct file	*prev;

	if ((prev = TAILQ_PREV(file, files, entry)) != NULL) {
		prev->errors += file->errors;
		TAILQ_REMOVE(&files, file, entry);
		fclose(file->stream);
		free(file->name);
		free(file);
		file = prev;
		return (0);
	}
	return (EOF);
}

int
parse_config(const char *filename, struct iked *x_env)
{
	struct sym	*sym;
	int		 errors = 0;

	env = x_env;
	rules = 0;

	if ((file = pushfile(filename, 1)) == NULL)
		return (-1);

	decouple = passive = 0;

	if (env->sc_opts & IKED_OPT_PASSIVE)
		passive = 1;

	yyparse();
	errors = file->errors;
	popfile();

	env->sc_passive = passive ? 1 : 0;
	env->sc_decoupled = decouple ? 1 : 0;
	env->sc_ocsp_url = ocsp_url;

	if (!rules)
		log_warnx("%s: no valid configuration rules found",
		    filename);
	else
		log_debug("%s: loaded %d configuration rules",
		    filename, rules);

	/* Free macros and check which have not been used. */
	while ((sym = TAILQ_FIRST(&symhead))) {
		if (!sym->used)
			log_debug("warning: macro '%s' not "
			    "used\n", sym->nam);
		free(sym->nam);
		free(sym->val);
		TAILQ_REMOVE(&symhead, sym, entry);
		free(sym);
	}

	return (errors ? -1 : 0);
}

int
symset(const char *nam, const char *val, int persist)
{
	struct sym	*sym;

	for (sym = TAILQ_FIRST(&symhead); sym && strcmp(nam, sym->nam);
	    sym = TAILQ_NEXT(sym, entry))
		;	/* nothing */

	if (sym != NULL) {
		if (sym->persist == 1)
			return (0);
		else {
			free(sym->nam);
			free(sym->val);
			TAILQ_REMOVE(&symhead, sym, entry);
			free(sym);
		}
	}
	if ((sym = calloc(1, sizeof(*sym))) == NULL)
		return (-1);

	sym->nam = strdup(nam);
	if (sym->nam == NULL) {
		free(sym);
		return (-1);
	}
	sym->val = strdup(val);
	if (sym->val == NULL) {
		free(sym->nam);
		free(sym);
		return (-1);
	}
	sym->used = 0;
	sym->persist = persist;
	TAILQ_INSERT_TAIL(&symhead, sym, entry);
	return (0);
}

int
cmdline_symset(char *s)
{
	char	*sym, *val;
	int	ret;
	size_t	len;

	if ((val = strrchr(s, '=')) == NULL)
		return (-1);

	len = strlen(s) - strlen(val) + 1;
	if ((sym = malloc(len)) == NULL)
		err(1, "cmdline_symset: malloc");

	strlcpy(sym, s, len);

	ret = symset(sym, val + 1, 1);
	free(sym);

	return (ret);
}

char *
symget(const char *nam)
{
	struct sym	*sym;

	TAILQ_FOREACH(sym, &symhead, entry)
		if (strcmp(nam, sym->nam) == 0) {
			sym->used = 1;
			return (sym->val);
		}
	return (NULL);
}

uint8_t
x2i(unsigned char *s)
{
	char	ss[3];

	ss[0] = s[0];
	ss[1] = s[1];
	ss[2] = 0;

	if (!isxdigit(s[0]) || !isxdigit(s[1])) {
		yyerror("keys need to be specified in hex digits");
		return (-1);
	}
	return ((uint8_t)strtoul(ss, NULL, 16));
}

int
parsekey(unsigned char *hexkey, size_t len, struct iked_auth *auth)
{
	unsigned int	  i;

	bzero(auth, sizeof(*auth));
	if ((len / 2) > sizeof(auth->auth_data))
		return (-1);
	auth->auth_length = len / 2;

	for (i = 0; i < auth->auth_length; i++)
		auth->auth_data[i] = x2i(hexkey + 2 * i);

	return (0);
}

int
parsekeyfile(char *filename, struct iked_auth *auth)
{
	struct stat	 sb;
	int		 fd, ret;
	unsigned char	*hex;

	if ((fd = open(filename, O_RDONLY)) < 0)
		err(1, "open %s", filename);
	if (fstat(fd, &sb) < 0)
		err(1, "parsekeyfile: stat %s", filename);
	if ((sb.st_size > KEYSIZE_LIMIT) || (sb.st_size == 0))
		errx(1, "%s: key too %s", filename, sb.st_size ? "large" :
		    "small");
	if ((hex = calloc(sb.st_size, sizeof(unsigned char))) == NULL)
		err(1, "parsekeyfile: calloc");
	if (read(fd, hex, sb.st_size) < sb.st_size)
		err(1, "parsekeyfile: read");
	close(fd);
	ret = parsekey(hex, sb.st_size, auth);
	free(hex);
	return (ret);
}

int
get_id_type(char *string)
{
	struct in6_addr ia;

	if (string == NULL)
		return (IKEV2_ID_NONE);

	if (*string == '/')
		return (IKEV2_ID_ASN1_DN);
	else if (inet_pton(AF_INET, string, &ia) == 1)
		return (IKEV2_ID_IPV4);
	else if (inet_pton(AF_INET6, string, &ia) == 1)
		return (IKEV2_ID_IPV6);
	else if (strchr(string, '@'))
		return (IKEV2_ID_UFQDN);
	else
		return (IKEV2_ID_FQDN);
}

int
check_pubkey(char *idstr, int type)
{
	char		 keyfile[PATH_MAX];
	FILE		*fp = NULL;
	const char	*suffix = NULL;

	switch (type) {
	case IKEV2_ID_IPV4:
		suffix = "ipv4";
		break;
	case IKEV2_ID_IPV6:
		suffix = "ipv6";
		break;
	case IKEV2_ID_FQDN:
		suffix = "fqdn";
		break;
	case IKEV2_ID_UFQDN:
		suffix = "ufqdn";
		break;
	default:
		/* Unspecified ID or public key not supported for this type */
		return (-1);
	}

	lc_string(idstr);
	if ((size_t)snprintf(keyfile, sizeof(keyfile),
	    IKED_CA IKED_PUBKEY_DIR "%s/%s", suffix,
	    idstr) >= sizeof(keyfile)) {
		log_warnx("%s: public key path is too long", __func__);
		return (-1);
	}

	if ((fp = fopen(keyfile, "r")) == NULL)
		return (-1);
	fclose(fp);

	log_debug("%s: found public key file %s", __func__, keyfile);

	return (0);
}

struct ipsec_addr_wrap *
host(const char *s)
{
	struct ipsec_addr_wrap	*ipa = NULL;
	int			 mask, cont = 1;
	char			*p, *q, *ps;

	if ((p = strrchr(s, '/')) != NULL) {
		errno = 0;
		mask = strtol(p + 1, &q, 0);
		if (errno == ERANGE || !q || *q || mask > 128 || q == (p + 1))
			errx(1, "host: invalid netmask '%s'", p);
		if ((ps = malloc(strlen(s) - strlen(p) + 1)) == NULL)
			err(1, "host: calloc");
		strlcpy(ps, s, strlen(s) - strlen(p) + 1);
	} else {
		if ((ps = strdup(s)) == NULL)
			err(1, "host: strdup");
		mask = -1;
	}

	/* Does interface with this name exist? */
	if (cont && (ipa = host_if(ps, mask)) != NULL)
		cont = 0;

	/* IPv4 address? */
	if (cont && (ipa = host_v4(s, mask == -1 ? 32 : mask)) != NULL)
		cont = 0;

	/* IPv6 address? */
	if (cont && (ipa = host_v6(ps, mask == -1 ? 128 : mask)) != NULL)
		cont = 0;

	/* dns lookup */
	if (cont && mask == -1 && (ipa = host_dns(s, mask)) != NULL)
		cont = 0;
	free(ps);

	if (ipa == NULL || cont == 1) {
		fprintf(stderr, "no IP address found for %s\n", s);
		return (NULL);
	}
	return (ipa);
}

struct ipsec_addr_wrap *
host_v6(const char *s, int prefixlen)
{
	struct ipsec_addr_wrap	*ipa = NULL;
	struct addrinfo		 hints, *res;
	char			 hbuf[NI_MAXHOST];

	bzero(&hints, sizeof(struct addrinfo));
	hints.ai_family = AF_INET6;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_NUMERICHOST;
	if (getaddrinfo(s, NULL, &hints, &res))
		return (NULL);
	if (res->ai_next)
		err(1, "host_v6: numeric hostname expanded to multiple item");

	ipa = calloc(1, sizeof(struct ipsec_addr_wrap));
	if (ipa == NULL)
		err(1, "host_v6: calloc");
	memcpy(&ipa->address, res->ai_addr, sizeof(struct sockaddr_in6));
	ipa->address.ss_family = res->ai_family;
	SET_SS_LEN(&ipa->address, sizeof(struct sockaddr_in6));
	if (prefixlen > 128)
		prefixlen = 128;
	ipa->next = NULL;
	ipa->tail = ipa;

	set_ipmask(ipa, prefixlen);
	if (getnameinfo(res->ai_addr, res->ai_addrlen,
	    hbuf, sizeof(hbuf), NULL, 0, NI_NUMERICHOST)) {
		errx(1, "could not get a numeric hostname");
	}

	if (prefixlen != 128) {
		ipa->netaddress = 1;
		if (asprintf(&ipa->name, "%s/%d", hbuf, prefixlen) == -1)
			err(1, "host_v6: asprintf");
	} else {
		if ((ipa->name = strdup(hbuf)) == NULL)
			err(1, "host_v6: strdup");
	}

	freeaddrinfo(res);

	return (ipa);
}

struct ipsec_addr_wrap *
host_v4(const char *s, int mask)
{
	struct ipsec_addr_wrap	*ipa = NULL;
	struct sockaddr_in	 ina;
	int			 bits = 32;

	bzero(&ina, sizeof(ina));
	if (strrchr(s, '/') != NULL) {
		if ((bits = inet_net_pton(AF_INET, s, &ina.sin_addr,
		    sizeof(ina.sin_addr))) == -1)
			return (NULL);
	} else {
		if (inet_pton(AF_INET, s, &ina.sin_addr) != 1)
			return (NULL);
	}

	ipa = calloc(1, sizeof(struct ipsec_addr_wrap));
	if (ipa == NULL)
		err(1, "host_v4: calloc");

	memcpy(&ipa->address, &ina, sizeof(ina));
	ipa->address.ss_family = AF_INET;
	SET_SS_LEN(&ipa->address, sizeof(ina));

	ipa->name = strdup(s);
	if (ipa->name == NULL)
		err(1, "host_v4: strdup");
	ipa->next = NULL;
	ipa->tail = ipa;

	set_ipmask(ipa, bits);
	if (strrchr(s, '/') != NULL)
		ipa->netaddress = 1;

	return (ipa);
}

struct ipsec_addr_wrap *
host_dns(const char *s, int mask)
{
	struct ipsec_addr_wrap	*ipa = NULL, *head = NULL;
	struct addrinfo		 hints, *res0, *res;
	int			 error, sslen;
	char			 hbuf[NI_MAXHOST];

	bzero(&hints, sizeof(struct addrinfo));
	hints.ai_family = PF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_ADDRCONFIG;
	error = getaddrinfo(s, NULL, &hints, &res0);
	if (error)
		return (NULL);

	for (res = res0; res; res = res->ai_next) {
		if (res->ai_family != AF_INET && res->ai_family != AF_INET6)
			continue;

		ipa = calloc(1, sizeof(struct ipsec_addr_wrap));
		if (ipa == NULL)
			err(1, "host_dns: calloc");
		switch (res->ai_family) {
		case AF_INET:
			sslen = sizeof(struct sockaddr_in);
			break;
		case AF_INET6:
			sslen = sizeof(struct sockaddr_in6);
			break;
		default:
			sslen = 0;
			break;
		}
		if (sslen > 0)
			memcpy(&ipa->address, res->ai_addr, sslen);
		ipa->address.ss_family = res->ai_family;
		SET_SS_LEN(&ipa->address, sslen);
		error = getnameinfo((struct sockaddr *)&ipa->address, sslen,
		    hbuf, sizeof(hbuf), NULL, 0, NI_NUMERICHOST);
		if (error)
			err(1, "host_dns: getnameinfo");
		ipa->name = strdup(hbuf);
		if (ipa->name == NULL)
			err(1, "host_dns: strdup");
		ipa->next = NULL;
		ipa->tail = ipa;
		if (head == NULL)
			head = ipa;
		else {
			head->tail->next = ipa;
			head->tail = ipa;
		}

		/*
		 * XXX for now, no netmask support for IPv6.
		 * but since there's no way to specify address family, once you
		 * have IPv6 address on a host, you cannot use dns/netmask
		 * syntax.
		 */
		if (ipa->address.ss_family == AF_INET)
			set_ipmask(ipa, mask == -1 ? 32 : mask);
		else
			if (mask != -1)
				err(1, "host_dns: cannot apply netmask "
				    "on non-IPv4 address");
	}
	freeaddrinfo(res0);

	return (head);
}

struct ipsec_addr_wrap *
host_if(const char *s, int mask)
{
	struct ipsec_addr_wrap *ipa = NULL;

	if (ifa_exists(s))
		ipa = ifa_lookup(s);

	return (ipa);
}

struct ipsec_addr_wrap *
host_any(void)
{
	struct ipsec_addr_wrap	*ipa;

	ipa = calloc(1, sizeof(struct ipsec_addr_wrap));
	if (ipa == NULL)
		err(1, "host_any: calloc");
	ipa->address.ss_family = AF_UNSPEC;
	ipa->netaddress = 1;
	ipa->tail = ipa;
	return (ipa);
}

/* interface lookup routintes */

struct ipsec_addr_wrap	*iftab;

void
ifa_load(void)
{
	struct ifaddrs		*ifap, *ifa;
	struct ipsec_addr_wrap	*n = NULL, *h = NULL;
	struct sockaddr_in	*sa_in;
	struct sockaddr_in6	*sa_in6;

	if (getifaddrs(&ifap) < 0)
		err(1, "ifa_load: getifaddrs");

	for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
		if (!(ifa->ifa_addr->sa_family == AF_INET ||
		    ifa->ifa_addr->sa_family == AF_INET6 ||
		    ifa->ifa_addr->sa_family == AF_LINK))
			continue;
		n = calloc(1, sizeof(struct ipsec_addr_wrap));
		if (n == NULL)
			err(1, "ifa_load: calloc");
		n->address.ss_family = ifa->ifa_addr->sa_family;
		SET_SS_LEN(&n->address, SA_LEN(ifa->ifa_addr));
		if ((n->name = strdup(ifa->ifa_name)) == NULL)
			err(1, "ifa_load: strdup");
		if (n->address.ss_family == AF_INET) {
			sa_in = (struct sockaddr_in *)ifa->ifa_addr;
			memcpy(&n->address, sa_in, sizeof(*sa_in));
			sa_in = (struct sockaddr_in *)ifa->ifa_netmask;
			n->mask = mask2prefixlen((struct sockaddr *)sa_in);
		} else if (n->address.ss_family == AF_INET6) {
			sa_in6 = (struct sockaddr_in6 *)ifa->ifa_addr;
			memcpy(&n->address, sa_in6, sizeof(*sa_in6));
			sa_in6 = (struct sockaddr_in6 *)ifa->ifa_netmask;
			n->mask = mask2prefixlen6((struct sockaddr *)sa_in6);
		}
		n->next = NULL;
		n->tail = n;
		if (h == NULL)
			h = n;
		else {
			h->tail->next = n;
			h->tail = n;
		}
	}

	iftab = h;
	freeifaddrs(ifap);
}

int
ifa_exists(const char *ifa_name)
{
	struct ipsec_addr_wrap	*n;
#if defined(SIOCGIFGMEMB)
	struct ifgroupreq	 ifgr;
	int			 s;
#endif

	if (iftab == NULL)
		ifa_load();

#if defined(SIOCGIFGMEMB)
	/* check wether this is a group */
	if ((s = socket(AF_INET, SOCK_DGRAM, 0)) == -1)
		err(1, "ifa_exists: socket");
	bzero(&ifgr, sizeof(ifgr));
	strlcpy(ifgr.ifgr_name, ifa_name, sizeof(ifgr.ifgr_name));
	if (ioctl(s, SIOCGIFGMEMB, (caddr_t)&ifgr) == 0) {
		close(s);
		return (1);
	}
	close(s);
#endif

	for (n = iftab; n; n = n->next) {
		if (n->address.ss_family == AF_LINK &&
		    !strncmp(n->name, ifa_name, IFNAMSIZ))
			return (1);
	}

	return (0);
}

struct ipsec_addr_wrap *
ifa_grouplookup(const char *ifa_name)
{
#if defined(SIOCGIFGMEMB)
	struct ifg_req		*ifg;
	struct ifgroupreq	 ifgr;
	int			 s;
	size_t			 len;
	struct ipsec_addr_wrap	*n, *h = NULL, *hn;

	if ((s = socket(AF_INET, SOCK_DGRAM, 0)) == -1)
		err(1, "socket");
	bzero(&ifgr, sizeof(ifgr));
	strlcpy(ifgr.ifgr_name, ifa_name, sizeof(ifgr.ifgr_name));
	if (ioctl(s, SIOCGIFGMEMB, (caddr_t)&ifgr) == -1) {
		close(s);
		return (NULL);
	}

	len = ifgr.ifgr_len;
	if ((ifgr.ifgr_groups = calloc(1, len)) == NULL)
		err(1, "calloc");
	if (ioctl(s, SIOCGIFGMEMB, (caddr_t)&ifgr) == -1)
		err(1, "ioctl");

	for (ifg = ifgr.ifgr_groups; ifg && len >= sizeof(struct ifg_req);
	    ifg++) {
		len -= sizeof(struct ifg_req);
		if ((n = ifa_lookup(ifg->ifgrq_member)) == NULL)
			continue;
		if (h == NULL)
			h = n;
		else {
			for (hn = h; hn->next != NULL; hn = hn->next)
				;	/* nothing */
			hn->next = n;
			n->tail = hn;
		}
	}
	free(ifgr.ifgr_groups);
	close(s);
	return (h);
#else
	return (NULL);
#endif
}

struct ipsec_addr_wrap *
ifa_lookup(const char *ifa_name)
{
	struct ipsec_addr_wrap	*p = NULL, *h = NULL, *n = NULL;
	struct sockaddr_in6	*in6;
	uint8_t			*s6;

	if (iftab == NULL)
		ifa_load();

	if ((n = ifa_grouplookup(ifa_name)) != NULL)
		return (n);

	for (p = iftab; p; p = p->next) {
		if (p->address.ss_family != AF_INET &&
		    p->address.ss_family != AF_INET6)
			continue;
		if (strncmp(p->name, ifa_name, IFNAMSIZ))
			continue;
		n = calloc(1, sizeof(struct ipsec_addr_wrap));
		if (n == NULL)
			err(1, "ifa_lookup: calloc");
		memcpy(n, p, sizeof(struct ipsec_addr_wrap));
		if ((n->name = strdup(p->name)) == NULL)
			err(1, "ifa_lookup: strdup");
		switch (n->address.ss_family) {
		case AF_INET:
			set_ipmask(n, 32);
			break;
		case AF_INET6:
			in6 = (struct sockaddr_in6 *)&n->address;
			s6 = (uint8_t *)&in6->sin6_addr.s6_addr;

			/* route/show.c and bgpd/util.c give KAME credit */
			if (IN6_IS_ADDR_LINKLOCAL(&in6->sin6_addr)) {
				uint16_t	 tmp16;

				/* for now we can not handle link local,
				 * therefore bail for now
				 */
				free(n);
				continue;

				memcpy(&tmp16, &s6[2], sizeof(tmp16));
				/* use this when we support link-local
				 * n->??.scopeid = ntohs(tmp16);
				 */
				s6[2] = 0;
				s6[3] = 0;
			}
			set_ipmask(n, 128);
			break;
		}

		n->next = NULL;
		n->tail = n;
		if (h == NULL)
			h = n;
		else {
			h->tail->next = n;
			h->tail = n;
		}
	}

	return (h);
}

void
set_ipmask(struct ipsec_addr_wrap *address, uint8_t b)
{
	address->mask = b;
}

const struct ipsec_xf *
parse_xf(const char *name, unsigned int length, const struct ipsec_xf xfs[])
{
	int		i;

	for (i = 0; xfs[i].name != NULL; i++) {
		if (strncmp(name, xfs[i].name, strlen(name)))
			continue;
		if (length == 0 || length == xfs[i].length)
			return &xfs[i];
	}
	return (NULL);
}

const char *
print_xf(unsigned int id, unsigned int length, const struct ipsec_xf xfs[])
{
	int		i;

	for (i = 0; xfs[i].name != NULL; i++) {
		if (xfs[i].id == id) {
			if (length == 0 || length == xfs[i].length)
				return (xfs[i].name);
		}
	}
	return ("unknown");
}

size_t
keylength_xf(unsigned int saproto, unsigned int type, unsigned int id)
{
	int			 i;
	const struct ipsec_xf	*xfs;

	switch (type) {
	case IKEV2_XFORMTYPE_ENCR:
		if (saproto == IKEV2_SAPROTO_IKE)
			xfs = ikeencxfs;
		else
			xfs = ipsecencxfs;
		break;
	case IKEV2_XFORMTYPE_INTEGR:
		xfs = authxfs;
		break;
	default:
		return (0);
	}

	for (i = 0; xfs[i].name != NULL; i++) {
		if (xfs[i].id == id)
			return (xfs[i].length * 8);
	}
	return (0);
}

size_t
noncelength_xf(unsigned int type, unsigned int id)
{
	const struct ipsec_xf	*xfs = ipsecencxfs;
	int			 i;

	if (type != IKEV2_XFORMTYPE_ENCR)
		return (0);

	for (i = 0; xfs[i].name != NULL; i++)
		if (xfs[i].id == id)
			return (xfs[i].nonce * 8);
	return (0);
}

void
print_user(struct iked_user *usr)
{
	print_verbose("user \"%s\" \"%s\"\n", usr->usr_name, usr->usr_pass);
}

void
print_policy(struct iked_policy *pol)
{
	struct iked_proposal	*pp;
	struct iked_transform	*xform;
	struct iked_flow	*flow;
	struct iked_cfg		*cfg;
	unsigned int		 i, j;
	const struct ipsec_xf	*xfs = NULL;

	print_verbose("ikev2");

	if (pol->pol_name[0] != '\0')
		print_verbose(" \"%s\"", pol->pol_name);

	if (pol->pol_flags & IKED_POLICY_DEFAULT)
		print_verbose(" default");
	else if (pol->pol_flags & IKED_POLICY_QUICK)
		print_verbose(" quick");
	else if (pol->pol_flags & IKED_POLICY_SKIP)
		print_verbose(" skip");

	if (pol->pol_flags & IKED_POLICY_ACTIVE)
		print_verbose(" active");
	else
		print_verbose(" passive");

	print_verbose(" %s", print_xf(pol->pol_saproto, 0, saxfs));

	if (pol->pol_ipproto)
		print_verbose(" proto %s", print_proto(pol->pol_ipproto));

	if (pol->pol_af) {
		if (pol->pol_af == AF_INET)
			print_verbose(" inet");
		else
			print_verbose(" inet6");
	}

	RB_FOREACH(flow, iked_flows, &pol->pol_flows) {
		print_verbose(" from %s",
		    print_host((struct sockaddr *)&flow->flow_src.addr, NULL,
		    0));
		if (flow->flow_src.addr_af != AF_UNSPEC &&
		    flow->flow_src.addr_net)
			print_verbose("/%d", flow->flow_src.addr_mask);
		if (flow->flow_src.addr_port)
			print_verbose(" port %d",
			    ntohs(flow->flow_src.addr_port));

		print_verbose(" to %s",
		    print_host((struct sockaddr *)&flow->flow_dst.addr, NULL,
		    0));
		if (flow->flow_dst.addr_af != AF_UNSPEC &&
		    flow->flow_dst.addr_net)
			print_verbose("/%d", flow->flow_dst.addr_mask);
		if (flow->flow_dst.addr_port)
			print_verbose(" port %d",
			    ntohs(flow->flow_dst.addr_port));
	}

	if ((pol->pol_flags & IKED_POLICY_DEFAULT) == 0) {
		print_verbose(" local %s",
		    print_host((struct sockaddr *)&pol->pol_local.addr, NULL,
		    0));
		if (pol->pol_local.addr.ss_family != AF_UNSPEC &&
		    pol->pol_local.addr_net)
			print_verbose("/%d", pol->pol_local.addr_mask);

		print_verbose(" peer %s",
		    print_host((struct sockaddr *)&pol->pol_peer.addr, NULL,
		    0));
		if (pol->pol_peer.addr.ss_family != AF_UNSPEC &&
		    pol->pol_peer.addr_net)
			print_verbose("/%d", pol->pol_peer.addr_mask);
	}

	TAILQ_FOREACH(pp, &pol->pol_proposals, prop_entry) {
		if (!pp->prop_nxforms)
			continue;
		if (pp->prop_protoid == IKEV2_SAPROTO_IKE)
			print_verbose(" ikesa");
		else
			print_verbose(" childsa");

		for (j = 0; ikev2_xformtype_map[j].cm_type != 0; j++) {
			xfs = NULL;

			for (i = 0; i < pp->prop_nxforms; i++) {
				xform = pp->prop_xforms + i;

				if (xform->xform_type !=
				    ikev2_xformtype_map[j].cm_type)
					continue;

				if (xfs != NULL) {
					print_verbose(",");
				} else {
					switch (xform->xform_type) {
					case IKEV2_XFORMTYPE_INTEGR:
						print_verbose(" auth ");
						xfs = authxfs;
						break;
					case IKEV2_XFORMTYPE_ENCR:
						print_verbose(" enc ");
						if (pp->prop_protoid ==
						    IKEV2_SAPROTO_IKE)
							xfs = ikeencxfs;
						else
							xfs = ipsecencxfs;
						break;
					case IKEV2_XFORMTYPE_PRF:
						print_verbose(" prf ");
						xfs = prfxfs;
						break;
					case IKEV2_XFORMTYPE_DH:
						print_verbose(" group ");
						xfs = groupxfs;
						break;
					default:
						continue;
					}
				}

				print_verbose("%s", print_xf(xform->xform_id,
				    xform->xform_length / 8, xfs));
			}
		}
	}

	if (pol->pol_localid.id_length != 0)
		print_verbose(" srcid %s", pol->pol_localid.id_data);
	if (pol->pol_peerid.id_length != 0)
		print_verbose(" dstid %s", pol->pol_peerid.id_data);

	if (pol->pol_rekey)
		print_verbose(" ikelifetime %u", pol->pol_rekey);

	print_verbose(" lifetime %llu bytes %llu",
	    pol->pol_lifetime.lt_seconds, pol->pol_lifetime.lt_bytes);

	if (pol->pol_auth.auth_method == IKEV2_AUTH_SHARED_KEY_MIC) {
			print_verbose(" psk 0x");
			for (i = 0; i < pol->pol_auth.auth_length; i++)
				print_verbose("%02x",
				    pol->pol_auth.auth_data[i]);
	} else {
		if (pol->pol_auth.auth_eap)
			print_verbose(" eap \"%s\"",
			    print_map(pol->pol_auth.auth_eap, eap_type_map));
		else
			print_verbose(" %s",
			    print_xf(pol->pol_auth.auth_method, 0, methodxfs));
	}

	for (i = 0; i < pol->pol_ncfg; i++) {
		cfg = &pol->pol_cfg[i];
		print_verbose(" config %s %s", print_xf(cfg->cfg_type,
		    cfg->cfg.address.addr_af, cpxfs),
		    print_host((struct sockaddr *)&cfg->cfg.address.addr, NULL,
		    0));
	}

	if (pol->pol_tag[0] != '\0')
		print_verbose(" tag \"%s\"", pol->pol_tag);

	if (pol->pol_tap != 0)
		print_verbose(" tap \"enc%u\"", pol->pol_tap);

	print_verbose("\n");
}

void
copy_transforms(unsigned int type, const struct ipsec_xf *xf,
    const struct ipsec_xf *xfs,
    struct iked_transform *dst, size_t ndst,
    unsigned int *n, struct iked_transform *src, size_t nsrc)
{
	unsigned int		 i;
	struct iked_transform	*a, *b;

	if (xf != NULL) {
		if (*n >= ndst)
			return;
		b = dst + (*n)++;

		b->xform_type = type;
		b->xform_id = xf->id;
		b->xform_keylength = xf->length * 8;
		b->xform_length = xf->keylength * 8;
		return;
	}

	for (i = 0; i < nsrc; i++) {
		a = src + i;
		if (a->xform_type != type)
			continue;
		if (*n >= ndst)
			return;
		b = dst + (*n)++;
		memcpy(b, a, sizeof(*b));
	}
}

int
create_ike(char *name, int af, uint8_t ipproto, struct ipsec_hosts *hosts,
    struct ipsec_hosts *peers, struct ipsec_mode *ike_sa,
    struct ipsec_mode *ipsec_sa, uint8_t saproto,
    uint8_t flags, char *srcid, char *dstid,
    uint32_t ikelifetime, struct iked_lifetime *lt,
    struct iked_auth *authtype, struct ipsec_filters *filter,
    struct ipsec_addr_wrap *ikecfg)
{
	char			 idstr[IKED_ID_SIZE];
	unsigned int		 idtype = IKEV2_ID_NONE;
	struct ipsec_addr_wrap	*ipa, *ipb;
	struct iked_policy	 pol;
	struct iked_proposal	 prop[2];
	unsigned int		 j;
	struct iked_transform	 ikexforms[64], ipsecxforms[64];
	struct iked_flow	 flows[64];
	static unsigned int	 policy_id = 0;
	struct iked_cfg		*cfg;

	bzero(&pol, sizeof(pol));
	bzero(&prop, sizeof(prop));
	bzero(idstr, sizeof(idstr));

	pol.pol_id = ++policy_id;
	pol.pol_certreqtype = env->sc_certreqtype;
	pol.pol_af = af;
	pol.pol_saproto = saproto;
	pol.pol_ipproto = ipproto;
	pol.pol_flags = flags;
	memcpy(&pol.pol_auth, authtype, sizeof(struct iked_auth));

	if (name != NULL) {
		if (strlcpy(pol.pol_name, name,
		    sizeof(pol.pol_name)) >= sizeof(pol.pol_name)) {
			yyerror("name too long");
			return (-1);
		}
	} else {
		snprintf(pol.pol_name, sizeof(pol.pol_name),
		    "policy%d", policy_id);
	}

	if (srcid) {
		pol.pol_localid.id_type = get_id_type(srcid);
		pol.pol_localid.id_length = strlen(srcid);
		if (strlcpy((char *)pol.pol_localid.id_data,
		    srcid, IKED_ID_SIZE) >= IKED_ID_SIZE) {
			yyerror("srcid too long");
			return (-1);
		}
	}
	if (dstid) {
		pol.pol_peerid.id_type = get_id_type(dstid);
		pol.pol_peerid.id_length = strlen(dstid);
		if (strlcpy((char *)pol.pol_peerid.id_data,
		    dstid, IKED_ID_SIZE) >= IKED_ID_SIZE) {
			yyerror("dstid too long");
			return (-1);
		}
	}

	if (filter != NULL) {
		if (filter->tag)
			strlcpy(pol.pol_tag, filter->tag, sizeof(pol.pol_tag));
		pol.pol_tap = filter->tap;
	}

	if (peers == NULL) {
		if (pol.pol_flags & IKED_POLICY_ACTIVE) {
			yyerror("active mode requires peer specification");
			return (-1);
		}
		pol.pol_flags |= IKED_POLICY_DEFAULT|IKED_POLICY_SKIP;
	}

	if (peers && peers->src && peers->dst &&
	    (peers->src->address.ss_family != AF_UNSPEC) &&
	    (peers->dst->address.ss_family != AF_UNSPEC) &&
	    (peers->src->address.ss_family != peers->dst->address.ss_family))
		fatalx("create_ike: peer address family mismatch");

	if (peers && (pol.pol_af != AF_UNSPEC) &&
	    ((peers->src && (peers->src->address.ss_family != AF_UNSPEC) &&
	    (peers->src->address.ss_family != pol.pol_af)) ||
	    (peers->dst && (peers->dst->address.ss_family != AF_UNSPEC) &&
	    (peers->dst->address.ss_family != pol.pol_af))))
		fatalx("create_ike: policy address family mismatch");

	ipa = ipb = NULL;
	if (peers) {
		if (peers->src)
			ipa = peers->src;
		if (peers->dst)
			ipb = peers->dst;
		if (ipa == NULL && ipb == NULL) {
			/*
			 * If no peers were specified, flag this policy
			 * as being able to use transport mode.
			 */
			pol.pol_flags |= IKED_POLICY_TRANSPORT;
			if (hosts->src && hosts->src->next == NULL)
				ipa = hosts->src;
			if (hosts->dst && hosts->dst->next == NULL)
				ipb = hosts->dst;
		}
	}
	if (ipa == NULL && ipb == NULL) {
		yyerror("could not get local/peer specification");
		return (-1);
	}
	if (pol.pol_flags & IKED_POLICY_ACTIVE) {
		if (ipb == NULL || ipb->netaddress ||
		    (ipa != NULL && ipa->netaddress)) {
			yyerror("active mode requires local/peer address");
			return (-1);
		}
	}
	if (ipa) {
		memcpy(&pol.pol_local.addr, &ipa->address,
		    sizeof(ipa->address));
		pol.pol_local.addr_af = ipa->address.ss_family;
		pol.pol_local.addr_mask = ipa->mask;
		pol.pol_local.addr_net = ipa->netaddress;
		if (pol.pol_af == AF_UNSPEC)
			pol.pol_af = ipa->address.ss_family;
	}
	if (ipb) {
		memcpy(&pol.pol_peer.addr, &ipb->address,
		    sizeof(ipb->address));
		pol.pol_peer.addr_af = ipb->address.ss_family;
		pol.pol_peer.addr_mask = ipb->mask;
		pol.pol_peer.addr_net = ipb->netaddress;
		if (pol.pol_af == AF_UNSPEC)
			pol.pol_af = ipb->address.ss_family;
	}

	if (ikelifetime)
		pol.pol_rekey = ikelifetime;

	if (lt)
		pol.pol_lifetime = *lt;
	else
		pol.pol_lifetime = deflifetime;

	TAILQ_INIT(&pol.pol_proposals);
	RB_INIT(&pol.pol_flows);

	prop[0].prop_id = ++pol.pol_nproposals;
	prop[0].prop_protoid = IKEV2_SAPROTO_IKE;
	if (ike_sa == NULL || ike_sa->xfs == NULL) {
		prop[0].prop_nxforms = ikev2_default_nike_transforms;
		prop[0].prop_xforms = ikev2_default_ike_transforms;
	} else {
		j = 0;
		copy_transforms(IKEV2_XFORMTYPE_INTEGR,
		    ike_sa->xfs->authxf, authxfs,
		    ikexforms, nitems(ikexforms), &j,
		    ikev2_default_ike_transforms,
		    ikev2_default_nike_transforms);
		copy_transforms(IKEV2_XFORMTYPE_ENCR,
		    ike_sa->xfs->encxf, ikeencxfs,
		    ikexforms, nitems(ikexforms), &j,
		    ikev2_default_ike_transforms,
		    ikev2_default_nike_transforms);
		copy_transforms(IKEV2_XFORMTYPE_DH,
		    ike_sa->xfs->groupxf, groupxfs,
		    ikexforms, nitems(ikexforms), &j,
		    ikev2_default_ike_transforms,
		    ikev2_default_nike_transforms);
		copy_transforms(IKEV2_XFORMTYPE_PRF,
		    ike_sa->xfs->prfxf, prfxfs,
		    ikexforms, nitems(ikexforms), &j,
		    ikev2_default_ike_transforms,
		    ikev2_default_nike_transforms);
		prop[0].prop_nxforms = j;
		prop[0].prop_xforms = ikexforms;
	}
	TAILQ_INSERT_TAIL(&pol.pol_proposals, &prop[0], prop_entry);

	prop[1].prop_id = ++pol.pol_nproposals;
	prop[1].prop_protoid = saproto;
	if (ipsec_sa == NULL || ipsec_sa->xfs == NULL) {
		prop[1].prop_nxforms = ikev2_default_nesp_transforms;
		prop[1].prop_xforms = ikev2_default_esp_transforms;
	} else {
		j = 0;
		if (ipsec_sa->xfs->encxf && ipsec_sa->xfs->encxf->noauth &&
		    ipsec_sa->xfs->authxf) {
			yyerror("authentication is implicit for %s",
			    ipsec_sa->xfs->encxf->name);
			return (-1);
		}
		if (ipsec_sa->xfs->encxf == NULL ||
		    (ipsec_sa->xfs->encxf && !ipsec_sa->xfs->encxf->noauth))
			copy_transforms(IKEV2_XFORMTYPE_INTEGR,
			    ipsec_sa->xfs->authxf, authxfs,
			    ipsecxforms, nitems(ipsecxforms), &j,
			    ikev2_default_esp_transforms,
			    ikev2_default_nesp_transforms);
		copy_transforms(IKEV2_XFORMTYPE_ENCR,
		    ipsec_sa->xfs->encxf, ipsecencxfs,
		    ipsecxforms, nitems(ipsecxforms), &j,
		    ikev2_default_esp_transforms,
		    ikev2_default_nesp_transforms);
		copy_transforms(IKEV2_XFORMTYPE_DH,
		    ipsec_sa->xfs->groupxf, groupxfs,
		    ipsecxforms, nitems(ipsecxforms), &j,
		    ikev2_default_esp_transforms,
		    ikev2_default_nesp_transforms);
		copy_transforms(IKEV2_XFORMTYPE_ESN,
		    NULL, NULL,
		    ipsecxforms, nitems(ipsecxforms), &j,
		    ikev2_default_esp_transforms,
		    ikev2_default_nesp_transforms);
		prop[1].prop_nxforms = j;
		prop[1].prop_xforms = ipsecxforms;
	}
	TAILQ_INSERT_TAIL(&pol.pol_proposals, &prop[1], prop_entry);

	if (hosts == NULL || hosts->src == NULL || hosts->dst == NULL)
		fatalx("create_ike: no traffic selectors/flows");

	for (j = 0, ipa = hosts->src, ipb = hosts->dst; ipa && ipb;
	    ipa = ipa->next, ipb = ipb->next, j++) {
		memcpy(&flows[j].flow_src.addr, &ipa->address,
		    sizeof(ipa->address));
		flows[j].flow_src.addr_af = ipa->address.ss_family;
		flows[j].flow_src.addr_mask = ipa->mask;
		flows[j].flow_src.addr_net = ipa->netaddress;
		flows[j].flow_src.addr_port = hosts->sport;

		memcpy(&flows[j].flow_dst.addr, &ipb->address,
		    sizeof(ipb->address));
		flows[j].flow_dst.addr_af = ipb->address.ss_family;
		flows[j].flow_dst.addr_mask = ipb->mask;
		flows[j].flow_dst.addr_net = ipb->netaddress;
		flows[j].flow_dst.addr_port = hosts->dport;

		flows[j].flow_ipproto = ipproto;

		pol.pol_nflows++;
		RB_INSERT(iked_flows, &pol.pol_flows, &flows[j]);
	}

	for (j = 0, ipa = ikecfg; ipa; ipa = ipa->next, j++) {
		if (j >= IKED_CFG_MAX)
			break;
		cfg = &pol.pol_cfg[j];
		pol.pol_ncfg++;

		cfg->cfg_action = ipa->action;
		cfg->cfg_type = ipa->type;
		memcpy(&cfg->cfg.address.addr, &ipa->address,
		    sizeof(ipa->address));
		cfg->cfg.address.addr_mask = ipa->mask;
		cfg->cfg.address.addr_net = ipa->netaddress;
		cfg->cfg.address.addr_af = ipa->address.ss_family;
	}

	if (dstid) {
		strlcpy(idstr, dstid, sizeof(idstr));
		idtype = pol.pol_peerid.id_type;
	} else if (!pol.pol_peer.addr_net) {
		print_host((struct sockaddr *)&pol.pol_peer.addr, idstr,
		    sizeof(idstr));
		switch (pol.pol_peer.addr.ss_family) {
		case AF_INET:
			idtype = IKEV2_ID_IPV4;
			break;
		case AF_INET6:
			idtype = IKEV2_ID_IPV6;
			break;
		default:
			log_warnx("%s: unknown address family", __func__);
			break;
		}
	}

	/* Check if we have a raw public key for this peer */
	if (check_pubkey(idstr, idtype) != -1)
		pol.pol_certreqtype = IKEV2_CERT_RSA_KEY;

	config_setpolicy(env, &pol, PROC_IKEV2);

	rules++;
	return (0);
}

int
create_user(const char *user, const char *pass)
{
	struct iked_user	 usr;

	bzero(&usr, sizeof(usr));

	if (*user == '\0' || (strlcpy(usr.usr_name, user,
	    sizeof(usr.usr_name)) >= sizeof(usr.usr_name))) {
		yyerror("invalid user name");
		return (-1);
	}
	if (*pass == '\0' || (strlcpy(usr.usr_pass, pass,
	    sizeof(usr.usr_pass)) >= sizeof(usr.usr_pass))) {
		yyerror("invalid password");
		return (-1);
	}

	config_setuser(env, &usr, PROC_IKEV2);

	rules++;
	return (0);
}
