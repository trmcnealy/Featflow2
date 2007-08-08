!##############################################################################
!# ****************************************************************************
!# <name> cc2dmediumm2timesupersystem </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module aims to solve the fully space-time coupled Stokes and
!# Navier-Stokes optimal control problem with a one-shot approach.
!# As this type of problem is of elliptic nature with a very special
!# structure, a nonlinear defect correction loop is executed for the solution
!# where a space-time coupled multigrid preconditioner does the preconditioning
!# of the nonlinear defect.
!#
!# The following subroutines can be found here:
!#
!# 1.) c2d2_solveSupersysDirectCN
!#     -> Only for nonstationary Stokes problem. Executes Crank-Nicolson on the
!#        fully space-time coupled system
!#
!# 2.) c2d2_solveSupersystemPrecond
!#     -> Solves the Stokes and Navier-Stokes problem with a preconditioned
!#        defect correction approach. Crank Nicolson is used for the time
!#        discretisation.
!#
!# Auxiliary routines:
!#
!# 1.) c2d2_assembleSpaceTimeDefect
!#     -> Calculates a space-time defect
!#
!# 2.) c2d2_precondDefectSupersystem
!#     -> Executes preconditioning on a space-time defect vector
!#
!# </purpose>
!##############################################################################

MODULE cc2dmediumm2timesupersystem

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
  USE cc2dmediumm2timeanalysis
  USE cc2dmediumm2boundary
  USE cc2dmediumm2discretisation
  USE cc2dmediumm2postprocessing
  USE cc2dmediumm2matvecassembly
  USE cc2dmediumm2spacetimediscret
  USE cc2dmediumm2spacetimesolver
  
  USE spacetimevectors
  USE dofmapping
  
  USE matrixio
    
  IMPLICIT NONE

CONTAINS

!  ! ***************************************************************************
!  
!!<subroutine>
!
!  SUBROUTINE c2d2_solveSupersysDirect (rproblem, rspaceTimeDiscr, rx, rd, &
!      rtempvectorX, rtempvectorB, rtempvectorD)
!
!!<description>
!  ! This routine assembles and solves the time-space coupled supersystem:
!  ! $Ax=b$. The RHS vector is generated on-the-fly.
!  ! The routine generates the full matrix in memory and solves with UMFPACK, 
!  ! so it should only be used for debugging!
!!</description>
!
!!<input>
!  ! A problem structure that provides information about matrices on all
!  ! levels as well as temporary vectors.
!  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!
!  ! A t_ccoptSpaceTimeDiscretisation structure defining the discretisation of the
!  ! coupled space-time matrix.
!  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr
!!</input>
!
!!<inputoutput>
!  ! A space-time vector defining the current solution.
!  ! Is replaced by the new solution
!  TYPE(t_spacetimeVector), INTENT(INOUT) :: rx
!
!  ! A temporary vector in the size of a spatial vector.
!  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorX
!
!  ! A second temporary vector in the size of a spatial vector.
!  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorB
!
!  ! A third temporary vector in the size of a spatial vector.
!  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorD
!
!  ! A space-time vector that receives the defect.
!  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd
!!</inputoutput>
!
!!</subroutine>
!
!    ! local variables
!    INTEGER :: isubstep,ilevel,ierror,i
!    TYPE(t_matrixBlock) :: rblockTemp
!    TYPE(t_matrixScalar) :: rmassLumped
!    TYPE(t_ccnonlinearIteration) :: rnonlinearIterationTmp
!    TYPE(t_vectorBlock) :: rxGlobal, rbGlobal, rdGlobal
!    TYPE(t_vectorBlock) :: rxGlobalSolve, rbGlobalSolve, rdGlobalSolve
!    TYPE(t_matrixBlock) :: rglobalA
!    TYPE(t_linsolNode), POINTER :: rsolverNode
!    TYPE(t_matrixBlock), DIMENSION(1) :: Rmatrices
!    INTEGER(PREC_VECIDX), DIMENSION(:), ALLOCATABLE :: Isize
!    INTEGER(PREC_VECIDX), DIMENSION(6) :: Isize2
!    
!    REAL(DP), DIMENSION(:),POINTER :: p_Dx, p_Db, p_Dd
!    
!    ! If the following constant is set from 1.0 to 0.0, the primal system is
!    ! decoupled from the dual system!
!    REAL(DP), PARAMETER :: dprimalDualCoupling = 0.0 !1.0
!
!    ilevel = rspaceTimeDiscr%ilevel
!    
!    ! Calculate the lumped mass matrix of the FE space -- we need it later!
!    CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass,&
!        rmassLumped, LSYSSC_DUP_SHARE, LSYSSC_DUP_SHARE)
!    CALL lsyssc_lumpMatrixScalar (rmassLumped,LSYSSC_LUMP_STD)
!    
!    ! ----------------------------------------------------------------------
!    ! 1.) Generate the global RHS vector
!    
!    CALL lsysbl_getbase_double (rtempVectorX,p_Dx)
!    CALL lsysbl_getbase_double (rtempVectorB,p_Db)
!    CALL lsysbl_getbase_double (rtempVectorD,p_Dd)
!
!    DO isubstep = 0,rspaceTimeDiscr%niterations
!    
!      ! Current point in time
!      rproblem%rtimedependence%dtime = &
!          rproblem%rtimedependence%dtimeInit + isubstep*rspaceTimeDiscr%dtstep
!          
!      ! Generate the RHS of that point in time.
!      CALL c2d2_generateBasicRHS (rproblem,rtempVectorB)
!      
!      ! Multiply the RHS of the dual velocity by dtstep according to the time
!      ! discretisation -- except for if we are in the last timestep!
!      !
!      ! In the last timestep, if GAMMA is =0, we have no terminal condition
!      ! and thus have to force the RHS to 0!
!      ! Otherwise, the terminat condition is multiplied with dgammaC.
!      IF (isubstep .NE. rspaceTimeDiscr%niterations) THEN
!        CALL lsyssc_scaleVector (rtempVectorB%RvectorBlock(4),rspaceTimeDiscr%dtstep)
!        CALL lsyssc_scaleVector (rtempVectorB%RvectorBlock(5),rspaceTimeDiscr%dtstep)
!      ELSE
!        ! Multiply -z by gamma, that's it.
!        CALL lsyssc_scaleVector (rtempVectorB%RvectorBlock(4),rspaceTimeDiscr%dgammaC)
!        CALL lsyssc_scaleVector (rtempVectorB%RvectorBlock(5),rspaceTimeDiscr%dgammaC)
!      END IF
!      
!      ! Initialise the collection for the assembly process with callback routines.
!      ! Basically, this stores the simulation time in the collection if the
!      ! simulation is nonstationary.
!      CALL c2d2_initCollectForAssembly (rproblem,rproblem%rcollection)
!
!      ! Discretise the boundary conditions at the new point in time -- 
!      ! if the boundary conditions are nonconstant in time!
!      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
!        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
!      END IF
!
!      ! Implement the boundary conditions into the RHS.
!      ! This is done *after* multiplying -z by GAMMA or dtstep, resp.,
!      ! as Dirichlet values mustn't be multiplied with GAMMA!
!      CALL vecfil_discreteBCsol (rtempVectorB)
!      CALL vecfil_discreteFBCsol (rtempVectorB)      
!      
!      CALL sptivec_setTimestepData(rd, isubstep, rtempVectorB)
!      
!      ! Clean up the collection (as we are done with the assembly, that's it.
!      CALL c2d2_doneCollectForAssembly (rproblem,rproblem%rcollection)
!
!    END DO
!
!    ! Release the mass matr, we don't need it anymore
!    CALL lsyssc_releaseMatrix (rmassLumped)
!    
!    ! ----------------------------------------------------------------------
!    ! 2.) Generate the matrix A
!    !
!    ! Create a global matrix:
!    CALL lsysbl_createEmptyMatrix (rglobalA,6*(rspaceTimeDiscr%niterations+1))
!    
!    ! Loop through the substeps
!    
!    DO isubstep = 0,rspaceTimeDiscr%niterations
!    
!      ! Current point in time
!      rproblem%rtimedependence%dtime = &
!          rproblem%rtimedependence%dtimeInit + isubstep*rspaceTimeDiscr%dtstep
!
!      ! -----
!      ! Discretise the boundary conditions at the new point in time -- 
!      ! if the boundary conditions are nonconstant in time!
!      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
!        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
!      END IF
!      
!      ! The first and last substep is a little bit special concerning
!      ! the matrix!
!      IF (isubstep .EQ. 0) THEN
!        
!        ! We are in the first substep
!      
!        ! -----
!      
!        ! Create a matrix that applies "-M" to the dual velocity and include it
!        ! to the global matrix.
!        CALL lsysbl_createMatBlockByDiscr (rtempVectorX%p_rblockDiscretisation,&
!            rblockTemp)
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(4,4),LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)
!        rblockTemp%RmatrixBlock(4,4)%dscaleFactor = -1.0_DP
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(5,5),LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)
!        rblockTemp%RmatrixBlock(5,5)%dscaleFactor = -1.0_DP
!        
!        ! Include the boundary conditions into that matrix.
!        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
!        ! main diagonal of the supermatrix.
!        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
!        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
!        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)
!        
!        ! Include "-M" in the global matrix at position (1,2).
!        CALL insertMatrix (rblockTemp,rglobalA,7,1)
!        
!        ! Release the block mass matrix.
!        CALL lsysbl_releaseMatrix (rblockTemp)
!      
!        ! -----
!        
!        ! Now the hardest -- or longest -- part: The diagonal matrix.
!        !
!        ! Generate the basic system matrix level rspaceTimeDiscr%ilevel
!        ! Will be modified by c2d2_assembleLinearisedMatrices later.
!        CALL c2d2_generateStaticSystemMatrix (rproblem%RlevelInfo(ilevel), &
!            rproblem%RlevelInfo(ilevel)%rmatrix,.FALSE.)
!      
!        ! Set up a core equation structure and assemble the nonlinear defect.
!        ! We use explicit Euler, so the weights are easy.
!      
!        CALL c2d2_initNonlinearLoop (&
!            rproblem,rproblem%NLMIN,rspaceTimeDiscr%ilevel,rtempVectorX,rtempVectorB,&
!            rnonlinearIterationTmp,'CC2D-NONLINEAR')
!
!        ! Set up all the weights in the core equation according to the current timestep.
!        rnonlinearIterationTmp%diota1 = 1.0_DP
!        rnonlinearIterationTmp%diota2 = 0.0_DP
!
!        rnonlinearIterationTmp%dkappa1 = 1.0_DP
!        rnonlinearIterationTmp%dkappa2 = 0.0_DP
!        
!        rnonlinearIterationTmp%dalpha1 = 0.0_DP
!        rnonlinearIterationTmp%dalpha2 = 1.0_DP
!        
!        rnonlinearIterationTmp%dtheta1 = 0.0_DP
!        rnonlinearIterationTmp%dtheta2 = rspaceTimeDiscr%dtstep
!        
!        rnonlinearIterationTmp%dgamma1 = 0.0_DP
!        rnonlinearIterationTmp%dgamma2 = rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
!        
!        rnonlinearIterationTmp%deta1 = 0.0_DP
!        rnonlinearIterationTmp%deta2 = rspaceTimeDiscr%dtstep
!        
!        rnonlinearIterationTmp%dtau1 = 0.0_DP
!        rnonlinearIterationTmp%dtau2 = 1.0_DP
!        
!        rnonlinearIterationTmp%dmu1 = 0.0_DP
!        rnonlinearIterationTmp%dmu2 = -rspaceTimeDiscr%dtstep
!        
!        ! Assemble the system matrix on level rspaceTimeDiscr%ilevel.
!        ! Include the boundary conditions into the matrices.
!        CALL c2d2_assembleLinearisedMatrices (rnonlinearIterationTmp,rproblem%rcollection,&
!            .FALSE.,.TRUE.,.FALSE.,.FALSE.,.FALSE.)
!            
!        ! Insert the system matrix for the dual equation to our global matrix.
!        CALL insertMatrix (rnonlinearIterationTmp%RcoreEquation(ilevel)%p_rmatrix,&
!            rglobalA,1,1)
!            
!      ELSE IF (isubstep .EQ. rspaceTimeDiscr%niterations) THEN
!        
!        ! We are in the last substep
!        
!        ! -----
!        
!        ! Create a matrix that applies "-M" to the primal velocity and include it
!        ! to the global matrix.
!        CALL lsysbl_createMatBlockByDiscr (rtempVectorX%p_rblockDiscretisation,&
!            rblockTemp)
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(1,1),LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
!        rblockTemp%RmatrixBlock(1,1)%dscaleFactor = -1.0_DP
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(2,2),LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
!        rblockTemp%RmatrixBlock(2,2)%dscaleFactor = -1.0_DP
!        
!        ! Include the boundary conditions into that matrix.
!        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
!        ! main diagonal of the supermatrix.
!        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
!        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
!        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)
!
!        ! Include "-M" in the global matrix at position (2,1).
!        CALL insertMatrix (rblockTemp,rglobalA,isubstep*6+1-6,isubstep*6+1)
!        
!        ! Release the block mass matrix.
!        CALL lsysbl_releaseMatrix (rblockTemp)
!      
!        ! -----
!        
!        ! Now the hardest -- or longest -- part: The diagonal matrix.
!        !
!        ! Generate the basic system matrix level rspaceTimeDiscr%ilevel
!        ! Will be modified by c2d2_assembleLinearisedMatrices later.
!        CALL c2d2_generateStaticSystemMatrix (rproblem%RlevelInfo(ilevel), &
!            rproblem%RlevelInfo(ilevel)%rmatrix,.FALSE.)
!      
!        ! Set up a core equation structure and assemble the nonlinear defect.
!        ! We use explicit Euler, so the weights are easy.
!      
!        CALL c2d2_initNonlinearLoop (&
!            rproblem,rproblem%NLMIN,rspaceTimeDiscr%ilevel,rtempVectorX,rtempVectorB,&
!            rnonlinearIterationTmp,'CC2D-NONLINEAR')
!
!        ! Set up all the weights in the core equation according to the current timestep.
!        rnonlinearIterationTmp%diota1 = 0.0_DP
!        rnonlinearIterationTmp%diota2 = 0.0_DP
!
!        rnonlinearIterationTmp%dkappa1 = 0.0_DP
!        rnonlinearIterationTmp%dkappa2 = 1.0_DP
!        
!        rnonlinearIterationTmp%dalpha1 = 1.0_DP
!        rnonlinearIterationTmp%dalpha2 = 1.0_DP
!        
!        rnonlinearIterationTmp%dtheta1 = rspaceTimeDiscr%dtstep
!        rnonlinearIterationTmp%dtheta2 = 0.0_DP
!        
!        rnonlinearIterationTmp%dgamma1 = rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
!        rnonlinearIterationTmp%dgamma2 = 0.0_DP
!        
!        rnonlinearIterationTmp%deta1 = rspaceTimeDiscr%dtstep
!        rnonlinearIterationTmp%deta2 = 0.0_DP
!        
!        rnonlinearIterationTmp%dtau1 = 1.0_DP
!        rnonlinearIterationTmp%dtau2 = 0.0_DP
!        
!        rnonlinearIterationTmp%dmu1 = dprimalDualCoupling * &
!            rspaceTimeDiscr%dtstep / rspaceTimeDiscr%dalphaC
!        rnonlinearIterationTmp%dmu2 = -rspaceTimeDiscr%dgammaC
!        
!        ! Assemble the system matrix on level rspaceTimeDiscr%ilevel.
!        ! Include the boundary conditions into the matrices.
!        CALL c2d2_assembleLinearisedMatrices (rnonlinearIterationTmp,rproblem%rcollection,&
!            .FALSE.,.TRUE.,.FALSE.,.FALSE.,.FALSE.)
!        
!        ! Insert the system matrix for the dual equation to our global matrix.
!        CALL insertMatrix (rnonlinearIterationTmp%RcoreEquation(ilevel)%p_rmatrix,&
!            rglobalA,isubstep*6+1,isubstep*6+1)
!
!        ! Release the block mass matrix.
!        CALL lsysbl_releaseMatrix (rblockTemp)
!      
!      ELSE
!      
!        ! We are sonewhere in the middle of the matrix. There is a substep
!        ! isubstep+1 and a substep isubstep-1!
!        
!        ! -----
!        
!        ! Create a matrix that applies "-M" to the dual velocity and include it
!        ! to the global matrix.
!        CALL lsysbl_createMatBlockByDiscr (rtempVectorX%p_rblockDiscretisation,&
!            rblockTemp)
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(4,4),LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)
!        rblockTemp%RmatrixBlock(4,4)%dscaleFactor = -1.0_DP
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(5,5),LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)
!        rblockTemp%RmatrixBlock(5,5)%dscaleFactor = -1.0_DP
!        
!        ! Include the boundary conditions into that matrix.
!        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
!        ! main diagonal of the supermatrix.
!        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
!        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
!        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)
!
!        ! Include that in the global matrix below the diagonal
!        CALL insertMatrix (rblockTemp,rglobalA,isubstep*6+7,isubstep*6+1)
!        
!        ! Release the block mass matrix.
!        CALL lsysbl_releaseMatrix (rblockTemp)
!      
!        ! -----
!        
!        ! Create a matrix that applies "-M" to the primal velocity and include it
!        ! to the global matrix.
!        CALL lsysbl_createMatBlockByDiscr (rtempVectorX%p_rblockDiscretisation,&
!            rblockTemp)
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(1,1),LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
!        rblockTemp%RmatrixBlock(1,1)%dscaleFactor = -1.0_DP
!        CALL lsyssc_duplicateMatrix (rspaceTimeDiscr%p_rlevelInfo%rmatrixMass, &
!            rblockTemp%RmatrixBlock(2,2),LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
!        rblockTemp%RmatrixBlock(2,2)%dscaleFactor = -1.0_DP
!        
!        ! Include the boundary conditions into that matrix.
!        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
!        ! main diagonal of the supermatrix.
!        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
!        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
!        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)
!
!        ! Include that in the global matrix above the diagonal
!        CALL insertMatrix (rblockTemp,rglobalA,isubstep*6+1-6,isubstep*6+1)
!        
!        ! Release the block mass matrix.
!        CALL lsysbl_releaseMatrix (rblockTemp)
!
!        ! -----      
!
!        ! Now the hardest -- or longest -- part: The diagonal matrix.
!        !
!        ! Generate the basic system matrix level rspaceTimeDiscr%ilevel
!        ! Will be modified by c2d2_assembleLinearisedMatrices later.
!        CALL c2d2_generateStaticSystemMatrix (rproblem%RlevelInfo(ilevel), &
!            rproblem%RlevelInfo(ilevel)%rmatrix,.FALSE.)
!      
!        ! Set up a core equation structure and assemble the nonlinear defect.
!        ! We use explicit Euler, so the weights are easy.
!      
!        CALL c2d2_initNonlinearLoop (&
!            rproblem,rproblem%NLMIN,rspaceTimeDiscr%ilevel,rtempVectorX,rtempVectorB,&
!            rnonlinearIterationTmp,'CC2D-NONLINEAR')
!
!        ! Set up all the weights in the core equation according to the current timestep.
!        rnonlinearIterationTmp%diota1 = 0.0_DP
!        rnonlinearIterationTmp%diota2 = 0.0_DP
!
!        rnonlinearIterationTmp%dkappa1 = 0.0_DP
!        rnonlinearIterationTmp%dkappa2 = 0.0_DP
!        
!        rnonlinearIterationTmp%dalpha1 = 1.0_DP
!        rnonlinearIterationTmp%dalpha2 = 1.0_DP
!        
!        rnonlinearIterationTmp%dtheta1 = rspaceTimeDiscr%dtstep
!        rnonlinearIterationTmp%dtheta2 = rspaceTimeDiscr%dtstep
!        
!        rnonlinearIterationTmp%dgamma1 = rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
!        rnonlinearIterationTmp%dgamma2 = rspaceTimeDiscr%dtstep * REAL(1-rproblem%iequation,DP)
!        
!        rnonlinearIterationTmp%deta1 = rspaceTimeDiscr%dtstep
!        rnonlinearIterationTmp%deta2 = rspaceTimeDiscr%dtstep
!        
!        rnonlinearIterationTmp%dtau1 = 1.0_DP
!        rnonlinearIterationTmp%dtau2 = 1.0_DP
!        
!        rnonlinearIterationTmp%dmu1 = dprimalDualCoupling * &
!            rspaceTimeDiscr%dtstep / rspaceTimeDiscr%dalphaC
!        rnonlinearIterationTmp%dmu2 = -rspaceTimeDiscr%dtstep
!      
!        ! Assemble the system matrix on level rspaceTimeDiscr%ilevel.
!        ! Include the boundary conditions into the matrices.
!        CALL c2d2_assembleLinearisedMatrices (rnonlinearIterationTmp,rproblem%rcollection,&
!            .FALSE.,.TRUE.,.FALSE.,.FALSE.,.FALSE.)
!        
!        ! Insert the system matrix for the dual equation to our global matrix.
!        CALL insertMatrix (rnonlinearIterationTmp%RcoreEquation(ilevel)%p_rmatrix,&
!            rglobalA,isubstep*6+1,isubstep*6+1)
!            
!      END IF
!    
!    END DO
!    
!    ! Update structural information of the global matrix.
!    CALL lsysbl_updateMatStrucInfo (rglobalA)
!
!    ! Write the global matrix to a file.
!    !CALL matio_writeBlockMatrixHR(rglobalA,'MATRIX',.TRUE.,0,'matrix.txt','(E13.2)')
!    
!    ! Get the global solution/rhs/temp vector.
!    CALL sptivec_convertSupervecToVector (rx, rxGlobal)
!    CALL sptivec_convertSupervecToVector (rd, rbGlobal)
!    CALL lsysbl_createVecBlockIndirect (rbGlobal,rdGlobal,.FALSE.)
!    
!    ! Initialise the UMFPACK solver.
!    CALL linsol_initUMFPACK4 (rsolverNode)
!    
!    ! Add the matrices
!    Rmatrices(1) = rglobalA
!    CALL linsol_setMatrices (rsolverNode,Rmatrices)
!    
!    ! Init the solver
!    CALL linsol_initStructure (rsolverNode,ierror)
!    CALL linsol_initData (rsolverNode,ierror)
!    
!    ! Reshape the x,b and d-vector to fit to our matrix.
!    CALL lsysbl_deriveSubvector(rxGlobal,rxGlobalSolve,bshare=.TRUE.)
!    CALL lsysbl_deriveSubvector(rbGlobal,rbGlobalSolve,bshare=.TRUE.)
!    CALL lsysbl_deriveSubvector(rdGlobal,rdGlobalSolve,bshare=.TRUE.)
!    ALLOCATE(Isize(rxGlobal%nblocks*6))
!    Isize2= (/rtempVectorB%RvectorBlock(1)%NEQ,&
!              rtempVectorB%RvectorBlock(2)%NEQ,&
!              rtempVectorB%RvectorBlock(3)%NEQ,&
!              rtempVectorB%RvectorBlock(4)%NEQ,&
!              rtempVectorB%RvectorBlock(5)%NEQ,&
!              rtempVectorB%RvectorBlock(6)%NEQ &
!             /)
!    DO i=0,rxGlobal%nblocks-1
!      Isize(i*6+1:i*6+6) = Isize2(1:6)
!    END DO
!    CALL lsysbl_enforceStructureDirect (Isize,rxGlobalSolve)
!    CALL lsysbl_enforceStructureDirect (Isize,rbGlobalSolve)
!    CALL lsysbl_enforceStructureDirect (Isize,rdGlobalSolve)
!    
!    ! Solve
!    CALL lsysbl_getbase_double (rxGlobalSolve,p_Dx)
!    CALL lsysbl_getbase_double (rbGlobalSolve,p_Db)
!    CALL linsol_solveAdaptively (rsolverNode,rxGlobalSolve,rbGlobalSolve,rdGlobalSolve)
!    
!    ! Release
!    CALL lsysbl_releaseVector (rxGlobalSolve)
!    CALL lsysbl_releaseVector (rbGlobalSolve)
!    CALL lsysbl_releaseVector (rdGlobalSolve)
!
!    CALL linsol_releaseSolver (rsolverNode)
!    CALL lsysbl_releaseVector (rdGlobal)
!    CALL lsysbl_releaseVector (rbGlobal)
!    
!    ! Remember the solution
!    CALL sptivec_convertVectorToSupervec (rxGlobal, rx) 
!    
!    ! Release the global matrix
!    CALL lsysbl_releaseMatrix (rglobalA)
!
!    CALL lsysbl_releaseVector (rxGlobal)
!    
!  CONTAINS
!  
!    SUBROUTINE insertMatrix (rsource,rdest,ileft,itop)
!    
!    ! Includes rsource into rdest at position ileft,itop
!    TYPE(t_matrixBlock), INTENT(IN) :: rsource
!    TYPE(t_matrixBlock), INTENT(INOUT) :: rdest
!    INTEGER, INTENT(IN) :: ileft
!    INTEGER, INTENT(IN) :: itop
!    
!    INTEGER :: i,j
!    
!    DO j=1,rsource%ndiagBlocks
!      DO i=1,rsource%ndiagBlocks
!        IF (lsysbl_isSubmatrixPresent (rsource,i,j)) THEN
!          IF (lsysbl_isSubmatrixPresent (rdest,i+itop-1,j+ileft-1)) THEN
!            CALL lsyssc_releaseMatrix (rdest%RmatrixBlock(j+ileft-1,i+itop-1))
!          END IF
!          CALL lsyssc_duplicateMatrix (rsource%RmatrixBlock(i,j),&
!              rdest%RmatrixBlock(i+itop-1,j+ileft-1),&
!              LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)
!        END IF
!      END DO
!    END DO
!        
!    END SUBROUTINE
!    
!  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_solveSupersysDirectCN (rproblem, rspaceTimeDiscr, rx, rd, &
      rtempvectorX, rtempvectorB, rtempvectorD)

!<description>
  ! This routine assembles and solves the time-space coupled supersystem:
  ! $Ax=b$. The RHS vector is generated on-the-fly.
  ! The routine generates the full matrix in memory and solves with UMFPACK, 
  ! so it should only be used for debugging!
  ! The routine assembles the global matrix with the time step scheme
  ! specified in dtimeStepTheta in the problem structure.
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

  ! A temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorX

  ! A second temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorB

  ! A third temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorD

  ! A space-time vector that receives the defect.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER :: isubstep,ilevel,ierror,i
    TYPE(t_matrixBlock) :: rblockTemp
    TYPE(t_vectorBlock) :: rxGlobal, rbGlobal, rdGlobal
    TYPE(t_vectorBlock) :: rxGlobalSolve, rbGlobalSolve, rdGlobalSolve
    TYPE(t_matrixBlock) :: rglobalA
    TYPE(t_linsolNode), POINTER :: rsolverNode,p_rpreconditioner
    TYPE(t_matrixBlock), DIMENSION(1) :: Rmatrices
    INTEGER(PREC_VECIDX), DIMENSION(:), ALLOCATABLE :: Isize
    INTEGER(PREC_VECIDX), DIMENSION(6) :: Isize2
    REAL(DP) :: dtheta
    TYPE(t_ccmatrixComponents) :: rmatrixComponents
    TYPE(t_matrixBlock), POINTER :: p_rmatrix
    
    REAL(DP), DIMENSION(:),POINTER :: p_Dx, p_Db, p_Dd

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

    ilevel = rspaceTimeDiscr%ilevel
    
    ! Theta-scheme identifier.
    ! =1: impliciz Euler.
    ! =0.5: Crank Nicolson
    dtheta = rproblem%rtimedependence%dtimeStepTheta
    
    ! Assemble the space-time RHS into rd.
    CALL c2d2_assembleSpaceTimeRHS (rproblem, rspaceTimeDiscr, rd, &
      rtempvectorX, rtempvectorB, rtempvectorD, .TRUE.)
      
    ! Implement the initial condition into the RHS.
    CALL c2d2_implementInitCondRHS (rproblem, rspaceTimeDiscr, &
        rx, rd, rtempvectorX, rtempvectorD)    

    ! ----------------------------------------------------------------------
    ! 2.) Generate the matrix A
    !
    ! Create a global matrix:
    CALL lsysbl_createEmptyMatrix (rglobalA,6*(rspaceTimeDiscr%niterations+1))

    ! Basic initialisation of rmatrixComponents with the pointers to the
    ! matrices / discretisation structures on the current level.
    !
    ! The weights in the rmatrixComponents structure are later initialised
    ! according to the actual situation when the matrix is to be used.
    rmatrixComponents%p_rdiscretisation         => &
        rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation
    rmatrixComponents%p_rmatrixStokes           => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixStokes          
    rmatrixComponents%p_rmatrixB1             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB1              
    rmatrixComponents%p_rmatrixB2             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB2              
    rmatrixComponents%p_rmatrixMass           => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixMass            
    rmatrixComponents%p_rmatrixIdentityPressure => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixIdentityPressure
    rmatrixComponents%dnu = collct_getvalue_real (rproblem%rcollection,'NU')
    rmatrixComponents%iupwind1 = collct_getvalue_int (rproblem%rcollection,'IUPWIND1')
    rmatrixComponents%dupsam1 = collct_getvalue_real (rproblem%rcollection,'UPSAM1')
    rmatrixComponents%iupwind2 = collct_getvalue_int (rproblem%rcollection,'IUPWIND2')
    rmatrixComponents%dupsam2 = collct_getvalue_real (rproblem%rcollection,'UPSAM2')

    
    ! Take a pointer to the preallocated system matrix. Use that as space
    ! for storing matrix data.
    p_rmatrix => rproblem%RlevelInfo(ilevel)%rpreallocatedSystemMatrix
    
    ! Loop through the substeps
    
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      ! Current point in time
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + isubstep*rspaceTimeDiscr%dtstep
      rproblem%rtimedependence%itimestep = isubstep

      ! -----
      ! Discretise the boundary conditions at the new point in time -- 
      ! if the boundary conditions are nonconstant in time!
      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
      END IF
      
      ! The first and last substep is a little bit special concerning
      ! the matrix!
      IF (isubstep .EQ. 0) THEN
        
        ! We are in the first substep
      
        ! -----
        
        ! The diagonal matrix.
      
        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,0,rmatrixComponents)
          
        ! Assemble the matrix
        CALL c2d2_assembleMatrix (CCMASM_COMPUTE,CCMASM_MTP_AUTOMATIC,&
            p_rmatrix,rmatrixComponents,ctypePrimalDual=0) 
          
        ! Assemble the system matrix on level rspaceTimeDiscr%ilevel.
        ! Include the boundary conditions into the matrices.
        !CALL c2d2_assembleLinearisedMatrices (&
        !    rnonlinearIterationTmp,rproblem%rcollection,&
        !    .FALSE.,.TRUE.,.FALSE.,.FALSE.,.FALSE.)
            
        ! Insert the system matrix for the dual equation to our global matrix.
        CALL insertMatrix (p_rmatrix,rglobalA,1,1)
            
        ! -----
      
        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the primal velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,1,rmatrixComponents)
      
        ! Assemble the matrix
        CALL c2d2_assembleMatrix (CCMASM_COMPUTE,CCMASM_MTP_AUTOMATIC,&
            p_rmatrix,rmatrixComponents,ctypePrimalDual=0) 
        
        CALL lsysbl_duplicateMatrix (&
            p_rmatrix,&
            rblockTemp,LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
       
        ! Include the boundary conditions into that matrix.
        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
        ! main diagonal of the supermatrix.
        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)

        ! We don't need submatrix (1,1) to (2,2).
        rblockTemp%RmatrixBlock(1:2,1:2)%dscaleFactor = 0.0_DP

        ! Include that in the global matrix below the diagonal
        CALL insertMatrix (rblockTemp,rglobalA,isubstep*6+1+6,isubstep*6+1)
        
        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)

      ELSE IF (isubstep .LT. rspaceTimeDiscr%niterations) THEN
        
        ! We are sonewhere in the middle of the matrix. There is a substep
        ! isubstep+1 and a substep isubstep-1!
        
        ! -----
        
        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the primal velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,-1,rmatrixComponents)

        ! Assemble the matrix
        CALL c2d2_assembleMatrix (CCMASM_COMPUTE,CCMASM_MTP_AUTOMATIC,&
            p_rmatrix,rmatrixComponents,ctypePrimalDual=0) 
        
        CALL lsysbl_duplicateMatrix (&
            p_rmatrix,rblockTemp,LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
       
        ! We don't need submatrix (4,4) to (5,5).
        rblockTemp%RmatrixBlock(4:5,4:5)%dscaleFactor = 0.0_DP

        ! Include the boundary conditions into that matrix.
        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
        ! main diagonal of the supermatrix.
        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)

        ! Include that in the global matrix below the diagonal
        CALL insertMatrix (rblockTemp,rglobalA,isubstep*6+1-6,isubstep*6+1)
        
        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)

        ! -----      

        ! Now the diagonal matrix.

        ! Assemble the nonlinear defect.
        ! We use explicit Euler, so the weights are easy.
      
        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,0,rmatrixComponents)
            
        ! Assemble the matrix
        CALL c2d2_assembleMatrix (CCMASM_COMPUTE,CCMASM_MTP_AUTOMATIC,&
            p_rmatrix,rmatrixComponents,ctypePrimalDual=0) 
        
        ! Insert the system matrix for the dual equation to our global matrix.
        CALL insertMatrix (p_rmatrix,&
            rglobalA,isubstep*6+1,isubstep*6+1)
            
        ! -----
        
        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the dual velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,1,rmatrixComponents)

        ! Assemble the matrix
        CALL c2d2_assembleMatrix (CCMASM_COMPUTE,CCMASM_MTP_AUTOMATIC,&
            p_rmatrix,rmatrixComponents,ctypePrimalDual=0) 
        
        CALL lsysbl_duplicateMatrix (&
            p_rmatrix,rblockTemp,LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
       
        ! We don't need submatrix (1,1) to (2,2).
        rblockTemp%RmatrixBlock(1:2,1:2)%dscaleFactor = 0.0_DP

        ! Include the boundary conditions into that matrix.
        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
        ! main diagonal of the supermatrix.
        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)

        ! Include that in the global matrix above the diagonal
        CALL insertMatrix (rblockTemp,rglobalA,isubstep*6+1+6,isubstep*6+1)
        
        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)

      ELSE
      
        ! We are in the last substep
        
        ! -----
        
        ! Create the matrix
        !   -M + dt*dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the dual velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,-1,rmatrixComponents)
      
        ! Assemble the matrix
        CALL c2d2_assembleMatrix (CCMASM_COMPUTE,CCMASM_MTP_AUTOMATIC,&
            p_rmatrix,rmatrixComponents,ctypePrimalDual=0) 
        
        CALL lsysbl_duplicateMatrix (&
            p_rmatrix,rblockTemp,LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
       
        ! We don't need submatrix (4,4) to (5,5).
        rblockTemp%RmatrixBlock(4:5,4:5)%dscaleFactor = 0.0_DP

        ! Include the boundary conditions into that matrix.
        ! Specify the matrix as 'off-diagonal' matrix because it's not on the
        ! main diagonal of the supermatrix.
        rblockTemp%imatrixSpec = LSYSBS_MSPEC_OFFDIAGSUBMATRIX
        CALL matfil_discreteBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteBC)
        CALL matfil_discreteFBC (rblockTemp,rproblem%RlevelInfo(ilevel)%p_rdiscreteFBC)

        ! Include that in the global matrix above the diagonal
        CALL insertMatrix (rblockTemp,rglobalA,isubstep*6+1-6,isubstep*6+1)

        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)

        ! -----
        
        ! The diagonal matrix.
      
        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,0,rmatrixComponents)
        
        ! Assemble the matrix
        CALL c2d2_assembleMatrix (CCMASM_COMPUTE,CCMASM_MTP_AUTOMATIC,&
            p_rmatrix,rmatrixComponents,ctypePrimalDual=0) 
        
        ! Insert the system matrix for the dual equation to our global matrix.
        CALL insertMatrix (p_rmatrix,rglobalA,isubstep*6+1,isubstep*6+1)

        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)
      
      END IF
    
    END DO
    
    ! Update structural information of the global matrix.
    CALL lsysbl_updateMatStrucInfo (rglobalA)

    ! Write the global matrix to a file.
    !CALL matio_writeBlockMatrixHR(rglobalA,'MATRIX',.TRUE.,0,'matrixcn.txt','(1X,E20.10)')
    !'(E13.2)')
    
    ! Get the global solution/rhs/temp vector.
    CALL sptivec_convertSupervecToVector (rx, rxGlobal)
    CALL sptivec_convertSupervecToVector (rd, rbGlobal)
    CALL lsysbl_createVecBlockIndirect (rbGlobal,rdGlobal,.FALSE.)
    
    ! Initialise the UMFPACK solver.
    !CALL linsol_initUMFPACK4 (rsolverNode)
    CALL linsol_initUMFPACK4 (p_rpreconditioner)
    CALL linsol_initDefCorr (rsolverNode,p_rpreconditioner)
    rsolverNode%ioutputLevel = 2
    rsolverNode%depsRel = 1E-10
    rsolverNode%nmaxIterations = 10
    
    ! Add the matrices
    Rmatrices(1) = rglobalA
    CALL linsol_setMatrices (rsolverNode,Rmatrices)
    
    ! Init the solver
    CALL linsol_initStructure (rsolverNode,ierror)
    CALL linsol_initData (rsolverNode,ierror)
    
    ! Reshape the x,b and d-vector to fit to our matrix.
    CALL lsysbl_deriveSubvector(rxGlobal,rxGlobalSolve,bshare=.TRUE.)
    CALL lsysbl_deriveSubvector(rbGlobal,rbGlobalSolve,bshare=.TRUE.)
    CALL lsysbl_deriveSubvector(rdGlobal,rdGlobalSolve,bshare=.TRUE.)
    ALLOCATE(Isize(rxGlobal%nblocks*6))
    Isize2= (/rtempVectorB%RvectorBlock(1)%NEQ,&
              rtempVectorB%RvectorBlock(2)%NEQ,&
              rtempVectorB%RvectorBlock(3)%NEQ,&
              rtempVectorB%RvectorBlock(4)%NEQ,&
              rtempVectorB%RvectorBlock(5)%NEQ,&
              rtempVectorB%RvectorBlock(6)%NEQ &
             /)
    DO i=0,rxGlobal%nblocks-1
      Isize(i*6+1:i*6+6) = Isize2(1:6)
    END DO
    CALL lsysbl_enforceStructureDirect (Isize,rxGlobalSolve)
    CALL lsysbl_enforceStructureDirect (Isize,rbGlobalSolve)
    CALL lsysbl_enforceStructureDirect (Isize,rdGlobalSolve)
    
    ! Solve
    CALL lsysbl_getbase_double (rxGlobalSolve,p_Dx)
    CALL lsysbl_getbase_double (rbGlobalSolve,p_Db)
    CALL linsol_solveAdaptively (rsolverNode,rxGlobalSolve,rbGlobalSolve,rdGlobalSolve)
    
    ! DEBUG!!!
    CALL lsysbl_blockMatVec (rglobalA,rxGlobalSolve,rbGlobalSolve,-1.0_DP,1.0_DP)
    !CALL lsyssc_scalarMatVec (rglobalA%RmatrixBlock(16,13),&
    !                          rxGlobalSolve%RvectorBlock(13),&
    !                          rbGlobalSolve%RvectorBlock(16),1.0_DP,-1.0_DP)
    
    ! Release
    CALL lsysbl_releaseVector (rxGlobalSolve)
    CALL lsysbl_releaseVector (rbGlobalSolve)
    CALL lsysbl_releaseVector (rdGlobalSolve)

    CALL linsol_releaseSolver (rsolverNode)
    CALL lsysbl_releaseVector (rdGlobal)
    CALL lsysbl_releaseVector (rbGlobal)
    
    ! Remember the solution
    CALL sptivec_convertVectorToSupervec (rxGlobal, rx) 
    
    ! Release the global matrix
    CALL lsysbl_releaseMatrix (rglobalA)

    CALL lsysbl_releaseVector (rxGlobal)
    
  CONTAINS
  
    SUBROUTINE insertMatrix (rsource,rdest,ileft,itop)
    
    ! Includes rsource into rdest at position ileft,itop
    TYPE(t_matrixBlock), INTENT(IN) :: rsource
    TYPE(t_matrixBlock), INTENT(INOUT) :: rdest
    INTEGER, INTENT(IN) :: ileft
    INTEGER, INTENT(IN) :: itop
    
    INTEGER :: i,j
    
    DO j=1,rsource%ndiagBlocks
      DO i=1,rsource%ndiagBlocks
        IF (lsysbl_isSubmatrixPresent (rsource,i,j)) THEN
          IF (lsysbl_isSubmatrixPresent (rdest,i+itop-1,j+ileft-1)) THEN
            CALL lsyssc_releaseMatrix (rdest%RmatrixBlock(j+ileft-1,i+itop-1))
          END IF
          CALL lsyssc_duplicateMatrix (rsource%RmatrixBlock(i,j),&
              rdest%RmatrixBlock(i+itop-1,j+ileft-1),&
              LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)
        END IF
      END DO
    END DO
        
    END SUBROUTINE
    
  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_assembleSpaceTimeDefect (rproblem, rspaceTimeDiscr, rx, rd, dnorm, rb,ry)

!<description>
  ! This routine assembles the space-time defect d=b-Ax. rd must have been
  ! initialised by the space-time RHS vector b. The routine will then
  ! calculate rd = rd - A rx to get the space-time defect.
  ! ry is an optional parameter that allows to specify where to evaluate the
  ! nonlinearity. If specified, the routine calculates rd = rd - A(ry) rx
!</description>

!<input>
  ! A problem structure that provides information about matrices on all
  ! levels as well as temporary vectors.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem

  ! A t_ccoptSpaceTimeDiscretisation structure defining the discretisation of the
  ! coupled space-time matrix.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr
  
  ! OPTIONAL: Evaluation point for A. If specified, A=A(ry) is used.
  ! If not soecified, the routine calculates A=A(rx)
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: ry
!</input>

!<inputoutput>
  ! A space-time vector defining the current solution.
  ! Is replaced by the new solution
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rx

  ! A space-time vector with the space-time RHS b. Is overwritten by
  ! d=b-Ax.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd

  ! OPTIONAL: A space-time vector with the space-time RHS b. 
  ! If not specified, the routine assumes that rd contains the RHS.
  TYPE(t_spacetimeVector), INTENT(INOUT), OPTIONAL :: rb
!</inputoutput>

!<output>
  ! OPTIONAL: If specified, returns the $l_2$-norm if the defect.
  REAL(DP), INTENT(OUT), OPTIONAL :: dnorm
!<output>

!</subroutine>

    ! local variables
    INTEGER :: isubstep,ilevel,icp
    TYPE(t_vectorBlock) :: rtempVectorD, rtempVector1, rtempVector2, rtempVector3
    TYPE(t_vectorBlock) :: rtempVectorEval1, rtempVectorEval2, rtempVectorEval3
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
    CALL lsysbl_getbase_double (rtempVector1,p_Dx1)
    CALL lsysbl_getbase_double (rtempVector2,p_Dx2)
    CALL lsysbl_getbase_double (rtempVector3,p_Dx3)
    CALL lsysbl_getbase_double (rtempVectorD,p_Db)
    
    ! Get the parts of the X-vector which are to be modified at first --
    ! subvector 1, 2 and 3.
    CALL sptivec_getTimestepData(rx, 0, rtempVector1)
    IF (rspaceTimeDiscr%niterations .GT. 0) &
      CALL sptivec_getTimestepData(rx, 1, rtempVector2)
    IF (rspaceTimeDiscr%niterations .GT. 1) &
      CALL sptivec_getTimestepData(rx, 2, rtempVector3)
      
    ! Create temp vectors for the evaluation point of the nonlinearity.
    ! If ry is not specified, share the vector content with rx, thus
    ! use ry=rx.
    IF (PRESENT(ry)) THEN
      CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVectorEval1,.FALSE.)
      CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVectorEval2,.FALSE.)
      CALL lsysbl_createVecBlockByDiscr (p_rdiscr,rtempVectorEval3,.FALSE.)
      
      ! Get the first three evaluation points
      CALL sptivec_getTimestepData(ry, 0, rtempVectorEval1)
      IF (rspaceTimeDiscr%niterations .GT. 0) &
        CALL sptivec_getTimestepData(ry, 1, rtempVectorEval2)
      IF (rspaceTimeDiscr%niterations .GT. 1) &
        CALL sptivec_getTimestepData(ry, 2, rtempVectorEval3)
    ELSE
      CALL lsysbl_duplicateVector (rtempVector1,rtempVectorEval1,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
      CALL lsysbl_duplicateVector (rtempVector2,rtempVectorEval2,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
      CALL lsysbl_duplicateVector (rtempVector3,rtempVectorEval3,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
    END IF
    
    ! If dnorm is specified, clear it.
    IF (PRESENT(dnorm)) THEN
      dnorm = 0.0_DP
    END IF

    ! Basic initialisation of rmatrixComponents with the pointers to the
    ! matrices / discretisation structures on the current level.
    !
    ! The weights in the rmatrixComponents structure are later initialised
    ! according to the actual situation when the matrix is to be used.
    rmatrixComponents%p_rdiscretisation         => &
        rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation
    rmatrixComponents%p_rmatrixStokes           => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixStokes          
    rmatrixComponents%p_rmatrixB1             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB1              
    rmatrixComponents%p_rmatrixB2             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB2              
    rmatrixComponents%p_rmatrixMass           => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixMass            
    rmatrixComponents%p_rmatrixIdentityPressure => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixIdentityPressure
    rmatrixComponents%dnu = collct_getvalue_real (rproblem%rcollection,'NU')
    rmatrixComponents%iupwind1 = collct_getvalue_int (rproblem%rcollection,'IUPWIND1')
    rmatrixComponents%dupsam1 = collct_getvalue_real (rproblem%rcollection,'UPSAM1')
    rmatrixComponents%iupwind2 = collct_getvalue_int (rproblem%rcollection,'IUPWIND2')
    rmatrixComponents%dupsam2 = collct_getvalue_real (rproblem%rcollection,'UPSAM2')
    
    ! Loop through the substeps
    
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      ! Current point in time
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + isubstep*rspaceTimeDiscr%dtstep
      rproblem%rtimedependence%itimestep = isubstep

      ! Get the part of rd which is to be modified.
      IF (PRESENT(rb)) THEN
        ! The RHS is in rb
        CALL sptivec_getTimestepData(rb, isubstep, rtempVectorD)
      ELSE
        ! The RHS is in rd
        CALL sptivec_getTimestepData(rd, isubstep, rtempVectorD)
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
        !   A12  :=  -M/dt + dtheta*[-nu\Laplace u + u \grad u]
        ! and subtract A12 x2 from rd.
        !
        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,1,rmatrixComponents)

        ! Subtract: rd = rd - A12 x2
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector2,rtempVectorD,&
            1.0_DP,rtempVectorEval2)

        ! Release the block mass matrix.
        CALL lsysbl_releaseMatrix (rblockTemp)
        
        ! The primal defect is =0 because of the initial condition.
        ! This is important, otherwise the nonlinear loop will not converge
        ! because of a lack in the defect in the 0th timestep!!!
        CALL lsyssc_clearVector (rtempVectorD%RvectorBlock(1))
        CALL lsyssc_clearVector (rtempVectorD%RvectorBlock(2))
        CALL lsyssc_clearVector (rtempVectorD%RvectorBlock(3))

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
            
        ! Subtract: rd = rd - Aii-1 xi-1
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector1,rtempVectorD,&
            1.0_DP,rtempVectorEval1)

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
        !   Ann-1 = -M/dt + dtheta*[-nu\Laplace u + u \grad u]
        ! and include that into the global matrix for the dual velocity.

        ! Set up the matrix weights of that submatrix.
        CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
          isubstep,-1,rmatrixComponents)
          
        ! Subtract: rd = rd - Ann-1 xn-1
        CALL c2d2_assembleDefect (rmatrixComponents,rtempVector2,rtempVectorD,&
            1.0_DP,rtempVectorEval2)
     
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
        IF (rproblem%MT_outputLevel .GE. 2) THEN
          CALL output_line ('||D_'//TRIM(sys_siL(isubstep,2))//'|| = '//&
              TRIM(sys_sdEL(&
                  SQRT(lsysbl_vectorNorm(rtempVectorD,LINALG_NORML2)&
                  ),10)) )
          DO icp=1,6
            CALL output_line ('  ||D_'//TRIM(sys_siL(isubstep,2))//'^'//TRIM(sys_siL(icp,2))&
                //'|| = '//&
                TRIM(sys_sdEL(&
                    SQRT(lsyssc_vectorNorm(rtempVectorD%RvectorBlock(icp),LINALG_NORML2)&
                    ),10)) )
          END DO
        END IF
        dnorm = dnorm + lsysbl_vectorNorm(rtempVectorD,LINALG_NORML2)**2
      END IF
      
      IF ((isubstep .GT. 0) .AND. &
          (isubstep .LT. rspaceTimeDiscr%niterations-1)) THEN
      
        ! Shift the timestep data: x_n+1 -> x_n -> x_n-1
        CALL lsysbl_copyVector (rtempVector2, rtempVector1)
        CALL lsysbl_copyVector (rtempVector3, rtempVector2)
        
        ! Get the new x_n+1 for the next pass through the loop.
        CALL sptivec_getTimestepData(rx, isubstep+2, rtempVector3)
        
        ! The same for the 'evaluation vector' ry -- if it's specified.
        ! If not specified, rtempVectorX and rtempVectorEvalX share the
        ! same memory, so we don't have to do anything.
        IF (PRESENT(ry)) THEN
          CALL lsysbl_copyVector (rtempVectorEval2, rtempVectorEval1)
          CALL lsysbl_copyVector (rtempVectorEval3, rtempVectorEval2)
          CALL sptivec_getTimestepData(ry, isubstep+2, rtempVectorEval3)
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

  SUBROUTINE c2d2_precondDefectSupersystem (rproblem, rspaceTimeDiscr, rx, rb, rd, &
      rtempvectorX,  rtempvectorD, rpreconditioner)

!<description>
  ! This routine performs preconditioning with the nonlinear super-defect
  ! vector rd: $d = C^{-1} d$.
!</description>

!<input>
  ! A problem structure that provides information about matrices on all
  ! levels as well as temporary vectors.
  TYPE(t_problem), INTENT(INOUT) :: rproblem

  ! A t_ccoptSpaceTimeDiscretisation structure defining the discretisation of the
  ! coupled space-time matrix.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr
  
  ! A space-time vector defining the current solution.
  TYPE(t_spacetimeVector), INTENT(IN) :: rx

  ! A space-time vector defining the current RHS.
  TYPE(t_spacetimeVector), INTENT(IN) :: rb

!</input>

!<inputoutput>
  ! A spatial preconditioner. This one is applied to each substep in the
  ! global matrix.
  TYPE(t_ccspatialPreconditioner), INTENT(INOUT) :: rpreconditioner
  
  ! A temporary vector in the size of a spatial vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorX

  ! A third temporary vector for the nonlinear iteration
  TYPE(t_vectorBlock), INTENT(INOUT) :: rtempVectorD
  
  ! A space-time vector that receives the preconditioned defect.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER :: isubstep,ilevel
    REAL(DP) :: dtheta,dtstep
    LOGICAL :: bsuccess
    TYPE(t_ccmatrixComponents) :: rmatrixComponents
    
    ! DEBUG!!!
    REAL(DP), DIMENSION(:), POINTER :: p_Dx,p_Dd
    
    dtheta = rproblem%rtimedependence%dtimeStepTheta
    dtstep = rspaceTimeDiscr%dtstep

    ! Level of the discretisation
    ilevel = rspaceTimeDiscr%ilevel
    
    ! The weights in the rmatrixComponents structure are later initialised
    ! according to the actual situation when the matrix is to be used.
    rmatrixComponents%p_rdiscretisation         => &
        rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation
    rmatrixComponents%p_rmatrixStokes           => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixStokes          
    rmatrixComponents%p_rmatrixB1             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB1              
    rmatrixComponents%p_rmatrixB2             => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixB2              
    rmatrixComponents%p_rmatrixMass           => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixMass            
    rmatrixComponents%p_rmatrixIdentityPressure => &
        rspaceTimeDiscr%p_rlevelInfo%rmatrixIdentityPressure
    rmatrixComponents%dnu = collct_getvalue_real (rproblem%rcollection,'NU')
    rmatrixComponents%iupwind1 = collct_getvalue_int (rproblem%rcollection,'IUPWIND1')
    rmatrixComponents%dupsam1 = collct_getvalue_real (rproblem%rcollection,'UPSAM1')
    rmatrixComponents%iupwind2 = collct_getvalue_int (rproblem%rcollection,'IUPWIND2')
    rmatrixComponents%dupsam2 = collct_getvalue_real (rproblem%rcollection,'UPSAM2')
    
    ! ----------------------------------------------------------------------
    ! We use a block-Jacobi scheme for preconditioning...
    !
    ! For this purpose, loop through the substeps.
    
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      ! Current time step?
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + isubstep * dtstep
      rproblem%rtimedependence%itimestep = isubstep

      CALL output_line ('Block-Jacobi preconditioning of timestep: '//&
          TRIM(sys_siL(isubstep,10))//&
          ' Time: '//TRIM(sys_sdL(rproblem%rtimedependence%dtime,10)))
    
      ! -----
      ! Discretise the boundary conditions at the new point in time -- 
      ! if the boundary conditions are nonconstant in time!
      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
      END IF

      ! DEBUG!!!      
      CALL lsysbl_getbase_double (rtempVectorX,p_Dx)
      CALL lsysbl_getbase_double (rtempVectorD,p_Dd)

      ! Read in the RHS/solution/defect vector of the current timestep.
      CALL sptivec_getTimestepData (rx, isubstep, rtempVectorX)
      CALL sptivec_getTimestepData (rd, isubstep, rtempVectorD)

      ! Set up the matrix weights for the diagonal matrix
      CALL c2d2_setupMatrixWeights (rproblem,rspaceTimeDiscr,dtheta,&
        isubstep,0,rmatrixComponents)
        
      ! Perform preconditioning of the defect with the method provided by the
      ! core equation module.
      CALL c2d2_precondDefect (rpreconditioner,rmatrixComponents,&
        rtempVectorD,rtempVectorX,bsuccess,rproblem%rcollection)      
    
      ! Save back the preconditioned defect.
      CALL sptivec_setTimestepData (rd, isubstep, rtempVectorD)
      
    END DO
    
  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_solveSupersystemDefCorr (rproblem, rspaceTimeDiscr, rx, rb, rd)
  
!<description>
  ! 
!</description>

!<input>
  ! A problem structure that provides information about matrices on all
  ! levels as well as temporary vectors.
  TYPE(t_problem), INTENT(INOUT) :: rproblem

  ! A t_ccoptSpaceTimeDiscretisation structure defining the discretisation of the
  ! coupled space-time matrix.
  TYPE(t_ccoptSpaceTimeDiscretisation), INTENT(IN) :: rspaceTimeDiscr
!</input>

!<inputoutput>
  ! A space-time vector defining the initial solution. Is replaced by a new
  ! solution vector.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rx

  ! A temporary space-time vector that receives the RHS during the calculation.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rb

  ! A temporary space-time vector that receives the defect during the calculation.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd
!</inputoutput>

!</subroutine>

    ! The nonlinear solver configuration
    INTEGER :: isubstep,iglobIter
    LOGICAL :: bneumann

    REAL(DP) :: ddefNorm,dinitDefNorm
    
    TYPE(t_ccspatialPreconditioner) :: rpreconditioner
    
    ! DEBUG!!!
    REAL(DP), DIMENSION(:), POINTER :: p_Dx

    ! A temporary vector in the size of a spatial vector.
    TYPE(t_vectorBlock) :: rtempVectorX

    ! A second temporary vector in the size of a spatial vector.
    TYPE(t_vectorBlock) :: rtempVectorB

    ! A third temporary vector for the nonlinear iteration
    TYPE(t_vectorBlock) :: rtempVector

    ! Create temp vectors for X, B and D.
    CALL lsysbl_createVecBlockByDiscr (rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation,&
        rtempVector,.TRUE.)
    CALL lsysbl_createVecBlockByDiscr (rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation,&
        rtempVectorX,.TRUE.)
    CALL lsysbl_createVecBlockByDiscr (rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation,&
        rtempVectorB,.TRUE.)
        
    ! Attach the boundary conditions to the temp vectors.
    rtempVector%p_rdiscreteBC => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC
    rtempVector%p_rdiscreteBCfict => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteFBC

    rtempVectorX%p_rdiscreteBC => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC
    rtempVectorX%p_rdiscreteBCfict => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteFBC

    rtempVectorB%p_rdiscreteBC => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC
    rtempVectorB%p_rdiscreteBCfict => rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteFBC

    ! Some preparations for the nonlinear solver.
    !
    ! Initialise the preconditioner for the nonlinear iteration
    CALL c2d2_initPreconditioner (rproblem,&
        rproblem%NLMIN,rproblem%NLMAX,rpreconditioner,0)
    CALL c2d2_configPreconditioner (rproblem,rpreconditioner)

    ! Implement the bondary conditions into all initial solution vectors
    DO isubstep = 0,rspaceTimeDiscr%niterations
    
      ! Current point in time
      rproblem%rtimedependence%dtime = &
          rproblem%rtimedependence%dtimeInit + isubstep*rspaceTimeDiscr%dtstep
      rproblem%rtimedependence%itimestep = isubstep

      ! -----
      ! Discretise the boundary conditions at the new point in time -- 
      ! if the boundary conditions are nonconstant in time!
      IF (collct_getvalue_int (rproblem%rcollection,'IBOUNDARY') .NE. 0) THEN
        CALL c2d2_updateDiscreteBC (rproblem, .FALSE.)
      END IF
      
      ! Implement the boundary conditions into the global solution vector.
      CALL sptivec_getTimestepData(rx, isubstep, rtempVectorX)
      
      ! DEBUG!!!
      CALL lsysbl_getbase_double (rtempVectorX,p_Dx)
      
      CALL c2d2_implementBC (rproblem,rvector=rtempVectorX)
      
      CALL sptivec_setTimestepData(rx, isubstep, rtempVectorX)
      
    END DO
    
    ddefNorm = 1.0_DP
    
    ! ---------------------------------------------------------------
    ! Solve the global space-time coupled system.
    !
    ! Get the initial defect: d=b-Ax
    !CALL c2d2_assembleDefectSupersystem (rproblem, rspaceTimeDiscr, rx, rd, &
    !    rtempvectorX, rtempvectorB, rtempVector, ddefNorm)
    CALL c2d2_assembleSpaceTimeRHS (rproblem, rspaceTimeDiscr, rb, &
      rtempvectorX, rtempvectorB, rtempvector, .FALSE.)    

    ! Implement the initial condition into the RHS.
    CALL c2d2_implementInitCondRHS (rproblem, rspaceTimeDiscr, &
        rx, rb, rtempvectorX, rtempvector)    

    ! Now work with rd, our 'defect' vector
    CALL sptivec_copyVector (rb,rd)

    ! Assemble the defect.
    CALL c2d2_assembleSpaceTimeDefect (rproblem, rspaceTimeDiscr, rx, rd, ddefNorm)
        
    dinitDefNorm = ddefNorm
    
    CALL output_separator (OU_SEP_EQUAL)
    CALL output_line ('Defect of supersystem: '//sys_sdEP(ddefNorm,20,10))
    CALL output_separator (OU_SEP_EQUAL)        

    iglobIter = 0
    
!    !CALL c2d2_solveSupersysDirect (rproblem, rspaceTimeDiscr, rx, rd, &
!    !  rtempvectorX, rtempvectorB, rtempVector)
!    CALL c2d2_solveSupersysDirectCN (rproblem, rspaceTimeDiscr, rx, rd, &
!      rtempvectorX, rtempvectorB, rtempVector)
    
    DO WHILE ((ddefNorm .GT. 1.0E-5*dinitDefNorm) .AND. (ddefNorm .LT. 1.0E99_DP) .AND. &
              (iglobIter .LT. 10))
    
      iglobIter = iglobIter+1
      
      ! Preconditioning of the defect: d=C^{-1}d
      CALL c2d2_precondDefectSupersystem (rproblem, rspaceTimeDiscr, rx, rb, rd, &
          rtempvectorX,  rtempVector, rpreconditioner)

      ! Add the defect: x = x + omega*d          
      CALL sptivec_vectorLinearComb (rd,rx,1.0_DP,1.0_DP)
          
      ! Assemble the new defect: d=b-Ax
      CALL sptivec_copyVector (rb,rd)
      CALL c2d2_assembleSpaceTimeDefect (rproblem, rspaceTimeDiscr, rx, rd, ddefNorm)
          
      CALL output_separator (OU_SEP_EQUAL)
      CALL output_line ('Iteration: '//sys_si(iglobIter,10)//&
          ' Defect of supersystem: '//sys_sdEP(ddefNorm,20,10))
      CALL output_separator (OU_SEP_EQUAL)
      
    END DO
    
    ! ---------------------------------------------------------------
    ! Release the preconditioner of the nonlinear iteration
    CALL c2d2_releasePreconditioner (rpreconditioner)
    
    !CALL c2d2_assembleDefectSupersystem (rproblem, rspaceTimeDiscr, rx, rd, &
    !    rtempvectorX, rtempvectorB, rtempVector, ddefNorm)
    CALL c2d2_assembleSpaceTimeRHS (rproblem, rspaceTimeDiscr, rd, &
      rtempvectorX, rtempvectorB, rtempvector,.FALSE.)

    ! Implement the initial condition into the RHS.
    CALL c2d2_implementInitCondRHS (rproblem, rspaceTimeDiscr, &
        rx, rd, rtempvectorX, rtempvector)    

    ! Assemble the defect
    CALL c2d2_assembleSpaceTimeDefect (rproblem, rspaceTimeDiscr, rx, rd, ddefNorm)
        
    CALL output_separator (OU_SEP_EQUAL)
    CALL output_line ('Defect of supersystem: '//sys_sdEP(ddefNorm,20,10))
    CALL output_separator (OU_SEP_EQUAL)        
    
    ! Do we have Neumann boundary?
    bneumann = collct_getvalue_int (rproblem%rcollection, 'INEUMANN') .EQ. YES
    
    IF (.NOT. bneumann) THEN
      ! Normalise the primal and dual pressure to zero.
      DO isubstep = 0,rspaceTimeDiscr%niterations
      
        CALL sptivec_getTimestepData(rx, isubstep, rtempVectorX)
        
        CALL vecfil_subvectorToL20 (rtempVectorX,3)
        CALL vecfil_subvectorToL20 (rtempVectorX,6)
        
        CALL sptivec_setTimestepData(rx, isubstep, rtempVectorX)
        
      END DO
      
    END IF
    
    CALL lsysbl_releaseVector (rtempVectorB)
    CALL lsysbl_releaseVector (rtempVectorX)
    CALL lsysbl_releaseVector (rtempVector)
          
  END SUBROUTINE
  
  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_solveSupersystemPrecond (rproblem, RspaceTimeDiscr, rx, rb, rd)
  
!<description>
  ! This subroutine solves the nonstationary space time coupled (Navier-)Stokes
  ! optimal control problem. For this purpose, a nonlinear defect correction
  ! loop is executed. Every defect is preconditioned by a space-time coupled
  ! preconditioner like Block-Jacobi, block SOR or whatever.
  !
  ! The caller must provide problem information in rproblem and a set of
  ! matrix configurations for all time levels which are allowed for the solver
  ! to use. If multiple time-levels are provided, space-time coupled multigrid
  ! is used for preconditioning. matrix configurations must be provided in
  ! RspaceTimeDiscr. The maximum level in this array defines the level where
  ! the system is solved. This level must correspond to the vectors rx, rb and 
  ! rd.
  !
  ! The caller can provide an initial solution in rx. However, rb is
  ! overwritten by a newly generated space-time coupled RHS vector.
  ! rd is used as temporary vector.
!</description>

!<input>
  ! A problem structure that provides information about matrices on all
  ! levels as well as temporary vectors.
  TYPE(t_problem), INTENT(INOUT) :: rproblem

  ! An array of t_ccoptSpaceTimeDiscretisation structure defining all the
  ! levels of the coupled space-time the discretisation.
  ! The solution/rhs rx/rb must correspond to the maximum level in this
  ! array.
  TYPE(t_ccoptSpaceTimeDiscretisation), DIMENSION(:), INTENT(IN), TARGET :: RspaceTimeDiscr
!</input>

!<inputoutput>
  ! A space-time vector defining the initial solution. Is replaced by a new
  ! solution vector.
  TYPE(t_spacetimeVector), INTENT(INOUT), TARGET :: rx

  ! A temporary space-time vector that receives the RHS during the calculation.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rb

  ! A temporary space-time vector that receives the defect during the calculation.
  TYPE(t_spacetimeVector), INTENT(INOUT) :: rd
!</inputoutput>

!</subroutine>

    ! The nonlinear solver configuration
    INTEGER :: isubstep,iglobIter,ierror,ilev,ispacelev,nsmSteps,cspaceTimePreconditioner
    INTEGER :: ilowerSpaceLevel,itemp
    LOGICAL :: bneumann
    REAL(DP), DIMENSION(4) :: Derror
    INTEGER(I32) :: nminIterations,nmaxIterations
    REAL(DP) :: depsRel,depsAbs,domega
    TYPE(t_ccoptSpaceTimeDiscretisation), POINTER :: p_rspaceTimeDiscr
    TYPE(t_ccspatialPreconditioner), DIMENSION(SIZE(RspaceTimeDiscr)) :: RspatialPrecond
    TYPE(t_ccspatialPreconditioner), DIMENSION(SIZE(RspaceTimeDiscr)) :: RspatialPrecondPrimal
    TYPE(t_ccspatialPreconditioner), DIMENSION(SIZE(RspaceTimeDiscr)) :: RspatialPrecondDual
    TYPE(t_sptiProjection), DIMENSION(SIZE(RspaceTimeDiscr)) :: RinterlevelProjection
    TYPE(t_ccoptSpaceTimeDiscretisation), DIMENSION(SIZE(RspaceTimeDiscr)) :: &
        myRspaceTimeDiscr
    TYPE(t_vectorBlock) :: rtempVecCoarse,rtempVecFine
    
    ! A solver node that identifies our solver.
    TYPE(t_sptilsNode), POINTER :: p_rprecond,p_rsolverNode
    TYPE(t_sptilsNode), POINTER :: p_rmgSolver,p_rsmoother,p_rcgrSolver
    TYPE(t_sptilsNode), POINTER :: p_rpresmoother,p_rpostsmoother

    REAL(DP) :: ddefNorm,dinitDefNorm
    
    ! DEBUG!!!
    REAL(DP), DIMENSION(:), POINTER :: p_Dx

    ! A temporary vector in the size of a spatial vector.
    TYPE(t_vectorBlock) :: rtempVectorX

    ! A second temporary vector in the size of a spatial vector.
    TYPE(t_vectorBlock) :: rtempVectorB

    ! A third temporary vector for the nonlinear iteration
    TYPE(t_vectorBlock) :: rtempVector
    
    ! Get a poiter to the discretisation structure on the maximum
    ! space/time level. That's the level where we solve here.
    p_rspaceTimeDiscr => RspaceTimeDiscr(SIZE(RspaceTimeDiscr))
    
    ! Create temp vectors for X, B and D.
    CALL lsysbl_createVecBlockByDiscr (&
        p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation,rtempVector,.TRUE.)
    CALL lsysbl_createVecBlockByDiscr (&
        p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation,rtempVectorX,.TRUE.)
    CALL lsysbl_createVecBlockByDiscr (&
        p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscretisation,rtempVectorB,.TRUE.)
        
    ! Attach the boundary conditions to the temp vectors.
    rtempVector%p_rdiscreteBC => p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC
    rtempVector%p_rdiscreteBCfict => p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteFBC

    rtempVectorX%p_rdiscreteBC => p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC
    rtempVectorX%p_rdiscreteBCfict => p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteFBC

    rtempVectorB%p_rdiscreteBC => p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteBC
    rtempVectorB%p_rdiscreteBCfict => p_rspaceTimeDiscr%p_rlevelInfo%p_rdiscreteFBC

    ! Implement the bondary conditions into all initial solution vectors
    CALL c2d2_implementBCsolution (rproblem,p_rspaceTimeDiscr,rx,rtempvectorX)
    
    ! Type of preconditioner to use for smoothing/solving in time?
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-MULTIGRID', &
        'cspaceTimePreconditioner', cspaceTimePreconditioner, 0)
    
    ! We set up a space-time preconditioner in the following configuration:
    ! Main Preconditioner: Multigrid
    !     -> Presmoother:  Block Jacobi/GS
    !     -> Postsmoother: Block Jacobi/GS
    !     -> CGr-Solver:   Defect correction
    !        -> Preconditioner: Block Jacobi
    !
    ! So we start creating the main solver: Multigrid.
    !
    ! Create as many time levels as specified by the length of RspatialPrecond.
    CALL sptils_initMultigrid (rproblem,1,SIZE(RspatialPrecond),p_rmgSolver)
    
    ! Loop over the time levels.
    DO ilev=1,SIZE(RspatialPrecond)
    
      IF (RspaceTimeDiscr(ilev)%ilevel .LT. rproblem%NLMAX) THEN
        ispacelev = MAX(rproblem%nlmin,rproblem%nlmax-SIZE(RspatialPrecond)+ilev)
      ELSE
        ispacelev = rproblem%nlmax
      END IF
      SELECT CASE (cspaceTimePreconditioner)
      CASE (0,2)
        ! Initialise the spatial preconditioner for Block Jacobi
        ! (note: this is slightly expensive in terms of memory!
        ! Probably we could use the same preconditioner for all levels,
        ! but this has still to be implemeted and is a little bit harder!)
        CALL c2d2_initPreconditioner (rproblem,rproblem%nlmin,&
            ispacelev,&
            RspatialPrecond(ilev),0)
        CALL c2d2_configPreconditioner (rproblem,RspatialPrecond(ilev))
         
      CASE (1)
        ! Initialise the spatial preconditioner for Block Gauss-Seidel
        ! (note: this is slightly expensive in terms of memory!
        ! Probably we could use the same preconditioner for all levels,
        ! but this has still to be implemeted and is a little bit harder!)
        CALL c2d2_initPreconditioner (rproblem,rproblem%nlmin,&
            ispacelev,&
            RspatialPrecondPrimal(ilev),1)
        CALL c2d2_configPreconditioner (rproblem,RspatialPrecondPrimal(ilev))

        CALL c2d2_initPreconditioner (rproblem,rproblem%nlmin,&
            ispacelev,&
            RspatialPrecondDual(ilev),2)
        CALL c2d2_configPreconditioner (rproblem,RspatialPrecondDual(ilev))
        
      END SELECT

      ! Generate an interlevel projection structure for that level.
      ! Note that space restriction/prolongation must be switched off if
      ! we are on the spatial coarse mesh!
      IF (ilev .GT. 1) THEN
        ilowerSpaceLevel = RspaceTimeDiscr(ilev-1)%ilevel
      ELSE
        ilowerSpaceLevel = ispacelev
      END IF
      CALL sptipr_initProjection (rinterlevelProjection(ilev),&
          RspaceTimeDiscr(ilev)%p_rlevelInfo%p_rdiscretisation,&
          ilowerSpaceLevel .NE. ispacelev)
         
      IF (ilev .EQ. 1) THEN
        ! ..., on the minimum level, create a coarse grid solver, ...
        NULLIFY(p_rsmoother)
        NULLIFY(p_rpresmoother)
        NULLIFY(p_rpostsmoother)
      
        SELECT CASE (cspaceTimePreconditioner)
        CASE (0)
          ! Block Jacobi preconditioner
          CALL sptils_initBlockJacobi (rproblem,p_rprecond,RspatialPrecond(ilev))

          ! Defect correction solver
          CALL sptils_initDefCorr (rproblem,p_rcgrSolver,p_rprecond)
          
        CASE (1)
          CALL sptils_initBlockFBGS (rproblem,p_rprecond,&
              RspatialPrecondPrimal(ilev),RspatialPrecondDual(ilev))

          ! Defect correction solver
          CALL sptils_initDefCorr (rproblem,p_rcgrSolver,p_rprecond)
          
        CASE (2)
          ! CG with Block Jacobi as preconditioner
          CALL sptils_initBlockJacobi (rproblem,p_rprecond,RspatialPrecond(ilev))

          ! CG solver        
          CALL sptils_initCG (rproblem,p_rcgrSolver,p_rprecond)
        END SELECT
        
        CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
            'nminIterations', p_rcgrSolver%nminIterations, 1)
        CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
            'nmaxIterations', p_rcgrSolver%nmaxIterations, 100)
        CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
                                    'depsRel', p_rcgrSolver%depsRel, 1E-5_DP)
        CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
                                    'depsAbs', p_rcgrSolver%depsAbs, 1E-5_DP)
        CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
                                    'domega', p_rcgrSolver%domega, 1.0_DP)
        CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
                                    'ddivRel', p_rcgrSolver%ddivRel, 1.0_DP)
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
                             'istoppingCriterion', p_rcgrSolver%istoppingCriterion, 0)


        CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-COARSEGRIDSOLVER', &
            'ioutputLevel', p_rcgrSolver%ioutputLevel, 100)
        p_rprecond%ioutputLevel = p_rcgrSolver%ioutputLevel-2
        
      ELSE
        ! ... on higher levels, create a Block Jacobi smoother, ...
        CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-SMOOTHER', &
                                    'domega', domega, 1.0_DP)
        CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-SMOOTHER', &
            'nsmSteps', nsmSteps, 1)

        SELECT CASE (cspaceTimePreconditioner)
        CASE (0)
          ! Block Jacobi
          CALL sptils_initBlockJacobi (rproblem,p_rsmoother,RspatialPrecond(ilev))
        CASE (1)
          ! Block Gauss-Seidel
          CALL sptils_initBlockFBGS (rproblem,p_rsmoother,&
              RspatialPrecondPrimal(ilev),RspatialPrecondDual(ilev))
        CASE (2)
          ! CG with Block Jacobi as preconditioner
          CALL sptils_initBlockJacobi (rproblem,p_rprecond,RspatialPrecond(ilev))
          CALL sptils_initCG (rproblem,p_rsmoother,p_rprecond)
        END SELECT
        
        CALL sptils_convertToSmoother (p_rsmoother,nsmSteps,domega)
        
        ! Switch off smoothing is set that way in the DAT file
        CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-SMOOTHER', &
                                  'ioutputLevel', p_rsmoother%ioutputLevel, 1)

        p_rpresmoother => p_rsmoother
        p_rpostsmoother => p_rsmoother
        CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-SMOOTHER', &
                                  'ipresmoothing', itemp, 1)
        IF (itemp .EQ. 0) NULLIFY(p_rpresmoother)
        CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-SMOOTHER', &
                                  'ipostsmoothing', itemp, 1)
        IF (itemp .EQ. 0) NULLIFY(p_rpostsmoother)

        ! NULLIFY(p_rsmoother)
        NULLIFY(p_rcgrSolver)
      END IF
       
      ! ...; finally initialise the level with that       
      CALL sptils_setMultigridLevel (p_rmgSolver,ilev,&
                    rinterlevelProjection(ilev),&
                    p_rpresmoother,p_rpostsmoother,p_rcgrSolver)
    END DO
    
    ! Our main solver is MG now.
    p_rsolverNode => p_rmgSolver
    
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-MULTIGRID', &
                             'nmaxIterations', p_rsolverNode%nmaxIterations, 1)
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-MULTIGRID', &
                             'nminIterations', p_rsolverNode%nminIterations, 10)
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-MULTIGRID', &
                             'ioutputLevel', p_rsolverNode%ioutputLevel, 0)
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-MULTIGRID', &
                             'icycle', p_rmgSolver%p_rsubnodeMultigrid%icycle, 0)
    CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-MULTIGRID', &
                                'depsRel', p_rmgSolver%depsRel, 1E-5_DP)
    CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-MULTIGRID', &
                                'depsAbs', p_rmgSolver%depsAbs, 1E-5_DP)
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-MULTIGRID', &
                             'istoppingCriterion', p_rmgSolver%istoppingCriterion, 0)
    
    ! Initialise the space-time coupled Block-Jacobi preconditioner.
    ! Attach the spatial preconditioner which is applied to each block.
    ! CALL sptils_initBlockJacobi (rproblem,p_rsolverNode,rspatialPrecond)
    
    ! Put a pointer to our rx into the space time discretisation on the maximum level
    myRspaceTimeDiscr = RspaceTimeDiscr
    myRspaceTimeDiscr(UBOUND(myRspaceTimeDiscr,1))%p_rsolution => rx
    
    ! Allocate space-time vectors on all lower levels that hold the solution vectors
    ! for the evaluation of the nonlinearity (if we have a nonlinearity).
    DO ilev=1,SIZE(RspatialPrecond)-1
      ALLOCATE(myRspaceTimeDiscr(ilev)%p_rsolution)
      CALL sptivec_initVector (myRspaceTimeDiscr(ilev)%p_rsolution,&
        dof_igetNDofGlobBlock(myRspaceTimeDiscr(ilev)%p_rlevelInfo%p_rdiscretisation),&
        myRspaceTimeDiscr(ilev)%niterations)   
    END DO
    ! Attach matrix information
    CALL sptils_setMatrices (p_rsolverNode,myRspaceTimeDiscr)
    ! Initialise the space-time preconditioner
    CALL sptils_initStructure (p_rsolverNode,ierror)
    CALL sptils_initData (p_rsolverNode,ierror)
    ddefNorm = 1.0_DP
    
    ! ---------------------------------------------------------------
    ! Solve the global space-time coupled system.
    !
    ! Get the initial defect: d=b-Ax
    CALL c2d2_assembleSpaceTimeRHS (rproblem, p_rspaceTimeDiscr, rb, &
      rtempvectorX, rtempvectorB, rtempvector, .FALSE.)    

    ! Implement the initial condition into the RHS.
    CALL c2d2_implementInitCondRHS (rproblem, p_rspaceTimeDiscr, &
        rx, rb, rtempvectorX, rtempvector)    

    ! Now work with rd, our 'defect' vector
    CALL sptivec_copyVector (rb,rd)

    ! Assemble the defect.
    CALL c2d2_assembleSpaceTimeDefect (rproblem, p_rspaceTimeDiscr, &
        rx, rd, ddefNorm)
        
    dinitDefNorm = ddefNorm
    CALL output_separator (OU_SEP_EQUAL)
    CALL output_line ('Defect of supersystem: '//sys_sdEP(ddefNorm,20,10))
    ! Value of the functional
    CALL c2d2_optc_nonstatFunctional (rproblem,&
        myRspaceTimeDiscr(SIZE(RspatialPrecond))%p_rsolution,&
        rtempVector,myRspaceTimeDiscr(SIZE(RspatialPrecond))%dalphaC,&
        myRspaceTimeDiscr(SIZE(RspatialPrecond))%dgammaC,&
        Derror)
    CALL output_line ('||y-z||       = '//TRIM(sys_sdEL(Derror(1),10)))
    CALL output_line ('||u||         = '//TRIM(sys_sdEL(Derror(2),10)))
    CALL output_line ('||y(T)-z(T)|| = '//TRIM(sys_sdEL(Derror(3),10)))
    CALL output_line ('J(y,u)        = '//TRIM(sys_sdEL(Derror(4),10)))
    CALL output_separator (OU_SEP_EQUAL)        

    ! Get configuration parameters from the DAT file
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-DISCRETISATION', &
                              'nminIterations', nminIterations, 1)
    CALL parlst_getvalue_int (rproblem%rparamList, 'TIME-DISCRETISATION', &
                             'nmaxIterations', nmaxIterations, 10)
    CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-DISCRETISATION', &
                                 'depsRel', depsRel, 1E-5_DP)
    CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-DISCRETISATION', &
                                 'depsAbs', depsAbs, 1E-5_DP)
    CALL parlst_getvalue_double (rproblem%rparamList, 'TIME-DISCRETISATION', &
                                 'domega', domega, 1.0_DP)

    iglobIter = 0
    
    DO WHILE ((iglobIter .LT. nminIterations) .OR. &
              ((ddefNorm .GT. depsRel*dinitDefNorm) .AND. (ddefNorm .GT. depsAbs) &
              .AND. (iglobIter .LT. nmaxIterations)))
    
      iglobIter = iglobIter+1
      
      ! Project the solution down to all levels, so the nonlinearity
      ! on the lower levels can be calculated correctly.
      ! Use the memory in rtempvectorX and rtempvectorB as temp memory;
      ! it's large enough.
      CALL lsysbl_duplicateVector (rtempvectorX,rtempVecFine,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
      CALL lsysbl_duplicateVector (rtempvectorB,rtempVecCoarse,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)

      DO ilev=SIZE(RspatialPrecond)-1,1,-1
        CALL lsysbl_enforceStructureDiscr(&
            myRspaceTimeDiscr(ilev+1)%p_rlevelInfo%p_rdiscretisation,rtempVecFine)
        rtempVecFine%p_rdiscreteBC =>&
            myRspaceTimeDiscr(ilev+1)%p_rlevelInfo%p_rdiscreteBC
        rtempVecFine%p_rdiscreteBCfict =>&
            myRspaceTimeDiscr(ilev+1)%p_rlevelInfo%p_rdiscreteFBC
            
        CALL lsysbl_enforceStructureDiscr(&
            myRspaceTimeDiscr(ilev)%p_rlevelInfo%p_rdiscretisation,rtempVecCoarse)
        rtempVecCoarse%p_rdiscreteBC =>&
            myRspaceTimeDiscr(ilev)%p_rlevelInfo%p_rdiscreteBC
        rtempVecCoarse%p_rdiscreteBCfict =>&
            myRspaceTimeDiscr(ilev)%p_rlevelInfo%p_rdiscreteFBC

        ! Interpolate down
        CALL sptipr_performInterpolation (RinterlevelProjection(ilev+1),&
            myRspaceTimeDiscr(ilev)%p_rsolution, myRspaceTimeDiscr(ilev+1)%p_rsolution,&
            rtempVecCoarse,rtempVecFine)
            
        ! Set boundary conditions
        CALL c2d2_implementBCsolution (rproblem,myRspaceTimeDiscr(ilev),&
            myRspaceTimeDiscr(ilev)%p_rsolution,rtempVecCoarse)
      END DO
      
      CALL lsysbl_releaseVector(rtempVecFine)
      CALL lsysbl_releaseVector(rtempVecCoarse)
          
      IF (rproblem%MT_outputLevel .GE. 2) THEN
        CALL output_line ('Writing solution to file '//&
            './ns/tmpsolution'//TRIM(sys_siL(iglobIter-1,10)))
        CALL sptivec_saveToFileSequence(&
            myRspaceTimeDiscr(SIZE(RspatialPrecond))%p_rsolution,&
            '(''./ns/tmpsolution'//TRIM(sys_siL(iglobIter-1,10))//'.'',I5.5)',&
            .TRUE.,rtempVectorX)
          
        DO ilev=1,SIZE(RspatialPrecond)
          CALL c2d2_postprocSpaceTimeGMV(rproblem,myRspaceTimeDiscr(ilev),&
              myRspaceTimeDiscr(ilev)%p_rsolution,&
              './gmv/iteration'//TRIM(sys_siL(iglobIter-1,10))//'level'//TRIM(sys_siL(ilev,10))//&
              '.gmv')
        END DO
      END IF
      
      IF (rproblem%MT_outputLevel .GE. 1) THEN
        ! Value of the functional
        CALL c2d2_optc_nonstatFunctional (rproblem,&
            myRspaceTimeDiscr(SIZE(RspatialPrecond))%p_rsolution,&
            rtempVector,myRspaceTimeDiscr(SIZE(RspatialPrecond))%dalphaC,&
            myRspaceTimeDiscr(SIZE(RspatialPrecond))%dgammaC,&
            Derror)
        CALL output_line ('||y-z||       = '//TRIM(sys_sdEL(Derror(1),10)))
        CALL output_line ('||u||         = '//TRIM(sys_sdEL(Derror(2),10)))
        CALL output_line ('||y(T)-z(T)|| = '//TRIM(sys_sdEL(Derror(3),10)))
        CALL output_line ('J(y,u)        = '//TRIM(sys_sdEL(Derror(4),10)))
      END IF
      
      ! Preconditioning of the defect: d=C^{-1}d
      IF (ASSOCIATED(p_rsolverNode)) THEN
        CALL sptils_precondDefect (p_rsolverNode,rd)
      END IF
      
      ! Filter the defect for boundary conditions in space and time.
      ! Normally this is done before the preconditioning -- but by doing it
      ! afterwards, the initial conditions can be seen more clearly!
      CALL c2d2_implementInitCondDefect (p_rspaceTimeDiscr,rd,rtempVector)
      CALL c2d2_implementBCdefect (rproblem,p_rspaceTimeDiscr,rd,rtempVector)
      
      ! Add the defect: x = x + omega*d          
      CALL sptivec_vectorLinearComb (rd,rx,domega,1.0_DP)
      
      ! Do we have Neumann boundary?
      bneumann = collct_getvalue_int (rproblem%rcollection, 'INEUMANN') .EQ. YES
      
      IF (.NOT. bneumann) THEN
        ! Normalise the primal and dual pressure to zero.
        DO isubstep = 0,p_rspaceTimeDiscr%niterations
        
          CALL sptivec_getTimestepData(rx, isubstep, rtempVectorX)
          
          CALL vecfil_subvectorToL20 (rtempVectorX,3)
          CALL vecfil_subvectorToL20 (rtempVectorX,6)
          
          CALL sptivec_setTimestepData(rx, isubstep, rtempVectorX)
          
        END DO
        
      END IF

      ! Assemble the new defect: d=b-Ax
      CALL sptivec_copyVector (rb,rd)
      CALL c2d2_assembleSpaceTimeDefect (rproblem, p_rspaceTimeDiscr, &
          rx, rd, ddefNorm)
          
      CALL output_separator (OU_SEP_EQUAL)
      CALL output_line ('Iteration: '//sys_si(iglobIter,10)//&
          ' Defect of supersystem: '//sys_sdEP(ddefNorm,20,10))
      CALL output_separator (OU_SEP_EQUAL)
      
    END DO
    
    CALL c2d2_assembleSpaceTimeRHS (rproblem, p_rspaceTimeDiscr, rd, &
      rtempvectorX, rtempvectorB, rtempvector,.FALSE.)

    ! Implement the initial condition into the RHS.
    CALL c2d2_implementInitCondRHS (rproblem, p_rspaceTimeDiscr, &
        rx, rd, rtempvectorX, rtempvector)    

    ! Assemble the defect
    CALL c2d2_assembleSpaceTimeDefect (rproblem, p_rspaceTimeDiscr, &  
        rx, rd, ddefNorm)
        
    CALL output_separator (OU_SEP_EQUAL)
    CALL output_line ('Defect of supersystem: '//sys_sdEP(ddefNorm,20,10))
    ! Value of the functional
    CALL c2d2_optc_nonstatFunctional (rproblem,&
        myRspaceTimeDiscr(SIZE(RspatialPrecond))%p_rsolution,&
        rtempVector,myRspaceTimeDiscr(SIZE(RspatialPrecond))%dalphaC,&
        myRspaceTimeDiscr(SIZE(RspatialPrecond))%dgammaC,&
        Derror)
    CALL output_line ('||y-z||       = '//TRIM(sys_sdEL(Derror(1),10)))
    CALL output_line ('||u||         = '//TRIM(sys_sdEL(Derror(2),10)))
    CALL output_line ('||y(T)-z(T)|| = '//TRIM(sys_sdEL(Derror(3),10)))
    CALL output_line ('J(y,u)        = '//TRIM(sys_sdEL(Derror(4),10)))
    CALL output_separator (OU_SEP_EQUAL)        

    ! Do we have Neumann boundary?
    bneumann = collct_getvalue_int (rproblem%rcollection, 'INEUMANN') .EQ. YES
    
    IF (.NOT. bneumann) THEN
      ! Normalise the primal and dual pressure to zero.
      DO isubstep = 0,p_rspaceTimeDiscr%niterations
      
        CALL sptivec_getTimestepData(rx, isubstep, rtempVectorX)
        
        CALL vecfil_subvectorToL20 (rtempVectorX,3)
        CALL vecfil_subvectorToL20 (rtempVectorX,6)
        
        CALL sptivec_setTimestepData(rx, isubstep, rtempVectorX)
        
      END DO
      
    END IF
    
    ! Release the space-time and spatial preconditioner. 
    ! We don't need them anymore.
    CALL sptils_releaseSolver (p_rsolverNode)
    
    ! Release the spatial preconditioner and temp vector on every level
    DO ilev=1,SIZE(RspatialPrecond)
      CALL c2d2_donePreconditioner (RspatialPrecondPrimal(ilev))
      CALL c2d2_donePreconditioner (RspatialPrecondDual(ilev))
      CALL c2d2_donePreconditioner (RspatialPrecond(ilev))
    END DO

    DO ilev=1,SIZE(RspatialPrecond)-1
      CALL sptivec_releaseVector (myRspaceTimeDiscr(ilev)%p_rsolution)
      DEALLOCATE(myRspaceTimeDiscr(ilev)%p_rsolution)
    END DO
          
    CALL lsysbl_releaseVector (rtempVectorB)
    CALL lsysbl_releaseVector (rtempVectorX)
    CALL lsysbl_releaseVector (rtempVector)
    
  END SUBROUTINE
  
END MODULE
