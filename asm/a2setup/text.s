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

; ACSI2STM setup program
; Text section content

	include	tui.i

	include	devsel.s
	include	mainmenu.s
	include	blkdev.s
	include	formatsd.s
	include	creatimg.s
	include	a2sttest.s
	include	timeset.s
	include	parts.s
	include	parttool.s
	include	partedit.s
	include	partfmt.s
	include	quickset.s
	include	acsicmd.s
	include	tui.s
	include	rtc.s

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
