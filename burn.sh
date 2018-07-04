# msp430 bsl tools could be installed in virtualenv
# https://pythonhosted.org/python-msp430-tools/commandline_tools.html

# use the following if you don't know password
# (this destroys factory calibration settings in info flash segment)
# python -m msp430.bsl.target -p /dev/ttyUSB0 -e out.hex

# otherwise set your password (really int vector table content)
# to the pwd.txt and use this one:
python -m msp430.bsl.target -p /dev/ttyUSB0 -m --password=pwd.txt out.hex
