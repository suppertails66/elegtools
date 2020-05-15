#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TThingyTable.h"
#include "util/TGraphic.h"
#include "util/TPngConversion.h"
#include "sms/SmsPattern.h"
#include "eleg/ElegScriptReader.h"
#include "eleg/ElegLineWrapper.h"
#include "exception/TGenericException.h"
#include <string>
#include <map>
#include <vector>
#include <fstream>
#include <iostream>

using namespace std;
using namespace BlackT;
using namespace Sms;

TThingyTable table;
ElegLineWrapper::CharSizeTable sizeTable;
//vector<SmsPattern> font;
map<int, SmsPattern> font;
map<int, TGraphic> fontGraphics;

const static int charsPerRow = 16;
const static int baseOutputTile = 0x90;
const static int tileOrMask = 0x1800;
const static int screenTileWidth = 20;
const static int screenVisibleX = 3;

const static int op_br   = 0x90;
const static int op_wait = 0x91;
const static int op_hero = 0x92;
const static int op_op93 = 0x93;
const static int op_terminator = 0xFF;

const static int targetOutputTileWidth = 20;

string as2bHex(int num) {
  string str = TStringConversion::intToString(num,
                  TStringConversion::baseHex).substr(2, string::npos);
  while (str.size() < 2) str = string("0") + str;
  
//  return "<$" + str + ">";
  return str;
}

string as2bHexPrefix(int num) {
  return "$" + as2bHex(num) + "";
}

void binToDcb(TStream& ifs, std::ostream& ofs) {
  int constsPerLine = 16;
  
  while (true) {
    if (ifs.eof()) break;
    
    ofs << "  .db ";
    
    for (int i = 0; i < constsPerLine; i++) {
      if (ifs.eof()) break;
      
      TByte next = ifs.get();
      ofs << as2bHexPrefix(next);
      if (!ifs.eof() && (i != constsPerLine - 1)) ofs << ",";
    }
    
    ofs << std::endl;
  }
}

string getStringName(ElegScriptReader::ResultString result) {
//  int bankNum = result.srcOffset / 0x4000;
  return string("string_")
    + TStringConversion::intToString(result.srcOffset,
          TStringConversion::baseHex);
}

int getStringWidth(ElegScriptReader::ResultString result) {
  int width = 0;
  
  TBufStream ifs;
  ifs.write(result.str.c_str(), result.str.size());
  ifs.clear();
  ifs.seek(0);
  
  while (!ifs.eof()) {
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "getStringWidth()",
                              "Unknown symbol at pos "
                                + TStringConversion::intToString(ifs.tell()));
    }
    
    width += sizeTable[result.id];
  }
  
  return width;
}

void composeStringGraphic(ElegScriptReader::ResultString result,
                          TGraphic& dst,
                          int extraOffset = 0) {
//                          int offset) {
/*  int pixelWidth = getStringWidth(result);
//  std::cerr << pixelWidth << std::endl;
  int centerPixelOffset
    = ((screenTileWidth * SmsPattern::w) - pixelWidth) / 2;
//  int tileOffset = centerPixelOffset / SmsPattern::w;
  int subpixelOffset = (centerPixelOffset % SmsPattern::w);
//  if ((centerPixelOffset % SmsPattern::w) == 0) subpixelOffset = 4;
  
  int tileWidth = ((pixelWidth + subpixelOffset) / SmsPattern::w) + 1;
  if ((centerPixelOffset % SmsPattern::w) == 0) --tileWidth;
//  if ((pixelWidth % SmsPattern::w) == 0) --tileWidth;
  
  dst.resize(tileWidth * SmsPattern::w, SmsPattern::h);
  
  // "clear" with space character (index 0)
  for (int i = 0; i < tileWidth; i++) {
    font[0].toGraphic(dst, NULL,
                      i * SmsPattern::w, 0,
                      false, false, true);
  }
  
  
  TBufStream ifs(0x10000);
  ifs.write(result.str.c_str(), result.str.size());
  ifs.clear();
  ifs.seek(0);
  
  int pos = subpixelOffset;
  while (!ifs.eof()) {
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "composeStringGraphic()",
                              "Unknown symbol at pos "
                                + TStringConversion::intToString(ifs.tell()));
    }
    
    int charWidth = sizeTable[result.id];
    
    dst.copy(fontGraphics[result.id],
      TRect(pos, 0, sizeTable[result.id], SmsPattern::h),
      TRect(0, 0, 0, 0));
    
    pos += charWidth;
  } */
  
  
  int rawPixelWidth = getStringWidth(result);
  // width of raw string in pixels
  int pixelWidth = rawPixelWidth + extraOffset;
  // number of pixels from the left edge of the screen that the string would
  // have to be moved to center it
  int centerPixelOffset
    = ((targetOutputTileWidth * SmsPattern::w) - pixelWidth) / 2;
  // number of pixels from the left edge of the tile at which the string
  // actually gets positioned that it must be moved in order to be centered 
  int subpixelOffset = (centerPixelOffset % SmsPattern::w);
  // the number of tiles required to contain the centered string
  int tileWidth = targetOutputTileWidth;
//  if ((rawPixelWidth != 0)
//      && ((pixelWidth + subpixelOffset) % SmsPattern::w) != 0) ++tileWidth;
  
//  std::cerr << pixelWidth << std::endl;
//  int tileOffset = centerPixelOffset / SmsPattern::w;
//  if ((centerPixelOffset % SmsPattern::w) == 0) subpixelOffset = 4;
  
//  int tileWidth = ((pixelWidth + subpixelOffset) / SmsPattern::w) + 1;
//  if (subpixelOffset == 0) --tileWidth;

//  if (subpixelOffset != 0) ++tileWidth;

//  if ((pixelWidth % SmsPattern::w) == 0) --tileWidth;

//  std::cerr << "  " << pixelWidth << " " << centerPixelOffset << " " << subpixelOffset << " " << tileWidth << std::endl;
  
  dst.resize(tileWidth * SmsPattern::w, SmsPattern::h);
  
  // "clear" with space character (index 0)
  for (int i = 0; i < tileWidth; i++) {
    font[0].toGraphic(dst, NULL,
                      i * SmsPattern::w, 0,
                      false, false, true);
  }

  if (rawPixelWidth == 0) {
    return;
  }
  
  TBufStream ifs;
  ifs.write(result.str.c_str(), result.str.size());
  ifs.clear();
  ifs.seek(0);
  
//  int pos = subpixelOffset + extraOffset;
  int pos = centerPixelOffset + extraOffset;
  while (!ifs.eof()) {
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "composeStringGraphic()",
                              "Unknown symbol at pos "
                                + TStringConversion::intToString(ifs.tell()));
    }
    
    int charWidth = sizeTable[result.id];
    
    dst.copy(fontGraphics[result.id],
      TRect(pos, 0, sizeTable[result.id], SmsPattern::h),
      TRect(0, 0, 0, 0));
    
    pos += charWidth;
  }
}

int main(int argc, char* argv[]) {
  if (argc < 6) {
    cout << "Eternal Legend intro builder" << endl;
    cout << "Usage: " << argv[0] << " [inprefix] [infile] [thingy] [labelname] [outprefix]"
      << endl;
    
    return 0;
  }
  
  string inPrefix = string(argv[1]);
  string inFilename = string(argv[2]);
  string tableName = string(argv[3]);
//  int bgColorIndex = TStringConversion::stringToInt(string(argv[4]));
  string labelName = string(argv[4]);
  string outPrefix = string(argv[5]);
  
  table.readSjis(tableName);
  
  // read size table
  {
    TBufStream ifs;
    ifs.open("out/font/sizetable.bin");
    int pos = 0;
    while (!ifs.eof()) {
      sizeTable[pos++] = ifs.readu8();
    }
  }
  
  int numChars = sizeTable.size();
  
  // font graphics
  TGraphic g;
  TPngConversion::RGBAPngToGraphic("rsrc/font_vwf/font.png", g);
  for (int i = 0; i < numChars; i++) {
    int x = (i % charsPerRow) * SmsPattern::w;
    int y = (i / charsPerRow) * SmsPattern::h;
  
    SmsPattern pattern;
    pattern.fromGrayscaleGraphic(g, x, y);
    
//    font.push_back(pattern);
    font[i] = pattern;
    TGraphic patternGraphic(SmsPattern::w, SmsPattern::h);
    patternGraphic.copy(g,
           TRect(0, 0, 0, 0),
           TRect(x, y, SmsPattern::w, SmsPattern::h));
    fontGraphics[i] = patternGraphic;
  }
  
  // intro text
  {
    TBufStream ifs;
//    ifs.open((inPrefix + "script.txt").c_str());
    ifs.open((inPrefix + inFilename).c_str());
    
    ElegScriptReader::ResultCollection results;
    ElegScriptReader(ifs, results, table)();
    
    std::ofstream dataOfs((outPrefix + "data.inc").c_str());
    std::ofstream tableOfs((outPrefix + "table.inc").c_str());
    
    tableOfs << ".slot 2" << endl;
    tableOfs << ".section \"" << labelName << " scroll table"
      << "\" superfree" << endl;
    tableOfs << "  " << labelName << "Table:" << endl;
      
    for (unsigned int i = 0; i < results.size(); i++) {
//      std::cerr << "string " << i << std::endl;
//      cout << getStringWidth(results[i]) << endl;

//      if (results[i].str.size() <= 0) {
//        TBufStream tilemapOfs;
//        tilemapOfs.writeu8(0);
//        outputTilemaps.push_back(tilemapOfs);
//        continue;
//      }

      TGraphic stringGraphic;
      composeStringGraphic(results[i], stringGraphic);
//      TPngConversion::graphicToRGBAPng("test_" + TStringConversion::intToString(i) + ".png",
//                                       stringGraphic);
      
//      TBufStream tilemapOfs;
      int tileW = stringGraphic.w() / SmsPattern::w;
      TBufStream outputPatterns;
      for (int j = 0; j < tileW; j++) {
        SmsPattern pattern;
        pattern.fromGrayscaleGraphic(stringGraphic, j * SmsPattern::w, 0);
        pattern.write(outputPatterns);
      }
      
      string dataLabelName = 
        labelName
        + "Data"
        + TStringConversion::intToString(i);
      
      // data
      
      dataOfs << ".slot 2" << endl;
      dataOfs << ".section \"" << labelName << " data section " << i << "\""
        << " superfree" << endl;
        dataOfs << "  " << dataLabelName << ":" << endl;
        outputPatterns.seek(0);
        binToDcb(outputPatterns, dataOfs);
      dataOfs << ".ends" << endl;
      
      // table entry
      
      // bank
      tableOfs << "  .db :" << dataLabelName << endl;
      // pointer
      tableOfs << "  .dw " << dataLabelName << endl;
    }
    
    // terminator
    tableOfs << "  .db $FE" << endl;
    
    tableOfs << ".ends" << endl;
  }
  
/*  outputPatterns.save((outPrefix + "grp.bin").c_str());
  
  TBufStream outputTilemapTable;
  outputTilemapTable.writeu8(outputTilemaps.size());
  
  for (unsigned int i = 0; i < outputTilemaps.size(); i++) {
    TBufStream& ofs = outputTilemaps[i];
    ofs.seek(0);
    outputTilemapTable.writeFrom(ofs, ofs.size());
  }
  
  outputTilemapTable.save((outPrefix + "tilemaps.bin").c_str()); */
  
  return 0;
}

