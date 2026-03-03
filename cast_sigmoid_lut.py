import numpy as np

# simple Python to generate a LUT for the sigmoid function

g = np.concatenate((np.arange(0, 800), np.repeat(800, repeats=1248)))

gnormalized = g / g.max()
# Center them to -.5 to .5
gcentered = gnormalized - .5
# Then scale them back to -4 to 4. (this makes sigmoid happy, since its range is -10, 10)
# The value here is fun to play with. Lower values (e.g. 4) produce more noise, but also more color.
gscaled = gcentered * 8
# Apply a sigmoid to reduce noise by creating a soft threshold.
sigmoid = lambda x: 1/(1 + np.exp(-x))
gthreshold = np.vectorize(sigmoid)(gscaled)
print(gthreshold)

v = (255 * gthreshold).astype(np.uint8)

for i in v:
    print(hex(i))
