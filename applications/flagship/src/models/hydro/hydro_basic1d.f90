!##############################################################################
!# ****************************************************************************
!# <name> hydro_basic1d </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains the basic routines required to solve the
!# compressible Euler/Navier-Stokes equations in 1D
!#
!# The following routines are available:
!#
!# 1.) hydro_getVarInterleaveFormat1d
!#     -> Extracts a single variable from the scalar vector of
!#        conservative variables stored in interleave format
!#
!# 2.) hydro_getVarBlockFormat1d
!#     -> Extracts a single variable from the vector of conservative
!#        variables stored in block format
!#
!# </purpose>
!##############################################################################

module hydro_basic1d

#include "../../flagship.h"
#include "hydro.h"

!$use omp_lib
  use fsystem
  use genoutput
  use linearsystemblock
  use linearsystemscalar

  implicit none

  private

  public :: hydro_getVarInterleaveFormat1d
  public :: hydro_getVarBlockFormat1d

contains

  !*****************************************************************************

!<subroutine>

  subroutine hydro_getVarInterleaveFormat1d(neq, nvar, cvariable, Ddata, Dvalue, Imask)

!<description>
    ! This subroutine extracs a single variable from the vector of
    ! conservative variabels which is stored in interleave format in 1D
!</description>

!<input>
    ! Number of equations
    integer, intent(in) :: neq

    ! Number of variables
    integer, intent(in) :: nvar

    ! Identifier for the variable
    character(LEN=*), intent(in) :: cvariable

    ! Vector of conservative variables
    real(DP), dimension(nvar,neq), intent(in) :: Ddata

    ! OPTIONAL: integer mask array
    ! If present only those entries of the destination vector are
    ! computed which are given by the integer mask.
    integer, dimension(:), intent(in), optional :: Imask
!</input>

!<output>
    ! Extracted single variable
    real(DP), dimension(:), intent(out) :: Dvalue
!</output>
!</subroutine>

    ! local variables
    integer :: ieq,idx

    
    if (trim(cvariable) .eq. 'density') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = DENSITY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = DENSITY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'velocity_magnitude') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = VELMAGNITUDE2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = VELMAGNITUDE2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'velocity_x') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = XVELOCITY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = XVELOCITY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'momentum_x') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = XMOMENTUM2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = XMOMENTUM2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = SPECIFICTOTALENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = SPECIFICTOTALENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if
      
    elseif (trim(cvariable) .eq. 'total_energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = TOTALENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = TOTALENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'internal_energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = INTERNALENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = INTERNALENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if
      
    elseif (trim(cvariable) .eq. 'kinetic_energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = KINETICENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = KINETICENERGY2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'pressure') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = PRESSURE2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = PRESSURE2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'machnumber') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = MACHNUMBER2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = MACHNUMBER2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'speedofsound') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = SOUNDSPEED2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = SOUNDSPEED2_1D(Ddata,IDX2_FORWARD,ieq,_,_)
        end do
      end if

    else
      
      call output_line('Invalid variable name!',&
          OU_CLASS_ERROR,OU_MODE_STD,'hydro_getVarInterleaveFormat1d')
      call sys_halt()
      
    end if
    
  end subroutine hydro_getVarInterleaveFormat1d

  !*****************************************************************************

!<subroutine>

  subroutine hydro_getVarBlockformat1d(neq, nvar, cvariable, Ddata, Dvalue, Imask)

!<description>
    ! This subroutine extracs a single variable from the vector of
    ! conservative variabels which is stored in block format in 1D
!</description>

!<input>
    ! Number of equations
    integer, intent(in) :: neq

    ! Number of variables
    integer, intent(in) :: nvar

    ! Identifier for the variable
    character(LEN=*), intent(in) :: cvariable

    ! Vector of conservative variables
    real(DP), dimension(neq,nvar), intent(in) :: Ddata

    ! OPTIONAL: integer mask array
    ! If present only those entries of the destination vector are
    ! computed which are given by the integer mask.
    integer, dimension(:), intent(in), optional :: Imask
!</input>

!<output>
    ! Extracted single variable
    real(DP), dimension(:), intent(out) :: Dvalue
!</output>
!</subroutine>

    ! local variables
    integer :: ieq,idx


    if (trim(cvariable) .eq. 'density') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = DENSITY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = DENSITY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if
      
    elseif (trim(cvariable) .eq. 'velocity_magnitude') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = VELMAGNITUDE2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = VELMAGNITUDE2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'velocity_x') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = XVELOCITY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = XVELOCITY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'momentum_x') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = XMOMENTUM2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
        Dvalue(ieq) = XMOMENTUM2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
      end do
    end if

    elseif (trim(cvariable) .eq. 'energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = SPECIFICTOTALENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = SPECIFICTOTALENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if
      
    elseif (trim(cvariable) .eq. 'total_energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = TOTALENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = TOTALENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'internal_energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = INTERNALENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = INTERNALENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'kinetic_energy') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = KINETICENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = KINETICENERGY2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'pressure') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = PRESSURE2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = PRESSURE2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if

    elseif (trim(cvariable) .eq. 'machnumber') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = MACHNUMBER2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = MACHNUMBER2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if
      
    elseif (trim(cvariable) .eq. 'speedofsound') then
      if (present(Imask)) then
        do idx = 1, size(Imask)
          ieq = Imask(idx)
          Dvalue(ieq) = SOUNDSPEED2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      else
        do ieq = 1, neq
          Dvalue(ieq) = SOUNDSPEED2_1D(Ddata,IDX2_REVERSE,ieq,_,_)
        end do
      end if
      
    else
      
      call output_line('Invalid variable name!',&
          OU_CLASS_ERROR,OU_MODE_STD,'hydro_getVarBlockformat1d')
      call sys_halt()
      
    end if

  end subroutine hydro_getVarBlockformat1d

end module hydro_basic1d
