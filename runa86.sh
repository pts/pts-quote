#!/bin/sh --
#
# runa86.sh: run the A86 assembler in DOSBox headless
# by pts@fazekas.hu at Sat Apr  9 21:31:46 CEST 2022
#
# This script runs the A86 assembler in DOSBox headless (i.e. without
# creating a window) on Linux (or other Unix), displaying the command's
# output on stdout and propagating error exit code (nonzero status code).
# It also takes care of renaming files so that assembly source files (.8)
# with longer than 8.3 characters in the file name can be used. It also
# prevents A86 from inserting its error messages to the assembly source file.
# It also does `include' processing to make it work in A86 3.22.
#
# Before running this script, install DOSBox, and make sure it starts with
# the `dosbox' command in a terminal window in the GUI. (Run `exit' to exit
# within the DOSBox window.)
#
# Before running this script, download the A86 assembler (any version
# between 3.22 and 4.05 would work), and copy the assembler executable
# program a86.com to the current directory. (If you don't do it, you'll get
# the DOSBox error: `Illegal command: a86'.)
#

unset ASMFILE COMFILE CMD STATUS ARG ARGS
if test $# != 1 && test "${1#[aA]86}" != "$1"; then  # An A86 command.
  CMD="$1" ARGS="$1"; shift; ASMFILE=; COMFILE=
  for ARG in "$@"; do
    test "$ARG" || continue
    if test "$ASMFILE" || test "${ARG#[-+]}" != "$ARG"; then  # Command-line flag (e.g. +P2).
      if test "$ASMFILE"; then
        test "$COMFILE" || COMFILE="$ARG"
      fi
      ARGS="$ARGS $ARG"
    else
      ASMFILE="$ARG"
      ARGS="$ARGS RUNA86.8"
    fi
  done
  if test "$ASMFILE"; then
    test "$COMFILE" || COMFILE="${ASMFILE%.*}".com
    if test "${ASMFILE#RUNA86.}" != "$ASMFILE"; then
      echo "fatal: $CMD assembly source file filename not allowed: $ASMFILE" >&2; exit 2
    fi
    if ! test -f "$ASMFILE"; then
      echo "fatal: $CMD assembly source file missing: $ASMFILE" >&2; exit 2
    fi
  fi
elif ! test "$1"; then
  echo "fatal: empty DOS command specified"; exit 1
else
  CMD="$1"
  ARGS="$*"
  test "$ARGS" || ARGS="a86"
  ARG=; for ARG in $CMD; do break; done
  if test "$CMD" != "$ARG"; then
    echo "fatal: DOS command has whitespace: $CMD"; exit 1
  fi
fi

rm -f RUNA86.*  # TODO(pts): Make it reentrant.
# This copy is to make long filenames and lowercase letters work.
# Also it makes sure that A86 doesn't modify the source file $ASMFILE.
if test "$ASMFILE"; then
  # Process `include' directives manually (but only in lowercase), because
  # A86 3.22 doesn't have it. We don't process them recurively though, to
  # prevent unwanted complications.
  LC_ALL=C PERL_BADLANG=x CMD="$CMD" perl -we '
    use integer; use strict;
    while (<STDIN>) {
      if (m@^[ \t]*include[ \t]+([^\r\n]*)\r?\n@) {
        my $fn = $1;
        $fn = $1 if $fn =~ m@^\x27(.*)\x27$@;
        print STDERR "info: manually processing include: $fn\n";
        die "fatal: error opening include file: $fn: $!\n" if !open(F, "<", $fn);
        my $got;
        while (1) {
          $got = sysread(F, $_, 8192);
          die "fatal: error reading include file: $fn: $!\n" if !defined($got);
          last if !$got;
          print;
        }
        close(F);
      } else {
        print
      }
    }
  ' <"$ASMFILE" >RUNA86.8 || exit 3
fi

# SUXX: This still opens many files such as auto.kl, keyboard.sys, timidity.conf,
# /dev/input/event* (for Joystick, no way to disable it in SDL 1.2, even
# with joysticktype=none), /dev/cdrom.
#
# SUXX: This still displays the spash screen in the background for half a second.
#
# SUXX: Cannot redirect file output to a pipe (e.g. `mkfifo RUNA86.OUT'),
#       cannot write serial output (AUX, COM0) to file.
#
# SUXX: Cannot redirect stdin to the DOS program.
#
#ln -s /dev/stdout RUNA86.OUT  # /proc/self/fd/1 on Linux
#mkfifo RUNA86.OUT
: >RUNA86.OUT || exit 1
DISPLAY= LC_ALL=C SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -conf "$0" \
    -c 'mount c .' -c 'c:' -c "<nul >>runa86.out $ARGS" \
    -c 'if errorlevel 1 echo @ERROR@ >>runa86.out' -c 'echo @EXIT@ >>runa86.out' -c exit >>RUNA86.DSB 2>&1
# Parse and print the output of the program.
LC_ALL=C PERL_BADLANG=x CMD="$CMD" perl -we '
  use integer; use strict;
  my $had_error = 0; my $had_exit = 0;
  while (<STDIN>) {
    if ($had_exit) { print STDERR "fatal: line too late after exit in: RUNA86.OUT\n"; exit(7); }
    if ($_ eq "\@ERROR\@\r\n") { $had_error = 1 }
    elsif ($_ eq "\@EXIT\@\r\n") { $had_exit = 1 }
    elsif ($had_error) { print STDERR "fatal: line too late after error in: RUNA86.OUT\n"; exit(7); }
    else {
      if (m@^Illegal command: @) { $had_error = 1 }
      print;  # Usually terminated by "\r\n".
    }
  }
  if (!$had_exit) { print STDERR "fatal: missing exit in RUNA86.OUT, see RUNA86.DSB\n"; exit(8); }
  if ($had_error) { print STDERR "fatal: DOS command $ENV{CMD} failed\n"; exit(10); }
' <RUNA86.OUT
STATUS="$?"
if test "$STATUS" = 0 && test "$COMFILE"; then
  mv -f RUNA86.COM "$COMFILE" || exit 2
  echo "info: renamed RUNA86.COM to $COMFILE" >&2
fi
exit "$STATUS"
# Now some temporary files RUNA86.* remain. They can be removed manually after inspection.

# This is the configurationfile for DOSBox 0.74. (Please use the latest version of DOSBox)
# Lines starting with a # are commentlines and are ignored by DOSBox.
# They are used to (briefly) document the effect of each option.

[sdl]
#       fullscreen: Start dosbox directly in fullscreen. (Press ALT-Enter to go back)
#       fulldouble: Use double buffering in fullscreen. It can reduce screen flickering, but it can also result in a slow DOSBox.
#   fullresolution: What resolution to use for fullscreen: original or fixed size (e.g. 1024x768).
#                     Using your monitor's native resolution with aspect=true might give the best results.
#                     If you end up with small window on a large screen, try an output different from surface.
# windowresolution: Scale the window to this size IF the output device supports hardware scaling.
#                     (output=surface does not!)
#           output: What video system to use for output.
#                   Possible values: surface, overlay, opengl, openglnb.
#         autolock: Mouse will automatically lock, if you click on the screen. (Press CTRL-F10 to unlock)
#      sensitivity: Mouse sensitivity.
#      waitonerror: Wait before closing the console if dosbox has an error.
#         priority: Priority levels for dosbox. Second entry behind the comma is for when dosbox is not focused/minimized.
#                     pause is only valid for the second entry.
#                   Possible values: lowest, lower, normal, higher, highest, pause.
#       mapperfile: File used to load/save the key/event mappings from. Resetmapper only works with the defaul value.
#     usescancodes: Avoid usage of symkeys, might not work on all operating systems.

# TODO(pts): How to disable SDL (and joysticks) completely? Maybe it's impossible.
fullscreen=false
fulldouble=false
fullresolution=original
windowresolution=original
output=surface
autolock=true
sensitivity=100
waitonerror=false
priority=higher,normal
#mapperfile=mapper-0.74.map
# No key events.
mapperfile=/dev/null
usescancodes=true

[dosbox]
# language: Select another language file.
#  machine: The type of machine tries to emulate.
#           Possible values: hercules, cga, tandy, pcjr, ega, vgaonly, svga_s3, svga_et3000, svga_et4000, svga_paradise, vesa_nolfb, vesa_oldvbe.
# captures: Directory where things like wave, midi, screenshot get captured.
#  memsize: Amount of memory DOSBox has in megabytes.
#             This value is best left at its default to avoid problems with some games,
#             though few games might require a higher value.
#             There is generally no speed advantage when raising this value.

language=
machine=svga_s3
captures=/dev/null
memsize=2

[render]
# frameskip: How many frames DOSBox skips before drawing one.
#    aspect: Do aspect correction, if your output method doesn't support scaling this can slow things down!.
#    scaler: Scaler used to enlarge/enhance low resolution modes.
#              If 'forced' is appended, then the scaler will be used even if the result might not be desired.
#            Possible values: none, normal2x, normal3x, advmame2x, advmame3x, advinterp2x, advinterp3x, hq2x, hq3x, 2xsai, super2xsai, supereagle, tv2x, tv3x, rgb2x, rgb3x, scan2x, scan3x.

frameskip=0
aspect=false
scaler=none

[cpu]
#      core: CPU Core used in emulation. auto will switch to dynamic if available and appropriate.
#            Possible values: auto, dynamic, normal, simple.
#   cputype: CPU Type used in emulation. auto is the fastest choice.
#            Possible values: auto, 386, 386_slow, 486_slow, pentium_slow, 386_prefetch.
#    cycles: Amount of instructions DOSBox tries to emulate each millisecond.
#            Setting this value too high results in sound dropouts and lags.
#            Cycles can be set in 3 ways:
#              'auto'          tries to guess what a game needs.
#                              It usually works, but can fail for certain games.
#              'fixed #number' will set a fixed amount of cycles. This is what you usually need if 'auto' fails.
#                              (Example: fixed 4000).
#              'max'           will allocate as much cycles as your computer is able to handle.
#            
#            Possible values: auto, fixed, max.
#   cycleup: Amount of cycles to decrease/increase with keycombo.(CTRL-F11/CTRL-F12)
# cycledown: Setting it lower than 100 will be a percentage.

# TODO(pts): Which core?
core=auto
cputype=auto
cycles=max
cycleup=10
cycledown=20

[mixer]
#   nosound: Enable silent mode, sound is still emulated though.
#      rate: Mixer sample rate, setting any device's rate higher than this will probably lower their sound quality.
#            Possible values: 44100, 48000, 32000, 22050, 16000, 11025, 8000, 49716.
# blocksize: Mixer block size, larger blocks might help sound stuttering but sound will also be more lagged.
#            Possible values: 1024, 2048, 4096, 8192, 512, 256.
# prebuffer: How many milliseconds of data to keep on top of the blocksize.

nosound=true
rate=44100
blocksize=1024
prebuffer=20

[midi]
#     mpu401: Type of MPU-401 to emulate.
#             Possible values: intelligent, uart, none.
# mididevice: Device that will receive the MIDI data from MPU-401.
#             Possible values: default, win32, alsa, oss, coreaudio, coremidi, none.
# midiconfig: Special configuration options for the device driver. This is usually the id of the device you want to use.
#               See the README/Manual for more details.

mpu401=none
mididevice=none
midiconfig=

[sblaster]
#  sbtype: Type of Soundblaster to emulate. gb is Gameblaster.
#          Possible values: sb1, sb2, sbpro1, sbpro2, sb16, gb, none.
#  sbbase: The IO address of the soundblaster.
#          Possible values: 220, 240, 260, 280, 2a0, 2c0, 2e0, 300.
#     irq: The IRQ number of the soundblaster.
#          Possible values: 7, 5, 3, 9, 10, 11, 12.
#     dma: The DMA number of the soundblaster.
#          Possible values: 1, 5, 0, 3, 6, 7.
#    hdma: The High DMA number of the soundblaster.
#          Possible values: 1, 5, 0, 3, 6, 7.
# sbmixer: Allow the soundblaster mixer to modify the DOSBox mixer.
# oplmode: Type of OPL emulation. On 'auto' the mode is determined by sblaster type. All OPL modes are Adlib-compatible, except for 'cms'.
#          Possible values: auto, cms, opl2, dualopl2, opl3, none.
#  oplemu: Provider for the OPL emulation. compat might provide better quality (see oplrate as well).
#          Possible values: default, compat, fast.
# oplrate: Sample rate of OPL music emulation. Use 49716 for highest quality (set the mixer rate accordingly).
#          Possible values: 44100, 49716, 48000, 32000, 22050, 16000, 11025, 8000.

sbtype=none
sbbase=220
irq=7
dma=1
hdma=5
sbmixer=true
oplmode=auto
oplemu=default
oplrate=44100

[gus]
#      gus: Enable the Gravis Ultrasound emulation.
#  gusrate: Sample rate of Ultrasound emulation.
#           Possible values: 44100, 48000, 32000, 22050, 16000, 11025, 8000, 49716.
#  gusbase: The IO base address of the Gravis Ultrasound.
#           Possible values: 240, 220, 260, 280, 2a0, 2c0, 2e0, 300.
#   gusirq: The IRQ number of the Gravis Ultrasound.
#           Possible values: 5, 3, 7, 9, 10, 11, 12.
#   gusdma: The DMA channel of the Gravis Ultrasound.
#           Possible values: 3, 0, 1, 5, 6, 7.
# ultradir: Path to Ultrasound directory. In this directory
#           there should be a MIDI directory that contains
#           the patch files for GUS playback. Patch sets used
#           with Timidity should work fine.

gus=false
gusrate=44100
gusbase=240
gusirq=5
gusdma=3
ultradir=C:\ULTRASND

[speaker]
# pcspeaker: Enable PC-Speaker emulation.
#    pcrate: Sample rate of the PC-Speaker sound generation.
#            Possible values: 44100, 48000, 32000, 22050, 16000, 11025, 8000, 49716.
#     tandy: Enable Tandy Sound System emulation. For 'auto', emulation is present only if machine is set to 'tandy'.
#            Possible values: auto, on, off.
# tandyrate: Sample rate of the Tandy 3-Voice generation.
#            Possible values: 44100, 48000, 32000, 22050, 16000, 11025, 8000, 49716.
#    disney: Enable Disney Sound Source emulation. (Covox Voice Master and Speech Thing compatible).

pcspeaker=false
pcrate=44100
tandy=auto
tandyrate=44100
disney=true

[joystick]
# joysticktype: Type of joystick to emulate: auto (default), none,
#               2axis (supports two joysticks),
#               4axis (supports one joystick, first joystick used),
#               4axis_2 (supports one joystick, second joystick used),
#               fcs (Thrustmaster), ch (CH Flightstick).
#               none disables joystick emulation.
#               auto chooses emulation depending on real joystick(s).
#               (Remember to reset dosbox's mapperfile if you saved it earlier)
#               Possible values: auto, 2axis, 4axis, 4axis_2, fcs, ch, none.
#        timed: enable timed intervals for axis. Experiment with this option, if your joystick drifts (away).
#     autofire: continuously fires as long as you keep the button pressed.
#       swap34: swap the 3rd and the 4th axis. can be useful for certain joysticks.
#   buttonwrap: enable button wrapping at the number of emulated buttons.

joysticktype=none
timed=true
autofire=false
swap34=false
buttonwrap=false

[serial]
# serial1: set type of device connected to com port.
#          Can be disabled, dummy, modem, nullmodem, directserial.
#          Additional parameters must be in the same line in the form of
#          parameter:value. Parameter for all types is irq (optional).
#          for directserial: realport (required), rxdelay (optional).
#                           (realport:COM1 realport:ttyS0).
#          for modem: listenport (optional).
#          for nullmodem: server, rxdelay, txdelay, telnet, usedtr,
#                         transparent, port, inhsocket (all optional).
#          Example: serial1=modem listenport:5000
#          Possible values: dummy, disabled, modem, nullmodem, directserial.
# serial2: see serial1
#          Possible values: dummy, disabled, modem, nullmodem, directserial.
# serial3: see serial1
#          Possible values: dummy, disabled, modem, nullmodem, directserial.
# serial4: see serial1
#          Possible values: dummy, disabled, modem, nullmodem, directserial.

# TODO(pts): Is it possible to write to stdout on the fly?
serial1=dummy
# It doesn't work.
#serial1=directserial realport:tty
serial2=dummy
serial3=disabled
serial4=disabled

[dos]
#            xms: Enable XMS support.
#            ems: Enable EMS support.
#            umb: Enable UMB support.
# keyboardlayout: Language code of the keyboard layout (or none).

xms=true
ems=true
umb=true
keyboardlayout=auto

[ipx]
# ipx: Enable ipx over UDP/IP emulation.

ipx=false

[autoexec]
# Lines in this section will be run at startup.
# You can put your MOUNT lines here.
