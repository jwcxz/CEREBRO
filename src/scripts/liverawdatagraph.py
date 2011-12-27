#!/usr/bin/env python2

# EEG Data Analyzer - Live Plotting
# this program partially implements NeuroSky's MindSet protocol (enough to get
# the post-FFT EEG data that comes out of the MindFlex toy)

import serial, sys
import Gnuplot, math

class EEGAnalyzer:
    # states
    s = { 'sync1': 0, 'sync2': 1, 'plnth': 2, 'payld': 3, 'chksm': 4 };

    # command values
    v = {
            'sync': int('aa', 16),
            'sgnl': int('02', 16),
            'eegp': int('83', 16),
            'attn': int('04', 16),
            'mdtn': int('05', 16)
        }

    # colors
    c = [
            '#660000',
            '#663300',
            '#a35200',
            '#666600',
            '#336600',
            '#006600',
            '#006666',
            '#003366'
        ];

    # labels
    l = [
            'delta [0.5-2.75 Hz]',
            'theta [3.5-6.75 Hz]',
            'low alpha [7.5-9.25 Hz]',
            'high alpha [10-11.75 Hz]',
            'low beta [13-16.75 Hz]',
            'high beta [18-29.75 Hz]',
            'low gamma [31-39.75 Hz]',
            'high gamma [41-49.75 Hz]'
        ];

    def __init__(self):
        self.state = self.s['sync1'];
        self.data = [];
        for i in xrange(11): self.data.append([]);

    def process_packet(self):
        # [ signl, delta, theta, lalph, halph, lbeta, hbeta, lgamm, hgamm, attn, mdtn ]
        p = self.packet;
        out = [];
        for i in xrange(11): out.append(0);

        i = 0;
        while i < len(p):
            if p[i] == self.v['sgnl']:
                i += 1
                out[0] = p[i]
            elif p[i] == self.v['eegp']:
                i += 2
                for j in xrange(1,9):
                    out[j] = (p[i] << 16) + (p[i+1] << 8) + p[i+2];
                    i += 3;
                i -= 1;     # correct for +1 below
            elif p[i] == self.v['attn']:
                i += 1;
                out[9] = p[i];
            elif p[i] == self.v['mdtn']:
                i += 1;
                out[10] = p[i];

            i += 1

        return out

    def update(self, newbyte):
        # convert received character to integer
        newbyte = ord(newbyte);

        if self.state == self.s['sync1']:
            self.plength = self.pcount = 0;
            self.csum = 0;
            self.packet = [];

            if newbyte == self.v['sync']:
                self.state = self.s['sync2'];

        elif self.state == self.s['sync2']:
            if newbyte == self.v['sync']:
                self.state = self.s['plnth'];

        elif self.state == self.s['plnth']:
            self.plength = newbyte;
            self.state = self.s['payld'];

        elif self.state == self.s['payld']:
            self.packet.append(newbyte);
            self.csum += newbyte;
            self.pcount += 1;
            if self.pcount == self.plength:
                self.state = self.s['chksm'];

        elif self.state == self.s['chksm']:
            self.csum = ~self.csum & 255;
            if self.csum == newbyte: match = "okay";
            else: match = "NO GOOD!";
            print "  chksm: ", self.csum, newbyte, "=>", match

            if self.csum == newbyte:
                _ = self.process_packet();
                print _
                for i in xrange(11):
                    self.data[i].append(_[i]);

            self.state = self.s['sync1'];

        else:
            print "uh..."
            sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) == 1:
        serport = "/dev/ttyS0";
    else:
        serport = sys.argv[1];

    cxn = serial.Serial(serport, 9600, parity=serial.PARITY_NONE);
    print ":: opened", cxn.portstr;

    eeg = EEGAnalyzer();

    while True:
        byte = cxn.read(1);
        eeg.update(byte);
