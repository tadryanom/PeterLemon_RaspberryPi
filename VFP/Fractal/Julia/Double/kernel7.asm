; Raspberry Pi 2 'Bare Metal' Julia Fractal Animation Demo by krom (Peter Lemon):
; 1. Set Cores 1..3 To Infinite Loop
; 2. Turn On L1 Cache
; 3. Turn On Vector Floating Point Unit
; 4. Setup Frame Buffer
; 5. Plot Fractal Using Double-Precision
; 6. Change Julia Settings & Redraw To Animate

format binary as 'img'
include 'LIB\FASMARM.INC'
include 'LIB\R_PI2.INC'

; Setup Frame Buffer
SCREEN_X       = 640
SCREEN_Y       = 480
BITS_PER_PIXEL = 32

org $0000

; Return CPU ID (0..3) Of The CPU Executed On
mrc p15,0,r0,c0,c0,5 ; R0 = Multiprocessor Affinity Register (MPIDR)
ands r0,3 ; R0 = CPU ID (Bits 0..1)
bne CoreLoop ; IF (CPU ID != 0) Branch To Infinite Loop (Core ID 1..3)

; Start L1 Cache
mrc p15,0,r0,c1,c0,0 ; R0 = System Control Register
orr r0,$0004 ; Data Cache (Bit 2)
orr r0,$0800 ; Branch Prediction (Bit 11)
orr r0,$1000 ; Instruction Caches (Bit 12)
mcr p15,0,r0,c1,c0,0 ; System Control Register = R0

; Enable Advanced SIMD & Vector Floating Point Calculations (NEON MPE)
mrc p15,0,r0,c1,c0,2 ; R0 = Access Control Register
orr r0,$300000 + $C00000 ; Enable Single & Double Precision
mcr p15,0,r0,c1,c0,2 ; Access Control Register = R0
mov r0,$40000000 ; R0 = Enable VFP
vmsr fpexc,r0 ; FPEXC = R0

FB_Init:
  imm32 r0,FB_STRUCT + MAIL_TAGS
  imm32 r1,PERIPHERAL_BASE + MAIL_BASE + MAIL_WRITE + MAIL_TAGS
  str r0,[r1] ; Mail Box Write

  ldr r0,[FB_POINTER] ; R0 = Frame Buffer Pointer
  cmp r0,0 ; Compare Frame Buffer Pointer To Zero
  beq FB_Init ; IF Zero Re-Initialize Frame Buffer

  and r0,$3FFFFFFF ; Convert Mail Box Frame Buffer Pointer From BUS Address To Physical Address ($CXXXXXXX -> $3XXXXXXX)
  str r0,[FB_POINTER] ; Store Frame Buffer Pointer Physical Address

ldr r1,[LAST_PIXEL]
add r1,r0 ; R1 = Frame Buffer Pointer Last Pixel

mov r2,SCREEN_X ; Load Double Screen X
fmsr s31,r2
fsitod d0,s31 ; D0 = X%
fcpyd d2,d0   ; D2 = SX

mov r2,SCREEN_Y ; Load Double Screen Y
fmsr s31,r2
fsitod d1,s31 ; D1 = Y%
fcpyd d3,d1   ; D3 = SY

fmrrd r8,r9,d2 ; R8 & R9 = SX
fmrrd r10,r11,d3 ; R10 & R11 = SY

fldd d4,[XMAX] ; D4 = XMax
fldd d5,[YMAX] ; D5 = YMax
fldd d6,[XMIN] ; D6 = XMin
fldd d7,[YMIN] ; D7 = YMin
fldd d8,[ANIM] ; D8 = Anim
fldd d9,[ONE]  ; D9 = 1.0

fsubd d4,d6 ; D4 = XMax - XMin
fsubd d5,d7 ; D5 = YMax - YMin
fdivd d2,d9,d2 ; D2 = (1.0 / SX)
fdivd d3,d9,d3 ; D3 = (1.0 / SY)

fcpyd d12,d9 ; D12 = CX (1.0)
fcpyd d13,d7 ; D13 = CY (-2.0)

ldr r12,[COL_MUL] ; R12 = Multiply Colour

Refresh:
  mov r2,r0 ; R2 = Frame Buffer Pointer
  mov r3,r1 ; R3 = Frame Buffer Pointer Last Pixel
  fmdrr d1,r10,r11 ; D1 = Y%
  LoopY:
    fmdrr d0,r8,r9 ; D0 = X%
    LoopX:
      fmuld d10,d0,d4 ; ZX = XMin + ((X% * (XMax - XMin)) * (1.0 / SX))
      fmuld d10,d2
      faddd d10,d6 ; D10 = ZX

      fmuld d11,d1,d5 ; ZY = YMin + ((Y% * (YMax - YMin)) * (1.0 / SY))
      fmuld d11,d3
      faddd d11,d7 ; D11 = ZY

      mov r4,192 ; R4 = IT (Iterations)
      Iterate:
	fmuld d14,d11,d11 ; XN = ((ZX * ZX) - (ZY * ZY)) + CX
	fmscd d14,d10,d10
	faddd d14,d12 ; D14 = XN

	fmuld d15,d10,d11 ; YN = (2 * ZX * ZY) + CY
	faddd d15,d15
	faddd d15,d13 ; D15 = YN

	fcpyd d10,d14 ; Copy XN & YN To ZX & ZY For Next Iteration
	fcpyd d11,d15

	fmuld d14,d14 ; R = (XN * XN) + (YN * YN)
	fmacd d14,d15,d15 ; D14 = R

	ftouid s31,d14 ; IF (R > 4) Plot
	fmrs r5,s31
	cmp r5,4
	bgt Plot

	subs r4,1 ; IT -= 1
	bne Iterate ; IF (IT != 0) Iterate

      Plot:
	mul r4,r12 ; R4 = Pixel Colour
	str r4,[r2],4  ; Store Pixel Colour To Frame Buffer (Top)
	str r4,[r3],-4 ; Store Pixel Colour To Frame Buffer (Bottom)

	fsubd d0,d9 ; Decrement X%
	fcmpzd d0
	fmstat
	bne LoopX ; IF (X% != 0) LoopX

	fsubd d1,d9 ; Decrement Y%
	cmp r2,r3 ; Compare Frame Buffer Top & Bottom
	blt LoopY ; IF (Y% < Frame Buffer Middle) LoopY

	fsubd d12,d8 ; Change Julia Settings
	faddd d13,d8
	b Refresh

CoreLoop: ; Infinite Loop For Core 1..3
  b CoreLoop

XMAX: dd 3.0
YMAX: dd 2.0
XMIN: dd -3.0
YMIN: dd -2.0
ANIM: dd 0.001
ONE:  dd 1.0

COL_MUL: dw $231AF9 ; Multiply Colour
LAST_PIXEL: dw (SCREEN_X * SCREEN_Y * (BITS_PER_PIXEL / 8)) - (BITS_PER_PIXEL / 8)

align 16
FB_STRUCT: ; Mailbox Property Interface Buffer Structure
  dw FB_STRUCT_END - FB_STRUCT ; Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  dw $00000000 ; Buffer Request/Response Code
	       ; Request Codes: $00000000 Process Request Response Codes: $80000000 Request Successful, $80000001 Partial Response
; Sequence Of Concatenated Tags
  dw Set_Physical_Display ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw SCREEN_X ; Value Buffer
  dw SCREEN_Y ; Value Buffer

  dw Set_Virtual_Buffer ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw SCREEN_X ; Value Buffer
  dw SCREEN_Y ; Value Buffer

  dw Set_Depth ; Tag Identifier
  dw $00000004 ; Value Buffer Size In Bytes
  dw $00000004 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw BITS_PER_PIXEL ; Value Buffer

  dw Set_Virtual_Offset ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_OFFSET_X:
  dw 0 ; Value Buffer
FB_OFFSET_Y:
  dw 0 ; Value Buffer

  dw Allocate_Buffer ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_POINTER:
  dw 0 ; Value Buffer
  dw 0 ; Value Buffer

dw $00000000 ; $0 (End Tag)
FB_STRUCT_END: