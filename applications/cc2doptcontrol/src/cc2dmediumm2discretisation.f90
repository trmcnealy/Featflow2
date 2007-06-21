!##############################################################################
!# ****************************************************************************
!# <name> cc2dminim2discretisation </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains the basic spatial discretisation related routines for 
!# CC2D. Here, matrix and RHS creation routines can be found as well as
!# routines to initialise/clean up discretisation structures.
!#
!# The following routines can be found here:
!#
!# 1.) c2d2_initDiscretisation
!#     -> Initialise the discretisation structure inside of the problem
!#        structure using the parameters from the INI/DAT files.
!#
!# 2.) c2d2_allocMatVec
!#     -> Allocates memory for vectors/matrices on all levels.
!#
!# 3.) c2d2_generateStaticMatrices
!#     -> Assembles matrix entries of static matrices (Stokes, B) on one level
!#
!# 4.) c2d2_generateBasicRHS
!#     -> Generates a general RHS vector without any boundary conditions
!#        implemented
!#
!# 5.) c2d2_doneMatVec
!#     -> Cleanup of matrices/vectors, release all memory
!#
!# 6.) c2d2_doneDiscretisation
!#     -> Cleanup of the underlying discretisation structures
!#
!# 7.) c2d2_initInitialSolution
!#     -> Init solution vector according to parameters in the DAT file
!#
!# 8.) c2d2_writeSolution
!#     -> Write solution vector as configured in the DAT file.
!#
!# </purpose>
!##############################################################################

MODULE cc2dmediumm2discretisation

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
  USE stdoperators
  USE vectorio
  
  USE collection
  USE convection
    
  USE cc2dmediumm2basic
  USE cc2dmedium_callback
  USE cc2dmediumm2nonlinearcoreinit
  
  IMPLICIT NONE
  
CONTAINS
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_initDiscretisation (rproblem)
  
!<description>
  ! This routine initialises the discretisation structure of the underlying
  ! problem and saves it to the problem structure.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: I,k,ielementType,icubA,icubB,icubF, icubM
  CHARACTER(LEN=SYS_NAMELEN) :: sstr
  
  ! Number of equations in our problem. 
  ! velocity+velocity+pressure + dual velocity+dual velocity+dual pressure = 6
  INTEGER, PARAMETER :: nequations = 6
  
    ! An object for saving the domain:
    TYPE(t_boundary), POINTER :: p_rboundary
    
    ! An object for saving the triangulation on the domain
    TYPE(t_triangulation), POINTER :: p_rtriangulation
    
    ! An object for the block discretisation on one level
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation
    TYPE(t_spatialDiscretisation), POINTER :: p_rdiscretisationMass
    
    ! Which discretisation is to use?
    ! Which cubature formula should be used?
    CALL parlst_getvalue_int (rproblem%rparamList,'CC-DISCRETISATION',&
                              'iElementType',ielementType,3)

    CALL parlst_getvalue_string (rproblem%rparamList,'CC-DISCRETISATION',&
                                 'scubStokes',sstr,'')
    IF (sstr .EQ. '') THEN
      CALL parlst_getvalue_int (rproblem%rparamList,'CC-DISCRETISATION',&
                                'icubStokes',icubA,CUB_G2X2)
    ELSE
      icubA = cub_igetID(sstr)
    END IF

    CALL parlst_getvalue_string (rproblem%rparamList,'CC-DISCRETISATION',&
                                'scubB',sstr,'')
    IF (sstr .EQ. '') THEN
      CALL parlst_getvalue_int (rproblem%rparamList,'CC-DISCRETISATION',&
                                'icubB',icubB,CUB_G2X2)
    ELSE
      icubB = cub_igetID(sstr)
    END IF

    CALL parlst_getvalue_string (rproblem%rparamList,'CC-DISCRETISATION',&
                                 'scubF',sstr,'')
    IF (sstr .EQ. '') THEN
      CALL parlst_getvalue_int (rproblem%rparamList,'CC-DISCRETISATION',&
                                'icubF',icubF,CUB_G2X2)
    ELSE
      icubF = cub_igetID(sstr)
    END IF

    ! Now set up discrezisation structures on all levels:

    DO i=rproblem%NLMIN,rproblem%NLMAX
      ! Ask the problem structure to give us the boundary and triangulation.
      ! We need it for the discretisation.
      p_rboundary => rproblem%p_rboundary
      p_rtriangulation => rproblem%RlevelInfo(i)%rtriangulation
      
      ! Now we can start to initialise the discretisation. At first, set up
      ! a block discretisation structure that specifies 3 blocks in the
      ! solution vector.
      ALLOCATE(p_rdiscretisation)
      CALL spdiscr_initBlockDiscr2D (p_rdiscretisation,nequations,&
                                     p_rtriangulation, p_rboundary)

      ! Save the discretisation structure to our local LevelInfo structure
      ! for later use.
      rproblem%RlevelInfo(i)%p_rdiscretisation => p_rdiscretisation

      SELECT CASE (ielementType)
      CASE (0)
        ! p_rdiscretisation%Rdiscretisations is a list of scalar 
        ! discretisation structures for every component of the solution vector.
        ! We have a solution vector with three components:
        !  Component 1 = X-velocity
        !  Component 2 = Y-velocity
        !  Component 3 = Pressure
        ! For simplicity, we set up one discretisation structure for the 
        ! velocity...
        CALL spdiscr_initDiscr_simple ( &
                    p_rdiscretisation%RspatialDiscretisation(1), &
                    EL_E031,icubA, &
                    p_rtriangulation, p_rboundary)
                    
        ! Manually set the cubature formula for the RHS as the above routine
        ! uses the same for matrix and vectors.
        p_rdiscretisation%RspatialDiscretisation(1)% &
          RelementDistribution(1)%ccubTypeLinForm = icubF
                    
        ! ...and copy this structure also to the discretisation structure
        ! of the 2nd component (Y-velocity). This needs no additional memory, 
        ! as both structures will share the same dynamic information afterwards,
        ! but we have to be careful when releasing the discretisation structures
        ! at the end of the program!
        p_rdiscretisation%RspatialDiscretisation(2) = &
          p_rdiscretisation%RspatialDiscretisation(1)
    
        ! For the pressure (3rd component), we set up a separate discretisation 
        ! structure, as this uses different finite elements for trial and test
        ! functions.
        CALL spdiscr_initDiscr_combined ( &
                    p_rdiscretisation%RspatialDiscretisation(3), &
                    EL_Q0,EL_E031,icubB, &
                    p_rtriangulation, p_rboundary)

      CASE (1)
        ! p_rdiscretisation%Rdiscretisations is a list of scalar 
        ! discretisation structures for every component of the solution vector.
        ! We have a solution vector with three components:
        !  Component 1 = X-velocity
        !  Component 2 = Y-velocity
        !  Component 3 = Pressure
        ! For simplicity, we set up one discretisation structure for the 
        ! velocity...
        CALL spdiscr_initDiscr_simple ( &
                    p_rdiscretisation%RspatialDiscretisation(1), &
                    EL_E030,icubA, &
                    p_rtriangulation, p_rboundary)
                    
        ! Manually set the cubature formula for the RHS as the above routine
        ! uses the same for matrix and vectors.
        p_rdiscretisation%RspatialDiscretisation(1)% &
          RelementDistribution(1)%ccubTypeLinForm = icubF
                    
        ! ...and copy this structure also to the discretisation structure
        ! of the 2nd component (Y-velocity). This needs no additional memory, 
        ! as both structures will share the same dynamic information afterwards,
        ! but we have to be careful when releasing the discretisation structures
        ! at the end of the program!
        p_rdiscretisation%RspatialDiscretisation(2) = &
          p_rdiscretisation%RspatialDiscretisation(1)
    
        ! For the pressure (3rd component), we set up a separate discretisation 
        ! structure, as this uses different finite elements for trial and test
        ! functions.
        CALL spdiscr_initDiscr_combined ( &
                    p_rdiscretisation%RspatialDiscretisation(3), &
                    EL_Q0,EL_E030,icubB, &
                    p_rtriangulation, p_rboundary)

      CASE (2)
        ! p_rdiscretisation%Rdiscretisations is a list of scalar 
        ! discretisation structures for every component of the solution vector.
        ! We have a solution vector with three components:
        !  Component 1 = X-velocity
        !  Component 2 = Y-velocity
        !  Component 3 = Pressure
        ! For simplicity, we set up one discretisation structure for the 
        ! velocity...
        CALL spdiscr_initDiscr_simple ( &
                    p_rdiscretisation%RspatialDiscretisation(1), &
                    EL_EM31,icubA, &
                    p_rtriangulation, p_rboundary)
                    
        ! Manually set the cubature formula for the RHS as the above routine
        ! uses the same for matrix and vectors.
        p_rdiscretisation%RspatialDiscretisation(1)% &
          RelementDistribution(1)%ccubTypeLinForm = icubF
                    
        ! ...and copy this structure also to the discretisation structure
        ! of the 2nd component (Y-velocity). This needs no additional memory, 
        ! as both structures will share the same dynamic information afterwards,
        ! but we have to be careful when releasing the discretisation structures
        ! at the end of the program!
        p_rdiscretisation%RspatialDiscretisation(2) = &
          p_rdiscretisation%RspatialDiscretisation(1)
    
        ! For the pressure (3rd component), we set up a separate discretisation 
        ! structure, as this uses different finite elements for trial and test
        ! functions.
        CALL spdiscr_initDiscr_combined ( &
                    p_rdiscretisation%RspatialDiscretisation(3), &
                    EL_Q0,EL_EM31,icubB, &
                    p_rtriangulation, p_rboundary)

      CASE (3)
        ! p_rdiscretisation%Rdiscretisations is a list of scalar 
        ! discretisation structures for every component of the solution vector.
        ! We have a solution vector with three components:
        !  Component 1 = X-velocity
        !  Component 2 = Y-velocity
        !  Component 3 = Pressure
        ! For simplicity, we set up one discretisation structure for the 
        ! velocity...
        CALL spdiscr_initDiscr_simple ( &
                    p_rdiscretisation%RspatialDiscretisation(1), &
                    EL_EM30,icubA, &
                    p_rtriangulation, p_rboundary)
                    
        ! Manually set the cubature formula for the RHS as the above routine
        ! uses the same for matrix and vectors.
        p_rdiscretisation%RspatialDiscretisation(1)% &
          RelementDistribution(1)%ccubTypeLinForm = icubF
                    
        ! ...and copy this structure also to the discretisation structure
        ! of the 2nd component (Y-velocity). This needs no additional memory, 
        ! as both structures will share the same dynamic information afterwards,
        ! but we have to be careful when releasing the discretisation structures
        ! at the end of the program!
        p_rdiscretisation%RspatialDiscretisation(2) = &
          p_rdiscretisation%RspatialDiscretisation(1)
    
        ! For the pressure (3rd component), we set up a separate discretisation 
        ! structure, as this uses different finite elements for trial and test
        ! functions.
        CALL spdiscr_initDiscr_combined ( &
                    p_rdiscretisation%RspatialDiscretisation(3), &
                    EL_Q0,EL_EM30,icubB, &
                    p_rtriangulation, p_rboundary)

      CASE (4)
        ! p_rdiscretisation%Rdiscretisations is a list of scalar 
        ! discretisation structures for every component of the solution vector.
        ! We have a solution vector with three components:
        !  Component 1 = X-velocity
        !  Component 2 = Y-velocity
        !  Component 3 = Pressure
        ! For simplicity, we set up one discretisation structure for the 
        ! velocity...
        CALL spdiscr_initDiscr_simple ( &
                    p_rdiscretisation%RspatialDiscretisation(1), &
                    EL_Q2,icubA, &
                    p_rtriangulation, p_rboundary)
                    
        ! Manually set the cubature formula for the RHS as the above routine
        ! uses the same for matrix and vectors.
        p_rdiscretisation%RspatialDiscretisation(1)% &
          RelementDistribution(1)%ccubTypeLinForm = icubF
                    
        ! ...and copy this structure also to the discretisation structure
        ! of the 2nd component (Y-velocity). This needs no additional memory, 
        ! as both structures will share the same dynamic information afterwards,
        ! but we have to be careful when releasing the discretisation structures
        ! at the end of the program!
        p_rdiscretisation%RspatialDiscretisation(2) = &
          p_rdiscretisation%RspatialDiscretisation(1)
    
        ! For the pressure (3rd component), we set up a separate discretisation 
        ! structure, as this uses different finite elements for trial and test
        ! functions.
        CALL spdiscr_initDiscr_combined ( &
                    p_rdiscretisation%RspatialDiscretisation(3), &
                    EL_QP1,EL_Q2,icubB, &
                    p_rtriangulation, p_rboundary)
                    
      CASE (5)
        ! p_rdiscretisation%Rdiscretisations is a list of scalar 
        ! discretisation structures for every component of the solution vector.
        ! We have a solution vector with three components:
        !  Component 1 = X-velocity
        !  Component 2 = Y-velocity
        !  Component 3 = Pressure
        ! For simplicity, we set up one discretisation structure for the 
        ! velocity...
        CALL spdiscr_initDiscr_simple ( &
                    p_rdiscretisation%RspatialDiscretisation(1), &
                    EL_EM30_UNPIVOTED,icubA, &
                    p_rtriangulation, p_rboundary)
                    
        ! Manually set the cubature formula for the RHS as the above routine
        ! uses the same for matrix and vectors.
        p_rdiscretisation%RspatialDiscretisation(1)% &
          RelementDistribution(1)%ccubTypeLinForm = icubF
                    
        ! ...and copy this structure also to the discretisation structure
        ! of the 2nd component (Y-velocity). This needs no additional memory, 
        ! as both structures will share the same dynamic information afterwards,
        ! but we have to be careful when releasing the discretisation structures
        ! at the end of the program!
        p_rdiscretisation%RspatialDiscretisation(2) = &
          p_rdiscretisation%RspatialDiscretisation(1)
    
        ! For the pressure (3rd component), we set up a separate discretisation 
        ! structure, as this uses different finite elements for trial and test
        ! functions.
        CALL spdiscr_initDiscr_combined ( &
                    p_rdiscretisation%RspatialDiscretisation(3), &
                    EL_Q0,EL_EM30_UNPIVOTED,icubB, &
                    p_rtriangulation, p_rboundary)

      CASE (6)
        ! p_rdiscretisation%Rdiscretisations is a list of scalar 
        ! discretisation structures for every component of the solution vector.
        ! We have a solution vector with three components:
        !  Component 1 = X-velocity
        !  Component 2 = Y-velocity
        !  Component 3 = Pressure
        ! For simplicity, we set up one discretisation structure for the 
        ! velocity...
        CALL spdiscr_initDiscr_simple ( &
                    p_rdiscretisation%RspatialDiscretisation(1), &
                    EL_EM30_UNSCALED,icubA, &
                    p_rtriangulation, p_rboundary)
                    
        ! Manually set the cubature formula for the RHS as the above routine
        ! uses the same for matrix and vectors.
        p_rdiscretisation%RspatialDiscretisation(1)% &
          RelementDistribution(1)%ccubTypeLinForm = icubF
                    
        ! ...and copy this structure also to the discretisation structure
        ! of the 2nd component (Y-velocity). This needs no additional memory, 
        ! as both structures will share the same dynamic information afterwards,
        ! but we have to be careful when releasing the discretisation structures
        ! at the end of the program!
        p_rdiscretisation%RspatialDiscretisation(2) = &
          p_rdiscretisation%RspatialDiscretisation(1)
    
        ! For the pressure (3rd component), we set up a separate discretisation 
        ! structure, as this uses different finite elements for trial and test
        ! functions.
        CALL spdiscr_initDiscr_combined ( &
                    p_rdiscretisation%RspatialDiscretisation(3), &
                    EL_Q0,EL_EM30_UNSCALED,icubB, &
                    p_rtriangulation, p_rboundary)

      CASE DEFAULT
        PRINT *,'Unknown discretisation: iElementType = ',ielementType
        STOP
      END SELECT
      
      ! -----------------------------------------------------------------------
      ! Optimal control extension
      ! -----------------------------------------------------------------------
      ! The variables 4,5,6 are discretised like the variables 1,2,3
      ! in the discretisation structure.
      ! Variable 1 = x-velocity  -->  Variable 4 = dual x-velocity
      ! Variable 2 = y-velocity  -->  Variable 5 = dual y-velocity
      ! Variable 3 = pressure    -->  Variable 6 = dual pressure
      ! As we simply copy the structures, we have to be careful when releasing
      ! the structures at the end of the program!
      p_rdiscretisation%RspatialDiscretisation(4) = &
          p_rdiscretisation%RspatialDiscretisation(1)
      p_rdiscretisation%RspatialDiscretisation(5) = &
          p_rdiscretisation%RspatialDiscretisation(2)
      p_rdiscretisation%RspatialDiscretisation(6) = &
          p_rdiscretisation%RspatialDiscretisation(3)

      ! -----------------------------------------------------------------------
      ! Mass matrices
      ! -----------------------------------------------------------------------

      ! Initialise a discretisation structure for the mass matrix.
      ! Copy the discretisation structure of the first (Stokes) block
      ! and replace the cubature-formula identifier by that which is to be
      ! used for the mass matrix.
      ALLOCATE(p_rdiscretisationMass)
      p_rdiscretisationMass = p_rdiscretisation%RspatialDiscretisation(1)
      
      ! Mark the mass matrix discretisation structure as copy of another one -
      ! to prevent accidental deallocation of memory.
      p_rdiscretisationMass%bisCopy = .TRUE.

      CALL parlst_getvalue_string (rproblem%rparamList,'CC-DISCRETISATION',&
                                  'scubStokes',sstr,'')
      IF (sstr .EQ. '') THEN
        CALL parlst_getvalue_int (rproblem%rparamList,'CC-DISCRETISATION',&
                                  'icubStokes',icubM,CUB_G2X2)
      ELSE
        icubM = cub_igetID(sstr)
      END IF

      ! Initialise the cubature formula appropriately.
      DO k = 1,p_rdiscretisationMass%inumFESpaces
        p_rdiscretisationMass%RelementDistribution(k)%ccubTypeBilForm = icubM
      END DO

      rproblem%RlevelInfo(i)%p_rdiscretisationMass => p_rdiscretisationMass
        
    END DO
                                   
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_doneDiscretisation (rproblem)
  
!<description>
  ! Releases the discretisation from the heap.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i
  TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation

    DO i=rproblem%NLMAX,rproblem%NLMIN,-1
      ! Before we remove the block discretisation structure, remember that
      ! we copied the scalar discretisation structure for the X-velocity
      ! to the Y-velocity.
      ! To prevent errors or wrong deallocation, we manually release the
      ! spatial discretisation structures of each of the components.
      p_rdiscretisation => rproblem%RlevelInfo(i)%p_rdiscretisation

      ! Remove spatial discretisation structure of the velocity:
      CALL spdiscr_releaseDiscr(p_rdiscretisation%RspatialDiscretisation(1))
      
      ! Don't remove that of the Y-velocity; there is none :)
      !
      ! Remove the discretisation structure of the pressure.
      CALL spdiscr_releaseDiscr(p_rdiscretisation%RspatialDiscretisation(3))
      
      ! Don't remove the discretisation structures for the dual variables;
      ! they had been the same as for the primal variables and were
      ! released already!
      !
      ! Finally remove the block discretisation structure. Don't release
      ! the substructures again.
      CALL spdiscr_releaseBlockDiscr(p_rdiscretisation,.FALSE.)
      
      ! Remove the discretisation from the heap.
      DEALLOCATE(p_rdiscretisation)

      ! -----------------------------------------------------------------------
      ! Mass matrix problem
      ! -----------------------------------------------------------------------

      ! Release the mass matrix discretisation.
      ! Don't release the content as we created it as a copy of the Stokes
      ! discretisation structure.
      DEALLOCATE(rproblem%RlevelInfo(i)%p_rdiscretisationMass)

    END DO
    
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_allocMatVec (rproblem,rvector,rrhs)
  
!<description>
  ! Allocates memory for all matrices and vectors of the problem on the heap
  ! by evaluating the parameters in the problem structure.
  ! Matrices/vectors of global importance are added to the collection
  ! structure of the problem, given in rproblem. Matrix/vector entries
  ! are not calculated, they are left uninitialised.\\\\
  !
  ! The following matrices/vectors are added to the collection:
  ! Level independent data:\\
  !  'RHS'         - Right hand side vector\\
  !  'SOLUTION'    - Solution vector\\
  !
  ! On every level:\\
  !  'STOKES'    - Stokes matrix\\
  !  'SYSTEMMAT' - Global system (block) matrix\\
  !  'RTEMPVEC'  - Temporary vector
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
  
  ! A vector structure for the solution vector. The structure is initialised,
  ! memory is allocated for the data entries.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector

  ! A vector structure for the RHS vector. The structure is initialised,
  ! memory is allocated for the data entries.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rrhs
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i,cmatBuildType
  
    ! A pointer to the system matrix and the RHS/solution vectors.
    TYPE(t_matrixScalar), POINTER :: p_rmatrixStokes
    TYPE(t_matrixScalar), POINTER :: p_rmatrixTemplateFEM,p_rmatrixTemplateGradient
    TYPE(t_vectorBlock), POINTER :: p_rtempVector

    ! A pointer to the discretisation structure with the data.
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation
  
    ! When the jump stabilisation is used, we have to create an extended
    ! matrix stencil!
    cmatBuildType = BILF_MATC_ELEMENTBASED
    
    CALL parlst_getvalue_int (rproblem%rparamList, 'CC-DISCRETISATION', &
                              'IUPWIND', i)
    IF (i .EQ. 2) cmatBuildType = BILF_MATC_EDGEBASED
  
    ! Initialise all levels...
    DO i=rproblem%NLMIN,rproblem%NLMAX

      ! -----------------------------------------------------------------------
      ! Basic (Navier-) Stokes problem
      ! -----------------------------------------------------------------------

      ! Ask the problem structure to give us the discretisation structure
      p_rdiscretisation => rproblem%RlevelInfo(i)%p_rdiscretisation
      
      ! The global system looks as follows:
      !
      !    ( A11       B1  M/a          )  ( u )  =  ( f1)
      !    (      A22  B2       M/a     )  ( v )     ( f2)
      !    ( B1^T B2^T                  )  ( p )     ( fp)
      !    ( -M            A44  A45  B1 )  ( l1)     ( z1)
      !    (      -M       A54  A55  B2 )  ( l2)     ( z2)
      !    (               B1^T B2^T    )  ( xi)     ( 0 )
      !
      ! with Aii = L + nonlinear Convection, a=alphaC from the given equation.
      ! We compute in advance a standard Stokes matrix L which can be added 
      ! later to the convection matrix, resulting in the nonlinear system matrix.
      !
      ! At first, we create 'template' matrices that define the structure
      ! of each of the submatrices in that global system. These matrices
      ! are later used to 'derive' the actual Laplace/Stokes matrices
      ! by sharing the structure (KCOL/KLD).
      !
      ! Get a pointer to the template FEM matrix. This is used for the
      ! Laplace/Stokes matrix and probably for the mass matrix.
      
      p_rmatrixTemplateFEM => rproblem%RlevelInfo(i)%rmatrixTemplateFEM

      ! Create the matrix structure
      CALL bilf_createMatrixStructure (&
                p_rdiscretisation%RspatialDiscretisation(1),LSYSSC_MATRIX9,&
                p_rmatrixTemplateFEM,cmatBuildType)

      ! In the global system, there are two gradient matrices B1 and B2.
      ! Create a template matrix that defines their structure.
      p_rmatrixTemplateGradient => rproblem%RlevelInfo(i)%rmatrixTemplateGradient
      
      ! Create the matrices structure of the pressure using the 3rd
      ! spatial discretisation structure in p_rdiscretisation%RspatialDiscretisation.
      CALL bilf_createMatrixStructure (&
                p_rdiscretisation%RspatialDiscretisation(3),LSYSSC_MATRIX9,&
                p_rmatrixTemplateGradient)
      
      ! Ok, now we use the matrices from above to create the actual submatrices
      ! that are used in the global system.
      !
      ! Get a pointer to the (scalar) Stokes matrix:
      p_rmatrixStokes => rproblem%RlevelInfo(i)%rmatrixStokes
      
      ! Connect the Stokes matrix to the template FEM matrix such that they
      ! use the same structure.
      !
      ! Don't create a content array yet, it will be created by 
      ! the assembly routines later.
      CALL lsyssc_duplicateMatrix (p_rmatrixTemplateFEM,&
                  p_rmatrixStokes,LSYSSC_DUP_SHARE,LSYSSC_DUP_REMOVE)
      
      ! Allocate memory for the entries; don't initialise the memory.
      CALL lsyssc_allocEmptyMatrix (p_rmatrixStokes,LSYSSC_SETM_UNDEFINED)
      
      ! In the global system, there are two coupling matrices B1 and B2.
      ! Both have the structure of the template gradient matrix.
      ! So connect the two B-matrices to the template gradient matrix
      ! such that they share the same structure.
      ! Create the matrices structure of the pressure using the 3rd
      ! spatial discretisation structure in p_rdiscretisation%RspatialDiscretisation.
      !
      ! Don't create a content array yet, it will be created by 
      ! the assembly routines later.
      
      CALL lsyssc_duplicateMatrix (p_rmatrixTemplateGradient,&
                  rproblem%RlevelInfo(i)%rmatrixB1,LSYSSC_DUP_SHARE,LSYSSC_DUP_REMOVE)
                  
      CALL lsyssc_duplicateMatrix (p_rmatrixTemplateGradient,&
                  rproblem%RlevelInfo(i)%rmatrixB2,LSYSSC_DUP_SHARE,LSYSSC_DUP_REMOVE)
                
      ! Allocate memory for the entries; don't initialise the memory.
      CALL lsyssc_allocEmptyMatrix (rproblem%RlevelInfo(i)%rmatrixB1,&
                                           LSYSSC_SETM_UNDEFINED)
      CALL lsyssc_allocEmptyMatrix (rproblem%RlevelInfo(i)%rmatrixB2,&
                                           LSYSSC_SETM_UNDEFINED)
                                           
      ! -----------------------------------------------------------------------
      ! Allocate memory for an identity matrix in the size of the pressure.
      ! Attach a discretisation structure that describes the pressure element
      ! as trial space.
      CALL lsyssc_createDiagMatrixStruc (rproblem%RlevelInfo(i)%rmatrixIdentityPressure,&
          rproblem%RlevelInfo(i)%rmatrixB1%NCOLS,LSYSSC_MATRIX9)
      rproblem%RlevelInfo(i)%rmatrixIdentityPressure%p_rspatialDiscretisation => &
        p_rdiscretisation%RspatialDiscretisation(3)

      ! -----------------------------------------------------------------------
      ! Now let's come to the main system matrix, which is a block matrix.
      
      ! Allocate memory for that matrix with the appropriate construction routine.
      ! The modules "nonlinearcoreinit" and "nonlinearcore" are actually the
      ! only modules that 'know' the structure of the system matrix!
      CALL c2d2_allocSystemMatrix (rproblem,rproblem%RlevelInfo(i),&
          rproblem%RlevelInfo(i)%rmatrix)
      
      ! -----------------------------------------------------------------------
      ! Temporary vectors
      !
      ! Now on all levels except for the maximum one, create a temporary 
      ! vector on that level, based on the matrix template.
      ! It's used for building the matrices on lower levels.
      IF (i .LT. rproblem%NLMAX) THEN
        p_rtempVector => rproblem%RlevelInfo(i)%rtempVector
        CALL lsysbl_createVecBlockIndMat (rproblem%RlevelInfo(i)%rmatrix,&
            p_rtempVector,.FALSE.)
        
        ! Add the temp vector to the collection on level i
        ! for use in the callback routine
        CALL collct_setvalue_vec(rproblem%rcollection,PAR_TEMPVEC,p_rtempVector,&
                                .TRUE.,i)
      END IF
      
    END DO
    
    ! (Only) on the finest level, we need to allocate a RHS vector
    ! and a solution vector.
    !
    ! Although we could manually create the solution/RHS vector,
    ! the easiest way to set up the vector structure is
    ! to create it by using our matrix as template.
    ! Initialise the vectors with 0.
    CALL lsysbl_createVecBlockIndMat (rproblem%RlevelInfo(rproblem%NLMAX)%rmatrix,&
        rrhs, .TRUE.)
    CALL lsysbl_createVecBlockIndMat (rproblem%RlevelInfo(rproblem%NLMAX)%rmatrix,&
        rvector, .TRUE.)

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_generateStaticMatrices (rproblem,rlevelInfo)
  
!<description>
  ! Calculates entries of all static matrices (Stokes, B-matrices,...)
  ! in the specified problem structure, i.e. the entries of all matrices 
  ! that do not change during the computation or which serve as a template for
  ! generating other matrices.
  !
  ! Memory for those matrices must have been allocated before with 
  ! allocMatVec!
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT) :: rproblem

  ! A level-info structure. The static matrices in this structure are generated.
  TYPE(t_problem_lvl), INTENT(INOUT),TARGET :: rlevelInfo
!</inputoutput>

!</subroutine>

    ! A pointer to the Stokes and mass matrix
    TYPE(t_matrixScalar), POINTER :: p_rmatrixStokes,p_rmatrixMass

    ! A pointer to the discretisation structure with the data.
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation
    
    ! Initialise the collection for the assembly process with callback routines.
    ! Basically, this stores the simulation time in the collection if the
    ! simulation is nonstationary.
    CALL c2d2_initCollectForAssembly (rproblem,rproblem%rcollection)

    ! -----------------------------------------------------------------------
    ! Basic (Navier-) Stokes problem
    ! -----------------------------------------------------------------------
  
    ! Ask the problem structure to give us the discretisation structure
    p_rdiscretisation => rlevelInfo%p_rdiscretisation
    
    ! Get a pointer to the (scalar) Stokes matrix:
    p_rmatrixStokes => rlevelInfo%rmatrixStokes
    
    CALL stdop_assembleLaplaceMatrix (p_rmatrixStokes,.TRUE.,rproblem%dnu)
    
    ! In the global system, there are two coupling matrices B1 and B2.
    !
    ! Build the first pressure matrix B1.
    CALL stdop_assembleSimpleMatrix (rlevelInfo%rmatrixB1,&
        DER_FUNC,DER_DERIV_X,-1.0_DP)

    ! Build the second pressure matrix B2.
    CALL stdop_assembleSimpleMatrix (rlevelInfo%rmatrixB2,&
        DER_FUNC,DER_DERIV_Y,-1.0_DP)
                                
    ! -----------------------------------------------------------------------
    ! Mass matrices
    ! -----------------------------------------------------------------------

    p_rmatrixMass => rlevelInfo%rmatrixMass

    ! If there is an existing mass matrix, release it.
    CALL lsyssc_releaseMatrix (rlevelInfo%rmatrixMass)

    ! Generate mass matrix. The matrix has basically the same structure as
    ! our template FEM matrix, so we can take that.
    CALL lsyssc_duplicateMatrix (rlevelInfo%rmatrixTemplateFEM,&
                p_rmatrixMass,LSYSSC_DUP_SHARE,LSYSSC_DUP_REMOVE)
                
    ! Change the discretisation structure of the mass matrix to the
    ! correct one; at the moment it points to the discretisation structure
    ! of the Stokes matrix...
    p_rmatrixMass%p_rspatialDiscretisation => &
      rlevelInfo%p_rdiscretisationMass

    ! Call the standard matrix setup routine to build the matrix.                    
    CALL stdop_assembleSimpleMatrix (p_rmatrixMass,DER_FUNC,DER_FUNC)

    ! Clean up the collection (as we are done with the assembly, that's it.
    CALL c2d2_doneCollectForAssembly (rproblem,rproblem%rcollection)

    ! -----------------------------------------------------------------------
    ! Initialise the identity matrix
    CALL lsyssc_initialiseIdentityMatrix (rlevelInfo%rmatrixIdentityPressure)

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_generateBasicRHS (rproblem,rrhs)
  
!<description>
  ! Calculates the entries of the basic right-hand-side vector on the finest
  ! level. Boundary conditions or similar things are not implemented into 
  ! the vector.
  ! Memory for the RHS vector must have been allocated in advance.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
  
  ! The RHS vector which is to be filled with data.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rrhs
!</inputoutput>

!</subroutine>

  ! local variables
  
    ! A bilinear and linear form describing the analytic problem to solve
    TYPE(t_linearForm) :: rlinform
    
    ! A pointer to the discretisation structure with the data.
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation
    
    ! DEBUG!!!
    REAL(DP), DIMENSION(:), POINTER :: p_Drhs
    
    ! DEBUG!!!
    CALL lsysbl_getbase_double (rrhs,p_Drhs)

    ! Get a pointer to the RHS on the finest level as well as to the
    ! block discretisation structure:
    p_rdiscretisation => rrhs%p_rblockDiscretisation
    
    ! The vector structure is already prepared, but the entries are missing.
    !
    ! At first set up the corresponding linear form (f,Phi_j):
    rlinform%itermCount = 1
    rlinform%Idescriptors(1) = DER_FUNC
    
    ! ... and then discretise the RHS to the first subvector of
    ! the block vector using the discretisation structure of the 
    ! first block.
    !
    ! We pass our collection structure as well to this routine, 
    ! so the callback routine has access to everything what is
    ! in the collection.
    !
    ! Note that the vector is unsorted after calling this routine!
    !
    ! Initialise the collection for the assembly process with callback routines.
    ! Basically, this stores the simulation time in the collection if the
    ! simulation is nonstationary.
    CALL c2d2_initCollectForAssembly (rproblem,rproblem%rcollection)

    ! Discretise the X-velocity part:
    CALL linf_buildVectorScalar (&
              p_rdiscretisation%RspatialDiscretisation(1),rlinform,.TRUE.,&
              rrhs%RvectorBlock(1),coeff_RHS_x,&
              rproblem%rcollection)

    ! And the Y-velocity part:
    CALL linf_buildVectorScalar (&
              p_rdiscretisation%RspatialDiscretisation(2),rlinform,.TRUE.,&
              rrhs%RvectorBlock(2),coeff_RHS_y,&
              rproblem%rcollection)
                                
    ! The third subvector must be zero initially - as it represents the RHS of
    ! the equation "div(u) = 0".
    CALL lsyssc_clearVector(rrhs%RvectorBlock(3))
    
    ! The RHS terms for the dual equation are calculated similarly using
    ! the desired 'target' flow field.
    !
    ! Discretise the X-velocity part:
    CALL linf_buildVectorScalar (&
              p_rdiscretisation%RspatialDiscretisation(1),rlinform,.TRUE.,&
              rrhs%RvectorBlock(4),coeff_TARGET_x,&
              rproblem%rcollection)

    ! And the Y-velocity part:
    CALL linf_buildVectorScalar (&
              p_rdiscretisation%RspatialDiscretisation(2),rlinform,.TRUE.,&
              rrhs%RvectorBlock(5),coeff_TARGET_y,&
              rproblem%rcollection)
              
    ! Switch the sign of the target velocity field because the RHS of the
    ! dual equation is '-z'!
    CALL lsyssc_scaleVector (rrhs%RvectorBlock(4),-1.0_DP)
    CALL lsyssc_scaleVector (rrhs%RvectorBlock(5),-1.0_DP)

    ! Dual pressure RHS is =0.
    CALL lsyssc_clearVector(rrhs%RvectorBlock(6))
                                
    ! Clean up the collection (as we are done with the assembly, that's it.
    CALL c2d2_doneCollectForAssembly (rproblem,rproblem%rcollection)

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_initInitialSolution (rproblem,rvector)
  
!<description>
  ! Initialises the initial solution vector into rvector. Depending on the settings
  ! in the DAT file this is either zero or read from a file.
!</description>

!<input>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(IN) :: rproblem
!</input>

!<inputoutput>
  ! The solution vector to be initialised. Must be set up according to the
  ! maximum level NLMAX in rproblem!
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER(I32) :: istart
    TYPE(t_vectorBlock) :: rvector1,rvector2
    TYPE(t_vectorScalar) :: rvectorTemp
    CHARACTER(LEN=SYS_STRLEN) :: sarray,sfile,sfileString
    INTEGER :: ilev
    INTEGER(PREC_VECIDX) :: NEQ
    TYPE(t_interlevelProjectionBlock) :: rprojection 

    ! Get the parameter what to do with rvector
    CALL parlst_getvalue_int (rproblem%rparamList,'CC-DISCRETISATION',&
                              'isolutionStart',istart,0)
    CALL parlst_getvalue_string (rproblem%rparamList,'CC-DISCRETISATION',&
                                 'ssolutionStart',sfileString,'')

    ! Create a temp vector at level NLMAX-istart+1.
    ilev = rproblem%NLMAX-ABS(istart)+1
    
    IF (ilev .LT. rproblem%NLMIN) THEN
      PRINT *,'Warning: Level of start vector is < NLMIN! Initialising with zero!'
      istart = 0
    END IF
    
    ! In�t with zero? Read from file?
    IF (istart .EQ. 0) THEN
      ! Init with zero
      CALL lsysbl_clearVector (rvector)
    ELSE
      ! Remove possible ''-characters
      READ(sfileString,*) sfile

      CALL lsysbl_createVectorBlock (&
          rproblem%RlevelInfo(ilev)%p_rdiscretisation,rvector1,.FALSE.)
      
      ! Read in the vector
      CALL vecio_readBlockVectorHR (&
          rvector1, sarray, .TRUE., 0, sfile, istart .GT. 0)
          
      ! If the vector is on level < NLMAX, we have to bring it to level NLMAX
      DO WHILE (ilev .LT. rproblem%NLMAX)
        
        ! Initialise a vector for the higher level and a prolongation structure.
        CALL lsysbl_createVectorBlock (&
            rproblem%RlevelInfo(ilev+1)%p_rdiscretisation,rvector2,.FALSE.)
        
        CALL mlprj_initProjectionVec (rprojection,rvector2)
        
        ! Prolongate to the next higher level.

        NEQ = mlprj_getTempMemoryVec (rprojection,rvector1,rvector2)
        IF (NEQ .NE. 0) CALL lsyssc_createVector (rvectorTemp,NEQ,.FALSE.)
        CALL mlprj_performProlongation (rprojection,rvector1, &
                                        rvector2,rvectorTemp)
        IF (NEQ .NE. 0) CALL lsyssc_releaseVector (rvectorTemp)
        
        ! Swap rvector1 and rvector2. Release the coarse grid vector.
        CALL lsysbl_swapVectors (rvector1,rvector2)
        CALL lsysbl_releaseVector (rvector2)
        
        CALL mlprj_doneProjection (rprojection)
        
        ! rvector1 is now on level ilev+1
        ilev = ilev+1
        
      END DO
      
      ! Copy the resulting vector rvector1 to the output.
      CALL lsysbl_copyVector (rvector1,rvector)
      
      ! Release the temp vector
      CALL lsysbl_releaseVector (rvector1)
      
    END IF

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_writeSolution (rproblem,rvector)
  
!<description>
  ! Writes a solution vector rvector to a file as configured in the parameters
  ! in the DAT file.
!</description>

!<input>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(IN) :: rproblem

  ! The solution vector to be written out. Must be set up according to the
  ! maximum level NLMAX in rproblem!
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
!</input>

!</subroutine>

    ! local variables
    INTEGER(I32) :: idestLevel
    TYPE(t_vectorBlock) :: rvector1,rvector2
    TYPE(t_vectorScalar) :: rvectorTemp
    CHARACTER(LEN=SYS_STRLEN) :: sfile,sfileString
    INTEGER :: ilev
    INTEGER(PREC_VECIDX) :: NEQ
    TYPE(t_interlevelProjectionBlock) :: rprojection 
    LOGICAL :: bformatted

    ! Get the parameter what to do with rvector
    CALL parlst_getvalue_int (rproblem%rparamList,'CC-DISCRETISATION',&
                              'iSolutionWrite',idestLevel,0)
    CALL parlst_getvalue_string (rproblem%rparamList,'CC-DISCRETISATION',&
                                 'sSolutionWrite',sfileString,'')

    IF (idestLevel .EQ. 0) RETURN ! nothing to do.
    
    ! Remove possible ''-characters
    READ(sfileString,*) sfile
    
    bformatted = idestLevel .GT. 0
    idestLevel = rproblem%NLMAX-ABS(idestLevel)+1 ! level where to write out

    IF (idestLevel .LT. rproblem%NLMIN) THEN
      PRINT *,'Warning: Level for solution vector is < NLMIN! &
              &Writing out at level NLMIN!'
      idestLevel = rproblem%NLMIN
    END IF
    
    ! Interpolate the solution down to level istart.
    CALL lsysbl_copyVector (rvector,rvector1)   ! creates new rvector1!

    DO ilev = rproblem%NLMAX,idestLevel+1,-1
      
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

    ! Write out the solution.
    IF (bformatted) THEN
      CALL vecio_writeBlockVectorHR (rvector1, 'SOLUTION', .TRUE.,&
                                    0, sfile, '(E22.15)')
    ELSE
      CALL vecio_writeBlockVectorHR (rvector1, 'SOLUTION', .TRUE.,0, sfile)
    END IF

    ! Release temp memory.
    CALL lsysbl_releaseVector (rvector1)

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c2d2_doneMatVec (rproblem,rvector,rrhs)
  
!<description>
  ! Releases system matrix and vectors.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem

  ! A vector structure for the solution vector. The structure is cleaned up,
  ! memory is released.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector

  ! A vector structure for the RHS vector. The structure is cleaned up,
  ! memory is released.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rrhs
!</inputoutput>

!</subroutine>

    INTEGER :: i

    ! Release matrices and vectors on all levels
    DO i=rproblem%NLMAX,rproblem%NLMIN,-1
      ! Delete the system matrix.
      CALL lsysbl_releaseMatrix (rproblem%RlevelInfo(i)%rmatrix)

      ! If there is an existing mass matrix, release it.
      CALL lsyssc_releaseMatrix (rproblem%RlevelInfo(i)%rmatrixMass)

      ! Release Stokes, B1 and B2 matrix
      CALL lsyssc_releaseMatrix (rproblem%RlevelInfo(i)%rmatrixB2)
      CALL lsyssc_releaseMatrix (rproblem%RlevelInfo(i)%rmatrixB1)
      CALL lsyssc_releaseMatrix (rproblem%RlevelInfo(i)%rmatrixStokes)
      
      CALL lsyssc_releaseMatrix (rproblem%RlevelInfo(i)%rmatrixIdentityPressure)
      
      ! Release the template matrices. This is the point, where the
      ! memory of the matrix structure is released.
      CALL lsyssc_releaseMatrix (rproblem%RlevelInfo(i)%rmatrixTemplateGradient)
      CALL lsyssc_releaseMatrix (rproblem%RlevelInfo(i)%rmatrixTemplateFEM)
      
      ! Remove the temp vector that was used for interpolating the solution
      ! from higher to lower levels in the nonlinear iteration.
      IF (i .LT. rproblem%NLMAX) THEN
        CALL lsysbl_releaseVector(rproblem%RlevelInfo(i)%rtempVector)
        CALL collct_deletevalue(rproblem%rcollection,PAR_TEMPVEC,i)
      END IF
      
    END DO

    ! Delete solution/RHS vector
    CALL lsysbl_releaseVector (rvector)
    CALL lsysbl_releaseVector (rrhs)

  END SUBROUTINE

END MODULE
