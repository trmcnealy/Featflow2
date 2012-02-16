module arraylistInt_Sngl

!$use omp_lib
  use arraylistbase
  use fsystem
  use genoutput
  use storage

#define T          Int
#define T_STORAGE  ST_INT
#define T_TYPE     integer

#define D          Sngl
#define D_STORAGE  ST_DOUBLE
#define D_TYPE     real(SP)

#include "arraylist.h"

end module
