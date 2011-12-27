#!/usr/bin/env python2

# EEG Data Analyzer
# this program partially implements NeuroSky's MindSet protocol (enough to get
# the post-FFT EEG data that comes out of the MindFlex toy)

import sys
import numpy as np
import matplotlib.pyplot as plt

# table of values
v = {
        'sync': int('aa', 16),
        'sgnl': int('02', 16),
        'eegp': int('83', 16),
        'attn': int('04', 16),
        'mdtn': int('05', 16)
    }

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


def process_packet(p):
    # [ signl, delta, theta, lalph, halph, lbeta, hbeta, lgamm, hgamm, attn, mdtn ]
    out = [];
    for i in xrange(11): out.append(0);

    i = 0;
    while i < len(p):
        if p[i] == v['sgnl']:
            i += 1
            out[0] = p[i]
        elif p[i] == v['eegp']:
            i += 2
            for j in xrange(1,9):
                out[j] = (p[i] << 16) + (p[i+1] << 8) + p[i+2];
                i += 3;
            i -= 1;     # correct for +1 below
        elif p[i] == v['attn']:
            i += 1;
            out[9] = p[i];
        elif p[i] == v['mdtn']:
            i += 1;
            out[10] = p[i];

        i += 1

    return out

if __name__ == "__main__":
    # open file
    # the file format is a hex string serial dump separated by spaces
    # e.g. "aa aa 00 01 02 03"
    f = open(sys.argv[1], 'r');
    hexstring = f.read();

    hx = [];
    # convert all strings into characters
    hexstrarr = hexstring.split(' ');
    for h in hexstrarr:
        if h != "": hx.append(int(h, 16));

    packets = [];
    i = 0
    try:
        while i < len(hx):
            if hx[i] == v['sync']:
                i += 1;
                if hx[i] == v['sync']:
                    i += 1;
                    if hx[i] < 170:
                        plength = hx[i]
                        i += 1;
                        j = i;
                        packet = [];
                        csum = 0;
                        while j < i+plength:
                            csum += hx[j];
                            packet.append(hx[j]);
                            j += 1;
                        i += plength;
                        csum = csum & 255;
                        csum = ~csum & 255;
                        if csum == hx[i]: match = "ok";
                        else: match = "NO GOOD!";
                        print "Checksum [calc, got]:", csum, hx[i], "=>", match
                        packets.append(packet)
            i += 1
    except IndexError, e:
        print "ran out of bytes :("

    print ""
    print "--------- PROCESSING PACKETS ---------"

    data = [];
    for i in xrange(11): data.append([]);

    for p in packets:
        # [ signl, delta, theta, lalph, halph, lbeta, hbeta, lgamm, hgamm, attn, mdtn ]
        _ = process_packet(p);
        print _
        i = 0;
        #  FIXME: this is just an orthogonal rotation of the data
        while i < 11: 
            data[i].append(_[i]);
            i += 1;

    # plot stuff

    plt.figure(1)
    
    rg = range(len(data[0]));
    lmax = float(max([max(i) for i in data[2:9]]));
    # delta is noisy and almost always much stronger than the other waveforms,
    # so it dominates the graph => scale it down so we can see things better
    _ = float(max(data[1]));
    deltaold = data[1];     # save old delta just in case we need it
    data[1] = [ i*lmax/_ for i in deltaold ];
    
    p = plt.subplot(111);
    p.set_zorder(2);
    p.patch.set(visible=False)

    for i in xrange(8):
        p.plot(rg, data[i+1], c[i], label=l[i]);
        p.fill_between(rg, data[i+1], color=c[i], alpha=0.2);

    p.legend(bbox_to_anchor=(0., 1.02, 1., .102), loc=3, ncol=4, mode="expand", borderaxespad=0.)

    plt.ylabel('Relative Power');
    plt.xlabel('Sample Number');

    s = plt.twinx();
    s.set_zorder(1);
    s.patch.set(visible=True)
    
    # plot signal strength
    s.fill_between(rg, data[0], color="#eeeeee", alpha=1.0);
    s.fill_between(rg, data[0], [200]*len(data[0]), color="#bbbbbb", alpha=1.0);
    plt.ylim(0,200);
    plt.ylabel('Poor Signal Quality');

    # plot attention and meditation (not really very useful)
    # tdat = [ i*lmax/100. for i in data[9] ];
    # plt.fill_between(rg, tdat, color="green", alpha=0.5);

    plt.show();
