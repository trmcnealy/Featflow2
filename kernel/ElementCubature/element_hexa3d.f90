!##############################################################################
!# ****************************************************************************
!# <name> element_hexa3d </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains the implementations of the 3D hexahedron basis
!# functions.
!#
!# </purpose>
!##############################################################################

module element_hexa3d

!$ use omp_lib
  use fsystem
  use basicgeometry
  use elementbase
  use derivatives
  use mprimitives
  use perfconfig
  use transformation

  implicit none

  private

  public :: elem_eval_Q0_3D
  public :: elem_eval_Q1_3D
  public :: elem_eval_Q2_3D
  public :: elem_eval_QP1_3D
  public :: elem_eval_QP1NP_3D

  public :: elem_eval_E030_3D
  public :: elem_eval_EB30_3D
  public :: elem_eval_EM30_3D
  public :: elem_eval_EN30_3D
  public :: elem_eval_E031_3D
  public :: elem_eval_E050_3D
  public :: elem_eval_EN50_3D
  public :: elem_eval_MSL2_3D
  public :: elem_eval_MSL2NP_3D

contains

  !****************************************************************************
  !****************************************************************************

  ! -------------- NEW ELEMENT INTERFACE IMPLEMENTATIONS FOLLOW --------------

  !****************************************************************************
  !****************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_Q0_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  !
  ! Due to the fact that this is a vector valued basis function, the
  ! meaning of Dbas is extended. There is
  !  Dbas(i        ,:,:,:) = values of the first basis function
  !  Dbas(i+ndofloc,:,:,:) = values of the 2nd basis function, 
  ! with ndofloc the number of local DOFs per element.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

    integer :: i   ! point counter
    integer :: j   ! element counter

    ! Q0 is a single basis function, constant in the element.
    ! The function value of the basis function is =1, the derivatives are all 0!

    !$omp parallel do default(shared) private(i) &
    !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
    do j=1,reval%nelements
      
      do i=1,reval%npointsPerElement
        Dbas(1,DER_FUNC,i,j) = 1.0_DP
      end do
      
    end do
    !$omp end parallel do

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_Q1_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! The Q1_3D element is specified by eight polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x*y, y*z, z*x, x*y*z }
  !
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,8:
  ! {
  !   For all j = 1,...,8:
  !   {
  !     Pi(vj) = kronecker(i,j)
  !   }
  ! }
  !
  ! With:
  ! vj being the eight corner vertices of the hexahedron
  !
  ! On the reference element, the above combination of monomial set and
  ! basis polynomial conditions leads to the following basis polynomials:
  !
  !  P1(x,y,z) = 1/8 * (1-x) * (1-y) * (1-z)
  !  P2(x,y,z) = 1/8 * (1+x) * (1-y) * (1-z)
  !  P3(x,y,z) = 1/8 * (1+x) * (1+y) * (1-z)
  !  P4(x,y,z) = 1/8 * (1-x) * (1+y) * (1-z)
  !  P5(x,y,z) = 1/8 * (1-x) * (1-y) * (1+z)
  !  P6(x,y,z) = 1/8 * (1+x) * (1-y) * (1+z)
  !  P7(x,y,z) = 1/8 * (1+x) * (1+y) * (1+z)
  !  P8(x,y,z) = 1/8 * (1-x) * (1+y) * (1+z)

  ! Parameter: number of local basis functions
  integer, parameter :: NBAS = 8

  ! derivatives on reference element
  real(DP), dimension(NBAS,NDIM3D) :: DrefDer

  ! Local variables
  real(DP) :: ddet,dx,dy,dz
  integer :: i,j

  real(DP), parameter :: Q1 = 1.0_DP
  real(DP), parameter :: Q8 = 0.125_DP

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,dx,dy,dz) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          Dbas(1,DER_FUNC3D,i,j) = Q8*(Q1-dx)*(Q1-dy)*(Q1-dz)
          Dbas(2,DER_FUNC3D,i,j) = Q8*(Q1+dx)*(Q1-dy)*(Q1-dz)
          Dbas(3,DER_FUNC3D,i,j) = Q8*(Q1+dx)*(Q1+dy)*(Q1-dz)
          Dbas(4,DER_FUNC3D,i,j) = Q8*(Q1-dx)*(Q1+dy)*(Q1-dz)
          Dbas(5,DER_FUNC3D,i,j) = Q8*(Q1-dx)*(Q1-dy)*(Q1+dz)
          Dbas(6,DER_FUNC3D,i,j) = Q8*(Q1+dx)*(Q1-dy)*(Q1+dz)
          Dbas(7,DER_FUNC3D,i,j) = Q8*(Q1+dx)*(Q1+dy)*(Q1+dz)
          Dbas(8,DER_FUNC3D,i,j) = Q8*(Q1-dx)*(Q1+dy)*(Q1+dz)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,dx,dy,dz,ddet,DrefDer) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Calculate derivatives on reference element
          ! X-derivatives
          DrefDer( 1,1) = -Q8*(Q1-dy)*(Q1-dz)
          DrefDer( 2,1) =  Q8*(Q1-dy)*(Q1-dz)
          DrefDer( 3,1) =  Q8*(Q1+dy)*(Q1-dz)
          DrefDer( 4,1) = -Q8*(Q1+dy)*(Q1-dz)
          DrefDer( 5,1) = -Q8*(Q1-dy)*(Q1+dz)
          DrefDer( 6,1) =  Q8*(Q1-dy)*(Q1+dz)
          DrefDer( 7,1) =  Q8*(Q1+dy)*(Q1+dz)
          DrefDer( 8,1) = -Q8*(Q1+dy)*(Q1+dz)

          ! Y-derivatives
          DrefDer( 1,2) = -Q8*(Q1-dx)*(Q1-dz)
          DrefDer( 2,2) = -Q8*(Q1+dx)*(Q1-dz)
          DrefDer( 3,2) =  Q8*(Q1+dx)*(Q1-dz)
          DrefDer( 4,2) =  Q8*(Q1-dx)*(Q1-dz)
          DrefDer( 5,2) = -Q8*(Q1-dx)*(Q1+dz)
          DrefDer( 6,2) = -Q8*(Q1+dx)*(Q1+dz)
          DrefDer( 7,2) =  Q8*(Q1+dx)*(Q1+dz)
          DrefDer( 8,2) =  Q8*(Q1-dx)*(Q1+dz)

          ! Z-derivatives
          DrefDer( 1,3) = -Q8*(Q1-dx)*(Q1-dy)
          DrefDer( 2,3) = -Q8*(Q1+dx)*(Q1-dy)
          DrefDer( 3,3) = -Q8*(Q1+dx)*(Q1+dy)
          DrefDer( 4,3) = -Q8*(Q1-dx)*(Q1+dy)
          DrefDer( 5,3) =  Q8*(Q1-dx)*(Q1-dy)
          DrefDer( 6,3) =  Q8*(Q1+dx)*(Q1-dy)
          DrefDer( 7,3) =  Q8*(Q1+dx)*(Q1+dy)
          DrefDer( 8,3) =  Q8*(Q1-dx)*(Q1+dy)

          ! Remark: Please note that the following code is universal and does
          ! not need to be modified for other parametric 3D hexahedron elements!

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)

          ! X-derivatives on real element
          dx = (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          dy = (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          dz = (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_X,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Y-derivatives on real element
          dx = (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          dy = (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          dz = (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Y,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Z-derivatives on real element
          dx = (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          dy = (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          dz = (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Z,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_Q2_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! The Q2_3D element is specified by twenty-seven polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x*y, y*z, z*x, x^2, y^2, z^2, x^2*y, y^2*z, z^2*x, x*y^2,
  !   y*z^2, z*x^2, x^2*y^2, y^2*z^2, z^2*x^2, x^2*y^2*z, y^2*z^2*x,
  !   z^2*x^2*y, x^2*y^2*z^2 }
  !
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,27:
  ! {
  !   For all j = 1,...,8:
  !   {
  !     Pi(vj) = kronecker(i,j)
  !   }
  !   For all j = 1,...,12:
  !   {
  !     Pi(ej) = kronecker(i,j+8)
  !   }
  !   For all j = 1,...,6:
  !   {
  !     Pi(fj) = kronecker(i,j+20)
  !   }
  !   Pi(0,0,0) = kronecker(i,27)
  ! }
  !
  ! With:
  ! vj being the eight corner vertices of the hexahedron
  ! ej being the twelve edge midpoints of the hexahedron
  ! fj being the six face midpoints of the hexahedron
  !
  ! On the reference element, the above combination of monomial set and
  ! basis polynomial conditions leads to the following basis polynomials:
  !
  ! P1 (x,y,z) = 1/8*x*y*z*(-1+x*( 1-y)+y*( 1-z)+z*( 1+x*(-1+y)))
  ! P2 (x,y,z) = 1/8*x*y*z*( 1+x*( 1-y)+y*(-1+z)+z*(-1+x*(-1+y)))
  ! P3 (x,y,z) = 1/8*x*y*z*(-1+x*(-1-y)+y*(-1+z)+z*( 1+x*( 1+y)))
  ! P4 (x,y,z) = 1/8*x*y*z*( 1+x*(-1-y)+y*( 1-z)+z*(-1+x*( 1+y)))
  ! P5 (x,y,z) = 1/8*x*y*z*( 1+x*(-1+y)+y*(-1-z)+z*( 1+x*(-1+y)))
  ! P6 (x,y,z) = 1/8*x*y*z*(-1+x*(-1+y)+y*( 1+z)+z*(-1+x*(-1+y)))
  ! P7 (x,y,z) = 1/8*x*y*z*( 1+x*( 1+y)+y*( 1+z)+z*( 1+x*( 1+y)))
  ! P8 (x,y,z) = 1/8*x*y*z*(-1+x*( 1+y)+y*(-1-z)+z*(-1+x*( 1+y)))
  ! P9 (x,y,z) = 1/4*y*z*( 1+y*(-1+z)-z+x^2*(-1+y+z*( 1-y)))
  ! P10(x,y,z) = 1/4*z*x*(-1+z*( 1+x)-x+y^2*( 1-z+x*( 1-z)))
  ! P11(x,y,z) = 1/4*y*z*(-1+y*(-1+z)+z+x^2*( 1+y+z*(-1-y)))
  ! P12(x,y,z) = 1/4*z*x*( 1+z*(-1+x)-x+y^2*(-1+z+x*( 1-z)))
  ! P13(x,y,z) = 1/4*x*y*( 1+x*(-1+y)-y+z^2*(-1+x+y*( 1-x)))
  ! P14(x,y,z) = 1/4*x*y*(-1+x*(-1+y)+y+z^2*( 1+x+y*(-1-x)))
  ! P15(x,y,z) = 1/4*x*y*( 1+x*( 1+y)+y+z^2*(-1-x+y*(-1-x)))
  ! P16(x,y,z) = 1/4*x*y*(-1+x*( 1+y)-y+z^2*( 1-x+y*( 1-x)))
  ! P17(x,y,z) = 1/4*y*z*(-1+y*( 1+z)-z+x^2*( 1-y+z*( 1-y)))
  ! P18(x,y,z) = 1/4*z*x*( 1+x*( 1+z)+z+y^2*(-1-x+z*(-1-x)))
  ! P19(x,y,z) = 1/4*y*z*( 1+y*( 1+z)+z+x^2*(-1-y+z*(-1-y)))
  ! P20(x,y,z) = 1/4*z*x*(-1+z*(-1+x)+x+y^2*( 1+z+x*(-1-z)))
  ! P21(x,y,z) = 1/2*z*(-1+x^2*( 1-y^2)+y^2+z*(1-x^2*(-1+y^2)-y^2))
  ! P22(x,y,z) = 1/2*y*(-1+z^2*( 1-x^2)+x^2+y*(1+z^2*(-1+x^2)-x^2))
  ! P23(x,y,z) = 1/2*x*( 1+y^2*(-1+z^2)-z^2+x*(1+y^2*(-1+z^2)-z^2))
  ! P24(x,y,z) = 1/2*y*( 1+z^2*(-1+x^2)-x^2+y*(1+z^2*(-1+x^2)-x^2))
  ! P25(x,y,z) = 1/2*x*(-1+y^2*( 1-z^2)+z^2+x*(1+y^2*(-1+z^2)-z^2))
  ! P26(x,y,z) = 1/2*z*( 1+x^2*( 1-y^2)-y^2+z*(1+x^2*(-1+y^2)-y^2))
  ! P27(x,y,z) = 1+x^2*(-1+y^2)+y^2*(-1+z^2)+z^2*(-1+x^2*(1-y^2))

  ! Parameter: number of local basis functions
  integer, parameter :: NBAS = 27

  ! derivatives on reference element
  real(DP), dimension(NBAS,NDIM3D) :: DrefDer

  ! Local variables
  real(DP) :: ddet,dx,dy,dz,dx2,dy2,dz2,daux
  integer :: i,j

  real(DP), parameter :: Q1 = 1.0_DP
  real(DP), parameter :: Q2 = 0.5_DP
  real(DP), parameter :: Q4 = 0.25_DP
  real(DP), parameter :: Q8 = 0.125_DP

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,dx,dy,dz,dx2,dy2,dz2,daux) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Pre-calculate squares
          dx2 = dx * dx
          dy2 = dy * dy
          dz2 = dz * dz

          daux = Q8*dx*dy*dz
          Dbas( 1,DER_FUNC3D,i,j) = daux*(-Q1+dx*( Q1-dy)+dy*( Q1-dz)+dz*( Q1+dx*(-Q1+dy)))
          Dbas( 2,DER_FUNC3D,i,j) = daux*( Q1+dx*( Q1-dy)+dy*(-Q1+dz)+dz*(-Q1+dx*(-Q1+dy)))
          Dbas( 3,DER_FUNC3D,i,j) = daux*(-Q1+dx*(-Q1-dy)+dy*(-Q1+dz)+dz*( Q1+dx*( Q1+dy)))
          Dbas( 4,DER_FUNC3D,i,j) = daux*( Q1+dx*(-Q1-dy)+dy*( Q1-dz)+dz*(-Q1+dx*( Q1+dy)))
          Dbas( 5,DER_FUNC3D,i,j) = daux*( Q1+dx*(-Q1+dy)+dy*(-Q1-dz)+dz*( Q1+dx*(-Q1+dy)))
          Dbas( 6,DER_FUNC3D,i,j) = daux*(-Q1+dx*(-Q1+dy)+dy*( Q1+dz)+dz*(-Q1+dx*(-Q1+dy)))
          Dbas( 7,DER_FUNC3D,i,j) = daux*( Q1+dx*( Q1+dy)+dy*( Q1+dz)+dz*( Q1+dx*( Q1+dy)))
          Dbas( 8,DER_FUNC3D,i,j) = daux*(-Q1+dx*( Q1+dy)+dy*(-Q1-dz)+dz*(-Q1+dx*( Q1+dy)))
          Dbas( 9,DER_FUNC3D,i,j) = Q4*dy*dz*( Q1+dy*(-Q1+dz)-dz+dx2*(-Q1+dy+dz*( Q1-dy)))
          Dbas(10,DER_FUNC3D,i,j) = Q4*dz*dx*(-Q1+dz*( Q1+dx)-dx+dy2*( Q1-dz+dx*( Q1-dz)))
          Dbas(11,DER_FUNC3D,i,j) = Q4*dy*dz*(-Q1+dy*(-Q1+dz)+dz+dx2*( Q1+dy+dz*(-Q1-dy)))
          Dbas(12,DER_FUNC3D,i,j) = Q4*dz*dx*( Q1+dz*(-Q1+dx)-dx+dy2*(-Q1+dz+dx*( Q1-dz)))
          Dbas(13,DER_FUNC3D,i,j) = Q4*dx*dy*( Q1+dx*(-Q1+dy)-dy+dz2*(-Q1+dx+dy*( Q1-dx)))
          Dbas(14,DER_FUNC3D,i,j) = Q4*dx*dy*(-Q1+dx*(-Q1+dy)+dy+dz2*( Q1+dx+dy*(-Q1-dx)))
          Dbas(15,DER_FUNC3D,i,j) = Q4*dx*dy*( Q1+dx*( Q1+dy)+dy+dz2*(-Q1-dx+dy*(-Q1-dx)))
          Dbas(16,DER_FUNC3D,i,j) = Q4*dx*dy*(-Q1+dx*( Q1+dy)-dy+dz2*( Q1-dx+dy*( Q1-dx)))
          Dbas(17,DER_FUNC3D,i,j) = Q4*dy*dz*(-Q1+dy*( Q1+dz)-dz+dx2*( Q1-dy+dz*( Q1-dy)))
          Dbas(18,DER_FUNC3D,i,j) = Q4*dz*dx*( Q1+dx*( Q1+dz)+dz+dy2*(-Q1-dx+dz*(-Q1-dx)))
          Dbas(19,DER_FUNC3D,i,j) = Q4*dy*dz*( Q1+dy*( Q1+dz)+dz+dx2*(-Q1-dy+dz*(-Q1-dy)))
          Dbas(20,DER_FUNC3D,i,j) = Q4*dz*dx*(-Q1+dz*(-Q1+dx)+dx+dy2*( Q1+dz+dx*(-Q1-dz)))
          Dbas(21,DER_FUNC3D,i,j) = Q2*dz*(-Q1+dx2*( Q1-dy2)+dy2+dz*(Q1+dx2*(-Q1+dy2)-dy2))
          Dbas(22,DER_FUNC3D,i,j) = Q2*dy*(-Q1+dz2*( Q1-dx2)+dx2+dy*(Q1+dz2*(-Q1+dx2)-dx2))
          Dbas(23,DER_FUNC3D,i,j) = Q2*dx*( Q1+dy2*(-Q1+dz2)-dz2+dx*(Q1+dy2*(-Q1+dz2)-dz2))
          Dbas(24,DER_FUNC3D,i,j) = Q2*dy*( Q1+dz2*(-Q1+dx2)-dx2+dy*(Q1+dz2*(-Q1+dx2)-dx2))
          Dbas(25,DER_FUNC3D,i,j) = Q2*dx*(-Q1+dy2*( Q1-dz2)+dz2+dx*(Q1+dy2*(-Q1+dz2)-dz2))
          Dbas(26,DER_FUNC3D,i,j) = Q2*dz*( Q1+dx2*(-Q1+dy2)-dy2+dz*(Q1+dx2*(-Q1+dy2)-dy2))
          Dbas(27,DER_FUNC3D,i,j) = Q1+dx2*(-Q1+dy2)+dy2*(-Q1+dz2)+dz2*(-Q1+dx2*(Q1-dy2))

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

      ! Loop through all elements
      !$omp parallel do default(shared)&
      !$omp private(i,dx,dy,dz,dx2,dy2,dz2,daux,ddet,DrefDer) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Pre-calculate squares
          dx2 = dx * dx
          dy2 = dy * dy
          dz2 = dz * dz

          ! Calculate derivatives on reference element
          ! X-derivatives
          daux = Q4*dx*dy*dz
          DrefDer( 1,1) = Q8*dy*dz*(-Q1+dy*( Q1-dz)+dz)+daux*( Q1+dy*(-Q1+dz)-dz)
          DrefDer( 2,1) = Q8*dy*dz*( Q1+dy*(-Q1+dz)-dz)+daux*( Q1+dy*(-Q1+dz)-dz)
          DrefDer( 3,1) = Q8*dy*dz*(-Q1+dy*(-Q1+dz)+dz)+daux*(-Q1+dy*(-Q1+dz)+dz)
          DrefDer( 4,1) = Q8*dy*dz*( Q1+dy*( Q1-dz)-dz)+daux*(-Q1+dy*(-Q1+dz)+dz)
          DrefDer( 5,1) = Q8*dy*dz*( Q1+dy*(-Q1-dz)+dz)+daux*(-Q1+dy*( Q1+dz)-dz)
          DrefDer( 6,1) = Q8*dy*dz*(-Q1+dy*( Q1+dz)-dz)+daux*(-Q1+dy*( Q1+dz)-dz)
          DrefDer( 7,1) = Q8*dy*dz*( Q1+dy*( Q1+dz)+dz)+daux*( Q1+dy*( Q1+dz)+dz)
          DrefDer( 8,1) = Q8*dy*dz*(-Q1+dy*(-Q1-dz)-dz)+daux*( Q1+dy*( Q1+dz)+dz)
          DrefDer( 9,1) = Q2*dx*dy*dz*(-Q1+dy*( Q1-dz)+dz)
          DrefDer(10,1) = Q2*dz*dx*(-Q1+dy2*( Q1-dz)+dz)+Q4*dz*(-Q1+dy2*( Q1-dz)+dz)
          DrefDer(11,1) = Q2*dx*dy*dz*( Q1+dy*( Q1-dz)-dz)
          DrefDer(12,1) = Q2*dz*dx*(-Q1+dy2*( Q1-dz)+dz)+Q4*dz*( Q1+dy2*(-Q1+dz)-dz)
          DrefDer(13,1) = Q2*dx*dy*(-Q1+dz2*( Q1-dy)+dy)+Q4*dy*( Q1+dz2*(-Q1+dy)-dy)
          DrefDer(14,1) = Q2*dx*dy*(-Q1+dz2*( Q1-dy)+dy)+Q4*dy*(-Q1+dz2*( Q1-dy)+dy)
          DrefDer(15,1) = Q2*dx*dy*( Q1+dz2*(-Q1-dy)+dy)+Q4*dy*( Q1+dz2*(-Q1-dy)+dy)
          DrefDer(16,1) = Q2*dx*dy*( Q1+dz2*(-Q1-dy)+dy)+Q4*dy*(-Q1+dz2*( Q1+dy)-dy)
          DrefDer(17,1) = Q2*dx*dy*dz*( Q1+dy*(-Q1-dz)+dz)
          DrefDer(18,1) = Q2*dz*dx*( Q1+dy2*(-Q1-dz)+dz)+Q4*dz*( Q1+dy2*(-Q1-dz)+dz)
          DrefDer(19,1) = Q2*dx*dy*dz*(-Q1+dy*(-Q1-dz)-dz)
          DrefDer(20,1) = Q2*dz*dx*( Q1+dy2*(-Q1-dz)+dz)+Q4*dz*(-Q1+dy2*( Q1+dz)-dz)
          DrefDer(21,1) = dz*dx*( Q1+dy2*(-Q1+dz)-dz)
          DrefDer(22,1) = dx*dy*( Q1+dz2*(-Q1+dy)-dy)
          DrefDer(23,1) = Q2*( Q1+dy2*(-Q1+dz2)-dz2)+dx*( Q1+dy2*(-Q1+dz2)-dz2)
          DrefDer(24,1) = dx*dy*(-Q1+dz2*( Q1+dy)-dy)
          DrefDer(25,1) = Q2*(-Q1+dy2*( Q1-dz2)+dz2)+dx*( Q1+dy2*(-Q1+dz2)-dz2)
          DrefDer(26,1) = dz*dx*(-Q1+dy2*( Q1+dz)-dz)
          DrefDer(27,1) = 2.0_DP*dx*(-Q1+dy2*( Q1-dz2)+dz2)

          ! Y-derivatives
          DrefDer( 1,2) = Q8*dz*dx*(-Q1+dz*( Q1-dx)+dx)+daux*( Q1+dz*(-Q1+dx)-dx)
          DrefDer( 2,2) = Q8*dz*dx*( Q1+dz*(-Q1-dx)+dx)+daux*(-Q1+dz*( Q1+dx)-dx)
          DrefDer( 3,2) = Q8*dz*dx*(-Q1+dz*( Q1+dx)-dx)+daux*(-Q1+dz*( Q1+dx)-dx)
          DrefDer( 4,2) = Q8*dz*dx*( Q1+dz*(-Q1+dx)-dx)+daux*( Q1+dz*(-Q1+dx)-dx)
          DrefDer( 5,2) = Q8*dz*dx*( Q1+dz*( Q1-dx)-dx)+daux*(-Q1+dz*(-Q1+dx)+dx)
          DrefDer( 6,2) = Q8*dz*dx*(-Q1+dz*(-Q1-dx)-dx)+daux*( Q1+dz*( Q1+dx)+dx)
          DrefDer( 7,2) = Q8*dz*dx*( Q1+dz*( Q1+dx)+dx)+daux*( Q1+dz*( Q1+dx)+dx)
          DrefDer( 8,2) = Q8*dz*dx*(-Q1+dz*(-Q1+dx)+dx)+daux*(-Q1+dz*(-Q1+dx)+dx)
          DrefDer( 9,2) = Q2*dy*dz*(-Q1+dx2*( Q1-dz)+dz)+Q4*dz*( Q1+dx2*(-Q1+dz)-dz)
          DrefDer(10,2) = Q2*dx*dy*dz*( Q1+dz*(-Q1-dx)+dx)
          DrefDer(11,2) = Q2*dy*dz*(-Q1+dx2*( Q1-dz)+dz)+Q4*dz*(-Q1+dx2*( Q1-dz)+dz)
          DrefDer(12,2) = Q2*dx*dy*dz*(-Q1+dz*( Q1-dx)+dx)
          DrefDer(13,2) = Q2*dx*dy*(-Q1+dz2*( Q1-dx)+dx)+Q4*dx*( Q1+dz2*(-Q1+dx)-dx)
          DrefDer(14,2) = Q2*dx*dy*( Q1+dz2*(-Q1-dx)+dx)+Q4*dx*(-Q1+dz2*( Q1+dx)-dx)
          DrefDer(15,2) = Q2*dx*dy*( Q1+dz2*(-Q1-dx)+dx)+Q4*dx*( Q1+dz2*(-Q1-dx)+dx)
          DrefDer(16,2) = Q2*dx*dy*(-Q1+dz2*( Q1-dx)+dx)+Q4*dx*(-Q1+dz2*( Q1-dx)+dx)
          DrefDer(17,2) = Q2*dy*dz*( Q1+dx2*(-Q1-dz)+dz)+Q4*dz*(-Q1+dx2*( Q1+dz)-dz)
          DrefDer(18,2) = Q2*dx*dy*dz*(-Q1+dz*(-Q1-dx)-dx)
          DrefDer(19,2) = Q2*dy*dz*( Q1+dx2*(-Q1-dz)+dz)+Q4*dz*( Q1+dx2*(-Q1-dz)+dz)
          DrefDer(20,2) = Q2*dx*dy*dz*( Q1+dz*( Q1-dx)-dx)
          DrefDer(21,2) = dy*dz*( Q1+dx2*(-Q1+dz)-dz)
          DrefDer(22,2) = Q2*(-Q1+dz2*( Q1-dx2)+dx2)+dy*( Q1+dz2*(-Q1+dx2)-dx2)
          DrefDer(23,2) = dx*dy*(-Q1+dz2*( Q1+dx)-dx)
          DrefDer(24,2) = Q2*( Q1+dz2*(-Q1+dx2)-dx2)+dy*( Q1+dz2*(-Q1+dx2)-dx2)
          DrefDer(25,2) = dx*dy*( Q1+dz2*(-Q1+dx)-dx)
          DrefDer(26,2) = dy*dz*(-Q1+dx2*( Q1+dz)-dz)
          DrefDer(27,2) = 2.0_DP*dy*(-Q1+dz2*( Q1-dx2)+dx2)

          ! Z-derivatives
          DrefDer( 1,3) = Q8*dx*dy*(-Q1+dx*( Q1-dy)+dy)+daux*( Q1+dx*(-Q1+dy)-dy)
          DrefDer( 2,3) = Q8*dx*dy*( Q1+dx*( Q1-dy)-dy)+daux*(-Q1+dx*(-Q1+dy)+dy)
          DrefDer( 3,3) = Q8*dx*dy*(-Q1+dx*(-Q1-dy)-dy)+daux*( Q1+dx*( Q1+dy)+dy)
          DrefDer( 4,3) = Q8*dx*dy*( Q1+dx*(-Q1-dy)+dy)+daux*(-Q1+dx*( Q1+dy)-dy)
          DrefDer( 5,3) = Q8*dx*dy*( Q1+dx*(-Q1+dy)-dy)+daux*( Q1+dx*(-Q1+dy)-dy)
          DrefDer( 6,3) = Q8*dx*dy*(-Q1+dx*(-Q1+dy)+dy)+daux*(-Q1+dx*(-Q1+dy)+dy)
          DrefDer( 7,3) = Q8*dx*dy*( Q1+dx*( Q1+dy)+dy)+daux*( Q1+dx*( Q1+dy)+dy)
          DrefDer( 8,3) = Q8*dx*dy*(-Q1+dx*( Q1+dy)-dy)+daux*(-Q1+dx*( Q1+dy)-dy)
          DrefDer( 9,3) = Q2*dy*dz*(-Q1+dx2*( Q1-dy)+dy)+Q4*dy*( Q1+dx2*(-Q1+dy)-dy)
          DrefDer(10,3) = Q2*dz*dx*( Q1+dy2*(-Q1-dx)+dx)+Q4*dx*(-Q1+dy2*( Q1+dx)-dx)
          DrefDer(11,3) = Q2*dy*dz*( Q1+dx2*(-Q1-dy)+dy)+Q4*dy*(-Q1+dx2*( Q1+dy)-dy)
          DrefDer(12,3) = Q2*dz*dx*(-Q1+dy2*( Q1-dx)+dx)+Q4*dx*( Q1+dy2*(-Q1+dx)-dx)
          DrefDer(13,3) = Q2*dx*dy*dz*(-Q1+dx*( Q1-dy)+dy)
          DrefDer(14,3) = Q2*dx*dy*dz*( Q1+dx*( Q1-dy)-dy)
          DrefDer(15,3) = Q2*dx*dy*dz*(-Q1+dx*(-Q1-dy)-dy)
          DrefDer(16,3) = Q2*dx*dy*dz*( Q1+dx*(-Q1-dy)+dy)
          DrefDer(17,3) = Q2*dy*dz*(-Q1+dx2*( Q1-dy)+dy)+Q4*dy*(-Q1+dx2*( Q1-dy)+dy)
          DrefDer(18,3) = Q2*dz*dx*( Q1+dy2*(-Q1-dx)+dx)+Q4*dx*( Q1+dy2*(-Q1-dx)+dx)
          DrefDer(19,3) = Q2*dy*dz*( Q1+dx2*(-Q1-dy)+dy)+Q4*dy*( Q1+dx2*(-Q1-dy)+dy)
          DrefDer(20,3) = Q2*dz*dx*(-Q1+dy2*( Q1-dx)+dx)+Q4*dx*(-Q1+dy2*( Q1-dx)+dx)
          DrefDer(21,3) = Q2*(-Q1+dx2*( Q1-dy2)+dy2)+dz*( Q1+dx2*(-Q1+dy2)-dy2)
          DrefDer(22,3) = dy*dz*( Q1+dx2*(-Q1+dy)-dy)
          DrefDer(23,3) = dz*dx*(-Q1+dy2*( Q1+dx)-dx)
          DrefDer(24,3) = dy*dz*(-Q1+dx2*( Q1+dy)-dy)
          DrefDer(25,3) = dz*dx*( Q1+dy2*(-Q1+dx)-dx)
          DrefDer(26,3) = Q2*( Q1+dx2*(-Q1+dy2)-dy2)+dz*( Q1+dx2*(-Q1+dy2)-dy2)
          DrefDer(27,3) = 2.0_DP*dz*(-Q1+dx2*( Q1-dy2)+dy2)

          ! Remark: Please note that the following code is universal and does
          ! not need to be modified for other parametric 3D hexahedron elements!

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)

          ! X-derivatives on real element
          dx = (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          dy = (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          dz = (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_X,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Y-derivatives on real element
          dx = (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          dy = (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          dz = (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Y,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Z-derivatives on real element
          dx = (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          dy = (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          dz = (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Z,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_QP1_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

! </subroutine>

  ! Element Description
  ! -------------------
  ! The QP1_3D element is specified by four polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z }
  !
  ! As the QP1 element is discontinous, the basis polynomials do not have to
  ! fulfill any special conditions - they are simply defined as:
  !
  !  P1 (x,y,z) = 1
  !  P2 (x,y,z) = x
  !  P3 (x,y,z) = y
  !  P4 (x,y,z) = z

  ! Local variables
  real(DP) :: ddet
  integer :: i,j

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i)&
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Evaluate basis functions
          Dbas(1,DER_FUNC3D,i,j) = 1.0_DP
          Dbas(2,DER_FUNC3D,i,j) = reval%p_DpointsRef(1,i,j)
          Dbas(3,DER_FUNC3D,i,j) = reval%p_DpointsRef(2,i,j)
          Dbas(4,DER_FUNC3D,i,j) = reval%p_DpointsRef(3,i,j)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,ddet)&
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)

          ! X-derivatives on real element
          Dbas(1,DER_DERIV3D_X,i,j) = 0.0_DP
          Dbas(2,DER_DERIV3D_X,i,j) = &
              (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j) &
              -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          Dbas(3,DER_DERIV3D_X,i,j) = &
              (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j) &
              -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          Dbas(4,DER_DERIV3D_X,i,j) = &
              (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j) &
              -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet

          ! Y-derivatives on real element
          Dbas(1,DER_DERIV3D_Y,i,j) = 0.0_DP
          Dbas(2,DER_DERIV3D_Y,i,j) = &
              (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j) &
              -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          Dbas(3,DER_DERIV3D_Y,i,j) = &
              (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j) &
              -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(4,DER_DERIV3D_Y,i,j) = &
              (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j) &
              -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet

          ! Z-derivatives on real element
          Dbas(1,DER_DERIV3D_Z,i,j) = 0.0_DP
          Dbas(2,DER_DERIV3D_Z,i,j) = &
              (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j) &
              -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          Dbas(3,DER_DERIV3D_Z,i,j) = &
              (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j) &
              -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          Dbas(4,DER_DERIV3D_Z,i,j) = &
              (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j) &
              -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_QP1NP_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
  !
  ! QP1 element, nonparametric version.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

! </subroutine>

    ! Element Description
    ! -------------------
    ! The QP1_3D element is specified by four polynomials per element.
    !
    ! The basis polynomials are constructed from the following set of monomials:
    ! { 1, x, y, z }
    !
    ! As the QP1 element is discontinous, the basis polynomials do not have to
    ! fulfill any special conditions - they are simply defined as:
    !
    !  P1 (x,y,z) = 1
    !  P2 (x,y,z) = x
    !  P3 (x,y,z) = y
    !  P4 (x,y,z) = z

    ! This element clearly works only with standard quadrilaterals
    integer, parameter :: NVE = 8
    integer, parameter :: NFACES = 6

    ! Local variables
    real(DP) :: ddet
    integer :: i,j,iface
    real(dp) :: CA1,CA2,CA3,CB1,CB2,CB3,CC1,CC2,CC3
    real(DP),dimension(NFACES) :: DXM,DYM,DZM
    real(dp) :: dx,dy,dz
    real(DP),dimension(3,3) :: cg

    ! Ordering of the vertices.
    integer, dimension(4,NFACES), parameter :: IverticesHexa =&
             reshape((/1,2,3,4, 1,5,6,2, 2,6,7,3,&
                       3,7,8,4, 1,4,8,5, 5,8,7,6/), (/4,NFACES/))

    ! Loop through all elements
    !$omp parallel do default(shared)&
    !$omp private(i,iface,DXM,DYM,DZM,CA1,CB1,CC1,CA2,CB2,CC2,CA3,CB3,CC3,&
    !$omp         dx,dy,dz,ddet,cg)&
    !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
    do j = 1, reval%nelements

      ! Loop through all points on the current element
      do i = 1, reval%npointsPerElement

        ! Calculate the face midpoints and length of edges:
        !  DXM(:) := X-coordinates of midpoints
        !  DYM(:) := Y-coordinates of midpoints
        !  DLX(:) := length of each edge in X-direction
        !  DLY(:) := length of each edge in Y-direction
        ! So SQRT(DLX(:)**2+DLY(:)**2) = length of the edges.

        do iface=1,NFACES
          DXM(iface)=0.25_DP*(reval%p_Dcoords(1,IverticesHexa(1,iface),j) &
                             +reval%p_Dcoords(1,IverticesHexa(2,iface),j) &
                             +reval%p_Dcoords(1,IverticesHexa(3,iface),j) &
                             +reval%p_Dcoords(1,IverticesHexa(4,iface),j))
          DYM(iface)=0.25_DP*(reval%p_Dcoords(2,IverticesHexa(1,iface),j) &
                             +reval%p_Dcoords(2,IverticesHexa(2,iface),j) &
                             +reval%p_Dcoords(2,IverticesHexa(3,iface),j) &
                             +reval%p_Dcoords(2,IverticesHexa(4,iface),j))
          DZM(iface)=0.25_DP*(reval%p_Dcoords(3,IverticesHexa(1,iface),j) &
                             +reval%p_Dcoords(3,IverticesHexa(2,iface),j) &
                             +reval%p_Dcoords(3,IverticesHexa(3,iface),j) &
                             +reval%p_Dcoords(3,IverticesHexa(4,iface),j))
        end do

        ! Calculate the vectors realising the local coordinate system.
        !
        ! eta
        CA1 = (DXM(3)-DXM(5))
        CB1 = (DYM(3)-DYM(5))
        CC1 = (DZM(3)-DZM(5))

        ! xi
        CA2 = (DXM(4)-DXM(2))
        CB2 = (DYM(4)-DYM(2))
        CC2 = (DZM(4)-DZM(2))

        ! tau
        CA3 = (DXM(6)-DXM(1))
        CB3 = (DYM(6)-DYM(1))
        CC3 = (DZM(6)-DZM(1))

        ! Our basis functions are as follows:
        !
        ! P1(z1,z2,z3) = a1 + b1*z1 + b2*z2 + b3*z3 = 1
        ! P2(z1,z2,z3) = a1 + b1*z1 + b2*z2 + b3*z3 = z1
        ! P3(z1,z2,z3) = a1 + b1*z1 + b2*z2 + b3*z3 = z2
        !
        ! with (z1,z2) the transformed (x,y) in the new coordinate system.
        ! The Pi are defined on the reference element and a linear
        ! mapping sigma:[0,1]^2->R^2 is used to map all the midpoints
        ! from the reference element to the real element:
        !
        !  sigma(0,0,0) = m
        !  sigma(1,0,0) = m + eta/2
        !  sigma(0,1,0) = m + xi/2
        !  sigma(0,0,1) = m + tau/2
        !
        !         ^                                       ^
        !   +-----X-----+                        +--------m3--------+
        !   |     |     |                       /         |          \
        !   |     |     |       sigma      ___ /          |           \
        ! --X-----+-----X-->   ------->       m4--------__|m____       \
        !   |     |     |                    /             |    --------m2->
        !   |     |     |                   /              |             \
        !   +-----X-----+                  /               |              \
        !         |                       +----_____       |               \
        !                                           -----__m1_              \
        !                                                  |   -----_____    \
        !                                                                -----+
        !
        ! The basis functions on the real element are defined as
        !
        !  Phi_i(x,y) = Pi(sigma^-1(x,y))
        !
        ! Because sigma is linear, we can calculate the inverse by hand.
        ! sigma is given by the formula
        !
        !   sigma(z1,z2) = m + 1/2 (eta1 xi1 tau1) (z1) = m + 1/2 (CA1 CA2 CA3) (z1)
        !                          (eta2 xi2 tau2) (z2)           (CB1 CB2 CB3) (z2)
        !                          (eta2 xi2 tau3) (z3)           (CC1 CC2 CC3) (z3)
        !
        ! so the inverse mapping is
        !
        !  sigma^-1(z1,z2) = [1/2*(CA1 CA2 CA3)]^-1 * (x - xm)
        !                    [    (CB1 CB2 CB3)]      (y - ym)
        !                    [    (CC1 CC2 CC3)]      (z - zm)
        !
        !                  = 2/det * [cg11 cg12 cg13] * (x - xm)
        !                            [cg21 cg22 cg23]   (y - ym)
        !                            [cg31 cg32 cg33]   (z - zm)
        !
        ! with
        !  cg11 = CB2 * CC3 - CB3 * CC2
        !  cg12 = -CA2 * CC3 + CA3 * CC2
        !  cg13 = CA2 * CB3 - CA3 * CB2
        !  cg21 = -CB1 * CC3 + CB3 * CC1
        !  cg22 = CA1 * CC3 - CA3 * CC1
        !  cg23 = -CA1 * CB3 + CA3 * CB1
        !  cg31 = CB1 * CC2 - CB2 * CC1
        !  cg32 = -CA1 * CC2 + CA2 * CC1
        !  cg33 = CA1 * CB2 - CA2 * CB1
        !
        ! and lambda = determinant of the matrix.
        !
        ! So in the first step, calculate (x-xm) and (y-ym).
        dx = (reval%p_DpointsRef(1,i,j)-0.5_DP*(DXM(3)+DXM(5)))
        dy = (reval%p_DpointsRef(2,i,j)-0.5_DP*(DYM(3)+DYM(5)))
        dz = (reval%p_DpointsRef(3,i,j)-0.5_DP*(DZM(3)+DZM(5)))

        ! Calculate the scaled inverse of the determinant of the matrix.
        ddet = 2.0_DP / (CA1 * CB2 * CC3 - CA1 * CB3 * CC2 - CB1 * CA2 * CC3 + &
                         CB1 * CA3 * CC2 + CC1 * CA2 * CB3 - CC1 * CA3 * CB2)

        ! Calculate the coefficients of the inverse matrix.
        cg(1,1) = ddet*(CB2 * CC3 - CB3 * CC2)
        cg(1,2) = ddet*(-CA2 * CC3 + CA3 * CC2)
        cg(1,3) = ddet*(CA2 * CB3 - CA3 * CB2)
        cg(2,1) = ddet*(-CB1 * CC3 + CB3 * CC1)
        cg(2,2) = ddet*(CA1 * CC3 - CA3 * CC1)
        cg(2,3) = ddet*(-CA1 * CB3 + CA3 * CB1)
        cg(3,1) = ddet*(CB1 * CC2 - CB2 * CC1)
        cg(3,2) = ddet*(-CA1 * CC2 + CA2 * CC1)
        cg(3,3) = ddet*(CA1 * CB2 - CA2 * CB1)

        ! Evaluate basis functions: cg * (dx,dy,dz)
        Dbas(1,DER_FUNC3D,i,j) = 1.0_DP
        Dbas(2,DER_FUNC3D,i,j) = cg(1,1)*dx+cg(1,2)*dy+cg(1,3)*dz
        Dbas(3,DER_FUNC3D,i,j) = cg(2,1)*dx+cg(2,2)*dy+cg(2,3)*dz
        Dbas(4,DER_FUNC3D,i,j) = cg(3,1)*dx+cg(3,2)*dy+cg(3,3)*dz

        ! X-derivatives on real element
        Dbas(1,DER_DERIV3D_X,i,j) = 0.0_DP
        Dbas(2,DER_DERIV3D_X,i,j) = cg(1,1)
        Dbas(3,DER_DERIV3D_X,i,j) = cg(2,1)
        Dbas(4,DER_DERIV3D_X,i,j) = cg(3,1)

        ! Y-derivatives on real element
        Dbas(1,DER_DERIV3D_Y,i,j) = 0.0_DP
        Dbas(2,DER_DERIV3D_Y,i,j) = cg(1,2)
        Dbas(3,DER_DERIV3D_Y,i,j) = cg(2,2)
        Dbas(4,DER_DERIV3D_Y,i,j) = cg(3,2)

        ! Z-derivatives on real element
        Dbas(1,DER_DERIV3D_Z,i,j) = 0.0_DP
        Dbas(2,DER_DERIV3D_Z,i,j) = cg(1,3)
        Dbas(3,DER_DERIV3D_Z,i,j) = cg(2,3)
        Dbas(4,DER_DERIV3D_Z,i,j) = cg(3,3)

      end do ! i

    end do ! j
    !$omp end parallel do

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_E030_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! The E030_3D element is specified by six polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x^2 - y^2, y^2 - z^2 }
  !
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,6:
  ! {
  !   For all j = 1,...,6:
  !   {
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))) d(x,y) = kronecker(i,j) * |fj|
  !     <==>
  !     Int_fj Pi(x,y) d(x,y) = kronecker(i,j) * |fj|
  !   }
  ! }
  !
  ! With:
  ! fj being the j-th local face of the hexahedron
  ! |fj| being the area of the face fj
  ! Fj: [-1,1]^2 -> fj being the parametrisation of the face fj
  ! |DFj(x,y)| being the determinant of the Jacobi-Matrix of Fj in the point (x,y)
  !
  ! On the reference element, the above combination of monomial set and
  ! basis polynomial conditions leads to the following basis polynomials:
  !
  !  P1(x,y,z) = 1/6 - 1/2*z - 1/4*(x^2 - y^2) - 1/2*(y^2 - z^2)
  !  P2(x,y,z) = 1/6 - 1/2*y - 1/4*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P3(x,y,z) = 1/6 + 1/2*x + 1/2*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P4(x,y,z) = 1/6 + 1/2*y - 1/4*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P5(x,y,z) = 1/6 - 1/2*x + 1/2*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P6(x,y,z) = 1/6 + 1/2*z - 1/4*(x^2 - y^2) - 1/2*(y^2 - z^2)

  ! Parameter: number of local basis functions
  integer, parameter :: NBAS = 6

  ! derivatives on reference element
  real(DP), dimension(NBAS,NDIM3D) :: DrefDer

  ! Local variables
  real(DP) :: ddet,dx,dy,dz,dxy,dyz
  integer :: i,j

  real(DP), parameter :: Q2 = 0.5_DP
  real(DP), parameter :: Q4 = 0.25_DP
  real(DP), parameter :: Q6 = 1.0_DP / 6.0_DP

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,dx,dy,dz,dxy,dyz) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Pre-calculate (x^2-y^2) and (y^2-z^2)
          dxy = dx*dx - dy*dy
          dyz = dy*dy - dz*dz

          Dbas(1,DER_FUNC3D,i,j) = Q6 - Q4*dxy - Q2*(dz + dyz)
          Dbas(2,DER_FUNC3D,i,j) = Q6 - Q4*(dxy - dyz) - Q2*dy
          Dbas(3,DER_FUNC3D,i,j) = Q6 + Q4*dyz + Q2*(dx + dxy)
          Dbas(4,DER_FUNC3D,i,j) = Q6 - Q4*(dxy - dyz) + Q2*dy
          Dbas(5,DER_FUNC3D,i,j) = Q6 + Q4*dyz - Q2*(dx - dxy)
          Dbas(6,DER_FUNC3D,i,j) = Q6 - Q4*dxy + Q2*(dz - dyz)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,dx,dy,dz,ddet,DrefDer) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Calculate derivatives on reference element
          ! X-derivatives
          DrefDer( 1,1) = -Q2*dx
          DrefDer( 2,1) = -Q2*dx
          DrefDer( 3,1) = dx + Q2
          DrefDer( 4,1) = -Q2*dx
          DrefDer( 5,1) = dx - Q2
          DrefDer( 6,1) = -Q2*dx

          ! Y-derivatives
          DrefDer( 1,2) = -Q2*dy
          DrefDer( 2,2) = dy - Q2
          DrefDer( 3,2) = -Q2*dy
          DrefDer( 4,2) = dy + Q2
          DrefDer( 5,2) = -Q2*dy
          DrefDer( 6,2) = -Q2*dy

          ! Z-derivatives
          DrefDer( 1,3) = dz - Q2
          DrefDer( 2,3) = -Q2*dz
          DrefDer( 3,3) = -Q2*dz
          DrefDer( 4,3) = -Q2*dz
          DrefDer( 5,3) = -Q2*dz
          DrefDer( 6,3) = dz + Q2

          ! Remark: Please note that the following code is universal and does
          ! not need to be modified for other parametric 3D hexahedron elements!

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)

          ! X-derivatives on real element
          dx = (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          dy = (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          dz = (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_X,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Y-derivatives on real element
          dx = (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          dy = (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          dz = (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Y,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Z-derivatives on real element
          dx = (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          dy = (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          dz = (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Z,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_EB30_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! The EB30_3D element is specified by ten polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x*y, x*z, y*z, x*y*z, x^2 - y^2, y^2 - z^2 }
  !
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,10:
  ! {
  !   For all j = 1,...,6:
  !   {
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))) d(x,y) = kronecker(i,j) * |fj|
  !     <==>
  !     Int_fj Pi(x,y) d(x,y) = kronecker(i,j) * |fj|
  !   }
  !   For all j = 1,...,4:
  !   {
  !     Int_T Pi(x,y,z)*Lj(x,y,z) = kronecker(i,6+j) * |T|
  !   }
  ! }
  !
  ! With:
  ! fj being the j-th local face of the hexahedron
  ! |fj| being the area of the face fj
  ! Fj: [-1,1]^2 -> fj being the parametrisation of the face fj
  ! |DFj(x,y)| being the determinant of the Jacobi-Matrix of Fj in the point (x,y)
  ! T being the reference hexahedron
  ! Lj being the following set of Legendre-Polynomials:
  !   L1(x,y,z) = x*y
  !   L2(x,y,z) = x*z
  !   L3(x,y,z) = y*z
  !   L4(x,y,z) = x*y*z
  !
  ! On the reference element, the above combination of monomial set and
  ! basis polynomial conditions leads to the following basis polynomials:
  !
  !  P1(x,y,z) = 1/6 - 1/2*z - 1/4*(x^2 - y^2) - 1/2*(y^2 - z^2)
  !  P2(x,y,z) = 1/6 - 1/2*y - 1/4*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P3(x,y,z) = 1/6 + 1/2*x + 1/2*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P4(x,y,z) = 1/6 + 1/2*y - 1/4*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P5(x,y,z) = 1/6 - 1/2*x + 1/2*(x^2 - y^2) + 1/4*(y^2 - z^2)
  !  P6(x,y,z) = 1/6 + 1/2*z - 1/4*(x^2 - y^2) - 1/2*(y^2 - z^2)
  !  P7(x,y,z) = 9*x*y
  !  P8(x,y,z) = 9*x*z
  !  P9(x,y,z) = 9*y*z
  !  P10(x,y,z) = 27*x*y*z

  ! Parameter: number of local basis functions
  integer, parameter :: NBAS = 10

  ! derivatives on reference element
  real(DP), dimension(NBAS,NDIM3D) :: DrefDer

  ! Local variables
  real(DP) :: ddet,dx,dy,dz,dxy,dyz
  integer :: i,j

  real(DP), parameter :: Q2 = 0.5_DP
  real(DP), parameter :: Q4 = 0.25_DP
  real(DP), parameter :: Q6 = 1.0_DP / 6.0_DP

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,dx,dy,dz,dxy,dyz) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Pre-calculate (x^2-y^2) and (y^2-z^2)
          dxy = dx*dx - dy*dy
          dyz = dy*dy - dz*dz

          Dbas(1,DER_FUNC3D,i,j) = Q6 - Q4*dxy - Q2*(dz + dyz)
          Dbas(2,DER_FUNC3D,i,j) = Q6 - Q4*(dxy - dyz) - Q2*dy
          Dbas(3,DER_FUNC3D,i,j) = Q6 + Q4*dyz + Q2*(dx + dxy)
          Dbas(4,DER_FUNC3D,i,j) = Q6 - Q4*(dxy - dyz) + Q2*dy
          Dbas(5,DER_FUNC3D,i,j) = Q6 + Q4*dyz - Q2*(dx - dxy)
          Dbas(6,DER_FUNC3D,i,j) = Q6 - Q4*dxy + Q2*(dz - dyz)
          Dbas(7,DER_FUNC3D,i,j) = 9.0_DP*dx*dy
          Dbas(8,DER_FUNC3D,i,j) = 9.0_DP*dx*dz
          Dbas(9,DER_FUNC3D,i,j) = 9.0_DP*dy*dz
          Dbas(10,DER_FUNC3D,i,j) = 27.0_DP*dx*dy*dz

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

      ! Loop through all elements
      !$omp parallel do default(shared) private(i,dx,dy,dz,ddet,DrefDer) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Calculate derivatives on reference element
          ! X-derivatives
          DrefDer( 1,1) = -Q2*dx
          DrefDer( 2,1) = -Q2*dx
          DrefDer( 3,1) = dx + Q2
          DrefDer( 4,1) = -Q2*dx
          DrefDer( 5,1) = dx - Q2
          DrefDer( 6,1) = -Q2*dx
          DrefDer( 7,1) = 9.0_DP*dy
          DrefDer( 8,1) = 9.0_DP*dz
          DrefDer( 9,1) = 0.0_DP
          DrefDer(10,1) = 27.0_DP*dy*dz

          ! Y-derivatives
          DrefDer( 1,2) = -Q2*dy
          DrefDer( 2,2) = dy - Q2
          DrefDer( 3,2) = -Q2*dy
          DrefDer( 4,2) = dy + Q2
          DrefDer( 5,2) = -Q2*dy
          DrefDer( 6,2) = -Q2*dy
          DrefDer( 7,2) = 9.0_DP*dx
          DrefDer( 8,2) = 0.0_DP
          DrefDer( 9,2) = 9.0_DP*dz
          DrefDer(10,2) = 27.0_DP*dx*dz

          ! Z-derivatives
          DrefDer( 1,3) = dz - Q2
          DrefDer( 2,3) = -Q2*dz
          DrefDer( 3,3) = -Q2*dz
          DrefDer( 4,3) = -Q2*dz
          DrefDer( 5,3) = -Q2*dz
          DrefDer( 6,3) = dz + Q2
          DrefDer( 7,3) = 0.0_DP
          DrefDer( 8,3) = 9.0_DP*dx
          DrefDer( 9,3) = 9.0_DP*dy
          DrefDer(10,3) = 27.0_DP*dx*dy

          ! Remark: Please note that the following code is universal and does
          ! not need to be modified for other parametric 3D hexahedron elements!

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)

          ! X-derivatives on real element
          dx = (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          dy = (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          dz = (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_X,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Y-derivatives on real element
          dx = (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          dy = (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          dz = (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Y,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Z-derivatives on real element
          dx = (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          dy = (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          dz = (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Z,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_EM30_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! It is recommended that you have read (and understood) the documentation
  ! of the 2D EM30 element as this documentation of the 3D EM30 is quite
  ! similar, although not as detailed and without that fancy ASCII-art...
  !
  ! The standard integral-based Q1~-element has the following six local
  ! basis functions:
  !
  !  p_1(x,y,z) = a1 + b1*x + c1*y + d1*z + e1*(x^2 - y^2) + f1*(y^2 - z^2)
  !  p_2(x,y,z) = a2 + b2*x + c2*y + d2*z + e2*(x^2 - y^2) + f2*(y^2 - z^2)
  !  p_3(x,y,z) = a3 + b3*x + c3*y + d3*z + e3*(x^2 - y^2) + f3*(y^2 - z^2)
  !  p_4(x,y,z) = a4 + b4*x + c4*y + d4*z + e4*(x^2 - y^2) + f4*(y^2 - z^2)
  !  p_5(x,y,z) = a5 + b5*x + c5*y + d5*z + e5*(x^2 - y^2) + f5*(y^2 - z^2)
  !  p_6(x,y,z) = a6 + b6*x + c6*y + d6*z + e6*(x^2 - y^2) + f6*(y^2 - z^2)
  !
  ! each of them designed in such a way, such that
  !
  !      1/|Xi| int_Xi p_j(x,y,z) d(x,y,z) = delta_ij
  !
  ! with Xi being the i-th local face of a hexahedron.
  !
  ! We will now use linear mapping between the face midpoints of our
  ! reference hexahedron [-1,1]^3 and the real hexahedron. So our
  ! mapping t:[-1,1]^3 -> R^3 will have the following form:
  !
  !   / X \                / t11 t12 t13 \   / x \                .
  !   | Y | := t(x,y,z) := | t21 t22 t23 | * | y |                .
  !   \ Z /                \ t31 t32 t33 /   \ z /                .
  !
  ! This mapping should fulfill:
  !
  !   / eta_1 \   / t11 t12 t13 \   / 1 \                         .
  !   | eta_2 | = | t21 t22 t23 | * | 0 |                       (1)
  !   \ eta_3 /   \ t31 t32 t33 /   \ 0 /                         .
  !
  !   / xi_1 \    / t11 t12 t13 \   / 0 \                         .
  !   | xi_2 |  = | t21 t22 t23 | * | 1 |                       (2)
  !   \ xi_3 /    \ t31 t32 t33 /   \ 0 /                         .
  !
  !   / rho_1 \   / t11 t12 t13 \   / 0 \                         .
  !   | rho_2 | = | t21 t22 t23 | * | 0 |                       (3)
  !   \ rho_3 /   \ t31 t32 t33 /   \ 1 /                         .
  !
  ! where eta is the vector from the hexahedron midpoint to the midpoint of
  ! the third face, xi being the vector from the hexahedron midpoint to the
  ! midpoint of the sixth face and rho being the vector from the hexahedron
  ! midpoint to the midpoint of the second face.
  ! Note: Check the 2D EM30 documentation for an ASCII-art.
  !
  ! The linear system given by the equations (1),(2) and (3) can easily
  ! be solved to calculate the unknown transformation coefficients tXY:
  !
  !   / X \                / eta_1 xi_1 rho_1 \   / x \                 .
  !   | Y | := t(x,y,z) := | eta_2 xi_2 rho_2 | * | y |                 .
  !   \ Z /                \ eta_3 xi_3 rho_3 /   \ z /                 .
  !
  ! Then, we set up the local basis functions in terms of xi, eta and rho,
  ! i.e. in the coordinate space of the new coordinate system,
  ! with a new set of (unknown) coefficents ai, bi, etc::
  !
  !  P1(X,Y,Z) = a1 + b1*X + c1*Y + d1*Z + e1*(X^2 - Y^2) + f1*(Y^2 - Z^2)
  !  P2(X,Y,Z) = a2 + b2*X + c2*Y + d2*Z + e2*(X^2 - Y^2) + f2*(Y^2 - Z^2)
  !  P3(X,Y,Z) = a3 + b3*X + c3*Y + d3*Z + e3*(X^2 - Y^2) + f3*(Y^2 - Z^2)
  !  P4(X,Y,Z) = a4 + b4*X + c4*Y + d4*Z + e4*(X^2 - Y^2) + f4*(Y^2 - Z^2)
  !  P5(X,Y,Z) = a5 + b5*X + c5*Y + d5*Z + e5*(X^2 - Y^2) + f5*(Y^2 - Z^2)
  !  P6(X,Y,Z) = a6 + b6*X + c6*Y + d6*Z + e6*(X^2 - Y^2) + f6*(Y^2 - Z^2)
  !
  ! Later, we want to evaluate these Pi. Each Pi consists of a linear
  ! combination of some coefficients ai, bi, etc. with the six monoms:
  !
  !  M1(X,Y,Z) := 1
  !  M2(X,Y,Z) := X
  !  M3(X,Y,Z) := Y
  !  M4(X,Y,Z) := Z
  !  M5(X,Y,Z) := X^2 - Y^2
  !  M6(X,Y,Z) := Y^2 - Z^2
  !
  ! To evaluate these Mi`s in the new coordinate system, we concatenate them
  ! with the mapping t(.,.,.). As result, we get the six functions Fi,
  ! which are defined as functions at the bottom of this routine:
  !
  !  F1(x,y,z) := M1(t(x,y,z)) = 1
  !  F2(x,y,z) := M2(t(x,y,z)) = eta_1*x + xi_1*y + rho_1*z
  !  F3(x,y,z) := M3(t(x,y,z)) = eta_2*x + xi_2*y + rho_2*z
  !  F4(x,y,z) := M4(t(x,y,z)) = eta_3*x + xi_3*y + rho_3*z
  !
  !  F5(x,y,z) := M5(t(x,y,z)) =   (eta_1*x + xi_1*y + rho_1*z)^2
  !                              - (eta_2*x + xi_2*y + rho_2*z)^2
  !                            =   (eta_1^2 - eta_2^2) * x^2
  !                              + (xi_1^2  - xi_2^2 ) * y^2
  !                              + (rho1_^2 - rho_2^2) * z^2
  !                              + 2*(eta_1*xi_1  - eta_2*xi_2 ) * x*y
  !                              + 2*(eta_1*rho_1 - eta_2*rho_2) * x*z
  !                              + 2*( xi_1*rho_1 -  xi_2*rho_2) * y*z
  !
  !  F6(x,y,z) := M6(t(x,y,z)) =   (eta_2*x + xi_2*y + rho_2*z)^2
  !                              - (eta_3*x + xi_3*y + rho_3*z)^2
  !                            =   (eta_2^2 - eta_3^2) * x^2
  !                              + (xi_2^2  - xi_3^2 ) * y^2
  !                              + (rho1_^2 - rho_3^2) * z^2
  !                              + 2*(eta_2*xi_2  - eta_3*xi_3 ) * x*y
  !                              + 2*(eta_2*rho_2 - eta_3*rho_3) * x*z
  !                              + 2*( xi_2*rho_2 -  xi_3*rho_3) * y*z
  !
  ! So the polynomials have now the form:
  !
  !  Pi(t(x,y,z)) = ai*F1(x,y,z) + bi*F2(x,y,z) + ci*F3(x,y,z)
  !               + di*F4(x,y,z) + ei*F5(x,y,z) + fi*F6(x,y,z)
  !
  ! It does not matter whether the local coordinate system starts in (0,0,0) or in
  ! the midpoint of the element or whereever. As the rotation of the element
  ! coincides with the rotation of the new coordinate system, the polynomial
  ! space is unisolvent and therefore exist the above local basis functions uniquely.
  !
  ! The coefficients ai, bi, ci, di are to be calculated in such a way, that
  !
  !    1/|Xi| int_Xi Pj(t(x,y,z)) d(x,y,z) = delta_ij
  !
  ! holds. The integral "1/|Xi| int_Xi ... d(x,y,z)" over the face Xi is approximated
  ! by a cubature formula with 8 points.
  ! This gives us six 6x6 systems for the computation of ai, bi, etc.
  ! The system matix A is given as A = {a_ij}, where
  !             a_ij := 1/|Xi| int_Xi Pj(t(x,y,z)) d(x,y,z)
  !
  ! Once the system matrix is inverted, the A^-1 will hold the coefficients
  ! ai, bi, etc. which define the basis polynomials Pi with the desired property.
  
  ! local parameters
  real(DP), parameter :: Q1 =   0.25_DP
  real(DP), parameter :: Q2 =   1.0_DP /   3.0_DP
  real(DP), parameter :: Q3 =   0.2_DP
  real(DP), parameter :: Q4 =   0.6_DP
  real(DP), parameter :: Q8 =  -9.0_DP /  16.0_DP
  real(DP), parameter :: Q9 = 100.0_DP / 192.0_DP

  ! local variables
  real(DP), dimension(3,8) :: P                       ! cubature points
  real(DP) :: PP1,PP2,PP3,PP4,PP5,PS1,PS2,PQ1,PQ2,PQ3 ! cubature weights
  real(DP), dimension(6,6) :: A, B                    ! coefficient matrices
  real(DP) :: CA1,CA2,CA3,CB1,CB2,CB3,CC1,&           ! auxiliary coefficients
              CC2,CC3,CD1,CD2,CD3,CD4,CD5,&
              CD6,CE1,CE2,CE3,CE4,CE5,CE6
  real(DP), dimension(6,10) :: COB                    ! monomial coefficients
  real(DP), dimension(3,4,6) :: V                     ! face corner vertices
  real(DP), dimension(2:6,8) :: F                     ! transformed monomials
  real(DP) :: dx,dy,dz
  integer :: i,j,k,l
  logical :: bsuccess

    ! Loop through all elements
    !$omp parallel do default(shared)&
    !$omp private(P,PP1,PP2,PP3,PP4,PP5,PS1,PS2,PQ1,PQ2,PQ3,A,B,&
    !$omp         CA1,CA2,CA3,CB1,CB2,CB3,CC1,CC2,CC3,CD1,CD2,CD3,&
    !$omp         CD4,CD5,CD6,CE1,CE2,CE3,CE4,CE5,CE6,COB,V,F,&
    !$omp         dx,dy,dz,i,k,l,bsuccess)&
    !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
    do j = 1, reval%nelements

      ! Initialise the vertex-coordinates
      V(1:3,1,1) = reval%p_Dcoords(1:3,1,j)
      V(1:3,2,1) = reval%p_Dcoords(1:3,2,j)
      V(1:3,3,1) = reval%p_Dcoords(1:3,3,j)
      V(1:3,4,1) = reval%p_Dcoords(1:3,4,j)
      V(1:3,1,2) = reval%p_Dcoords(1:3,1,j)
      V(1:3,2,2) = reval%p_Dcoords(1:3,2,j)
      V(1:3,3,2) = reval%p_Dcoords(1:3,6,j)
      V(1:3,4,2) = reval%p_Dcoords(1:3,5,j)
      V(1:3,1,3) = reval%p_Dcoords(1:3,2,j)
      V(1:3,2,3) = reval%p_Dcoords(1:3,3,j)
      V(1:3,3,3) = reval%p_Dcoords(1:3,7,j)
      V(1:3,4,3) = reval%p_Dcoords(1:3,6,j)
      V(1:3,1,4) = reval%p_Dcoords(1:3,3,j)
      V(1:3,2,4) = reval%p_Dcoords(1:3,4,j)
      V(1:3,3,4) = reval%p_Dcoords(1:3,8,j)
      V(1:3,4,4) = reval%p_Dcoords(1:3,7,j)
      V(1:3,1,5) = reval%p_Dcoords(1:3,4,j)
      V(1:3,2,5) = reval%p_Dcoords(1:3,1,j)
      V(1:3,3,5) = reval%p_Dcoords(1:3,5,j)
      V(1:3,4,5) = reval%p_Dcoords(1:3,8,j)
      V(1:3,1,6) = reval%p_Dcoords(1:3,5,j)
      V(1:3,2,6) = reval%p_Dcoords(1:3,6,j)
      V(1:3,3,6) = reval%p_Dcoords(1:3,7,j)
      V(1:3,4,6) = reval%p_Dcoords(1:3,8,j)

      ! Calculate the coefficients of the Fi
      CA1 = Q1*((reval%p_Dcoords(1,1,j)+reval%p_Dcoords(1,2,j)+ &
                 reval%p_Dcoords(1,3,j)+reval%p_Dcoords(1,4,j)) &
               -(reval%p_Dcoords(1,5,j)+reval%p_Dcoords(1,6,j)+ &
                 reval%p_Dcoords(1,7,j)+reval%p_Dcoords(1,8,j)))
      CB1 = Q1*((reval%p_Dcoords(2,1,j)+reval%p_Dcoords(2,2,j)+ &
                 reval%p_Dcoords(2,3,j)+reval%p_Dcoords(2,4,j)) &
               -(reval%p_Dcoords(2,5,j)+reval%p_Dcoords(2,6,j)+ &
                 reval%p_Dcoords(2,7,j)+reval%p_Dcoords(2,8,j)))
      CC1 = Q1*((reval%p_Dcoords(3,1,j)+reval%p_Dcoords(3,2,j)+ &
                 reval%p_Dcoords(3,3,j)+reval%p_Dcoords(3,4,j)) &
               -(reval%p_Dcoords(3,5,j)+reval%p_Dcoords(3,6,j)+ &
                 reval%p_Dcoords(3,7,j)+reval%p_Dcoords(3,8,j)))
      CA2 = Q1*((reval%p_Dcoords(1,1,j)+reval%p_Dcoords(1,2,j)+ &
                 reval%p_Dcoords(1,6,j)+reval%p_Dcoords(1,5,j)) &
               -(reval%p_Dcoords(1,3,j)+reval%p_Dcoords(1,7,j)+ &
                 reval%p_Dcoords(1,8,j)+reval%p_Dcoords(1,4,j)))
      CB2 = Q1*((reval%p_Dcoords(2,1,j)+reval%p_Dcoords(2,2,j)+ &
                 reval%p_Dcoords(2,6,j)+reval%p_Dcoords(2,5,j)) &
               -(reval%p_Dcoords(2,3,j)+reval%p_Dcoords(2,7,j)+ &
                 reval%p_Dcoords(2,8,j)+reval%p_Dcoords(2,4,j)))
      CC2 = Q1*((reval%p_Dcoords(3,1,j)+reval%p_Dcoords(3,2,j)+ &
                 reval%p_Dcoords(3,6,j)+reval%p_Dcoords(3,5,j)) &
               -(reval%p_Dcoords(3,3,j)+reval%p_Dcoords(3,7,j)+ &
                 reval%p_Dcoords(3,8,j)+reval%p_Dcoords(3,4,j)))
      CA3 = Q1*((reval%p_Dcoords(1,2,j)+reval%p_Dcoords(1,3,j)+ &
                 reval%p_Dcoords(1,7,j)+reval%p_Dcoords(1,6,j)) &
               -(reval%p_Dcoords(1,1,j)+reval%p_Dcoords(1,4,j)+ &
                 reval%p_Dcoords(1,8,j)+reval%p_Dcoords(1,5,j)))
      CB3 = Q1*((reval%p_Dcoords(2,2,j)+reval%p_Dcoords(2,3,j)+ &
                 reval%p_Dcoords(2,7,j)+reval%p_Dcoords(2,6,j)) &
               -(reval%p_Dcoords(2,1,j)+reval%p_Dcoords(2,4,j)+ &
                 reval%p_Dcoords(2,8,j)+reval%p_Dcoords(2,5,j)))
      CC3 = Q1*((reval%p_Dcoords(3,2,j)+reval%p_Dcoords(3,3,j)+ &
                 reval%p_Dcoords(3,7,j)+reval%p_Dcoords(3,6,j)) &
               -(reval%p_Dcoords(3,1,j)+reval%p_Dcoords(3,4,j)+ &
                 reval%p_Dcoords(3,8,j)+reval%p_Dcoords(3,5,j)))
      CD1 = CA1**2 - CA2**2
      CD2 = CB1**2 - CB2**2
      CD3 = CC1**2 - CC2**2
      CD4 = 2.0_DP*(CA1*CB1 - CA2*CB2)
      CD5 = 2.0_DP*(CA1*CC1 - CA2*CC2)
      CD6 = 2.0_DP*(CB1*CC1 - CB2*CC2)
      CE1 = CA2**2 - CA3**2
      CE2 = CB2**2 - CB3**2
      CE3 = CC2**2 - CC3**2
      CE4 = 2.0_DP*(CA2*CB2 - CA3*CB3)
      CE5 = 2.0_DP*(CA2*CC2 - CA3*CC3)
      CE6 = 2.0_DP*(CB2*CC2 - CB3*CC3)
      
      do k=1,6
        ! Calculate the eight cubature points
        P(1,1)=Q2*(V(1,1,k)+V(1,2,k)+V(1,3,k))
        P(2,1)=Q2*(V(2,1,k)+V(2,2,k)+V(2,3,k))
        P(3,1)=Q2*(V(3,1,k)+V(3,2,k)+V(3,3,k))
        P(1,2)=Q4*V(1,1,k)+Q3*V(1,2,k)+Q3*V(1,3,k)
        P(2,2)=Q4*V(2,1,k)+Q3*V(2,2,k)+Q3*V(2,3,k)
        P(3,2)=Q4*V(3,1,k)+Q3*V(3,2,k)+Q3*V(3,3,k)
        P(1,3)=Q3*V(1,1,k)+Q4*V(1,2,k)+Q3*V(1,3,k)
        P(2,3)=Q3*V(2,1,k)+Q4*V(2,2,k)+Q3*V(2,3,k)
        P(3,3)=Q3*V(3,1,k)+Q4*V(3,2,k)+Q3*V(3,3,k)
        P(1,4)=Q3*V(1,1,k)+Q3*V(1,2,k)+Q4*V(1,3,k)
        P(2,4)=Q3*V(2,1,k)+Q3*V(2,2,k)+Q4*V(2,3,k)
        P(3,4)=Q3*V(3,1,k)+Q3*V(3,2,k)+Q4*V(3,3,k)
        P(1,5)=Q2*(V(1,1,k)+V(1,3,k)+V(1,4,k))
        P(2,5)=Q2*(V(2,1,k)+V(2,3,k)+V(2,4,k))
        P(3,5)=Q2*(V(3,1,k)+V(3,3,k)+V(3,4,k))
        P(1,6)=Q4*V(1,1,k)+Q3*V(1,3,k)+Q3*V(1,4,k)
        P(2,6)=Q4*V(2,1,k)+Q3*V(2,3,k)+Q3*V(2,4,k)
        P(3,6)=Q4*V(3,1,k)+Q3*V(3,3,k)+Q3*V(3,4,k)
        P(1,7)=Q3*V(1,1,k)+Q4*V(1,3,k)+Q3*V(1,4,k)
        P(2,7)=Q3*V(2,1,k)+Q4*V(2,3,k)+Q3*V(2,4,k)
        P(3,7)=Q3*V(3,1,k)+Q4*V(3,3,k)+Q3*V(3,4,k)
        P(1,8)=Q3*V(1,1,k)+Q3*V(1,3,k)+Q4*V(1,4,k)
        P(2,8)=Q3*V(2,1,k)+Q3*V(2,3,k)+Q4*V(2,4,k)
        P(3,8)=Q3*V(3,1,k)+Q3*V(3,3,k)+Q4*V(3,4,k)

        ! And calculate the weights for the cubature formula
        PP1=sqrt((V(1,1,k)-V(1,2,k))**2+(V(2,1,k)-V(2,2,k))**2+&
                 (V(3,1,k)-V(3,2,k))**2)
        PP2=sqrt((V(1,2,k)-V(1,3,k))**2+(V(2,2,k)-V(2,3,k))**2+&
                 (V(3,2,k)-V(3,3,k))**2)
        PP3=sqrt((V(1,1,k)-V(1,3,k))**2+(V(2,1,k)-V(2,3,k))**2+&
                 (V(3,1,k)-V(3,3,k))**2)
        PP4=sqrt((V(1,3,k)-V(1,4,k))**2+(V(2,3,k)-V(2,4,k))**2+&
                 (V(3,3,k)-V(3,4,k))**2)
        PP5=sqrt((V(1,1,k)-V(1,4,k))**2+(V(2,1,k)-V(2,4,k))**2+&
                 (V(3,1,k)-V(3,4,k))**2)
        PS1=(PP1+PP2+PP3)*0.5_DP
        PS2=(PP3+PP4+PP5)*0.5_DP
        PQ1=sqrt(PS1*(PS1-PP1)*(PS1-PP2)*(PS1-PP3))
        PQ2=sqrt(PS2*(PS2-PP3)*(PS2-PP4)*(PS2-PP5))
        PQ3=1.0_DP / (PQ1 + PQ2)

        ! Evalute the F2..F6 in the eight cubature points
        ! Remember: F1 = 1
        do l=1,8
          F(2,l) = CA1*P(1,l) + CB1*P(2,l) + CC1*P(3,l)
          F(3,l) = CA2*P(1,l) + CB2*P(2,l) + CC2*P(3,l)
          F(4,l) = CA3*P(1,l) + CB3*P(2,l) + CC3*P(3,l)
          F(5,l) = CD1*P(1,l)**2 + CD2*P(2,l)**2 + CD3*P(3,l)**2 &
                 + CD4*P(1,l)*P(2,l) + CD5*P(1,l)*P(3,l) + CD6*P(2,l)*P(3,l)
          F(6,l) = CE1*P(1,l)**2 + CE2*P(2,l)**2 + CE3*P(3,l)**2 &
                 + CE4*P(1,l)*P(2,l) + CE5*P(1,l)*P(3,l) + CE6*P(2,l)*P(3,l)
        end do
        
        ! Build up the matrix entries
        A(k,1)= 1.0_DP
        do l=2,6
          A(k,l) = PQ3*(PQ1*(Q8*F(l,1)+Q9*(F(l,2)+F(l,3)+F(l,4))) &
                       +PQ2*(Q8*F(l,5)+Q9*(F(l,6)+F(l,7)+F(l,8))))
        end do
        
      end do

      ! Now we have the coeffienct matrix - so invert it
      call mprim_invert6x6MatrixDirect(A,B,bsuccess)
      
      ! Transform coefficiencts into monomial base
      do k=1,6
        COB(k,1) = B(6,k)*CE1 + B(5,k)*CD1
        COB(k,2) = B(6,k)*CE2 + B(5,k)*CD2
        COB(k,3) = B(6,k)*CE3 + B(5,k)*CD3
        COB(k,4) = B(6,k)*CE4 + B(5,k)*CD4
        COB(k,5) = B(6,k)*CE5 + B(5,k)*CD5
        COB(k,6) = B(6,k)*CE6 + B(5,k)*CD6
        COB(k,7) = B(4,k)*CA3 + B(3,k)*CA2 + B(2,k)*CA1
        COB(k,8) = B(4,k)*CB3 + B(3,k)*CB2 + B(2,k)*CB1
        COB(k,9) = B(4,k)*CC3 + B(3,k)*CC2 + B(2,k)*CC1
        COB(k,10)= B(1,k)
      end do
      
      ! Calculate function values?
      if(Bder(DER_FUNC3D)) then

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsReal(1,i,j)
          dy = reval%p_DpointsReal(2,i,j)
          dz = reval%p_DpointsReal(3,i,j)

          Dbas(1,DER_FUNC3D,i,j)= COB(1,1)*dx**2+COB(1,2)*dy**2+COB(1,3)*dz**2&
                  +COB(1,4)*dx*dy+COB(1,5)*dx*dz+COB(1,6)*dy*dz&
                  +COB(1,7)*dx+COB(1,8)*dy+COB(1,9)*dz+COB(1,10)
          Dbas(2,DER_FUNC3D,i,j)= COB(2,1)*dx**2+COB(2,2)*dy**2+COB(2,3)*dz**2&
                  +COB(2,4)*dx*dy+COB(2,5)*dx*dz+COB(2,6)*dy*dz&
                  +COB(2,7)*dx+COB(2,8)*dy+COB(2,9)*dz+COB(2,10)
          Dbas(3,DER_FUNC3D,i,j)= COB(3,1)*dx**2+COB(3,2)*dy**2+COB(3,3)*dz**2&
                  +COB(3,4)*dx*dy+COB(3,5)*dx*dz+COB(3,6)*dy*dz&
                  +COB(3,7)*dx+COB(3,8)*dy+COB(3,9)*dz+COB(3,10)
          Dbas(4,DER_FUNC3D,i,j)= COB(4,1)*dx**2+COB(4,2)*dy**2+COB(4,3)*dz**2&
                  +COB(4,4)*dx*dy+COB(4,5)*dx*dz+COB(4,6)*dy*dz&
                  +COB(4,7)*dx+COB(4,8)*dy+COB(4,9)*dz+COB(4,10)
          Dbas(5,DER_FUNC3D,i,j)= COB(5,1)*dx**2+COB(5,2)*dy**2+COB(5,3)*dz**2&
                  +COB(5,4)*dx*dy+COB(5,5)*dx*dz+COB(5,6)*dy*dz&
                  +COB(5,7)*dx+COB(5,8)*dy+COB(5,9)*dz+COB(5,10)
          Dbas(6,DER_FUNC3D,i,j)= COB(6,1)*dx**2+COB(6,2)*dy**2+COB(6,3)*dz**2&
                  +COB(6,4)*dx*dy+COB(6,5)*dx*dz+COB(6,6)*dy*dz&
                  +COB(6,7)*dx+COB(6,8)*dy+COB(6,9)*dz+COB(6,10)

        end do ! i
      end if

      ! X-derivatives
      if(BDER(DER_DERIV3D_X)) then

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsReal(1,i,j)
          dy = reval%p_DpointsReal(2,i,j)
          dz = reval%p_DpointsReal(3,i,j)

          Dbas(1,DER_DERIV3D_X,i,j)=2.0_DP*COB(1,1)*dx+COB(1,4)*dy+COB(1,5)*dz+COB(1,7)
          Dbas(2,DER_DERIV3D_X,i,j)=2.0_DP*COB(2,1)*dx+COB(2,4)*dy+COB(2,5)*dz+COB(2,7)
          Dbas(3,DER_DERIV3D_X,i,j)=2.0_DP*COB(3,1)*dx+COB(3,4)*dy+COB(3,5)*dz+COB(3,7)
          Dbas(4,DER_DERIV3D_X,i,j)=2.0_DP*COB(4,1)*dx+COB(4,4)*dy+COB(4,5)*dz+COB(4,7)
          Dbas(5,DER_DERIV3D_X,i,j)=2.0_DP*COB(5,1)*dx+COB(5,4)*dy+COB(5,5)*dz+COB(5,7)
          Dbas(6,DER_DERIV3D_X,i,j)=2.0_DP*COB(6,1)*dx+COB(6,4)*dy+COB(6,5)*dz+COB(6,7)
        end do
      end if
      
      ! Y-derivatives
      if(BDER(DER_DERIV3D_Y)) then

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsReal(1,i,j)
          dy = reval%p_DpointsReal(2,i,j)
          dz = reval%p_DpointsReal(3,i,j)
          
          Dbas(1,DER_DERIV3D_Y,i,j)=2.0_DP*COB(1,2)*dy+COB(1,4)*dx+COB(1,6)*dz+COB(1,8)
          Dbas(2,DER_DERIV3D_Y,i,j)=2.0_DP*COB(2,2)*dy+COB(2,4)*dx+COB(2,6)*dz+COB(2,8)
          Dbas(3,DER_DERIV3D_Y,i,j)=2.0_DP*COB(3,2)*dy+COB(3,4)*dx+COB(3,6)*dz+COB(3,8)
          Dbas(4,DER_DERIV3D_Y,i,j)=2.0_DP*COB(4,2)*dy+COB(4,4)*dx+COB(4,6)*dz+COB(4,8)
          Dbas(5,DER_DERIV3D_Y,i,j)=2.0_DP*COB(5,2)*dy+COB(5,4)*dx+COB(5,6)*dz+COB(5,8)
          Dbas(6,DER_DERIV3D_Y,i,j)=2.0_DP*COB(6,2)*dy+COB(6,4)*dx+COB(6,6)*dz+COB(6,8)
        end do
      end if
      
      ! Z-derivatives
      if(BDER(DER_DERIV3D_Z)) then
        
        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsReal(1,i,j)
          dy = reval%p_DpointsReal(2,i,j)
          dz = reval%p_DpointsReal(3,i,j)

          Dbas(1,DER_DERIV3D_Z,i,j)=2.0_DP*COB(1,3)*dz+COB(1,5)*dx+COB(1,6)*dy+COB(1,9)
          Dbas(2,DER_DERIV3D_Z,i,j)=2.0_DP*COB(2,3)*dz+COB(2,5)*dx+COB(2,6)*dy+COB(2,9)
          Dbas(3,DER_DERIV3D_Z,i,j)=2.0_DP*COB(3,3)*dz+COB(3,5)*dx+COB(3,6)*dy+COB(3,9)
          Dbas(4,DER_DERIV3D_Z,i,j)=2.0_DP*COB(4,3)*dz+COB(4,5)*dx+COB(4,6)*dy+COB(4,9)
          Dbas(5,DER_DERIV3D_Z,i,j)=2.0_DP*COB(5,3)*dz+COB(5,5)*dx+COB(5,6)*dy+COB(5,9)
          Dbas(6,DER_DERIV3D_Z,i,j)=2.0_DP*COB(6,3)*dz+COB(6,5)*dx+COB(6,6)*dy+COB(6,9)
        end do
      end if

    end do ! j
    !$omp end parallel do

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_E031_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! The E031_3D element is specified by six polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x^2 - y^2, y^2 - z^2 }
  !
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,6:
  ! {
  !   For all j = 1,...,6:
  !   {
  !     Pi(fj) = kronecker(i,j)
  !   }
  ! }
  !
  ! With:
  ! fj being the midpoint of the j-th local face of the hexahedron
  !
  ! On the reference element, the above combination of monomial set and
  ! basis polynomial conditions leads to the following basis polynomials:
  !
  !  P1(x,y,z) = 1/6 - 1/2*z - 1/6*(x^2 - y^2) - 1/3*(y^2 - z^2)
  !  P2(x,y,z) = 1/6 - 1/2*y - 1/6*(x^2 - y^2) + 1/6*(y^2 - z^2)
  !  P3(x,y,z) = 1/6 + 1/2*x + 1/3*(x^2 - y^2) + 1/6*(y^2 - z^2)
  !  P4(x,y,z) = 1/6 + 1/2*y - 1/6*(x^2 - y^2) + 1/6*(y^2 - z^2)
  !  P5(x,y,z) = 1/6 - 1/2*x + 1/3*(x^2 - y^2) + 1/6*(y^2 - z^2)
  !  P6(x,y,z) = 1/6 + 1/2*z - 1/6*(x^2 - y^2) - 1/3*(y^2 - z^2)

  ! Parameter: number of local basis functions
  integer, parameter :: NBAS = 6

  ! derivatives on reference element
  real(DP), dimension(NBAS,NDIM3D) :: DrefDer

  ! Local variables
  real(DP) :: ddet,dx,dy,dz,dxy,dyz
  integer :: i,j

  real(DP), parameter :: Q2 = 0.5_DP
  real(DP), parameter :: Q3 = 1.0_DP / 3.0_DP
  real(DP), parameter :: Q6 = 1.0_DP / 6.0_DP

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do defaulT(shared) private(i,dx,dy,dz,dxy,dyz) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Pre-calculate (x^2-y^2) and (y^2-z^2)
          dxy = dx*dx - dy*dy
          dyz = dy*dy - dz*dz

          Dbas(1,DER_FUNC3D,i,j) = Q6 - Q2*dz - Q6*dxy - Q3*dyz
          Dbas(2,DER_FUNC3D,i,j) = Q6 - Q2*dy - Q6*dxy + Q6*dyz
          Dbas(3,DER_FUNC3D,i,j) = Q6 + Q2*dx + Q3*dxy + Q6*dyz
          Dbas(4,DER_FUNC3D,i,j) = Q6 + Q2*dy - Q6*dxy + Q6*dyz
          Dbas(5,DER_FUNC3D,i,j) = Q6 - Q2*dx + Q3*dxy + Q6*dyz
          Dbas(6,DER_FUNC3D,i,j) = Q6 + Q2*dz - Q6*dxy - Q3*dyz

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

      ! Loop through all elements
      !$omp parallel do defaulT(shared) private(i,dx,dy,dz,ddet,DrefDer) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Calculate derivatives on reference element
          ! X-derivatives
          DrefDer( 1,1) = -Q3*dx
          DrefDer( 2,1) = -Q3*dx
          DrefDer( 3,1) = Q6*(4.0_DP*dx + 3.0_DP)
          DrefDer( 4,1) = -Q3*dx
          DrefDer( 5,1) = Q6*(4.0_DP*dx - 3.0_DP)
          DrefDer( 6,1) = -Q3*dx

          ! Y-derivatives
          DrefDer( 1,2) = -Q3*dy
          DrefDer( 2,2) = Q6*(4.0_DP*dy - 3.0_DP)
          DrefDer( 3,2) = -Q3*dy
          DrefDer( 4,2) = Q6*(4.0_DP*dy + 3.0_DP)
          DrefDer( 5,2) = -Q3*dy
          DrefDer( 6,2) = -Q3*dy

          ! Z-derivatives
          DrefDer( 1,3) = Q6*(4.0_DP*dz - 3.0_DP)
          DrefDer( 2,3) = -Q3*dz
          DrefDer( 3,3) = -Q3*dz
          DrefDer( 4,3) = -Q3*dz
          DrefDer( 5,3) = -Q3*dz
          DrefDer( 6,3) = Q6*(4.0_DP*dz + 3.0_DP)

          ! Remark: Please note that the following code is universal and does
          ! not need to be modified for other parametric 3D hexahedron elements!

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)

          ! X-derivatives on real element
          dx = (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          dy = (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          dz = (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_X,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Y-derivatives on real element
          dx = (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          dy = (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          dz = (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Y,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Z-derivatives on real element
          dx = (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          dy = (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          dz = (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Z,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_EN30_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

! </subroutine>

  ! Element Description
  ! -------------------
  ! The EN30_3D element is specified by nineteen polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x^2 - y^2, y^2 - z^2 }
  !
  ! see:
  ! J.-P. Hennart, J. Jaffre, and J. E. Roberts;
  ! "A Constructive Method for Deriving Finite Elements of Nodal Type";
  ! Numer. Math., 53 (1988), pp. 701-738.
  ! (The basis monomial set above is presented in example 10, pp. 728-730)
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,6:
  ! {
  !   For all j = 1,...,6:
  !   {
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))) d(x,y) = kronecker(i,j) * |fj|
  !     <==>
  !     Int_fj Pi(x,y) d(x,y) = kronecker(i,j) * |fj|
  !   }
  ! }
  !
  ! With:
  ! fj being the j-th local face of the hexahedron
  ! |fj| being the area of the face fj
  ! Fj: [-1,1]^2 -> fj being the parametrisation of the face fj
  ! |DFj(x,y)| being the determinant of the Jacobi-Matrix of Fj in the point (x,y)

  ! Parameter: Number of local basis functions
  integer, parameter :: NBAS = 6

  ! Parameter: Number of cubature points for 1D edge integration
  integer, parameter :: NCUB1D = 2

  ! Parameter: Number of cubature points for 2D quad integration
  integer, parameter :: NCUB2D = NCUB1D**2

  ! 1D edge cubature rule point coordinates and weights
  real(DP), dimension(NCUB1D) :: DcubPts1D
  real(DP), dimension(NCUB1D) :: DcubOmega1D

  ! 2D quad cubature rule point coordinates and weights
  real(DP), dimension(NDIM2D, NCUB2D) :: DcubPts2D
  real(DP), dimension(NCUB2D) :: DcubOmega2D

  ! Corner vertice coordinates
  real(DP), dimension(NDIM3D, 8) :: Dvert

  ! Local mapped 2D cubature point coordinates and integration weights
  real(DP), dimension(NDIM3D, NCUB2D, 6) :: DfacePoints
  real(DP), dimension(NCUB2D, 6) :: DfaceWeights
  real(DP), dimension(6) :: DfaceArea

  ! Temporary variables for face vertice mapping
  real(DP), dimension(4,3) :: Dft

  ! Coefficients for inverse affine transformation
  real(DP), dimension(NDIM3D,NDIM3D) :: Ds, Dat
  real(DP), dimension(NDIM3D) :: Dr

  ! other local variables
  integer :: i,j,l,iel, ipt
  real(DP), dimension(NBAS,NBAS) :: Da, Dc
  real(DP) :: dx,dy,dz,dt,derx,dery,derz,dx1,dy1,dz1
  logical :: bsuccess

    ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    ! Step 0: Set up 1D and 2D cubature rules
    ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    ! Set up a 2-point Gauss rule for 1D
    ! Remark: Although we do not actually need the 1D formula for integration,
    ! it is used a few lines below to set up the 2D formula...
    DcubPts1D(1) = -sqrt(1.0_DP / 3.0_DP)
    DcubPts1D(2) =  sqrt(1.0_DP / 3.0_DP)
    DcubOmega1D(1) = 1.0_DP
    DcubOmega1D(2) = 1.0_DP

!    ! !!! DEBUG: 5-point Gauss rule !!!
!    dt = 2.0_DP*sqrt(10.0_DP / 7.0_DP)
!    DcubPts1D(1) = -sqrt(5.0_DP + dt) / 3.0_DP
!    DcubPts1D(2) = -sqrt(5.0_DP - dt) / 3.0_DP
!    DcubPts1D(3) = 0.0_DP
!    DcubPts1D(4) =  sqrt(5.0_DP - dt) / 3.0_DP
!    DcubPts1D(5) =  sqrt(5.0_DP + dt) / 3.0_DP
!    dt = 13.0_DP*sqrt(70.0_DP)
!    DcubOmega1D(1) = (322.0_DP - dt) / 900.0_DP
!    DcubOmega1D(2) = (322.0_DP + dt) / 900.0_DP
!    DcubOmega1D(3) = 128.0_DP / 225.0_DP
!    DcubOmega1D(4) = (322.0_DP + dt) / 900.0_DP
!    DcubOmega1D(5) = (322.0_DP - dt) / 900.0_DP

    ! Set up a 2x2-point Gauss rule for 2D
    l = 1
    do i = 1, NCUB1D
      do j = 1, NCUB1D
        DcubPts2D(1,l) = DcubPts1D(i)
        DcubPts2D(2,l) = DcubPts1D(j)
        DcubOmega2D(l) = DcubOmega1D(i)*DcubOmega1D(j)
        l = l+1
      end do
    end do

    ! Loop over all elements
    !$omp parallel do default(shared)&
    !$omp private(Da,Dat,Dc,DfacePoints,DfaceWeights,Dr,Ds,Dvert,bsuccess,&
    !$omp         derx,dery,derz,dt,dx,dx1,dy,dy1,dz,dz1,i,ipt,j)&
    !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
    do iel = 1, reval%nelements

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 1: Fetch vertice coordinates
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Fetch the eight corner vertices for that element
      Dvert(1:3,1:8) = reval%p_Dcoords(1:3,1:8,iel)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 2: Calculate inverse affine transformation
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      Dr(:) = 0.125_DP * (Dvert(:,1) + Dvert(:,2) + Dvert(:,3) + Dvert(:,4) &
                         +Dvert(:,5) + Dvert(:,6) + Dvert(:,7) + Dvert(:,8))

      ! Set up affine trafo
      Dat(:,1) = 0.25_DP * (Dvert(:,2)+Dvert(:,3)+Dvert(:,7)+Dvert(:,6))-Dr(:)
      Dat(:,2) = 0.25_DP * (Dvert(:,3)+Dvert(:,4)+Dvert(:,8)+Dvert(:,7))-Dr(:)
      Dat(:,3) = 0.25_DP * (Dvert(:,5)+Dvert(:,6)+Dvert(:,7)+Dvert(:,8))-Dr(:)

!      ! !!! DEBUG: normalise local coordinate system !!!
!      dx1 = 1.0_DP / sqrt(Dat(1,1)**2 + Dat(2,1)**2 + Dat(3,1)**2)
!      dy1 = 1.0_DP / sqrt(Dat(1,2)**2 + Dat(2,2)**2 + Dat(3,2)**2)
!      dz1 = 1.0_DP / sqrt(Dat(1,3)**2 + Dat(2,3)**2 + Dat(3,3)**2)
!      Dat(:,1) = dx1 * Dat(:,1)
!      Dat(:,2) = dy1 * Dat(:,2)
!      Dat(:,3) = dz1 * Dat(:,3)
!      ! !!! DEBUG !!!

      ! And invert it
      call mprim_invert3x3MatrixDirect(Dat,Ds,bsuccess)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 3: Map 2D cubature points onto the real faces
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Map the 2D cubature points onto the real faces and calculate the
      ! integration weighting factors in this step.
      do j = 1, 6

        ! Calculate trafo for this face
        call elh3d_calcFaceTrafo_Q1(Dft,j,Dvert)

        ! Loop over all cubature points
        do i = 1, NCUB2D

          ! Get the cubature point coordinates
          dx = DcubPts2D(1,i)
          dy = DcubPts2D(2,i)

          ! Transform the point
          DfacePoints(1,i,j) = Dft(1,1)+Dft(2,1)*dx+Dft(3,1)*dy+Dft(4,1)*dx*dy
          DfacePoints(2,i,j) = Dft(1,2)+Dft(2,2)*dx+Dft(3,2)*dy+Dft(4,2)*dx*dy
          DfacePoints(3,i,j) = Dft(1,3)+Dft(2,3)*dx+Dft(3,3)*dy+Dft(4,3)*dx*dy

          ! Calculate jacobi-determinant of mapping
          ! TODO: Explain WTF is happening here...
          dt = sqrt(((Dft(2,2) + Dft(4,2)*dy)*(Dft(3,3) + Dft(4,3)*dx) &
                    -(Dft(2,3) + Dft(4,3)*dy)*(Dft(3,2) + Dft(4,2)*dx))**2 &
                  + ((Dft(2,3) + Dft(4,3)*dy)*(Dft(3,1) + Dft(4,1)*dx) &
                    -(Dft(2,1) + Dft(4,1)*dy)*(Dft(3,3) + Dft(4,3)*dx))**2 &
                  + ((Dft(2,1) + Dft(4,1)*dy)*(Dft(3,2) + Dft(4,2)*dx) &
                    -(Dft(2,2) + Dft(4,2)*dy)*(Dft(3,1) + Dft(4,1)*dx))**2)

          ! Calculate integration weight
          DfaceWeights(i,j) = dt * DcubOmega2D(i)

        end do ! i

      end do ! j

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 4: Calculate face areas
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Calculate the inverse of the face areas - we will need them for
      ! scaling later...
      do j = 1, 6
        dt = 0.0_DP
        do i = 1, NCUB2D
          dt = dt + DfaceWeights(i,j)
        end do
        DfaceArea(j) = 1.0_DP / dt
      end do

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 5: Build coefficient matrix
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Clear coefficient matrix
      Da = 0.0_DP

      ! Loop over all faces of the hexahedron
      do j = 1, 6

        ! Loop over all cubature points on the current face
        do i = 1, NCUB2D

          dx1 = DfacePoints(1,i,j) - Dr(1)
          dy1 = DfacePoints(2,i,j) - Dr(2)
          dz1 = DfacePoints(3,i,j) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Integral-Mean over the faces
          ! ----------------------------
          dt = DfaceWeights(i,j) * DfaceArea(j)

          Da( 1,j) = Da( 1,j) + dt
          Da( 2,j) = Da( 2,j) + dt*dx
          Da( 3,j) = Da( 3,j) + dt*dy
          Da( 4,j) = Da( 4,j) + dt*dz
          Da( 5,j) = Da( 5,j) + dt*(dx**2 - dy**2)
          Da( 6,j) = Da( 6,j) + dt*(dy**2 - dz**2)

        end do ! i

      end do ! j

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 6: Invert coefficient matrix
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Call the 'direct' inversion routine for 6x6 systems
      call mprim_invert6x6MatrixDirect(Da, Dc,bsuccess)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 8: Evaluate function values
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      if(Bder(DER_FUNC3D)) then

        ! Loop over all points then
        do ipt = 1, reval%npointsPerElement

          dx1 = reval%p_DpointsReal(1,ipt,iel) - Dr(1)
          dy1 = reval%p_DpointsReal(2,ipt,iel) - Dr(2)
          dz1 = reval%p_DpointsReal(3,ipt,iel) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Evaluate basis functions
          do i = 1, NBAS

            Dbas(i,DER_FUNC3D,ipt,iel) = Dc(i,1) &
              + dx*(Dc(i,2) + dx*Dc(i,5)) &
              + dy*(Dc(i,3) + dy*(Dc(i,6) - Dc(i,5))) &
              + dz*(Dc(i,4) - dz*Dc(i,6))

          end do ! i

        end do ! ipt

      end if ! function values evaluation

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 9: Evaluate derivatives
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

        ! Loop over all points then
        do ipt = 1, reval%npointsPerElement

          dx1 = reval%p_DpointsReal(1,ipt,iel) - Dr(1)
          dy1 = reval%p_DpointsReal(2,ipt,iel) - Dr(2)
          dz1 = reval%p_DpointsReal(3,ipt,iel) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Evaluate derivatives
          do i = 1, NBAS

            ! Calculate 'reference' derivatives
            derx = Dc(i,2) + 2.0_DP*dx*Dc(i,5)
            dery = Dc(i,3) + 2.0_DP*dy*(Dc(i,6) - Dc(i,5))
            derz = Dc(i,4) - 2.0_DP*dz*Dc(i,6)

            ! Calculate 'real' derivatives
            Dbas(i,DER_DERIV3D_X,ipt,iel) = &
              Ds(1,1)*derx + Ds(2,1)*dery + Ds(3,1)*derz
            Dbas(i,DER_DERIV3D_Y,ipt,iel) = &
              Ds(1,2)*derx + Ds(2,2)*dery + Ds(3,2)*derz
            Dbas(i,DER_DERIV3D_Z,ipt,iel) = &
              Ds(1,3)*derx + Ds(2,3)*dery + Ds(3,3)*derz

          end do ! i

        end do ! ipt

      end if ! derivatives evaluation

    end do ! iel
    !$omp end parallel do

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_E050_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! The E050_3D element is specified by nineteen polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x*y, y*z, z*x, x^2, y^2, z^2, x*y^2, y*z^2, z*x^2,
  !   x^2*y, y^2*z, z^2*x, x^3*y - x*y^3, y^3*z - y*z^3, z^3*x - z*x^3 }
  !
  ! see:
  ! J.-P. Hennart, J. Jaffre, and J. E. Roberts;
  ! "A Constructive Method for Deriving Finite Elements of Nodal Type";
  ! Numer. Math., 53 (1988), pp. 701-738.
  ! (The basis monomial set above is presented in example 10, pp. 728-730)
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,19:
  ! {
  !   For all j = 1,...,6:
  !   {
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))      ) d(x,y)
  !         = kronecker(i,j        ) * |fj|
  !
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))*L1(x)) d(x,y)
  !         = kronecker(i,2*(j-1)+7) * |fj|
  !
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))*L1(y)) d(x,y)
  !         = kronecker(i,2*(j-1)+8) * |fj|
  !   }
  !   Int_T (Pi(x,y,z)) d(x,y,z) = kronecker(i,19) * |T|
  ! }
  !
  ! With:
  ! fj being the j-th local face of the hexahedron
  ! |fj| being the area of the face fj
  ! Fj: [-1,1]^2 -> fj being the parametrisation of the face fj
  ! |DFj(x,y)| being the determinant of the Jacobi-Matrix of Fj in the point (x,y)
  ! T being the hexahedron
  ! |T| being the volume of the hexahedron
  ! L1 being the first Legendre-Polynomial:
  ! L1(x) := x
  !
  ! On the reference element, the above combination of monomial set and
  ! basis polynomial conditions leads to the following basis polynomials:
  !
  !  P1 (x,y,z) = z*(-1 + 3/4*(z + x^2 + y^2)) - 1/4
  !  P2 (x,y,z) = y*(-1 + 3/4*(y + x^2 + z^2)) - 1/4
  !  P3 (x,y,z) = x*( 1 + 3/4*(x - y^2 - z^2)) - 1/4
  !  P4 (x,y,z) = y*( 1 + 3/4*(y - x^2 - z^2)) - 1/4
  !  P5 (x,y,z) = x*(-1 + 3/4*(x + y^2 + z^2)) - 1/4
  !  P6 (x,y,z) = z*( 1 + 3/4*(z - x^2 - y^2)) - 1/4
  !  P7 (x,y,z) = 3/4*x*(-1 + z*(-1 + z*( 3 - 5/2*z) + 5/2*x^2))
  !  P8 (x,y,z) = 3/4*y*(-1 + z*(-1 + z*( 3 - 5/2*z) + 5/2*y^2))
  !  P9 (x,y,z) = 3/4*z*(-1 + y*(-1 + y*( 3 - 5/2*y) + 5/2*z^2))
  !  P10(x,y,z) = 3/4*x*(-1 + y*(-1 + y*( 3 - 5/2*y) + 5/2*x^2))
  !  P11(x,y,z) = 3/4*z*( 1 + x*(-1 + x*(-3 - 5/2*x) + 5/2*z^2))
  !  P12(x,y,z) = 3/4*y*( 1 + x*(-1 + x*(-3 - 5/2*x) + 5/2*y^2))
  !  P13(x,y,z) = 3/4*x*( 1 + y*(-1 + y*(-3 - 5/2*y) + 5/2*x^2))
  !  P14(x,y,z) = 3/4*z*( 1 + y*(-1 + y*(-3 - 5/2*y) + 5/2*z^2))
  !  P15(x,y,z) = 3/4*y*(-1 + x*(-1 + x*( 3 - 5/2*x) + 5/2*y^2))
  !  P16(x,y,z) = 3/4*z*(-1 + x*(-1 + x*( 3 - 5/2*x) + 5/2*z^2))
  !  P17(x,y,z) = 3/4*y*( 1 + z*(-1 + z*(-3 - 5/2*z) + 5/2*y^2))
  !  P18(x,y,z) = 3/4*x*( 1 + z*(-1 + z*(-3 - 5/2*z) + 5/2*x^2))
  !  P19(x,y,z) = 5/2 - 3/2*(x^2 + y^2 + z^2)

  ! Parameter: number of local basis functions
  integer, parameter :: NBAS = 19

  ! derivatives on reference element
  real(DP), dimension(NBAS,NDIM3D) :: DrefDer

  ! Twist matrices
  real(DP), dimension(2,2,0:7) :: Dtwist
  real(DP), dimension(2,2,6) :: Dtm

  real(DP), dimension(2,6) :: DL

  ! Local variables
  real(DP) :: ddet,dx,dy,dz,dx2,dy2,dz2
  integer :: i,j
  integer(I32) :: itwist

  ! Some parameters to make the code less readable... ^_^
  real(DP), parameter :: P1 = 0.75_DP
  real(DP), parameter :: P2 = 1.0_DP
  real(DP), parameter :: P3 = 2.5_DP
  real(DP), parameter :: P4 = 3.0_DP
  real(DP), parameter :: Q1 = 0.75_DP
  real(DP), parameter :: Q2 = 1.0_DP
  real(DP), parameter :: Q3 = 1.5_DP
  real(DP), parameter :: Q4 = 1.875_DP
  real(DP), parameter :: Q5 = 2.25_DP
  real(DP), parameter :: Q6 = 4.5_DP
  real(DP), parameter :: Q7 = 5.625_DP

    ! Set up twist matrices
    Dtwist(:,:,0) = reshape( (/ 1.0_DP, 0.0_DP, 0.0_DP, 1.0_DP/) , (/2,2/) )
    Dtwist(:,:,1) = reshape( (/ 0.0_DP, 1.0_DP,-1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,2) = reshape( (/-1.0_DP, 0.0_DP, 0.0_DP,-1.0_DP/) , (/2,2/) )
    Dtwist(:,:,3) = reshape( (/ 0.0_DP,-1.0_DP, 1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,4) = reshape( (/ 0.0_DP, 1.0_DP, 1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,5) = reshape( (/-1.0_DP, 0.0_DP, 0.0_DP, 1.0_DP/) , (/2,2/) )
    Dtwist(:,:,6) = reshape( (/ 0.0_DP,-1.0_DP,-1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,7) = reshape( (/ 1.0_DP, 0.0_DP, 0.0_DP,-1.0_DP/) , (/2,2/) )

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do default(shared)&
      !$omp private(i,itwist,Dtm,dx,dy,dz,dx2,dy2,dz2,DL)&
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Get the six twist matrices for this element
        itwist = reval%p_ItwistIndex(j)
        Dtm(:,:,1) = Dtwist(:,:,iand(int(ishft(itwist,-12)),7))
        Dtm(:,:,2) = Dtwist(:,:,iand(int(ishft(itwist,-15)),7))
        Dtm(:,:,3) = Dtwist(:,:,iand(int(ishft(itwist,-18)),7))
        Dtm(:,:,4) = Dtwist(:,:,iand(int(ishft(itwist,-21)),7))
        Dtm(:,:,5) = Dtwist(:,:,iand(int(ishft(itwist,-24)),7))
        Dtm(:,:,6) = Dtwist(:,:,iand(int(ishft(itwist,-27)),7))

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Pre-calculate squares
          dx2 = dx * dx
          dy2 = dy * dy
          dz2 = dz * dz

          ! Evaluate basis functions
          DL(1,1) = P1*dx*(-P2 + dz*(-P2 + dz*( P4 - P3*dz) + P3*dx2))
          DL(2,1) = P1*dy*(-P2 + dz*(-P2 + dz*( P4 - P3*dz) + P3*dy2))
          DL(1,2) = P1*dz*(-P2 + dy*(-P2 + dy*( P4 - P3*dy) + P3*dz2))
          DL(2,2) = P1*dx*(-P2 + dy*(-P2 + dy*( P4 - P3*dy) + P3*dx2))
          DL(1,3) = P1*dz*( P2 + dx*(-P2 + dx*(-P4 - P3*dx) + P3*dz2))
          DL(2,3) = P1*dy*( P2 + dx*(-P2 + dx*(-P4 - P3*dx) + P3*dy2))
          DL(1,4) = P1*dx*( P2 + dy*(-P2 + dy*(-P4 - P3*dy) + P3*dx2))
          DL(2,4) = P1*dz*( P2 + dy*(-P2 + dy*(-P4 - P3*dy) + P3*dz2))
          DL(1,5) = P1*dy*(-P2 + dx*(-P2 + dx*( P4 - P3*dx) + P3*dy2))
          DL(2,5) = P1*dz*(-P2 + dx*(-P2 + dx*( P4 - P3*dx) + P3*dz2))
          DL(1,6) = P1*dy*( P2 + dz*(-P2 + dz*(-P4 - P3*dz) + P3*dy2))
          DL(2,6) = P1*dx*( P2 + dz*(-P2 + dz*(-P4 - P3*dz) + P3*dx2))

          Dbas( 1,DER_FUNC3D,i,j) = dz*(-P2 + P1*(dz + dx2 + dy2)) - 0.25_DP
          Dbas( 2,DER_FUNC3D,i,j) = dy*(-P2 + P1*(dy + dx2 + dz2)) - 0.25_DP
          Dbas( 3,DER_FUNC3D,i,j) = dx*( P2 + P1*(dx - dy2 - dz2)) - 0.25_DP
          Dbas( 4,DER_FUNC3D,i,j) = dy*( P2 + P1*(dy - dx2 - dz2)) - 0.25_DP
          Dbas( 5,DER_FUNC3D,i,j) = dx*(-P2 + P1*(dx + dy2 + dz2)) - 0.25_DP
          Dbas( 6,DER_FUNC3D,i,j) = dz*( P2 + P1*(dz - dx2 - dy2)) - 0.25_DP
          Dbas( 7,DER_FUNC3D,i,j) = Dtm(1,1,1)*DL(1,1) + Dtm(1,2,1)*DL(2,1)
          Dbas( 8,DER_FUNC3D,i,j) = Dtm(2,1,1)*DL(1,1) + Dtm(2,2,1)*DL(2,1)
          Dbas( 9,DER_FUNC3D,i,j) = Dtm(1,1,2)*DL(1,2) + Dtm(1,2,2)*DL(2,2)
          Dbas(10,DER_FUNC3D,i,j) = Dtm(2,1,2)*DL(1,2) + Dtm(2,2,2)*DL(2,2)
          Dbas(11,DER_FUNC3D,i,j) = Dtm(1,1,3)*DL(1,3) + Dtm(1,2,3)*DL(2,3)
          Dbas(12,DER_FUNC3D,i,j) = Dtm(2,1,3)*DL(1,3) + Dtm(2,2,3)*DL(2,3)
          Dbas(13,DER_FUNC3D,i,j) = Dtm(1,1,4)*DL(1,4) + Dtm(1,2,4)*DL(2,4)
          Dbas(14,DER_FUNC3D,i,j) = Dtm(2,1,4)*DL(1,4) + Dtm(2,2,4)*DL(2,4)
          Dbas(15,DER_FUNC3D,i,j) = Dtm(1,1,5)*DL(1,5) + Dtm(1,2,5)*DL(2,5)
          Dbas(16,DER_FUNC3D,i,j) = Dtm(2,1,5)*DL(1,5) + Dtm(2,2,5)*DL(2,5)
          Dbas(17,DER_FUNC3D,i,j) = Dtm(1,1,6)*DL(1,6) + Dtm(1,2,6)*DL(2,6)
          Dbas(18,DER_FUNC3D,i,j) = Dtm(2,1,6)*DL(1,6) + Dtm(2,2,6)*DL(2,6)
          Dbas(19,DER_FUNC3D,i,j) = 2.5_DP - 1.5_DP*(dx2 + dy2 + dz2)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

      ! Loop through all elements
      !$omp parallel do default(shared)&
      !$omp private(i,itwist,Dtm,dx,dy,dz,dx2,dy2,dz2,DL,DrefDer,ddet)&
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Get the six twist matrices for this element
        itwist = reval%p_ItwistIndex(j)
        Dtm(:,:,1) = Dtwist(:,:,iand(int(ishft(itwist,-12)),7))
        Dtm(:,:,2) = Dtwist(:,:,iand(int(ishft(itwist,-15)),7))
        Dtm(:,:,3) = Dtwist(:,:,iand(int(ishft(itwist,-18)),7))
        Dtm(:,:,4) = Dtwist(:,:,iand(int(ishft(itwist,-21)),7))
        Dtm(:,:,5) = Dtwist(:,:,iand(int(ishft(itwist,-24)),7))
        Dtm(:,:,6) = Dtwist(:,:,iand(int(ishft(itwist,-27)),7))

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          ! Pre-calculate squares
          dx2 = dx * dx
          dy2 = dy * dy
          dz2 = dz * dz

          ! Calculate derivatives on reference element
          ! X-derivatives
          DL(1,1) = -Q1 + dz*(-Q1 + Q7*dx2 + dz*( Q5 - Q4*dz))
          DL(2,1) =  0.0_DP
          DL(1,2) =  0.0_DP
          DL(2,2) = -Q1 + dy*(-Q1 + Q7*dx2 + dy*( Q5 - Q4*dy))
          DL(1,3) =  dz*(-Q1 + dx*(-Q6 - Q7*dx) + Q4*dz2)
          DL(2,3) =  dy*(-Q1 + dx*(-Q6 - Q7*dx) + Q4*dy2)
          DL(1,4) =  Q1 + dy*(-Q1 + Q7*dx2 + dy*(-Q5 - Q4*dy))
          DL(2,4) =  0.0_DP
          DL(1,5) =  dy*(-Q1 + dx*( Q6 - Q7*dx) + Q4*dy2)
          DL(2,5) =  dz*(-Q1 + dx*( Q6 - Q7*dx) + Q4*dz2)
          DL(1,6) =  0.0_DP
          DL(2,6) =  Q1 + dz*(-Q1 + Q7*dx2 + dz*(-Q5 - Q4*dz))

          DrefDer( 1,1) =  Q3*dx*dz
          DrefDer( 2,1) =  Q3*dx*dy
          DrefDer( 3,1) =  Q2 + Q3*dx - Q1*dy2 - Q1*dz2
          DrefDer( 4,1) = -Q3*dx*dy
          DrefDer( 5,1) = -Q2 + Q3*dx + Q1*dy2 + Q1*dz2
          DrefDer( 6,1) = -Q3*dx*dz
          DrefDer( 7,1) = Dtm(1,1,1)*DL(1,1) + Dtm(1,2,1)*DL(2,1)
          DrefDer( 8,1) = Dtm(2,1,1)*DL(1,1) + Dtm(2,2,1)*DL(2,1)
          DrefDer( 9,1) = Dtm(1,1,2)*DL(1,2) + Dtm(1,2,2)*DL(2,2)
          DrefDer(10,1) = Dtm(2,1,2)*DL(1,2) + Dtm(2,2,2)*DL(2,2)
          DrefDer(11,1) = Dtm(1,1,3)*DL(1,3) + Dtm(1,2,3)*DL(2,3)
          DrefDer(12,1) = Dtm(2,1,3)*DL(1,3) + Dtm(2,2,3)*DL(2,3)
          DrefDer(13,1) = Dtm(1,1,4)*DL(1,4) + Dtm(1,2,4)*DL(2,4)
          DrefDer(14,1) = Dtm(2,1,4)*DL(1,4) + Dtm(2,2,4)*DL(2,4)
          DrefDer(15,1) = Dtm(1,1,5)*DL(1,5) + Dtm(1,2,5)*DL(2,5)
          DrefDer(16,1) = Dtm(2,1,5)*DL(1,5) + Dtm(2,2,5)*DL(2,5)
          DrefDer(17,1) = Dtm(1,1,6)*DL(1,6) + Dtm(1,2,6)*DL(2,6)
          DrefDer(18,1) = Dtm(2,1,6)*DL(1,6) + Dtm(2,2,6)*DL(2,6)
          DrefDer(19,1) = -3.0_DP*dx

          ! Y-derivatives
          DL(1,1) =  0.0_DP
          DL(2,1) = -Q1 + dz*(-Q1 + Q7*dy2 + dz*( Q5 - Q4*dz))
          DL(1,2) =  dz*(-Q1 + dy*( Q6 - Q7*dy) + Q4*dz2)
          DL(2,2) =  dx*(-Q1 + dy*( Q6 - Q7*dy) + Q4*dx2)
          DL(1,3) =  0.0_DP
          DL(2,3) =  Q1 + dx*(-Q1 + Q7*dy2 + dx*(-Q5 - Q4*dx))
          DL(1,4) =  dx*(-Q1 + dy*(-Q6 - Q7*dy) + Q4*dx2)
          DL(2,4) =  dz*(-Q1 + dy*(-Q6 - Q7*dy) + Q4*dz2)
          DL(1,5) = -Q1 + dx*(-Q1 + Q7*dy2 + dx*( Q5 - Q4*dx))
          DL(2,5) =  0.0_DP
          DL(1,6) =  Q1 + dz*(-Q1 + Q7*dy2 + dz*(-Q5 - Q4*dz))
          DL(2,6) =  0.0_DP

          DrefDer( 1,2) =  Q3*dy*dz
          DrefDer( 2,2) = -Q2 + Q3*dy + Q1*dx2 + Q1*dz2
          DrefDer( 3,2) = -Q3*dx*dy
          DrefDer( 4,2) =  Q2 + Q3*dy - Q1*dx2 - Q1*dz2
          DrefDer( 5,2) =  Q3*dx*dy
          DrefDer( 6,2) = -Q3*dy*dz
          DrefDer( 7,2) = Dtm(1,1,1)*DL(1,1) + Dtm(1,2,1)*DL(2,1)
          DrefDer( 8,2) = Dtm(2,1,1)*DL(1,1) + Dtm(2,2,1)*DL(2,1)
          DrefDer( 9,2) = Dtm(1,1,2)*DL(1,2) + Dtm(1,2,2)*DL(2,2)
          DrefDer(10,2) = Dtm(2,1,2)*DL(1,2) + Dtm(2,2,2)*DL(2,2)
          DrefDer(11,2) = Dtm(1,1,3)*DL(1,3) + Dtm(1,2,3)*DL(2,3)
          DrefDer(12,2) = Dtm(2,1,3)*DL(1,3) + Dtm(2,2,3)*DL(2,3)
          DrefDer(13,2) = Dtm(1,1,4)*DL(1,4) + Dtm(1,2,4)*DL(2,4)
          DrefDer(14,2) = Dtm(2,1,4)*DL(1,4) + Dtm(2,2,4)*DL(2,4)
          DrefDer(15,2) = Dtm(1,1,5)*DL(1,5) + Dtm(1,2,5)*DL(2,5)
          DrefDer(16,2) = Dtm(2,1,5)*DL(1,5) + Dtm(2,2,5)*DL(2,5)
          DrefDer(17,2) = Dtm(1,1,6)*DL(1,6) + Dtm(1,2,6)*DL(2,6)
          DrefDer(18,2) = Dtm(2,1,6)*DL(1,6) + Dtm(2,2,6)*DL(2,6)
          DrefDer(19,2) = -3.0_DP*dy

          ! Z-derivatives
          DL(1,1) =  dx*(-Q1 + dz*( Q6 - Q7*dz) + Q4*dx2)
          DL(2,1) =  dy*(-Q1 + dz*( Q6 - Q7*dz) + Q4*dy2)
          DL(1,2) = -Q1 + dy*(-Q1 + Q7*dz2 + dy*( Q5 - Q4*dy))
          DL(2,2) =  0.0_DP
          DL(1,3) =  Q1 + dx*(-Q1 + Q7*dz2 + dx*(-Q5 - Q4*dx))
          DL(2,3) =  0.0_DP
          DL(1,4) =  0.0_DP
          DL(2,4) =  Q1 + dy*(-Q1 + Q7*dz2 + dy*(-Q5 - Q4*dy))
          DL(1,5) =  0.0_DP
          DL(2,5) = -Q1 + dx*(-Q1 + Q7*dz2 + dx*( Q5 - Q4*dx))
          DL(1,6) =  dy*(-Q1 + dz*(-Q6 - Q7*dz) + Q4*dy2)
          DL(2,6) =  dx*(-Q1 + dz*(-Q6 - Q7*dz) + Q4*dx2)

          DrefDer( 1,3) = -Q2 + Q3*dz + Q1*dx2 + Q1*dy2
          DrefDer( 2,3) =  Q3*dy*dz
          DrefDer( 3,3) = -Q3*dx*dz
          DrefDer( 4,3) = -Q3*dy*dz
          DrefDer( 5,3) =  Q3*dx*dz
          DrefDer( 6,3) =  Q2 + Q3*dz - Q1*dx2 - Q1*dy2
          DrefDer( 7,3) = Dtm(1,1,1)*DL(1,1) + Dtm(1,2,1)*DL(2,1)
          DrefDer( 8,3) = Dtm(2,1,1)*DL(1,1) + Dtm(2,2,1)*DL(2,1)
          DrefDer( 9,3) = Dtm(1,1,2)*DL(1,2) + Dtm(1,2,2)*DL(2,2)
          DrefDer(10,3) = Dtm(2,1,2)*DL(1,2) + Dtm(2,2,2)*DL(2,2)
          DrefDer(11,3) = Dtm(1,1,3)*DL(1,3) + Dtm(1,2,3)*DL(2,3)
          DrefDer(12,3) = Dtm(2,1,3)*DL(1,3) + Dtm(2,2,3)*DL(2,3)
          DrefDer(13,3) = Dtm(1,1,4)*DL(1,4) + Dtm(1,2,4)*DL(2,4)
          DrefDer(14,3) = Dtm(2,1,4)*DL(1,4) + Dtm(2,2,4)*DL(2,4)
          DrefDer(15,3) = Dtm(1,1,5)*DL(1,5) + Dtm(1,2,5)*DL(2,5)
          DrefDer(16,3) = Dtm(2,1,5)*DL(1,5) + Dtm(2,2,5)*DL(2,5)
          DrefDer(17,3) = Dtm(1,1,6)*DL(1,6) + Dtm(1,2,6)*DL(2,6)
          DrefDer(18,3) = Dtm(2,1,6)*DL(1,6) + Dtm(2,2,6)*DL(2,6)
          DrefDer(19,3) = -3.0_DP*dz

          ! Remark: Please note that the following code is universal and does
          ! not need to be modified for other parametric 3D hexahedron elements!

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)

          ! X-derivatives on real element
          dx = (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          dy = (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          dz = (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_X,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Y-derivatives on real element
          dx = (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          dy = (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          dz = (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Y,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

          ! Z-derivatives on real element
          dx = (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          dy = (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          dz = (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Z,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)

        end do ! i

      end do ! j
      !$omp end parallel do

    end if

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_EN50_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

! </subroutine>

  ! Element Description
  ! -------------------
  ! The EN50_3D element is specified by nineteen polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x*y, y*z, z*x, x^2, y^2, z^2, x*y^2, y*z^2, z*x^2,
  !   x^2*y, y^2*z, z^2*x, x^3*y - x*y^3, y^3*z - y*z^3, z^3*x - z*x^3 }
  !
  ! see:
  ! J.-P. Hennart, J. Jaffre, and J. E. Roberts;
  ! "A Constructive Method for Deriving Finite Elements of Nodal Type";
  ! Numer. Math., 53 (1988), pp. 701-738.
  ! (The basis monomial set above is presented in example 10, pp. 728-730)
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,19:
  ! {
  !   For all j = 1,...,6:
  !   {
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))      ) d(x,y)
  !         = kronecker(i,j        ) * |fj|
  !
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))*L1(x)) d(x,y)
  !         = kronecker(i,2*(j-1)+7) * |fj|
  !
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))*L1(y)) d(x,y)
  !         = kronecker(i,2*(j-1)+8) * |fj|
  !   }
  !   Int_T (Pi(x,y,z)) d(x,y,z) = kronecker(i,19) * |T|
  ! }
  !
  ! With:
  ! fj being the j-th local face of the hexahedron
  ! |fj| being the area of the face fj
  ! Fj: [-1,1]^2 -> fj being the parametrisation of the face fj
  ! |DFj(x,y)| being the determinant of the Jacobi-Matrix of Fj in the point (x,y)
  ! T being the hexahedron
  ! |T| being the volume of the hexahedron
  ! L1 being the first Legendre-Polynomial:
  ! L1(x) := x

  ! Parameter: Number of local basis functions
  integer, parameter :: NBAS = 19

  ! Parameter: Number of cubature points for 1D edge integration
  integer, parameter :: NCUB1D = 3

  ! Parameter: Number of cubature points for 2D quad integration
  integer, parameter :: NCUB2D = NCUB1D**2

  ! Parameter: Number of cubature points for 3D hexahedron integration
  integer, parameter :: NCUB3D = NCUB1D**3

  ! 1D edge cubature rule point coordinates and weights
  real(DP), dimension(NCUB1D) :: DcubPts1D
  real(DP), dimension(NCUB1D) :: DcubOmega1D

  ! 2D quad cubature rule point coordinates and weights
  real(DP), dimension(NDIM2D, NCUB2D) :: DcubPts2D
  real(DP), dimension(NCUB2D) :: DcubOmega2D

  ! 3D hexahedron cubature rule point coordinates and weights
  real(DP), dimension(NDIM3D, NCUB3D) :: DcubPts3D
  real(DP), dimension(NCUB3D) :: DcubOmega3D

  ! Corner vertice and face midpoint coordinates
  real(DP), dimension(NDIM3D, 8) :: Dvert
  !real(DP), dimension(NDIM3D, 6) :: Dface

  ! Hexahedron midpoint coordinates
  !real(DP), dimension(NDIM3D) :: Dhexa

  ! Local mapped 2D cubature point coordinates and integration weights
  real(DP), dimension(NDIM3D, NCUB2D, 6) :: DfacePoints
  real(DP), dimension(NCUB2D, 6) :: DfaceWeights
  real(DP), dimension(6) :: DfaceArea

  ! Local mapped 3D cubature point coordinates and integration weights
  real(DP), dimension(NDIM3D, NCUB3D) :: DhexaPoints
  real(DP), dimension(NCUB3D) :: DhexaWeights
  real(DP) :: dhexaVol

  ! temporary variables for trafo call (will be removed later)
  real(DP), dimension(TRAFO_NAUXJAC3D) :: DjacPrep
  real(DP), dimension(9) :: DjacTrafo

  ! Temporary variables for face vertice mapping
  real(DP), dimension(4,3) :: Dft

  ! Coefficients for inverse affine transformation
  real(DP), dimension(NDIM3D,NDIM3D) :: Ds, Dat
  real(DP), dimension(NDIM3D) :: Dr

  ! Twist matrices
  real(DP), dimension(2,2,0:7) :: Dtwist
  real(DP), dimension(2,2,6) :: Dtm

  ! other local variables
  integer(I32) :: itwist
  integer :: i,j,k,l,iel, ipt
  real(DP), dimension(NBAS,NBAS) :: Da
  real(DP) :: dx,dy,dz,dt,derx,dery,derz,dx1,dy1,dz1
  logical :: bsuccess

    ! Set up twist matrices
    Dtwist(:,:,0) = reshape( (/ 1.0_DP, 0.0_DP, 0.0_DP, 1.0_DP/) , (/2,2/) )
    Dtwist(:,:,1) = reshape( (/ 0.0_DP, 1.0_DP,-1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,2) = reshape( (/-1.0_DP, 0.0_DP, 0.0_DP,-1.0_DP/) , (/2,2/) )
    Dtwist(:,:,3) = reshape( (/ 0.0_DP,-1.0_DP, 1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,4) = reshape( (/ 0.0_DP, 1.0_DP, 1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,5) = reshape( (/-1.0_DP, 0.0_DP, 0.0_DP, 1.0_DP/) , (/2,2/) )
    Dtwist(:,:,6) = reshape( (/ 0.0_DP,-1.0_DP,-1.0_DP, 0.0_DP/) , (/2,2/) )
    Dtwist(:,:,7) = reshape( (/ 1.0_DP, 0.0_DP, 0.0_DP,-1.0_DP/) , (/2,2/) )

    ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    ! Step 0: Set up 1D, 2D and 3D cubature rules
    ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    ! Set up a 3-point Gauss rule for 1D
    ! Remark: Although we do not actually need the 1D formula for integration,
    ! it is used a few lines below to set up the 2D and 3D formulas...
    DcubPts1D(1) = -sqrt(3.0_DP / 5.0_DP)
    DcubPts1D(2) = 0.0_DP
    DcubPts1D(3) = sqrt(3.0_DP / 5.0_DP)
    DcubOmega1D(1) = 5.0_DP / 9.0_DP
    DcubOmega1D(2) = 8.0_DP / 9.0_DP
    DcubOmega1D(3) = 5.0_DP / 9.0_DP

    ! Set up a 3x3-point Gauss rule for 2D
    l = 1
    do i = 1, NCUB1D
      do j = 1, NCUB1D
        DcubPts2D(1,l) = DcubPts1D(i)
        DcubPts2D(2,l) = DcubPts1D(j)
        DcubOmega2D(l) = DcubOmega1D(i)*DcubOmega1D(j)
        l = l+1
      end do
    end do

    ! Set up a 3x3x3-point Gauss rule for 3D
    l = 1
    do i = 1, NCUB1D
      do j = 1, NCUB1D
        do k = 1, NCUB1D
          DcubPts3D(1,l) = DcubPts1D(i)
          DcubPts3D(2,l) = DcubPts1D(j)
          DcubPts3D(3,l) = DcubPts1D(k)
          DcubOmega3D(l) = DcubOmega1D(i)*DcubOmega1D(j)*DcubOmega1D(k)
          l = l+1
        end do
      end do
    end do

    ! Loop over all elements
    !$omp parallel do default(shared)&
    !$omp private(Da,Dat,DfaceArea,DfacePoints,DfaceWeights,DhexaPoints,&
    !$omp         DhexaWeights,DjacPrep,DjacTrafo,Dr,Ds,Dtm,Dvert,bsuccess,&
    !$omp         derx,dery,derz,dhexaVol,dt,dx,dx1,dy,dy1,dz,dz1,i,ipt,&
    !$omp         itwist,j,k)&
    !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
    do iel = 1, reval%nelements

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 1: Calculate vertice and face midpoint coordinates
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Fetch the eight corner vertices for that element
      Dvert(1:3,1:8) = reval%p_Dcoords(1:3,1:8,iel)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 2: Calculate inverse affine transformation
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      Dr(:) = 0.125_DP * (Dvert(:,1) + Dvert(:,2) + Dvert(:,3) + Dvert(:,4) &
                         +Dvert(:,5) + Dvert(:,6) + Dvert(:,7) + Dvert(:,8))

      ! Set up affine trafo
      Dat(:,1) = 0.25_DP * (Dvert(:,2)+Dvert(:,3)+Dvert(:,7)+Dvert(:,6))-Dr(:)
      Dat(:,2) = 0.25_DP * (Dvert(:,3)+Dvert(:,4)+Dvert(:,8)+Dvert(:,7))-Dr(:)
      Dat(:,3) = 0.25_DP * (Dvert(:,5)+Dvert(:,6)+Dvert(:,7)+Dvert(:,8))-Dr(:)

      ! And invert it
      call mprim_invert3x3MatrixDirect(Dat,Ds,bsuccess)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 3: Map 2D cubature points onto the real faces
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Map the 2D cubature points onto the real faces and calculate the
      ! integration weighting factors in this step.
      ! TODO: Replace by Q2-mapping later.
      do j = 1, 6

        ! Calculate trafo for this face
        call elh3d_calcFaceTrafo_Q1(Dft,j,Dvert)

        ! Loop over all cubature points
        do i = 1, NCUB2D

          ! Get the cubature point coordinates
          dx = DcubPts2D(1,i)
          dy = DcubPts2D(2,i)

          ! Transform the point
          DfacePoints(1,i,j) = Dft(1,1)+Dft(2,1)*dx+Dft(3,1)*dy+Dft(4,1)*dx*dy
          DfacePoints(2,i,j) = Dft(1,2)+Dft(2,2)*dx+Dft(3,2)*dy+Dft(4,2)*dx*dy
          DfacePoints(3,i,j) = Dft(1,3)+Dft(2,3)*dx+Dft(3,3)*dy+Dft(4,3)*dx*dy

          ! Calculate jacobi-determinant of mapping
          ! TODO: Explain WTF is happening here...
          dt = sqrt(((Dft(2,2) + Dft(4,2)*dy)*(Dft(3,3) + Dft(4,3)*dx) &
                    -(Dft(2,3) + Dft(4,3)*dy)*(Dft(3,2) + Dft(4,2)*dx))**2 &
                  + ((Dft(2,3) + Dft(4,3)*dy)*(Dft(3,1) + Dft(4,1)*dx) &
                    -(Dft(2,1) + Dft(4,1)*dy)*(Dft(3,3) + Dft(4,3)*dx))**2 &
                  + ((Dft(2,1) + Dft(4,1)*dy)*(Dft(3,2) + Dft(4,2)*dx) &
                    -(Dft(2,2) + Dft(4,2)*dy)*(Dft(3,1) + Dft(4,1)*dx))**2)

          ! Calculate integration weight
          DfaceWeights(i,j) = dt * DcubOmega2D(i)

        end do ! i

      end do ! j

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 4: Map 3D cubature points onto the real element
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Map the 3D cubature points onto the real element and calculate the
      ! integration weighting factors in this step.
      ! TODO: Replace by Q2-mapping later.
      call trafo_prepJac_hexa3D(Dvert, DjacPrep)
      do i = 1, NCUB3D
        call trafo_calcTrafo_hexa3d(DjacPrep, DjacTrafo, dt, &
            DcubPts3D(1,i), DcubPts3D(2,i), DcubPts3D(3,i), &
            DhexaPoints(1,i), DhexaPoints(2,i), DhexaPoints(3,i))
        DhexaWeights(i) = dt * DcubOmega3D(i)
      end do

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 5: Calculate face areas and hexahedron volume
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Calculate the inverse of the face areas - we will need them for
      ! scaling later...
      do j = 1, 6
        dt = 0.0_DP
        do i = 1, NCUB2D
          dt = dt + DfaceWeights(i,j)
        end do
        DfaceArea(j) = 1.0_DP / dt
      end do

      ! ...and also calculate the inverse of the element`s volume.
      dt = 0.0_DP
      do i = 1, NCUB3D
        dt = dt + DhexaWeights(i)
      end do
      dhexaVol = 1.0_DP / dt

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 6: Build coefficient matrix
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Get the six twist matrices for this element
      itwist = reval%p_ItwistIndex(iel)
      Dtm(:,:,1) = Dtwist(:,:,iand(int(ishft(itwist,-12)),7))
      Dtm(:,:,2) = Dtwist(:,:,iand(int(ishft(itwist,-15)),7))
      Dtm(:,:,3) = Dtwist(:,:,iand(int(ishft(itwist,-18)),7))
      Dtm(:,:,4) = Dtwist(:,:,iand(int(ishft(itwist,-21)),7))
      Dtm(:,:,5) = Dtwist(:,:,iand(int(ishft(itwist,-24)),7))
      Dtm(:,:,6) = Dtwist(:,:,iand(int(ishft(itwist,-27)),7))

      ! Clear coefficient matrix
      Da = 0.0_DP

      ! Loop over all faces of the hexahedron
      do j = 1, 6

        ! Loop over all cubature points on the current face
        do i = 1, NCUB2D

          dx1 = DfacePoints(1,i,j) - Dr(1)
          dy1 = DfacePoints(2,i,j) - Dr(2)
          dz1 = DfacePoints(3,i,j) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Integral-Mean over the faces
          ! ----------------------------
          dt = DfaceWeights(i,j) * DfaceArea(j)

          Da( 1,j) = Da( 1,j) + dt
          Da( 2,j) = Da( 2,j) + dt*dx
          Da( 3,j) = Da( 3,j) + dt*dy
          Da( 4,j) = Da( 4,j) + dt*dz
          Da( 5,j) = Da( 5,j) + dt*dx*dy
          Da( 6,j) = Da( 6,j) + dt*dy*dz
          Da( 7,j) = Da( 7,j) + dt*dz*dx
          Da( 8,j) = Da( 8,j) + dt*dx**2
          Da( 9,j) = Da( 9,j) + dt*dy**2
          Da(10,j) = Da(10,j) + dt*dz**2
          Da(11,j) = Da(11,j) + dt*dx*dy**2
          Da(12,j) = Da(12,j) + dt*dy*dz**2
          Da(13,j) = Da(13,j) + dt*dz*dx**2
          Da(14,j) = Da(14,j) + dt*dx**2*dy
          Da(15,j) = Da(15,j) + dt*dy**2*dz
          Da(16,j) = Da(16,j) + dt*dz**2*dx
          Da(17,j) = Da(17,j) + dt*(dx**3*dy - dx*dy**3)
          Da(18,j) = Da(18,j) + dt*(dy**3*dz - dy*dz**3)
          Da(19,j) = Da(19,j) + dt*(dz**3*dx - dz*dx**3)

          ! Legendre-Weighted Integral-Mean over the faces
          ! ----------------------------------------------
          dt = DfaceWeights(i,j) * DfaceArea(j) * &
               (Dtm(1,1,j)*DcubPts2D(1,i) + Dtm(1,2,j)*DcubPts2D(2,i))

          k = 2*(j-1) + 7
          Da( 1,k) = Da( 1,k) + dt
          Da( 2,k) = Da( 2,k) + dt*dx
          Da( 3,k) = Da( 3,k) + dt*dy
          Da( 4,k) = Da( 4,k) + dt*dz
          Da( 5,k) = Da( 5,k) + dt*dx*dy
          Da( 6,k) = Da( 6,k) + dt*dy*dz
          Da( 7,k) = Da( 7,k) + dt*dz*dx
          Da( 8,k) = Da( 8,k) + dt*dx**2
          Da( 9,k) = Da( 9,k) + dt*dy**2
          Da(10,k) = Da(10,k) + dt*dz**2
          Da(11,k) = Da(11,k) + dt*dx*dy**2
          Da(12,k) = Da(12,k) + dt*dy*dz**2
          Da(13,k) = Da(13,k) + dt*dz*dx**2
          Da(14,k) = Da(14,k) + dt*dx**2*dy
          Da(15,k) = Da(15,k) + dt*dy**2*dz
          Da(16,k) = Da(16,k) + dt*dz**2*dx
          Da(17,k) = Da(17,k) + dt*(dx**3*dy - dx*dy**3)
          Da(18,k) = Da(18,k) + dt*(dy**3*dz - dy*dz**3)
          Da(19,k) = Da(19,k) + dt*(dz**3*dx - dz*dx**3)

          dt = DfaceWeights(i,j) * DfaceArea(j) * &
               (Dtm(2,1,j)*DcubPts2D(1,i) + Dtm(2,2,j)*DcubPts2D(2,i))

          k = 2*(j-1) + 8
          Da( 1,k) = Da( 1,k) + dt
          Da( 2,k) = Da( 2,k) + dt*dx
          Da( 3,k) = Da( 3,k) + dt*dy
          Da( 4,k) = Da( 4,k) + dt*dz
          Da( 5,k) = Da( 5,k) + dt*dx*dy
          Da( 6,k) = Da( 6,k) + dt*dy*dz
          Da( 7,k) = Da( 7,k) + dt*dz*dx
          Da( 8,k) = Da( 8,k) + dt*dx**2
          Da( 9,k) = Da( 9,k) + dt*dy**2
          Da(10,k) = Da(10,k) + dt*dz**2
          Da(11,k) = Da(11,k) + dt*dx*dy**2
          Da(12,k) = Da(12,k) + dt*dy*dz**2
          Da(13,k) = Da(13,k) + dt*dz*dx**2
          Da(14,k) = Da(14,k) + dt*dx**2*dy
          Da(15,k) = Da(15,k) + dt*dy**2*dz
          Da(16,k) = Da(16,k) + dt*dz**2*dx
          Da(17,k) = Da(17,k) + dt*(dx**3*dy - dx*dy**3)
          Da(18,k) = Da(18,k) + dt*(dy**3*dz - dy*dz**3)
          Da(19,k) = Da(19,k) + dt*(dz**3*dx - dz*dx**3)

        end do ! i

      end do ! j

      ! Loop over all 3D cubature points
      do i = 1, NCUB3D

        dx1 = DhexaPoints(1,i) - Dr(1)
        dy1 = DhexaPoints(2,i) - Dr(2)
        dz1 = DhexaPoints(3,i) - Dr(3)

        ! Apply inverse affine trafo to get (x,y,z)
        dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
        dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
        dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

        ! Integral-Mean over the element
        ! ------------------------------
        dt = DhexaWeights(i) * dhexaVol

        Da( 1,19) = Da( 1,19) + dt
        Da( 2,19) = Da( 2,19) + dt*dx
        Da( 3,19) = Da( 3,19) + dt*dy
        Da( 4,19) = Da( 4,19) + dt*dz
        Da( 5,19) = Da( 5,19) + dt*dx*dy
        Da( 6,19) = Da( 6,19) + dt*dy*dz
        Da( 7,19) = Da( 7,19) + dt*dz*dx
        Da( 8,19) = Da( 8,19) + dt*dx**2
        Da( 9,19) = Da( 9,19) + dt*dy**2
        Da(10,19) = Da(10,19) + dt*dz**2
        Da(11,19) = Da(11,19) + dt*dx*dy**2
        Da(12,19) = Da(12,19) + dt*dy*dz**2
        Da(13,19) = Da(13,19) + dt*dz*dx**2
        Da(14,19) = Da(14,19) + dt*dx**2*dy
        Da(15,19) = Da(15,19) + dt*dy**2*dz
        Da(16,19) = Da(16,19) + dt*dz**2*dx
        Da(17,19) = Da(17,19) + dt*(dx**3*dy - dx*dy**3)
        Da(18,19) = Da(18,19) + dt*(dy**3*dz - dy*dz**3)
        Da(19,19) = Da(19,19) + dt*(dz**3*dx - dz*dx**3)

      end do ! i

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 7: Invert coefficient matrix
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      call mprim_invertMatrixPivot(Da, NBAS,bsuccess)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 8: Evaluate function values
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      if(Bder(DER_FUNC3D)) then

        ! Loop over all points then
        do ipt = 1, reval%npointsPerElement

          dx1 = reval%p_DpointsReal(1,ipt,iel) - Dr(1)
          dy1 = reval%p_DpointsReal(2,ipt,iel) - Dr(2)
          dz1 = reval%p_DpointsReal(3,ipt,iel) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Evaluate basis functions
          do i = 1, NBAS

            Dbas(i,DER_FUNC3D,ipt,iel) = Da(i,1) &
              + dx*(Da(i,2) + dy*Da(i,5) + dx*(Da(i,8) &
                  + dz*(Da(i,13) - dx*Da(i,19)) &
                  + dy*(Da(i,14) + dx*Da(i,17)))) &
              + dy*(Da(i,3) + dz*Da(i,6) + dy*(Da(i,9) &
                  + dx*(Da(i,11) - dy*Da(i,17)) &
                  + dz*(Da(i,15) + dy*Da(i,18)))) &
              + dz*(Da(i,4) + dx*Da(i,7) + dz*(Da(i,10) &
                  + dy*(Da(i,12) - dz*Da(i,18)) &
                  + dx*(Da(i,16) + dz*Da(i,19))))

          end do ! i

        end do ! ipt

      end if ! function values evaluation

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 9: Evaluate derivatives
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

        ! Loop over all points then
        do ipt = 1, reval%npointsPerElement

          dx1 = reval%p_DpointsReal(1,ipt,iel) - Dr(1)
          dy1 = reval%p_DpointsReal(2,ipt,iel) - Dr(2)
          dz1 = reval%p_DpointsReal(3,ipt,iel) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Evaluate derivatives
          do i = 1, NBAS

            ! Calculate 'reference' derivatives
            derx = Da(i,2) &
              + dy*(Da(i,5) + dy*(Da(i,11) - dy*Da(i,17))) &
              + dz*(Da(i,7) + dz*(Da(i,16) + dz*Da(i,19))) &
              + 2.0_DP*dx*(Da(i,8) + dy*Da(i,14) + dz*Da(i,13) &
              + 1.5_DP*dx*(dy*Da(i,17) - dz*Da(i,19)))
            dery = Da(i,3) &
              + dz*(Da(i,6) + dz*(Da(i,12) - dz*Da(i,18))) &
              + dx*(Da(i,5) + dx*(Da(i,14) + dx*Da(i,17))) &
              + 2.0_DP*dy*(Da(i,9) + dz*Da(i,15) + dx*Da(i,11) &
              + 1.5_DP*dy*(dz*Da(i,18) - dx*Da(i,17)))
            derz = Da(i,4) &
              + dx*(Da(i,7) + dx*(Da(i,13) - dx*Da(i,19))) &
              + dy*(Da(i,6) + dy*(Da(i,15) + dy*Da(i,18))) &
              + 2.0_DP*dz*(Da(i,10) + dx*Da(i,16) + dy*Da(i,12) &
              + 1.5_DP*dz*(dx*Da(i,19) - dy*Da(i,18)))

            ! Calculate 'real' derivatives
            Dbas(i,DER_DERIV3D_X,ipt,iel) = &
              Ds(1,1)*derx + Ds(2,1)*dery + Ds(3,1)*derz
            Dbas(i,DER_DERIV3D_Y,ipt,iel) = &
              Ds(1,2)*derx + Ds(2,2)*dery + Ds(3,2)*derz
            Dbas(i,DER_DERIV3D_Z,ipt,iel) = &
              Ds(1,3)*derx + Ds(2,3)*dery + Ds(3,3)*derz

          end do ! i

        end do ! ipt

      end if ! derivatives evaluation

    end do ! iel
    !$omp end parallel do

  end subroutine

  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_MSL2_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

!</subroutine>

  ! Element Description
  ! -------------------
  ! The MSL2_3D element is specified by fourteen polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x^2, y^2, z^2, xy, xz, yz, xyz, x*(x^2 - 3/5*(y^2 + z^2)),
  !   y*(y^2 - 3/5*(x^2 + z^2)), z*(z^2 - 3/5*(x^2 + y^2)) }
  !
  ! see:
  ! Z. Meng, D. Sheen, Z. Luo:
  ! "Three-dimensional quadratic nonconforming brick element";
  ! pre-print
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,14:
  ! {
  !   For all j = 1,...,8:
  !   {
  !     Pi(vj) = kronecker(i,j)
  !   }
  !   For all j = 1,...,6:
  !   {
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))) d(x,y) = kronecker(i+8,j) * |fj|
  !     <==>
  !     Int_fj Pi(x,y) d(x,y) = kronecker(i+8,j) * |fj|
  !   }
  ! }
  !
  ! With:
  ! vj being the j-th local vertex of the hexahedron
  ! fj being the j-th local face of the hexahedron
  ! |fj| being the area of the face fj
  ! Fj: [-1,1]^2 -> fj being the parametrisation of the face fj
  ! |DFj(x,y)| being the determinant of the Jacobi-Matrix of Fj in the point (x,y)
  !
  ! On the reference element, the above combination of monomial set and
  ! basis polynomial conditions leads to the following basis polynomials:
  ! ...

  ! Parameter: number of local basis functions
  integer, parameter :: NBAS = 14

  ! derivatives on reference element
  real(DP), dimension(NBAS,NDIM3D) :: DrefDer

  ! Local variables
  real(DP) :: ddet,dx,dy,dz
  integer :: i,j

    ! Calculate function values?
    if(Bder(DER_FUNC3D)) then

      ! Loop through all elements
      !$omp parallel do defaulT(shared) private(i,dx,dy,dz) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements

        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement

          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)

          Dbas( 1,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*(-dx - dy - dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*( dx*dy + dx*dz + dy*dz - dx*dy*dz) &
            + dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            + dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            + dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 2,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*( dx - dy - dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*(-dx*dy - dx*dz + dy*dz + dx*dy*dz) &
            - dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            + dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            + dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 3,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*( dx + dy - dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*( dx*dy - dx*dz - dy*dz - dx*dy*dz) &
            - dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            - dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            + dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 4,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*(-dx + dy - dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*(-dx*dy + dx*dz - dy*dz + dx*dy*dz) &
            + dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            - dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            + dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 5,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*(-dx - dy + dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*( dx*dy - dx*dz - dy*dz + dx*dy*dz) &
            + dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            + dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            - dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 6,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*( dx - dy + dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*(-dx*dy + dx*dz - dy*dz - dx*dy*dz) &
            - dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            + dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            - dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 7,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*( dx + dy + dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*( dx*dy + dx*dz + dy*dz + dx*dy*dz) &
            - dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            - dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            - dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 8,DER_FUNC3D,i,j) = (-5.0_DP + 3.0_DP*(-dx + dy + dz + dx**2 + dy**2 + dz**2) &
            + 4.0_DP*(-dx*dy - dx*dz + dy*dz - dx*dy*dz) &
            + dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2)) &
            - dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2)) &
            - dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 32.0_DP
          Dbas( 9,DER_FUNC3D,i,j) = (3.0_DP - dz + 3.0_DP*(-dx**2 - dy**2 + dz**2) &
            - dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 8.0_DP
          Dbas(10,DER_FUNC3D,i,j) = (3.0_DP - dy + 3.0_DP*(-dx**2 + dy**2 - dz**2) &
            - dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2))) / 8.0_DP
          Dbas(11,DER_FUNC3D,i,j) = (3.0_DP + dx + 3.0_DP*( dx**2 - dy**2 - dz**2) &
            + dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2))) / 8.0_DP
          Dbas(12,DER_FUNC3D,i,j) = (3.0_DP + dy + 3.0_DP*(-dx**2 + dy**2 - dz**2) &
            + dy*(5.0_DP*dy**2 - 3.0_DP*(dx**2 + dz**2))) / 8.0_DP
          Dbas(13,DER_FUNC3D,i,j) = (3.0_DP - dx + 3.0_DP*( dx**2 - dy**2 - dz**2) &
            - dx*(5.0_DP*dx**2 - 3.0_DP*(dy**2 + dz**2))) / 8.0_DP
          Dbas(14,DER_FUNC3D,i,j) = (3.0_DP + dz + 3.0_DP*(-dx**2 - dy**2 + dz**2) &
            + dz*(5.0_DP*dz**2 - 3.0_DP*(dx**2 + dy**2))) / 8.0_DP
        end do ! i

      end do ! j
      !$omp end parallel do

    end if

    ! Calculate derivatives?
    if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then
    
      ! Loop through all elements
      !$omp parallel do defaulT(shared) private(i,dx,dy,dz,ddet,DrefDer) &
      !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
      do j = 1, reval%nelements
    
        ! Loop through all points on the current element
        do i = 1, reval%npointsPerElement
    
          ! Get the point coordinates
          dx = reval%p_DpointsRef(1,i,j)
          dy = reval%p_DpointsRef(2,i,j)
          dz = reval%p_DpointsRef(3,i,j)
    
          ! Remark: Please note that the following code is universal and does
          ! not need to be modified for other parametric 3D hexahedron elements!

          ! X-Derivatives
          DrefDer( 1,1) = (-3.0_DP + 6.0_DP*dx + 4.0_DP*dy + 4.0_DP*dz - 4.0_DP*dy*dz + 15.0_DP*dx**2 &
                        - 3.0_DP*dy**2 - 3.0_DP*dz**2 - 6.0_DP*dx*dy - 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 2,1) = ( 3.0_DP + 6.0_DP*dx - 4.0_DP*dy - 4.0_DP*dz + 4.0_DP*dy*dz - 15.0_DP*dx**2 &
                        + 3.0_DP*dy**2 + 3.0_DP*dz**2 - 6.0_DP*dx*dy - 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 3,1) = ( 3.0_DP + 6.0_DP*dx + 4.0_DP*dy - 4.0_DP*dz - 4.0_DP*dy*dz - 15.0_DP*dx**2 &
                        + 3.0_DP*dy**2 + 3.0_DP*dz**2 + 6.0_DP*dx*dy - 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 4,1) = (-3.0_DP + 6.0_DP*dx - 4.0_DP*dy + 4.0_DP*dz + 4.0_DP*dy*dz + 15.0_DP*dx**2 &
                        - 3.0_DP*dy**2 - 3.0_DP*dz**2 + 6.0_DP*dx*dy - 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 5,1) = (-3.0_DP + 6.0_DP*dx + 4.0_DP*dy - 4.0_DP*dz + 4.0_DP*dy*dz + 15.0_DP*dx**2 &
                        - 3.0_DP*dy**2 - 3.0_DP*dz**2 - 6.0_DP*dx*dy + 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 6,1) = ( 3.0_DP + 6.0_DP*dx - 4.0_DP*dy + 4.0_DP*dz - 4.0_DP*dy*dz - 15.0_DP*dx**2 &
                        + 3.0_DP*dy**2 + 3.0_DP*dz**2 - 6.0_DP*dx*dy + 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 7,1) = ( 3.0_DP + 6.0_DP*dx + 4.0_DP*dy + 4.0_DP*dz + 4.0_DP*dy*dz - 15.0_DP*dx**2 &
                        + 3.0_DP*dy**2 + 3.0_DP*dz**2 + 6.0_DP*dx*dy + 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 8,1) = (-3.0_DP + 6.0_DP*dx - 4.0_DP*dy - 4.0_DP*dz - 4.0_DP*dy*dz + 15.0_DP*dx**2 &
                        - 3.0_DP*dy**2 - 3.0_DP*dz**2 + 6.0_DP*dx*dy + 6.0_DP*dx*dz) / 32.0_DP
          DrefDer( 9,1) = (-6.0_DP*dx + 6.0_DP*dx*dz) / 8.0_DP
          DrefDer(10,1) = (-6.0_DP*dx + 6.0_DP*dx*dy) / 8.0_DP
          DrefDer(11,1) = ( 1.0_DP + 6.0_DP*dx + 15.0_DP*dx**2 - 3.0_DP*dy**2 - 3.0_DP*dz**2) / 8.0_DP
          DrefDer(12,1) = (-6.0_DP*dx - 6.0_DP*dx*dy) / 8.0_DP
          DrefDer(13,1) = (-1.0_DP + 6.0_DP*dx - 15.0_DP*dx**2 + 3.0_DP*dy**2 + 3.0_DP*dz**2) / 8.0_DP
          DrefDer(14,1) = (-6.0_DP*dx - 6.0_DP*dx*dz) / 8.0_DP

          ! Y-Derivatives
          DrefDer( 1,2) = (-3.0_DP + 6.0_DP*dy + 4.0_DP*dx + 4.0_DP*dz - 4.0_DP*dx*dz - 6.0_DP*dx*dy &
                        + 15.0_DP*dy**2 - 3.0_DP*dx**2 - 3.0_DP*dz**2 - 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 2,2) = (-3.0_DP + 6.0_DP*dy - 4.0_DP*dx + 4.0_DP*dz + 4.0_DP*dx*dz + 6.0_DP*dx*dy &
                        + 15.0_DP*dy**2 - 3.0_DP*dx**2 - 3.0_DP*dz**2 - 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 3,2) = ( 3.0_DP + 6.0_DP*dy + 4.0_DP*dx - 4.0_DP*dz - 4.0_DP*dx*dz + 6.0_DP*dx*dy &
                        - 15.0_DP*dy**2 + 3.0_DP*dx**2 + 3.0_DP*dz**2 - 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 4,2) = ( 3.0_DP + 6.0_DP*dy - 4.0_DP*dx - 4.0_DP*dz + 4.0_DP*dx*dz - 6.0_DP*dx*dy &
                        - 15.0_DP*dy**2 + 3.0_DP*dx**2 + 3.0_DP*dz**2 - 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 5,2) = (-3.0_DP + 6.0_DP*dy + 4.0_DP*dx - 4.0_DP*dz + 4.0_DP*dx*dz - 6.0_DP*dx*dy &
                        + 15.0_DP*dy**2 - 3.0_DP*dx**2 - 3.0_DP*dz**2 + 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 6,2) = (-3.0_DP + 6.0_DP*dy - 4.0_DP*dx - 4.0_DP*dz - 4.0_DP*dx*dz + 6.0_DP*dx*dy &
                        + 15.0_DP*dy**2 - 3.0_DP*dx**2 - 3.0_DP*dz**2 + 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 7,2) = ( 3.0_DP + 6.0_DP*dy + 4.0_DP*dx + 4.0_DP*dz + 4.0_DP*dx*dz + 6.0_DP*dx*dy &
                        - 15.0_DP*dy**2 + 3.0_DP*dx**2 + 3.0_DP*dz**2 + 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 8,2) = ( 3.0_DP + 6.0_DP*dy - 4.0_DP*dx + 4.0_DP*dz - 4.0_DP*dx*dz - 6.0_DP*dx*dy &
                        - 15.0_DP*dy**2 + 3.0_DP*dx**2 + 3.0_DP*dz**2 + 6.0_DP*dy*dz) / 32.0_DP
          DrefDer( 9,2) = (-6.0_DP*dy + 6.0_DP*dy*dz) / 8.0_DP
          DrefDer(10,2) = (-1.0_DP + 6.0_DP*dy - 15.0_DP*dy**2 + 3.0_DP*dx**2 + 3.0_DP*dz**2) / 8.0_DP
          DrefDer(11,2) = (-6.0_DP*dy - 6.0_DP*dx*dy) / 8.0_DP
          DrefDer(12,2) = ( 1.0_DP + 6.0_DP*dy + 15.0_DP*dy**2 - 3.0_DP*dx**2 - 3.0_DP*dz**2) / 8.0_DP
          DrefDer(13,2) = (-6.0_DP*dy + 6.0_DP*dx*dy) / 8.0_DP
          DrefDer(14,2) = (-6.0_DP*dy - 6.0_DP*dy*dz) / 8.0_DP

          ! Z-Derivatives
          DrefDer( 1,3) = (-3.0_DP + 6.0_DP*dz + 4.0_DP*dx + 4.0_DP*dy - 4.0_DP*dx*dy - 6.0_DP*dx*dz &
                        - 6.0_DP*dy*dz + 15.0_DP*dz**2 - 3.0_DP*dx**2 - 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 2,3) = (-3.0_DP + 6.0_DP*dz - 4.0_DP*dx + 4.0_DP*dy + 4.0_DP*dx*dy + 6.0_DP*dx*dz &
                        - 6.0_DP*dy*dz + 15.0_DP*dz**2 - 3.0_DP*dx**2 - 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 3,3) = (-3.0_DP + 6.0_DP*dz - 4.0_DP*dx - 4.0_DP*dy - 4.0_DP*dx*dy + 6.0_DP*dx*dz &
                        + 6.0_DP*dy*dz + 15.0_DP*dz**2 - 3.0_DP*dx**2 - 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 4,3) = (-3.0_DP + 6.0_DP*dz + 4.0_DP*dx - 4.0_DP*dy + 4.0_DP*dx*dy - 6.0_DP*dx*dz &
                        + 6.0_DP*dy*dz + 15.0_DP*dz**2 - 3.0_DP*dx**2 - 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 5,3) = ( 3.0_DP + 6.0_DP*dz - 4.0_DP*dx - 4.0_DP*dy + 4.0_DP*dx*dy - 6.0_DP*dx*dz &
                        - 6.0_DP*dy*dz - 15.0_DP*dz**2 + 3.0_DP*dx**2 + 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 6,3) = ( 3.0_DP + 6.0_DP*dz + 4.0_DP*dx - 4.0_DP*dy - 4.0_DP*dx*dy + 6.0_DP*dx*dz &
                        - 6.0_DP*dy*dz - 15.0_DP*dz**2 + 3.0_DP*dx**2 + 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 7,3) = ( 3.0_DP + 6.0_DP*dz + 4.0_DP*dx + 4.0_DP*dy + 4.0_DP*dx*dy + 6.0_DP*dx*dz &
                        + 6.0_DP*dy*dz - 15.0_DP*dz**2 + 3.0_DP*dx**2 + 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 8,3) = ( 3.0_DP + 6.0_DP*dz - 4.0_DP*dx + 4.0_DP*dy - 4.0_DP*dx*dy - 6.0_DP*dx*dz &
                        + 6.0_DP*dy*dz - 15.0_DP*dz**2 + 3.0_DP*dx**2 + 3.0_DP*dy**2) / 32.0_DP
          DrefDer( 9,3) = (-1.0_DP + 6.0_DP*dz - 15.0_DP*dz**2 + 3.0_DP*dx**2 + 3.0_DP*dy**2) / 8.0_DP
          DrefDer(10,3) = (-6.0_DP*dz + 6.0_DP*dy*dz) / 8.0_DP
          DrefDer(11,3) = (-6.0_DP*dz - 6.0_DP*dx*dz) / 8.0_DP
          DrefDer(12,3) = (-6.0_DP*dz - 6.0_DP*dy*dz) / 8.0_DP
          DrefDer(13,3) = (-6.0_DP*dz + 6.0_DP*dx*dz) / 8.0_DP
          DrefDer(14,3) = ( 1.0_DP + 6.0_DP*dz + 15.0_DP*dz**2 - 3.0_DP*dx**2 - 3.0_DP*dy**2) / 8.0_DP

          ! Get jacobian determinant
          ddet = 1.0_DP / reval%p_Ddetj(i,j)
    
          ! X-derivatives on real element
          dx = (reval%p_Djac(5,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(6,i,j)*reval%p_Djac(8,i,j))*ddet
          dy = (reval%p_Djac(8,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(2,i,j)*reval%p_Djac(9,i,j))*ddet
          dz = (reval%p_Djac(2,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(5,i,j)*reval%p_Djac(3,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_X,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)
    
          ! Y-derivatives on real element
          dx = (reval%p_Djac(7,i,j)*reval%p_Djac(6,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(9,i,j))*ddet
          dy = (reval%p_Djac(1,i,j)*reval%p_Djac(9,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(3,i,j))*ddet
          dz = (reval%p_Djac(4,i,j)*reval%p_Djac(3,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(6,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Y,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)
    
          ! Z-derivatives on real element
          dx = (reval%p_Djac(4,i,j)*reval%p_Djac(8,i,j)&
               -reval%p_Djac(7,i,j)*reval%p_Djac(5,i,j))*ddet
          dy = (reval%p_Djac(7,i,j)*reval%p_Djac(2,i,j)&
               -reval%p_Djac(1,i,j)*reval%p_Djac(8,i,j))*ddet
          dz = (reval%p_Djac(1,i,j)*reval%p_Djac(5,i,j)&
               -reval%p_Djac(4,i,j)*reval%p_Djac(2,i,j))*ddet
          Dbas(1:NBAS,DER_DERIV3D_Z,i,j) = dx*DrefDer(1:NBAS,1) &
                  + dy*DrefDer(1:NBAS,2) + dz*DrefDer(1:NBAS,3)
    
        end do ! i
    
      end do ! j
      !$omp end parallel do
    
    end if

  end subroutine
  
  !************************************************************************

!<subroutine>

#ifndef USE_OPENMP
  pure &
#endif

  subroutine elem_eval_MSL2NP_3D (celement, reval, Bder, Dbas)

!<description>
  ! This subroutine simultaneously calculates the values of the basic
  ! functions of the finite element at multiple given points on the
  ! reference element for multiple given elements.
!</description>

!<input>
  ! The element specifier.
  integer(I32), intent(in)                       :: celement

  ! t_evalElementSet-structure that contains cell-specific information and
  ! coordinates of the evaluation points. revalElementSet must be prepared
  ! for the evaluation.
  type(t_evalElementSet), intent(in)             :: reval

  ! Derivative quantifier array. array [1..DER_MAXNDER] of boolean.
  ! If bder(DER_xxxx)=true, the corresponding derivative (identified
  ! by DER_xxxx) is computed by the element (if supported). Otherwise,
  ! the element might skip the computation of that value type, i.e.
  ! the corresponding value 'Dvalue(DER_xxxx)' is undefined.
  logical, dimension(:), intent(in)              :: Bder
!</input>

!<output>
  ! Value/derivatives of basis functions.
  ! array [1..EL_MAXNBAS,1..DER_MAXNDER,1..npointsPerElement,nelements] of double
  ! Bder(DER_FUNC)=true  => Dbas(i,DER_FUNC,j) defines the value of the i-th
  !   basis function of the finite element in the point Dcoords(j) on the
  !   reference element,
  !   Dvalue(i,DER_DERIV_X) the value of the x-derivative of the i-th
  !   basis function,...
  ! Bder(DER_xxxx)=false => Dbas(i,DER_xxxx,.) is undefined.
  real(DP), dimension(:,:,:,:), intent(out)      :: Dbas
!</output>

! </subroutine>

  ! Element Description
  ! -------------------
  ! The MSL2_3D element is specified by fourteen polynomials per element.
  !
  ! The basis polynomials are constructed from the following set of monomials:
  ! { 1, x, y, z, x^2, y^2, z^2, xy, xz, yz, xyz, x*(x^2 - 3/5*(y^2 + z^2)),
  !   y*(y^2 - 3/5*(x^2 + z^2)), z*(z^2 - 3/5*(x^2 + y^2)) }
  !
  ! see:
  ! Z. Meng, D. Sheen, Z. Luo:
  ! "Three-dimensional quadratic nonconforming brick element";
  ! pre-print
  !
  ! The basis polynomials Pi are constructed such that they fulfill the
  ! following conditions:
  !
  ! For all i = 1,...,14:
  ! {
  !   For all j = 1,...,8:
  !   {
  !     Pi(vj) = kronecker(i,j)
  !   }
  !   For all j = 1,...,6:
  !   {
  !     Int_[-1,1]^2 (|DFj(x,y)|*Pi(Fj(x,y))) d(x,y) = kronecker(i+8,j) * |fj|
  !     <==>
  !     Int_fj Pi(x,y) d(x,y) = kronecker(i+8,j) * |fj|
  !   }
  ! }
  !
  ! With:
  ! vj being the j-th local vertex of the hexahedron
  ! fj being the j-th local face of the hexahedron
  ! |fj| being the area of the face fj
  ! Fj: [-1,1]^2 -> fj being the parametrisation of the face fj
  ! |DFj(x,y)| being the determinant of the Jacobi-Matrix of Fj in the point (x,y)

  ! Parameter: Number of local basis functions
  integer, parameter :: NBAS = 14

  ! Parameter: Number of cubature points for 1D edge integration
  integer, parameter :: NCUB1D = 3

  ! Parameter: Number of cubature points for 2D quad integration
  integer, parameter :: NCUB2D = NCUB1D**2

  ! 1D edge cubature rule point coordinates and weights
  real(DP), dimension(NCUB1D) :: DcubPts1D
  real(DP), dimension(NCUB1D) :: DcubOmega1D

  ! 2D quad cubature rule point coordinates and weights
  real(DP), dimension(NDIM2D, NCUB2D) :: DcubPts2D
  real(DP), dimension(NCUB2D) :: DcubOmega2D

  ! Corner vertice coordinates
  real(DP), dimension(NDIM3D, 8) :: Dvert

  ! Local mapped 2D cubature point coordinates and integration weights
  real(DP), dimension(NDIM3D, NCUB2D, 6) :: DfacePoints
  real(DP), dimension(NCUB2D, 6) :: DfaceWeights
  real(DP), dimension(6) :: DfaceArea

  ! Temporary variables for face vertice mapping
  real(DP), dimension(4,3) :: Dft

  ! Coefficients for inverse affine transformation
  real(DP), dimension(NDIM3D,NDIM3D) :: Ds, Dat
  real(DP), dimension(NDIM3D) :: Dr

  ! other local variables
  integer :: i,j,l,iel, ipt
  real(DP), dimension(NBAS,NBAS) :: Da
  real(DP) :: dx,dy,dz,dt,derx,dery,derz,dx1,dy1,dz1
  logical :: bsuccess

    ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    ! Step 0: Set up 1D and 2D cubature rules
    ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    ! Set up a 3-point Gauss rule for 1D
    ! Remark: Although we do not actually need the 1D formula for integration,
    ! it is used a few lines below to set up the 2D and 3D formulas...
    DcubPts1D(1) = -sqrt(3.0_DP / 5.0_DP)
    DcubPts1D(2) = 0.0_DP
    DcubPts1D(3) = sqrt(3.0_DP / 5.0_DP)
    DcubOmega1D(1) = 5.0_DP / 9.0_DP
    DcubOmega1D(2) = 8.0_DP / 9.0_DP
    DcubOmega1D(3) = 5.0_DP / 9.0_DP

!    ! !!! DEBUG: 5-point Gauss rule !!!
!    dt = 2.0_DP*sqrt(10.0_DP / 7.0_DP)
!    DcubPts1D(1) = -sqrt(5.0_DP + dt) / 3.0_DP
!    DcubPts1D(2) = -sqrt(5.0_DP - dt) / 3.0_DP
!    DcubPts1D(3) = 0.0_DP
!    DcubPts1D(4) =  sqrt(5.0_DP - dt) / 3.0_DP
!    DcubPts1D(5) =  sqrt(5.0_DP + dt) / 3.0_DP
!    dt = 13.0_DP*sqrt(70.0_DP)
!    DcubOmega1D(1) = (322.0_DP - dt) / 900.0_DP
!    DcubOmega1D(2) = (322.0_DP + dt) / 900.0_DP
!    DcubOmega1D(3) = 128.0_DP / 225.0_DP
!    DcubOmega1D(4) = (322.0_DP + dt) / 900.0_DP
!    DcubOmega1D(5) = (322.0_DP - dt) / 900.0_DP

    ! Set up a 3x3-point Gauss rule for 2D
    l = 1
    do i = 1, NCUB1D
      do j = 1, NCUB1D
        DcubPts2D(1,l) = DcubPts1D(i)
        DcubPts2D(2,l) = DcubPts1D(j)
        DcubOmega2D(l) = DcubOmega1D(i)*DcubOmega1D(j)
        l = l+1
      end do
    end do

    ! Loop over all elements
    !$omp parallel do default(shared)&
    !$omp private(Da,Dat,DfacePoints,DfaceWeights,Dr,Ds,Dvert,bsuccess,&
    !$omp         derx,dery,derz,dt,dx,dx1,dy,dy1,dz,dz1,i,ipt,j)&
    !$omp if(reval%nelements > reval%p_rperfconfig%NELEMMIN_OMP)
    do iel = 1, reval%nelements

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 1: Fetch vertice coordinates
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Fetch the eight corner vertices for that element
      Dvert(1:3,1:8) = reval%p_Dcoords(1:3,1:8,iel)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 2: Calculate inverse affine transformation
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      Dr(:) = 0.125_DP * (Dvert(:,1) + Dvert(:,2) + Dvert(:,3) + Dvert(:,4) &
                         +Dvert(:,5) + Dvert(:,6) + Dvert(:,7) + Dvert(:,8))

      ! Set up affine trafo
      Dat(:,1) = 0.25_DP * (Dvert(:,2)+Dvert(:,3)+Dvert(:,7)+Dvert(:,6))-Dr(:)
      Dat(:,2) = 0.25_DP * (Dvert(:,3)+Dvert(:,4)+Dvert(:,8)+Dvert(:,7))-Dr(:)
      Dat(:,3) = 0.25_DP * (Dvert(:,5)+Dvert(:,6)+Dvert(:,7)+Dvert(:,8))-Dr(:)

      ! And invert it
      call mprim_invert3x3MatrixDirect(Dat,Ds,bsuccess)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 3: Map 2D cubature points onto the real faces
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Map the 2D cubature points onto the real faces and calculate the
      ! integration weighting factors in this step.
      do j = 1, 6

        ! Calculate trafo for this face
        call elh3d_calcFaceTrafo_Q1(Dft,j,Dvert)

        ! Loop over all cubature points
        do i = 1, NCUB2D

          ! Get the cubature point coordinates
          dx = DcubPts2D(1,i)
          dy = DcubPts2D(2,i)

          ! Transform the point
          DfacePoints(1,i,j) = Dft(1,1)+Dft(2,1)*dx+Dft(3,1)*dy+Dft(4,1)*dx*dy
          DfacePoints(2,i,j) = Dft(1,2)+Dft(2,2)*dx+Dft(3,2)*dy+Dft(4,2)*dx*dy
          DfacePoints(3,i,j) = Dft(1,3)+Dft(2,3)*dx+Dft(3,3)*dy+Dft(4,3)*dx*dy

          ! Calculate jacobi-determinant of mapping
          ! TODO: Explain WTF is happening here...
          dt = sqrt(((Dft(2,2) + Dft(4,2)*dy)*(Dft(3,3) + Dft(4,3)*dx) &
                    -(Dft(2,3) + Dft(4,3)*dy)*(Dft(3,2) + Dft(4,2)*dx))**2 &
                  + ((Dft(2,3) + Dft(4,3)*dy)*(Dft(3,1) + Dft(4,1)*dx) &
                    -(Dft(2,1) + Dft(4,1)*dy)*(Dft(3,3) + Dft(4,3)*dx))**2 &
                  + ((Dft(2,1) + Dft(4,1)*dy)*(Dft(3,2) + Dft(4,2)*dx) &
                    -(Dft(2,2) + Dft(4,2)*dy)*(Dft(3,1) + Dft(4,1)*dx))**2)

          ! Calculate integration weight
          DfaceWeights(i,j) = dt * DcubOmega2D(i)

        end do ! i

      end do ! j

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 4: Calculate face areas
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Calculate the inverse of the face areas - we will need them for
      ! scaling later...
      do j = 1, 6
        dt = 0.0_DP
        do i = 1, NCUB2D
          dt = dt + DfaceWeights(i,j)
        end do
        DfaceArea(j) = 1.0_DP / dt
      end do

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 5: Build coefficient matrix
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      ! Clear coefficient matrix
      Da = 0.0_DP

      ! Loop over all vertices of the hexahedron
      do j = 1, 8

        dx1 = Dvert(1,j) - Dr(1)
        dy1 = Dvert(2,j) - Dr(2)
        dz1 = Dvert(3,j) - Dr(3)

        ! Apply inverse affine trafo to get (x,y,z)
        dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
        dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
        dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

        ! Function values in the vertices
        ! -------------------------------
        Da( 1,j) = 1.0_DP
        Da( 2,j) = dx
        Da( 3,j) = dy
        Da( 4,j) = dz
        Da( 5,j) = dx**2
        Da( 6,j) = dy**2
        Da( 7,j) = dz**2
        Da( 8,j) = dx*dy
        Da( 9,j) = dx*dz
        Da(10,j) = dy*dz
        Da(11,j) = dx*dy*dz
        Da(12,j) = dx*(dx**2 - 0.6_DP*(dy**2 + dz**2))
        Da(13,j) = dy*(dy**2 - 0.6_DP*(dx**2 + dz**2))
        Da(14,j) = dz*(dz**2 - 0.6_DP*(dx**2 + dy**2))

      end do

      ! Loop over all faces of the hexahedron
      do j = 1, 6

        ! Loop over all cubature points on the current face
        do i = 1, NCUB2D

          dx1 = DfacePoints(1,i,j) - Dr(1)
          dy1 = DfacePoints(2,i,j) - Dr(2)
          dz1 = DfacePoints(3,i,j) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Integral-Mean over the faces
          ! ----------------------------
          dt = DfaceWeights(i,j) * DfaceArea(j)

          Da( 1,j+8) = Da( 1,j+8) + dt
          Da( 2,j+8) = Da( 2,j+8) + dt*dx
          Da( 3,j+8) = Da( 3,j+8) + dt*dy
          Da( 4,j+8) = Da( 4,j+8) + dt*dz
          Da( 5,j+8) = Da( 5,j+8) + dt*dx**2
          Da( 6,j+8) = Da( 6,j+8) + dt*dy**2
          Da( 7,j+8) = Da( 7,j+8) + dt*dz**2
          Da( 8,j+8) = Da( 8,j+8) + dt*dx*dy
          Da( 9,j+8) = Da( 9,j+8) + dt*dx*dz
          Da(10,j+8) = Da(10,j+8) + dt*dy*dz
          Da(11,j+8) = Da(11,j+8) + dt*dx*dy*dz
          Da(12,j+8) = Da(12,j+8) + dt*dx*(dx**2 - 0.6_DP*(dy**2 + dz**2))
          Da(13,j+8) = Da(13,j+8) + dt*dy*(dy**2 - 0.6_DP*(dx**2 + dz**2))
          Da(14,j+8) = Da(14,j+8) + dt*dz*(dz**2 - 0.6_DP*(dx**2 + dy**2))

        end do ! i

      end do ! j

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 6: Invert coefficient matrix
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Call the 'direct' inversion routine for 6x6 systems
      call mprim_invertMatrixPivot(Da, NBAS,bsuccess)

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 8: Evaluate function values
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      if(Bder(DER_FUNC3D)) then

        ! Loop over all points then
        do ipt = 1, reval%npointsPerElement

          dx1 = reval%p_DpointsReal(1,ipt,iel) - Dr(1)
          dy1 = reval%p_DpointsReal(2,ipt,iel) - Dr(2)
          dz1 = reval%p_DpointsReal(3,ipt,iel) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Evaluate basis functions
          do i = 1, NBAS

            Dbas(i,DER_FUNC3D,ipt,iel) = Da(i,1) + dx*dy*dz*Da(i,11) &
              + dx*(Da(i,2) + dx*Da(i,5) + dy*Da(i,8) &
                    + (dx**2 - 0.6_DP*(dy**2 + dz**2))*Da(i,12)) &
              + dy*(Da(i,3) + dy*Da(i,6) + dz*Da(i,10) &
                    + (dy**2 - 0.6_DP*(dx**2 + dz**2))*Da(i,13)) &
              + dz*(Da(i,4) + dz*Da(i,7) + dx*Da(i,9) &
                    + (dz**2 - 0.6_DP*(dx**2 + dy**2))*Da(i,14))

          end do ! i

        end do ! ipt

      end if ! function values evaluation

      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
      ! Step 9: Evaluate derivatives
      ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

      if(Bder(DER_DERIV3D_X) .or. Bder(DER_DERIV3D_Y) .or. Bder(DER_DERIV3D_Z)) then

        ! Loop over all points then
        do ipt = 1, reval%npointsPerElement

          dx1 = reval%p_DpointsReal(1,ipt,iel) - Dr(1)
          dy1 = reval%p_DpointsReal(2,ipt,iel) - Dr(2)
          dz1 = reval%p_DpointsReal(3,ipt,iel) - Dr(3)

          ! Apply inverse affine trafo to get (x,y,z)
          dx = Ds(1,1)*dx1 + Ds(1,2)*dy1 + Ds(1,3)*dz1
          dy = Ds(2,1)*dx1 + Ds(2,2)*dy1 + Ds(2,3)*dz1
          dz = Ds(3,1)*dx1 + Ds(3,2)*dy1 + Ds(3,3)*dz1

          ! Evaluate derivatives
          do i = 1, NBAS

            ! Calculate 'reference' derivatives
            derx = Da(i,2) + 2.0_DP*dx*Da(i,5) + dy*Da(i,8) + dz*Da(i, 9) + dy*dz*Da(i,11) &
                 + (3.0_DP*dx**2 - 0.6_DP*(dy**2 + dz**2))*Da(i,12) &
                 - 1.2_DP*dx*(dy*Da(i,13) + dz*Da(i,14))
            dery = Da(i,3) + 2.0_DP*dy*Da(i,6) + dx*Da(i,8) + dz*Da(i,10) + dx*dz*Da(i,11) &
                 + (3.0_DP*dy**2 - 0.6_DP*(dx**2 + dz**2))*Da(i,13) &
                 - 1.2_DP*dy*(dx*Da(i,12) + dz*Da(i,14))
            derz = Da(i,4) + 2.0_DP*dz*Da(i,7) + dx*Da(i,9) + dy*Da(i,10) + dx*dy*Da(i,11) &
                 + (3.0_DP*dz**2 - 0.6_DP*(dx**2 + dy**2))*Da(i,14) &
                 - 1.2_DP*dz*(dx*Da(i,12) + dy*Da(i,13))

            ! Calculate 'real' derivatives
            Dbas(i,DER_DERIV3D_X,ipt,iel) = &
              Ds(1,1)*derx + Ds(2,1)*dery + Ds(3,1)*derz
            Dbas(i,DER_DERIV3D_Y,ipt,iel) = &
              Ds(1,2)*derx + Ds(2,2)*dery + Ds(3,2)*derz
            Dbas(i,DER_DERIV3D_Z,ipt,iel) = &
              Ds(1,3)*derx + Ds(2,3)*dery + Ds(3,3)*derz

          end do ! i

        end do ! ipt

      end if ! derivatives evaluation

    end do ! iel
    !$omp end parallel do

  end subroutine

  ! ***************************************************************************

!<subroutine>

  pure subroutine elh3d_calcFaceTrafo_Q1(Dt,iface,Dv)

!<description>
  ! PRIVATE AUXILIARY ROUTINE:
  ! This auxiliary subroutine calculates the transformation coefficients for
  ! a bilinear transformation from [-1,1]x[-1,1] onto one of the hexahedron`s
  ! local faces.
!</description>

!<input>
  ! The index of the local face for which the trafo is to be calculated.
  ! Is assumed to be 1 <= iface <= 6.
  integer, intent(in) :: iface

  ! The coordinates of the corner vertices of the hexahedron.
  real(DP), dimension(NDIM3D,8), intent(in) :: Dv

!<output>
  ! The transformation coefficients for the bilinear face trafo.
  real(DP), dimension(4,3), intent(out) :: Dt
!</output>

!</subroutine>

  ! corner vertice indices of the face
  integer, dimension(4) :: i

    ! Get face corner vertice indices
    select case(iface)
    case (1)
      i = (/1,2,3,4/)
    case (2)
      i = (/1,5,6,2/)
    case (3)
      i = (/7,3,2,6/)
    case (4)
      i = (/7,8,4,3/)
    case (5)
      i = (/1,4,8,5/)
    case (6)
      i = (/7,6,5,8/)
    end select

    ! Calculate trafo coefficients
    Dt(1,1) = 0.25_DP*( Dv(1,i(1))+Dv(1,i(2))+Dv(1,i(3))+Dv(1,i(4)))
    Dt(2,1) = 0.25_DP*(-Dv(1,i(1))+Dv(1,i(2))+Dv(1,i(3))-Dv(1,i(4)))
    Dt(3,1) = 0.25_DP*(-Dv(1,i(1))-Dv(1,i(2))+Dv(1,i(3))+Dv(1,i(4)))
    Dt(4,1) = 0.25_DP*( Dv(1,i(1))-Dv(1,i(2))+Dv(1,i(3))-Dv(1,i(4)))
    Dt(1,2) = 0.25_DP*( Dv(2,i(1))+Dv(2,i(2))+Dv(2,i(3))+Dv(2,i(4)))
    Dt(2,2) = 0.25_DP*(-Dv(2,i(1))+Dv(2,i(2))+Dv(2,i(3))-Dv(2,i(4)))
    Dt(3,2) = 0.25_DP*(-Dv(2,i(1))-Dv(2,i(2))+Dv(2,i(3))+Dv(2,i(4)))
    Dt(4,2) = 0.25_DP*( Dv(2,i(1))-Dv(2,i(2))+Dv(2,i(3))-Dv(2,i(4)))
    Dt(1,3) = 0.25_DP*( Dv(3,i(1))+Dv(3,i(2))+Dv(3,i(3))+Dv(3,i(4)))
    Dt(2,3) = 0.25_DP*(-Dv(3,i(1))+Dv(3,i(2))+Dv(3,i(3))-Dv(3,i(4)))
    Dt(3,3) = 0.25_DP*(-Dv(3,i(1))-Dv(3,i(2))+Dv(3,i(3))+Dv(3,i(4)))
    Dt(4,3) = 0.25_DP*( Dv(3,i(1))-Dv(3,i(2))+Dv(3,i(3))-Dv(3,i(4)))

  end subroutine

end module
