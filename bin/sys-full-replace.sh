#!/bin/bash -e

if [ `whoami` != "root" ]; then
	echo "This script must be run as root!"
	exit 0
fi

dirs=(bin boot etc lib lib32 lib64 libx32 opt root sbin usr var)

pycode="
import os, sys, argparse

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = os.path.expanduser(fn)
	return open(fn, mode, **kwargs)


is_id_human = lambda its: len(its)>=3 and 20000>=int(its[2])>=1000

if __name__=='__main__':
	parser = argparse.ArgumentParser(usage='\$0 src_dir tgt_dir 1>output 2>progress',
			description='This program copies user credentials in passwd/shadow/group from src_dir to tgt_dir, keeping system user information.',
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	parser.add_argument('src_dir', help='source directory')
	parser.add_argument('tgt_dir', help='target directory')
	parser.add_argument('-o', '--overwrite-backup', help='whether to overwrite backups', choices=['ask', 'yes', 'no'], default='ask')
	parser.add_argument('-n', '--no-backup', help='do not make any backup', action='store_true')
	#nargs='?': optional positional argument; action='append': multiple instances of the arg; type=; default=
	opt=parser.parse_args()
	globals().update(vars(opt))

	if not no_backup:
		overwrite = False
		if overwrite_backup=='ask' and sum([os.path.isfile(tgt_dir+f+'.bak') for f in ['/passwd', '/shadow', '/group']]):
			print('Backup file(s) already exists, overwrite? (Yes/No/Cancel)', end=' ')
			kbd=input()
			if kbd.lower().startswith('y'):
				overwrite = True
			elif kbd.lower().startswith('c'):
				sys.exit(0)
				
		for f in ['/passwd', '/shadow', '/group']:
			if overwrite or not os.path.isfile(tgt_dir+f+'.bak'):
				os.system(f'cp -vf {src_dir}/{f} {tgt_dir}/{f}.bak')


	pw1,sd1,gp1 = [Open(src_dir+f).readlines() for f in ['/passwd', '/shadow', '/group']]
	pw2,sd2,gp2 = [Open(tgt_dir+f).readlines() for f in ['/passwd', '/shadow', '/group']]

	pwu1 = [L for L in pw1 if is_id_human(L.split(':'))]
	pwu2 = [L for L in pw2 if is_id_human(L.split(':'))]

	if not pwu1:
		print('Warning: no human users found in \$src_dir/passwd')
		sys.exit(1)
	if set(pwu1)!=set(pwu2):
		Ls=[L for L in pw2 if not is_id_human(L.split(':'))]+pwu1
		with Open(tgt_dir+'/passwd', 'w') as fp:
			fp.write(''.join(Ls))
		print('\$tgt_dir/passwd is updated')
	u1 = [L.split(':')[0] for L in pwu1]
	u2 = [L.split(':')[0] for L in pwu2]
	sdu1 = [L for L in sd1 if ':' in L and L.split(':')[0] in u1]
	sdu2 = [L for L in sd2 if ':' in L and L.split(':')[0] in u2]
	if set(sdu1)!=set(sdu2):
		Ls = [L for L in sd2 if not (':' in L and L.split(':')[0] in u2)] + sdu1
		with Open(tgt_dir+'/shadow', 'w') as fp:
			fp.write(''.join(Ls))
		print('\$tgt_dir/shadow is updated')
	gpu1 = [L for L in gp1 if is_id_human(L.split(':'))]
	gpu2 = [L for L in gp2 if is_id_human(L.split(':'))]
	if set(gpu1) != set(gpu2):
		Ls = [L for L in gp2 if not is_id_human(L.split(':'))] + gpu1
		with Open(tgt_dir+'/group', 'w') as fp:
			fp.write(''.join(Ls))
		print('\$tgt_dir/group is updated')
"

copy_if () {
	if [ -e "$1" ]; then
		rsync -avlP --delete "$1" "$2"
	fi
}


# START
cd /

if [ ! -d /full-upgrade ] || [ ! -d /full-backup ]; then
	echo "Abort: /full-upgrade or /full-backup does not exist"
	exit 1
fi

for d1 in `ls /full-upgrade`; do
	if [ -d /full-backup/$d1 ] && [ -d /$d1 ]; then
		echo "Abort: /$1 cannot be backed up because /full-backup/$d1 already exists"
		exit 1
	fi
done

if [ ! -s /busybox ]; then
	cp /full-upgrade/usr/bin/busybox /
fi

if ! file /busybox | grep 'statically'; then
	echo "Abort: /busybox is NOT statically linked"
	exit 1
fi

echo Copy over credentials and configs
python3 -c "$pycode" /etc /full-upgrade/etc

copy_if /etc/network/interfaces /full-upgrade/etc/network/
copy_if /etc/NetworkManager /full-upgrade/etc/
copy_if /etc/openvpn /full-upgrade/etc/
copy_if /root/.ssh /full-upgrade/root/
copy_if /var/log /full-upgrade/var/

cp -rf /etc/fstab /etc/exports /etc/host* /etc/sudoers /full-upgrade/etc/

echo Perform OS replacement
cd /full-upgrade
for f in "${dirs[@]}"; do if [ -e "/$f" ]; then /busybox mv -v "/$f" /full-backup/; fi; /busybox mv -v "$f" /;done
cd /

echo Prepare EFI
EFI=`mount | grep '/boot/efi' | awk '{print $1}'`
umount /full-backup/boot/efi
mount $EFI /boot/efi
rm -rf /full-backup/boot/efi/EFI/*
mkdir -p /full-backup/boot/efi/EFI
mv /boot/efi/EFI/* /full-backup/boot/efi/EFI/

echo Install grub
grub-mkdevicemap
ROOT_DEV=`mount | grep ' / ' | awk '{print $1}'`
grub-install --efi-directory=/boot/efi --root-directory=/ $ROOT_DEV
update-grub
update-initramfs -u -k all

echo Cleanup
rm /busybox

