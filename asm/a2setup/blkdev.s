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
; Block device commands

blkdev.wr
	; Write to block device
	; Input:
	;  d0.w: block count (limited to $00ff)
	;  d1.l: Source address
	;  d2.l: Block number
	;  d7.b: Device id
	; Output:
	;  d0.w: ASC/Key or -1 if timeout

	lea	blkdev.rw.c(pc),a0
	move.b	#$2a,2(a0)
	move.l	d2,4(a0)
	and.w	#$00ff,d0
	move.b	d0,10(a0)
	bset	#8,d0
	bra.b	blkdev..exc

blkdev.rd
	; Read from block device
	; Input:
	;  d0.w: block count (limited to $00ff)
	;  d1.l: Target address
	;  d2.l: Block number
	;  d7.b: Device id
	; Output:
	;  d0.w: ASC/Key or -1 if timeout

	lea	blkdev.rw.c(pc),a0
	move.b	#$28,2(a0)
	move.l	d2,4(a0)
	and.w	#$00ff,d0
	move.b	d0,10(a0)

	; Fall through blkdev..exc
	
blkdev..exc
	; Execute a command and sense errors
	; Private function
	bsr.w	acsicmd
	tst.b	d0
	bgt.b	blkdev.sns
	bne.b	.rts
	moveq	#0,d0
.rts	rts

blkdev.sns
	; Sense error code
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.w: ASC/Key or -1 if timeout

	lea	blkdev.sns.c(pc),a0     ; Run Request sense
	moveq	#1,d0                   ;
	lea	bss+buf(pc),a1          ;
	move.l	a1,d1                   ;
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Process sense error
	bge.b	.ntmout                 ;
	rts                             ;
.ntmout	beq.b	.snsok                  ;
	moveq	#-1,d0                  ;
	rts                             ;

.snsok	moveq	#0,d0
	lea	bss+buf(pc),a0          ; Read ASC/Key
	move.b	12(a0),d0               ; ASC
	lsl.w	#8,d0                   ;
	move.b	2(a0),d0                ; Sense key
	rts

blkdev.cap
	; Read capacity
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.l: Block count or 0 if error

	lea	blkdev.cap.c(pc),a0     ; Send read capacity
	moveq	#1,d0                   ;
	lea	bss+buf(pc),a1          ;
	move.l	a1,d1                   ;
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Check for error
	bne.b	blkdev.flush.err        ;

blkdev.flush
	lea	blkdev.inq.c(pc),a0     ; Flush DMA buffer
	move.w	#$0201,d0               ;
	bsr.w	acsicmd                 ;

	tst.b	d0                      ; Check for error
	bne.b	blkdev.flush.err        ;

	move.l	bss+buf(pc),d0          ; Read capacity: returns last sector
	addq.l	#1,d0                   ; Return sector count
	rts

blkdev.flush.err
	moveq	#0,d0                   ; Return 0 in case of error
	rts                             ;

blkdev.tst
	; Test unit ready
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.w: ASC/Key or -1 if timeout

	moveq	#0,d0
	lea	blkdev.tst.c(pc),a0
	bra.w	blkdev..exc

blkdev.fmtsd
	; Format SD card
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.w: ASC/Key or -1 if timeout

	moveq	#0,d0
	lea	blkdev.fmtsd.c(pc),a0
	bra.w	blkdev..exc

blkdev.cim
	; Create an image on the SD card
	; Input:
	;  d0.w: Image size in 64kb units
	;  d7.b: Device id
	; Output:
	;  d0.w: ASC/Key or -1 if timeout

	lea	blkdev.cim.c(pc),a0
	move.w	d0,10(a0)
	moveq	#0,d0
	bra.w	blkdev..exc

blkdev.inq
	; ACSI Inquiry
	; Input:
	;  a0: target buffer
	;  d7.b: Device id
	; Output:
	;  d0.b: 0 if successful or -1 if timeout
	;  (a0) will contain the result
	lea	bss+buf(pc),a0          ; Send inquiry
	move.l	a0,d1                   ;
	lea	blkdev.inq.c(pc),a0     ;
	moveq	#1,d0                   ;
	bsr.w	acsicmd                 ;

	rts

blkdev.tsta2st
	; Test if the device is an ACSI2STM
	; Input:
	;  d7.b: Device id
	; Output:
	;  d0.w: 0 : Not an ACSI2STM (or no device at all)
	;        1 : No SD card
	;        2 : Raw SD card (no filesystem on the Arduino side)
	;        3 : Mounted image
	;        4 : Raw FAT16 SD
	;        5 : Raw FAT32 SD
	;        6 : Raw ExFAT SD
	;        7 : Unknown format

	bsr.b	blkdev.inq              ; Inquiry (to get device string)

	tst.b	d0                      ; Check if the command succeeded
	beq.b	.dmaok                  ;

.na2st	moveq	#0,d0                   ; Failed: return 0
	rts                             ;

.dmaok	; The inquiry command worked: analyze the device string
	lea	bss+buf+8(pc),a0
	cmp.l	#'ACSI',(a0)+
	bne.b	.na2st
	cmp.l	#'2STM',(a0)+
	bne.b	.na2st

	; The device is an ACSI2STM. Check its media type.

	move.l	4(a0),d1
	lea	.types(pc),a1
	moveq	#0,d0
	moveq	#(.typend-.types)/4-1,d2

.nxttyp	addq.w	#1,d0
	cmp.l	(a1)+,d1
	dbeq	d2,.nxttyp
	rts

.types	dc.b	' NO '
	dc.b	' RAW'
	dc.b	' IM0'
	dc.b	' F16'
	dc.b	' F32'
	dc.b	' EXF'
.typend

blkdev.wait
	; Wait forever until a device appears
	; Input:
	;  d7.b: device id

	bsr.w	blkdev.tst
	tst.b	d0
	bne.b	blkdev.wait
	rts

blkdev.pname
	; Print the device's name and version
	; Input:
	;  d7.b: device id

	lea	bss+buf(pc),a0
	bsr.w	blkdev.inq
	tst.b	d0
	rtsne

	lea	bss+buf+8(pc),a0

	clr.b	24(a0)                  ; Add an end of string marker
	print	(a0)                    ; Print the device string

	moveq	#0,d0
	rts

	ifne	stm32flash              ; Only if running from STM32 flash
blkdev.1byte
	; Read driver code with the specialized 1 byte command
	; Input:
	;  a0: target address
	;  d1.b: ACSI command to send
	;  d7.b: ACSI id
	; Output:
	;  a0: kept intact
	;  d0.l: 0 if success, 1 if failure
	;  Z: set if success, clear if failure

	st	flock.w                 ; Lock floppy drive

	lea	dmactrl.w,a1
	move.w	#$190,(a1)              ; Reset DMA
	move.w	#$90,(a1)               ; Read mode, set DMA length

	; DMA transfer address
	move.l	a0,d0
	move.b	d0,dmalow.w             ; Set DMA address low
	lsr.l	#8,d0                   ;
	move.b	d0,dmamid.w             ; Set DMA address mid
	lsr.w	#8,d0                   ;
	move.b	d0,dmahigh.w            ; Set DMA address high

	move.l	#$00ff0088,dma.w        ; Read 255 blocks. Switch to command.

	move.b	d7,d0                   ; Build command: ACSI id | command
	or.b	d1,d0                   ;
	swap	d0                      ; Command in data register, then DMA.
	move.l	d0,dma.w                ; Send command $d and start DMA

	; Wait until DMA ack (IRQ pulse)
	moveq	#20,d0                  ; 100ms timeout
	add.l	hz200.w,d0              ;
.await	cmp.l	hz200.w,d0              ; Test timeout
	bmi.b	.fail                   ;
	btst.b	#5,gpip.w               ; Test command acknowledge
	bne.b	.await                  ;

	move.w	#$008a,(a1)             ; Acknowledge status byte
	move.w	dma.w,d0                ;

	sf	flock.w                 ; Unlock floppy drive

	tst.b	d0                      ; If DMA failed,
	bne.b	.fail                   ; return error

	cmp.l	#'A2ST',(a0)            ; Check signature
	bne.b	.fail                   ;

	moveq	#0,d0
	rts
.fail	moveq	#1,d0
	rts

	endc

blkdev.waitkey
	; Wait for a key or an ACSI test unit ready error
	; Polls the ACSI device periodically to check for media
	; Calls Cconis as fast as possible to check for keyboard
	; Once either of these changes state, the function returns
	; Input:
	;  d7.b: ACSI id
	; Output:
	;  d0.w: Last Cconis result
	;  d1.l: Last blkdev.tst result

	movem.l	d3-d6,-(sp)

	moveq	#0,d5                   ; d5 = last Cconis result

	bsr.w	blkdev.tst              ; Compute expected blkdev.tst return
	move.w	d0,d4                   ; d4 = expected blkdev.tst result

.rescan	move.l	hz200.w,d3              ; Set refresh period
	add.l	#20,d3                  ;

	bsr.w	blkdev.tst              ; Scan the device
	move.l	d0,d6                   ; d6 = last blkdev.tst result
	cmp.w	d4,d6                   ; Check if the result is expected
	bne.b	.end                    ;

	addq.w	#1,d0                   ; If tst timed out, return immediately
	beq.b	.end                    ;

.wait	gemdos	Cconis,2                ; Check key pressed
	move.w	d0,d5                   ; Save last value
	bne.b	.end                    ; If a key was pressed, exit

	cmp.l	hz200.w,d3              ; Check for refresh timeout
	blt.b	.rescan                 ;

	bra.b	.wait                   ; Loop keyboard check

.end	move.l	d5,d0                   ; Return last values in normal registers
	move.l	d6,d1                   ;

	movem.l	(sp)+,d3-d6
	rts

blkdev.tst.c	; Test unit ready
	dc.b	4
	dc.b	$00,$00,$00,$00,$00,$00	; This one is easy
	even

blkdev.sns.c	; Request sense
	dc.b	4
	dc.b	$03,$00,$00,$00,$10,$00
	even

blkdev.inq.c	; Inquiry
	dc.b	4
	dc.b	$12,$00,$00,$00,$20,$00
	even

blkdev.cap.c	; Read capacity
	dc.b	9
	dc.b	$1f,$25
	dc.b	$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00
	even

blkdev.fmtsd.c	; Format SD card (ACSI2STM extension)
	dc.b	9
	dc.b	$1f,$20
	dc.b	'A2STFmtSd'
	even

blkdev.setrtc.c	; Set RTC clock time (UltraSatan extension)
	dc.b	9
	dc.b	$1f,$20
	dc.b	'USWrClRTC'
	even

; ACSI errors

blkerr.timeout	equ	-1
blkerr.ok	equ	0
blkerr.read	equ	$1103
blkerr.write	equ	$0303
blkerr.wprot	equ	$2707
blkerr.opcode	equ	$2005
blkerr.invaddr	equ	$2105
blkerr.invarg	equ	$2405
blkerr.invlun	equ	$2505
blkerr.mchange	equ	$2806
blkerr.nomedium	equ	$3a06

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm tw=80
