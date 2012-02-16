module octreeDble

!$use omp_lib
  use fsystem
  use genoutput
  use octreebase
  use storage

#define T          Dble
#define T_STORAGE  ST_DOUBLE
#define T_TYPE     real(DP)

#include "octree.h"

end module
