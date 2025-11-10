

### ns1.r304-15.sae.proj:
*/etc/named.conf :*
```shell
options {
	listen-on port 53 { any; };
	listen-on-v6 port 53 { none; };
	directory	"/var/named";
	dump-file	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	secroots-file	"/var/named/data/named.secroots";
	recursing-file	"/var/named/data/named.recursing";
	allow-query     { any; };
	forwarders { 10.1.147.199; }; 
	forward only;

	recursion yes;

	dnssec-validation no;

	managed-keys-directory "/var/named/dynamic";
	geoip-directory "/usr/share/GeoIP";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";

	include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

zone "r304-15.sae.proj" {
        type forward;
        forwarders { 10.98.40.199; };
        forward only;
};

zone "98.10.in-addr.arpa" IN {
        type forward;
        forwarders { 10.98.40.199; };
        forward only;
};
```
*/etc/named.conf :*
```shell
options {
        listen-on port 53 { any; };
        listen-on-v6 port 53 { none; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file   "/var/named/data/named.secroots";
        recursing-file  "/var/named/data/named.recursing";
        allow-query     { any; };

        recursion no;

        dnssec-validation no;

        managed-keys-directory "/var/named/dynamic";
        geoip-directory "/usr/share/GeoIP";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";

        /* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
        include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

// Vue pour le réseau interne
view "interne" {
        match-clients { 10.98/16; 127.0.0.1; };

        zone "r304-15.sae.proj" IN {
                type master;
                file "r304-15.sae.proj.internal.zone";
        };

        zone "98.10.in-addr.arpa" IN {
                type master;
                file "98.10.in-addr.arpa.internal.zone";
        };


        include "/etc/named.rfc1912.zones";
        include "/etc/named.root.key";
};


// Vue pour le réseau externe
view "externe" {
    match-clients { any; };

    zone "r304-15.sae.proj" IN {
        type master;
        file "r304-15.sae.proj.external.zone";
    };
};
```


### dns.r304-15.sae.proj:
*/var/named/r304-15.sae.proj.internal.zone :*
```shell
$TTL    30s;

$ORIGIN r304-15.sae.proj.

@		IN	SOA	dns.r304-15.sae.proj. barisona.etu.univ-grenoble-alpes.fr.    (
2025110301 ; serial
3H ; refresh
15 ; retry
1w ; expire
30 ; nxdomain ttl)

IN	NS	dns.r304-15.sae.proj.
www		IN	A	10.98.40.200
dns		IN	A	10.98.40.199
ns1		IN	A	10.98.40.198
```
*/var/named/r304-15.sae.proj.external.zone :*
```shell
$TTL    30s;

$ORIGIN r304-15.sae.proj.

@		IN	SOA	dns.r304-15.sae.proj. barisona.etu.univ-grenoble-alpes.fr.    (
2025110301 ; serial
3H ; refresh
15 ; retry
1w ; expire
30 ; nxdomain ttl)

IN	NS	dns.r304-15.sae.proj.
www		IN	A	10.1.15.73
dns		IN	A	10.1.15.73
ns1		IN	A	10.1.15.73
```
*/var/named/r304-15.sae.proj.external.zone*
```shell
$TTL    30s;

$ORIGIN 98.10.in-addr.arpa.

@		IN	SOA	dns.r304-15.sae.proj. barisona.etu.univ-grenoble-alpes.fr.    (
2025110301 ; serial
3H ; refresh
15 ; retry
1w ; expire
30 ; nxdomain ttl)

IN	NS	dns.r304-15.sae.proj.
200.40	IN	PTR	www.sae304-15.sae.proj.
199.40	IN	PTR	dns.sae304-15.sae.proj.
198.40	IN	PTR	ns1.sae304-15.sae.proj.
```