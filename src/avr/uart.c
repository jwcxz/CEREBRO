/* UART FUNCTIONS */

#include "uart.h"

void uart_init(void) {
    // want 57.6k => ubrr = 42, u2xn = 1

    // UART 0 is the PC <- AVR interface
	UBRR0H = (unsigned char) (BAUD_PRESCALE>>8);
	UBRR0L = (unsigned char) BAUD_PRESCALE;
    UCSR0A = ( _BV(U2X0) );
	//UCSR0B = ( _BV(RXCIE0) | _BV(RXEN0) | _BV(TXCIE0) | _BV(TXEN0) );
	UCSR0B = ( _BV(TXCIE0) | _BV(TXEN0) );
	UCSR0C = ( _BV(UCSZ01) | _BV(UCSZ00) ); // 8 bits, 1 stop bit, no parity

    // UART 1 is the AVR <- EEG interface
	UBRR1H = (uint8_t) (BAUD_PRESCALE>>8);
	UBRR1L = (uint8_t) BAUD_PRESCALE;
    UCSR1A = ( _BV(U2X0) );
	UCSR0B = ( _BV(RXCIE0) | _BV(RXEN0) );  // no transmit capability to the eeg
	UCSR0C = ( _BV(UCSZ01) | _BV(UCSZ00) ); // 8 bits, 1 stop bit, no parity

    // reset pointers
    avrcom_i = avrcom;
    avrcom_o = avrcom;
    avrcom_c = 0;

    eegavr_i = eegavr;
    eegavr_o = eegavr;
    eegavr_c = 0;
}

uint8_t eegavr_rx(void) {
	uint8_t tmp;
	while ( eegavr_c == 0 );

    cli();              // lock
	tmp = *eegavr_o;
	eegavr_c--;

	eegavr_o++;
	if ( eegavr_o >= eegavr + UART_RX_BUFSZ )
		eegavr_o = eegavr;

    sei();              // unlock
	return tmp;
}

uint8_t eegavr_dr(void) {
	return ( eegavr_c );
}

void avrcom_tx(uint8_t data) {
	while ( avrcom_c >= UART_TX_BUFSZ );

    cli();              // lock
	*avrcom_i = data;
	avrcom_c++;

	avrcom_i++;
	if ( avrcom_i >= avrcom + UART_TX_BUFSZ )
		avrcom_i = avrcom;

	_ON(UCSR0B,UDRIE0);
    sei();              // unlock
}

/* INTERRUPT VECTORS */

/* AVR <- EEG receive */
ISR(USART1_RX_vect) {
	uint8_t data;

    data = UDR1;

    if ( eegavr_c <= UART_RX_BUFSZ ) {
        *eegavr_i = data;
        eegavr_c++;

        eegavr_i++;
        if ( eegavr_i >= eegavr + UART_RX_BUFSZ )
            eegavr_i = eegavr;
    }
}

/* PC <- AVR receive */
/* XXX: not used right now
ISR(USART0_RX_vect) {
	unsigned char data;

    data = UDR0;

    if ( uart_rxbuf_count <= UART_RX_BUFSZ ) {
        *uart_rxbuf_iptr = data;
        uart_rxbuf_count++;

        uart_rxbuf_iptr++;
        if ( uart_rxbuf_iptr >= uart_rxbuf + UART_RX_BUFSZ )
            uart_rxbuf_iptr = uart_rxbuf;
    }
}
*/

/* PC <- AVR transmit */
ISR(USART0_TX_vect) {
	if ( avrcom_c > 0 ) {
		UDR0 = *avrcom_o;
		avrcom_c--;

		avrcom_o++;
		if ( avrcom_o >= avrcom + UART_TX_BUFSZ )
			avrcom_o = avrcom;
	} else {
		_OFF(UCSR0B, UDRIE0);
	}
}
