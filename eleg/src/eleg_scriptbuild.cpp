#include "util/TStringConversion.h"
#include "util/TBufStream.h"
#include "util/TIfstream.h"
#include "util/TOfstream.h"
#include "util/TThingyTable.h"
#include "eleg/ElegScriptReader.h"
#include "eleg/ElegLineWrapper.h"
#include "exception/TGenericException.h"
#include <string>
#include <map>
#include <fstream>
#include <iostream>
#include <sstream>

using namespace std;
using namespace BlackT;
using namespace Sms;

TThingyTable table;

const static int hashMask = 0x0FFF;

const static int op_jumpShort  = 0xED;
const static int op_waitendJump = 0xEE;
const static int op_endJump    = 0xEF;
const static int op_tilebr     = 0xF0;
const static int op_jump       = 0xF1;
const static int op_br         = 0xF8;
const static int op_end        = 0xFE;
const static int op_waitend    = 0xFF;

static int currentStringId = 256;
static int currentStringShortLookupId = 0;
static int menuStringId = 0;

string getStringName(ElegScriptReader::ResultString result) {
//  int bankNum = result.srcOffset / 0x4000;
  return string("string_")
    + TStringConversion::intToString(result.srcOffset,
          TStringConversion::baseHex);
}

void exportRawResults(ElegScriptReader::ResultCollection& results,
                      std::string filename) {
  TBufStream ofs(0x10000);
  for (int i = 0; i < results.size(); i++) {
    ofs.write(results[i].str.c_str(), results[i].str.size());
  }
  ofs.save((filename).c_str());
}

void exportRawResults(TStream& ifs,
                      std::string filename) {
  ElegScriptReader::ResultCollection results;
  ElegScriptReader(ifs, results, table)();
  exportRawResults(results, filename);
}

void exportTabledResults(TStream& ifs,
                         std::string binFilename,
                         ElegScriptReader::ResultCollection& results,
                         TBufStream& ofs) {
  int offset = 0;
  for (int i = 0; i < results.size(); i++) {
    ofs.writeu16le(offset + (results.size() * 2));
    offset += results[i].str.size();
  }
  
  for (int i = 0; i < results.size(); i++) {
    ofs.write(results[i].str.c_str(), results[i].str.size());
  }
  
  ofs.save((binFilename).c_str());
}

void exportTabledResults(TStream& ifs,
                         std::string binFilename) {
  ElegScriptReader::ResultCollection results;
  ElegScriptReader(ifs, results, table)();
  
//  std::ofstream incofs(incFilename.c_str());
  TBufStream ofs(0x10000);
  exportTabledResults(ifs, binFilename, results, ofs);
}

void exportSizeTabledResults(TStream& ifs,
                         std::string binFilename) {
  ElegScriptReader::ResultCollection results;
  ElegScriptReader(ifs, results, table)();
  
//  std::ofstream incofs(incFilename.c_str());
  TBufStream ofs(0x10000);
  ofs.writeu8(results.size());
  exportTabledResults(ifs, binFilename, results, ofs);
}

/*void generateHashTable(string infile, string outPrefix, string outName) {
  TBufStream ifs;
//    ifs.open((inPrefix + "script.txt").c_str());
//  ifs.open((outPrefix + "script_wrapped.txt").c_str());
  ifs.open(infile.c_str());
  
  ElegScriptReader::ResultCollection results;
  ElegScriptReader(ifs, results, table)();
  
//    TBufStream ofs(0x20000);
//    for (unsigned int i = 0; i < results.size(); i++) {
//      ofs.write(results[i].str.c_str(), results[i].str.size());
//    }
//    ofs.save((outPrefix + "script.bin").c_str());
  
  // create:
  // * an individual .bin file for each compiled string
  // * a .inc containing, for each string, one superfree section with an
  //   incbin that includes the corresponding string's .bin
  // * a .inc containing the hash bucket arrays for the remapped strings.
  //   table keys are (orig_pointer & 0x1FFF).
  //   the generated bucket sets go in a single superfree section.
  //   each bucket set is an array of the following structure (terminate
  //   arrays with FF so we can detect missed entries):
  //       struct Bucket {
  //       u8 origBank
  //       u16 origPointer  // respects original slotting!
  //       u8 newBank
  //       u16 newPointer
  //     }
  // * a .inc containing the bucket array start pointers (keys are 16-bit
  //   and range from 0x0000-0x1FFF, so this gets its own bank)
  
  std::ofstream strIncOfs(
    (outPrefix + "strings" + outName + ".inc").c_str());
  std::map<int, ElegScriptReader::ResultCollection>
    mappedStringBuckets;
  for (unsigned int i = 0; i < results.size(); i++) {
    std::string stringName = getStringName(results[i]) + outName;
    
    // write string to file
    TBufStream ofs(0x10000);
    ofs.write(results[i].str.c_str(), results[i].str.size());
    ofs.save((outPrefix + "strings/" + stringName + ".bin").c_str());
    
    // add string binary to generated includes
    strIncOfs << ".slot 2" << endl;
    strIncOfs << ".section \"string include " << outName << " "
      << i << "\" superfree"
      << endl;
    strIncOfs << "  " << stringName << ":" << endl;
    strIncOfs << "    " << ".incbin \""
      << outPrefix << "strings/" << stringName << ".bin"
      << "\"" << endl;
    strIncOfs << ".ends" << endl;
    
    // add to map
    mappedStringBuckets[results[i].srcOffset & hashMask]
      .push_back(results[i]);
  }
  
  // generate bucket arrays
  std::ofstream stringHashOfs(
    (outPrefix + "string_bucketarrays" + outName + ".inc").c_str());
  stringHashOfs << ".include \""
    << outPrefix + "strings" + outName + ".inc\""
    << endl;
  stringHashOfs << ".section \"string hash buckets " << outName
    << "\" superfree" << endl;
  stringHashOfs << "  stringHashBuckets" + outName + ":" << endl;
  for (std::map<int, ElegScriptReader::ResultCollection>::iterator it
         = mappedStringBuckets.begin();
       it != mappedStringBuckets.end();
       ++it) {
    int key = it->first;
    ElegScriptReader::ResultCollection& results = it->second;
    
    stringHashOfs << "  hashBucketArray_"
      << outName
      << TStringConversion::intToString(key,
            TStringConversion::baseHex)
      << ":" << endl;
    
    for (unsigned int i = 0; i < results.size(); i++) {
      ElegScriptReader::ResultString result = results[i];
      string stringName = getStringName(result) + outName;
      
      // original bank
      stringHashOfs << "    .db " << result.srcOffset / 0x4000 << endl;
      // original pointer (respecting slotting)
      stringHashOfs << "    .dw "
        << (result.srcOffset & 0x3FFF) + (0x4000 * result.srcSlot)
        << endl;
      // new bank
      stringHashOfs << "    .db :" << stringName << endl;
      // new pointer
      stringHashOfs << "    .dw " << stringName << endl;
    }
    
    // array terminator
    stringHashOfs << "  .db $FF " << endl;
  }
  stringHashOfs << ".ends" << endl;
  
  // generate bucket array hash table
  std::ofstream bucketHashOfs(
    (outPrefix + "string_bucket_hashtable" + outName + ".inc").c_str());
  bucketHashOfs << ".include \""
    << outPrefix + "string_bucketarrays" + outName + ".inc\""
    << endl;
  bucketHashOfs
    << ".section \"bucket array hash table " << outName
      << "\" size $4000 align $4000 superfree"
    << endl;
  bucketHashOfs << "  bucketArrayHashTable" << outName << ":" << endl;
  for (int i = 0; i < hashMask; i++) {
    std::map<int, ElegScriptReader::ResultCollection>::iterator findIt
      = mappedStringBuckets.find(i);
    if (findIt != mappedStringBuckets.end()) {
      int key = findIt->first;
      // bucket bank
      bucketHashOfs << "    .db :hashBucketArray_" + outName
        << TStringConversion::intToString(key,
              TStringConversion::baseHex)
        << endl;
      // bucket pointer
      bucketHashOfs << "    .dw hashBucketArray_" + outName
        << TStringConversion::intToString(key,
              TStringConversion::baseHex)
        << endl;
      // reserved
      bucketHashOfs << "    .db $FF"
        << endl;
    }
    else {
      // no array
      bucketHashOfs << "    .db $FF,$FF,$FF,$FF" << endl;
    }
  }
  bucketHashOfs << ".ends" << endl;
} */

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

void generateRemapAsmFiles(string infile, string outPrefix, string outName) {
  TBufStream ifs;
  ifs.open(infile.c_str());
  
  ElegScriptReader::ResultCollection results;
  ElegScriptReader(ifs, results, table)();
  
  std::ofstream dataOfs((outPrefix + outName + "data.inc").c_str());
  std::ofstream tableOfs((outPrefix + outName + "table.inc").c_str());
  std::ofstream overwriteOfs((outPrefix + outName + "overwrite.inc").c_str());
  
  std::map<int, int> usedIds;
  
  for (ElegScriptReader::ResultCollection::iterator it = results.begin();
       it != results.end();
       ++it) {
    ElegScriptReader::ResultString src = *it;
    
    if (src.srcSize < 3) {
      cout << "WARNING: Skipping string from "
        << TStringConversion::intToString(src.srcOffset,
            TStringConversion::baseHex)
        << " due to (srcSize < 3)" << endl;
      continue;
    }
    
    int id;
    if (src.srcSize == 3)
      id = currentStringShortLookupId++;
    else
      id = currentStringId++;
    
    int srcBankNum = src.srcOffset / 0x4000;
    int srcBankBase = (srcBankNum * 0x4000);
    int srcOrg = src.srcOffset - srcBankBase;
    
    // string ID may not contain the terminator opcode (0xFE)
    // in either byte, or else the script skipping logic will break
    int idLo = id & 0xFF;
    int idHi = (id & 0xFF00) >> 8;
    while ((idLo == op_end) || (idHi == op_end)
           || (idLo == op_waitend) || (idHi == op_waitend)) {
//      tableOfs << "  ; dummy entry " << id << endl;
//      tableOfs << "  .db $00,$00,$00,$00" << endl;
//      tableOfs << endl;
      
      if (src.srcSize == 3)
        id = currentStringShortLookupId++;
      else
        id = currentStringId++;
      
      idLo = id & 0xFF;
      idHi = (id & 0xFF00) >> 8;
    }
    
    usedIds[id] = src.srcOffset;
    
    string idString = std::string("string")
      + TStringConversion::intToString(id)
      + "_offset";
    
    TBufStream srcIfs;
    srcIfs.writeString(src.str);
    // the final byte of the script _must_ be a terminator.
    // replace it with a terminator-jump corresponding to the original
    // terminator.
    srcIfs.seekoff(-1);
    int lastOp = srcIfs.readu8();
    srcIfs.seekoff(-1);
    // opcode
    if (lastOp == op_end) {
      srcIfs.writeu8(0xEF);
    }
    else if (lastOp == op_waitend) {
      srcIfs.writeu8(0xEE);
    }
    else {
      throw TGenericException(T_SRCANDLINE,
                              "generateRemapAsmFiles()",
                              string("ERROR: script from ")
                              + TStringConversion::intToString(src.srcOffset,
                                TStringConversion::baseHex)
                              + " not terminated with terminator");
    }
//    srcIfs.writeu8(0xEF);
    // banknum
    srcIfs.writeu8(srcBankNum);
    // pointer
    srcIfs.writeu16le(srcOrg + src.srcSize + 0x8000);
    
    srcIfs.seek(0);
    std::ostringstream srcOss;
    binToDcb(srcIfs, srcOss);
    
    // data entry
    
    dataOfs << ".slot 2" << endl;
    dataOfs << ".section \"string " << id << " data\" superfree" << endl;
      // label
      dataOfs << "  " << idString << ":" << endl;
      // data
      dataOfs << srcOss.str();
    dataOfs << ".ends" << endl;
    dataOfs << endl;
    
    // table entry
    
/*     tableOfs << "  ; string " << id << " (orig: "
      << TStringConversion::intToString(src.srcOffset,
                                TStringConversion::baseHex)
      << ")"
      << endl;
    // pointer
    tableOfs << "  .dw " << idString << endl;
    // bank
    tableOfs << "  .db :" << idString << endl;
    // dummy
    tableOfs << "  .db $00" << endl;
    tableOfs << endl; */
    
    // overwrite entry
    
    overwriteOfs << ".bank " << srcBankNum << " slot 2" << endl;
    overwriteOfs << ".org " << srcOrg << endl;
    overwriteOfs << ".section \"string " << id << " overwrite\" overwrite" << endl;
    if (src.srcSize == 3) {
      // trigger opcode
      overwriteOfs << "  .db $ED" << endl;
      // message id
      overwriteOfs << "  .db " << id << endl;
    }
    else {
      // trigger opcode
      overwriteOfs << "  .db $F1" << endl;
      // message id
      overwriteOfs << "  .dw " << id << endl;
    }
    overwriteOfs << ".ends" << endl;
    overwriteOfs << endl;
  }
  
  tableOfs << ".slot 2" << endl;
  tableOfs << ".section \"script index table\" superfree" << endl;
  tableOfs << "  scriptStringJumpTable:" << endl;
  
  int tablePos = 0;
  for (std::map<int, int>::iterator it = usedIds.begin();
       it != usedIds.end();
       ++it) {
    int id = it->first;
    
    if (id < tablePos) cerr << "dead" << endl;
    
    while (tablePos != id) {
      tableOfs << "  ; dummy entry " << tablePos << endl;
      tableOfs << "  .db $00,$00,$00,$00" << endl;
      tableOfs << endl;
      ++tablePos;
    }
    
    string idString = std::string("string")
      + TStringConversion::intToString(id)
      + "_offset";
    
    tableOfs << "  ; string " << id << " (orig: "
      << TStringConversion::intToString(it->second,
                                TStringConversion::baseHex)
      << ")"
      << endl;
    // pointer
    tableOfs << "  .dw " << idString << endl;
    // bank
    tableOfs << "  .db :" << idString << endl;
    // dummy
    tableOfs << "  .db $00" << endl;
    tableOfs << endl;
    
    ++tablePos;
  }
  
  tableOfs << ".ends" << endl;
}

void generateMenuAsmFiles(string infile, string outPrefix, string outName) {
  TBufStream ifs;
  ifs.open(infile.c_str());
  
  ElegScriptReader::ResultCollection results;
  ElegScriptReader(ifs, results, table)();
  
  std::ofstream dataOfs((outPrefix + outName + "data.inc").c_str());
  std::ofstream overwriteOfs((outPrefix + outName + "overwrite.inc").c_str());
  
  for (ElegScriptReader::ResultCollection::iterator it = results.begin();
       it != results.end();
       ++it) {
    ElegScriptReader::ResultString src = *it;
    
    if (src.srcSize < 6) {
      cout << "WARNING: Skipping menu from "
        << TStringConversion::intToString(src.srcOffset,
            TStringConversion::baseHex)
        << " due to (srcSize < 6)" << endl;
      continue;
    }
    
    int srcBankNum = src.srcOffset / 0x4000;
    int srcBankBase = (srcBankNum * 0x4000);
    int srcOrg = src.srcOffset - srcBankBase;
    
    int id = menuStringId++;
    
    string idString = std::string("menu")
      + TStringConversion::intToString(id)
      + "_offset";
    
    TBufStream srcIfs;
    srcIfs.writeString(src.str);
    
    // first 2 bytes of data are window size specifier, which goes in
    // the overwrite file
    srcIfs.seek(2);
    std::ostringstream srcOss;
    binToDcb(srcIfs, srcOss);
    
    // data entry
    
    dataOfs << ".slot 2" << endl;
    dataOfs << ".section \"menu " << id << " data\" superfree" << endl;
      // label
      dataOfs << "  " << idString << ":" << endl;
      // data
      dataOfs << srcOss.str();
    dataOfs << ".ends" << endl;
    dataOfs << endl;
    
    // overwrite entry
    
    overwriteOfs << ".bank " << srcBankNum << " slot 2" << endl;
    overwriteOfs << ".org " << srcOrg << endl;
    overwriteOfs << ".section \"menu " << id << " overwrite\" overwrite" << endl;
      srcIfs.seek(0);
      {
        TBufStream tempIfs;
        
        // window size specifier
        tempIfs.put(srcIfs.get());
        tempIfs.put(srcIfs.get());
        // jump op
        tempIfs.put(op_endJump);
        
        tempIfs.seek(0);
        std::ostringstream tempOss;
        binToDcb(tempIfs, tempOss);
        
        overwriteOfs << tempOss.str();
      }
      overwriteOfs << "  .db :" << idString << endl;
      overwriteOfs << "  .dw " << idString << endl;
    overwriteOfs << ".ends" << endl;
    overwriteOfs << endl;
  }
}

int main(int argc, char* argv[]) {
  if (argc < 4) {
    cout << "Eternal Legend (Game Gear) script builder" << endl;
    cout << "Usage: " << argv[0] << " [inprefix] [thingy] [outprefix]"
      << endl;
    
    return 0;
  }
  
  string inPrefix = string(argv[1]);
  string tableName = string(argv[2]);
  string outPrefix = string(argv[3]);
  
  table.readSjis(tableName);
  
  // wrap script
  {
    // read size table
    ElegLineWrapper::CharSizeTable sizeTable;
    {
      TBufStream ifs;
      ifs.open("out/font/sizetable.bin");
      int pos = 0;
      while (!ifs.eof()) {
        sizeTable[pos++] = ifs.readu8();
      }
    }
    
    {
      TBufStream ifs;
      ifs.open((inPrefix + "script.txt").c_str());
      
      TLineWrapper::ResultCollection results;
      ElegLineWrapper(ifs, results, table, sizeTable)();
      
      if (results.size() > 0) {
        TOfstream ofs((outPrefix + "script_wrapped.txt").c_str());
        ofs.write(results[0].str.c_str(), results[0].str.size());
      }
    }
    
    {
      TBufStream ifs;
      ifs.open((inPrefix + "new.txt").c_str());
      
      TLineWrapper::ResultCollection results;
      ElegLineWrapper(ifs, results, table, sizeTable)();
      
      if (results.size() > 0) {
        TOfstream ofs((outPrefix + "new_wrapped.txt").c_str());
        ofs.write(results[0].str.c_str(), results[0].str.size());
      }
    }
  }
  
  // remapped strings
/*  generateHashTable((outPrefix + "script_wrapped.txt"),
                    outPrefix,
                    "main"); */
  
  generateRemapAsmFiles((outPrefix + "script_wrapped.txt"),
                        outPrefix,
                        "script_");
  generateMenuAsmFiles((inPrefix + "script_menus.txt"),
                        outPrefix,
                        "menus_");
  {
    TBufStream ifs;
    ifs.open((outPrefix + "new_wrapped.txt").c_str());
    
    exportTabledResults(ifs, outPrefix + "new.bin");
  }
  
  // tilemaps/new
/*  {
    TBufStream ifs;
    ifs.open((inPrefix + "tilemaps.txt").c_str());
    
    exportRawResults(ifs, outPrefix + "roulette_right.bin");
    exportRawResults(ifs, outPrefix + "roulette_wrong.bin");
    exportRawResults(ifs, outPrefix + "roulette_timeup.bin");
    exportRawResults(ifs, outPrefix + "roulette_perfect.bin");
    exportRawResults(ifs, outPrefix + "roulette_blank.bin");
    
    exportRawResults(ifs, outPrefix + "mainmenu_help.bin");
    
    exportSizeTabledResults(ifs, outPrefix + "credits.bin");
  } */
  
  // dialogue
/*  {
    TBufStream ifs;
    ifs.open((outPrefix + "dialogue_wrapped.txt").c_str());
    
    exportTabledResults(ifs, outPrefix + "dialogue.bin");
  }
  
  // credits
  {
    TBufStream ifs;
    ifs.open((inPrefix + "credits.txt").c_str());
    
    exportRawResults(ifs, outPrefix + "credits.bin");
  }
  
  // new text
  {
    TBufStream ifs;
    ifs.open((inPrefix + "new.txt").c_str());
    
    // turn counter
    exportRawResults(ifs, outPrefix + "turn_counter.bin");
  } */
  
  return 0;
}

