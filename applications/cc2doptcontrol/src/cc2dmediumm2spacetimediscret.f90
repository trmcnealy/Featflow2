!##############################################################################
!# ****************************************************************************
!# <name> cc2dmediumm2spacetimediscretisation </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains routines for the space time discretisation.
!# The structure t_ccoptSpaceTimeDiscretisation defines the shape of the
!# space-time discretisation and describes how to do a matrix-vector
!# multiplication with the global matrix.
!# The routines in this module form the basic set of discretisation routines:
!#
!# 1.) c2d2_spaceTimeMatVec
!#     -> Matrix-Vector multiplication of a space-time vector with the
!#        global matrix.
!#
!# 2.) c2d2_assembleSpaceTimeRHS
!#     -> Assemble the space-time RHS vector. 
!#
!# 3.) ...
!# </purpose>
!##############################################################################

MODULE cc2dmediumm2spacetimediscret

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
  USE triangulation
  USE spatialdiscretisation
  USE coarsegridcorrection
  USE spdiscprojection
  USE nonlinearsolver
  USE paramlist
  USE linearsolverautoinitialise
  USE matrixrestriction
  USE paramlist
  USE timestepping
  USE l2projection
  
  USE collection
  USE convection
    
  USE cc2dmediumm2basic
  USE cc2dmedium_callback

  USE cc2dmediumm2nonlinearcore
  USE cc2dmediumm2nonlinearcoreinit
  USE cc2dmediumm2stationary
  USE adaptivetimestep
  USE cc2dmediumm2timeanalysis
  USE cc2dmediumm2boundary
  USE cc2dmediumm2discretisation
  USE cc2dmediumm2postprocessing
  USE cc2dmediumm2matvecassembly
  
  USE spacetimevectors
  USE dofmapping
  
  USE matrixio
    
  IMPLICIT NONE

!<types>

!<typeblock>

  ! Defines the basic shape of the supersystem which realises the coupling
  ! between all timesteps.
  TYPE t_ccoptSpaceTimeDiscretisation
  
    ! Spatial refinement level of this matrix.
    INTEGER :: ilevel
  
    ! Number of time steps
    INTEGER :: niterations         = 0

    ! Absolute start time of the simulation
    REAL(DP) :: dtimeInit          = 0.0_DP     
    
    ! Maximum time of the simulation
    REAL(DP) :: dtimeMax           = 1.0_DP
    
    ! Time-stepping scheme (IFRSTP);
    ! 0=one step scheme
    INTEGER :: ctimeStepScheme     = 0
    
    ! Parameter for one step scheme (THETA) if itimeStepScheme=0;
    ! =0:Forward Euler(instable), =1: Backward Euler, =0.5: Crank-Nicolson
    REAL(DP) :: dtimeStepTheta     = 1.0_DP
    
    ! Time step length of the time discretisation
    REAL(DP) :: dtstep

    ! Regularisation parameter for the control $\alpha$. Must be <> 0.
    ! A value of 0.0 disables the terminal condition.
    REAL(DP) :: dalphaC = 1.0_DP
    
    ! Regularisation parameter for the terminal condition 
    ! $\gamma/2*||y(T)-z(T)||$.
    ! A value of 0.0 disables the terminal condition.
    REAL(DP) :: dgammaC = 0.0_DP

    ! Problem-related structure that provides the templates for
    ! matrices/vectors on the spatial level of the matrix.
    TYPE(t_problem_lvl), POINTER :: p_rlevelInfo

    ! Pointer to a space-time solution vector that defines the point
    ! where the nonlinearity is evaluated when applying or calculating
    ! matrices.
    ! If this points to NULL(), there is no global solution specified,
    ! so the matrix assembly/application routines use the vector that
    ! is specified in their input parameters.
    TYPE(t_spacetimeVector), POINTER :: p_rsolution => NULL()
    
  END TYPE

!</typeblock>

!</types>

CONTAINS

  
  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_initParamsSupersystem (rproblem,ilevelTime,ilevelSpace,&
      rspaceTimeDiscr, rx, rb, rd)
  
!<description>
  ! Initialises the time stepping scheme according to the parameters in the
  ! DAT file and the problem structure.
!</description>

!<input>
  ! The problem structure describing the whole problem.
  TYPE(t_problem), INTENT(IN), TARGET :: rproblem
  
  ! 'Refinement level in time'. =1: Initialise as described in
  ! rproblem. >1: Refine (irefineInTime-1) times regularly in time.
  ! (-> #timesteps * 2**(irefineInTime-1) )
  INTEGER, INTENT(IN) :: ilevelTime

  ! 'Refinement level in space'. =1: Calculate on the coarse mesh
  ! >0: calculate on level ilevelSpace. Must be <= rproblem%NLMAX,
  ! >= rproblem%NLMIN.
  INTEGER, INTENT(IN) :: ilevelSpace
!</input>

!<inputoutput>
  ! Supersystem-structure to be initialised.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(OUT) :: rspaceTimeDiscr

  ! A space-time vector that is initialised for the current solution.
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: rx

  ! A space-time vector that is initialised for the current RHS.
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: rb

  ! A space-time vector that is initialised for the current defect.
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: rd
!</inputoutput>

!</subroutine>

    ! local variables
    REAL(DP) :: dtstep

    ! Copy most relevant data from the problem structure.
    rspaceTimeDiscr%ilevel          = ilevelSpace
    rspaceTimeDiscr%p_rlevelInfo    => rproblem%RlevelInfo(ilevelSpace)
    rspaceTimeDiscr%niterations     = &
        rproblem%rtimedependence%niterations * 2**MAX(0,ilevelTime-1)
    rspaceTimeDiscr%dtimeInit       = rproblem%rtimedependence%dtimeInit
    rspaceTimeDiscr%dtimeMax        = rproblem%rtimedependence%dtimeMax
    rspaceTimeDiscr%ctimeStepScheme = rproblem%rtimedependence%ctimeStepScheme
    rspaceTimeDiscr%dtimeStepTheta  = rproblem%rtimedependence%dtimeStepTheta
    
    CALL parlst_getvalue_double (rproblem%rparamList,'OPTIMALCONTROL',&
                                'dalphaC',rspaceTimeDiscr%dalphaC,1.0_DP)
    CALL parlst_getvalue_double (rproblem%rparamList,'OPTIMALCONTROL',&
                                'dgammaC',rspaceTimeDiscr%dgammaC,0.0_DP)

    ! The complete time interval is divided into niteration iterations
    dtstep = (rspaceTimeDiscr%dtimemax-rspaceTimeDiscr%dtimeInit) &
             / REAL(MAX(rspaceTimeDiscr%niterations,1),DP)
             
    rspaceTimeDiscr%dtstep = dtstep
    
    ! Initialise the global solution- and defect- vector.
    IF (PRESENT(rx)) THEN
      CALL sptivec_initVector (rx,&
          dof_igetNDofGlobBlock(rproblem%RlevelInfo(ilevelSpace)%p_rdiscretisation,.FALSE.),&
          rspaceTimeDiscr%niterations)
    END IF
    IF (PRESENT(rb)) THEN
      CALL sptivec_initVector (rb,&
          dof_igetNDofGlobBlock(rproblem%RlevelInfo(ilevelSpace)%p_rdiscretisation,.FALSE.),&
          rspaceTimeDiscr%niterations)
    END IF
    IF (PRESENT(rd)) THEN
      CALL sptivec_initVector (rd,&
          dof_igetNDofGlobBlock(rproblem%RlevelInfo(ilevelSpace)%p_rdiscretisation,.FALSE.),&
          rspaceTimeDiscr%niterations)
    END IF

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_doneParamsSupersystem (rspaceTimeDiscr,rx,rb,rd)
  
!<description>
  ! Cleans up a given supersystem structure.
!</description>

!<inputoutput>
  ! Supersystem-structure to be cleaned up.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(OUT) :: rspaceTimeDiscr

  ! A space-time vector that is initialised for the current solution.
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: rx

  ! A space-time vector that is initialised for the current RHS.
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: rb

  ! A space-time vector that is initialised for the current defect.
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: rd
!</inputoutput>

!</subroutine>

    ! Release memory.
    IF (PRESENT(rb)) CALL sptivec_releaseVector (rb)
    IF (PRESENT(rd)) CALL sptivec_releaseVector (rd)
    IF (PRESENT(rx)) CALL sptivec_releaseVector (rx)

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
      isubstep,irelpos,rmatrixComponents)

!<description>
  ! This routine sets up the matrix weights in the rmatrixComponents structure
  ! according to the position of the corresponding submatrix.
  ! isubstep defines the timestep which is to be tackled -- which corresponds
  ! to the row in the supermatrix.
  ! irelpos specifies the column in the supermatrix relative to the diagonal --
  ! thus =0 means the diagonal, =1 the submatrix above the diagonal and =-1
  ! the submatrix below the diagonal.
  !
  ! The matrix weights in rmatrixComponents are initialised based on this
  ! information such that the 'assembleMatrix' and 'assembleDefect' routines of 
  ! the core equation will build the system matrix / defect at that position 
  ! in the supermatrix.
  !
  ! The routine does not initialise the pointers to the basic matrices/discretisation
  ! structures in the rmatrixComponents structure. This has to be done by
  ! the caller!
!</description>

!<input>
  ! Problem structure
  TYPE(t_problem), INTENT(IN) :: rproblem
  
  ! A t_ccoptSpaceTimeDiscretisation structure defining the discretisation of the
  ! coupled space-time matrix.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr

  ! Theta scheme identifier.
  ! = 0.5: Crank-Nicolson.
  ! = 1.0: Explicit Euler
  REAL(DP), INTENT(IN) :: dtheta
  
  ! Substep in the time-dependent simulation = row in the supermatrix.
  ! Range 0..nsubsteps
  INTEGER, INTENT(IN) :: isubstep
  
  ! Specifies the column in the supermatrix relative to the diagonal.
  ! =0: set matrix weights for the diagonal.
  INTEGER, INTENT(IN) :: irelpos
!</input>

!<inputoutput>
  ! A t_ccmatrixComponents structure that defines tghe shape of the core
  ! equation. The weights that specify the submatrices of a small 6x6 
  ! block matrix system are initialised depending on the position
  ! specified by isubstep and nsubsteps.
  TYPE(t_ccmatrixComponents), INTENT(INOUT) :: rmatrixComponents
!</inputoutput>

!</subroutine>

    ! If the following constant is set from 1.0 to 0.0, the primal system is
    ! decoupled from the dual system!
    REAL(DP), PARAMETER :: dprimalDualCoupling = 1.0_DP
    
    ! If the following constant is set from 1.0 to 0.0, the dual system is
    ! decoupled from the primal system!
    REAL(DP), PARAMETER :: ddualPrimalCoupling = 1.0_DP
    
    ! If the following parameter is set from 1.0 to 0.0, the terminal
    ! condition between the primal and dual equation is decoupled, i.e.
    ! the dual equation gets independent from the primal one.
    REAL(DP), PARAMETER :: dterminalCondDecoupled = 1.0_DP

    ! The first and last substep is a little bit special concerning
    ! the matrix!
    IF (isubstep .EQ. 0) THEN
      
      ! We are in the first substep
    
      IF (irelpos .EQ. 0) THEN
      
        ! The diagonal matrix.
        rmatrixComponents%diota1 = 1.0_DP
        rmatrixComponents%diota2 = 0.0_DP

        rmatrixComponents%dkappa1 = 1.0_DP
        rmatrixComponents%dkappa2 = 0.0_DP
        
        rmatrixComponents%dalpha1 = 0.0_DP
        rmatrixComponents%dalpha2 = 1.0_DP
        
        rmatrixComponents%dtheta1 = 0.0_DP
        rmatrixComponents%dtheta2 = dtheta * rspaceTimeDiscr%dtstep
        
        rmatrixComponents%dgamma1 = 0.0_DP
        rmatrixComponents%dgamma2 = &
            - dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        
        rmatrixComponents%dnewton1 = 0.0_DP
        rmatrixComponents%dnewton2 = &
              dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)

        rmatrixComponents%deta1 = 0.0_DP
        rmatrixComponents%deta2 = rspaceTimeDiscr%dtstep
        
        rmatrixComponents%dtau1 = 0.0_DP
        rmatrixComponents%dtau2 = 1.0_DP
        
        rmatrixComponents%dmu1 = 0.0_DP
        rmatrixComponents%dmu2 = ddualPrimalCoupling * &
            (-rspaceTimeDiscr%dtstep * dtheta)
        
      ELSE IF (irelpos .EQ. 1) THEN
      
        ! Offdiagonal matrix on the right of the diagonal.

        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]

        rmatrixComponents%diota1 = 0.0_DP
        rmatrixComponents%diota2 = 0.0_DP

        rmatrixComponents%dkappa1 = 0.0_DP
        rmatrixComponents%dkappa2 = 0.0_DP
        
        rmatrixComponents%dalpha1 = 0.0_DP
        rmatrixComponents%dalpha2 = -1.0_DP
        
        rmatrixComponents%dtheta1 = 0.0_DP
        rmatrixComponents%dtheta2 = (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep
        
        rmatrixComponents%dgamma1 = 0.0_DP
        rmatrixComponents%dgamma2 = &
            - (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        
        rmatrixComponents%dnewton1 = 0.0_DP
        rmatrixComponents%dnewton2 = &
              (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)

        rmatrixComponents%deta1 = 0.0_DP
        rmatrixComponents%deta2 = 0.0_DP
        
        rmatrixComponents%dtau1 = 0.0_DP
        rmatrixComponents%dtau2 = 0.0_DP
        
        rmatrixComponents%dmu1 = 0.0_DP
        rmatrixComponents%dmu2 = ddualPrimalCoupling * &
            (-rspaceTimeDiscr%dtstep) * (1.0_DP-dtheta)
            
      END IF
    
    ELSE IF (isubstep .LE. rspaceTimeDiscr%niterations) THEN
      
      ! We are sonewhere in the middle of the matrix. There is a substep
      ! isubstep+1 and a substep isubstep-1!
      
      ! -----
      
      IF (irelpos .EQ. -1) THEN
      
        ! Matrix on the left of the diagonal.
        !
        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]

        rmatrixComponents%diota1 = 0.0_DP
        rmatrixComponents%diota2 = 0.0_DP

        rmatrixComponents%dkappa1 = 0.0_DP
        rmatrixComponents%dkappa2 = 0.0_DP
        
        rmatrixComponents%dalpha1 = -1.0_DP
        rmatrixComponents%dalpha2 = 0.0_DP
        
        rmatrixComponents%dtheta1 = (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep
        rmatrixComponents%dtheta2 = 0.0_DP
        
        rmatrixComponents%dgamma1 = &
            (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        rmatrixComponents%dgamma2 = 0.0_DP
        
        rmatrixComponents%dnewton1 = 0.0_DP
        rmatrixComponents%dnewton2 = 0.0_DP

        rmatrixComponents%deta1 = 0.0_DP
        rmatrixComponents%deta2 = 0.0_DP
        
        rmatrixComponents%dtau1 = 0.0_DP
        rmatrixComponents%dtau2 = 0.0_DP
        
        rmatrixComponents%dmu1 = dprimalDualCoupling * &
            rspaceTimeDiscr%dtstep * (1.0_DP-dtheta) / rspaceTimeDiscr%dalphaC
        rmatrixComponents%dmu2 = 0.0_DP

      ELSE IF (irelpos .EQ. 0) THEN    

        ! The diagonal matrix.

        rmatrixComponents%diota1 = 0.0_DP
        rmatrixComponents%diota2 = 0.0_DP

        rmatrixComponents%dkappa1 = 0.0_DP
        rmatrixComponents%dkappa2 = 0.0_DP
        
        rmatrixComponents%dalpha1 = 1.0_DP
        rmatrixComponents%dalpha2 = 1.0_DP
        
        rmatrixComponents%dtheta1 = dtheta * rspaceTimeDiscr%dtstep
        rmatrixComponents%dtheta2 = dtheta * rspaceTimeDiscr%dtstep
        
        rmatrixComponents%dgamma1 = &
            dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        rmatrixComponents%dgamma2 = &
            - dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        
        rmatrixComponents%dnewton1 = 0.0_DP
        rmatrixComponents%dnewton2 = &
              dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)

        rmatrixComponents%deta1 = rspaceTimeDiscr%dtstep
        rmatrixComponents%deta2 = rspaceTimeDiscr%dtstep
        
        rmatrixComponents%dtau1 = 1.0_DP
        rmatrixComponents%dtau2 = 1.0_DP
        
        rmatrixComponents%dmu1 = dprimalDualCoupling * &
            dtheta * rspaceTimeDiscr%dtstep / rspaceTimeDiscr%dalphaC
        rmatrixComponents%dmu2 = ddualPrimalCoupling * &
            dtheta * (-rspaceTimeDiscr%dtstep)

      ELSE IF (irelpos .EQ. 1) THEN
            
        ! Matrix on the right of the diagonal.
        !
        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        rmatrixComponents%diota1 = 0.0_DP
        rmatrixComponents%diota2 = 0.0_DP

        rmatrixComponents%dkappa1 = 0.0_DP
        rmatrixComponents%dkappa2 = 0.0_DP
        
        rmatrixComponents%dalpha1 = 0.0_DP
        rmatrixComponents%dalpha2 = -1.0_DP
        
        rmatrixComponents%dtheta1 = 0.0_DP
        rmatrixComponents%dtheta2 = (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep
        
        rmatrixComponents%dgamma1 = 0.0_DP
        rmatrixComponents%dgamma2 = &
            - (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        
        rmatrixComponents%dnewton1 = 0.0_DP
        rmatrixComponents%dnewton2 = &
            (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)

        rmatrixComponents%deta1 = 0.0_DP
        rmatrixComponents%deta2 = 0.0_DP
        
        rmatrixComponents%dtau1 = 0.0_DP
        rmatrixComponents%dtau2 = 0.0_DP
        
        rmatrixComponents%dmu1 = 0.0_DP
        rmatrixComponents%dmu2 = ddualPrimalCoupling * &
            (1.0_DP-dtheta) * (-rspaceTimeDiscr%dtstep)
            
      END IF
    
    ELSE
    
      ! NOT USED!!!
      ! Although this would be the correct implementation of the matrix weights
      ! for the terminal condition at the first glance, it would be wrong to use 
      ! that. The last timestep has to be processed like
      ! the others, which infers some 'smoothing' in the dual solution
      ! at the end of the time cylinder! Without that smoothing that, some 
      ! time discretisation schemes like Crank-Nicolson would get instable
      ! if a terminal condition <> 0 is prescribed!
    
      ! We are in the last substep
      
      IF (irelpos .EQ. -1) THEN
      
        ! Matrix on the left of the diagonal
        !
        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        
        rmatrixComponents%diota1 = 0.0_DP
        rmatrixComponents%diota2 = 0.0_DP

        rmatrixComponents%dkappa1 = 0.0_DP
        rmatrixComponents%dkappa2 = 0.0_DP
        
        rmatrixComponents%dalpha1 = -1.0_DP
        rmatrixComponents%dalpha2 = 0.0_DP
        
        rmatrixComponents%dtheta1 = (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep
        rmatrixComponents%dtheta2 = 0.0_DP
        
        rmatrixComponents%dgamma1 = &
            (1.0_DP-dtheta) * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        rmatrixComponents%dgamma2 = 0.0_DP
        
        rmatrixComponents%dnewton1 = 0.0_DP
        rmatrixComponents%dnewton2 = 0.0_DP
        
        rmatrixComponents%deta1 = 0.0_DP
        rmatrixComponents%deta2 = 0.0_DP
        
        rmatrixComponents%dtau1 = 0.0_DP
        rmatrixComponents%dtau2 = 0.0_DP
        
        rmatrixComponents%dmu1 = dprimalDualCoupling * &
            rspaceTimeDiscr%dtstep * (1.0_DP-dtheta) / rspaceTimeDiscr%dalphaC
        rmatrixComponents%dmu2 = 0.0_DP
        
      ELSE IF (irelpos .EQ. 0) THEN
      
        ! The diagonal matrix.
        
        rmatrixComponents%diota1 = 0.0_DP
        rmatrixComponents%diota2 = (1.0_DP-ddualPrimalCoupling)

        rmatrixComponents%dkappa1 = 0.0_DP
        rmatrixComponents%dkappa2 = 1.0_DP
        
        rmatrixComponents%dalpha1 = 1.0_DP
        rmatrixComponents%dalpha2 = 1.0_DP
        
        rmatrixComponents%dtheta1 = dtheta * rspaceTimeDiscr%dtstep
        rmatrixComponents%dtheta2 = 0.0_DP
        
        rmatrixComponents%dgamma1 = &
            dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        rmatrixComponents%dgamma2 = 0.0_DP
!           - dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
        
        rmatrixComponents%dnewton1 = 0.0_DP
        rmatrixComponents%dnewton2 = 0.0_DP
!             dtheta * rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)

        rmatrixComponents%deta1 = rspaceTimeDiscr%dtstep
        rmatrixComponents%deta2 = 0.0_DP
        
        rmatrixComponents%dtau1 = 1.0_DP
        rmatrixComponents%dtau2 = 0.0_DP
        
        rmatrixComponents%dmu1 = dprimalDualCoupling * &
            dtheta * rspaceTimeDiscr%dtstep / rspaceTimeDiscr%dalphaC
        rmatrixComponents%dmu2 = ddualPrimalCoupling * &
            (-rspaceTimeDiscr%dgammaC)
        
      END IF

    END IF

  END SUBROUTINE  
  
  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_spaceTimeMatVec (rproblem, rspaceTimeDiscr, rx, rd, cx, cy, dnorm)

!<description>
  ! This routine performs a matrix-vector multiplication with the
  ! system matrix A defined by rspaceTimeDiscr.
  !    rd  :=  cx A(p_rsolution) rx  +  cy rd
  ! If rspaceTimeDiscr does not specify an evaluation point for th nonlinearity
  ! in A(.), the routine calculates
  !    rd  :=  cx A(rx) rx  +  cy rd
  ! rd is overwritten by the result.
!</description>

!<input>
  ! A problem structure that provides information about matrices on all
  ! levels as well as temporary vectors.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem

  ! A t_ccoptSpaceTimeDiscretisation structure defining the discretisation of the
  ! coupled space-time matrix.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr
!</input>

!<inputoutput>
  ! A space-time vector defining the current solution.
  ! Is replaced by the new solution
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rx

  ! A second space-time vector.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd
  
  ! Multiplication factor for rx
  REAL(DP), INTENT(IN) :: cx
  
  ! Multiplication factor for rd
  REAL(DP), INTENT(IN) :: cy
!</inputoutput>

!<output>
  ! OPTIONAL: If specified, returns the $l_2$-norm of rd.
  REAL(DP), INTENT(OUT), OPTIONAL :: dnorm
!<output>

!</subroutine>

    ! local variables
    INTEGER :: isubstep,ilevel
    TYPE(t_vectorBlock) :: rtempVectorD, rtempVector1, rtempVector2, rtempVector3
    TYPE(t_vectorBlock) :: rtempVectorEval1,rtempVectorEval2,rtempVectorEval3
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscr
    REAL(DP) :: dtheta
    TYPE(t_matrixBlock) :: rblockTemp
    TYPE(t_ccmatrixComponents) :: rmatrixComponents
    
    ! DEBUG!!!
    REAL(DP), DIMENSION(:), POINTER :: p_Dx1,p_Dx2,p_Dx3,p_Db
    
    ! If the following constant is set from 1.0 to 0.0, the primal system is
    ! decoupled from the dual system!
    REAL(DP), PARAMETER :: dprimalDualCoupling = 1.0_DP
    
    ! If the following constant is set from 1.0 to 0.0, the dual system is
    ! decoupled from the primal system!
    REAL(DP), PARAMETER :: ddualPrimalCoupling = 1.0_DP
    
    ! If the following parameter is set from 1.0 to 0.0, the terminal
    ! condition between the primal and dual equation is decoupled, i.e.
    ! the dual equation gets independent from the primal one.
    REAL(DP), PARAMETER :: dterminalCondDecoupled = 1.0_DP

    ! Level of the discretisation
    ilevel = rspaceTimeDiscr%ilevel

    ! Theta-scheme identifier.
    ! =1: implicit Euler.
    ! =0.5: Crank Nicolson
    dtheta = rproblem%rtimedependence%dtimeStepTheta
    
    ! Create a temp vector that contains the part of rd which is to be modified.
    p_rdiscr => rspaceTimeDiscr%p_RlevelInfo%p_rdiscretisation
    CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVectorD,.FALSE.)
    
    ! The vector will be a defect vector. Assign the boundary conditions so
    ! that we can implement them.
    rtempVectorD%p_rdiscreteBC => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC
    rtempVectorD%p_rdiscreteBCfict => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteFBC
    
    ! Create a temp vector for the X-vectors at timestep i-1, i and i+1.
    CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVector1,.FALSE.)
    CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVector2,.FALSE.)
    CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVector3,.FALSE.)
    
    ! DEBUG!!!
    !CALL lsysbl_getbase_double (rtempVector1,p_Dx1)
    !CALL lsysbl_getbase_double (rtempVector2,p_Dx2)
    !CALL lsysbl_getbase_double (rtempVector3,p_Dx3)
    !CALL lsysbl_getbase_double (rtempVectorD,p_Db)
    
    ! Get the parts of the X-vector which are to be modified at first --
    ! subvector 1, 2 and 3.
    CALL sptivec_getTimestepData(rx, 0, rtempVector1)
    IF (rspaceTimeDiscr%niterations .GT. 0) &
      CALL sptivec_getTimestepData(rx, 1, rtempVector2)
    IF (rspaceTimeDiscr%niterations .GT. 1) &
      CALL sptivec_getTimestepData(rx, 2, rtempVector3)
      
    ! If necesary, multiply the rtempVectorX. We have to take a -1 into
    ! account as the actual matrix multiplication routine c2d2_assembleDefect
    ! introduces another -1!
    IF (cx .NE. -1.0_DP) THEN
      CALL lsysbl_scaleVector (rtempVector1,-cx)
      CALL lsysbl_scaleVector (rtempVector2,-cx)
      CALL lsysbl_scaleVector (rtempVector3,-cx)
    END IF
      
    ! Now what's the evaluation point where to evaluate the nonlinearity/ies?
    ! If the structure defines an evaluation point, we take that one, so
    ! we need another temp vector that holds the evaluation point.
    ! If not, we take the vector rx. This is archived by creating new
    ! vectors that share their information with rx.
    IF (ASSOCIATED(rspaceTimeDiscr%p_rsolution)) THEN
      CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVectorEval1,.FALSE.)
      CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVectorEval2,.FALSE.)
      CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVectorEval3,.FALSE.)
    ELSE
      CALL lsysbl_duplicateVector (rtempVector1,rtempVectorEval1,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
      CALL lsysbl_duplicateVector (rtempVector2,rtempVectorEval2,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
      CALL lsysbl_duplicateVector (rtempVector3,rtempVectorEval3,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
    END IF

    IF (ASSOCIATED(rspaceTimeDiscr%p_rsolution)) THEN
      CALL sptivec_getTimestepData(rspaceTimeDiscr%p_rsolution, 0, rtempVectorEval1)
      IF (rspaceTimeDiscr%niterations .GT. 0) &
        CALL sptivec_getTimestepData(rspaceTimeDiscr%p_rsolution, 1, rtempVectorEval2)
      IF (rspaceTimeDiscr%niterations .GT. 1) &
        CALL sptivec_getTimestepData(rspaceTimeDiscr%p_rsolution, 2, rtempVectorEval3)
    END IF
    
    ! Basic initialisation of rmatrixComponents with the pointers to the
    ! matrices / discretisation structures on the current level.
    !
    ! The weights in the rmatrixComponents structure are later initialised
    ! according to the actual situation when the matrix is to be used.
    rmatrixComponents%p_rdiscretisation         => &
        rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation
    rmatrixComponents%p_rmatrixStokes         => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixStokes          
    rmatrixComponents%p_rmatrixB1             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB1              
    rmatrixComponents%p_rmatrixB2             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB2              
    rmatrixComponents%p_rmatrixMass           => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixMass            
    rmatrixComponents%p_rmatrixIdentityPressure => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixIdentityPressure
    rmatrixComponents%iupwind = collct_getvalue_int (rproblem%rcollection,'IUPWIND')
    rmatrixComponents%dnu = collct_getvalue_real (rproblem%rcollection,'NU')
    rmatrixComponents%dupsam = collct_getvalue_real (rproblem%rcollection,'UPSAM')

    ! If dnorm is specified, clear it.
    IF (PRESENT(dnorm)) THEN
      dnorm = 0.0_DP
    END IF

    ! Loop through the substeps
    
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      ! Current point in time
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + isubstep*rspaceTimeDiscr%dtstep

      ! Get the part of rd which is to be modified.
      CALL sptivec_getTimestepData(rd, isubstep, rtempVectorD)
      
      ! If cy <> 1, multiply rtempVectorD by that.
      IF (cy .NE. 1.0_DP) THEN
        CALL lsysbl_scaleVector (rtempVectorD,cy)
      END IF

      ! -----
      ! Discretise the boundary conditions at the new point in time -- 
      ! if the boundary conditions are nonconstant in time!
      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
      END IF
      
      ! The first and last substep is a little bit special concerning
      ! the matrix!
      IF (isubstep .EQ. 0) THEN
        
        ! We are in the first substep. Here, we have to handle the following
        ! part of the supersystem:
        !
        !  ( A11 A12   0   0 ... )  ( x1 )  =  ( f1 )
        !  ( ... ... ... ... ... )  ( .. )     ( .. )
        !
        ! So we have to compute:
        !
        !  d1  :=  f1  -  A11 x1  -  A12 x2
        !
        ! -----
        
        ! The diagonal matrix.
      
        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,0,rmatrixComponents)
          
        ! Subtract: rd = rd - A11 x1
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector1,rtempVectorD,&
            1.0_DP,rtempVectorEval1)

        ! -----
      
        ! Create the matrix
        !   A12  :=  -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and subtract A12 x2 from rd.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,1,rmatrixComponents)

        ! Subtract: rd = rd - A12 x2
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector2,rtempVectorD,&
            1.0_DP,rtempVectorEval2)

        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)

      ELSE IF (isubstep .LT. rspaceTimeDiscr%niterations) THEN

        ! We are sonewhere in the middle of the matrix. There is a substep
        ! isubstep+1 and a substep isubstep-1!  Here, we have to handle the following
        ! part of the supersystem:
        !
        !  ( ... ...   ... ...   ... )  ( .. )     ( .. )
        !  ( ... Aii-1 Aii Aii+1 ... )  ( xi )  =  ( fi )
        !  ( ... ...   ... ...   ... )  ( .. )     ( .. )
        !
        ! So we have to compute:
        !
        !  dn  :=  fn  -  Aii-1 xi-1  -  Aii xi  -  Aii+1 xi+1
        
        ! -----
        
        ! Create the matrix
        !   Aii-1 := -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the primal velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,-1,rmatrixComponents)
            
        ! Subtract: rd = rd - Aii-1 xi-1.
        ! Note that at this point, the nonlinearity must be evaluated
        ! at xi due to the discretisation scheme!!!
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector1,rtempVectorD,&
            1.0_DP,rtempVectorEval2)

        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)

        ! -----      

        ! Now the diagonal matrix.
      
        ! Assemble the nonlinear defect.
      
        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,0,rmatrixComponents)

        ! Subtract: rd = rd - Aii xi
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector2,rtempVectorD,&
            1.0_DP,rtempVectorEval2)
            
        ! -----
        
        ! Create the matrix
        !   Aii+1 := -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the dual velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,1,rmatrixComponents)
          
        ! Subtract: rd = rd - Aii+1 xi+1
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector3,rtempVectorD,&
            1.0_DP,rtempVectorEval3)
        
        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)

      ELSE 
        
        ! We are in the last substep. Here, we have to handle the following
        ! part of the supersystem:
        !
        !  ( ... ... ... ...   ... )  ( .. )     ( .. )
        !  ( ... ...   0 Ann-1 Ann )  ( xn )  =  ( fn )
        !
        ! So we have to compute:
        !
        !  dn  :=  fn  -  Ann-1 xn-1  -  Ann xn
        
        ! -----
        
        ! Create the matrix
        !   Ann-1 = -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the dual velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,-1,rmatrixComponents)
          
        ! Subtract: rd = rd - Ann-1 xn-1
        ! Note that at this point, the nonlinearity must be evaluated
        ! at xn due to the discretisation scheme!!!
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector2,rtempVectorD,&
            1.0_DP,rtempVectorEval3)
     
        ! -----
        
        ! Now the diagonal matrix.
      
        ! Assemble the nonlinear defect.
      
        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,0,rmatrixComponents)

        ! Subtract: rd = rd - Ann xn
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector3,rtempVectorD,&
            1.0_DP,rtempVectorEval3)
      
      END IF
      
      ! Implement the boundary conditions into the defect.
      CALL vecfil_discreteBCdef (rtempVectorD)
      CALL vecfil_discreteFBCdef (rtempVectorD)      
      
      ! Save the defect vector back to rd.
      CALL sptivec_setTimestepData(rd, isubstep, rtempVectorD)
      
      ! If dnorm is specified, calculate the norm of the sub-defect vector and
      ! add it to dnorm.
      IF (PRESENT(dnorm)) THEN
        dnorm = dnorm + lsysbl_vectorNorm(rtempVectorD,LINALG_NORML2)**2
      END IF
      
      IF ((isubstep .GT. 0) .AND. &
          (isubstep .LT. rspaceTimeDiscr%niterations-1)) THEN
      
        ! Shift the timestep data: x_n+1 -> x_n -> x_n-1
        IF (rtempVector2%NEQ .NE. 0) &
          CALL lsysbl_copyVector (rtempVector2, rtempVector1)
        
        IF (rtempVector3%NEQ .NE. 0) &
          CALL lsysbl_copyVector (rtempVector3, rtempVector2)
        
        ! Get the new x_n+1 for the next pass through the loop.
        CALL sptivec_getTimestepData(rx, isubstep+2, rtempVector3)
        
        ! If necessary, multiply rtempVector3
        IF (cx .NE. -1.0_DP) THEN
          CALL lsysbl_scaleVector (rtempVector3,-cx)
        END IF        
        
        ! A similar shifting has to be done for the evaluation point --
        ! if it's different from rx!
        IF (ASSOCIATED(rspaceTimeDiscr%p_rsolution)) THEN
          CALL lsysbl_copyVector (rtempVectorEval2, rtempVectorEval1)
          CALL lsysbl_copyVector (rtempVectorEval3, rtempVectorEval2)
          ! Get the new x_n+1 for the next pass through the loop.
          CALL sptivec_getTimestepData(rspaceTimeDiscr%p_rsolution, &
              isubstep+2, rtempVectorEval3)
        END IF
        
      END IF
    
    END DO
    
    ! If dnorm is specified, normalise it.
    ! It was calculated from rspaceTimeDiscr%niterations+1 subvectors.
    IF (PRESENT(dnorm)) THEN
      dnorm = SQRT(dnorm) / REAL(rspaceTimeDiscr%niterations+1,DP)
    END IF
    
    ! Release the temp vectors.
    CALL lsysbl_releaseVector (rtempVectorEval3)
    CALL lsysbl_releaseVector (rtempVectorEval2)
    CALL lsysbl_releaseVector (rtempVectorEval1)
    CALL lsysbl_releaseVector (rtempVector3)
    CALL lsysbl_releaseVector (rtempVector2)
    CALL lsysbl_releaseVector (rtempVector1)
    CALL lsysbl_releaseVector (rtempVectorD)
    
  END SUBROUTINE 
   
  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_assembleSpaceTimeRHS (rproblem, rspaceTimeDiscr, rb, &
      rtempvector1, rtempvector2, rtempvector3, bimplementBC)

!<description>
  ! Assembles the space-time RHS vector rb. Bondary conditions are NOT
  ! implemented!
  !
  ! Note: rproblem%rtimedependence%dtime will be undefined at the end of
  ! this routine!
!</description>

!<input>
  ! A problem structure that provides information on all
  ! levels as well as temporary vectors.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
  
  ! A t_ccoptSpaceTimeDiscretisation structure defining the discretisation of the
  ! coupled space-time system.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr
!</input>

!<inputoutput>
  ! A temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVector1

  ! A second temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVector2

  ! A third temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVector3

  ! A space-time vector that receives the RHS.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rb
  
  ! Whether to implement boundary conditions into the RHS or not.
  LOGICAL, INTENT(IN) :: bimplementBC
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER :: isubstep
    REAL(DP) :: dtheta,dtstep
    
    ! A temporary vector for the creation of the RHS.
    TYPE(t_vectorBlock) :: rtempVectorRHS
    
    REAL(DP), DIMENSION(:),POINTER :: p_Dx, p_Db, p_Dd, p_Drhs

    ! Theta-scheme identifier.
    ! =1: impliciz Euler.
    ! =0.5: Crank Nicolson
    dtheta = rproblem%rtimedependence%dtimeStepTheta
    dtstep = rspaceTimeDiscr%dtstep
    
    ! ----------------------------------------------------------------------
    ! Generate the global RHS vector
    
    CALL lsysbl_getbase_double (rtempVector1,p_Dx)
    CALL lsysbl_getbase_double (rtempVector2,p_Db)
    CALL lsysbl_getbase_double (rtempVector3,p_Dd)

    ! Assemble 1st RHS vector in X temp vector.
    CALL generateRHS (rproblem,0,rb%ntimesteps,&
        rtempVector1, .TRUE., .FALSE.)
    
    ! Assemble the 2nd RHS vector in the RHS temp vector
    CALL generateRHS (rproblem,1,rb%ntimesteps,&
        rtempVector2, .TRUE., .FALSE.)

    ! Assemble the 3rd RHS vector in the defect temp vector
    CALL generateRHS (rproblem,2,rb%ntimesteps,&
        rtempVector3, .TRUE., .FALSE.)
        
    ! Create a copy of the X temp vector (RHS0). That vector will be
    ! our destination vector for assembling the RHS in all timesteps.
    CALL lsysbl_copyVector (rtempVector1,rtempVectorRHS)
    
    ! DEBUG!!!
    CALL lsysbl_getbase_double (rtempVectorRHS,p_Drhs)
    
    ! RHS 0,1,2 -> 1-2-3
    
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      IF (isubstep .EQ. 0) THEN
      
        ! Primal RHS comes from rtempVector1. The dual from the
        ! isubstep+1'th RHS in rtempVector2.
        !
        ! primal RHS(0) = PRIMALRHS(0)
        ! dual RHS(0)   = THETA*DUALRHS(0) + (1-THETA)*DUALRHS(1)

        CALL lsyssc_copyVector (rtempVector1%RvectorBlock(1),rtempVectorRHS%RvectorBlock(1))
        CALL lsyssc_copyVector (rtempVector1%RvectorBlock(2),rtempVectorRHS%RvectorBlock(2))
        CALL lsyssc_copyVector (rtempVector1%RvectorBlock(3),rtempVectorRHS%RvectorBlock(3))

        CALL lsyssc_vectorLinearComb (&
            rtempVector1%RvectorBlock(4),rtempVector2%RvectorBlock(4),&
            dtstep*dtheta,dtstep*(1.0_DP-dtheta),&
            rtempVectorRHS%RvectorBlock(4))
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector1%RvectorBlock(5),rtempVector2%RvectorBlock(5),&
            dtstep*dtheta,dtstep*(1.0_DP-dtheta),&
            rtempVectorRHS%RvectorBlock(5))
        ! Pressure is fully implicit; no weighting by dtstep!
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector1%RvectorBlock(6),rtempVector2%RvectorBlock(6),&
            dtheta,(1.0_DP-dtheta),&
            rtempVectorRHS%RvectorBlock(6))
            
      ELSE IF (isubstep .LT. rspaceTimeDiscr%niterations) THEN
      
        ! We are somewhere 'in the middle'.
        !
        ! Dual RHS comes from rtempVector3. The primal from the
        ! isubstep-1'th RHS.
        !
        ! primal RHS(0) = THETA*PRIMALRHS(0) + (1-THETA)*PRIMALRHS(-1)
        ! dual RHS(0)   = THETA*DUALRHS(0) + (1-THETA)*DUALRHS(1)
        
        CALL lsyssc_vectorLinearComb (&
            rtempVector1%RvectorBlock(1),rtempVector2%RvectorBlock(1),&
            dtstep*(1.0_DP-dtheta),dtstep*dtheta,&
            rtempVectorRHS%RvectorBlock(1))                                        
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector1%RvectorBlock(2),rtempVector2%RvectorBlock(2),&
            dtstep*(1.0_DP-dtheta),dtstep*dtheta,&
            rtempVectorRHS%RvectorBlock(2))                                        
        ! Pressure is fully implicit; no weighting by dtstep!
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector1%RvectorBlock(3),rtempVector2%RvectorBlock(3),&
            (1.0_DP-dtheta),dtheta,&
            rtempVectorRHS%RvectorBlock(3))

        CALL lsyssc_vectorLinearComb (&
            rtempVector2%RvectorBlock(4),rtempVector3%RvectorBlock(4),&
            dtstep*dtheta,dtstep*(1.0_DP-dtheta),&
            rtempVectorRHS%RvectorBlock(4))
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector2%RvectorBlock(5),rtempVector3%RvectorBlock(5),&
            dtstep*dtheta,dtstep*(1.0_DP-dtheta),&
            rtempVectorRHS%RvectorBlock(5))
        ! Pressure is fully implicit; no weighting by dtstep!
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector2%RvectorBlock(6),rtempVector3%RvectorBlock(6),&
            dtheta,(1.0_DP-dtheta),&
            rtempVectorRHS%RvectorBlock(6))
        
        IF (isubstep .LT. rspaceTimeDiscr%niterations-1) THEN
          ! Shift the RHS vectors and generate the RHS for the next time step.
          ! (Yes, I know, this could probably be solved more elegant without copying anything
          ! using a ring buffer ^^)
          CALL lsysbl_copyVector(rtempVector2,rtempVector1)
          CALL lsysbl_copyVector(rtempVector3,rtempVector2)
          CALL generateRHS (rproblem,isubstep+2,rspaceTimeDiscr%niterations,&
              rtempVector3, .TRUE., .FALSE.)
        END IF
        
      ELSE
      
        ! We are 'at the end'.
        !
        ! Dual RHS comes from rtempVector3. The primal from the
        ! isubstep-1'th RHS and rtempVector3.
        !
        ! primal RHS(0) = THETA*PRIMALRHS(0) + (1-THETA)*PRIMALRHS(-1)
        ! dual RHS(0)   = DUALRHS(0)
      
        CALL lsyssc_vectorLinearComb (&
            rtempVector2%RvectorBlock(1),rtempVector3%RvectorBlock(1),&
            dtstep*(1.0_DP-dtheta),dtstep*dtheta,&
            rtempVectorRHS%RvectorBlock(1))                                        
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector2%RvectorBlock(2),rtempVector3%RvectorBlock(2),&
            dtstep*(1.0_DP-dtheta),dtstep*dtheta,&
            rtempVectorRHS%RvectorBlock(2))                                        
        ! Pressure is fully implicit; no weighting by dtstep!
        CALL lsyssc_vectorLinearComb (&                                                   
            rtempVector2%RvectorBlock(3),rtempVector3%RvectorBlock(3),&
            (1.0_DP-dtheta),dtheta,&
            rtempVectorRHS%RvectorBlock(3))

        !CALL generateRHS (rproblem,isubstep+1,rspaceTimeDiscr%niterations,&
        !    rtempVector3, .TRUE., .FALSE.)

        CALL lsyssc_copyVector (rtempVector3%RvectorBlock(4),rtempVectorRHS%RvectorBlock(4))
        CALL lsyssc_copyVector (rtempVector3%RvectorBlock(5),rtempVectorRHS%RvectorBlock(5))
        CALL lsyssc_copyVector (rtempVector3%RvectorBlock(6),rtempVectorRHS%RvectorBlock(6))

        ! Multiply the last RHS of the dual equation -z by gamma, that's it.
        CALL lsyssc_scaleVector (rtempVectorRHS%RvectorBlock(4),rspaceTimeDiscr%dgammaC)
        CALL lsyssc_scaleVector (rtempVectorRHS%RvectorBlock(5),rspaceTimeDiscr%dgammaC)

      END IF

      ! Implement the boundary conditions into the RHS vector        
      IF (bimplementBC) THEN
        CALL generateRHS (rproblem,isubstep,rspaceTimeDiscr%niterations,&
            rtempVectorRHS, .FALSE., .TRUE.)
      END IF
      
      ! Save the RHS.
      CALL sptivec_setTimestepData(rb, isubstep, rtempVectorRHS)
      
    END DO
    
    ! Release the temp vector for generating the RHS.
    CALL lsysbl_releaseVector (rtempVectorRHS)

  CONTAINS
  
    SUBROUTINE generateRHS (rproblem,isubstep,nsubsteps,&
        rvector, bgenerate, bincludeBC)
    
    ! Generate the RHS vector of timestep isubstep and/or include boundary
    ! conditions.
    
    ! Problem structure.
    TYPE(t_problem), INTENT(INOUT) :: rproblem
    
    ! Number of the substep where to generate the RHS vector
    INTEGER, INTENT(IN) :: isubstep
    
    ! Total number of substeps
    INTEGER, INTENT(IN) :: nsubsteps
    
    ! Destination vector
    TYPE(t_vectorBlock), INTENT(INOUT) :: rvector
    
    ! Whether to generate the RHS vector or not
    LOGICAL, INTENT(IN) :: bgenerate
    
    ! Whether to include boundary conditions
    LOGICAL, INTENT(IN) :: bincludeBC
    
    ! DEBUG!!!
    REAL(DP), DIMENSION(:), POINTER :: p_Ddata
    
      ! DEBUG!!!
      CALL lsysbl_getbase_double (rvector,p_Ddata)

      ! Set the time where we are at the moment
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + isubstep*dtstep
          
      ! Assemble the RHS?
      IF (bgenerate) THEN
      
        ! Generate the RHS of that point in time into the vector.
        CALL c2d2_generateBasicRHS (rproblem,rvector)

      END IF
      
      ! Include BC's?
      IF (bincludeBC) THEN
        
        ! Initialise the collection for the assembly process with callback routines.
        ! Basically, this stores the simulation time in the collection if the
        ! simulation is nonstationary.
        CALL c2d2_initCollectForAssembly (rproblem,rproblem%rcollection)

        ! Discretise the boundary conditions at the new point in time -- 
        ! if the boundary conditions are nonconstant in time!
        IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
          CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
        END IF

        ! Implement the boundary conditions into the RHS.
        ! This is done *after* multiplying -z by GAMMA or dtstep, resp.,
        ! as Dirichlet values mustn't be multiplied with GAMMA!
        CALL vecfil_discreteBCsol (rvector)
        CALL vecfil_discreteFBCsol (rvector)      
      
        ! Clean up the collection (as we are done with the assembly, that's it.
        CALL c2d2_doneCollectForAssembly (rproblem,rproblem%rcollection)
        
      END IF
    
    END SUBROUTINE
    
  END SUBROUTINE
  
  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_implementInitCondRHS (rx, rb, rtempvectorX, rtempvectorD)

!<description>
  ! Implements the initial condition into the RHS vector rb.
  ! Overwrites the rb of the first time step.
  !
  ! Does not implement boundary conditions!
!</description>

!<input>
  ! A space-time vector containing the initial condition in the first subvector.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rb
!</input>

!<inputoutput>
  ! A space-time vector with the RHS. The initial condition is implemented into
  ! this vector.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rx

  ! A temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorX

  ! A temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorD
!</inputoutput>

!</subroutine>

    ! Overwrite the primal RHS with the initial primal solution vector.
    ! This realises the inital condition.
    CALL sptivec_getTimestepData(rx, 0, rtempVectorX)
    CALL sptivec_getTimestepData(rb, 0, rtempVectorD)
    CALL lsyssc_copyVector (rtempVectorX%RvectorBlock(1),rtempVectorD%RvectorBlock(1))
    CALL lsyssc_copyVector (rtempVectorX%RvectorBlock(2),rtempVectorD%RvectorBlock(2))
    CALL lsyssc_copyVector (rtempVectorX%RvectorBlock(3),rtempVectorD%RvectorBlock(3))
    CALL sptivec_setTimestepData(rb, 0, rtempVectorD)

    ! DEBUG!!!
    !CALL sptivec_getTimestepData(rx, 2, rtempVectorX)
    !CALL sptivec_getTimestepData(rb, 2, rtempVectorD)
    !CALL lsyssc_copyVector (rtempVectorX%RvectorBlock(4),rtempVectorD%RvectorBlock(4))
    !CALL lsyssc_copyVector (rtempVectorX%RvectorBlock(5),rtempVectorD%RvectorBlock(5))
    !CALL lsyssc_copyVector (rtempVectorX%RvectorBlock(6),rtempVectorD%RvectorBlock(6))
    !CALL sptivec_setTimestepData(rb, 2, rtempVectorD)

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_implementBCsolution (rproblem,rspaceTimeDiscr,rx,rtempvectorX)

!<description>
  ! Implements the boundary conditions of all timesteps into the solution rx.
!</description>

!<input>
  ! Problem structure of the main problem.
  TYPE(t_problem), INTENT(INOUT) :: rproblem
  
  ! Discretisation structure that corresponds to rx.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr

!</input>

!<inputoutput>
  ! A space-time vector with the solution where the BC's should be implemented
  ! to.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rx

  ! A temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorX
!</inputoutput>

!</subroutine>

    INTEGER :: isubstep

    ! Implement the bondary conditions into all initial solution vectors
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      ! Current point in time
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + &
          isubstep*rspaceTimeDiscr%dtstep

      ! -----
      ! Discretise the boundary conditions at the new point in time -- 
      ! if the boundary conditions are nonconstant in time!
      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
      END IF
      
      ! Implement the boundary conditions into the global solution vector.
      CALL sptivec_getTimestepData(rx, isubstep, rtempVectorX)
      
      CALL c2d2_implementBC (rproblem,rvector=rtempVectorX)
      
      CALL sptivec_setTimestepData(rx, isubstep, rtempVectorX)
      
    END DO

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_implementBCdefect (rproblem,rspaceTimeDiscr,rd,rtempvectorX)

!<description>
  ! Implements the boundary conditions of all timesteps into the defect rd.
!</description>

!<input>
  ! Problem structure of the main problem.
  TYPE(t_problem), INTENT(INOUT) :: rproblem
  
  ! Discretisation structure that corresponds to rx.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr

!</input>

!<inputoutput>
  ! A space-time vector with the solution where the BC's should be implemented
  ! to.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd

  ! A temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorX
!</inputoutput>

!</subroutine>

    INTEGER :: isubstep
    TYPE(t_vectorBlock) :: rtempVector
    
    CALL lsysbl_duplicateVector(rtempVectorX,rtempVector,&
        LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
    rtempVector%p_rdiscreteBC => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC

    ! Implement the bondary conditions into all initial solution vectors
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      ! Current point in time
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + &
          isubstep*rspaceTimeDiscr%dtstep

      ! -----
      ! Discretise the boundary conditions at the new point in time -- 
      ! if the boundary conditions are nonconstant in time!
      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
      END IF
      
      ! Implement the boundary conditions into the global solution vector.
      CALL sptivec_getTimestepData(rd, isubstep, rtempVector)
      
      CALL c2d2_implementBC (rproblem,rdefect=rtempVector)
      
      ! In the very first time step, we have the initial condition for the
      ! solution. The defect is =0 there!
      IF (isubstep .EQ. 0) THEN
        CALL lsyssc_clearVector (rtempVector%RvectorBlock(1))
        CALL lsyssc_clearVector (rtempVector%RvectorBlock(2))
        CALL lsyssc_clearVector (rtempVector%RvectorBlock(3))
      END IF
      
      CALL sptivec_setTimestepData(rd, isubstep, rtempVector)
      
    END DO
    
    CALL lsysbl_releaseVector(rtempVector)

  END SUBROUTINE

END MODULE
