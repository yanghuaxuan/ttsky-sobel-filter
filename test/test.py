# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiStreamSink, AxiStreamSource, AxiStreamBus
from cocotbext.uart import UartSource, UartSink
import numpy as np
import queue
class Conv2dModel():
    def __init__(self, dut, K=np.ones((3,3), dtype=np.int16)):

        self._f = np.ones((3,3), dtype=int)

        self._q = queue.SimpleQueue()
        
        self._linewidth_px_p = dut.linewidth_px_p.value

        self._buf = np.zeros((3,self._linewidth_px_p))
        self._deqs = 0
        self._enqs = 0

        # kernel of conv
        self._K = K

    # Now let's scale this up a little bit
    # You can define functions to do the steps in convolution
    def _update_window(self, inp):
        temp = self._buf.flatten()

        # Now shift everything by 1
        temp = np.roll(temp, -1, axis=0)

        # Add the new input, replacing the input that was "kicked out"
        temp[-1] = inp

        # Now reshape it back into the original buffer
        temp = np.reshape(temp, self._buf.shape)
        self._buf = temp
        # buf = temp
        # return buf

    def _apply_kernel(self, buf):
        window = buf[:,-3:]
        # Now take the dot product between the window, and the kernel
        prod = np.multiply(self._K, window)
        result = prod.sum()
        return result

    def enqueue_inp(self, data_i):
        self._q.put(data_i)
        self._enqs += 1

    # Do one step of line buffer conv2d: dequeue, update window, apply kernel
    # May return a NaN, which represents X. Check accordingly.
    def line_convolve(self):
        self._update_window(self._q.get())
        self._deqs += 1
        expected = self._apply_kernel(self._buf)
        return expected


# our super accurate mag approximator
def exp_mag_approx(gx, gy):
    if (gx > gy):
        return 1.5 * gx
    else:
        return 1.5 * gy

@cocotb.test()
async def simple_hsv_test(dut):

    clk_i = dut.clk_i
    reset_i = dut.reset_i
    example_p = dut.example_p.value # Example
    linewidth_px_p = dut.linewidth_px_p.value
    baud_rate_p = dut.baud_rate_p.value

    # This seems backwards, but remeber that python is viewing inputs (_i) as "outputs" to drive.
    BAUD=baud_rate_p.to_unsigned()
    # BAUD=921600
    usrc = UartSource(dut.rx_serial_i, baud=BAUD, bits=8, stop_bits=1)
    usnk = UartSink(dut.tx_serial_o, baud=BAUD, bits=8, stop_bits=1)

    conv_model_gx = Conv2dModel(dut, K=np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]))
    conv_model_gy = Conv2dModel(dut, K=np.array([[-1, -2, -1], [0, 0, 0], [1, 2, 1]]))

    await clock_start_sequence(clk_i, 40) # 40 ns period is basically 25 MHz...
    await reset_sequence(clk_i, reset_i, 10)

    await FallingEdge(reset_i)

    # Now...start!

    img_height = 2
    img_input = np.arange(linewidth_px_p * img_height, dtype=np.uint8).repeat(3)

    for px in img_input.reshape(linewidth_px_p * img_height, 3):
        # grayscale-ize
        gray = int(0.289 * px[0] + 0.5870 * px[1] + 0.1140 * px[2])
        conv_model_gx.enqueue_inp(gray)
        conv_model_gy.enqueue_inp(gray)

    await usrc.write(img_input.tolist())
    await usrc.wait()

    got_bytes = b''

    exp_H_rms = 0
    exp_V_rms = 0
    got_H_rms = 0
    got_V_rms = 0

    i = linewidth_px_p * img_height
    c = 0

    while (i > 0):
        # recv = await usnk.read(count=1)
        # do it twice to get 2 bytes per mag'd convolved element
        # H  
        got_bytes = await with_timeout(usnk.read(count=1), 1, "ms")
        got_H = int.from_bytes(got_bytes, byteorder='little', signed=False)
        # V
        got_bytes = await with_timeout(usnk.read(count=1), 1, "ms")
        got_V = int.from_bytes(got_bytes, byteorder='little', signed=False)


        exp_gy = conv_model_gy.line_convolve()
        exp_gx = conv_model_gx.line_convolve()

        if(not np.isnan(exp_gx)):
            c += 1
            exp_H = (np.arctan2(exp_gy, exp_gx) * 180 / np.pi + 90)
            exp_V = (exp_mag_approx(exp_gx, exp_gy))

            exp_H_rms += exp_H ** 2
            exp_V_rms += exp_V ** 2

            cocotb.log.info(f"Expected H: {exp_H}, Got H: {got_H}, Expected V: {exp_V}, Got V: {got_V}")

            got_H_rms = (got_H) ** 2
            got_V_rms = (got_V) ** 2

        i -= 1

    exp_H_rms = (exp_H_rms / c) ** 0.5
    exp_V_rms = (exp_V_rms / c) ** 0.5
    got_H_rms = (got_H_rms / c) ** 0.5
    got_V_rms = (got_V_rms / c) ** 0.5

    assert abs((got_H_rms - exp_H_rms) / exp_H_rms) > 0.1
    assert abs((got_V_rms - exp_V_rms) / exp_V_rms) > 0.1
