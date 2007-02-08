!##############################################################################
!# ****************************************************************************
!# <name> scalarbilinearform </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains the definition of scalar continuous bilinear forms.
!# Remark that only the shape of the continuous formulation is defined
!# here. The discretisation of bilinear forms is realised in higher
!# level modules.
!# </purpose>
!##############################################################################

MODULE scalarpde

  USE fsystem
  USE derivatives
  
  IMPLICIT NONE
  
!<constants>

!<constantblock>

  ! Maximum number of additive terms in the integral
  INTEGER, PARAMETER :: SCPDE_NNAB = 21

!</constantblock>

!</constants>

!<types>
  
  !<typeblock>
  
  ! A structure for a scalar bilinear form.
  !
  ! Example: Let's take a look at the 2D equation
  !
  !    $   \int_{\Omega}  ( \nabla u , \nabla v )  dx $
  !    $ = \int_{\Omega}  1*u_x*v_x  +  1*u_y*v_y  dx $
  !
  ! This bilinear form consists of two additive terms. Both terms have
  ! a constant coefficient '1' in front of them and consist of a combination
  ! of derivatives in different directions. The form itself is encoded
  ! with the structure t_bilinearForm as follows:
  !
  ! 1.) itermCount = 2                     -> 2 additive terms     
  ! 2.) BconstantCoeff = true              -> constant coefficients
  ! 3.) Dcoefficients(1)  = 1.0            -> 1st coefficient      
  ! 4.) Idescriptors(1,1) = DER_DERIV_X    -> u_x in the 1st term  
  ! 5.) Idescriptors(2,1) = DER_DERIV_X    -> v_x in the 1st term  
  ! 6.) Dcoefficients(2)  = 1.0            -> 2nd coefficient      
  ! 7.) Idescriptors(1,2) = DER_DERIV_Y    -> u_y in the 2nd term  
  ! 8.) Idescriptors(2,2) = DER_DERIV_Y    -> v_y in the 2nd term
  
  TYPE t_bilinearForm
  
    ! Number of additive terms in the bilinear form
    INTEGER :: itermCount = 0
    
    ! Descriptors of additive terms.
    ! Idescriptors(1,.) = trial function descriptor,
    ! Idescriptors(2,.) = test function descriptor.
    ! The descriptor itself is a DER_xxxx derivatrive
    ! identifier (c.f. module 'derivatives').
    INTEGER, DIMENSION(2,SCPDE_NNAB) :: Idescriptors = DER_FUNC
    
    ! TRUE if all coefficients in the biliear form are constant,
    ! FALSE if there is at least one nonconstant coefficient.
    LOGICAL                          :: ballCoeffConstant = .TRUE.
    
    ! For every additive term in the integral:
    ! = true, if the coefficient in front of the term is constant,
    ! = false, if the coefficient is nonconstant.
    LOGICAL, DIMENSION(SCPDE_NNAB)   :: BconstantCoeff = .TRUE.
    
    ! If ballCoeffConstant=TRUE: the constant coefficients in front of
    ! each additive terms in the bilinear form.
    ! Otherwise: Not used.
    REAL(DP), DIMENSION(SCPDE_NNAB)  :: Dcoefficients = 0.0_DP
  END TYPE
  
  !</typeblock>

  !<typeblock>
  
  ! A structure for a scalar trilinear form.
  !
  ! Example: For w:R2->R let's take a look at the 2D equation
  !
  !    $   \int_{\Omega}  w ( \nabla u , \nabla v )  dx $
  !    $ = \int_{\Omega}  ( F(w) \nabla u , \nabla v )  dx $
  !    $ = \int_{\Omega}  f_1(w)*1*u_x*v_x  +  f_2(w)*1*u_y*v_y  dx $
  !    $ = \int_{\Omega}  w*1*u_x*v_x  +  w*1*u_y*v_y  dx $
  !
  ! with $F=matrix([f_1,0],[0,f_2])$ specifying derivative quantifiers
  ! to be applied to w, here e.g. $f_1(w) = f_2(w) = w$.
  !
  ! This trilinear form consists of two additive terms. Both terms have
  ! a constant coefficient '1' in front of them and consist of a combination
  ! of derivatives in different directions. Additionally to that, there is
  ! a finite element function f(.) given that specifies variable coefficients.
  ! The form itself is encoded with the structure t_trilinearForm as follows:
  !
  !  1.) itermCount = 2                     -> 2 additive terms     
  !  2.) BconstantCoeff = true              -> constant coefficients
  !  3.) Dcoefficients(1)  = 1.0            -> 1st coefficient      
  !  5.) Idescriptors(1,1) = DER_FUNC       -> w(x,y) in the 1st term  
  !  6.) Idescriptors(2,1) = DER_DERIV_X    -> u_x in the 1st term  
  !  7.) Idescriptors(3,1) = DER_DERIV_X    -> v_x in the 1st term  
  !  8.) Dcoefficients(2)  = 1.0            -> 2nd coefficient      
  !  9.) Idescriptors(1,2) = DER_FUNC       -> w(x,y) in the 2nd term  
  ! 10.) Idescriptors(2,2) = DER_DERIV_Y    -> u_y in the 2nd term  
  ! 11.) Idescriptors(3,2) = DER_DERIV_Y    -> v_y in the 2nd term
  !
  ! One diffence to the usual meaning of the descriptors: A value of
  !   Idescriptors(1,i) = 0
  ! instead of DER_xxxx means that the function f is the constant 
  ! mapping f_i(u):=1. So this disables the contribution of u for that term.
  
  TYPE t_trilinearForm
  
    ! Number of additive terms in the bilinear form
    INTEGER :: itermCount = 0
    
    ! Descriptors of additive terms.
    ! Idescriptors(1,.) = coefficient function descriptor,
    ! Idescriptors(2,.) = trial function descriptor,
    ! Idescriptors(3,.) = test function descriptor.
    ! The descriptor itself is a DER_xxxx derivatrive
    ! identifier (c.f. module 'derivatives').
    INTEGER, DIMENSION(3,SCPDE_NNAB) :: Idescriptors = DER_FUNC
    
    ! TRUE if all coefficients in the biliear form are constant,
    ! FALSE if there is at least one nonconstant coefficient.
    LOGICAL                          :: ballCoeffConstant = .TRUE.
    
    ! For every additive term in the integral:
    ! = true, if the coefficient in front of the term is constant,
    ! = false, if the coefficient is nonconstant.
    LOGICAL, DIMENSION(SCPDE_NNAB)   :: BconstantCoeff = .TRUE.
    
    ! If ballCoeffConstant=TRUE: the constant coefficients in front of
    ! each additive terms in the bilinear form.
    ! Otherwise: Not used.
    REAL(DP), DIMENSION(SCPDE_NNAB)  :: Dcoefficients = 0.0_DP
  END TYPE
  
  !</typeblock>

  !<typeblock>
  
  ! A structure for a scalar linear form.
  !
  ! Example: Let's take a look at the 2D equation
  !
  !    $   \int_{\Omega}  ( f, v )   dx $
  !    $ = \int_{\Omega}  1*f*v      dx $
  !
  ! This bilinear form consists of one additive term. The term has
  ! a constant coefficient '1' in front and consist of a combination
  ! of derivatives. The form itself is encoded with the structure 
  ! t_linearForm as follows:
  !
  ! 1.) itermCount = 1                     -> 2 additive terms     
  ! 2.) BconstantCoeff = true              -> constant coefficients
  ! 3.) Dcoefficients(1)  = 1.0            -> 1st coefficient      
  ! 4.) Idescriptors(1,1) = DER_FUNC       -> f in the 1st term    
  ! 5.) Idescriptors(2,1) = DER_FUNC       -> v in the 1st term    
  
  TYPE t_linearForm
  
    ! Number of additive terms in the bilinear form
    INTEGER :: itermCount = 0
    
    ! Descriptors of additive terms, i.e. test function descriptors.
    ! The descriptor itself is a DER_xxxx derivatrive
    ! identifier (c.f. module 'derivatives').
    INTEGER, DIMENSION(SCPDE_NNAB) :: Idescriptors = DER_FUNC
    
  END TYPE
  
  !</typeblock>

!</types>
  
  ! ***************************************************************************
  
END MODULE
