#include "eleg/ElegLineWrapper.h"
#include "util/TParse.h"
#include "util/TStringConversion.h"
#include "exception/TGenericException.h"
#include <iostream>

using namespace BlackT;

namespace Sms {

const static int controlOpsStart = 0xF0;
const static int controlOpsEnd   = 0x100;

const static int code_space   = 0x20;
const static int code_arwyn   = 0xF2;
const static int code_party1  = 0xF3;
const static int code_party2  = 0xF4;
const static int code_wait    = 0xF5;
const static int code_5spaces = 0xF6;
const static int code_scrollout = 0xF7;
const static int code_br      = 0xF8;
const static int code_dict0   = 0xF9;
const static int code_dict1   = 0xFA;
const static int code_dict2   = 0xFB;
const static int code_dict3   = 0xFC;
const static int code_buf     = 0xFD;
const static int code_end     = 0xFE;
const static int code_waitend = 0xFF;

// added for translation
const static int code_tilebr  = 0xF0;

ElegLineWrapper::ElegLineWrapper(BlackT::TStream& src__,
                ResultCollection& dst__,
                const BlackT::TThingyTable& thingy__,
                CharSizeTable sizeTable__,
                int xSize__,
                int ySize__)
  : TLineWrapper(src__, dst__, thingy__, xSize__, ySize__),
    sizeTable(sizeTable__),
    xBeforeWait(-1),
//    clearMode(clearMode_default),
    breakMode(breakMode_single) {
  
}

int ElegLineWrapper::widthOfKey(int key) {
  if ((key == code_br)) return 0;
  else if ((key == code_arwyn)) return 27+16;
  // TODO 
  else if ((key == code_buf)) return 64;
//  else if ((key == code_party1)) return 64; // not used
//  else if ((key == code_party2)) return 64; // not used
  else if ((key == code_end)) return 0;
  else if ((key == code_wait)) return 0;
  else if ((key == code_waitend)) return 0;
  else if ((key == code_tilebr)) return 8;  // assume worst case
  else if ((key >= controlOpsStart) && (key < controlOpsEnd)) return 0;
  
  return sizeTable[key];
}

bool ElegLineWrapper::isWordDivider(int key) {
  if (
      (key == code_br)
      || (key == code_space)
     ) return true;
  
  return false;
}

bool ElegLineWrapper::isLinebreak(int key) {
  if (
      (key == code_br)
      ) return true;
  
  return false;
}

bool ElegLineWrapper::isBoxClear(int key) {
  // END
  if ((key == code_end)
      || (key == code_waitend)
      || (key == code_scrollout)
      || (key == code_wait)) return true;
  
  return false;
}

void ElegLineWrapper::onBoxFull() {
/*  if (clearMode == clearMode_default) {
    std::string content;
    if (lineHasContent) {
      // wait
      content += thingy.getEntry(code_wait);
      content += thingy.getEntry(code_br);
      currentScriptBuffer.write(content.c_str(), content.size());
    }
    // linebreak
    stripCurrentPreDividers();
    
    currentScriptBuffer.put('\n');
    xPos = 0;
    yPos = 0;
  }
  else if (clearMode == clearMode_messageSplit) {
    std::string content;
//      if (lineHasContent) {
      // wait
//        content += thingy.getEntry(code_wait);
//        content += thingy.getEntry(code_br);
      content += thingy.getEntry(code_end);
      content += "\n\n#ENDMSG()\n\n";
      currentScriptBuffer.write(content.c_str(), content.size());
//      }
    // linebreak
    stripCurrentPreDividers();
    
    xPos = 0;
    yPos = 0;
  } */
  
  std::string content;
  if (lineHasContent) {
    // wait
    content += thingy.getEntry(code_wait);
//    content += thingy.getEntry(code_br);
    content += linebreakString();
    currentScriptBuffer.write(content.c_str(), content.size());
  }
  // linebreak
  stripCurrentPreDividers();
  
  currentScriptBuffer.put('\n');
  xPos = 0;
  yPos = -1;

/*  std::cerr << "WARNING: line " << lineNum << ":" << std::endl;
  std::cerr << "  overflow at: " << std::endl;
  std::cerr << streamAsString(currentScriptBuffer)
    << std::endl
    << streamAsString(currentWordBuffer) << std::endl; */
}

//int ElegLineWrapper::linebreakKey() {
//  return code_br;
//}

std::string ElegLineWrapper::linebreakString() const {
  std::string breakString = thingy.getEntry(code_br);
  if (breakMode == breakMode_single) {
    return breakString;
  }
  else {
    return breakString + breakString;
  }
}

//int ElegLineWrapper::linebreakHeight() const {
//  if (breakMode == breakMode_single) {
//    return 1;
//  }
//  else {
//    return 2;
//  }
//}

void ElegLineWrapper::onSymbolAdded(BlackT::TStream& ifs, int key) {
/*  if (isLinebreak(key)) {
    if ((yPos != -1) && (yPos >= ySize - 1)) {
      flushActiveWord();
      
    }
  } */
}

void ElegLineWrapper
    ::handleManualLinebreak(TLineWrapper::Symbol result, int key) {
  if ((key != code_br) || (breakMode == breakMode_single)) {
    TLineWrapper::handleManualLinebreak(result, key);
  }
  else {
    outputLinebreak(linebreakString());
  }
}

void ElegLineWrapper::afterLinebreak(
    LinebreakSource clearSrc, int key) {
/*  if (clearSrc != linebreakBoxEnd) {
    if (spkrOn) {
      xPos = spkrLineInitialX;
    }
  } */
  
/*  if (clearSrc == linebreakManual) {
    if (breakMode == breakMode_double) {
      --yPos;
    }
  } */
}

void ElegLineWrapper::beforeBoxClear(
    BoxClearSource clearSrc, int key) {
  if (((clearSrc == boxClearManual) && (key == code_wait))) {
    xBeforeWait = xPos;
  }
}

void ElegLineWrapper::afterBoxClear(
  BoxClearSource clearSrc, int key) {
  // wait pauses but does not automatically break the line
  if (((clearSrc == boxClearManual) && (key == code_wait))) {
    xPos = xBeforeWait;
    yPos = -1;
/*    if (breakMode == breakMode_single) {
      yPos = -1;
    }
    else {
      yPos = -2;
    } */
  }
}

bool ElegLineWrapper::processUserDirective(BlackT::TStream& ifs) {
  TParse::skipSpace(ifs);
  
  std::string name = TParse::matchName(ifs);
  TParse::matchChar(ifs, '(');
  
  for (int i = 0; i < name.size(); i++) {
    name[i] = toupper(name[i]);
  }
  
  if (name.compare("SETBREAKMODE") == 0) {
    std::string type = TParse::matchName(ifs);
    
    if (type.compare("SINGLE") == 0) {
      breakMode = breakMode_single;
    }
    else if (type.compare("DOUBLE") == 0) {
      breakMode = breakMode_double;
    }
    else {
      throw TGenericException(T_SRCANDLINE,
                              "ElegLineWrapper::processUserDirective()",
                              "Line "
                                + TStringConversion::intToString(lineNum)
                                + ": unknown break mode '"
                                + type
                                + "'");
    }
    
    return true;
  }
/*  else if (name.compare("PARABR") == 0) {
//    if (yPos >= ySize) {
//      onBoxFull();
//    }
//    else {
//      onBoxFull();
//    }
    flushActiveWord();
    outputLinebreak();
    return true;
  } */
//  else if (name.compare("ENDMSG") == 0) {
//    processEndMsg(ifs);
//    return true;
//  }
  
  return false;
}

}
