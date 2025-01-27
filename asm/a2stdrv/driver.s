; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2022 by Jean-Matthieu Coulon

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

; ACSI2STM integrated driver

	org	0

	dc.b	'A2ST'                  ; Signature
	dc.l	memend<<8+(bss+$1ff)/$200 ; RAM size and sector count

	incdir	..\
	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i
	include	structs.i
	include	hook.i

boot
	include	bootini.s
	even
	include	init.s
	even
	include	parts.s
	even
	include	prtpart.s
	even
	include	print.s
	even
	include	blkdev.s
	even
	include	acsicmd.s
	even
	include	rtc.s
	even
	include	rodata.s
	even
data
	include	data.s

	; Align payload to 16 bytes boundary for DMA transfers
	align16
bss
	include	bss.s

memend	equ	bss+bss...

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
