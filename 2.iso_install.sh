#!/bin/bash
create_qcow2()
{
	local image_name=$1
	local image_size=$2
	[[ -e $image_name ]] && echo "${image_name} already exists!" && return 0
	qemu-img create -f qcow2 $image_name $image_size
}

install_iso_with_vnc()
{
	local iso_file=$1
	create_qcow2 $iso_file 20G
	qemu-system-x86_64 -enable-kvm -cdrom $iso_file -hda fedora.img -boot d -m 2048
}

install_iso_with_cmdline()
{
	# get iso from https://mirrors.tuna.tsinghua.edu.cn/fedora/releases/40/Server/x86_64/iso/
	local tmp_mnt=./mnt
	local iso_file=./Fedora-Server-dvd-x86_64-40-1.14.iso
	local kernel=${tmp_mnt}/images/pxeboot/vmlinuz
	local initrd=${tmp_mnt}/images/pxeboot/initrd.img
	local dst_image=${1:-./fedora.img}
	local dst_image_size=${2:-20G}

	mkdir -p ${tmp_mnt}
	create_qcow2 $dst_image ${dst_image_size}
	sudo mount $iso_file ${tmp_mnt}
	[[ $? -ne 0 ]] && echo "mount failed!" && return ${LINENO}
	[[ ! -e  $kernel ]] && echo "kernel ${kernel} not exist!!" && return ${LINENO}
	[[ ! -e  $initrd ]] && echo "initrd ${initrd} not exist!!" && return ${LINENO}
	# attention: partion suggest to use standard partition, default xfs filesystem
	qemu-system-x86_64 -enable-kvm -cpu host -boot dc -hda $dst_image -cdrom ${iso_file} \
		-net nic -net user,hostfwd=tcp::12346-:22 -smp 4 -m 4G \
		-kernel $kernel -initrd $initrd \
		-append console=ttyS0 -nographic 
	sudo umount ${tmp_mnt}
}

install_iso_with_cmdline $@
