/*
 * very simple program to read EEG data from a ThinkGear EEG and output a CSV
 * string of the following fields
 *      signalquality,attention,meditation,delta,theta,lowalpha,highalpha,lowbeta,highbeta,lowgamma,highgamma
 * this can be interfaced with the visualizer located at 
 *      http://github.com/kitschpatrol/Processing-Brain-Grapher/zipball/master
 */
#include "main.h"
#include "uart.h"

volatile uint8_t eegavr[UART_RX_BUFSZ];
volatile uint8_t* eegavr_i, * eegavr_o;
volatile uint8_t eegavr_c;

volatile uint8_t avrcom[UART_TX_BUFSZ];
volatile uint8_t* avrcom_i, * avrcom_o;
volatile uint8_t avrcom_c;


static uint8_t payload[169];   // max data size is 169 bytes
static uint8_t plength;

typedef struct {
    uint8_t poor_signal,
            attention,
            meditation,
            blink;      // I don't think this is ever given
    
    // fft power values
    uint16_t delta,
             theta,
             loalpha,
             hialpha,
             lobeta,
             hibeta,
             logamma,
             mdgamma;
} eeg_data;


int main(void) {
	UBRR0H = (unsigned char) (42>>8);
	UBRR0L = (unsigned char) 42;
    UCSR0A = ( _BV(U2X0) );
	UCSR0B = ( _BV(RXEN0) | _BV(TXEN0) );
	UCSR0C = ( _BV(UCSZ01) | _BV(UCSZ00) ); // 8 bits, 1 stop bit, no parity

    while (1) {
        while ( ( UCSR0A & _BV(UDRE0) ) == 0 );
        UDR0 = 'h';
    }
    
    /*------------------*/

    // initialize UART
    uart_init();
    // enable interrupts
    sei();

    uint8_t data, payload_c, checksum;

    // loosely based on mindset_communications_protocol.pdf
    while (1) {
        // two [SYNC] bytes begin a packet
        data = eegavr_rx();
        if ( data != EEG_SYNC ) continue;
        data = eegavr_rx();
        if ( data != EEG_SYNC ) continue;

        // get packet length -- [PLENGTH]
        // note: code differs from their (insane) implementation
        do {
            data = eegavr_rx();
        } while ( data >= EEG_SYNC );   // PLENGTH is never higher than 169
        plength = data;

        // get payload
        // note: code differs from their (fread-based) implementation
        payload_c = 0;
        while (payload_c < plength) {
            payload[payload_c] = eegavr_rx();
        }

        // calculate checksum
        // note: code differs from their (insane) implementation
        checksum = 0;
        for ( payload_c=0 ; payload_c<plength ; payload_c++ ) checksum += payload[payload_c];
        checksum = ~checksum;
        
        // compare against checksum byte
        if ( checksum != eegavr_rx() ) continue;

        //process_payload();
    }

	return 0;
}

void process_payload(void) {
    // iterate through the payload and pull data into struct
    // EXCODES are not used in the protocol, so we don't need to handle them

    uint8_t pptr = 0;   // current packet byte we're processing
    
    while (pptr < plength) {
        // first byte is going to be a command
        switch (payload[pptr]) {
            case 0x02:  // poor signal quality
                break;
            case 0x04:  // attention (0-100)
                break;
case :
        }
    }
}
