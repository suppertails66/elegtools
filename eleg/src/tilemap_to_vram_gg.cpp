#include "util/TBufStream.h"
#include "util/TStringConversion.h"
#include "util/TOpt.h"
#include "util/TFileManip.h"
#include <string>
#include <iostream>

using namespace std;
using namespace BlackT;

int patternsPerRow = 16;

int main(int argc, char* argv[]) {
  if (argc < 8) {
    cout << "Program to convert Game Gear tilesmaps to VRAM"
      << endl;
    cout << "Usage: " << argv[0] << " <vram> <map> <mapoffset> <w> <h>"
      << " <basevdpaddr> <dst>"
      << " [options]"
      << endl;
    cout << "Options:" << endl;
    cout << "  h    If set, use half-width input tilemap" << endl;
    return 0;
  }
  
  char* vramName = argv[1];
  char* mapName = argv[2];
  int mapOffset = TStringConversion::stringToInt(string(argv[3]));
  int w = TStringConversion::stringToInt(string(argv[4]));
  int h = TStringConversion::stringToInt(string(argv[5]));
  int baseVdpAddr = TStringConversion::stringToInt(string(argv[6]));
  char* dstName = argv[7];
  
  bool halfFormat = TOpt::hasFlag(argc, argv, "-h");
  
//  int outW = patternsPerRow * SmsPattern::w;
//  int outH = numPatterns / patternsPerRow;
//  if ((numPatterns % patternsPerRow)) ++outH;
//  outH *= SmsPattern::h;
  
  TBufStream ofs;
  if (TFileManip::fileExists(vramName)) ofs.open(vramName);
  ofs.seek(baseVdpAddr);
  
  TBufStream ifs;
  ifs.open(mapName);
  ifs.seek(mapOffset);
  
  for (int j = 0; j < h; j++) {
    ofs.seek(baseVdpAddr + (0x0040 * j));
    for (int i = 0; i < w; i++) {
      ofs.put(ifs.get());
      
      if (halfFormat) {
        ofs.seekoff(1);
        continue;
      }
      
      ofs.put(ifs.get());
    }
  }
  
  ofs.save(dstName);
  
  return 0;
}
