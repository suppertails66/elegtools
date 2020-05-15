#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TThingyTable.h"
#include "exception/TGenericException.h"
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <map>

using namespace std;
using namespace BlackT;

typedef std::map<int, std::string> DictionaryMap;
typedef std::map<int, int> ScriptOpSkipTable;

const static int op_f2         = 0xF2;
const static int op_f3         = 0xF3;
const static int op_f4         = 0xF4;
const static int op_clear      = 0xF5;
const static int op_f6         = 0xF6;
const static int op_f7         = 0xF7;
const static int op_br         = 0xF8;
const static int op_dict0      = 0xF9;
const static int op_dict1      = 0xFA;
const static int op_dict2      = 0xFB;
const static int op_dict3      = 0xFC;
const static int op_fd         = 0xFD;
const static int op_end        = 0xFE;
const static int op_wait       = 0xFF;

//const static int region_locTable_addr = 0x1A069;
//const static int dictionaryTableBase = 0xe75e;

const static int blockTableAddr = 0x30000;
const static int eventScriptOpSkipTableAddr = 0x2BD6;
const static int numEventScriptOps = 0x26;

int smsBankSize = 0x4000;

DictionaryMap dictionary0;
DictionaryMap dictionary1;
DictionaryMap dictionary2;
DictionaryMap dictionary3;
ScriptOpSkipTable eventScriptOpSkipTable;

int lastAttemptedBlockScriptIndex = -1;

bool verbose = true;

string as2bHex(int num) {
  string str = TStringConversion::intToString(num,
                  TStringConversion::baseHex).substr(2, string::npos);
  while (str.size() < 2) str = string("0") + str;
  
  return "<$" + str + ">";
}

void outputComment(std::ostream& ofs,
               string comment = "") {
  if (comment.size() > 0) {
    ofs << "//=======================================" << endl;
    ofs << "// " << comment << endl;
    ofs << "//=======================================" << endl;
    ofs << endl;
  }
}

bool isTextEventOp(int eventOp) {
  switch (eventOp) {
  case 0x01:
  case 0x08:
  case 0x0A:
  case 0x0F:
  case 0x10:
  case 0x17:
  case 0x1C:
  case 0x1D:
    return true;
    break;
  default:
    break;
  }
  
  return false;
}

bool isOpId(int op) {
  return ((op >= 0xF2) && (op <= 0xFF));
}

int numOpParamBytes(int op) {
  switch (op) {
  case op_dict0:
  case op_dict1:
  case op_dict2:
  case op_dict3:
    return 1;
    break;
  default:
    break;
  }
  
  return 0;
}

bool isSharedOp(int op) {
  switch (op) {
  case op_f2:
  case op_f3:
  case op_f4:
  case op_f6:
//  case op_f7:
  case op_br:
  case op_dict0:
  case op_dict1:
  case op_dict2:
  case op_dict3:
  case op_fd:
    return false;
    break;
  default:
    break;
  }
  
  return true;
}

// number of linebreaks that should precede an op type
int numOpPreLines(int op) {
  switch (op) {
  case op_wait:
  case op_clear:
  case op_end:
    return 1;
    break;
  default:
    break;
  }
  
  return 0;
}

// number of linebreaks that should follow an op type
int numOpPostLines(int op) {
  switch (op) {
  case op_br:
    return 1;
    break;
  case op_wait:
  case op_end:
  case op_clear:
//  case op_waitend:
    return 2;
    break;
  default:
    break;
  }
  
  if (isSharedOp(op)) return 1;
  
  return 0;
}

void addComment(std::ostream& ofs, string comment) {
  ofs << "//===========================================================" << endl;
  ofs << "// " << comment << endl;
  ofs << "//===========================================================" << endl;
  ofs << endl;
}

void dumpSubstring(TStream& ifs, std::ostream& ofs, const TThingyTable& table,
                   int offset) {
//  std::cerr << hex << offset << endl;
  ifs.seek(offset);
  while (true) {
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "dumpSubstring(TStream&, std::ostream&)",
                              string("At offset ")
                                + TStringConversion::intToString(
                                    ifs.tell(),
                                    TStringConversion::baseHex)
                                + ": unknown character '"
                                + TStringConversion::intToString(
                                    (unsigned char)ifs.peek(),
                                    TStringConversion::baseHex)
                                + "'");
    }
    
    string resultStr = table.getEntry(result.id);
    
    if ((result.id == op_end)) {
      break;
    }
    
    ofs << resultStr;
  }
}

void dumpMenuString(TStream& ifs, std::ostream& ofs, const TThingyTable& table,
              int offset) {
  std::ostringstream oss;
  
  ifs.seek(offset);
  
  int x = ifs.readu8();
  int y = ifs.readu8();
  
  oss << as2bHex(x) << as2bHex(y);
  oss << endl;
  
  oss << "// ";
  while (true) {
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "dumpMenuString(TStream&, std::ostream&)",
                              string("At offset ")
                                + TStringConversion::intToString(
                                    ifs.tell(),
                                    TStringConversion::baseHex)
                                + ": unknown character '"
                                + TStringConversion::intToString(
                                    (unsigned char)ifs.peek(),
                                    TStringConversion::baseHex)
                                + "'");
    }
    
    string resultStr = table.getEntry(result.id);
    
    // linebreak
    if (result.id == op_end) {
      oss << resultStr;
      oss << endl << "// ";
      continue;
    }
    // terminator
    else if (result.id == op_wait) {
//      oss << resultStr;
      oss << endl << endl << resultStr;
      break;
    }
    
    oss << resultStr;
  }
  
  oss << endl << endl;
  
  ofs << "//[TEXT]" << endl;
  ofs << "#STARTMSG("
      // offset
      << TStringConversion::intToString(
          offset, TStringConversion::baseHex)
      << ", "
      // size
      << TStringConversion::intToString(
          ifs.tell() - offset, TStringConversion::baseDec)
      << ", "
      // slot num
//      << TStringConversion::intToString(
//          slot, TStringConversion::baseDec)
      << "0"
      << ")" << endl << endl;
  
  ofs << oss.str();
  
  ofs << "#ENDMSG()";
  ofs << endl << endl;
}

void outputRawString(std::string str,
                      std::ostream& ofs, const TThingyTable& table) {
  TBufStream ifs;
  for (int i = 0; i < str.size(); i++) ifs.put(str[i]);
  ifs.seek(0);
  
  while (!ifs.eof()) {
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "outputRawString()",
                              string("At offset ")
                                + TStringConversion::intToString(
                                    ifs.tell(),
                                    TStringConversion::baseHex)
                                + ": unknown character '"
                                + TStringConversion::intToString(
                                    (unsigned char)ifs.peek(),
                                    TStringConversion::baseHex)
                                + "'");
    }
    
    string resultStr = table.getEntry(result.id);
    
//    if ((result.id == op_end)) {
//      break;
//    }
    
    ofs << resultStr;
  }
}

void outputDictString(const DictionaryMap& dict, int stringId,
                      std::ostream& ofs, const TThingyTable& table) {
  DictionaryMap::const_iterator findIt = dict.find(stringId);
  if (findIt == dict.end()) {
    throw TGenericException(T_SRCANDLINE,
                            "outputDictString()",
                            string("Out-of-range dictionary entry: ")
                              + TStringConversion::intToString(
                                  stringId,
                                  TStringConversion::baseHex));
  }
  
  outputRawString(findIt->second, ofs, table);
}

void dumpString(TStream& ifs, std::ostream& ofs, const TThingyTable& table,
              int offset, int slot,
//              int autowrap = -1,
              string comment = "") {
  ifs.seek(offset);
  
  std::ostringstream oss_final;
  std::ostringstream oss_textline;
  
  if (comment.size() > 0)
    oss_final << "// " << comment << endl;
  
  bool atLineStart = true;
  bool lastWasBr = false;
  int charsOnLine = 0;
  while (!ifs.eof()) {
    TThingyTable::MatchResult result = table.matchId(ifs);
    if (result.id == -1) {
      throw TGenericException(T_SRCANDLINE,
                              "dumpScript()",
                              string("At file offset ")
                                + TStringConversion::intToString(
                                    ifs.tell(),
                                    TStringConversion::baseHex)
                                + ": could not match character from table");
    }
    
    int id = result.id;
    
    switch (id) {
    case op_dict0:
      outputDictString(dictionary0, ifs.readu8(), oss_textline, table);
      continue;
      break;
    case op_dict1:
      outputDictString(dictionary1, ifs.readu8(), oss_textline, table);
      continue;
      break;
    case op_dict2:
      // [ ]
      outputRawString(std::string("\xB2"), oss_textline, table);
      outputDictString(dictionary2, ifs.readu8(), oss_textline, table);
      outputRawString(std::string("\xB3"), oss_textline, table);
      continue;
      break;
    case op_dict3:
      // << >>
      outputRawString(std::string("\xAA"), oss_textline, table);
      outputDictString(dictionary3, ifs.readu8(), oss_textline, table);
      outputRawString(std::string("\xAB"), oss_textline, table);
      continue;
      break;
    default:
      
      break;
    }
    
    string resultStr = table.getEntry(result.id);
    bool isOp = isOpId(id);
//                  || (id == op_waitend)
    
    if (isOp) {
      bool shared = isSharedOp(id);
      
      std::ostringstream* targetOss = NULL;
      if (shared) {
        targetOss = &oss_final;
        
        // empty comment line buffer
        if (oss_textline.str().size() > 0) {
          oss_final << "// " << oss_textline.str();
          oss_final << std::endl << std::endl;
          oss_textline.str("");
          atLineStart = true;
        }
      }
      else {
        targetOss = &oss_textline;
      }
      
      //===========================================
      // output pre-linebreaks
      //===========================================
      
      int numPreLines = numOpPreLines(id);
      if ((!atLineStart || (atLineStart && lastWasBr))
          && (numPreLines > 0)) {
        if (oss_textline.str().size() > 0) {
          oss_final << "// " << oss_textline.str();
          oss_textline.str("");
        }
        
        for (int i = 0; i < numPreLines; i++) {
          oss_final << std::endl;
        }

        atLineStart = true;
      }
      
      //===========================================
      // if op is shared, output it directly to
      // the final text on its own line, separate
      // from the commented-out original
      //===========================================
      
      // non-shared op: add to commented-out original line
      *targetOss << resultStr;
      atLineStart = false;
      
      //===========================================
      // output param bytes
      //===========================================
      
      int numParamBytes = numOpParamBytes(id);
      for (int i = 0; i < numParamBytes; i++) {
        *targetOss << as2bHex(ifs.readu8());
        atLineStart = false;
      }
      
      //===========================================
      // output post-linebreaks
      //===========================================
     
      int numPostLines = numOpPostLines(id);
      
      // HACK: hack for wait/end combo
      if ((id == op_wait) && ((unsigned char)ifs.peek() == op_end)) {
        numPostLines = 1;
      }
      else if ((id == op_clear) && ((unsigned char)ifs.peek() == op_end)) {
        numPostLines = 1;
      }
      
      if (numPostLines > 0) {
        if (oss_textline.str().size() > 0) {
          oss_final << "// " << oss_textline.str();
          oss_textline.str("");
        }
       
        for (int i = 0; i < numPostLines; i++) {
          oss_final << std::endl;
        }

        atLineStart = true;
      }
    }
    else {
      // account for auto-break every 7 chars
/*      ++charsOnLine;
      if ((autowrap != -1) && (charsOnLine > autowrap)) {
        oss_final << "// " << oss_textline.str();
        oss_textline.str("");
        oss_final << std::endl;
        charsOnLine = 0;
        atLineStart = true;
      } */
      
      // not an op: add to commented-out original line
      oss_textline << resultStr;
      
      atLineStart = false;
    }
    
    // check for terminators
    if ((id == op_end) || (id == op_wait)) {
      break;
    }
    
    // handle line-breaking ops
    if ((id == op_br) || (id == op_wait)) charsOnLine = 0;
    
    lastWasBr = (id == op_br);
  }
  
  ofs << "//[TEXT]" << endl;
  ofs << "#STARTMSG("
      // offset
      << TStringConversion::intToString(
          offset, TStringConversion::baseHex)
      << ", "
      // size
      << TStringConversion::intToString(
          ifs.tell() - offset, TStringConversion::baseDec)
      << ", "
      // slot num
      << TStringConversion::intToString(
          slot, TStringConversion::baseDec)
      << ")" << endl << endl;
  
//  ofs << oss.str();
  ofs << oss_final.str();
  
//  ofs << endl;
  ofs << "#ENDMSG()";
  ofs << endl << endl;
}

/*void dumpStringSet(TStream& ifs, std::ostream& ofs, const TThingyTable& table,
               int startOffset, int slot,
               int numStrings,
               string comment = "") {
  if (comment.size() > 0) {
    ofs << "//=======================================" << endl;
    ofs << "// " << comment << endl;
    ofs << "//=======================================" << endl;
    ofs << endl;
  }
  
  ifs.seek(startOffset);
  for (int i = 0; i < numStrings; i++) {
    ofs << "// substring " << i << endl;
    dumpString(ifs, ofs, table, ifs.tell(), slot, "");
  }
}

void dumpTilemap(TStream& ifs, std::ostream& ofs, int offset, int slot,
              TThingyTable& tbl, int w, int h,
              bool isHalved = true,
              string comment = "") {
  ifs.seek(offset);
  
  std::ostringstream oss;
  
  if (comment.size() > 0)
    oss << "// " << comment << endl;
  
  // comment out first line of original text
  oss << "// ";
  for (int j = 0; j < h; j++) {
    for (int i = 0; i < w; i++) {
    
//      TThingyTable::MatchResult result = tbl.matchId(ifs);
      
      TByte next = ifs.get();
      if (!tbl.hasEntry(next)) {
        throw TGenericException(T_SRCANDLINE,
                                "dumpTilemap()",
                                string("At offset ")
                                  + TStringConversion::intToString(
                                      ifs.tell() - 1,
                                      TStringConversion::baseHex)
                                  + ": unknown character '"
                                  + TStringConversion::intToString(
                                      (unsigned char)next,
                                      TStringConversion::baseHex)
                                  + "'");
      }
      
//      string resultStr = tbl.getEntry(result.id);
      string resultStr = tbl.getEntry(next);
      oss << resultStr;
      
      if (!isHalved) ifs.get();
    }
    
    // end of line
    oss << endl;
    oss << "// ";
  }
  
//  oss << endl << endl << "[end]";
  
  ofs << "#STARTMSG("
      // offset
      << TStringConversion::intToString(
          offset, TStringConversion::baseHex)
      << ", "
      // size
      << TStringConversion::intToString(
          ifs.tell() - offset, TStringConversion::baseDec)
      << ", "
      // slot num
      << TStringConversion::intToString(
          slot, TStringConversion::baseDec)
      << ")" << endl << endl;
  
  ofs << oss.str();
  
//  oss << endl;
  ofs << endl << endl;
//  ofs << "//   end pos: "
//      << TStringConversion::intToString(
//          ifs.tell(), TStringConversion::baseHex)
//      << endl;
//  ofs << "//   size: " << ifs.tell() - offset << endl;
  ofs << endl;
  ofs << "#ENDMSG()";
  ofs << endl << endl;
}

void dumpTilemapSet(TStream& ifs, std::ostream& ofs, int startOffset, int slot,
               TThingyTable& tbl, int w, int h,
               int numTilemaps,
               bool isHalved = true,
               string comment = "") {
  if (comment.size() > 0) {
    ofs << "//=======================================" << endl;
    ofs << "// " << comment << endl;
    ofs << "//=======================================" << endl;
    ofs << endl;
  }
  
  ifs.seek(startOffset);
  for (int i = 0; i < numTilemaps; i++) {
    ofs << "// tilemap " << i << endl;
    dumpTilemap(ifs, ofs, ifs.tell(), slot, tbl, w, h, isHalved);
  }
} */

/*const static int region_baseBank_default = 3;
const static int region_baseBank_region2 = 5;
const static int region_baseBank_region4 = 6;

int getRegionBaseBank(int regionNum) {
  switch (regionNum) {
  case 2: return region_baseBank_region2;
  case 4: return region_baseBank_region4;
  default: return region_baseBank_default;
  }
} */

/*void dumpRegionString(TStream& ifs, std::ostream& ofs, TThingyTable& table,
                      int regionNum, int scriptNum) {
  // skip invalid stuff in tables
  if ((regionNum == 3) && (scriptNum == 0x25)) {
    ofs << "#STARTMSG("
        // offset
        << TStringConversion::intToString(
            0, TStringConversion::baseHex)
        << ", "
        // size
        << TStringConversion::intToString(
            0, TStringConversion::baseDec)
        << ", "
        // slot num
        << TStringConversion::intToString(
            1, TStringConversion::baseDec)
        << ")" << endl << endl;
    
    ofs << endl;
    ofs << "#ENDMSG()";
    ofs << endl << endl;
    
    return;
  }
  
//  int baseBank = getRegionBaseBank(regionNum);
  ifs.seek(region_locTable_addr + (regionNum * 2));
  int rsrcId = ifs.readu8();
  int baseBank = ifs.readu8();
  
  int bankBaseAddr = baseBank * smsBankSize;
  ifs.seek(bankBaseAddr + 4 + (rsrcId * 2));
  int regionTablePtr = ifs.readu16le();
  int regionTableAddr = bankBaseAddr + (regionTablePtr - (smsBankSize * 1));
  
  ifs.seek(regionTableAddr + (scriptNum * 2));
  int scriptPtr = ifs.readu16le();
  int scriptAddr = bankBaseAddr + (scriptPtr - (smsBankSize * 1));
  
//  std::cerr << regionNum << " " << hex << " " << regionLoc << " " << regionBaseAddr << std::endl;
//  ifs.seek(regionBaseAddr);
//  int temp = ifs.readu16le();
//  std::cerr << hex << (temp / 2) << endl;
//  cerr << "region " << regionNum << ": " << hex << scriptNum << " "
//      << hex << regionTableAddr + (scriptNum * 2) << " "
//      << hex << scriptAddr << endl;
  
  ofs << "// script "
    << TStringConversion::intToString(regionNum, TStringConversion::baseDec)
    << "-"
    << TStringConversion::intToString(scriptNum, TStringConversion::baseHex)
    << endl;
  
  // dump target script
  dumpString(ifs, ofs, table, scriptAddr, 1, 7);
}

void dumpPointerTable(TStream& ifs, std::ostream& ofs, TThingyTable& table,
                int offset, int slot, int numScripts) {
  addComment(ofs,
    std::string("Pointer table ")
      + TStringConversion::intToString(offset, TStringConversion::baseHex));
      
//  ofs << "#STARTREGION(" << regionNum << ")" << endl << endl;

  int bankBase = (offset / smsBankSize) * smsBankSize;
  
  for (int i = 0; i < numScripts; i++) {
    int pointerOffset = (offset + (i * 2));
    ifs.seek(pointerOffset);
    int ptr = ifs.readu16le();
    int addr = (ptr - (smsBankSize * slot)) + bankBase;
    dumpString(ifs, ofs, table, addr, slot);
//    dumpRegionString(ifs, ofs, table, regionNum, i);
  }
}

void dumpRegion(TStream& ifs, std::ostream& ofs, TThingyTable& table,
                int regionNum, int numScripts) {
  addComment(ofs,
    std::string("Region ") + TStringConversion::intToString(regionNum));
  ofs << "#STARTREGION(" << regionNum << ")" << endl << endl;
  for (int i = 0; i < numScripts; i++) {
    dumpRegionString(ifs, ofs, table, regionNum, i);
  }
  ofs << "#ENDREGION(" << regionNum << ")" << endl << endl;
} */

int getScriptBlockPointer(TStream& rom, int blockNum) {
  rom.seek(blockTableAddr + (blockNum * 3));
  int bank = rom.readu8();
  int pointer = rom.readu16le();
  int blockBaseAddr = (bank * smsBankSize) + (pointer % smsBankSize);
  return blockBaseAddr;
}

void buildDictionary(TStream& rom, DictionaryMap& dict, int index,
                     int numEntries) {
  int blockBaseAddr = getScriptBlockPointer(rom, index);
  rom.seek(blockBaseAddr);
  
  for (int i = 0; i < numEntries; i++) {
    std::string str;
    
    TByte next = rom.get();
    while (next != op_wait) {
      str += next;
      next = rom.get();
    }
    
    dict[i + 1] = str;
  }
}

void dumpEventScripts(
                TStream& ifs, std::ostream& ofs, TThingyTable& table,
                int numScripts) {
  int highestId = -1;
  for (int i = 0; i < numScripts; i++) {
    lastAttemptedBlockScriptIndex = i;
    
    while (ifs.peek() != 0x00) {
      TByte next = ifs.peek();
      if (isTextEventOp(next)) {
        // skip start of op
        ifs.get();
        
        // it turns out that some ops have additional parameters preceding
        // the text string. skip these.
/*        if (next == 0x0A) ifs.seekoff(1);
        else if (next == 0x0F) ifs.seekoff(1);
        else if (next == 0x10) ifs.seekoff(1);
        else if (next == 0x1C) ifs.seekoff(3);
        else if (next == 0x1D) ifs.seekoff(3); */
        
        // not text
        if ((next == 0x08)
            || (next == 0x0A)
            || (next == 0x0F)
            || (next == 0x10)
            || (next == 0x17)
            || (next == 0x1C)
            || (next == 0x1D)) {
          while (!ifs.eof() && ((TByte)ifs.peek() != 0xFE)) ifs.seekoff(1);
          ifs.get();
          continue;
        }
        
//        if (next == 0x17) std::cout << "17: " << hex << ifs.tell();
        // this is not actually text; it's a collection of byte pairs
        // terminated with FE
/*        if (next == 0x1C) {
          while (!ifs.eof() && (ifs.peek() != 0xFE)) ifs.seekoff(2);
          ifs.get();
          continue;
        }
        
        if (next == 0x0A) std::cout << "a: " << hex << ifs.tell();
        if (next == 0x0F) std::cout << "f: " << hex << ifs.tell();
        if (next == 0x10) std::cout << "10: " << hex << ifs.tell();
        if (next == 0x1D) std::cout << "1D: " << hex << ifs.tell(); */
        
        // dump content
        dumpString(ifs, ofs, table, ifs.tell(), 2);
      }
      else {
        // skip
        ifs.seekoff(eventScriptOpSkipTable.at(next));
      }
    }
    
    // skip terminator
    ifs.get();
    
    // read script id number
    int id = ifs.readu8();
    
    if (verbose)
      std::cout << "  processing event script "
        << i
        << " (id: " << id << ")"
        << " at "
        << TStringConversion::intToString(ifs.tell(),
              TStringConversion::baseHex)
        << std::endl;
    
//    if (id < highestId) {
//      throw TGenericException(T_SRCANDLINE,
//                              "dumpEventScripts()",
//                              "Script ID decreased");
//    }
    
    highestId = id;
  }
}

void dumpTextScripts(
                TStream& ifs, std::ostream& ofs, TThingyTable& table,
                int numScripts) {
  for (int i = 0; i < numScripts; i++) {
    lastAttemptedBlockScriptIndex = i;
    
    dumpString(ifs, ofs, table, ifs.tell(), 2);
    
    if (verbose)
      std::cout << "  processing text script "
        << i
        << " at "
        << TStringConversion::intToString(ifs.tell(),
              TStringConversion::baseHex)
        << std::endl;
  }
}

void dumpEventScriptBlock(
                TStream& ifs, std::ostream& ofs, TThingyTable& table,
                int blockNum, int numScripts) {
  if (verbose)
    std::cout << "dumping event script block "
      << blockNum << std::endl;
  
  addComment(ofs,
    std::string("Event script block ")
      + TStringConversion::intToString(blockNum));
  ofs << "#STARTBLOCK(" << blockNum << ")" << endl << endl;
//  for (int i = 0; i < numScripts; i++) {
//    dumpRegionString(ifs, ofs, table, regionNum, i);
//    dumpBlock(ifs, ofs, table, blockNum);
    int blockBaseAddr = getScriptBlockPointer(ifs, blockNum);
    ifs.seek(blockBaseAddr);
    dumpEventScripts(ifs, ofs, table, numScripts);
//  }
  ofs << "#ENDBLOCK(" << blockNum << ")" << endl << endl;
}

void dumpTextScriptBlock(
                TStream& ifs, std::ostream& ofs, TThingyTable& table,
                int blockNum, int numScripts) {
  if (verbose)
    std::cout << "dumping text script block "
      << blockNum << std::endl;
  
  addComment(ofs,
    std::string("Text script block ")
      + TStringConversion::intToString(blockNum));
  ofs << "#STARTBLOCK(" << blockNum << ")" << endl << endl;
//  for (int i = 0; i < numScripts; i++) {
//    dumpRegionString(ifs, ofs, table, regionNum, i);
//    dumpBlock(ifs, ofs, table, blockNum);
    int blockBaseAddr = getScriptBlockPointer(ifs, blockNum);
    ifs.seek(blockBaseAddr);
    dumpTextScripts(ifs, ofs, table, numScripts);
//  }
  ofs << "#ENDBLOCK(" << blockNum << ")" << endl << endl;
}

void dumpTextTable(
                TStream& ifs, std::ostream& ofs, TThingyTable& table,
                int offset, int numScripts) {
  if (verbose)
    std::cout << "dumping text table "
      << offset << std::endl;
  
  addComment(ofs,
    std::string("Text table ")
      + TStringConversion::intToString(offset,
          TStringConversion::baseHex));
//  ofs << "#STARTBLOCK(" << blockNum << ")" << endl << endl;
  ifs.seek(offset);
  dumpTextScripts(ifs, ofs, table, numScripts);
//  ofs << "#ENDBLOCK(" << blockNum << ")" << endl << endl;
}

void dumpMenu(TStream& ifs, std::ostream& ofs, const TThingyTable& table,
              int offset) {
  ifs.seek(offset + 3);
  int stringAddr = ifs.readu16le();
  dumpMenuString(ifs, ofs, table, stringAddr);
}

void dumpMenuSet(TStream& ifs, std::ostream& ofs, const TThingyTable& table,
              int offset, int count) {
  for (int i = 0; i < count; i++) {
    dumpMenu(ifs, ofs, table, offset + (i * 8));
  }
}

//std::map<int, int> blockSizes;

int main(int argc, char* argv[]) {
  if (argc < 3) {
    cout << "Eternal Legend script dumper" << endl;
    cout << "Usage: " << argv[0] << " [rom] [outprefix]" << endl;
    
    return 0;
  }
  
  string romName = string(argv[1]);
//  string tableName = string(argv[2]);
  string outPrefix = string(argv[2]);
  
  TBufStream ifs;
  ifs.open(romName.c_str());
  
  TThingyTable tablestd;
  tablestd.readSjis(string("table/eleg.tbl"));
  
  buildDictionary(ifs, dictionary0, 0, 63);
  buildDictionary(ifs, dictionary1, 1, 186);
  buildDictionary(ifs, dictionary2, 2, 254);
  buildDictionary(ifs, dictionary3, 3, 141);
  
  ifs.seek(eventScriptOpSkipTableAddr);
  for (int i = 0; i < numEventScriptOps; i++) {
    eventScriptOpSkipTable[i] = ifs.get();
  }
  
  try
  {
    {
      std::ofstream ofs((outPrefix + "script.txt").c_str(),
                    ios_base::binary);
      
/*      for (int i = 0; i < dictionary0.size(); i++) {
        string str = dictionary0[i + 1];
        
        TBufStream ifs;
        for (int i = 0; i < str.size(); i++) ifs.put(str[i]);
        ifs.put(op_end);
        
        ifs.seek(0);
        dumpString(ifs, ofs, tablestd, 0, 2,
                   TStringConversion::intToString(i + 1));
      } */
      
//      dumpEventScriptBlock(ifs, ofs, tablestd, 4, 157);
      // TODO: last few scripts contain intro/ending text.
      // but their IDs aren't valid.
      // check on these
//      dumpEventScriptBlock(ifs, ofs, tablestd, 5, 39);
//      dumpEventScriptBlock(ifs, ofs, tablestd, 6, 18);
//      dumpEventScriptBlock(ifs, ofs, tablestd, 7, 13);
      
      // these are used only for dictionary lookups (right??)
//      dumpTextScriptBlock(ifs, ofs, tablestd, 0, 63);
//      dumpTextScriptBlock(ifs, ofs, tablestd, 1, 186);
      
      dumpEventScriptBlock(ifs, ofs, tablestd, 4, 157+1);
      dumpEventScriptBlock(ifs, ofs, tablestd, 5, 33);
      dumpEventScriptBlock(ifs, ofs, tablestd, 6, 19);
      dumpEventScriptBlock(ifs, ofs, tablestd, 7, 19);
      dumpEventScriptBlock(ifs, ofs, tablestd, 8, 15);
      dumpEventScriptBlock(ifs, ofs, tablestd, 9, 13);
      dumpEventScriptBlock(ifs, ofs, tablestd, 10, 10);
      dumpEventScriptBlock(ifs, ofs, tablestd, 11, 14);
      dumpEventScriptBlock(ifs, ofs, tablestd, 12, 14);
      dumpEventScriptBlock(ifs, ofs, tablestd, 13, 19);
      dumpEventScriptBlock(ifs, ofs, tablestd, 14, 17);
      dumpEventScriptBlock(ifs, ofs, tablestd, 15, 19);
      dumpEventScriptBlock(ifs, ofs, tablestd, 16, 20);
      dumpEventScriptBlock(ifs, ofs, tablestd, 17, 17);
      dumpEventScriptBlock(ifs, ofs, tablestd, 18, 6);
      dumpEventScriptBlock(ifs, ofs, tablestd, 19, 7);
      dumpEventScriptBlock(ifs, ofs, tablestd, 20, 3);
      dumpEventScriptBlock(ifs, ofs, tablestd, 21, 27);
      dumpEventScriptBlock(ifs, ofs, tablestd, 22, 23);
      dumpEventScriptBlock(ifs, ofs, tablestd, 23, 29);
      dumpEventScriptBlock(ifs, ofs, tablestd, 24, 13);
      dumpEventScriptBlock(ifs, ofs, tablestd, 25, 12);
      dumpEventScriptBlock(ifs, ofs, tablestd, 26, 16);
      dumpEventScriptBlock(ifs, ofs, tablestd, 27, 31);
      dumpEventScriptBlock(ifs, ofs, tablestd, 28, 8);
      dumpEventScriptBlock(ifs, ofs, tablestd, 29, 14);
      dumpEventScriptBlock(ifs, ofs, tablestd, 30, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 31, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 32, 10);
      dumpEventScriptBlock(ifs, ofs, tablestd, 33, 16);
      dumpEventScriptBlock(ifs, ofs, tablestd, 34, 19);
      dumpEventScriptBlock(ifs, ofs, tablestd, 35, 27);
      dumpEventScriptBlock(ifs, ofs, tablestd, 36, 8);
      dumpEventScriptBlock(ifs, ofs, tablestd, 37, 16);
      dumpEventScriptBlock(ifs, ofs, tablestd, 38, 13);
      dumpEventScriptBlock(ifs, ofs, tablestd, 39, 20);
      dumpEventScriptBlock(ifs, ofs, tablestd, 40, 6);
      dumpEventScriptBlock(ifs, ofs, tablestd, 41, 20);
      dumpEventScriptBlock(ifs, ofs, tablestd, 42, 2);
      dumpEventScriptBlock(ifs, ofs, tablestd, 43, 44);
      dumpEventScriptBlock(ifs, ofs, tablestd, 44, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 45, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 46, 21);
      dumpEventScriptBlock(ifs, ofs, tablestd, 47, 18);
      dumpEventScriptBlock(ifs, ofs, tablestd, 48, 28);
      dumpEventScriptBlock(ifs, ofs, tablestd, 49, 13);
      dumpEventScriptBlock(ifs, ofs, tablestd, 50, 43);
      dumpEventScriptBlock(ifs, ofs, tablestd, 51, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 52, 11);
      dumpEventScriptBlock(ifs, ofs, tablestd, 53, 5);
      dumpEventScriptBlock(ifs, ofs, tablestd, 54, 43);
      dumpEventScriptBlock(ifs, ofs, tablestd, 55, 43);
      dumpEventScriptBlock(ifs, ofs, tablestd, 56, 43);
      dumpEventScriptBlock(ifs, ofs, tablestd, 57, 12);
      dumpEventScriptBlock(ifs, ofs, tablestd, 58, 5);
      dumpEventScriptBlock(ifs, ofs, tablestd, 59, 5);
      dumpEventScriptBlock(ifs, ofs, tablestd, 60, 7);
      dumpEventScriptBlock(ifs, ofs, tablestd, 61, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 62, 11);
      dumpEventScriptBlock(ifs, ofs, tablestd, 63, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 64, 7);
      dumpEventScriptBlock(ifs, ofs, tablestd, 65, 3);
      dumpEventScriptBlock(ifs, ofs, tablestd, 66, 42);
      dumpEventScriptBlock(ifs, ofs, tablestd, 67, 3);
      dumpEventScriptBlock(ifs, ofs, tablestd, 68, 9);
      // modified
      dumpEventScriptBlock(ifs, ofs, tablestd, 69, 9);
      dumpEventScriptBlock(ifs, ofs, tablestd, 70, 3);
      dumpEventScriptBlock(ifs, ofs, tablestd, 71, 17);
      dumpEventScriptBlock(ifs, ofs, tablestd, 72, 18);
      dumpEventScriptBlock(ifs, ofs, tablestd, 73, 43);
      dumpEventScriptBlock(ifs, ofs, tablestd, 74, 4);
      // modified
      dumpEventScriptBlock(ifs, ofs, tablestd, 75, 4);
      dumpEventScriptBlock(ifs, ofs, tablestd, 76, 7);
      dumpEventScriptBlock(ifs, ofs, tablestd, 77, 17);
      dumpEventScriptBlock(ifs, ofs, tablestd, 78, 1+1);
      dumpEventScriptBlock(ifs, ofs, tablestd, 79, 1+1);
      
      dumpString(ifs, ofs, tablestd, 0x3E28, 1,
        "dashes for blank inventory/party slots");
//      dumpString(ifs, ofs, tablestd, 0x0E14, 1,
//        "party member selector: \"all\"");
      dumpTextTable(ifs, ofs, tablestd, 0x0E14, 3);
      dumpTextTable(ifs, ofs, tablestd, 0x0E43, 9);
      dumpTextTable(ifs, ofs, tablestd, 0x0E84, 1);
/*      for (int i = 4; i < 0x50; i++) {
        try {
          dumpEventScriptBlock(ifs, ofs, tablestd, i, 256);
        }
        catch (std::exception& e) {
          std::cout << "Caught: " << e.what() << std::endl;
          std::cout << "Guessing size = " << lastAttemptedBlockScriptIndex
            << std::endl;
          blockSizes[i] = lastAttemptedBlockScriptIndex;
        }
      } */
    }
    
    {
      std::ofstream ofs((outPrefix + "script_items.txt").c_str(),
                    ios_base::binary);
      
      dumpTextScriptBlock(ifs, ofs, tablestd, 2, 254);
    }
    
    {
      std::ofstream ofs((outPrefix + "script_monsters.txt").c_str(),
                    ios_base::binary);
      
      dumpTextScriptBlock(ifs, ofs, tablestd, 3, 141);
    }
    
//    dumpString(ifs, ofs, tablestd, 0x1A8D1, 2);
    
    {
      std::ofstream ofs((outPrefix + "script_menus.txt").c_str(),
                    ios_base::binary);
      
      dumpMenuSet(ifs, ofs, tablestd, 0x4071, 6);
      dumpMenuSet(ifs, ofs, tablestd, 0x409E, 1);
      dumpMenuSet(ifs, ofs, tablestd, 0x40A3, 9);
      dumpMenuSet(ifs, ofs, tablestd, 0x5240, 1);
      dumpMenuSet(ifs, ofs, tablestd, 0x7B98, 4);
      
//      dumpMenuString(ifs, ofs, tablestd, 0x5265);
//      dumpMenuString(ifs, ofs, tablestd, 0x527D);
      dumpMenuString(ifs, ofs, tablestd, 0x528B);
      dumpMenuString(ifs, ofs, tablestd, 0x52A0);
//      dumpMenuString(ifs, ofs, tablestd, 0x52AD);
//      dumpMenuString(ifs, ofs, tablestd, 0x52B7);
      dumpMenuString(ifs, ofs, tablestd, 0x7C01);
    }
    
    {
      std::ofstream ofs((outPrefix + "script_names.txt").c_str(),
                    ios_base::binary);
      
      dumpTextTable(ifs, ofs, tablestd, 0x3FE1, 8);
    }
    
/*    for (int i = 4; i < 0x50; i++) {
      std::cout << "dumpEventScriptBlock(ifs, ofs, tablestd, "
        << i
        << ", "
        << blockSizes[i]
        << ");" << std::endl;
    } */
  }
  catch (BlackT::TGenericException& e) {
    std::cerr << "Exception: " << e.problem() << std::endl;
    return 1;
  }
  
  
  return 0;
} 
