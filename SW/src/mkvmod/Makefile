TARGET = mkvmod

VPATH = include
OBJS = $(TARGET).o m1.o m1_internal.o m1_firmware.o m1_numbers.o m1_files_and_directories.o m1_serial_communications.o
PREFIX = $(HOME)
BINDIR = $(PREFIX)/bin

# compile
.adb.o:
	gcc -c -gnat2012 $< -I include
.SUFFIXES: .adb .o

# link
$(TARGET): $(OBJS)
	gnatbind -x $(TARGET).ali; gnatlink $(TARGET).ali

install:
#	install -D -s $(TARGET) $(BINDIR)/$(TARGET) 
# if debug symbols are required:
	install -D $(TARGET) $(BINDIR)/$(TARGET)

uninstall:
	-rm -f $(BINDIR)/$(TARGET)

clean:
	rm -f *.o *.ali $(TARGET)

	


