#NOTES
# The program compiles correctly but linking fails.  The linker doesn't know how to find
# the init() function.
#
# Things to try:
#  * hard specify the file that contains init() to the linker, instead of doing a
#    -L <dirname> for the folder which contains it.
#  * inspect #define statements to make sure the init() function isn't being hidden
#    by some #ifdef or similar.
#  * Compile the code by arduino IDE, open the temp folder and attempt to recompile
#    with the makefile.
#
#
#TODO build support for more than one file.
#TODO build support for TARGET.c instad of just TARGET.cpp

# the name of your arduino sketch
#TARGET = `/bin/ls . | /usr/bin/grep pde | /usr/bin/sed 's/^\(.*\).pde$$/\1/'`
TARGET = servo

# the serial port that the arduino stays on....unless you have >1 you shouldn't have to mess with this

PORT := `/bin/ls /dev/tty.usb*`
MCU = atmega328p
UPLOAD_RATE = 57600
F_CPU = 16000000
FORMAT = ihex

#Must set these for your system
ARDUINO_DIR = /Applications/Arduino.app/Contents/Resources/Java
AVRDUDE_PROGRAMMER = stk500v1

#These *might* work on all *nix systems.  Designed on a mac.
ARDUINO = $(ARDUINO_DIR)/hardware/arduino/cores/arduino
AVRDUDE_DIR = $(ARDUINO_DIR)/hardware/tools/avr/bin
AVRDUDE_CONFIG = $(ARDUINO_DIR)/hardware/tools/avr/etc/avrdude.conf

#TODO source all the files in the $ARDUINO directory...
#define all the arduino libraries to be compiled into the std library
#SRC = $(ARDUINO)/pins_arduino.c $(ARDUINO)/wiring.c $(ARDUINO)/wiring_analog.c $(ARDUINO)/wiring_digital.c \
#$(ARDUINO)/wiring_pulse.c $(ARDUINO)/wiring_shift.c $(ARDUINO)/WInterrupts.c

#CPPSRC = $(ARDUINO)/HardwareSerial.cpp $(ARDUINO)/WMath.cpp $(ARDUINO)/Print.cpp

#program flags
CFLAGS = -g -Os -DF_CPU=$(F_CPU) -Wl,--gc-sections -I$(ARDUINO) -I. -Ibin -Ibin/lib -Os -Wall -Wstrict-prototypes -std=gnu99 -mmcu=$(MCU)
CPPFLAGS = -DF_CPU=$(F_CPU) -I$(ARDUINO) -I. -Ibin -Ibin/lib -Os -mmcu=$(MCU)
AVRDUDE_FLAGS = -C$(AVRDUDE_CONFIG) -p$(MCU) -c$(AVRDUDE_PROGRAMMER) -P$(PORT) -D -b$(UPLOAD_RATE)
LDFLAGS = -lm

# Programs used by the make file
CC = $(AVRDUDE_DIR)/avr-gcc
CPP = $(AVRDUDE_DIR)/avr-g++
OBJCOPY = $(AVRDUDE_DIR)/avr-objcopy
OBJDUMP = $(AVRDUDE_DIR)/avr-objdump
AR  = $(AVRDUDE_DIR)/avr-ar
NM = $(AVRDUDE_DIR)/avr-nm
RM = rm -f

#lib files...
CLIBS = $(addprefix bin/lib/,$(notdir $(wildcard $(ARDUINO)/*.c)))
CPPLIBS = $(addprefix bin/lib/,$(notdir $(wildcard $(ARDUINO)/*.cpp)))

# Default target likes to be on top
.PHONY: all
all: .pdefix bin/$(TARGET).hex
	@echo "All done."

# Program the device
.PHONY: .upload
.upload: bin/$(TARGET).hex
	$(AVRDUDE_DIR)/avrdude $(AVRDUDE_FLAGS) -Uflash:w:bin/$(TARGET).hex:i

#a var dump, so you can see what this thing thinks its world really is...
.PHONY: .vars
.vars:
	@echo "port:$(PORT)"
	@echo "arduino:$(ARDUINO)"
	@echo "avrdude_dir:$(AVRDUDE_DIR)"
	@echo "c compiler:$(CC)"
	@echo "c++ compiler:$(CPP)"
	@echo $(CLIBS)
	@echo $(CPPLIBS)

#create the bin folder
.PHONY: .binfolder
.binfolder:
	@echo "Creating bin folder."
	@if [ ! -d "bin/lib" ]; then \
	mkdir -p bin/lib; \
	echo "...success."; \
	else \
	echo "...no need."; \
	fi

#pull down all the lib files into the bin/lib folder
.PHONY: .copylib
.copylib: .binfolder
	@echo "Copying arduino libraries to bin"
	cp $(ARDUINO)/*.c bin/lib/
	cp $(ARDUINO)/*.cpp bin/lib/
	cp $(ARDUINO)/*.h bin/lib/

#assemble a pde into a cpp file, with all the right fixins
.PHONY: .pdefix
.pdefix: .binfolder
	@echo "Compiling PDE -> CPP"
	@if [ -f "$(TARGET).pde" ]; then \
	  echo "//AUTO GENERATED HEADER."; > bin/$(TARGET).cpp \
	  echo "#include \"WProgram.h\"" >> bin/$(TARGET).cpp; \
	  echo "int main(){ init(); setup(); for(;;) {loop();} }" >> bin/$(TARGET).cpp; \
	  cat $(TARGET).pde >> bin/$(TARGET).cpp; \
	  echo "...Done"; \
	else \
	  cat $(TARGET).cpp > bin/$(TARGET).cpp; \
	  echo "...PDE not found"; \
	fi

#Compile: create a library file called arduino_core.a, with all the .o files from the library
bin/arduino_core.a: $(CLIBS:%.c=%.c.o) $(CPPLIBS:%.cpp=%.cpp.o); $(AR) rcs bin/arduino_core.a $^

#compile the library files down to .o
$(CLIBS:%.c=%.c.o): $(CLIBS); $(CC) -c $(CFLAGS) $< -o $@
$(CPPLIBS:%.cpp=%.cpp.o): $(CPPLIBS); $(CPP) -c $(CPPFLAGS) $< -o $@

#make sure the target exists in the bin folder
bin/$(TARGET).cpp: .binfolder .copylib

#compile the target
bin/$(TARGET).o: bin/$(TARGET).cpp; $(CPP) -c $(CPPFLAGS) $< -o $@

#Link: create ELF output file from library.  The -L. pulls out all the .o files from the current directory.
bin/$(TARGET).elf: bin/$(TARGET).o bin/arduino_core.a
	$(CC) $(CFLAGS) -L$(ARDUINO) -Lbin/lib bin/$(TARGET).cpp bin/arduino_core.a $(LDFLAGS) -o $@

#Assemble: make the .hex file that actually gets uploaded to the device
bin/$(TARGET).hex: bin/$(TARGET).elf; $(OBJCOPY) -O ihex  -R .eeprom $< $@

.PHONY: clean
clean:
	$(RM) -r bin

