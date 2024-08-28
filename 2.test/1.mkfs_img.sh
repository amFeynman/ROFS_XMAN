#!/bin/bash

FSCK=`which fsck.erofs`
MKFS=`which mkfs.erofs`
DPFS=`which dump.erofs`
SRC_DIR=${1:-./0.src}
IMGDIR=./0.image/
LOG_FILE=${IMGDIR}/mkfs.log

mkdir -p ${IMGDIR}
(printf '=%.0s' $(seq 1 40) && echo "") | tee -a ${LOG_FILE}

create_erofsimg()
{
	local img_dir=$1
	local img_name=""
	shift
	mkdir -p $img_dir
	img_name=$img_dir/$(basename $SRC_DIR)$(echo $@ | tr -s ' '| sed  's/\([^a-zA-Z0-9]\)/\_/g' | tr -s '_').img
	[[ ! -e $img_name ]] && echo "MKFS [mkfs.erofs $img_name $@ ${SRC_DIR}]" | tee -a ${LOG_FILE}
	[[ ! -e $img_name ]] && $MKFS ${img_name} $@ ${SRC_DIR} >> ${LOG_FILE} 2>&1 && return 0
	echo "$img_name exists!" | tee -a ${LOG_FILE}
}

compare_filesize()
{
	local org_dir=$1
	local cmp_dir=$2
	local name_diff=$3
	local org_fname
	local cmp_fname
	local cur_name
	local format_str="|%-30s|%-12s|%-12s|%-9s|"
	local header_str="|%-30s|%-12s|%-12s|%-9s|"

	printf "$header_str\n" "erofs_image" "orgin_size" "${name_diff}" "Opt_ratio"
	printf "$header_str\n" "--" "--" "--" "--"
	for f in $(ls $org_dir/* -S)
	do
		org_fname=$f
		cmp_fname=$(basename $f)
		cur_name=${cmp_fname%%.img}
		cmp_fname=${cur_name}_${name_diff}.img
		cmp_fname=$(find $cmp_dir -name $cmp_fname)
		local org_size=$(stat --printf="%s" $org_fname) 
		local cmp_size=$(stat --printf="%s" $cmp_fname)
		local opt_ratio=$(echo $org_size $cmp_size | awk '{print (1-$2/$1)*100}' | xargs printf "%.2f%%")
		printf "$format_str\n" $cur_name $org_size $cmp_size "${opt_ratio}"
	done
}

#test mkfs.erofs
mkimg_raw()
{
	#erofs-raw32.img
	create_erofsimg  ${IMGDIR}/ -E force-inode-compact || exit ${LINENO}
	#erofs-raw64.img
	create_erofsimg  ${IMGDIR}/ -E force-inode-extended || exit ${LINENO}
}

mkimg_lzma()
{
	#erofs-lzma-4k
	create_erofsimg  ${IMGDIR}/ -zlzma,9 -C 4096 || exit ${LINENO}
	create_erofsimg  ${IMGDIR}/ -zlzma,9 -C 8192 || exit ${LINENO}
	#create_erofsimg  ${IMGDIR}/ -zlzma,9 -C 1048576 --random-pclusterblks || exit ${LINENO}
}

erofs_mkimg()
{
	local cluster
	local cluster_list="4 8 32 64 1024"

	for cluster in $cluster_list
	do
		create_erofsimg  ${IMGDIR}/origin -zlz4hc,9 -C $((cluster * 1024))  || exit ${LINENO}
		create_erofsimg  ${IMGDIR}/       -zlz4hc,9 -C $((cluster * 1024)) --bcj-arm64 || exit ${LINENO}
		create_erofsimg  ${IMGDIR}/origin -zlzma    -C $((cluster * 1024))  || exit ${LINENO}
		create_erofsimg  ${IMGDIR}/       -zlzma    -C $((cluster * 1024)) --bcj-arm64 || exit ${LINENO}
	done
}

mkimg_random()
{
	#erofs-rand-alg-1M.img
	create_erofsimg  ${IMGDIR}/-zlz4:lzma,9:lz4hc,9 -C 1048576 --random-pclusterblks --random-algorithms || exit ${LINENO}
	#erofs-rand-frag-1M.img
	create_erofsimg  ${IMGDIR}/ -zlz4:lzma,9:lz4hc,9 -C 8192 -Efragments,8192 --random-pclusterblks --random-algorithms || exit ${LINENO}
	#erofs-rand-frag-dedupe-1M.img
	create_erofsimg  ${IMGDIR}/ -zlz4:lzma,9:lz4hc,9 -C 1048576 -Efragments,1048576 -Ededupe --random-algorithms || exit ${LINENO}
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

erofs_mkimg
compare_filesize ${IMGDIR}/origin ${IMGDIR}/ bcj_arm64
