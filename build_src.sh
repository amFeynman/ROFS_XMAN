#!/bin/bash
BASEDIR=${PWD}/0.src/
INSTALL_DIR=${PWD}/1.bin/

export PATH=${INSTALL_DIR}/bin/:$PATH

install_package()
{
	local package="$1"
	dpkg -s ${package} > /dev/null || sudo apt-get install --yes "${package}"
}

prepare_install_tools()
{
	install_package autopoint
	install_package libtool
	install_package po4a
	install_package doxygen
}

build_xz()
{
	local wkdir=$1
	local install_prefix=$2
	cd $wkdir
	[[ -a Makefile ]] || (./autogen.sh && ./configure --prefix=${install_prefix})
	make install -j32
}

build_lz4()
{
	local wkdir=$1
	local install_prefix=$2
	cd $wkdir
	[[ -a ${install_prefix}/usr ]] || (mkdir -p ${install_prefix}/usr && ln -s ../ ${install_prefix}/usr/local)
	make DESTDIR="$install_prefix" install -j32
	[[ -a ${install_prefix}/usr ]] && rm -rf ${install_prefix}/usr
}

build_erofs_utils()
{
	local wkdir=$1
	local install_prefix=$2
	cd $wkdir
	[[ -a Makefile ]] || (./autogen.sh && \
					./configure --prefix=${install_prefix} \
					--with-lz4-incdir=${install_prefix}/include \
					--with-lz4-libdir=${install_prefix}/lib \
					--with-liblzma-incdir=${install_prefix}/include/ \
					--with-liblzma-libdir=${install_prefix}/lib --enable-lzma \
					-without-uuid \
					)
	make install -j32
}

prepare_install_tools

case "$1" in
	xz)
		build_xz ${BASEDIR}/xz $INSTALL_DIR
	;;
	lz4)
		build_lz4 ${BASEDIR}/lz4 $INSTALL_DIR
	;;
	erofs)
		build_erofs_utils ${BASEDIR}/erofs-utils $INSTALL_DIR
	;;
esac
