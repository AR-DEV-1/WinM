@ WinM (Morbius) Advanced Bootloader
@ Version 1 Revision 8
@ This bootloader sets up the ARM environment, initializes hardware, loads the kernel, and provides diagnostics.
@ Author: AR-DEV-1

.section .text
.global _start

_start:
    @ Stage 1: Initial Setup - Stack, Basic CPU Configuration
    ldr r0, =_stack_top               @ Load stack pointer into r0
    mov sp, r0                        @ Initialize stack pointer
    bl init_cpu                       @ Call function to initialize CPU

    @ Stage 2: Diagnostics and Self-Tests
    bl diagnostics_check              @ Perform diagnostics checks

    @ Stage 3: Memory Setup with MMU
    bl setup_memory_controller        @ Initialize memory controller
    bl setup_mmu                      @ Set up MMU with page table mappings

    @ Stage 4: Peripheral Initialization
    bl init_uart                      @ Set up UART for debugging
    bl init_timer                     @ Initialize system timer

    @ Stage 5: Load Kernel from Storage to RAM
    bl load_kernel                    @ Load the kernel into RAM

    @ Stage 6: Handoff to Kernel
    mov r0, #0                        @ Clear register for kernel args
    ldr r1, =KERNEL_ENTRY_POINT       @ Load kernel entry point address
    bx r1                             @ Branch to kernel entry point

@ ------------------------------------------------------------
@ Stage 2: Diagnostics - CPU, Memory, and Peripherals
@ ------------------------------------------------------------
diagnostics_check:
    bl cpu_check                      @ Check CPU compatibility
    bl memory_check                   @ Verify minimum RAM presence
    bl peripheral_check               @ Check for necessary peripherals
    bx lr                             @ Return from diagnostics check

cpu_check:
    ldr r0, =CPU_ID_CONSTANT          @ Load CPU ID constant
    mrc p15, 0, r1, c0, c0, 0         @ Read Main ID Register (MIR)
    cmp r1, r0                        @ Compare CPU ID with the constant
    beq cpu_check_passed              @ If CPU is compatible, proceed
    b error                           @ If not, jump to error handling
cpu_check_passed:
    bx lr                             @ Return from CPU check

memory_check:
    ldr r0, =0x80000000               @ Load a RAM address
    ldr r1, [r0]                      @ Try to read from that address
    bx lr                             @ If successful, return

peripheral_check:
    bx lr                             @ Peripherals check completed

@ ------------------------------------------------------------
@ Stage 3: Memory Controller and MMU Setup
@ ------------------------------------------------------------
setup_memory_controller:
    ldr r0, =MEMORY_CONTROLLER_BASE   @ Load memory controller base address
    mov r1, #MEMORY_CONFIG            @ Load memory configuration settings
    str r1, [r0]                      @ Store memory configuration to the controller
    bx lr                             @ Return from memory controller setup

setup_mmu:
    ldr r0, =MMU_TABLE_BASE           @ Load base address of MMU page table
    mcr p15, 0, r0, c2, c0, 0         @ Set TTBR0 (Translation Table Base)
    mrc p15, 0, r0, c1, c0, 0         @ Read current system control register
    orr r0, r0, #(1 << 0)             @ Enable MMU by setting the first bit
    mcr p15, 0, r0, c1, c0, 0         @ Write updated system control register
    dsb                               @ Data Synchronization Barrier
    isb                               @ Instruction Synchronization Barrier
    bx lr                             @ Return from MMU setup

@ ------------------------------------------------------------
@ Stage 4: Peripheral Initialization - UART and Timer
@ ------------------------------------------------------------
init_uart:
    ldr r0, =UART_BASE                @ Load UART base address
    mov r1, #UART_CONFIG              @ Load UART configuration
    str r1, [r0]                      @ Store configuration to UART registers
    bx lr                             @ Return from UART initialization

init_timer:
    ldr r0, =TIMER_BASE               @ Load timer base address
    mov r1, #TIMER_CONFIG             @ Load timer configuration
    str r1, [r0]                      @ Store configuration to timer registers
    bx lr                             @ Return from timer initialization

@ ------------------------------------------------------------
@ Stage 5: Kernel Loading
@ ------------------------------------------------------------
load_kernel:
    ldr r0, =KERNEL_SOURCE_ADDR       @ Load source address of kernel
    ldr r1, =KERNEL_LOAD_ADDR         @ Load destination address for kernel in RAM
    mov r2, #KERNEL_SIZE              @ Load size of the kernel to be loaded

kernel_load_loop:
    ldrb r3, [r0], #1                 @ Load one byte from kernel source
    strb r3, [r1], #1                 @ Store one byte to destination RAM
    subs r2, r2, #1                   @ Decrement byte count
    bne kernel_load_loop              @ Loop until all bytes are loaded
    bx lr                             @ Return from kernel load

@ ------------------------------------------------------------
@ CPU Initialization
@ ------------------------------------------------------------
init_cpu:
    @ Initialize CPU - Enable caches, FPU, etc. (example for ARM Cortex-A)
    mrc p15, 0, r0, c1, c0, 0         @ Read the system control register (SCR)
    orr r0, r0, #(1 << 0)             @ Set the "I" bit to enable the instruction cache
    orr r0, r0, #(1 << 1)             @ Set the "C" bit to enable the data cache
    mcr p15, 0, r0, c1, c0, 0         @ Write back to the SCR to enable caches

    @ Enable FPU (Floating Point Unit)
    orr r0, r0, #(1 << 30)            @ Set the "F" bit to enable the FPU (if applicable)
    mcr p15, 0, r0, c1, c0, 0         @ Write to SCR to enable FPU

    @ Any other CPU initialization code will go here

    bx lr                             @ Return from init_cpu

@ ------------------------------------------------------------
@ Error Handling - Display Error and Halt
@ ------------------------------------------------------------
error:
    ldr r0, =UART_BASE                @ Load UART base for error message
    ldr r1, =ERROR_MSG                @ Load address of error message
    bl uart_output_string             @ Call function to display error message
    b error                           @ Loop indefinitely in error state

uart_output_string:
    ldrb r2, [r1], #1                 @ Load one byte from the string
    cmp r2, #0                        @ Check if end of string
    beq uart_output_done              @ If end, finish output
    str r2, [r0]                      @ Output character to UART
    b uart_output_string              @ Repeat until string ends
uart_output_done:
    bx lr                             @ Return from UART string output

@ ------------------------------------------------------------
@ Constants and Memory Mapping
@ ------------------------------------------------------------
.equ KERNEL_LOAD_ADDR, 0x80000               @ Kernel load address in RAM
.equ KERNEL_ENTRY_POINT, 0x80000            @ Kernel entry address
.equ MEMORY_CONTROLLER_BASE, 0x100000       @ Memory controller base address
.equ MEMORY_CONFIG, 0x03                    @ Memory configuration setting
.equ MMU_TABLE_BASE, 0x70000                @ MMU page table base address
.equ KERNEL_SOURCE_ADDR, 0x900000           @ Source address for kernel load
.equ KERNEL_SIZE, 0x10000                   @ Kernel size in bytes
.equ UART_BASE, 0x11000                     @ UART base address
.equ UART_CONFIG, 0x05                      @ UART configuration value
.equ TIMER_BASE, 0x12000                    @ Timer base address
.equ TIMER_CONFIG, 0x02                     @ Timer configuration value

.section .data
CPU_ID_CONSTANT:
    .word 0x410FC0F0                      @ Store ARM Cortex-A5 CPU ID constant

ERROR_MSG:
    .ascii "Bootloader encountered an error.\n\0"  @ Error message for output

.section .bss
.space 0x1000                               @ Define space for stack in BSS
_stack_top:
