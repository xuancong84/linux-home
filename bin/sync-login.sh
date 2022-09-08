#!/bin/bash

if [ $# != 2 ]; then
	echo "Usage: $0 src-dir dst-dir"
	echo "This program syncs passwd, shadow and group from src-dir to dst-dir"
	exit 1
fi

pycode="
import os,sys
is_id_human=lambda its: len(its)>=3 and int(its[2])>=1000 and its[0] not in ['nobody', 'nogroup']
src, dst = sys.argv[1], sys.argv[2]
pw1=open(src+'/passwd').readlines()
sd1=open(src+'/shadow').readlines()
gp1=open(src+'/group').readlines()
pw2=open(dst+'/passwd').readlines()
sd2=open(dst+'/shadow').readlines()
gp2=open(dst+'/group').readlines()
pwu1=[L for L in pw1 if is_id_human(L.split(':'))]
pwu2=[L for L in pw2 if is_id_human(L.split(':'))]
if not pwu1:
	sys.exit(1)
if set(pwu1)!=set(pwu2):
	Ls=[L for L in pw2 if not is_id_human(L.split(':'))]+pwu1
	with open(dst+'/passwd', 'wb') as fp:
		fp.write(''.join(Ls))
u1=[L.split(':')[0] for L in pwu1]
u2=[L.split(':')[0] for L in pwu2]
sdu1=[L for L in sd1 if ':' in L and L.split(':')[0] in u1]
sdu2=[L for L in sd2 if ':' in L and L.split(':')[0] in u2]
if set(sdu1)!=set(sdu2):
	Ls=[L for L in sd2 if not (':' in L and L.split(':')[0] in u2)]+sdu1
	with open(dst+'/shadow', 'wb') as fp:
		fp.write(''.join(Ls))
gpu1=[L for L in gp1 if is_id_human(L.split(':'))]
gpu2=[L for L in gp2 if is_id_human(L.split(':'))]
if set(gpu1)!=set(gpu2):
	Ls=[L for L in gp2 if not is_id_human(L.split(':'))]+gpu1
	with open(dst+'/group', 'wb') as fp:
		fp.write(''.join(Ls))
"

python -c "$pycode" "$1" "$2"

