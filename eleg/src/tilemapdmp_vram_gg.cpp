#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TBufStream.h"
#include "util/TIniFile.h"
#include "util/TStringConversion.h"
#include "util/TFreeSpace.h"
#include "util/TFileManip.h"
#include "util/TArray.h"
#include "util/TByte.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "util/TOpt.h"
#include "sms/SmsTilemap.h"
#include "sms/SmsPattern.h"
#include "sms/SmsPalette.h"
#include <iostream>
#include <string>
#include <vector>
#include <cctype>
#include <cstring>

using namespace std;
using namespace BlackT;
using namespace Sms;

int main(int argc, char* argv[]) {
  
  if (argc < 6) {
    cout << "Game Gear tilemap renderer" << endl;
    cout << "Usage: " << argv[0] << " <vram> <offset> <w> <h>"
      << " <outfile>" << endl;
    cout << "Options: " << endl;
//    cout << "  m     Set mode (full, half)" << endl;
    cout << "  p     Set palette (default: grayscale)"
      << endl;
    
    return 0;
  }
  
  TBufStream ifs;
  ifs.open(argv[1]);
  
  int offset = TStringConversion::stringToInt(string(argv[2]));
  int w = TStringConversion::stringToInt(string(argv[3]));
  int h = TStringConversion::stringToInt(string(argv[4]));
  
  int loadTileNum = 0;
  SmsVram vram;
  {
    while (ifs.remaining() > 0) {
      SmsPattern pattern;
      pattern.read(ifs);
      vram.setPattern(loadTileNum++, pattern);
    }
  }
                             
  SmsPalette* palP = NULL;
  SmsPalette pal;
  SmsPalette spritePal;
  if (TOpt::getOpt(argc, argv, "-p") != NULL) {
    TIfstream ifs(TOpt::getOpt(argc, argv, "-p"), ios_base::binary);
    pal.readGG(ifs);
    spritePal.readGG(ifs);
    palP = &pal;
  }
  
  SmsTilemap tilemap;
  tilemap.resize(w, h);
//  tilemap.read((const char*)buffer.data().data(), w, h);
  for (int j = 0; j < h; j++) {
    ifs.seek(offset + (j * 0x0040));
    for (int i = 0; i < w; i++) {
      SmsTileId id;
      id.read(ifs.data().data() + ifs.tell());
      tilemap.setTileId(i, j, id);
      ifs.seekoff(2);
    }
  }
  
  TGraphic g;
  if (palP == NULL) {
    tilemap.toGrayscaleGraphic(g, vram, true);
  }
  else {
    vram.setTilePalette(pal);
    vram.setSpritePalette(spritePal);
    tilemap.toColorGraphic(g, vram, true);
  }
  
//  std::cerr << argv[7] << std::endl;
  TPngConversion::graphicToRGBAPng(string(argv[5]), g);
  
  return 0;
}
