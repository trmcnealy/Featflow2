!##############################################################################
!# ****************************************************************************
!# <name> poissoncallback </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains callback functions for the poisson problem that are
!# used during the matrix/vector assembly for specifying analytical data.
!# There are three callback functions involved, which may be called depending
!# on the situation. All of them correspond to a specific interface for
!# callback functions, defined in 'intf_xxxx.inc' files.
!#
!# 1.) coeff_Laplace
!#     -> Returns the coefficients for the Laplace matrix. This routine is
!#        only used if the problem to calculate has nonconstant coefficients!
!#        Otherwise the routine is dead.
!#     -> Corresponds to the interface defined in the file
!#        'intf_coefficientMatrixSc.inc'
!#
!# 2.) coeff_RHS
!#     -> Returns analytical values for the right hand side of the Laplace
!#        equation.
!#     -> Corresponds to the interface defined in the file
!#        'intf_coefficientVectorSc.inc'
!#
!# 3.) getBoundaryValues
!#     -> Returns analytic values on the (Dirichlet) boundary of the
!#        problem to solve.
!#     -> Corresponds to the interface defined in the file
!#        'intf_bcassembly.inc'
!#
!#
!# 4.) getBoundaryValuesFBC
!#    
!#     -> Returns analytic values in the inner of the domain on
!#        fictitious boundary objects
!#     -> Corresponds to the interface defined in the file
!#        'intf_bcfassembly.inc'
!#
!# 5.) getReferenceFunction
!#
!#     -> Returns the values of the analytic function and its derivatives,
!#        corresponding to coeff_RHS
!#     -> Is only used for the postprocessing to calculate the $L_2$- and
!#        $H_1$-error of the FE function in comparison to the analytic
!#        function
!# </purpose>
!##############################################################################

MODULE poisson_callback

  USE fsystem
  USE storage
  USE linearsolver
  USE boundary
  USE bilinearformevaluation
  USE linearformevaluation
  USE cubature
  USE matrixfilters
  USE vectorfilters
  USE bcassembly
  
  IMPLICIT NONE

CONTAINS

! ***************************************************************************
  !<subroutine>

  SUBROUTINE coeff_Laplace (rdiscretisation,rform, &
                  nelements,npointsPerElement,Dpoints, &
                  IdofsTrial,IdofsTest,rdomainIntSubset, p_rcollection,&
                  Dcoefficients)
    
    USE basicgeometry
    USE triangulation
    USE collection
    USE scalarpde
    USE domainintegration
    
  !<description>
    ! This subroutine is called during the matrix assembly. It has to compute
    ! the coefficients in front of the terms of the bilinear form.
    !
    ! The routine accepts a set of elements and a set of points on these
    ! elements (cubature points) in real coordinates.
    ! According to the terms in the bilinear form, the routine has to compute
    ! simultaneously for all these points and all the terms in the bilinear form
    ! the corresponding coefficients in front of the terms.
  !</description>
    
  !<input>
    ! The discretisation structure that defines the basic shape of the
    ! triangulation with references to the underlying triangulation,
    ! analytic boundary boundary description etc.
    TYPE(t_spatialDiscretisation), INTENT(IN)                   :: rdiscretisation
    
    ! The bilinear form which is currently being evaluated:
    TYPE(t_bilinearForm), INTENT(IN)                            :: rform
    
    ! Number of elements, where the coefficients must be computed.
    INTEGER(PREC_ELEMENTIDX), INTENT(IN)                        :: nelements
    
    ! Number of points per element, where the coefficients must be computed
    INTEGER, INTENT(IN)                                         :: npointsPerElement
    
    ! This is an array of all points on all the elements where coefficients
    ! are needed.
    ! Remark: This usually coincides with rdomainSubset%p_DcubPtsReal.
    ! DIMENSION(dimension,npointsPerElement,nelements)
    REAL(DP), DIMENSION(:,:,:), INTENT(IN)  :: Dpoints
    
    ! An array accepting the DOF's on all elements trial in the trial space.
    ! DIMENSION(#local DOF's in trial space,nelements)
    INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(IN) :: IdofsTrial
    
    ! An array accepting the DOF's on all elements trial in the trial space.
    ! DIMENSION(#local DOF's in test space,nelements)
    INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(IN) :: IdofsTest
    
    ! This is a t_domainIntSubset structure specifying more detailed information
    ! about the element set that is currently being integrated.
    ! It's usually used in more complex situations (e.g. nonlinear matrices).
    TYPE(t_domainIntSubset), INTENT(IN)              :: rdomainIntSubset

    ! A pointer to a collection structure to provide additional 
    ! information to the coefficient routine. May point to NULL() if not defined.
    TYPE(t_collection), POINTER                      :: p_rcollection
    
  !</input>
  
  !<output>
    ! A list of all coefficients in front of all terms in the bilinear form -
    ! for all given points on all given elements.
    !   DIMENSION(itermCount,npointsPerElement,nelements)
    ! with itermCount the number of terms in the bilinear form.
    REAL(DP), DIMENSION(:,:,:), INTENT(OUT)                      :: Dcoefficients
  !</output>
    
  !</subroutine>

    Dcoefficients = 1.0_DP

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE coeff_RHS (rdiscretisation,rform, &
                  nelements,npointsPerElement,Dpoints, &
                  IdofsTest,rdomainIntSubset,p_rcollection, &
                  Dcoefficients)
    
    USE basicgeometry
    USE triangulation
    USE collection
    USE scalarpde
    USE domainintegration
    
  !<description>
    ! This subroutine is called during the vector assembly. It has to compute
    ! the coefficients in front of the terms of the linear form.
    !
    ! The routine accepts a set of elements and a set of points on these
    ! elements (cubature points) in real coordinates.
    ! According to the terms in the linear form, the routine has to compute
    ! simultaneously for all these points and all the terms in the linear form
    ! the corresponding coefficients in front of the terms.
  !</description>
    
  !<input>
    ! The discretisation structure that defines the basic shape of the
    ! triangulation with references to the underlying triangulation,
    ! analytic boundary boundary description etc.
    TYPE(t_spatialDiscretisation), INTENT(IN)                   :: rdiscretisation
    
    ! The linear form which is currently to be evaluated:
    TYPE(t_linearForm), INTENT(IN)                              :: rform
    
    ! Number of elements, where the coefficients must be computed.
    INTEGER(PREC_ELEMENTIDX), INTENT(IN)                        :: nelements
    
    ! Number of points per element, where the coefficients must be computed
    INTEGER, INTENT(IN)                                         :: npointsPerElement
    
    ! This is an array of all points on all the elements where coefficients
    ! are needed.
    ! Remark: This usually coincides with rdomainSubset%p_DcubPtsReal.
    ! DIMENSION(dimension,npointsPerElement,nelements)
    REAL(DP), DIMENSION(:,:,:), INTENT(IN)  :: Dpoints

    ! An array accepting the DOF's on all elements trial in the trial space.
    ! DIMENSION(#local DOF's in test space,nelements)
    INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(IN) :: IdofsTest

    ! This is a t_domainIntSubset structure specifying more detailed information
    ! about the element set that is currently being integrated.
    ! It's usually used in more complex situations (e.g. nonlinear matrices).
    TYPE(t_domainIntSubset), INTENT(IN)              :: rdomainIntSubset

    ! A pointer to a collection structure to provide additional 
    ! information to the coefficient routine. May point to NULL() if not defined.
    TYPE(t_collection), POINTER                      :: p_rcollection
    
  !</input>
  
  !<output>
    ! A list of all coefficients in front of all terms in the linear form -
    ! for all given points on all given elements.
    !   DIMENSION(itermCount,npointsPerElement,nelements)
    ! with itermCount the number of terms in the linear form.
    REAL(DP), DIMENSION(:,:,:), INTENT(OUT)                      :: Dcoefficients
  !</output>
    
  !</subroutine>

    !    u(x,y) = 16*x*(1-x)*y*(1-y)
    ! => f(x,y) = 32 * (y*(1-y)+x*(1-x))
    Dcoefficients (1,:,:) = 32.0_DP * &
                    ( Dpoints(2,:,:)*(1.0_DP-Dpoints(2,:,:)) + &
                      Dpoints(1,:,:)*(1.0_DP-Dpoints(1,:,:)) )

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE getReferenceFunction (cderivative,rdiscretisation, &
                nelements,npointsPerElement,Dpoints, &
                IdofsTest,rdomainIntSubset,p_rcollection, &
                Dvalues)
  
  USE basicgeometry
  USE triangulation
  USE collection
  USE scalarpde
  USE domainintegration
  
!<description>
  ! This subroutine is called during the calculation of errors. It has to compute
  ! the (analytical) values of a function in a couple of points on a couple
  ! of elements. These values are compared to those of a computed FE function
  ! and used to calculate an error.
  !
  ! The routine accepts a set of elements and a set of points on these
  ! elements (cubature points) in in real coordinates.
  ! According to the terms in the linear form, the routine has to compute
  ! simultaneously for all these points.
!</description>
  
!<input>
  ! This is a DER_xxxx derivative identifier (from derivative.f90) that
  ! specifies what to compute: DER_FUNC=function value, DER_DERIV_X=x-derivative,...
  ! The result must be written to the Dvalue-array below.
  INTEGER, INTENT(IN)                                         :: cderivative

  ! The discretisation structure that defines the basic shape of the
  ! triangulation with references to the underlying triangulation,
  ! analytic boundary boundary description etc.
  TYPE(t_spatialDiscretisation), INTENT(IN)                   :: rdiscretisation
  
  ! Number of elements, where the coefficients must be computed.
  INTEGER, INTENT(IN)                                         :: nelements
  
  ! Number of points per element, where the coefficients must be computed
  INTEGER, INTENT(IN)                                         :: npointsPerElement
  
  ! This is an array of all points on all the elements where coefficients
  ! are needed.
  ! Remark: This usually coincides with rdomainSubset%p_DcubPtsReal.
  REAL(DP), DIMENSION(:,:,:), INTENT(IN)                      :: Dpoints

  ! An array accepting the DOF's on all elements trial in the trial space.
  ! DIMENSION(\#local DOF's in trial space,Number of elements)
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(IN) :: IdofsTest

  ! This is a t_domainIntSubset structure specifying more detailed information
  ! about the element set that is currently being integrated.
  ! It's usually used in more complex situations (e.g. nonlinear matrices).
  TYPE(t_domainIntSubset), INTENT(IN)              :: rdomainIntSubset

  ! A pointer to a collection structure to provide additional 
  ! information to the coefficient routine. May point to NULL() if not defined.
  TYPE(t_collection), POINTER                      :: p_rcollection
  
!</input>

!<output>
  ! This array has to receive the values of the (analytical) function
  ! in all the points specified in Dpoints, or the appropriate derivative
  ! of the function, respectively, according to cderivative.
  !   DIMENSION(npointsPerElement,nelements)
  REAL(DP), DIMENSION(:,:), INTENT(OUT)                      :: Dvalues
!</output>
  
!</subroutine>

  SELECT CASE (cderivative)
  CASE (DER_FUNC)
    ! u(x,y) = 16*x*(1-x)*y*(1-y)
    Dvalues (:,:) = 16.0_DP * Dpoints(1,:,:)*(1.0_DP-Dpoints(1,:,:)) * &
                              Dpoints(2,:,:)*(1.0_DP-Dpoints(2,:,:))
  CASE (DER_DERIV_X)
    !    u(x,y)   = 16*x*(1-x)*y*(1-y)
    ! => u_x(x,y) = 16 * ( y*(1-x)*(1-y)-x*y*(1-y) )
    Dvalues (:,:) = 16.0_DP * ( &
        Dpoints(2,:,:) * (1.0_DP-Dpoints(1,:,:)) * (1.0_DP-Dpoints(2,:,:)) - &
        Dpoints(1,:,:) * Dpoints(2,:,:) * (1.0_DP-Dpoints(2,:,:)) )
  CASE (DER_DERIV_Y)
    !    u(x,y)   = 16*x*(1-x)*y*(1-y)
    ! => u_y(x,y) = 16 * ( x*(1-x)*(1-y)-x*y*(1-x) )
    Dvalues (:,:) = 16.0_DP * ( &
        Dpoints(1,:,:) * (1.0_DP-Dpoints(1,:,:)) * (1.0_DP-Dpoints(2,:,:)) - &
        Dpoints(1,:,:) * Dpoints(2,:,:) * (1.0_DP-Dpoints(1,:,:)) )
  CASE DEFAULT
    ! Unknown. Set the result to 0.0.
    Dvalues = 0.0_DP
  END SELECT
  

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE getBoundaryValues (Icomponents,rdiscretisation,rbcRegion,ielement, &
                                cinfoNeeded,iwhere,dwhere, p_rcollection, Dvalues)
  
  USE collection
  USE spatialdiscretisation
  USE discretebc
  
!<description>
  ! This subroutine is called during the discretisation of boundary
  ! conditions. It calculates a special quantity on the boundary, which is
  ! then used by the discretisation routines to generate a discrete
  ! 'snapshot' of the (actually analytic) boundary conditions.
!</description>
  
!<input>
  ! Component specifier.
  ! For Dirichlet boundary: 
  !   Icomponents(1) defines the number of the boundary component, the value
  !   should be calculated for (e.g. 1=1st solution component, e.g. X-velocitry, 
  !   2=2nd solution component, e.g. Y-velocity,...)
  INTEGER, DIMENSION(:), INTENT(IN)                           :: Icomponents

  ! The discretisation structure that defines the basic shape of the
  ! triangulation with references to the underlying triangulation,
  ! analytic boundary boundary description etc.
  TYPE(t_spatialDiscretisation), INTENT(IN)                   :: rdiscretisation
  
  ! Boundary condition region that is currently being processed.
  ! (This e.g. defines the type of boundary conditions that are
  !  currently being calculated, as well as information about the current
  !  boundary segment 'where we are at the moment'.)
  TYPE(t_bcRegion), INTENT(IN)                                :: rbcRegion
  
  
  ! The element number on the boundary which is currently being processed
  INTEGER(I32), INTENT(IN)                                    :: ielement
  
  ! The type of information, the routine should calculate. One of the
  ! DISCBC_NEEDxxxx constants. Depending on the constant, the routine has
  ! to return one or multiple information value in the result array.
  INTEGER, INTENT(IN)                                         :: cinfoNeeded
  
  ! A reference to a geometric object where information should be computed.
  ! cinfoNeeded=DISCBC_NEEDFUNC : 
  !   iwhere = number of the point in the triangulation or
  !          = 0, if only the parameter value of the point is known; this
  !               can be found in dwhere,
  ! cinfoNeeded=DISCBC_NEEDDERIV : 
  !   iwhere = number of the point in the triangulation or
  !          = 0, if only the parameter value of the point is known; this
  !               can be found in dwhere,
  ! cinfoNeeded=DISCBC_NEEDINTMEAN : 
  !   iwhere = number of the edge where the value integral mean value
  !            should be computed
  INTEGER(I32), INTENT(IN)                                     :: iwhere

  ! A reference to a geometric object where information should be computed.
  ! cinfoNeeded=DISCBC_NEEDFUNC : 
  !   dwhere = parameter value of the point where the value should be computed,
  ! cinfoNeeded=DISCBC_NEEDDERIV : 
  !   dwhere = parameter value of the point where the value should be computed,
  ! cinfoNeeded=DISCBC_NEEDINTMEAN : 
  !   dwhere = 0 (not used)
  REAL(DP), INTENT(IN)                                        :: dwhere
    
  ! A pointer to a collection structure to provide additional 
  ! information to the coefficient routine. May point to NULL() if not defined.
  TYPE(t_collection), POINTER                  :: p_rcollection

!</input>

!<output>
  ! This array receives the calculated information. If the caller
  ! only needs one value, the computed quantity is put into Dvalues(1). 
  ! If multiple values are needed, they are collected here (e.g. for 
  ! DISCBC_NEEDDERIV: Dvalues(1)=x-derivative, Dvalues(2)=y-derivative,...)
  REAL(DP), DIMENSION(:), INTENT(OUT)                         :: Dvalues
!</output>
  
!</subroutine>


  ! To get the X/Y-coordinates of the boundary point, use:
  !
  ! REAL(DP) :: dx,dy
  !
  ! CALL boundary_getCoords(rdiscretisation%p_rboundary, &
  !     rbcRegion%rboundaryRegion%iboundCompIdx, dwhere, dx, dy)

  ! Return zero Dirichlet boundary values for all situations.
  Dvalues(1) = 0.0_DP
  
  END SUBROUTINE

  ! ***************************************************************************
  ! Only for POISSON_METHOD6: Values in a fictitious boundary component:

!<subroutine>

  SUBROUTINE getBoundaryValuesFBC (Icomponents,rdiscretisation,rbcRegion, &
                                   Revaluation, p_rcollection)
  
  USE collection
  USE spatialdiscretisation
  USE discretefbc
  
!<description>
  ! This subroutine is called during the discretisation of boundary
  ! conditions on fictitious boundary components. It calculates a special quantity 
  ! on the boundary, which is then used by the discretisation routines to 
  ! generate a discrete 'snapshot' of the (actually analytic) boundary conditions.
  !
  ! The routine must calculate the values on all elements of the element
  ! list Ielements simultaneously. Iwhere is a list with vertex or edge numbers
  ! where information is to be retrieved. Dvalues is filled with function values
  ! while Binside is set to TRUE for every vertex/edge that is inside of the
  ! corresponding fictitious boundary region (identified by rbcRegion).
!</description>
  
!<input>
  ! Component specifier.
  ! For Dirichlet boundary: 
  !   Icomponents(1..SIZE(Icomponents)) defines the number of the solution component,
  !   the value should be calculated for 
  !   (e.g. 1=1st solution component, e.g. X-velocity, 
  !         2=2nd solution component, e.g. Y-velocity,...,
  !         3=3rd solution component, e.g. pressure)
  !   Example: Icomponents(:) = [1,2] -> Compute velues for X- and Y-velocity
  !     (1=x, 2=y component)
  INTEGER, DIMENSION(:), INTENT(IN)                           :: Icomponents

  ! The discretisation structure that defines the basic shape of the
  ! triangulation with references to the underlying triangulation,
  ! analytic boundary boundary description etc.
  TYPE(t_blockDiscretisation), INTENT(IN)                     :: rdiscretisation
  
  ! Boundary condition region that is currently being processed.
  ! (This e.g. defines the type of boundary conditions that are 
  !  currently being calculated (Dirichlet, Robin,...), as well as information
  !  about the current boundary region 'what is discretised at the moment'.)
  TYPE(t_bcRegion), INTENT(IN)                                :: rbcRegion
  
  ! A pointer to a collection structure to provide additional 
  ! information to the coefficient routine. May point to NULL() if not defined.
  TYPE(t_collection), POINTER                                 :: p_rcollection

!</input>

!<inputoutput>
  ! A t_discreteFBCevaluation structure array that defines what to evaluate, 
  ! where to evaluate and which accepts the return values.
  ! This callback routine must check out the cinfoNeeded-entry in this structure
  ! to find out what to evaluate.
  ! The other entries in this structure describe where to evaluate.
  ! The result of the evaluation must be written into the p_Dvalues array entry
  ! in this structure.
  !
  ! The number of structures in this array depend on what to evaluate:
  !
  ! For Dirichlet boudary:
  !   revaluation contains as many entries as Icomponents; every entry in
  !   Icomponent corresponds to one entry in revaluation
  !   (so Icomponent(1)=1 defines to evaluate the X-velocity while the 
  !    values for the X-velocity are written to revaluation(1)\%p_Dvalues;
  !    Icomponent(2)=2 defines to evaluate the Y-velocity while the values 
  !    for the Y-velocity are written to revaluation(2)\%p_Dvalues, etc).
  !
  TYPE(t_discreteFBCevaluation), DIMENSION(:), INTENT(INOUT) :: Revaluation
!</inputoutput>
  
!</subroutine>

    ! local variables
    REAL(DP) :: ddistance, dxcenter, dycenter, dradius, dx, dy
    REAL(DP), DIMENSION(:,:), POINTER :: p_DvertexCoordinates
    TYPE(t_triangulation), POINTER :: p_rtriangulation
    INTEGER :: ipoint,idx

    ! Are we evaluating our fictitious boundary component?
    IF (rbcRegion%rfictBoundaryRegion%sname .EQ. 'CIRCLE') THEN
    
      ! Just make sure we are evaluating in the corners.
      IF (Revaluation(1)%cinfoNeeded .NE. DISCFBC_NEEDFUNC) THEN
        PRINT *,'FBC: only corner evaluation supported at the moment!'
        STOP
      END IF
      
      ! Get the triangulation array for the point coordinates
      p_rtriangulation => rdiscretisation%RspatialDiscretisation(1)%p_rtriangulation
      CALL storage_getbase_double2d (p_rtriangulation%h_DvertexCoords,&
                                     p_DvertexCoordinates)

      ! Definition of the circle
      dxcenter = 0.4
      dycenter = 0.4
      dradius  = 0.25
      
      ! Loop through the points where to evaluate:
      DO idx = 1,Revaluation(1)%nvalues
      
        ! Get the number of the point to process
        ipoint = Revaluation(1)%p_Iwhere(idx)
        
        ! Get x- and y-coordinate
        dx = p_DvertexCoordinates(1,ipoint)
        dy = p_DvertexCoordinates(2,ipoint)
        
        ! Get the distance to the center
        ddistance = SQRT( (dx-dxcenter)**2 + (dy-dycenter)**2 )
        
        ! Point inside?
        IF (ddistance .LE. dradius) THEN
        
          ! Denote in the p_Iinside array that we prescribe a value here:
          Revaluation(1)%p_Iinside (idx) = 1
          
          ! We prescribe 0.0 as Dirichlet value here.
          Revaluation(1)%p_Dvalues (idx,1) = 0.0_DP
        
        END IF
        
      END DO

      ! Definition of a 2nd circle
      dxcenter = 0.75
      dycenter = 0.75
      dradius  = 0.1
      
      ! Loop through the points where to evaluate:
      DO idx = 1,Revaluation(1)%nvalues
      
        ! Get the number of the point to process
        ipoint = Revaluation(1)%p_Iwhere(idx)
        
        ! Get x- and y-coordinate
        dx = p_DvertexCoordinates(1,ipoint)
        dy = p_DvertexCoordinates(2,ipoint)
        
        ! Get the distance to the center
        ddistance = SQRT( (dx-dxcenter)**2 + (dy-dycenter)**2 )
        
        ! Point inside?
        IF (ddistance .LE. dradius) THEN
        
          ! Denote in the p_Iinside array that we prescribe a value here:
          Revaluation(1)%p_Iinside (idx) = 1
          
          ! We prescribe 0.0 as Dirichlet value here.
          Revaluation(1)%p_Dvalues (idx,1) = 0.0_DP
        
        END IF
        
      END DO
    
    END IF

  END SUBROUTINE

  ! ***************************************************************************
  ! Only for POISSON_METHOD8: Monitor function for adaptive grid refinement
  
!<subroutine>

  SUBROUTINE gethadaptMonitorFunction(rtriangulation,rindicator)
  
!<description>
  ! This routine defines a 'monitor function' for the adaptive grid refinement
  ! with the h-adaptivity refinement strategy. rindicator is a vector with
  ! NEL entries for all the elements in the triangulation. The routine must
  ! fill each entry with a value that tells the h-adaptivity routines whether
  ! to refine that element or not.
!</descrition>
  
!<input>
  ! The triangulation structure of the underlying mesh which is to be refined
  TYPE(t_triangulation), INTENT(IN) :: rtriangulation
!</input>
    
!</inputoutput>
  ! An indicator vector. Entry i in the vector rindicatir that tells the 
  ! mesh adaption routines whether to refine element i or to do coarsening
  ! with it. A value > 1.0 will refine element i, a value < 0.01 will result
  ! in coarsening -- as specified during the initialisation of the
  ! mesh refinement in the main program.
  TYPE(t_vectorScalar), INTENT(INOUT) :: rindicator

!</subroutine>

    ! local variables
    REAL(DP), DIMENSION(:,:), POINTER :: p_DvertexCoords
    REAL(DP), DIMENSION(:), POINTER   :: p_Dindicator
    INTEGER(PREC_VERTEXIDX), DIMENSION(:,:), POINTER :: p_IverticesAtElement
    INTEGER(PREC_ELEMENTIDX) :: iel
    INTEGER :: ive
    REAL(DP) :: distance

    ! In this example, we do adaptive refinement to a ring.
    ! (x0,y0) defines the midpoint of the ring.
    REAL(DP), PARAMETER :: x0=0.5, y0=0.5
    
    ! r0 defines the radius of the inner circle, r1 the radius of the
    ! outer circle that define the ring.
    REAL(DP), PARAMETER :: r0=0.2, r1=0.3

    ! Get information about the mesh.
    CALL storage_getbase_double2d(rtriangulation%h_DvertexCoords,p_DvertexCoords)
    CALL storage_getbase_int2D(rtriangulation%h_IverticesAtElement,p_IverticesAtElement)

    ! Get the array of the indicator function.
    CALL lsyssc_getbase_double(rindicator,p_Dindicator)
    
    DO iel=1,rtriangulation%NEL
      ! Loop through the vertices on the element.
      ! If at least one corner vertex of the the element iel is inside 
      ! of the ring, refine it.
      DO ive = 1,tria_getNVE(p_IverticesAtElement,iel)
        ! Distance to the center of the ring
        distance = &
            SQRT( (p_DvertexCoords(1,p_IverticesAtElement(ive,iel))-x0)**2 + &
                  (p_DvertexCoords(2,p_IverticesAtElement(ive,iel))-y0)**2 )
          
        IF ((distance .GE. r0) .AND. (distance  .LE. r1)) THEN
          p_Dindicator(iel) = 2.0
        END IF
      END DO
    END DO
    
  END SUBROUTINE gethadaptMonitorFunction

END MODULE
