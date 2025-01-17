#!/usr/bin/bash
#
# {{{ CDDL HEADER
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source. A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
# }}}

# Copyright 2022 OmniOS Community Edition (OmniOSce) Association.

. ../../lib/build.sh

PROG=openldap
VER=2.6.3
PKG=ooce/network/openldap
SUMMARY="open-source LDAP implementation"
DESC="Open-source implementation of the Lightweight Directory Access Protocol"

# Previous versions that also need to be built and packaged since compiled
# software may depend on it.
PVERS="2.4.59"

OPREFIX="$PREFIX"
PREFIX+="/$PROG"

SKIP_LICENCES=OpenLDAP
SKIP_RTIME_CHECK=1

# Setting this variable in the environment makes mkversion use a constant
# string in the LDAP version rather than the hostname and build path.
export SOURCE_DATE_EPOCH=`date +%s`

XFORM_ARGS+="
    -DOPREFIX=${OPREFIX#/}
    -DPREFIX=${PREFIX#/}
    -DPROG=$PROG
    -DPKGROOT=$PROG
    -DUSER=openldap -DGROUP=openldap
"

CONFIGURE_OPTS="
    --prefix=$PREFIX
    --with-tls=openssl
    --sysconfdir=/etc$OPREFIX
    --localstatedir=/var$PREFIX
    --disable-static
    --enable-shared
    --enable-dynamic
    --enable-crypt
    --without-cyrus-sasl
"
CONFIGURE_OPTS_32+="
    --bindir=$PREFIX/bin/$ISAPART
    --disable-slapd
"
CONFIGURE_OPTS_64+="
    --bindir=$PREFIX/bin
    --sbindir=$PREFIX/sbin
    --libexecdir=$PREFIX/libexec

    --enable-slapd
    --enable-ldap
    --disable-bdb
    --disable-hdb
    --enable-mdb
    --enable-meta
    --enable-monitor
    --enable-null

    --enable-modules
    --enable-overlays=mod
"
[ $RELVER -ge 151037 ] && LDFLAGS32+=" -lssp_ns"

MAKE_INSTALL_ARGS+=" STRIP= STRIP_OPTS="

# On older OmniOS releases where the compiler outputs 32-bit objects by
# default, libtool creates some intermediate objects as 32-bit during the
# 64-bit build.
if [ $RELVER -lt 151034 ]; then
    save_function configure64 _configure64
    configure64() {
        _configure64 "$@"
        sed -i '/^no_builtin_flag=/s/-/-m64 &/' libtool
    }
fi

build_manifests() {
    manifest_start $TMPDIR/manifest.client
    manifest_add_dir $OPREFIX/lib pkgconfig $ISAPART64 $ISAPART64/pkgconfig
    manifest_add_dir $PREFIX/bin
    manifest_add_dir $OPREFIX/include
    manifest_add_dir $PREFIX/share/man man1 man3
    manifest_add $PREFIX/share/man/man5 ldap.conf.5 ldif.5
    manifest_add etc$PREFIX ldap.conf
    manifest_finalise $TMPDIR/manifest.client $OPREFIX etc$OPREFIX

    manifest_uniq $TMPDIR/manifest.{server,client}
    manifest_finalise $TMPDIR/manifest.server $OPREFIX etc$OPREFIX
}

init
prep_build

# Build previous versions
for pver in $PVERS; do
    note -n "Building previous version: $pver"
    save_variables BUILDDIR EXTRACTED_SRC CONFIGURE_OPTS_64
    BUILDDIR=$PROG-$pver
    EXTRACTED_SRC=$PROG-$pver
    CONFIGURE_OPTS_64+=" --disable-slapd"
    download_source $PROG $PROG $pver
    patch_source patches-`echo $pver | cut -d. -f1-2`
    build
    restore_variables BUILDDIR EXTRACTED_SRC CONFIGURE_OPTS_64
done

note -n "Building current version: $VER"
download_source $PROG $PROG $VER
patch_source
build
xform files/$PROG.xml > $TMPDIR/$PROG.xml
install_smf -oocemethod ooce $PROG.xml
build_manifests
PKG=${PKG/network/library} SUMMARY+=" - clients and libraries" \
    make_package -seed $TMPDIR/manifest.client
make_package -seed $TMPDIR/manifest.server server.mog
clean_up

# Vim hints
# vim:ts=4:sw=4:et:fdm=marker
