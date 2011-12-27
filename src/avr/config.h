#define SYSCLK 20000000UL
#define F_CPU 20000000UL

// 57600 baud with doubling enabled
#define BAUD_PRESCALE 42
#define UARTDBL 1

/* UART BUFFER DATA */
#define UART_RX_BUFSZ   128
#define UART_TX_BUFSZ   128

#define EEG_SYNC   0xAA
#define EEG_EXCODE 0x55
