/*
Copyright 2010 Charles Yarnold charlesyarnold@gmail.com

NotifyBoard is free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

NotifyBoard is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with NotifyBoard.
If not, see http://www.gnu.org/licenses/.

*/

/*
Version 0.1
*/

#include <FatReader.h>
#include <SdReader.h>
#include <avr/pgmspace.h>
#include "WaveUtil.h"
#include "WaveHC.h"


SdReader card;    // This object holds the information for the card
FatVolume vol;    // This holds the information for the partition on the card
FatReader root;   // This holds the information for the filesystem on the card
FatReader f;      // This holds the information for the file we're play

WaveHC wave;      // This is the only wave (audio) object, since we will only play one at a time

#include "MatrixDisplay.h"
#include "DisplayToolbox.h"
#include "font.h"

// Easy to use function
#define setMaster(dispNum, CSPin) initDisplay(dispNum,CSPin,true)
#define setSlave(dispNum, CSPin) initDisplay(dispNum,CSPin,false)

// 4 = Number of displays
// Data = 10
// WR == 11
// False - we dont need a shadow buffer for this example. saves 50% memory!

// Init Matrix
MatrixDisplay disp(4,15,14, false);
// Pass a copy of the display into the toolbox
DisplayToolbox toolbox(&disp);

// Prepare boundaries
uint8_t X_MAX = 0;
uint8_t Y_MAX = 0;

//serial in stuff
#define INLENGTH 21
char intermator = '|';
char inString[INLENGTH+1];
int inCount;


void setup() {
  Serial.begin(9600); 

  // Fetch bounds
  X_MAX = disp.getDisplayCount() * (disp.getDisplayWidth()-1)+1;
  Y_MAX = disp.getDisplayHeight();
  
  // Prepare displays
  // The first number represents how the buffer/display is stored in memory. Could be useful for reorganising the displays or matching the physical layout
  // The number is a array index and is sequential from 0. You can't use 4-8. You must use the numbers 0-4
  disp.setMaster(0,16);
  disp.setSlave(1,17);
  disp.setSlave(2,18);
  disp.setSlave(3,19);
  
  //wave hc stuff
  byte i;
  
  putstring("Free RAM: ");       // This can help with debugging, running out of RAM is bad
  Serial.println(freeRam());      // if this is under 150 bytes it may spell trouble!
  
  // Set the output pins for the DAC control. This pins are defined in the library
  pinMode(2, OUTPUT);
  pinMode(3, OUTPUT);
  pinMode(4, OUTPUT);
  pinMode(5, OUTPUT);
 
  // pin13 LED
  pinMode(6, OUTPUT);
  
  //  if (!card.init(true)) { //play with 4 MHz spi if 8MHz isn't working for you
  if (!card.init()) {         //play with 8 MHz spi (default faster!)  
    putstring_nl("Card init. failed!");  // Something went wrong, lets print out why
    sdErrorCheck();
    while(1);                            // then 'halt' - do nothing!
  }
  
  // enable optimize read - some cards may timeout. Disable if you're having problems
  card.partialBlockRead(true);
 
// Now we will look for a FAT partition!
  uint8_t part;
  for (part = 0; part < 5; part++) {     // we have up to 5 slots to look in
    if (vol.init(card, part)) 
      break;                             // we found one, lets bail
  }
  if (part == 5) {                       // if we ended up not finding one  :(
    putstring_nl("No valid FAT partition!");
    sdErrorCheck();      // Something went wrong, lets print out why
    while(1);                            // then 'halt' - do nothing!
  }
  
  // Lets tell the user about what we found
  putstring("Using partition ");
  Serial.print(part, DEC);
  putstring(", type is FAT");
  Serial.println(vol.fatType(),DEC);     // FAT16 or FAT32?
  
  // Try to open the root directory
  if (!root.openRoot(vol)) {
    putstring_nl("Can't open root dir!"); // Something went wrong,
    while(1);                             // then 'halt' - do nothing!
  }
  
  // Whew! We got past the tough parts.
  putstring_nl("Ready!");
}


void loop()
{
  Serial.println("Moo");
  
  inCount = 0;
  do {
    while (!Serial.available());             // wait for input
    inString[inCount] = Serial.read();       // get it
    if (inString[inCount] == intermator) break;
    //Serial.println(inString[inCount]);
    inCount = inCount + 1;
  } while (inCount < INLENGTH);
  inString[inCount] = 0;
  
  // center text
  int x = floor ((128 - ((strlen(inString)*6) - 1)) / 2);
  
  disp.clear();
  drawString(x,0,inString);
  disp.syncDisplays(); 
  playfile("CYMBAL.WAV");
}

//wave hc stuff

// this handy function will return the number of bytes currently free in RAM, great for debugging!   
int freeRam(void)
{
  extern int  __bss_end; 
  extern int  *__brkval; 
  int free_memory; 
  if((int)__brkval == 0) {
    free_memory = ((int)&free_memory) - ((int)&__bss_end); 
  }
  else {
    free_memory = ((int)&free_memory) - ((int)__brkval); 
  }
  return free_memory; 
} 

void sdErrorCheck(void)
{
  if (!card.errorCode()) return;
  putstring("\n\rSD I/O error: ");
  Serial.print(card.errorCode(), HEX);
  putstring(", ");
  Serial.println(card.errorData(), HEX);
  while(1);
}

// Plays a full file from beginning to end with no pause.
void playcomplete(char *name) {
  // call our helper to find and play this name
  playfile(name);
  while (wave.isplaying) {
  // do nothing while its playing
  }
  // now its done playing
}

void playfile(char *name) {
  // see if the wave object is currently doing something
  if (wave.isplaying) {// already playing something, so stop it!
    wave.stop(); // stop it
  }
  // look in the root directory and open the file
  if (!f.open(root, name)) {
    putstring("Couldn't open file "); Serial.print(name); return;
  }
  // OK read the file and turn it into a wave object
  if (!wave.create(f)) {
    putstring_nl("Not a valid WAV"); return;
  }
  
  // ok time to play! start playback
  wave.play();
}

//sure display
void drawChar(uint8_t x, uint8_t y, char c)
{
  //if (x + 5 >=  2 * 32) return;
  Serial.print(c);
  uint8_t dots;
  if (c >= 'A' && c <= 'Z' ||
    (c >= 'a' && c <= 'z') ) {
    c &= 0x1F;   // A-Z maps to 1-26
  } 
  else if (c >= '0' && c <= '9') {
    c = (c - '0') + 27;
  } 
  else if (c == ' ') {
    c = 0; // space
  }
  for (char col=0; col< 5; col++) {
    dots = pgm_read_byte_near(&myfont[c][col]);
    for (char row=0; row < 7; row++) {
      if (dots & (64>>row))   	     // only 7 rows.
        toolbox.setPixel(x+col, y+row, 1);
      else 
        toolbox.setPixel(x+col, y+row, 0);
    }
  }
}


// Write out an entire string (Null terminated)
void drawString(uint8_t x, uint8_t y, char* c)
{
	for(char i=0; i< strlen(c); i++)
	{
		drawChar(x, y, c[i]);
		x+=6; // Width of each glyph
	}
}
