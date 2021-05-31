#! /usr/bin/python3

from scipy.io import wavfile
import numpy as np
import matplotlib.pyplot as plt
import struct


def plot_wav():
    fs, data = wavfile.read("data.wav")

    ch0 = data[:, 0]
    ch1 = data[:, 1]

    plt.figure(figsize=[10, 5])
    plt.plot(ch0)
    plt.plot(ch1)
    plt.xlim([0, 200])
    plt.savefig("wavdata.png")

    return fs, data

def hex2int64(s):
    return struct.unpack('<Q', bytes.fromhex(s))[0] # <Q = little endian, unsigned long long

def hex2int16(s):
    return struct.unpack('<h', bytes.fromhex(s))[0] # <h = little endian, short

def hex2float(s):
    return struct.unpack('<f', bytes.fromhex(s))[0] # <f = little endian, float

def plot_udp():
    nums = []
    i_data = []
    q_data = []

    with open("UDP short.txt") as f:
        for line in f.readlines():
            if len(line) < 4:
                print(line)
                break

            line_split = [line[i:i+8] for i in range(16, len(line), 8)]
            nums.append(hex2int64(line[0:16]))

            for sample in line_split:
                if len(sample) == 8:
                    i_data.append(hex2int16(sample[0:4]))
                    q_data.append(hex2int16(sample[4:]))

    plt.figure(figsize=[10, 5])
    plt.plot(i_data)
    plt.plot(q_data)
    plt.xlim([0, 200])
    plt.savefig("udpdata.png")

    # return i_data, q_data
    return np.array(i_data), np.array(q_data)


def padded_twos(s):
    if s < 0:
        s = abs(s)
        s = 2**13 - s

        return bin(s)[2:].zfill(13)
    else:
        return bin(s)[2:].zfill(13)


def hex_twos(s):
    return hex(int(padded_twos(s), 2))[2:].zfill(4)


def write_lvds(i_data, q_data):
    with open("LVDS_bin.txt", 'x') as f:
        for j in range(len(i_data)):
            i = i_data[j] >> 3
            q = q_data[j] >> 3

            data = "10" + padded_twos(i) + "001" + padded_twos(q) + "0\n"

            f.write(data)


if __name__ == "__main__":
    # plot_wav()
    i_data, q_data = plot_udp()
    # write_lvds(i, q)

    # print(i[0:25]/8)
    # print(q[0:25]/8)

    for j in range(20):
        i = i_data[j] >> 3
        q = q_data[j] >> 3

        print(f"{i}, {q} - {padded_twos(i)}, {padded_twos(q)} - {hex_twos(i)}, {hex_twos(q)}")
