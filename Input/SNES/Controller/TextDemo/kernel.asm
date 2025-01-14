; Raspberry Pi 'Bare Metal' Input SNES Controller Text Demo by krom (Peter Lemon):
; 1. Setup Frame Buffer
; 2. Initialize & Update Input Data
; 3. Print RAW Hex Values To Screen

macro PrintText Text, TextLength {
  local .DrawChars,.DrawChar
  imm32 r1,Font ; R1 = Characters
  imm32 r2,Text ; R2 = Text Offset
  mov r3,TextLength ; R3 = Number Of Text Characters To Print
  .DrawChars:
    mov r4,CHAR_Y ; R4 = Character Row Counter
    ldrb r5,[r2],1 ; R5 = Next Text Character
    add r5,r1,r5,lsl 6 ; Add Shift To Correct Position In Font (* 64)

    .DrawChar:
      ldr r6,[r5],4 ; Load Font Text Character 1/2 Row
      str r6,[r0],4 ; Store Font Text Character 1/2 Row To Frame Buffer
      ldr r6,[r5],4 ; Load Font Text Character 1/2 Row
      str r6,[r0],4 ; Store Font Text Character 1/2 Row To Frame Buffer
      add r0,SCREEN_X ; Jump Down 1 Scanline
      sub r0,CHAR_X ; Jump Back 1 Char
      subs r4,1 ; Decrement Character Row Counter
      bne .DrawChar ; IF (Character Row Counter != 0) DrawChar

    subs r3,1 ; Subtract Number Of Text Characters To Print
    sub r0,SCREEN_X * CHAR_Y ; Jump To Top Of Char
    add r0,CHAR_X ; Jump Forward 1 Char
    bne .DrawChars ; IF (Number Of Text Characters != 0) Continue To Print Characters
}

macro PrintValueLE Value, ValueLength {
  local .DrawHEXChars,.DrawHEXChar,.DrawHEXCharB
  imm32 r1,Font ; R1 = Characters
  imm32 r2,Value ; R2 = Text Offset
  add r2,ValueLength - 1
  mov r3,ValueLength ; R3 = Number Of HEX Characters To Print
  .DrawHEXChars:
    ldrb r4,[r2],-1 ; R4 = Next 2 HEX Characters
    lsr r5,r4,4 ; Get 2nd Nibble
    cmp r5,$9
    addle r5,$30
    addgt r5,$37
    add r5,r1,r5,lsl 6 ; Add Shift To Correct Position In Font (* 64)
    mov r6,CHAR_Y ; R6 = Character Row Counter
    .DrawHEXChar:
      ldr r7,[r5],4 ; Load Font Text Character 1/2 Row
      str r7,[r0],4 ; Store Font Text Character 1/2 Row To Frame Buffer
      ldr r7,[r5],4 ; Load Font Text Character 1/2 Row
      str r7,[r0],4 ; Store Font Text Character 1/2 Row To Frame Buffer
      add r0,SCREEN_X ; Jump Down 1 Scanline
      sub r0,CHAR_X ; Jump Back 1 Char
      subs r6,1 ; Decrement Character Row Counter
      bne .DrawHEXChar ; IF (Character Row Counter != 0) DrawChar

    sub r0,SCREEN_X * CHAR_Y ; Jump To Top Of Char

    add r0,CHAR_X ; Jump Forward 1 Char
    and r5,r4,$F ; Get 1st Nibble
    cmp r5,$9
    addle r5,$30
    addgt r5,$37
    add r5,r1,r5,lsl 6 ; Add Shift To Correct Position In Font (* 64)
    mov r6,CHAR_Y ; R6 = Character Row Counter
    .DrawHEXCharB:
      ldr r7,[r5],4 ; Load Font Text Character 1/2 Row
      str r7,[r0],4 ; Store Font Text Character 1/2 Row To Frame Buffer
      ldr r7,[r5],4 ; Load Font Text Character 1/2 Row
      str r7,[r0],4 ; Store Font Text Character 1/2 Row To Frame Buffer
      add r0,SCREEN_X ; Jump Down 1 Scanline
      sub r0,CHAR_X ; Jump Back 1 Char
      subs r6,1 ; Decrement Character Row Counter
      bne .DrawHEXCharB ; IF (Character Row Counter != 0) DrawChar

    subs r3,1 ; Subtract Number Of HEX Characters To Print
    sub r0,SCREEN_X * CHAR_Y ; Jump To Top Of Char
    add r0,CHAR_X ; Jump Forward 1 Char
    bne .DrawHEXChars ; IF (Number Of Hex Characters != 0) Continue To Print Characters
}

macro PrintTAGValueLE Text, TextLength, Value, ValueLength {
  PrintText Text, TextLength
  PrintValueLE Value, ValueLength
}

macro Delay amount {
  local .DelayLoop
  imm32 r12,amount
  .DelayLoop:
    subs r12,1
    bne .DelayLoop
}

format binary as 'img'
include 'LIB\FASMARM.INC'
include 'LIB\R_PI.INC'

; Setup Frame Buffer
SCREEN_X       = 640
SCREEN_Y       = 480
BITS_PER_PIXEL = 8

; Setup Characters
CHAR_X = 8
CHAR_Y = 8

org $0000

FB_Init:
  imm32 r0,FB_STRUCT + MAIL_TAGS
  imm32 r1,PERIPHERAL_BASE + MAIL_BASE + MAIL_WRITE + MAIL_TAGS
  str r0,[r1] ; Mail Box Write

  ldr r0,[FB_POINTER] ; R0 = Frame Buffer Pointer
  cmp r0,0 ; Compare Frame Buffer Pointer To Zero
  beq FB_Init ; IF Zero Re-Initialize Frame Buffer

  and r0,$3FFFFFFF ; Convert Mail Box Frame Buffer Pointer From BUS Address To Physical Address ($CXXXXXXX -> $3XXXXXXX)
  str r0,[FB_POINTER] ; Store Frame Buffer Pointer Physical Address

;;;;;;;;;;;;;;;;;;;;;;
;; Initialize Input ;;
;;;;;;;;;;;;;;;;;;;;;;
; Set GPIO 10 & 11 (Clock & Latch) Function To Output
imm32 r0,PERIPHERAL_BASE + GPIO_BASE
mov r1,GPIO_FSEL0_OUT + GPIO_FSEL1_OUT
str r1,[r0,GPIO_GPFSEL1]

;;;;;;;;;;;;;;;;;;
;; Update Input ;;
;;;;;;;;;;;;;;;;;;
UpdateInput:
  imm32 r0,PERIPHERAL_BASE + GPIO_BASE ; Set GPIO 11 (Latch) Output State To HIGH
  mov r1,GPIO_11
  str r1,[r0,GPIO_GPSET0]
  Delay 32

  mov r1,GPIO_11 ; Set GPIO 11 (Latch) Output State To LOW
  str r1,[r0,GPIO_GPCLR0]
  Delay 32

  mov r1,0  ; R1 = Input Data
  mov r2,15 ; R2 = Input Data Count
  LoopInputData:
    ldr r3,[r0,GPIO_GPLEV0] ; Get GPIO 4 (Data) Level
    tst r3,GPIO_4
    moveq r3,1 ; GPIO 4 (Data) Level LOW
    orreq r1,r3,lsl r2

    mov r3,GPIO_10 ; Set GPIO 10 (Clock) Output State To HIGH
    str r3,[r0,GPIO_GPSET0]
    Delay 32

    mov r3,GPIO_10 ; Set GPIO 10 (Clock) Output State To LOW
    str r3,[r0,GPIO_GPCLR0]
    Delay 32

    subs r2,1
    bge LoopInputData ; Loop 16bit Data

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; R1 Now Contains Input Data ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
str r1,[DataValue]

adr r1,FB_POINTER
ldr r0,[r1] ; R0 = Frame Buffer Pointer
imm32 r1,(320 * 50) + 160
add r0,r1
PrintTAGValueLE Text, 22, DataValue, 2

b UpdateInput ; Refresh Input Data

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

  dw Set_Palette ; Tag Identifier
  dw $00000010 ; Value Buffer Size In Bytes
  dw $00000010 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw 0 ; Value Buffer (Offset: First Palette Index To Set (0-255))
  dw 2 ; Value Buffer (Length: Number Of Palette Entries To Set (1-256))
FB_PAL:
  dw $00000000,$FFFFFFFF ; RGBA Palette Values (Offset To Offset+Length-1)

  dw Allocate_Buffer ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_POINTER:
  dw 0 ; Value Buffer
  dw 0 ; Value Buffer

dw $00000000 ; $0 (End Tag)
FB_STRUCT_END:

Text: db "SNES Controller Test: "

align 4
DataValue: dw 0
Font: include 'Font8x8.asm'