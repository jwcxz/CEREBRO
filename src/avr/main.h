#include "config.h"
#include "macros.h"

#include <inttypes.h>
#include <util/delay.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>

/* UART BUFFERS */
extern volatile uint8_t eegavr[UART_RX_BUFSZ];
extern volatile uint8_t* eegavr_i, * eegavr_o;
extern volatile uint8_t eegavr_c;

extern volatile uint8_t avrcom[UART_TX_BUFSZ];
extern volatile uint8_t* avrcom_i, * avrcom_o;
extern volatile uint8_t avrcom_c;

int main(void);
void process_payload(void);
