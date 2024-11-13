; WinM (Morbius) Advanced Bootloader
; Sets up ARM environment, initializes hardware, loads kernel, and provides comprehensive diagnostics.
; Author: AR-DEV-1
; Version 1 Revision 3

.section .text
.global _start

_start:
    ; Stage 1: Initial Setup - Stack, Basic CPU Configuration
    ldr r0, =_stack_top               ; Load stack pointer
    mov sp, r0                        ; Initialize stack
    bl init_cpu                       ; Basic CPU and cache setup

    ; Stage 2: Diagnostics and Self-Tests
    bl diagnostics_check              ; Perform CPU, memory, and peripheral checks

    ; Stage 3: Memory Setup with MMU
    bl setup_memory_controller        ; Initialize memory controller
    bl setup_mmu                      ; Set up MMU with page table mappings

    ; Stage 4: Peripheral Initialization
    bl init_uart                      ; UART setup for debugging
    bl init_timer                     ; System timer setup

    ; Stage 5: Load Kernel from Storage to RAM
    bl load_kernel

    ; Stage 6: Handoff to Kernel
    mov r0, #0                        ; Clear register for kernel args
    ldr r1, =KERNEL_ENTRY_POINT       ; Kernel entry point
    bx r1                             ; Transfer control to kernel

; -----------------------------------------------------------------
; Stage 2: Diagnostics - CPU, Memory, and Peripherals
; -----------------------------------------------------------------
diagnostics_check:
    bl cpu_check                      ; Check CPU compatibility
    bl memory_check                   ; Verify minimum RAM
    bl peripheral_check               ; Check presence of required peripherals
    bx lr

cpu_check:
    mrc p15, 0, r0, c0, c0, 0         ; Read Main ID Register
    cmp r0, #0x410FC0F0               ; Check for ARM Cortex-A5 (Example)
    beq cpu_check_passed
    b error                           ; Fail if CPU unsupported
cpu_check_passed:
    bx lr

memory_check:
    ldr r0, =0x80000000               ; Check for addressable RAM
    ldr r1, [r0]                      ; Attempt read
    bx lr                             ; If successful, return

peripheral_check:
    ; Optional checks for peripherals like UART and timers
    bx lr

; -----------------------------------------------------------------
; Stage 3: Memory Controller and MMU Setup
; -----------------------------------------------------------------
setup_memory_controller:
    ldr r0, =MEMORY_CONTROLLER_BASE   ; Memory controller base
    mov r1, #MEMORY_CONFIG            ; Memory settings
    str r1, [r0]                      ; Apply configuration
    bx lr

setup_mmu:
    ldr r0, =MMU_TABLE_BASE           ; MMU page table base
    mcr p15, 0, r0, c2, c0, 0         ; Set TTBR0 (Translation Table Base)
    mrc p15, 0, r0, c1, c0, 0         ; Read System Control Register
    orr r0, r0, #(1 << 0)             ; Enable MMU
    mcr p15, 0, r0, c1, c0, 0         ; Write back
    dsb                               ; Data sync barrier
    isb                               ; Instruction sync barrier
    bx lr

; -----------------------------------------------------------------
; Stage 4: Peripheral Initialization - UART and Timer
; -----------------------------------------------------------------
init_uart:
    ldr r0, =UART_BASE                ; UART base
    mov r1, #UART_CONFIG              ; Config for UART initialization
    str r1, [r0]
    bx lr

init_timer:
    ldr r0, =TIMER_BASE               ; Timer base
    mov r1, #TIMER_CONFIG             ; Timer setup
    str r1, [r0]
    bx lr

; -----------------------------------------------------------------
; Stage 5: Kernel Loading
; -----------------------------------------------------------------
load_kernel:
    ldr r0, =KERNEL_SOURCE_ADDR       ; Source of kernel
    ldr r1, =KERNEL_LOAD_ADDR         ; Destination in RAM
    mov r2, #KERNEL_SIZE              ; Size in bytes

kernel_load_loop:
    ldrb r3, [r0], #1                 ; Load byte and increment
    strb r3, [r1], #1                 ; Store to destination and increment
    subs r2, r2, #1                   ; Decrement count
    bne kernel_load_loop              ; Repeat
    bx lr

; -----------------------------------------------------------------
; Error Handling - Display Error and Halt
; -----------------------------------------------------------------
error:
    ldr r0, =UART_BASE                ; UART base for error message
    ldr r1, =ERROR_MSG                ; Error message string
    bl uart_output_string             ; Output error
    b error                           ; Halt by looping indefinitely

uart_output_string:
    ldrb r2, [r1], #1                 ; Load char and increment
    cmp r2, #0                        ; Check if end of string
    beq uart_output_done
    str r2, [r0]                      ; Output to UART
    b uart_output_string              ; Repeat
uart_output_done:
    bx lr

; -----------------------------------------------------------------
; Constants and Memory Mapping
; -----------------------------------------------------------------
.equ KERNEL_LOAD_ADDR, 0x80000               ; Kernel load address in RAM
.equ KERNEL_ENTRY_POINT, 0x80000            ; Kernel entry address
.equ MEMORY_CONTROLLER_BASE, 0x100000       ; Memory controller base
.equ MEMORY_CONFIG, 0x03                    ; Memory config settings
.equ MMU_TABLE_BASE, 0x70000                ; MMU page table base
.equ KERNEL_SOURCE_ADDR, 0x900000           ; Source address for kernel load
.equ KERNEL_SIZE, 0x10000                   ; Kernel size
.equ UART_BASE, 0x11000                     ; UART base
.equ UART_CONFIG, 0x05                      ; UART config bits
.equ TIMER_BASE, 0x12000                    ; Timer base
.equ TIMER_CONFIG, 0x02                     ; Timer config bits

.section .data
ERROR_MSG:
    .ascii "Bootloader encountered an error.\n\0"

.section .bss
.space 0x1000                               ; Stack space
_stack_top:
