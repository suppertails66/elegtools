#include "madoua/MadouALineWrapper.h"
#include "util/TParse.h"
#include "util/TStringConversion.h"
#include "exception/TGenericException.h"
#include <iostream>

using namespace BlackT;

namespace Sms {

const static int controlOpsStart = 0xFD;
const static int controlOpsEnd   = 0x100;

/*const static int code_space   = 0x20;
//const static int code_clear   = 0xFD;
const static int code_rightbox = 0xC0;
const static int code_leftbox = 0xC1;
const static int code_bottombox = 0xC2;
const static int code_wait    = 0xC4;
const static int code_br      = 0xC3;
const static int code_end     = 0xFF; */

const static int op_terminator = 0x00;
const static int op_wait       = 0xFD;
const static int op_flags      = 0xFE;
const static int op_br         = 0xFF;

// added for translation
const static int op_num5digitBig = 0x1D;
const static int op_num5digit    = 0x1E;
const static int op_tilebr       = 0x1F;
const static int op_space        = 0x20;

MadouALineWrapper::MadouALineWrapper(BlackT::TStream& src__,
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

int MadouALineWrapper::widthOfKey(int key) {
  if ((key == op_br)) return 0;
  else if ((key == op_terminator)) return 0;
  else if ((key == op_tilebr)) return 8;  // assume worst case
  else if ((key == op_num5digit)) return 5 * 5;
  else if ((key == op_num5digitBig)) return 8 * 5;
  else if ((key >= controlOpsStart) && (key < controlOpsEnd)) return 0;
  
  return sizeTable[key];
}

bool MadouALineWrapper::isWordDivider(int key) {
  if (
      (key == op_br)
      || (key == op_space)
     ) return true;
  
  return false;
}

bool MadouALineWrapper::isLinebreak(int key) {
  if (
      (key == op_br)
      ) return true;
  
  return false;
}

bool MadouALineWrapper::isBoxClear(int key) {
  // END
  if ((key == op_terminator)
//      || (key == code_clear)
      || (key == op_wait)) return true;
  return false;
}

void MadouALineWrapper::onBoxFull() {
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
    content += thingy.getEntry(op_wait);
//    content += thingy.getEntry(code_br);
//    content += linebreakString();
    currentScriptBuffer.write(content.c_str(), content.size());
  }
  // linebreak
  stripCurrentPreDividers();
  
  currentScriptBuffer.put('\n');
  xPos = 0;
  yPos = 0;

/*  std::cerr << "WARNING: line " << lineNum << ":" << std::endl;
  std::cerr << "  overflow at: " << std::endl;
  std::cerr << streamAsString(currentScriptBuffer)
    << std::endl
    << streamAsString(currentWordBuffer) << std::endl; */
}

//int MadouALineWrapper::linebreakKey() {
//  return code_br;
//}

std::string MadouALineWrapper::linebreakString() const {
  std::string breakString = thingy.getEntry(op_br);
  if (breakMode == breakMode_single) {
    return breakString;
  }
  else {
    return breakString + breakString;
  }
}

//int MadouALineWrapper::linebreakHeight() const {
//  if (breakMode == breakMode_single) {
//    return 1;
//  }
//  else {
//    return 2;
//  }
//}

void MadouALineWrapper::onSymbolAdded(BlackT::TStream& ifs, int key) {
/*  if (isLinebreak(key)) {
    if ((yPos != -1) && (yPos >= ySize - 1)) {
      flushActiveWord();
      
    }
  } */
}

void MadouALineWrapper
    ::handleManualLinebreak(TLineWrapper::Symbol result, int key) {
  if ((key != op_br) || (breakMode == breakMode_single)) {
    TLineWrapper::handleManualLinebreak(result, key);
  }
  else {
    outputLinebreak(linebreakString());
  }
}

void MadouALineWrapper::afterLinebreak(
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

void MadouALineWrapper::beforeBoxClear(
    BoxClearSource clearSrc, int key) {
//  if (((clearSrc == boxClearManual) && (key == code_wait))) {
//    xBeforeWait = xPos;
//  }
}

void MadouALineWrapper::afterBoxClear(
  BoxClearSource clearSrc, int key) {
  // wait pauses but does not automatically break the line
  if (((clearSrc == boxClearManual) && (key == op_wait))) {
//    xPos = xBeforeWait;
    yPos = 0;
/*    if (breakMode == breakMode_single) {
      yPos = -1;
    }
    else {
      yPos = -2;
    } */
  }
}

bool MadouALineWrapper::processUserDirective(BlackT::TStream& ifs) {
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
                              "MadouALineWrapper::processUserDirective()",
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
