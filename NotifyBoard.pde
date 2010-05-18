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
#define INLENGTH 20
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
  
  //Serial.println(inString);
  
  disp.clear();
  drawString(0,0,inString);
  disp.syncDisplays(); 
  
}

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
