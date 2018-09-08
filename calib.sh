# calibration words (lsb) are at 0x1000 (pressure) and 0x1002 (temperature)
# 1mmHg = 21.3, 1C = 480
python -m msp430.bsl.target -p /dev/ttyUSB0 -b --password=pwd.txt calib.txt