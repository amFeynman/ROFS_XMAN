#!/bin/bash

FSCK=`which fsck.erofs`
MKFS=`which mkfs.erofs`
DPFS=`which dump.erofs`
SRC_DIR=${1:-./0.src}
IMGDIR=./0.image/

mkdir -p ${IMGDIR}
create_erofsimg()
{
	local img=$1
	echo "MKFS [mkfs.erofs $@]"
	$MKFS $@ ${SRC_DIR}
}

#test mkfs.erofs
mkimg_raw()
{
	create_erofsimg  ${IMGDIR}/erofs-raw32.img -E force-inode-compact || exit -11
	create_erofsimg  ${IMGDIR}/erofs-raw64.img -E force-inode-extended || exit -12
}

mkimg_lzma()
{
	create_erofsimg  ${IMGDIR}/erofs-lzma-4k.img -zlzma,9 || exit -13
	create_erofsimg  ${IMGDIR}/erofs-lzma-bigpcluster-8k.img -zlzma,9 -C 8192 || exit -14
	create_erofsimg  ${IMGDIR}/erofs-lzma-rand-bigpcluster-1M.img -zlzma,9 -C 1048576 --random-pclusterblks || exit -15
}

mkimg_lz4()
{
	create_erofsimg  ${IMGDIR}/erofs-lz4-4k.img -zlz4hc,9 || exit -16
	create_erofsimg  ${IMGDIR}/erofs-lz4-bigpcluster-1M.img -zlz4hc,9 -C 1048576 | exit -17
	#create_erofsimg  ${IMGDIR}/erofs-lz4-rand-bigpcluster-1M.img -zlz4hc,9 -C 1048576 --random-pclusterblks || exit -17
}

mkimg_random()
{
	create_erofsimg  ${IMGDIR}/erofs-rand-alg-1M.img -zlz4:lzma,9:lz4hc,9 -C 1048576 --random-pclusterblks --random-algorithms || exit -18
	create_erofsimg  ${IMGDIR}/erofs-rand-frag-1M.img -zlz4:lzma,9:lz4hc,9 -C 8192 -Efragments,8192 --random-pclusterblks --random-algorithms || exit -19
	create_erofsimg  ${IMGDIR}/erofs-rand-frag-dedupe-1M.img -zlz4:lzma,9:lz4hc,9 -C 1048576 -Efragments,1048576 -Ededupe --random-algorithms || exit -20
}

#test {dump,fsck}.erofs
test_dump_fsck_erofs()
{
	for img in `ls ${IMGDIR}/*.img`
	do
		echo "FSCK_DUMP==================$img====================="
		mkdir -p ${img}_dir && $FSCK $img && $FSCK --extract=${img}_dir $img
		$DPFS $img
	done
	ls -F ${IMGDIR}/
}

mkimg_lz4
