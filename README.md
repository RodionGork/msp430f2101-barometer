# msp430f2101-barometer

Software I2C to talk to LPS331 pressure/temperature sensor.

Shows pressure (in mmHg, add 700) and temperature (celsius).

Results are printed to UART (if connected) and blinked with LED:

- first 2 digits of pressure are blinked, e.g. 64 (for 764 mmHg)
- then 2 digits of temperature, e.g. 27 (for 27 celsius)

Long blink means 5, short means 1. Two long mean 0 (not 10).

So, for example, values above are blinked like this:

    ===== ==     == == == ==          == ==     ===== == ==
        6             4                 2            7
