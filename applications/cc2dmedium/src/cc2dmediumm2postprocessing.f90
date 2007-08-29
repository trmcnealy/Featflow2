!##############################################################################
!# ****************************************************************************
!# <name> cc2dminim2postprocessing </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains postprocessing routines for the cc2dminim2_method2
!# CC2D solver.
!#
!# The following routines can be found here:
!#
!# 1.) c2d2_postprocessing
!#     -> Evaluate the solution of the stationary solver, write GMV-file.
!# </purpose>
!##############################################################################

MODULE cc2dmediumm2postprocessing

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
  
  USE collection
  USE convection
  
  USE ucd
  
  USE pprocnavierstokes
  USE pprocerror
  
  USE cc2dmediumm2basic
  USE cc2dmedium_callback
  
  IMPLICIT NONE
  
!<types>

!<typeblock>

  ! Postprocessing structure. Whenever the postprocessing calculation routines are
  ! called, they fill this structure using the current solution vector (and other
  ! information if necessary). The information in this structure can then be used
  ! for GMV output e.g.
  TYPE t_c2d2postprocessing

    ! A discretisation structure that describes a piecewise constant discretisation
    ! (usually P0 or Q0).
    TYPE(t_spatialDiscretisation) :: rdiscrConstant
    
    ! A discretisation structure that describes a piecewise linear discretisation
    ! (usually P1 or Q1).
    TYPE(t_spatialDiscretisation) :: rdiscrLinear

    ! A discretisation structure that describes a piecewise quadratic discretisation
    ! (usually P2 or Q2).
    TYPE(t_spatialDiscretisation) :: rdiscrQuadratic
    
    ! Whether nonstationary postprocessing should be used or not.
    LOGICAL              :: bnonstationaryPostprocessing
    
    ! Point in time when the next UCD file is to be written out
    REAL(DP)             :: dnextTimeUCD = 0.0_DP
    
    ! Next file extension for UCD output file.
    INTEGER              :: inextFileSuffixUCD = 0

    ! Point in time when the next Film file is to be written out
    REAL(DP)             :: dnextTimeFilm = 0.0_DP
    
    ! Next file extension for Film output file.
    INTEGER              :: inextFileSuffixFilm = 0

    ! A vector that describes the X-velocity field in the vertices
    TYPE(t_vectorScalar) :: rvectorVelX

    ! A vector that describes the Y-velocity field in the vertices
    TYPE(t_vectorScalar) :: rvectorVelY

    ! A vector that describes the pressure field in the vertices
    TYPE(t_vectorScalar) :: rvectorPressure

    ! A vector that describes the pressure field in the cells
    TYPE(t_vectorScalar) :: rvectorPressureCells

    ! A vector that describes the streamfunction
    TYPE(t_vectorScalar) :: rvectorStreamfunction
    
    ! A vector that describes the H1-error of the velocity field in the vertices
    TYPE(t_vectorScalar) :: rvectorH1err

    ! A vector that describes the H1-error of the pressure in the cells
    TYPE(t_vectorScalar) :: rvectorH1errCells
  
  END TYPE

!</typeblock>

!</types>
  
CONTAINS

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_postprocessingStationary (rproblem,rvector,rpostprocessing)
  
!<description>
  ! Postprocessing of solutions of stationary simulations.
  ! Writes the solution into a GMV file, calculates forces,...
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem

  ! Postprocvessing structure. 
  TYPE(t_c2d2postprocessing), INTENT(INOUT) :: rpostprocessing
!</inputoutput>

!<input>
  ! The solution vector which is to be evaluated by the postprocessing routines.
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
!</input>

!</subroutine>

    ! Calculate body forces.
    CALL c2d2_calculateBodyForces (rvector,rproblem)
    
    ! Calculate the divergence
    CALL c2d2_calculateDivergence (rvector,rproblem)
    
    ! Error analysis, comparison to reference function.
    CALL c2d2_errorAnalysis (rvector,rproblem)
    
    ! Write the UCD export file (GMV, AVS,...) as configured in the DAT file.
    CALL c2d2_writeUCD (rpostprocessing, rvector, rproblem)
    
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_postprocessingNonstat (rproblem,rvector,rpostprocessing)
  
!<description>
  ! Postprocessing of solutions of stationary simulations.
  ! Writes the solution into a GMV file, calculates forces,...
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem

  ! Postprocvessing structure. Defines what to do with solution vectors.
  TYPE(t_c2d2postprocessing), INTENT(INOUT) :: rpostprocessing
!</inputoutput>

!<input>
  ! The solution vector which is to be evaluated by the postprocessing routines.
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
!</input>

!</subroutine>

    ! Calculate body forces.
    CALL c2d2_calculateBodyForces (rvector,rproblem)
    
    ! Calculate the divergence
    CALL c2d2_calculateDivergence (rvector,rproblem)

    ! Error analysis, comparison to reference function.
    CALL c2d2_errorAnalysis (rvector,rproblem)
    
    ! Write the UCD export file (GMV, AVS,...) as configured in the DAT file.
    CALL c2d2_writeUCD (rpostprocessing, rvector, rproblem, &
        rproblem%rtimedependence%dtime)
    
    ! Write film output (raw data vectors)
    CALL c2d2_writeFilm (rpostprocessing, rvector, rproblem, &
        rproblem%rtimedependence%dtime)
    
  END SUBROUTINE

!******************************************************************************

!<subroutine>

  SUBROUTINE c2d2_errorAnalysis (rsolution,rproblem)

!<description>
  ! Performs error analysis on a given solution rsolution as specified
  ! in the .DAT file.
  ! The result of the error analysis is written to the standard output.
!</description>
  
!<input>
  ! Solution vector to compute the norm/error from.
  TYPE(t_vectorBlock), INTENT(IN) :: rsolution
!</input>

!<inputoutput>
  ! Problem structure.
  TYPE(t_problem), INTENT(INOUT) :: rproblem
!</inputoutput>

!</subroutine>
    
    ! local variables
    REAL(DP),DIMENSION(3) :: Derr
    REAL(DP) :: derrorVel, derrorP
    INTEGER :: icalcL2,icalcH1
    
    CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                     'IERRORANALYSISL2', icalcL2, 0)
    CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                     'IERRORANALYSISH1', icalcH1, 0)
    
    IF ((icalcL2 .NE. 0) .OR. (icalcH1 .NE. 0)) THEN
      CALL output_lbrk()
      CALL output_line ('Error Analysis')
      CALL output_line ('--------------')
    END IF
    
    IF (icalcL2 .NE. 0) THEN
    
      CALL c2d2_initCollectForAssembly (rproblem,rproblem%rcollection)
    
      ! Perform error analysis to calculate and add 1/2||u-z||_{L^2}.
      CALL pperr_scalar (rsolution%RvectorBlock(1),PPERR_L2ERROR,Derr(1),&
                         ffunction_TargetX,rproblem%rcollection)

      CALL pperr_scalar (rsolution%RvectorBlock(2),PPERR_L2ERROR,Derr(2),&
                         ffunction_TargetY,rproblem%rcollection)
                         
      derrorVel = (0.5_DP*(Derr(1)**2+Derr(2)**2))

      CALL pperr_scalar (rsolution%RvectorBlock(3),PPERR_L2ERROR,Derr(3),&
                         ffunction_TargetP,rproblem%rcollection)

      derrorP = Derr(3)
      
      CALL output_line ('||u-reference||_L2 = '//TRIM(sys_sdEP(derrorVel,15,6)) )
      CALL output_line ('||p-reference||_L2 = '//TRIM(sys_sdEP(derrorP,15,6)) )
      
      CALL c2d2_doneCollectForAssembly (rproblem,rproblem%rcollection)
      
    END IF

    IF (icalcL2 .NE. 0) THEN
    
      CALL c2d2_initCollectForAssembly (rproblem,rproblem%rcollection)
    
      ! Perform error analysis to calculate and add 1/2||u-z||_{L^2}.
      CALL pperr_scalar (rsolution%RvectorBlock(1),PPERR_H1ERROR,Derr(1),&
                         ffunction_TargetX,rproblem%rcollection)

      CALL pperr_scalar (rsolution%RvectorBlock(2),PPERR_H1ERROR,Derr(2),&
                         ffunction_TargetY,rproblem%rcollection)
                         
      derrorVel = (0.5_DP*(Derr(1)**2+Derr(2)**2))

      CALL output_line ('||u-reference||_H1 = '//TRIM(sys_sdEP(derrorVel,15,6)) )
      
      CALL c2d2_doneCollectForAssembly (rproblem,rproblem%rcollection)
      
    END IF
    
  END SUBROUTINE

!******************************************************************************

!<subroutine>

  SUBROUTINE c2d2_calculateBodyForces (rsolution,rproblem)

!<description>
  ! Calculates body forces as configured in the .DAT file.
  ! The result is written to the standard output.
!</description>
  
!<input>
  ! Solution vector to compute the norm/error from.
  TYPE(t_vectorBlock), INTENT(IN) :: rsolution
!</input>

!<inputoutput>
  ! Problem structure.
  TYPE(t_problem), INTENT(INOUT) :: rproblem
!</inputoutput>

!</subroutine>
    
    ! local variables
    
    ! Forces on the object
    REAL(DP), DIMENSION(NDIM2D) :: Dforces
    REAL(DP) :: df1,df2
    TYPE(t_boundaryRegion) :: rregion
    
    ! If we have a uniform discretisation, calculate the body forces on the
    ! 2nd boundary component - if it exists.
    IF ((rsolution%p_rblockDiscretisation%RspatialDiscretisation(1)% &
         ccomplexity .EQ. SPDISC_UNIFORM) .AND. &
        (boundary_igetNBoundComp(rproblem%p_rboundary) .GE. 2)) THEN

      ! Calculate drag-/lift coefficients on the 2nd boundary component.
      ! This is for the benchmark channel!
      CALL boundary_createRegion (rproblem%p_rboundary, &
          2, 0, rregion)
      rregion%iproperties = BDR_PROP_WITHSTART+BDR_PROP_WITHEND
      df1 = 1.0_DP/1000.0_DP
      df2 = 0.1_DP * 0.2_DP**2
      CALL ppns2D_bdforces_uniform (rsolution,rregion,Dforces,CUB_G1_1D,df1,df2)

      CALL output_lbrk()
      CALL output_line ('Body forces')
      CALL output_line ('-----------')
      CALL output_line ('Body forces real bd., bdc/horiz/vert')
      CALL output_line (' 2 / ' &
          //TRIM(sys_sdEP(Dforces(1),15,6)) // ' / '&
          //TRIM(sys_sdEP(Dforces(2),15,6)) )
      
    ENDIF
    
  END SUBROUTINE

!******************************************************************************

!<subroutine>

  SUBROUTINE c2d2_calculateDivergence (rsolution,rproblem)

!<description>
  ! Calculates the divergence of a solution.
  ! The result is written to the standard output.
!</description>
  
!<input>
  ! Solution vector to compute the norm/error from.
  TYPE(t_vectorBlock), INTENT(IN) :: rsolution
!</input>

!<inputoutput>
  ! Problem structure.
  TYPE(t_problem), INTENT(INOUT) :: rproblem
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER :: ieltype
    TYPE(t_matrixScalar) :: rBmatrix
    TYPE(t_vectorScalar), TARGET :: rtempVector
    
    IF (rsolution%p_rblockDiscretisation%RspatialDiscretisation(1)% &
        ccomplexity .EQ. SPDISC_UNIFORM) THEN
        
      ieltype = rsolution%p_rblockDiscretisation%RspatialDiscretisation(1)% &
                RelementDistribution(1)%itrialElement
                
      IF (elem_getPrimaryElement(ieltype) .EQ. EL_Q1T) THEN
      
        ! Create a temporary vector 
        CALL lsyssc_createVecByDiscr (rsolution%RvectorBlock(3)%p_rspatialDiscretisation,&
            rtempVector,.TRUE.)

        ! Calculate divergence = B1^T u1 + B2^T u2
        CALL lsyssc_transposeMatrix (rproblem%RlevelInfo(rproblem%nlmax)%rmatrixB1,&
            rBmatrix,LSYSSC_TR_VIRTUAL)
        CALL lsyssc_scalarMatVec (&
            rBmatrix, rsolution%RvectorBlock(1), &
            rtempVector, 1.0_DP, 0.0_DP)
        CALL lsyssc_transposeMatrix (rproblem%RlevelInfo(rproblem%nlmax)%rmatrixB2,&
            rBmatrix,LSYSSC_TR_VIRTUAL)
        CALL lsyssc_scalarMatVec (&
            rBmatrix, rsolution%RvectorBlock(2), &
            rtempVector, 1.0_DP, 1.0_DP)
        
        CALL output_lbrk()
        CALL output_line ('Divergence')
        CALL output_line ('----------')
        CALL output_line ('Divergence = ' &
            //TRIM(sys_sdEP(lsyssc_vectorNorm(rtempVector,LINALG_NORML2),15,6)) )
            
        CALL lsyssc_releaseVector (rtempVector)
      
      END IF
      
    END IF    
    
  END SUBROUTINE

!******************************************************************************

!<subroutine>

  SUBROUTINE c2d2_writeUCD (rpostprocessing,rvector,rproblem,dtime)

!<description>
  ! Writes an UCD postprocessing file as configured in the DAT file.
  ! (-> GMV, AVS, Paraview,...)
!</description>
  
!<input>
  ! Solution vector.
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
  
  ! OPTIONAL: Simulation time.
  ! Must be ommitted in stationary simulations.
  REAL(DP), INTENT(IN), OPTIONAL :: dtime
!</input>

!<inputoutput>
  ! Problem structure.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
  
  ! Postprocessing structure. Must have been initialised prior
  ! to calling this routine.
  ! The time stamp of the last written out GMV is updated.
  TYPE(t_c2d2postprocessing), INTENT(INOUT) :: rpostprocessing  
!</inputoutput>

!</subroutine>

    ! local variables

    ! We need some more variables for postprocessing - i.e. writing
    ! a GMV file.
    REAL(DP), DIMENSION(:), POINTER :: p_Ddata,p_Ddata2

    ! A pointer to the triangulation.
    TYPE(t_triangulation), POINTER :: p_rtriangulation
    
    ! A vector accepting Q1 data
    TYPE(t_vectorBlock) :: rprjVector
    
    ! A discretisation structure for Q1
    TYPE(t_blockDiscretisation) :: rprjDiscretisation
    
    ! Discrete boundary conditions for the output vector
    TYPE(t_discreteBC), POINTER :: p_rdiscreteBC
    TYPE(t_discreteFBC), POINTER :: p_rdiscreteFBC
    
    ! Output block for UCD output to GMV file
    TYPE(t_ucdExport) :: rexport
    
    REAL(DP) :: dminTime, dmaxTime, dtimeDifferenceUCD
    INTEGER :: ioutputUCD,ieltype,ilevelUCD
    
    CHARACTER(SYS_STRLEN) :: sfile,sfilename
    
    IF (PRESENT(dtime)) THEN
      ! In a nonstationary simulation, first check if we are allowed
      ! to write something.

      CALL parlst_getvalue_double (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                      'DMINTIMEUCD', dminTime, -1.E100_DP)
      CALL parlst_getvalue_double (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                      'DMAXTIMEUCD', dmaxTime, 1.E100_DP)
      CALL parlst_getvalue_double (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                      'DTIMEDIFFERENCEUCD', dtimeDifferenceUCD, 0.0_DP)
                                      
      IF ((dtime .LT. dminTime) .OR. (dtime .GT. dmaxTime)) RETURN
      
      IF (dtimeDifferenceUCD .GT. 0.0_DP) THEN
        IF (rpostprocessing%dnextTimeUCD .GT.  dtime) RETURN
      ELSE IF (dtimeDifferenceUCD .LT. 0.0_DP) THEN
        IF (rpostprocessing%dnextTimeUCD .LT. dtime) RETURN
      END IF
      ! Otherwise: Always write!
      
    END IF

    ! Type of output:    
    CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
                              'IOUTPUTUCD', ioutputUCD, 0)
    IF (ioutputUCD .EQ. 0) RETURN

    ! Level of output:
    CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
                              'ILEVELUCD', ilevelUCD, 0)
    IF (ilevelUCD .LE. 0) THEN
      ilevelUCD = rproblem%NLMAX+ilevelUCD
    END IF
    
    ilevelUCD = MIN(rproblem%NLMAX,MAX(rproblem%NLMIN,ilevelUCD))
    
    ! The solution vector is probably not in the way, GMV likes it!
    ! GMV for example does not understand Q1~ vectors!
    ! Therefore, we first have to convert the vector to a form that
    ! GMV understands.
    ! GMV understands only Q1 solutions! So the task is now to create
    ! a Q1 solution from rvector and write that out.
    !
    ! For this purpose, first create a 'derived' simple discretisation
    ! structure based on Q1 by copying the main guiding block discretisation
    ! structure and modifying the discretisation structures of the
    ! two velocity subvectors:
    
    CALL spdiscr_duplicateDiscrBlock(rvector%p_rblockDiscretisation,rprjDiscretisation)
    
    CALL spdiscr_deriveSimpleDiscrSc (&
                 rvector%p_rblockDiscretisation%RspatialDiscretisation(1), &
                 EL_Q1, CUB_G2X2, &
                 rprjDiscretisation%RspatialDiscretisation(1))

    CALL spdiscr_deriveSimpleDiscrSc (&
                 rvector%p_rblockDiscretisation%RspatialDiscretisation(2), &
                 EL_Q1, CUB_G2X2, &
                 rprjDiscretisation%RspatialDiscretisation(2))
                 
    ! The pressure discretisation substructure stays the old.
    !
    ! Now set up a new solution vector based on this discretisation,
    ! allocate memory.
    CALL lsysbl_createVecBlockByDiscr (rprjDiscretisation,rprjVector,.FALSE.)
    
    ! Then take our original solution vector and convert it according to the
    ! new discretisation:
    CALL spdp_projectSolution (rvector,rprjVector)

    ! Initialise the collection for the assembly process with callback routines.
    ! Basically, this stores the simulation time in the collection if the
    ! simulation is nonstationary.
    CALL c2d2_initCollectForAssembly (rproblem,rproblem%rcollection)

    ! Discretise the boundary conditions according to the Q1/Q1/Q0 
    ! discretisation for implementing them into a solution vector.
    NULLIFY(p_rdiscreteBC)
    CALL bcasm_discretiseBC (rprjDiscretisation,p_rdiscreteBC, &
                            .FALSE.,getBoundaryValues,rproblem%rcollection,&
                            BCASM_DISCFORSOL)
                            
    ! Connect the vector to the BC's
    rprjVector%p_rdiscreteBC => p_rdiscreteBC
    
    ! The same way, discretise boundary conditions of fictitious boundary components.
    NULLIFY(p_rdiscreteFBC)
    CALL bcasm_discretiseFBC (rprjDiscretisation,p_rdiscreteFBC, &
                              .FALSE.,getBoundaryValuesFBC,rproblem%rcollection,&
                              BCASM_DISCFORSOL)
    rprjVector%p_rdiscreteBCfict => p_rdiscreteFBC
    
    ! Filter the solution vector to implement discrete BC's.
    CALL vecfil_discreteBCsol (rprjVector)

    ! Filter the solution vector to implement discrete BC's for fictitious 
    ! boundary components.
    CALL vecfil_discreteFBCsol (rprjVector)
    
    ! Clean up the collection (as we are done with the assembly, that's it.
    CALL c2d2_doneCollectForAssembly (rproblem,rproblem%rcollection)

    ! Basic filename
    CALL parlst_getvalue_string (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                 'SFILENAMEUCD', sfile, '')
                                 
    ! Remove possible ''-characters
    READ(sfile,*) sfilename
    
    ! Create the actual filename
    sfile = TRIM(ADJUSTL(sfilename))//'.'//sys_si0(rpostprocessing%inextFileSuffixUCD,5)
                                 
    ! Now we have a Q1/Q1/Q0 solution in rprjVector -- on the level NLMAX.
    ! The next step is to project it down to level ilevelUCD.
    ! Due to the fact that solutions are usually 2-level-ordered,
    ! this can be shortened by taking only the first NVT vertices
    ! of the solution vector!
    
    ! From the attached discretisation, get the underlying triangulation
    ! of that level
    p_rtriangulation => rproblem%RlevelInfo(ilevelUCD)%rtriangulation
    
    ! Start UCD export to GMV file:
    CALL output_lbrk ()
    CALL output_line ('Writing GMV file: '//sfile)
    
    SELECT CASE (ioutputUCD)
    CASE (1)
      CALL ucd_startGMV (rexport,UCD_FLAG_STANDARD,p_rtriangulation,sfile)

    CASE (2)
      CALL ucd_startAVS (rexport,UCD_FLAG_STANDARD,p_rtriangulation,sfile)
          
    CASE (3)
      CALL ucd_startVTK (rexport,UCD_FLAG_STANDARD,p_rtriangulation,sfile)
          
    CASE DEFAULT
      CALL output_line ('Invalid UCD ooutput type.', &
                        OU_CLASS_ERROR,OU_MODE_STD,'mysubroutine')
      STOP
    END SELECT
        
    ! Is there a simulation time?
    IF (PRESENT(dtime)) &
      CALL ucd_setSimulationTime (rexport,dtime)
    
    ! Write the configuration of the application as comment block
    ! to the output file.
    CALL ucd_addCommentLine (rexport,'Configuration:')
    CALL ucd_addCommentLine (rexport,'---------------')
    CALL ucd_addParameterList (rexport,rproblem%rparamList)
    CALL ucd_addCommentLine (rexport,'---------------')

    ! Write velocity field
    CALL lsyssc_getbase_double (rprjVector%RvectorBlock(1),p_Ddata)
    CALL lsyssc_getbase_double (rprjVector%RvectorBlock(2),p_Ddata2)
    
    ! CALL ucd_addVariableVertexBased (rexport,'X-vel',UCD_VAR_XVELOCITY, &
    !     p_Ddata(1:p_rtriangulation%NVT))
    ! CALL ucd_addVariableVertexBased (rexport,'Y-vel',UCD_VAR_YVELOCITY, &
    !     p_Ddata2(1:p_rtriangulation%NVT))
    CALL ucd_addVarVertBasedVec (rexport,'velocity',&
        p_Ddata(1:p_rtriangulation%NVT),p_Ddata2(1:p_rtriangulation%NVT))
    
    ! Write pressure
    CALL lsyssc_getbase_double (rprjVector%RvectorBlock(3),p_Ddata)
    CALL ucd_addVariableElementBased (rexport,'pressure',UCD_VAR_STANDARD, &
        p_Ddata(1:p_rtriangulation%NEL))
    
    ! If we have a simple Q1~ discretisation, calculate the streamfunction.
    IF (rvector%p_rblockDiscretisation%RspatialDiscretisation(1)% &
        ccomplexity .EQ. SPDISC_UNIFORM) THEN
        
      ieltype = rvector%p_rblockDiscretisation%RspatialDiscretisation(1)% &
                RelementDistribution(1)%itrialElement
                
      IF (elem_getPrimaryElement(ieltype) .EQ. EL_Q1T) THEN
          
        CALL ppns2D_streamfct_uniform (rvector,rprjVector%RvectorBlock(1))
        
        CALL lsyssc_getbase_double (rprjVector%RvectorBlock(1),p_Ddata)
        CALL ucd_addVariableVertexBased (rexport,'streamfunction',&
            UCD_VAR_STANDARD, p_Ddata(1:p_rtriangulation%NVT))
            
      END IF
      
    END IF
    
    ! Write the file to disc, that's it.
    CALL ucd_write (rexport)
    CALL ucd_release (rexport)
    
    ! Release the auxiliary vector
    CALL lsysbl_releaseVector (rprjVector)
    
    ! Release the discretisation structure.
    CALL spdiscr_releaseBlockDiscr (rprjDiscretisation)
    
    ! Throw away the discrete BC's - not used anymore.
    CALL bcasm_releaseDiscreteBC (p_rdiscreteBC)
    CALL bcasm_releaseDiscreteFBC (p_rdiscreteFBC)
    
    IF (PRESENT(dtime)) THEN
      ! Update time stamp of last written out GMV.
      rpostprocessing%dnextTimeUCD = rpostprocessing%dnextTimeUCD+dtimeDifferenceUCD
      rpostprocessing%inextFileSuffixUCD = rpostprocessing%inextFileSuffixUCD + 1
    END IF

  END SUBROUTINE

!******************************************************************************

!<subroutine>

  SUBROUTINE c2d2_writeFilm (rpostprocessing,rvector,rproblem,dtime)

!<description>
  ! Writes Film output (raw data vectors) to a file as configured in the 
  ! DAT file.
  !
  ! Note: This file is usually only used in a nonstationary simulation.
  ! In a stationary simulation, Film output makes no sense!
!</description>
  
!<input>
  ! Solution vector.
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
  
  ! Simulation time.
  REAL(DP), INTENT(IN) :: dtime
!</input>

!<inputoutput>
  ! Problem structure.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
  
  ! Postprocessing structure. Must have been initialised prior
  ! to calling this routine.
  ! The time stamp of the last written out Film file is updated.
  TYPE(t_c2d2postprocessing), INTENT(INOUT) :: rpostprocessing  
!</inputoutput>

!</subroutine>

    ! local variables
    REAL(DP) :: dminTime, dmaxTime, dtimeDifferenceFilm
    INTEGER :: ioutputFilm,ilevelFilm
    
    TYPE(t_vectorBlock) :: rvector1,rvector2
    TYPE(t_vectorScalar) :: rvectorTemp
    CHARACTER(LEN=SYS_STRLEN) :: sfile,sfilename
    INTEGER :: ilev
    INTEGER(PREC_VECIDX) :: NEQ
    TYPE(t_interlevelProjectionBlock) :: rprojection 
    LOGICAL :: bformatted
    
    ! Type of output:    
    CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
                              'IOUTPUTFILM', ioutputFilm, 0)
    IF (ioutputFilm .EQ. 0) RETURN

    ! First check if we are allowed to write something.
    CALL parlst_getvalue_double (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                    'DMINTIMEFILM', dminTime, -1.E100_DP)
    CALL parlst_getvalue_double (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                    'DMAXTIMEFILM', dmaxTime, 1.E100_DP)
    CALL parlst_getvalue_double (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                    'DTIMEDIFFERENCEFILM', dtimeDifferenceFilm, 0.0_DP)
                                    
    IF ((dtime .LT. dminTime) .OR. (dtime .GT. dmaxTime)) RETURN
    
    IF (dtimeDifferenceFilm .GT. 0.0_DP) THEN
      IF (rpostprocessing%dnextTimeFilm .GT.  dtime) RETURN
    ELSE IF (dtimeDifferenceFilm .LT. 0.0_DP) THEN
      IF (rpostprocessing%dnextTimeFilm .LT. dtime) RETURN
    END IF

    ! Basic filename
    CALL parlst_getvalue_string (rproblem%rparamList, 'CC-POSTPROCESSING', &
                                 'SFILENAMEFILM', sfile, '')
                                 
    ! Remove possible ''-characters
    READ(sfile,*) sfilename
    
    ! Create the actual filename
    sfile = TRIM(ADJUSTL(sfilename))//'.'//sys_si0(rpostprocessing%inextFileSuffixFilm,5)
                                 
    ! Level of output:
    CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
                              'ILEVELFILM', ilevelFilm, 0)
    IF (ilevelFilm .LE. 0) THEN
      ilevelFilm = rproblem%NLMAX+ilevelFilm
    END IF
    
    ilevelFilm = MIN(rproblem%NLMAX,MAX(rproblem%NLMIN,ilevelFilm))
    
    IF (ilevelFilm .LT. rproblem%NLMIN) THEN
      PRINT *,'Warning: Level for solution vector is < NLMIN! &
              &Writing out at level NLMIN!'
      ilevelFilm = rproblem%NLMIN
    END IF
    
    ! Write formatted output?
    bformatted = ioutputFilm .NE. 2

    ! Interpolate the solution down to level istart.
    CALL lsysbl_copyVector (rvector,rvector1)   ! creates new rvector1!

    DO ilev = rproblem%NLMAX,ilevelFilm+1,-1
      
      ! Initialise a vector for the lower level and a prolongation structure.
      CALL lsysbl_createVectorBlock (&
          rproblem%RlevelInfo(ilev-1)%p_rdiscretisation,rvector2,.FALSE.)
      
      CALL mlprj_initProjectionVec (rprojection,rvector2)
      
      ! Interpolate to the next higher level.
      ! (Don't 'restrict'! Restriction would be for the dual space = RHS vectors!)

      NEQ = mlprj_getTempMemoryVec (rprojection,rvector2,rvector1)
      IF (NEQ .NE. 0) CALL lsyssc_createVector (rvectorTemp,NEQ,.FALSE.)
      CALL mlprj_performInterpolation (rprojection,rvector2,rvector1, &
                                       rvectorTemp)
      IF (NEQ .NE. 0) CALL lsyssc_releaseVector (rvectorTemp)
      
      ! Swap rvector1 and rvector2. Release the fine grid vector.
      CALL lsysbl_swapVectors (rvector1,rvector2)
      CALL lsysbl_releaseVector (rvector2)
      
      CALL mlprj_doneProjection (rprojection)
      
    END DO

    CALL output_lbrk ()
    CALL output_line ('Writing Film file: '//sfile)

    ! Write out the solution.
    IF (bformatted) THEN
      CALL vecio_writeBlockVectorHR (rvector1, 'SOLUTION', .TRUE.,&
         0, sfile, '(E22.15)')
    ELSE
      CALL vecio_writeBlockVectorHR (rvector1, 'SOLUTION', .TRUE.,0, sfile)
    END IF

    ! Release temp memory.
    CALL lsysbl_releaseVector (rvector1)

    ! Update time stamp of last written out Film file.
    rpostprocessing%dnextTimeFilm = rpostprocessing%dnextTimeFilm+dtimeDifferenceFilm
    rpostprocessing%inextFileSuffixFilm = rpostprocessing%inextFileSuffixFilm + 1

  END SUBROUTINE

  !****************************************************************************

!<subroutine>

  SUBROUTINE c2d2_initpostprocessing (rproblem,rpostprocessing)

!<description>
  ! Initialises the given postprocessing structure rpostprocessing
  ! according to the main problem rproblem. The structure can then be used
  ! to generate postprocessing data.
!</description>

!<input>
  ! A problem structure that describes the main problem to solve.
  TYPE(t_problem), INTENT(IN),TARGET :: rproblem
!</input>

!<output>  
  ! Postprocvessing structure.
  TYPE(t_c2d2postprocessing), INTENT(OUT) :: rpostprocessing
!</output>

!</subroutine>

  ! local variables
  TYPE(t_blockDiscretisation), POINTER :: p_rdiscr

    ! For postprocessing, we need discretisation structures in the Q0 and Q1 space,
    ! later perhaps in the Q2 space. For this purpose, derive the corresponding
    ! discretisation structure using the 'main' discretisation structure on the
    ! maximum level.
    !
    ! For simplicity, we use only the discretisation structure of the X-velocity
    ! to derive everything.
    
    p_rdiscr => rproblem%RlevelInfo(rproblem%NLMAX)%p_rdiscretisation

    ! Piecewise constant space:
    CALL spdiscr_deriveSimpleDiscrSc (&
                 p_rdiscr%RspatialDiscretisation(1), &
                 EL_Q0, CUB_G1X1, &
                 rpostprocessing%rdiscrConstant)

    ! Piecewise linear space:
    CALL spdiscr_deriveSimpleDiscrSc (&
                 p_rdiscr%RspatialDiscretisation(1), &
                 EL_Q1, CUB_G2X2, &
                 rpostprocessing%rdiscrLinear)
  
    ! Piecewise quadratic space:
    CALL spdiscr_deriveSimpleDiscrSc (&
                 p_rdiscr%RspatialDiscretisation(1), &
                 EL_Q2, CUB_G3X3, &
                 rpostprocessing%rdiscrQuadratic)
  
    ! Initialise the time/file suffix when the first UCD file is to be written out.
    rpostprocessing%bnonstationaryPostprocessing = (rproblem%itimedependence .NE. 0)
    IF (rproblem%itimedependence .NE. 0) THEN
      rpostprocessing%dnextTimeUCD = rproblem%rtimedependence%dtimeInit
      CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
         'ISTARTSUFFIXUCD', rpostprocessing%inextFileSuffixUCD, 1)
      
      rpostprocessing%dnextTimeFilm = rproblem%rtimedependence%dtimeInit
      CALL parlst_getvalue_int (rproblem%rparamList, 'CC-POSTPROCESSING', &
         'ISTARTSUFFIXFILM', rpostprocessing%inextFileSuffixFilm, 1)
    END IF
                                    
  END SUBROUTINE

  !****************************************************************************

!<subroutine>

  SUBROUTINE c2d2_copyPostprocessing (rpostprocessingSrc,rpostprocessingDst)

!<description>
  ! Copies the state of the postprocessing from rpostprocessingSrc
  ! to rpostprocessingDst.
  ! This is typically called to back up or to restore the current state
  ! of a running postprocessing structure.
!</description>

!<input>
  ! Source Postprocessing structure.
  TYPE(t_c2d2postprocessing), INTENT(IN) :: rpostprocessingSrc
!</input>

!<inputoutput>  
  ! Destination Postprocessing structure.
  TYPE(t_c2d2postprocessing), INTENT(INOUT) :: rpostprocessingDst
!</inputoutput>

!</subroutine>

    ! Initialise the time/file suffix when the first UCD file is to be written out.
    IF (rpostprocessingSrc%bnonstationaryPostprocessing) THEN
      rpostprocessingDst%bnonstationaryPostprocessing = &
          rpostprocessingSrc%bnonstationaryPostprocessing

      rpostprocessingDst%dnextTimeUCD = rpostprocessingSrc%dnextTimeUCD
      rpostprocessingDst%inextFileSuffixUCD = rpostprocessingSrc%inextFileSuffixUCD

      rpostprocessingDst%dnextTimeFilm = rpostprocessingSrc%dnextTimeFilm
      rpostprocessingDst%inextFileSuffixFilm = rpostprocessingSrc%inextFileSuffixFilm
    END IF
                                    
  END SUBROUTINE

  !****************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_clearpostprocessing (rpostprocessing)

!<description>
  ! Releases all calculated data in the given postprocessing structure
  ! so that it can be allocated again in the calculation routines.
  ! This routine must be called at the end of the postprocessing routines
  ! to release the temporary memory that was allocated for the vectors
  ! in the postprocessing structure.
!</description>

!<inputoutput>  
  ! Postprocvessing structure.
  TYPE(t_c2d2postprocessing), INTENT(INOUT) :: rpostprocessing
!</inputoutput>

!</subroutine>

    ! Release all vectors which might be allocated.
    IF (rpostprocessing%rvectorVelX%NEQ .NE. 0) &
      CALL lsyssc_releaseVector (rpostprocessing%rvectorVelX)
    IF (rpostprocessing%rvectorVelY%NEQ .NE. 0) &
      CALL lsyssc_releaseVector (rpostprocessing%rvectorVelY)
    IF (rpostprocessing%rvectorPressure%NEQ .NE. 0) &
      CALL lsyssc_releaseVector (rpostprocessing%rvectorPressure)
    IF (rpostprocessing%rvectorPressureCells%NEQ .NE. 0) &
      CALL lsyssc_releaseVector (rpostprocessing%rvectorPressureCells)
    IF (rpostprocessing%rvectorStreamfunction%NEQ .NE. 0) &
      CALL lsyssc_releaseVector (rpostprocessing%rvectorStreamfunction)
    IF (rpostprocessing%rvectorH1err%NEQ .NE. 0) &
      CALL lsyssc_releaseVector (rpostprocessing%rvectorH1err)
    IF (rpostprocessing%rvectorH1errCells%NEQ .NE. 0) &
      CALL lsyssc_releaseVector (rpostprocessing%rvectorH1errCells)

  END SUBROUTINE

  !****************************************************************************
  
!<subroutine>

  SUBROUTINE c2d2_donepostprocessing (rpostprocessing)

!<description>
  ! Releases a given problem structure. All allocated memory of this structure
  ! is released.
!</description>

!<inputoutput>  
  TYPE(t_c2d2postprocessing), INTENT(INOUT) :: rpostprocessing
!</inputoutput>

!</subroutine>

    ! Release all vectors -- if there are still some allocated
    CALL c2d2_clearpostprocessing (rpostprocessing)

    ! Release the discretisation structures allocated above.
    CALL spdiscr_releaseDiscr(rpostprocessing%rdiscrQuadratic)
    CALL spdiscr_releaseDiscr(rpostprocessing%rdiscrLinear)
    CALL spdiscr_releaseDiscr(rpostprocessing%rdiscrConstant)
  
  END SUBROUTINE


!  !****************************************************************************
!
!!<subroutine>
!
!  SUBROUTINE ppns2D_fbdforces (rvector,rregion,Dforces,cformulation,CcubU,CcubP)
!
!!<description>
!  ! Calculates the drag-/lift-forces acting on a part of the real
!  ! boundary for a vector rvector with the solution of the 2D
!  ! (Navier-)Stokes equation. It's assumed that
!  !  rvector%rvectorBlock(1) = X-velocity,
!  !  rvector%rvectorBlock(2) = Y-velocity,
!  !  rvector%rvectorBlock(3) = pressure,
!  ! and that X- and Y-velocity is discretised with the same 
!  ! finite element.
!  ! rregion specifies a boundary region where to calculate
!  ! the force integral. Dforces(1:NDIM2D) receives the forces in the
!  ! X- and Y-direction.
!  !
!  ! Double precision version
!!</description>
!
!!<input>
!  ! The FE solution vector.
!  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector
!  
!  ! Boundary region where to calculate the boundary forces.
!  ! Can be created e.g. by boundary_createRegion.
!  TYPE(t_boundaryRegion), INTENT(OUT) :: rregion
!  
!  ! Type identifier that specifies the formulation of the Navier Stokes
!  ! equation that should be used for performing the integration.
!  ! ... = gradient formulation,
!  ! ... = deformation formulation
!  INTEGER, INTENT(IN) :: cformulation
!  
!  ! OPTIONAL: Array with cubature formula identifiers when integrating
!  ! the velocity. If specified, there must be a cubature formula identifier
!  ! for each of the element distributions specified in the discretisation
!  ! structure that is associated to rvector.
!  ! If not specified, the standard cubature formula in the discretisation
!  ! structure for integrating linear forms is used.
!  INTEGER, DIMENSION(:), INTENT(IN) :: CcubU
!
!  ! OPTIONAL: Array with cubature formula identifiers when integrating
!  ! the pressure. If specified, there must be a cubature formula identifier
!  ! for each of the element distributions specified in the discretisation
!  ! structure that is associated to rvector.
!  ! If not specified, the standard cubature formula in the discretisation
!  ! structure for integrating linear forms is used.
!  INTEGER, DIMENSION(:), INTENT(IN) :: CcubP
!!</input>
!
!!<output>
!  ! Array receiving the forces acting on the boundary specified by rregion.
!  ! Note: These are the drag-/lift-FORCES, not the coefficients!!!
!  REAL(DP), DIMENSION(:), INTENT(OUT) :: Dforces
!!</output>
!
!!</subroutine>
!
!  ! Array to tell the element which derivatives to calculate.
!  LOGICAL, DIMENSION(EL_MAXNDER) :: BderU, BderP
!  
!  ! Cubature point coordinates on the reference element.
!  REAL(DP), DIMENSION(CUB_MAXCUBP, NDIM3D) :: DxiU, DxiP
!
!  ! For every cubature point on the reference element,
!  ! the corresponding cubature weight
!  REAL(DP), DIMENSION(CUB_MAXCUBP) :: DomegaU, DomegaP
!  
!  ! number of cubature points on the reference element
!  INTEGER :: ncubpU, ncubpP
!
!  ! Pointer to the vector entries
!  REAL(DP), DIMENSION(:), POINTER :: p_DdataUX, p_DdataUY, p_DdataP
!
!  ! An allocateable array accepting the DOF's of a set of elements.
!  INTEGER(PREC_DOFIDX), DIMENSION(:,:), ALLOCATABLE, TARGET :: IdofsTrialU, IdofsTrialP
!  
!  ! Allocateable arrays for the values of the basis functions.
!  REAL(DP), DIMENSION(:,:,:,:), ALLOCATABLE, TARGET :: DbasTrialU,DbasTrialP
!  
!  ! Number of entries in the vector - for quicker access
!  INTEGER(I32) :: neqU, neqP
!
!  ! Arrays for saving Jacobian determinants and matrices
!  REAL(DP), DIMENSION(:,:), POINTER :: p_Ddetj
!  REAL(DP), DIMENSION(:,:,:), POINTER :: p_Djac
!
!  ! Pointer to KVERT of the triangulation
!  INTEGER(I32), DIMENSION(:,:), POINTER :: p_IverticesAtElement
!  
!  ! Pointer to DCORVG of the triangulation
!  REAL(DP), DIMENSION(:,:), POINTER :: p_DvertexCoords
!  
!  ! Current element distribution
!  TYPE(t_elementDistribution), POINTER :: p_elementDistribution
!
!  ! Number of elements in a block. Normally =BILF_NELEMSIM,
!  ! except if there are less elements in the discretisation.
!  INTEGER :: nelementsPerBlock
!  
!
!  BderU = .FALSE.
!  BderP = .FALSE.
!
!  ! Get the vector data
!  neqU = rvector%RvectorBlock(1)%NEQ
!  neqP = rvector%RvectorBlock(3)%NEQ
!  
!  IF (rvector%cdataType .NE. ST_DOUBLE) THEN
!    PRINT *,'ppns2D_fbdforces: Unsupported vector precision.'
!    STOP
!  END IF
!
!  ! We support only uniform and conformal discretisation structures.
!  IF (.NOT. ASSOCIATED(rvector%p_rblockDiscretisation)) THEN
!    PRINT *,'ppns2D_fbdforces: No discretisation structure!'
!    STOP
!  END IF
!
!  IF ((rvector%p_rblockDiscretisation%ccomplexity .NE. SPDISC_UNIFORM) .AND. &
!      (rvector%p_rblockDiscretisation%ccomplexity .NE. SPDISC_CONFORMAL)) THEN
!    PRINT *,'ppns2D_fbdforces: Discretisation too complex!'
!    STOP
!  END IF
!  
!  ! Get pointers to the subvectors from the block vector
!  CALL lsyssc_getbase_double (rvector%RvectorBlock(1),p_DdataUX)
!  CALL lsyssc_getbase_double (rvector%RvectorBlock(2),p_DdataUY)
!  CALL lsyssc_getbase_double (rvector%RvectorBlock(3),p_DdataP)
!
!  ! Now loop over the different element distributions in the discretisation.
!  ! Each element distribution has a different element combination.
!  ! E.g. distribution 1 may describe P1~/P1~/P0 triangular elements, while
!  ! distrbution 2 may describe Q1~/Q1~/Q0.
!
!  !DO icurrentElementDistr = 1,rdiscretisation%inumFESpaces
!
!
!  !END DO ! icurrentElementDistr
!  
!  Dforces = 0.0_DP
!  
!  END SUBROUTINE
!
!
!  !****************************************************************************
!
!!<subroutine>
!
!  SUBROUTINE ppns2D_bdforces (rvector,rregion,Dforces,cformulation,CcubU,CcubP)
!
!!<description>
!  ! Calculates the drag-/lift-forces acting on a part of the real
!  ! boundary for a vector rvector with the solution of the 2D
!  ! (Navier-)Stokes equation. It's assumed that
!  !  rvector%rvectorBlock(1) = X-velocity,
!  !  rvector%rvectorBlock(2) = Y-velocity,
!  !  rvector%rvectorBlock(3) = pressure,
!  ! and that X- and Y-velocity is discretised with the same 
!  ! finite element.
!  ! rregion specifies a boundary region where to calculate
!  ! the force integral. Dforces(1:NDIM2D) receives the forces in the
!  ! X- and Y-direction.
!  !
!  ! Double precision version
!!</description>
!
!!<input>
!  ! The FE solution vector.
!  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector
!  
!  ! Boundary region where to calculate the boundary forces.
!  ! Can be created e.g. by boundary_createRegion.
!  TYPE(t_boundaryRegion), INTENT(OUT) :: rregion
!  
!  ! Type identifier that specifies the formulation of the Navier Stokes
!  ! equation that should be used for performing the integration.
!  ! ... = gradient formulation,
!  ! ... = deformation formulation
!  INTEGER, INTENT(IN) :: cformulation
!  
!  ! 1D Cubature formula identifier to use for the line integration.
!  ! One of the CUB_xxxx_1D constants in the cubature.f90.
!  INTEGER, DIMENSION(:), INTENT(IN) :: CcubU
!!</input>
!
!!<output>
!  ! Array receiving the forces acting on the boundary specified by rregion.
!  ! Note: These are the drag-/lift-FORCES, not the coefficients!!!
!  REAL(DP), DIMENSION(:), INTENT(OUT) :: Dforces
!!</output>
!
!!</subroutine>
!
!  ! Spatial discretisation structure of velocity and pressure
!  TYPE(t_spatialDiscretisation), POINTER :: p_rdiscrU, p_rdiscrP
!  
!  ! Element distribution of velocity and pressure
!  TYPE(t_elementDistribution), POINTER :: p_elemDistrU,p_elemDistrP
!
!
!  ! Array to tell the element which derivatives to calculate.
!  LOGICAL, DIMENSION(EL_MAXNDER) :: BderU, BderP
!  
!  ! Cubature point coordinates on the reference element.
!  REAL(DP), DIMENSION(CUB_MAXCUBP, NDIM3D) :: Dxi1D, DXi2D
!
!  ! For every cubature point on the reference element,
!  ! the corresponding cubature weight
!  REAL(DP), DIMENSION(CUB_MAXCUBP) :: Domega
!  
!  ! number of cubature points on the reference element
!  INTEGER :: ncubp
!
!  ! Pointer to the vector entries
!  REAL(DP), DIMENSION(:), POINTER :: p_DdataUX, p_DdataUY, p_DdataP
!
!  ! An allocateable array accepting the DOF's of a set of elements.
!  INTEGER(PREC_DOFIDX), DIMENSION(:,:), ALLOCATABLE, TARGET :: IdofsTrialU, IdofsTrialP
!  
!  ! Allocateable arrays for the values of the basis functions.
!  REAL(DP), DIMENSION(:,:,:,:), ALLOCATABLE, TARGET :: DbasTrialU,DbasTrialP
!  
!  ! Number of entries in the vector - for quicker access
!  INTEGER(I32) :: neqU, neqP
!
!  ! Arrays for saving Jacobian determinants and matrices
!  REAL(DP), DIMENSION(:,:), POINTER :: p_Ddetj
!  REAL(DP), DIMENSION(:,:,:), POINTER :: p_Djac
!
!  ! Pointer to KVERT of the triangulation
!  INTEGER(I32), DIMENSION(:,:), POINTER :: p_IverticesAtElement
!  
!  ! Pointer to DCORVG of the triangulation
!  REAL(DP), DIMENSION(:,:), POINTER :: p_DvertexCoords
!  
!
!  ! Number of elements in a block. Normally =BILF_NELEMSIM,
!  ! except if there are less elements in the discretisation.
!  INTEGER :: nelementsPerBlock
!  
!  BderU = .FALSE.
!  BderP = .FALSE.
!
!  ! Get the vector data
!  neqU = rvector%RvectorBlock(1)%NEQ
!  neqP = rvector%RvectorBlock(3)%NEQ
!  
!  IF (rvector%cdataType .NE. ST_DOUBLE) THEN
!    PRINT *,'ppns2D_bdforces: Unsupported vector precision.'
!    STOP
!  END IF
!
!  ! We support only uniform and conformal discretisation structures.
!  IF (.NOT. ASSOCIATED(rvector%p_rblockDiscretisation)) THEN
!    PRINT *,'ppns2D_bdforces: No discretisation structure!'
!    STOP
!  END IF
!
!  IF ((rvector%p_rblockDiscretisation%ccomplexity .NE. SPDISC_UNIFORM) .AND. &
!      (rvector%p_rblockDiscretisation%ccomplexity .NE. SPDISC_CONFORMAL)) THEN
!    PRINT *,'ppns2D_bdforces: Discretisation too complex!'
!    STOP
!  END IF
!  
!  ! Get pointers to the subvectors from the block vector
!  CALL lsyssc_getbase_double (rvector%RvectorBlock(1),p_DdataUX)
!  CALL lsyssc_getbase_double (rvector%RvectorBlock(2),p_DdataUY)
!  CALL lsyssc_getbase_double (rvector%RvectorBlock(3),p_DdataP)
!  
!  ! Get pointers to the spatial discretisation structures of the
!  ! veloctiy and pressure
!  p_rdiscrU => rvector%RvectorBlock(1)%p_spatialDiscretisation
!  p_rdiscrP => rvector%RvectorBlock(3)%p_spatialDiscretisation
!
!  ! Now loop over the different element distributions in the discretisation.
!  ! Each element distribution has a different element combination.
!  ! E.g. distribution 1 may describe P1~/P1~/P0 triangular elements, while
!  ! distrbution 2 may describe Q1~/Q1~/Q0.
!  !
!  ! For every element distribution, we have to loop through all elements
!  ! along the boundary component, calculate their contribution to the
!  ! integral and add everything together.
!
!  DO icurrentElementDistr = 1,rdiscretisation%inumFESpaces
!
!    ! Get the element distribution structure of that FE-space comination
!    p_relemDistrU => p_rdiscrU%RelementDistribution(RelementDistribution)
!    p_relemDistrP => p_rdiscrP%RelementDistribution(RelementDistribution)
!    
!    ! By that we know
!    ! - what's the element
!    ! - which transformation from the reference element to use
!    
!    
!    
!    
!
!  END DO ! icurrentElementDistr
!  
!  END SUBROUTINE

END MODULE
