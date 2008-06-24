!##############################################################################
!# ****************************************************************************
!# <name> cc3dmini_method1 </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module is a demonstation program how to solve a stationary
!# Navier-Stokes problem 
!#
!#              $$- \nu Laplace(u) + u*grad(u) + \Nabla p = f $$
!#              $$ \Nable \cdot p = 0$$
!#
!# on a 3D domain for a 3D function $u=(u_1,u_2,u_3)$ and a pressure $p$.
!#
!# The routine splits up the tasks of reading the domain, creating 
!# triangulations, discretisation, solving, postprocessing and creanup into
!# different subroutines. The communication between these subroutines
!# is done using an application-specific structure saving problem data
!# as well as a collection structure for the communication with callback
!# routines.
!#
!# For the nonlinearity, the nonlinear solver is invoked. The
!# defect that is setted up there is preconditioned by a linear Multigrid
!# solver with a simple-VANCA smoother/preconditioner for
!# 3D saddle point problems, Jacobi-Type. As coarse grid solver,
!# UMFPACK is used.
!# </purpose>
!##############################################################################

MODULE cc3dmini_method1

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
  USE ucd
  USE meshregion
  
  USE collection
  USE convection
    
  USE cc3dmini_callback
  USE cc3dmini_aux
  
  IMPLICIT NONE
  
!<types>

!<typeblock description="Type block defining all information about one level">

  TYPE t_problem_lvl
  
    ! An object for saving the triangulation on the domain
    TYPE(t_triangulation) :: rtriangulation

    ! An object specifying the block discretisation
    ! (size of subvectors in the solution vector, trial/test functions,...)
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation
    
    ! A system matrix for that specific level. 
    TYPE(t_matrixBlock) :: rmatrix

    ! Laplace matrix for that specific level. 
    TYPE(t_matrixScalar) :: rmatrixLaplace

    ! B1-matrix for that specific level. 
    TYPE(t_matrixScalar) :: rmatrixB1

    ! B2-matrix for that specific level. 
    TYPE(t_matrixScalar) :: rmatrixB2

    ! B3-matrix for that specific level. 
    TYPE(t_matrixScalar) :: rmatrixB3

    ! A temporary vector for building the solution when assembling the
    ! matrix on lower levels.
    TYPE(t_vectorBlock) :: rtempVector

    ! A variable describing the discrete boundary conditions fo the velocity
    TYPE(t_discreteBC) :: rdiscreteBC
  
  END TYPE
  
!</typeblock>


!<typeblock description="Application-specific type block for Nav.St. problem">

  TYPE t_problem
  
    ! Minimum refinement level; = Level i in p_RlevelInfo
    INTEGER :: NLMIN
    
    ! Maximum refinement level
    INTEGER :: NLMAX
    
    ! Viscosity parameter nu = 1/Re
    REAL(DP) :: dnu

    ! A solution vector and a RHS vector on the finest level. 
    TYPE(t_vectorBlock) :: rvector,rrhs

    ! A solver node that accepts parameters for the linear solver    
    TYPE(t_linsolNode), POINTER :: p_rsolverNode

    ! An array of t_problem_lvl structures, each corresponding
    ! to one level of the discretisation.
    TYPE(t_problem_lvl), DIMENSION(:), POINTER :: p_RlevelInfo
    
    ! A collection object that saves structural data and some 
    ! problem-dependent information which is e.g. passed to 
    ! callback routines.
    TYPE(t_collection) :: rcollection

  END TYPE

!</typeblock>

!</types>
  
CONTAINS

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_initParamTriang (ilvmin,ilvmax,rproblem)
  
!<description>
  ! This routine initialises the parametrisation and triangulation of the
  ! domain. The corresponding .prm/.tri files are read from disc and
  ! the triangulation is refined as described by the parameter ilv.
!</description>

!<input>
  ! Minimum refinement level of the mesh; = coarse grid = level 1
  INTEGER, INTENT(IN) :: ilvmin
  
  ! Maximum refinement level
  INTEGER, INTENT(IN) :: ilvmax
!</input>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT) :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i
  
    ! Variable for a filename:  
    CHARACTER(LEN=SYS_STRLEN) :: sString

    ! Initialise the level in the problem structure
    rproblem%NLMIN = ilvmin
    rproblem%NLMAX = ilvmax

    CALL collct_setvalue_int(rproblem%rcollection,'NLMIN',ilvmin,.TRUE.)
    CALL collct_setvalue_int(rproblem%rcollection,'NLMAX',ilvmax,.TRUE.)

    ! At first, read in the basic triangulation.
    CALL tria_readTriFile3D (rproblem%p_RlevelInfo(rproblem%NLMIN)%rtriangulation, &
                                                 './pre/CUBE.tri')

    ! Refine the mesh up to the minimum level
    CALL tria_quickRefine2LevelOrdering(rproblem%NLMIN-1,&
        rproblem%p_RlevelInfo(rproblem%NLMIN)%rtriangulation)

    ! Create information about adjacencies and everything one needs from
    ! a triangulation. Afterwards, we have the coarse mesh.
    CALL tria_initStandardMeshFromRaw (&
        rproblem%p_RlevelInfo(rproblem%NLMIN)%rtriangulation)
    
    ! Now, refine to level up to nlmax.
    DO i=rproblem%NLMIN+1,rproblem%NLMAX
      CALL tria_refine2LevelOrdering (rproblem%p_RlevelInfo(i-1)%rtriangulation,&
          rproblem%p_RlevelInfo(i)%rtriangulation)
      CALL tria_initStandardMeshFromRaw (rproblem%p_RlevelInfo(i)%rtriangulation)
    END DO

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_initDiscretisation (rproblem)
  
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
  INTEGER :: i
  
    ! An object for saving the triangulation on the domain
    TYPE(t_triangulation), POINTER :: p_rtriangulation
    
    ! An object for the block discretisation on one level
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation

    DO i = rproblem%NLMIN, rproblem%NLMAX
      ! Ask the problem structure to give us the boundary and triangulation.
      ! We need it for the discretisation.
      !p_rboundary => rproblem%rboundary
      p_rtriangulation => rproblem%p_RlevelInfo(i)%rtriangulation
      
      ! Now we can start to initialise the discretisation. At first, set up
      ! a block discretisation structure that specifies 3 blocks in the
      ! solution vector. In this simple problem, we only have one block.
      ALLOCATE(p_rdiscretisation)
      CALL spdiscr_initBlockDiscr(p_rdiscretisation,4,p_rtriangulation)

      ! Save the discretisation structure to our local LevelInfo structure
      ! for later use.
      rproblem%p_RlevelInfo(i)%p_rdiscretisation => p_rdiscretisation

      ! p_rdiscretisation%Rdiscretisations is a list of scalar 
      ! discretisation structures for every component of the solution vector.
      ! We have a solution vector with three components:
      !  Component 1 = X-velocity
      !  Component 2 = Y-velocity
      !  Component 3 = Z-velocity
      !  Component 4 = Pressure
      ! For simplicity, we set up one discretisation structure for the 
      ! velocity...
      CALL spdiscr_initDiscr_simple ( &
                  p_rdiscretisation%RspatialDiscretisation(1), &
                  EL_EM30_3D,CUB_G2_3D,p_rtriangulation)
                  
      ! ...and copy this structure also to the discretisation structure
      ! of the 2nd component (Y-velocity). This needs no additional memory, 
      ! as both structures will share the same dynamic information afterwards.
      CALL spdiscr_duplicateDiscrSc(p_rdiscretisation%RspatialDiscretisation(1),&
          p_rdiscretisation%RspatialDiscretisation(2))
  
      ! ...and copy this structure also to the discretisation structure
      ! of the 3rd component (Z-velocity). This needs no additional memory, 
      ! as both structures will share the same dynamic information afterwards.
      CALL spdiscr_duplicateDiscrSc(p_rdiscretisation%RspatialDiscretisation(1),&
          p_rdiscretisation%RspatialDiscretisation(3))

      ! For the pressure (4th component), we set up a separate discretisation 
      ! structure, as this uses different finite elements for trial and test
      ! functions.
      CALL spdiscr_initDiscr_combined ( &
                  p_rdiscretisation%RspatialDiscretisation(4), &
                  EL_Q0_3D,EL_EM30_3D,CUB_G2_3D,p_rtriangulation)
    END DO
                                   
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_initMatVec (rproblem)
  
!<description>
  ! Calculates the system matrix and RHS vector of the linear system
  ! by discretising the problem with the default discretisation structure
  ! in the problem structure.
  ! Sets up a solution vector for the linear system.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i
  
    ! A bilinear and linear form describing the analytic problem to solve
    TYPE(t_bilinearForm) :: rform
    TYPE(t_linearForm) :: rlinform
    
    ! A pointer to the system matrix and the RHS/solution vectors.
    TYPE(t_matrixBlock), POINTER :: p_rmatrix
    TYPE(t_matrixScalar), POINTER :: p_rmatrixLaplace
    TYPE(t_vectorBlock), POINTER :: p_rrhs,p_rvector,p_rtempVector

    ! A pointer to the discretisation structure with the data.
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation
  
    DO i=rproblem%NLMIN,rproblem%NLMAX
      ! Ask the problem structure to give us the discretisation structure
      p_rdiscretisation => rproblem%p_RlevelInfo(i)%p_rdiscretisation
      
      ! The global system looks as follows:
      !
      !    / A              B1 \
      !    |      A         B2 |
      !    |           A    B3 |
      !    \ B1^T B2^T B3^T    /
      !
      ! with A = L + nonlinear Convection. We compute in advance
      ! a standard Laplace matrix L which can be added later to the
      ! convection matrix, resulting in the nonlinear system matrix.
      !
      ! Get a pointer to the (scalar) Laplace matrix:
      p_rmatrixLaplace => rproblem%p_RlevelInfo(i)%rmatrixLaplace
      
      ! and save it to the collection for later use.
      CALL collct_setvalue_matsca(rproblem%rcollection,'LAPLACE',&
                                  p_rmatrixLaplace,.TRUE.,i)
      
      ! Create the matrix structure of the Laplace matrix:
      CALL bilf_createMatrixStructure (&
                p_rdiscretisation%RspatialDiscretisation(1),LSYSSC_MATRIX9,&
                p_rmatrixLaplace)
      
      ! And now to the entries of the matrix. For assembling of the entries,
      ! we need a bilinear form, which first has to be set up manually.
      ! We specify the bilinear form (grad Psi_j, grad Phi_i) for the
      ! scalar system matrix in 3D.
      rform%itermCount = 3
      rform%Idescriptors(1,1) = DER_DERIV3D_X
      rform%Idescriptors(2,1) = DER_DERIV3D_X
      rform%Idescriptors(1,2) = DER_DERIV3D_Y
      rform%Idescriptors(2,2) = DER_DERIV3D_Y
      rform%Idescriptors(1,3) = DER_DERIV3D_Z
      rform%Idescriptors(2,3) = DER_DERIV3D_Z

      ! In the standard case, we have constant coefficients:
      rform%ballCoeffConstant = .TRUE.
      rform%BconstantCoeff = .TRUE.
      rform%Dcoefficients(1)  = rproblem%dnu
      rform%Dcoefficients(2)  = rproblem%dnu
      rform%Dcoefficients(3)  = rproblem%dnu

      ! Now we can build the matrix entries.
      ! We specify the callback function coeff_Stokes for the coefficients.
      ! As long as we use constant coefficients, this routine is not used.
      ! By specifying ballCoeffConstant = BconstantCoeff = .FALSE. above,
      ! the framework will call the callback routine to get analytical data.
      !
      ! We pass our collection structure as well to this routine, 
      ! so the callback routine has access to everything what is
      ! in the collection.
      CALL bilf_buildMatrixScalar (rform,.TRUE.,&
                                   p_rmatrixLaplace,coeff_Stokes,&
                                   rproblem%rcollection)
      
      ! In the global system, there are two coupling matrices B1 and B2.
      ! Both have the same structure.
      ! Create the matrices structure of the pressure using the 3rd
      ! spatial discretisation structure in p_rdiscretisation%RspatialDiscretisation.
      CALL bilf_createMatrixStructure (&
                p_rdiscretisation%RspatialDiscretisation(4),LSYSSC_MATRIX9,&
                rproblem%p_RlevelInfo(i)%rmatrixB1)
                
      ! Duplicate the B1 matrix structure to the B2 matrix, so use
      ! lsyssc_duplicateMatrix to create B2. Share the matrix 
      ! structure between B1 and B2 (B1 is the parent and B2 the child). 
      ! Don't create a content array yet, it will be created by 
      ! the assembly routines later.
      CALL lsyssc_duplicateMatrix (rproblem%p_RlevelInfo(i)%rmatrixB1,&
                  rproblem%p_RlevelInfo(i)%rmatrixB2,LSYSSC_DUP_COPY,LSYSSC_DUP_REMOVE)
      CALL lsyssc_duplicateMatrix (rproblem%p_RlevelInfo(i)%rmatrixB1,&
                  rproblem%p_RlevelInfo(i)%rmatrixB3,LSYSSC_DUP_COPY,LSYSSC_DUP_REMOVE)

      ! Build the first pressure matrix B1.
      ! Again first set up the bilinear form, then call the matrix assembly.
      rform%itermCount = 1
      rform%Idescriptors(1,1) = DER_FUNC3D
      rform%Idescriptors(2,1) = DER_DERIV3D_X

      ! In the standard case, we have constant coefficients:
      rform%ballCoeffConstant = .TRUE.
      rform%BconstantCoeff = .TRUE.
      rform%Dcoefficients(1)  = -1.0_DP
      
      CALL bilf_buildMatrixScalar (rform,.TRUE.,&
                                  rproblem%p_RlevelInfo(i)%rmatrixB1,coeff_Pressure,&
                                  rproblem%rcollection)

      ! Build the second pressure matrix B2.
      ! Again first set up the bilinear form, then call the matrix assembly.
      rform%itermCount = 1
      rform%Idescriptors(1,1) = DER_FUNC3D
      rform%Idescriptors(2,1) = DER_DERIV3D_Y

      ! In the standard case, we have constant coefficients:
      rform%ballCoeffConstant = .TRUE.
      rform%BconstantCoeff = .TRUE.
      rform%Dcoefficients(1)  = -1.0_DP
      
      CALL bilf_buildMatrixScalar (rform,.TRUE.,&
                                  rproblem%p_RlevelInfo(i)%rmatrixB2,coeff_Pressure,&
                                  rproblem%rcollection)
                                  
      ! Build the second pressure matrix B3.
      ! Again first set up the bilinear form, then call the matrix assembly.
      rform%itermCount = 1
      rform%Idescriptors(1,1) = DER_FUNC3D
      rform%Idescriptors(2,1) = DER_DERIV3D_Z

      ! In the standard case, we have constant coefficients:
      rform%ballCoeffConstant = .TRUE.
      rform%BconstantCoeff = .TRUE.
      rform%Dcoefficients(1)  = -1.0_DP
      
      CALL bilf_buildMatrixScalar (rform,.TRUE.,&
                                  rproblem%p_RlevelInfo(i)%rmatrixB3,coeff_Pressure,&
                                  rproblem%rcollection)

      ! Now let's come to the main system matrix, which is a block matrix.
      p_rmatrix => rproblem%p_RlevelInfo(i)%rmatrix
      
      ! Initialise the block matrix with default values based on
      ! the discretisation.
      CALL lsysbl_createMatBlockByDiscr (p_rdiscretisation,p_rmatrix)    
      
      ! Save the system matrix to the collection.
      ! They maybe used later, expecially in nonlinear problems.
      CALL collct_setvalue_mat(rproblem%rcollection,'SYSTEMMAT',p_rmatrix,.TRUE.,i)

      ! Inform the matrix that we build a saddle-point problem.
      ! Normally, imatrixSpec has the value LSYSBS_MSPEC_GENERAL,
      ! but probably some solvers can use the special structure later.
      p_rmatrix%imatrixSpec = LSYSBS_MSPEC_SADDLEPOINT
      
      ! Let's consider the global system in detail:
      !
      !    / A              B1 \ = / A11  A12  A13  A14 \
      !    |      A         B2 |   | A21  A22  A23  A24 |
      !    |           A    B3 |   | A31  A32  A33  A34 |
      !    \ B1^T B2^T B3^T    /   ( A41  A42  A43  A44 /
      !
      ! The matrices A11, A22 and A33 of the global system matrix have exactly
      ! the same structure as the original Laplace matrix from above!
      ! Initialise them with the same structure, i.e. A11, A22, A33 and the
      ! Laplace matrix L share(!) the same structure.
      !
      ! For this purpose, use the "duplicate matric" routine.
      ! The structure of the matrix is shared with the Laplace matrix.
      ! For the content, a new empty array is allocated which will later receive
      ! the entries.
      CALL lsyssc_duplicateMatrix (p_rmatrixLaplace,&
                  p_rmatrix%RmatrixBlock(1,1),LSYSSC_DUP_SHARE,LSYSSC_DUP_EMPTY)
                  
      ! The matrix A22 is identical to A11! So mirror A11 to A22 sharing the
      ! structure and the content.
      CALL lsyssc_duplicateMatrix (p_rmatrix%RmatrixBlock(1,1),&
                  p_rmatrix%RmatrixBlock(2,2),LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)

      ! The matrix A33 is identical to A11! So mirror A11 to A33 sharing the
      ! structure and the content.
      CALL lsyssc_duplicateMatrix (p_rmatrix%RmatrixBlock(1,1),&
                  p_rmatrix%RmatrixBlock(3,3),LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)

      ! Manually change the discretisation structure of the Y-velocity 
      ! matrix to the Y-discretisation structure.
      ! Ok, we use the same discretisation structure for both, X- and Y-velocity,
      ! so this is not really necessary - we do this for sure...
      p_rmatrix%RmatrixBlock(2,2)%p_rspatialDiscretisation => &
        p_rdiscretisation%RspatialDiscretisation(2)
      p_rmatrix%RmatrixBlock(3,3)%p_rspatialDiscretisation => &
        p_rdiscretisation%RspatialDiscretisation(3)
                                  
      ! The B1/B2 matrices exist up to now only in our local problem structure.
      ! Put a copy of them into the block matrix.
      !
      ! Note that we share the structure of B1/B2 with those B1/B2 of the
      ! block matrix, while we create copies of the entries. The reason is
      ! that these matrices are modified for bondary conditions later.
      CALL lsyssc_duplicateMatrix (rproblem%p_RlevelInfo(i)%rmatrixB1, &
                                   p_rmatrix%RmatrixBlock(1,4),&
                                   LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)

      CALL lsyssc_duplicateMatrix (rproblem%p_RlevelInfo(i)%rmatrixB2, &
                                   p_rmatrix%RmatrixBlock(2,4),&
                                   LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)
      
      CALL lsyssc_duplicateMatrix (rproblem%p_RlevelInfo(i)%rmatrixB3, &
                                   p_rmatrix%RmatrixBlock(3,4),&
                                   LSYSSC_DUP_SHARE,LSYSSC_DUP_COPY)

      ! Furthermore, put B1^T and B2^T to the block matrix.
      CALL lsyssc_transposeMatrix (rproblem%p_RlevelInfo(i)%rmatrixB1, &
                                   p_rmatrix%RmatrixBlock(4,1),&
                                   LSYSSC_TR_VIRTUAL)

      CALL lsyssc_transposeMatrix (rproblem%p_RlevelInfo(i)%rmatrixB2, &
                                   p_rmatrix%RmatrixBlock(4,2),&
                                   LSYSSC_TR_VIRTUAL)

      CALL lsyssc_transposeMatrix (rproblem%p_RlevelInfo(i)%rmatrixB3, &
                                   p_rmatrix%RmatrixBlock(4,3),&
                                   LSYSSC_TR_VIRTUAL)

      ! Update the structural information of the block matrix, as we manually
      ! changed the submatrices:
      CALL lsysbl_updateMatStrucInfo (p_rmatrix)
      
      ! Now on all levels except for the maximum one, create a temporary 
      ! vector on that level, based on the matrix template.
      ! It's used for building the matrices on lower levels.
      IF (i .LT. rproblem%NLMAX) THEN
        p_rtempVector => rproblem%p_RlevelInfo(i)%rtempVector
        CALL lsysbl_createVecBlockIndMat (p_rmatrix,p_rtempVector,.FALSE.)
        
        ! Add the temp vector to the collection on level i
        ! for use in the callback routine
        CALL collct_setvalue_vec(rproblem%rcollection,'RTEMPVEC',p_rtempVector,&
                                .TRUE.,i)
      END IF

    END DO

    ! (Only) on the finest level, we need to calculate a RHS vector
    ! and to allocate a solution vector.
    
    p_rrhs    => rproblem%rrhs   
    p_rvector => rproblem%rvector

    ! Although we could manually create the solution/RHS vector,
    ! the easiest way to set up the vector structure is
    ! to create it by using our matrix as template:
    CALL lsysbl_createVecBlockIndMat (p_rmatrix,p_rrhs, .FALSE.)
    CALL lsysbl_createVecBlockIndMat (p_rmatrix,p_rvector, .FALSE.)

    ! Save the solution/RHS vector to the collection. Might be used
    ! later (e.g. in nonlinear problems)
    CALL collct_setvalue_vec(rproblem%rcollection,'RHS',p_rrhs,.TRUE.)
    CALL collct_setvalue_vec(rproblem%rcollection,'SOLUTION',p_rvector,.TRUE.)
    
    ! The vector structure is ready but the entries are missing. 
    ! So the next thing is to calculate the content of that vector.
    !
    ! At first set up the corresponding linear form (f,Phi_j):
    rlinform%itermCount = 1
    rlinform%Idescriptors(1) = DER_FUNC3D
    
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
    ! Discretise the X-velocity part:
    CALL linf_buildVectorScalar (&
              p_rdiscretisation%RspatialDiscretisation(1),rlinform,.TRUE.,&
              p_rrhs%RvectorBlock(1),coeff_RHS_x,&
              rproblem%rcollection)

    ! And the Y-velocity part:
    CALL linf_buildVectorScalar (&
              p_rdiscretisation%RspatialDiscretisation(2),rlinform,.TRUE.,&
              p_rrhs%RvectorBlock(2),coeff_RHS_y,&
              rproblem%rcollection)

    ! And the Z-velocity part:
    CALL linf_buildVectorScalar (&
              p_rdiscretisation%RspatialDiscretisation(3),rlinform,.TRUE.,&
              p_rrhs%RvectorBlock(3),coeff_RHS_z,&
              rproblem%rcollection)

    ! The third subvector must be zero - as it represents the RHS of
    ! the equation "div(u) = 0".
    CALL lsyssc_clearVector(p_rrhs%RvectorBlock(4))
                                
    ! Clear the solution vector on the finest level.
    CALL lsysbl_clearVector(rproblem%rvector)
    
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_discretiseBC (rdiscretisation,rdiscreteBC)
  
!<description>
  ! This routine discretises the current boundary conditions for
  ! the discretisation specified by rdiscretisation.
!</description>

!<input>
  ! A discretisation structure specifying the current discretisation.
  TYPE(t_blockDiscretisation), INTENT(IN) :: rdiscretisation
!</input>

!<inputoutput>
  ! A structure that receives the discretised boundary conditions.
  TYPE(t_discreteBC), INTENT(INOUT) :: rdiscreteBC
!</inputoutput>

!</subroutine>

    ! local variables
    TYPE(t_meshRegion) :: rmeshRegion
    
    ! First of all, get a mesh region that describes the cube's boundary.
    CALL mshreg_createFromNodalProp(rmeshRegion, &
                                    rdiscretisation%p_rtriangulation, &
                                    MSHREG_IDX_ALL)

    ! We want to prescribe Dirichlet on the cube's boundary, except for
    ! the face where the X-coordinate is 1. So the next thing we need
    ! to do is to kick out all faces, edges and vertices which
    ! belong to the cube's face with X-coordinate 1.
    ! This task is performed by the following auxiliary routine:
    CALL cc3daux_calcCubeDirichletRegion(rmeshRegion)

    ! Initialise the structure for discrete boundary conditions.
    !CALL bcasm_initDiscreteBC (rdiscreteBC)

    ! Set Dirichlet BCs for X-velocity:
    CALL bcasm_newDirichletBConMR(rdiscretisation, 1, &
        rdiscreteBC, rmeshRegion, getBoundaryValues)

    ! Set Dirichlet BCs for Y-velocity:
    CALL bcasm_newDirichletBConMR(rdiscretisation, 2, &
        rdiscreteBC, rmeshRegion, getBoundaryValues)

    ! Set Dirichlet BCs for Z-velocity:
    CALL bcasm_newDirichletBConMR(rdiscretisation, 3, &
        rdiscreteBC, rmeshRegion, getBoundaryValues)

    ! Don't forget to release the mesh region
    CALL mshreg_done(rmeshRegion)

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_initDiscreteBC (rproblem)
  
!<description>
  ! This calculates the discrete version of the boundary conditions and
  ! assigns it to the system matrix and RHS vector.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i

  ! A pointer to the system matrix and the RHS vector as well as 
  ! the discretisation
  TYPE(t_matrixBlock), POINTER :: p_rmatrix
  TYPE(t_vectorBlock), POINTER :: p_rrhs,p_rvector
  TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation

  ! Pointer to structure for saving discrete BC's:
  TYPE(t_discreteBC), POINTER :: p_rdiscreteBC
    
    DO i=rproblem%NLMIN,rproblem%NLMAX
    
      ! Get our velocity matrix from the problem structure.
      p_rmatrix => rproblem%p_RlevelInfo(i)%rmatrix
      
      ! From the matrix or the RHS we have access to the discretisation and the
      ! analytic boundary conditions.
      p_rdiscretisation => p_rmatrix%p_rblockDiscretisation
      
      ! For implementing boundary conditions, we use a 'filter technique with
      ! discretised boundary conditions'. This means, we first have to calculate
      ! a discrete version of the analytic BC, which we can implement into the
      ! solution/RHS vectors using the corresponding filter.
      !
      ! Create a t_discreteBC structure where we store all discretised boundary
      ! conditions.
      CALL bcasm_initDiscreteBC(rproblem%p_RlevelInfo(i)%rdiscreteBC)
      
      ! Discretise the boundary conditions.
      CALL c3d1_discretiseBC (p_rdiscretisation,rproblem%p_RlevelInfo(i)%rdiscreteBC)
                               
      ! Hang the pointer into the the matrix. That way, these
      ! boundary conditions are always connected to that matrix and that
      ! vector.
      p_rdiscreteBC => rproblem%p_RlevelInfo(i)%rdiscreteBC
      
      p_rmatrix%p_rdiscreteBC => p_rdiscreteBC
      
      ! Also hang in the boundary conditions into the temporary vector that is
      ! used for the creation of solutions on lower levels.
      ! This allows us to filter this vector when we create it.
      rproblem%p_RlevelInfo(i)%rtempVector%p_rdiscreteBC => p_rdiscreteBC
      
    END DO

    ! On the finest level, attach the discrete BC also
    ! to the solution and RHS vector. They need it to be compatible
    ! to the matrix on the finest level.
    p_rdiscreteBC => rproblem%p_RlevelInfo(rproblem%NLMAX)%rdiscreteBC
    
    p_rrhs    => rproblem%rrhs   
    p_rvector => rproblem%rvector
    
    p_rrhs%p_rdiscreteBC => p_rdiscreteBC
    p_rvector%p_rdiscreteBC => p_rdiscreteBC
                
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_implementBC (rproblem)
  
!<description>
  ! Implements boundary conditions into the RHS and into a given solution vector.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i,ilvmax
  
    ! A pointer to the system matrix and the RHS vector as well as 
    ! the discretisation
    TYPE(t_matrixBlock), POINTER :: p_rmatrix
    TYPE(t_vectorBlock), POINTER :: p_rrhs,p_rvector
    
    ! Get our the right hand side and solution from the problem structure
    ! on the finest level
    ilvmax = rproblem%NLMAX
    p_rrhs    => rproblem%rrhs   
    p_rvector => rproblem%rvector
    
    ! Filter the solution and RHS vectors through the boundary-condition-
    ! implementation filter. This implements all discrete boundary
    ! conditions.
    ! Use the RHS-filter for the RHS and the solution-filter for the
    ! solution vector.
    CALL vecfil_discreteBCrhs (p_rrhs)
    CALL vecfil_discreteBCsol (p_rvector)

    ! Implement discrete boundary conditions into the matrices on all 
    ! levels, too.
    ! In fact, this modifies the B-matrices. The A-matrices are overwritten
    ! later and must then be modified again!
    DO i=rproblem%NLMIN ,rproblem%NLMAX
      p_rmatrix => rproblem%p_RlevelInfo(i)%rmatrix
      CALL matfil_discreteBC (p_rmatrix)
    END DO

  END SUBROUTINE

  ! ***************************************************************************
  !<subroutine>
  
    SUBROUTINE c3d1_getDefect (ite,rx,rb,rd,p_rcollection)
  
    USE linearsystemblock
    USE collection
    
  !<description>
    ! FOR NONLINEAR ITERATION:
    ! Defect vector calculation callback routine. Based on the current iteration 
    ! vector rx and the right hand side vector rb, this routine has to compute the 
    ! defect vector rd. The routine accepts a pointer to a collection structure 
    ! p_rcollection, which allows the routine to access information from the
    ! main application (e.g. system matrices).
  !</description>

  !<input>
    ! Number of current iteration. 0=build initial defect
    INTEGER, INTENT(IN)                           :: ite

    ! Current iteration vector
    TYPE(t_vectorBlock), INTENT(IN),TARGET        :: rx

    ! Right hand side vector of the equation.
    TYPE(t_vectorBlock), INTENT(IN)               :: rb
  !</input>
               
  !<inputoutput>
    ! Pointer to collection structure of the application. Points to NULL()
    ! if there is none.
    TYPE(t_collection), POINTER                   :: p_rcollection

    ! Defect vector b-A(x)x. This must be filled by the callback routine
    ! with data.
    TYPE(t_vectorBlock), INTENT(INOUT)            :: rd
  !</inputoutput>
  
  !</subroutine>

    ! local variables
    INTEGER :: ilvmax
    TYPE(t_matrixBlock), POINTER :: p_rmatrix
    TYPE(t_matrixScalar), POINTER :: p_rmatrixLaplace
    TYPE(t_matrixBlock) :: rmatrixLaplaceBlock
    TYPE(t_convStreamlineDiffusion) :: rsd
    
    ! A filter chain to pre-filter the vectors and the matrix.
    TYPE(t_filterChain), DIMENSION(1), TARGET :: RfilterChain

      ! Get minimum/maximum level from the collection
      ilvmax = collct_getvalue_int (p_rcollection,'NLMAX')
      
      ! Get the system and the Laplace matrix on the maximum level
      p_rmatrix => collct_getvalue_mat (p_rcollection,'SYSTEMMAT',ilvmax)
      p_rmatrixLaplace => collct_getvalue_matsca (p_rcollection,'LAPLACE',ilvmax)
      
      ! Build a temporary 4x4 block matrix rmatrixLaplace with Laplace 
      ! on the main diagonal:
      !
      ! /  L    0    0    B1 \
      ! |  0    L    0    B2 |
      ! |  0    0    L    B3 |
      ! \ B1^T B2^T B3^T     /
      !
      CALL lsysbl_duplicateMatrix (p_rmatrix,rmatrixLaplaceBlock,&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
          
      CALL lsyssc_duplicateMatrix (p_rmatrixLaplace,&
          rmatrixLaplaceBlock%RmatrixBlock(1,1),&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)

      CALL lsyssc_duplicateMatrix (p_rmatrixLaplace,&
          rmatrixLaplaceBlock%RmatrixBlock(2,2),&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)
      
      CALL lsyssc_duplicateMatrix (p_rmatrixLaplace,&
          rmatrixLaplaceBlock%RmatrixBlock(3,3),&
          LSYSSC_DUP_SHARE,LSYSSC_DUP_SHARE)

      ! Now, in the first step, we build the linear part of the nonlinear defect:
      !     d_lin = rhs - (-nu * Laplace(.))*solution
      CALL lsysbl_copyVector (rb,rd)
      CALL lsysbl_blockMatVec (rmatrixLaplaceBlock, rx, rd, -1.0_DP, 1.0_DP)
      
      ! Release the temporary matrix again.
      CALL lsysbl_releaseMatrix (rmatrixLaplaceBlock)
      
      ! For the final defect
      !
      !     d = rhs - (-nu * Laplace(.))*solution - u*grad(.)*solution
      !       = d_lin -  u*grad(.)*solution
      !
      ! we need the nonlinearity.
      
      ! Set up the upwind structure for the creation of the defect.
      ! There's not much to do, only initialise the viscosity...
      !rupwind%dnu = collct_getvalue_real (p_rcollection,'NU')
      rsd%dnu = collct_getvalue_real (p_rcollection,'NU')
      
      ! Set up a filter that modifies the block vectors/matrix
      ! according to boundary conditions.
      ! Initialise the first filter of the filter chain as boundary
      ! implementation filter for defect vectors:
      RfilterChain(1)%ifilterType = FILTER_DISCBCDEFREAL

      ! Apply the filter chain to the defect vector.
      ! As the filter consists only of an implementation filter for
      ! boundary conditions, this implements the boundary conditions
      ! into the defect vector.
      CALL filter_applyFilterChainVec (rd, RfilterChain)
      
      ! Call the upwind method to calculate the nonlinear defect.
      ! As we calculate only the defect, the matrix is ignored!
      rsd%dupsam = 1.0_DP
      CALL conv_streamlineDiffusion3d(rx,rx,1.0_DP,0.0_DP,&
                          rsd, CONV_MODDEFECT, &
                          p_rmatrix%RmatrixBlock(1,1), rx, rd)      
      
      ! Apply the filter chain to the defect vector again - since the
      ! implementation of the nonlinearity usually changes the Dirichlet
      ! nodes in the vector!
      CALL filter_applyFilterChainVec (rd, RfilterChain)

      ! That's it
      
    END SUBROUTINE
    
  ! ***************************************************************************

  !<subroutine>

    SUBROUTINE c3d1_getOptimalDamping (rd,rx,rb,rtemp1,rtemp2,domega,p_rcollection)
  
  !<description>
    ! This subroutine is called inside of the nonlinear loop, to be precise,
    ! inside of c3d1_precondDefect. It calculates an optiman damping parameter
    ! for the nonlinear defect correction.
    !
    ! The nonlinear loop reads:
    !
    !     $$ u_(n+1) = u_n + OMEGA * C^{-1}d_n $$
    !
    ! with $d_n$ the nonlinear defect and $C^{-1}$ a preconditioner (usually
    ! the linearised system).
    ! Based on the current solution $u_n$, the defect vector $d_n$, the RHS 
    ! vector $f_n$ and the previous parameter OMEGA, a new 
    ! OMEGA=domega value is calculated.
    !
    ! The nonlinear system matrix on the finest level in the collection is 
    ! overwritten by $A(u_n+domega_{old}*C^{-1}d_n)$.
  !</description>

  !<input>
    ! Current iteration vector
    TYPE(t_vectorBlock), INTENT(IN)               :: rx

    ! Current RHS vector of the nonlinear equation
    TYPE(t_vectorBlock), INTENT(IN)               :: rb

    ! Defect vector b-A(x)x. 
    TYPE(t_vectorBlock), INTENT(IN)               :: rd

    ! Pointer to collection structure of the application. Points to NULL()
    ! if there is none.
    TYPE(t_collection), POINTER                   :: p_rcollection
  !</input>

  !<inputoutput>
    ! A temporary vector in the structure of rx
    TYPE(t_vectorBlock), INTENT(INOUT)            :: rtemp1

    ! A 2nd temporary vector in the structure of rx
    TYPE(t_vectorBlock), INTENT(INOUT)            :: rtemp2

    ! Damping parameter. On entry: an initial value given e.g. by the
    ! previous step.
    ! On return: The new damping parameter.
    REAL(DP), INTENT(INOUT)                       :: domega
  !</inputoutput>
  
  !</subroutine>

    ! local variables
    INTEGER :: ilvmax
    REAL(DP) :: domegaMin, domegaMax,dskv1,dskv2
    TYPE(t_matrixBlock), POINTER :: p_rmatrix
    TYPE(t_matrixScalar), POINTER :: p_rmatrixLaplace
    TYPE(t_convStreamlineDiffusion) :: rsd

    ! A filter chain to pre-filter the vectors and the matrix.
    TYPE(t_filterChain), DIMENSION(1), TARGET :: RfilterChain
    
      ! Get minimum/maximum level from the collection
      ilvmax = collct_getvalue_int (p_rcollection,'NLMAX')
      
      ! Initialise minimum/maximum omega. In a later implementation, this
      ! might be set using a parameter from a DAT-file.
      domegaMin = 0.0_DP
      domegaMax = 1.0_DP
      
      ! Is there anything to do?
      IF (domegaMin .GE. domegaMax) THEN
        ! No - cancel.
        domega = domegaMin
        RETURN
      END IF

      ! Get the system and the Laplace matrix on the maximum level
      p_rmatrix => collct_getvalue_mat (p_rcollection,'SYSTEMMAT',ilvmax)
      p_rmatrixLaplace => collct_getvalue_matsca (p_rcollection,'LAPLACE',ilvmax)

      ! Set up the upwind structure for the creation of the defect.
      ! There's not much to do, only initialise the viscosity...
      !rupwind%dnu = collct_getvalue_real (p_rcollection,'NU')
      rsd%dnu = collct_getvalue_real (p_rcollection,'NU')
      
      ! Set up a filter that modifies the block vectors/matrix
      ! according to boundary conditions.
      ! Initialise the first filter of the filter chain as boundary
      ! implementation filter for defect vectors:
      RfilterChain(1)%ifilterType = FILTER_DISCBCDEFREAL
      
      ! We now want to calculate a new OMEGA parameter
      ! with OMGMIN < OMEGA < OMGMAX.
      !
      ! The defect correction for a problem like T(u)u=f has the form
      !
      !       u_(n+1)  =  u_n  +  OMEGA * C * ( f - T(u_n)u_n )
      !                =  u_n  +  OMEGA * d_n
      !
      ! with an appropriate preconditioner C, which we don't care here.
      ! In our case, this iteration system can be written as:
      !
      ! (u1)     (u1)                     ( (f1)   [ A         B1] (u1) )
      ! (u2)  := (u2)  + OMEGA * C^{-1} * ( (f2) - [      A    B2] (u2) )
      ! (p )     (p )                     ( (fp)   [ B1^T B2^T 0 ] (p ) )
      !
      !                                   |------------------------------|
      !                                              = d_n
      !                            |-------------------------------------|
      !                                        = Y = (y1,y2,yp) = rd
      !
      ! with KST1=KST1(u1,u2,p) and Y=rd being the solution from
      ! the Oseen equation with 
      !
      !                  [ A         B1 ]
      !    C = T(u_n) =  [      A    B2 ]
      !                  [ B1^T B2^T 0  ]
      !
      ! The parameter OMEGA is calculated as the result of the 1D
      ! minimization problem:
      !
      !   OMEGA = min_omega || T(u^l+omega*Y)*(u^l+omega*Y) - f ||_E
      !
      !           < T(u^l+omegaold*Y)Y , f - T(u^l+omegaold*Y)u^l >
      !        ~= -------------------------------------------------
      !              < T(u^l+omegaold*Y)Y , T(u^l+omegaold*Y)Y >
      !
      ! when choosing omegaold=previous omega, which is a good choice
      ! as one can see by linearization (see p. 170, Turek's book).
      !
      ! Here, ||.||_E denotes the the Euclidian norm to the Euclidian 
      ! scalar product <.,.>.
      
      ! ==================================================================
      ! First term of scalar product in the nominator
      !
      ! Calculate the new nonlinear block A at the
      ! point rtemp1 = u_n + omegaold*Y
      ! ==================================================================
      !
      ! At first, calculate the point rtemp1 = u_n+omegaold*Y where
      ! to evaluate the matrix.

      CALL lsysbl_copyVector(rd,rtemp1)
      CALL lsysbl_vectorLinearComb (rx,rtemp1,1.0_DP,domega)

      ! Construct the linear part of the nonlinear matrix on the maximum
      ! level. 
      !
      ! The system matrix looks like:
      !   (  A    0   B1 )
      !   (  0    A   B2 )
      !   ( B1^T B2^T 0  )
      !
      ! The A-matrix consists of Laplace+Convection.
      ! We build them separately and add together.
      !
      ! So at first, initialise the A-matrix with the Laplace contribution.
      ! We ignore the structure and simply overwrite the content of the
      ! system submatrices with the Laplace matrix.
      CALL lsyssc_duplicateMatrix (p_rmatrixLaplace,p_rmatrix%RmatrixBlock(1,1),&
                                   LSYSSC_DUP_IGNORE, LSYSSC_DUP_COPY)

      ! Call the upwind method to evaluate nonlinearity part of the matrix
      ! in the point rtemp1.
      rsd%dupsam = 1.0_DP
      CALL conv_streamlineDiffusion3d (rtemp1, rtemp1, 1.0_DP, 0.0_DP,&
                          rsd, CONV_MODMATRIX, p_rmatrix%RmatrixBlock(1,1))      
                                    
      ! Apply the filter chain to the matrix.
      ! As the filter consists only of an implementation filter for
      ! boundary conditions, this implements the boundary conditions
      ! into the system matrix.
      CALL filter_applyFilterChainMat (p_rmatrix, RfilterChain)
        
      ! ==================================================================
      ! Second term of the scalar product in the nominator
      ! Calculate the defect rtemp2 = F-T*u_n.
      ! ==================================================================

      CALL lsysbl_copyVector (rb,rtemp2)
      CALL lsysbl_blockMatVec (p_rmatrix, rx, rtemp2, -1.0_DP, 1.0_DP)
      
      ! This is a defect vector - filter it! This e.g. implements boundary
      ! conditions.
      CALL filter_applyFilterChainVec (rtemp2, RfilterChain)
      
      ! ==================================================================
      ! For all terms in the fraction:
      ! Calculate the value  rtemp1 = T*Y
      ! ==================================================================

      CALL lsysbl_blockMatVec (p_rmatrix, rd, rtemp1, 1.0_DP, 0.0_DP)
      
      ! This is a defect vector against 0 - filter it! This e.g. 
      ! implements boundary conditions.
      CALL filter_applyFilterChainVec (rtemp1, RfilterChain)
      
      ! ==================================================================
      ! Calculation of the fraction terms.
      ! Calculate nominator:    dskv1:= (T*Y,D)   = (rtemp1,rtemp2)
      ! Calculate denominator:  dskv2:= (T*Y,T*Y) = (rtemp1,rtemp1)
      ! ==================================================================
      
      dskv1 = lsysbl_scalarProduct (rtemp1, rtemp2)
      dskv2 = lsysbl_scalarProduct (rtemp1, rtemp1)
      
      IF (dskv2 .LT. 1.0E-40_DP) THEN
        PRINT *,'Error in c3d1_getOptimalDamping. dskv2 nearly zero.'
        PRINT *,'Optimal damping parameter singular.'
        PRINT *,'Is the triangulation ok??? .tri-file destroyed?'
        STOP
      END IF
      
      ! Ok, we have the nominator and the denominator. Divide them
      ! by each other to calculate the new OMEGA.
      
      domega = dskv1 / dskv2
      
      ! And make sure it's in the allowed range:
      
      domega = max(domegamin,min(domegamax,domega))
      
      ! That's it, we have our new Omega.
  
    END SUBROUTINE

  ! ***************************************************************************

  !<subroutine>

    SUBROUTINE c3d1_precondDefect (ite, rd,rx,rb,domega,bsuccess,p_rcollection)
  
    USE linearsystemblock
    USE collection
    
  !<description>
    ! FOR NONLINEAR ITERATION:
    ! Defect vector calculation callback routine. Based on the current iteration 
    ! vector rx and the right hand side vector rb, this routine has to compute the 
    ! defect vector rd. The routine accepts a pointer to a collection structure 
    ! p_rcollection, which allows the routine to access information from the
    ! main application (e.g. system matrices).
  !</description>

  !<inputoutput>
    ! Number of current iteration. 
    INTEGER, INTENT(IN)                           :: ite

    ! Defect vector b-A(x)x. This must be replaced by J^{-1} rd by a preconditioner.
    TYPE(t_vectorBlock), INTENT(INOUT)            :: rd

    ! Pointer to collection structure of the application. Points to NULL()
    ! if there is none.
    TYPE(t_collection), POINTER                   :: p_rcollection
    
    ! Damping parameter. Is set to rsolverNode%domega (usually = 1.0_DP)
    ! on the first call to the callback routine.
    ! The callback routine can modify this parameter according to any suitable
    ! algorithm to calculate an 'optimal damping' parameter. The nonlinear loop
    ! will then use this for adding rd to the solution vector:
    ! $$ x_{n+1} = x_n + domega*rd $$
    ! domega will stay at this value until it's changed again.
    REAL(DP), INTENT(INOUT)                       :: domega

    ! If the preconditioning was a success. Is normally automatically set to
    ! TRUE. If there is an error in the preconditioner, this flag can be
    ! set to FALSE. In this case, the nonlinear solver breaks down with
    ! the error flag set to 'preconditioner broke down'.
    LOGICAL, INTENT(INOUT)                        :: bsuccess
  !</inputoutput>
  
  !<input>
    ! Current iteration vector
    TYPE(t_vectorBlock), INTENT(IN), TARGET       :: rx

    ! Current right hand side of the nonlinear system
    TYPE(t_vectorBlock), INTENT(IN), TARGET       :: rb
  !</input>
  
  !</subroutine>
  
    ! An array for the system matrix(matrices) during the initialisation of
    ! the linear solver.
    TYPE(t_matrixBlock), POINTER :: p_rmatrix
    TYPE(t_matrixScalar), POINTER :: p_rmatrixLaplace
    TYPE(t_vectorScalar), POINTER :: p_rvectorTemp,p_rvectorTemp2
    TYPE(t_vectorBlock) :: rtemp1,rtemp2
    INTEGER :: ierror,ilvmax,ilvmin, ilev
    TYPE(t_linsolNode), POINTER :: p_rsolverNode
    TYPE(t_convStreamlineDiffusion) :: rsd
    TYPE(t_vectorBlock), POINTER :: p_rvectorFine,p_rvectorCoarse

    ! An interlevel projection structure for changing levels
    TYPE(t_interlevelProjectionBlock), POINTER :: p_rprojection

    ! A filter chain to pre-filter the vectors and the matrix.
    TYPE(t_filterChain), DIMENSION(1), TARGET :: RfilterChain
    REAL(DP), DIMENSION(:), POINTER :: p_Ddata

      ! Get minimum and maximum level from the collection
      ilvmax = collct_getvalue_int (p_rcollection,'NLMAX')
      ilvmin = collct_getvalue_int (p_rcollection,'NLMIN')
      
      ! Set up the upwind structure for the creation of the defect.
      ! There's not much to do, only initialise the viscosity...
      !rupwind%dnu = collct_getvalue_real (p_rcollection,'NU')
      rsd%dnu = collct_getvalue_real (p_rcollection,'NU')
      
      ! Set up a filter that modifies the block vectors/matrix
      ! according to boundary conditions.
      ! Initialise the first filter of the filter chain as boundary
      ! implementation filter for defect vectors:
      RfilterChain(1)%ifilterType = FILTER_DISCBCDEFREAL
      
      ! Get the interlevel projection structure and the temporary vector
      ! from the collection.
      ! Our 'parent' prepared there how to interpolate the solution on the
      ! fine grid to coarser grids.
      p_rprojection => collct_getvalue_ilvp(p_rcollection,'ILVPROJECTION')
      p_rvectorTemp => collct_getvalue_vecsca(p_rcollection,'RTEMPSCALAR')

      ! On all levels, we have to set up the nonlinear system matrix,
      ! so that the linear solver can be applied to it.

      DO ilev=ilvmax,ilvmin,-1
      
        ! Get the system matrix and the Laplace matrix
        p_rmatrix => collct_getvalue_mat (p_rcollection,'SYSTEMMAT',ilev)
        p_rmatrixLaplace => collct_getvalue_matsca (p_rcollection,'LAPLACE',ilev)
        
        ! On the highest level, we use rx as solution to build the nonlinear
        ! matrix. On lower levels, we have to create a solution
        ! on that level from a fine-grid solution before we can use
        ! it to build the matrix!
        IF (ilev .EQ. ilvmax) THEN
          p_rvectorCoarse => rx
        ELSE
          ! Get the temporary vector on level i. Will receive the solution
          ! vector on that level. 
          p_rvectorCoarse => collct_getvalue_vec (p_rcollection,'RTEMPVEC',ilev)
          
          ! Get the solution vector on level i+1. This is either the temporary
          ! vector on that level, or the solution vector on the maximum level.
          IF (ilev .LT. ilvmax-1) THEN
            p_rvectorFine => collct_getvalue_vec (p_rcollection,'RTEMPVEC',ilev+1)
          ELSE
            p_rvectorFine => rx
          END IF

          ! Interpolate the solution from the finer grid to the coarser grid.
          ! The interpolation is configured in the interlevel projection
          ! structure we got from the collection.
          CALL mlprj_performInterpolation (p_rprojection,p_rvectorCoarse, &
                                           p_rvectorFine,p_rvectorTemp)

          ! Apply the filter chain to the temp vector.
          ! This implements the boundary conditions that are attached to it.
          CALL filter_applyFilterChainVec (p_rvectorCoarse, RfilterChain)

        END IF
        
        ! The system matrix looks like:
        !   (  A    0   B1 )
        !   (  0    A   B2 )
        !   ( B1^T B2^T 0  )
        !
        ! The A-matrix consists of Laplace+Convection.
        ! We build them separately and add together.
        !
        ! So at first, initialise the A-matrix with the Laplace contribution.
        ! We ignore the structure and simply overwrite the content of the
        ! system submatrices with the Laplace matrix.
        CALL lsyssc_duplicateMatrix (p_rmatrixLaplace,p_rmatrix%RmatrixBlock(1,1),&
                                     LSYSSC_DUP_IGNORE, LSYSSC_DUP_COPY)

        ! Call the upwind method to calculate the nonlinear matrix.
        rsd%dupsam = 1.0_DP
        CALL conv_streamlineDiffusion3d (p_rvectorCoarse, p_rvectorCoarse, &
                            1.0_DP, 0.0_DP, rsd, CONV_MODMATRIX, &
                            p_rmatrix%RmatrixBlock(1,1))      
                                     
        ! Apply the filter chain to the matrix.
        ! As the filter consists only of an implementation filter for
        ! boundary conditions, this implements the boundary conditions
        ! into the system matrix.
        CALL filter_applyFilterChainMat (p_rmatrix, RfilterChain)
        
      END DO

      ! Our 'parent' (the caller of the nonlinear solver) has prepared
      ! a preconditioner node for us (a linear solver with symbolically
      ! factorised matrices). Get this from the collection.
      p_rsolverNode => collct_getvalue_linsol(p_rcollection,'LINSOLVER')

      ! Initialise data of the solver. This in fact performs a numeric
      ! factorisation of the matrices in UMFPACK-like solvers.
      CALL linsol_initData (p_rsolverNode, ierror)
      IF (ierror .NE. LINSOL_ERR_NOERROR) STOP
      
      ! Finally solve the system. As we want to solve Ax=b with
      ! b being the real RHS and x being the real solution vector,
      ! we use linsol_solveAdaptively. If b is a defect
      ! RHS and x a defect update to be added to a solution vector,
      ! we would have to use linsol_precondDefect instead.
      CALL linsol_precondDefect (p_rsolverNode,rd)

      ! Release the numeric factorisation of the matrix.
      ! We don't release the symbolic factorisation, as we can use them
      ! for the next iteration.
      CALL linsol_doneData (p_rsolverNode)
      
      ! Finally calculate a new damping parameter domega.
      !
      ! For this purpose, we need two temporary vectors.
      ! On one hand, we have p_rvectorTemp.
      ! Get the second temporary vector from the collection as it was
      ! prepared by our 'parent' that invoked the nonlinear solver.
      p_rvectorTemp2 => collct_getvalue_vecsca(p_rcollection,'RTEMP2SCALAR')
      
      ! Both temp vectors are scalar, but we need block-vectors in the
      ! structure of rx/rb. Derive block vectors in that structure that
      ! share their memory with the scalar temp vectors. Note that the
      ! temp vectors are created large enough by our parent!
      CALL lsysbl_createVecFromScalar (p_rvectorTemp,rtemp1)
      CALL lsysbl_enforceStructure (rb,rtemp1)

      CALL lsysbl_createVecFromScalar (p_rvectorTemp2,rtemp2)
      CALL lsysbl_enforceStructure (rb,rtemp2)

      ! Calculate the omega
      CALL c3d1_getOptimalDamping (rd,rx,rb,rtemp1,rtemp2,&
                                   domega,p_rcollection)

      ! Release the temp block vectors. This only cleans up the structure.
      ! The data is not released from heap as it belongs to the
      ! scalar temp vectors.
      CALL lsysbl_releaseVector (rtemp2)
      CALL lsysbl_releaseVector (rtemp1)

    END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_solve (rproblem)
  
!<description>
  ! Solves the given problem by applying a nonlinear solver with linear solver
  ! as preconditioner.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER :: ilvmin,ilvmax
    INTEGER :: i
    INTEGER(PREC_VECIDX) :: imaxmem

    ! Error indicator during initialisation of the solver
    INTEGER :: ierror    
  
    ! A filter chain to filter the vectors and the matrix during the
    ! solution process.
    TYPE(t_filterChain), DIMENSION(1), TARGET :: RfilterChain
    TYPE(t_filterChain), DIMENSION(:), POINTER :: p_RfilterChain

    ! A pointer to the system matrix and the RHS vector as well as 
    ! the discretisation
    TYPE(t_matrixBlock), POINTER :: p_rmatrix
    TYPE(t_vectorBlock), POINTER :: p_rrhs,p_rvector
    TYPE(t_vectorBlock), TARGET :: rtempBlock
    TYPE(t_vectorScalar), TARGET :: rtempVectorSc,rtempVectorSc2

    ! A solver node that accepts parameters for the linear solver    
    TYPE(t_linsolNode), POINTER :: p_rsolverNode,p_rsmoother
    TYPE(t_linsolNode), POINTER :: p_rcoarseGridSolver,p_rpreconditioner

    ! The nonlinear solver configuration
    TYPE(t_nlsolNode) :: rnlSol

    ! An array for the system matrix(matrices) during the initialisation of
    ! the linear solver.
    TYPE(t_matrixBlock), DIMENSION(:), TARGET, ALLOCATABLE :: Rmatrices
    
    ! An interlevel projection structure for changing levels
    TYPE(t_interlevelProjectionBlock) :: rprojection

    ! One level of multigrid
    TYPE(t_linsolMGLevelInfo), POINTER :: p_RlevelInfo

    ilvmin = rproblem%NLMIN
    ilvmax = rproblem%NLMAX
    
    ! Get our right hand side / solution / matrix on the finest
    ! level from the problem structure.
    p_rrhs    => rproblem%rrhs   
    p_rvector => rproblem%rvector
    p_rmatrix => rproblem%p_RlevelInfo(ilvmax)%rmatrix
    
    ! Now we have to build up the level information for multigrid.
    !
    ! At first, initialise a standard interlevel projection structure. We
    ! can use the same structure for all levels. Therefore it's enough
    ! to initialise one structure using the RHS vector on the finest
    ! level to specify the shape of the PDE-discretisation.
    CALL mlprj_initProjectionVec (rprojection,rproblem%rrhs)
    
    ! During the linear solver, the boundary conditions must
    ! frequently be imposed to the vectors. This is done using
    ! a filter chain. As the linear solver does not work with 
    ! the actual solution vectors but with defect vectors instead,
    ! a filter for implementing the real boundary conditions 
    ! would be wrong.
    ! Therefore, create a filter chain with one filter only,
    ! which implements Dirichlet-conditions into a defect vector.
    RfilterChain(1)%ifilterType = FILTER_DISCBCDEFREAL

    ! Create a Multigrid-solver. Attach the above filter chain
    ! to the solver, so that the solver automatically filters
    ! the vector during the solution process.
    p_RfilterChain => RfilterChain
    CALL linsol_initMultigrid (p_rsolverNode,p_RfilterChain)
    !CALL linsol_initVANCA (p_rpreconditioner,1.0_DP,LINSOL_VANCA_3DFNAVST)
    !CALL linsol_initBiCGStab (p_rsolverNode,p_rpreconditioner,p_RfilterChain)
    !CALL linsol_initVANCA (p_rsolverNode,1.0_DP,LINSOL_VANCA_3DFNAVST)
    !CALL linsol_initUMFPACK4 (p_rsolverNode)

    ! Set the output level of the solver for some output
    p_rsolverNode%ioutputLevel = 2

    ! Configure MG to gain only one digit. We can do this, as MG is only
    ! used as preconditioner inside of another solver. Furthermore, perform
    ! at least two, at most 10 steps.
    p_rsolverNode%depsRel = 1E-1_DP
    p_rsolverNode%depsAbs = 0.0_DP
    p_rsolverNode%nminIterations = 2
    p_rsolverNode%nmaxIterations = 10
    
    ! Add the interlevel projection structure to the collection; we can
    ! use it later for setting up nonlinear matrices.
    CALL collct_setvalue_ilvp(rproblem%rcollection,'ILVPROJECTION',&
                              rprojection,.TRUE.)
    
    ! Then set up smoothers / coarse grid solver:
    imaxmem = 0
    DO i=ilvmin,ilvmax
      
      ! On the coarsest grid, set up a coarse grid solver and no smoother
      ! On finer grids, set up a smoother but no coarse grid solver.
      NULLIFY(p_rpreconditioner)
      NULLIFY(p_rsmoother)
      NULLIFY(p_rcoarseGridSolver)
      IF (i .EQ. ilvmin) THEN
        ! Set up a BiCGStab solver with VANCA preconditioning as coarse grid solver:
        !CALL linsol_initVANCA (p_rpreconditioner,1.0_DP,LINSOL_VANCA_3DFNAVST)
        !CALL linsol_initBiCGStab (p_rcoarseGridSolver,p_rpreconditioner,p_RfilterChain)
        !p_rcoarseGridSolver%ioutputLevel = 2
        
        ! Setting up UMFPACK coarse grid solver would be:
        CALL linsol_initUMFPACK4 (p_rcoarseGridSolver)

      ELSE
        ! Set up the VANCA smoother for multigrid with damping parameter 0.7,
        ! 4 smoothing steps:
        CALL linsol_initVANCA (p_rsmoother,1.0_DP,LINSOL_VANCA_3DNAVST)
        CALL linsol_convertToSmoother (p_rsmoother,4,0.7_DP)
      END IF
    
      ! Add the level.
      CALL linsol_addMultigridLevel (p_RlevelInfo,p_rsolverNode, rprojection,&
                                     p_rsmoother,p_rsmoother,p_rcoarseGridSolver)

      ! How much memory is necessary for performing the level change?
      ! We ourself must build nonlinear matrices on multiple levels and have
      ! to interpolate the solution vector from finer level to coarser ones.
      ! We need temporary memory for this purpose...
      IF (i .GT. ilvmin) THEN
        ! Pass the system metrices on the coarse/fine grid to 
        ! mlprj_getTempMemoryMat to specify the discretisation structures
        ! of all equations in the PDE there.
        imaxmem = MAX(imaxmem,mlprj_getTempMemoryMat (rprojection,&
                              rproblem%p_RlevelInfo(i-1)%rmatrix,&
                              rproblem%p_RlevelInfo(i)%rmatrix))
      END IF
    END DO
    
    ! Set up a scalar temporary vector that we need for building up nonlinear
    ! matrices. It must be at least as large as MAXMEM and NEQ(finest level),
    ! as we use it for resorting vectors, too.
    CALL lsyssc_createVector (rtempVectorSc,MAX(imaxmem,rproblem%rrhs%NEQ),&
                              .FALSE.,ST_DOUBLE)
    CALL collct_setvalue_vecsca(rproblem%rcollection,'RTEMPSCALAR',&
                                rtempVectorSc,.TRUE.)
    
    ! Set up a second temporary vector that we need for calculating
    ! the optimal defect correction.
    CALL lsyssc_createVector (rtempVectorSc2,rproblem%rrhs%NEQ,.FALSE.,ST_DOUBLE)
    CALL collct_setvalue_vecsca(rproblem%rcollection,'RTEMP2SCALAR',&
                                rtempVectorSc2,.TRUE.)
    
    ! Attach the system matrices to the solver.
    !
    ! We copy our matrices to a big matrix array and transfer that
    ! to the setMatrices routines. This intitialises then the matrices
    ! on all levels according to that array.
    ALLOCATE(Rmatrices(ilvmin:ilvmax))
    Rmatrices(ilvmin:ilvmax) = rproblem%p_RlevelInfo(ilvmin:ilvmax)%rmatrix
    CALL linsol_setMatrices(p_rsolverNode,Rmatrices(ilvmin:ilvmax))
    DEALLOCATE(Rmatrices)
    
    ! Initialise structure/data of the solver. This allows the
    ! solver to allocate memory / perform some precalculation
    ! to the problem.
    CALL linsol_initStructure (p_rsolverNode,ierror)
    IF (ierror .NE. LINSOL_ERR_NOERROR) STOP
    ! Put the prepared solver node to the collection for later use.
    CALL collct_setvalue_linsol(rproblem%rcollection,'LINSOLVER',p_rsolverNode,.TRUE.)
    
    ! Create a temporary vector we need for the nonliner iteration.
    CALL lsysbl_createVecBlockIndirect (rproblem%rrhs, rtempBlock, .FALSE.)

    ! The nonlinear solver structure rnlSol is initialised by the default
    ! initialisation with all necessary information to solve the problem.
    ! We call the nonlinear solver directly. For preconditioning
    ! and defect calculation, we use our own callback routine.
    rnlSol%ioutputLevel = 2
    CALL nlsol_performSolve(rnlSol,rproblem%rvector,rproblem%rrhs,rtempBlock,&
                            c3d1_getDefect,c3d1_precondDefect,&
                            rcollection=rproblem%rcollection)

    ! Release the temporary vector(s)
    CALL lsysbl_releaseVector (rtempBlock)
    CALL lsyssc_releaseVector (rtempVectorSc)
    CALL lsyssc_releaseVector (rtempVectorSc2)
    
    ! Remove the solver node from the collection - not needed anymore there
    CALL collct_deletevalue(rproblem%rcollection,'LINSOLVER')
    
    ! Remove the temporary vector from the collection
    CALL collct_deletevalue(rproblem%rcollection,'RTEMPSCALAR')
    CALL collct_deletevalue(rproblem%rcollection,'RTEMP2SCALAR')
    
    ! Remove the interlevel projection structure
    CALL collct_deletevalue(rproblem%rcollection,'ILVPROJECTION')
    
    ! Clean up the linear solver, release all memory, remove the solver node
    ! from memory.
    CALL linsol_releaseSolver (p_rsolverNode)
    
    ! Release the multilevel projection structure.
    CALL mlprj_doneProjection (rprojection)
    
    PRINT *
    PRINT *,'Nonlinear solver statistics'
    PRINT *,'---------------------------'
    PRINT *,'Intial defect: ',rnlSol%DinitialDefect(1)
    PRINT *,'Final defect:  ',rnlSol%DfinalDefect(1)
    PRINT *,'#Iterations:   ',rnlSol%iiterations

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_postprocessing (rproblem)
  
!<description>
  ! Writes the solution into a GMV file.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  
    ! We need some more variables for postprocessing - i.e. writing
    ! a GMV file.
    REAL(DP), DIMENSION(:), POINTER :: p_Ddata,p_Ddata2,p_Ddata3

    ! Output block for UCD output to GMV file
    TYPE(t_ucdExport) :: rexport

    ! A pointer to the solution vector and to the triangulation.
    TYPE(t_vectorBlock), POINTER :: p_rvector
    TYPE(t_triangulation), POINTER :: p_rtriangulation
    
    ! A vector accepting Q1 data
    TYPE(t_vectorBlock) :: rprjVector
    
    ! A discretisation structure for Q1
    TYPE(t_blockDiscretisation) :: rprjDiscretisation
    
    ! Discrete boundary conditions for the output vector
    TYPE(t_discreteBC), TARGET :: rdiscreteBC

    ! A filter chain to pre-filter the vectors and the matrix.
    TYPE(t_filterChain), DIMENSION(1), TARGET :: RfilterChain

    ! Get the solution vector from the problem structure.
    p_rvector => rproblem%rvector
    
    ! The solution vector is probably not in the way, GMV likes it!
    ! GMV for example does not understand Q1~ vectors!
    ! Therefore, we first have to convert the vector to a form that
    ! GMV understands.
    ! GMV understands only Q1 solutions! So the task is now to create
    ! a Q1 solution from p_rvector and write that out.
    !
    ! For this purpose, first create a 'derived' simple discretisation
    ! structure based on Q1 by copying the main guiding block discretisation
    ! structure and modifying the discretisation structures of the
    ! two velocity subvectors:
    
    CALL spdiscr_duplicateBlockDiscr(p_rvector%p_rblockDiscretisation,rprjDiscretisation)
    
    CALL spdiscr_deriveSimpleDiscrSc (&
                 p_rvector%p_rblockDiscretisation%RspatialDiscretisation(1), &
                 EL_Q1_3D, CUB_G2_3D, &
                 rprjDiscretisation%RspatialDiscretisation(1))

    CALL spdiscr_deriveSimpleDiscrSc (&
                 p_rvector%p_rblockDiscretisation%RspatialDiscretisation(2), &
                 EL_Q1_3D, CUB_G2_3D, &
                 rprjDiscretisation%RspatialDiscretisation(2))
                 
    CALL spdiscr_deriveSimpleDiscrSc (&
                 p_rvector%p_rblockDiscretisation%RspatialDiscretisation(3), &
                 EL_Q1_3D, CUB_G2_3D, &
                 rprjDiscretisation%RspatialDiscretisation(3))

    ! The pressure discretisation substructure stays the old.
    !
    ! Now set up a new solution vector based on this discretisation,
    ! allocate memory.
    CALL lsysbl_createVecBlockByDiscr (rprjDiscretisation,rprjVector,.FALSE.)
    
    ! Then take our original solution vector and convert it according to the
    ! new discretisation:
    CALL spdp_projectSolution (p_rvector,rprjVector)
    
    ! Discretise the boundary conditions according to the Q1/Q1/Q0 
    ! discretisation:
    CALL c3d1_discretiseBC (rprjDiscretisation,rdiscreteBC)
                            
    ! Connect the vector to the BC's
    rprjVector%p_rdiscreteBC => rdiscreteBC
    
    ! Set up a boundary condition filter for Dirichlet boundary conditions
    ! and pass the vector through it. This finally implements the Dirichlet
    ! boundary conditions into the output vector.
    RfilterChain(1)%ifilterType = FILTER_DISCBCSOLREAL
    CALL filter_applyFilterChainVec (rprjVector, RfilterChain)
    
    ! Now we have a Q1/Q1/Q0 solution in rprjVector.
    !
    ! From the attached discretisation, get the underlying triangulation
    p_rtriangulation => &
      p_rvector%RvectorBlock(1)%p_rspatialDiscretisation%p_rtriangulation
    
    ! p_rvector now contains our solution. We can now
    ! start the postprocessing. 
    ! p_rvector now contains our solution. We can now
    ! start the postprocessing. 
    ! Start UCD export to GMV file:
    CALL ucd_startGMV (rexport,UCD_FLAG_STANDARD,p_rtriangulation,'gmv/u1.gmv')
    !CALL ucd_startVTK (rexport,UCD_FLAG_STANDARD,p_rtriangulation,'gmv/u1.vtk',&
    !                   UCD_PARAM_VTK_VECTOR_TO_SCALAR)
    
    ! Write velocity field
    CALL lsyssc_getbase_double (rprjVector%RvectorBlock(1),p_Ddata)
    CALL lsyssc_getbase_double (rprjVector%RvectorBlock(2),p_Ddata2)
    CALL lsyssc_getbase_double (rprjVector%RvectorBlock(3),p_Ddata3)
    
    CALL ucd_addVariableVertexBased (rexport,'X-vel',UCD_VAR_XVELOCITY, p_Ddata)
    CALL ucd_addVariableVertexBased (rexport,'Y-vel',UCD_VAR_YVELOCITY, p_Ddata2)
    CALL ucd_addVariableVertexBased (rexport,'Z-vel',UCD_VAR_ZVELOCITY, p_Ddata3)
    
    ! Write pressure
    CALL lsyssc_getbase_double (rprjVector%RvectorBlock(4),p_Ddata)
    CALL ucd_addVariableElementBased (rexport,'pressure',UCD_VAR_STANDARD, p_Ddata)
    
    ! Write the file to disc, that's it.
    CALL ucd_write (rexport)
    CALL ucd_release (rexport)
    
    ! Release the auxiliary vector
    CALL lsysbl_releaseVector (rprjVector)
    
    ! Release the discretisation structure.
    CALL spdiscr_releaseBlockDiscr (rprjDiscretisation)
    
    ! Throw away the discrete BC's - not used anymore.
    CALL bcasm_releaseDiscreteBC (rdiscreteBC)
    
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_doneMatVec (rproblem)
  
!<description>
  ! Releases system matrix and vectors.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

    INTEGER :: i

    ! Release matrices and vectors on all levels
    DO i=rproblem%NLMAX,rproblem%NLMIN,-1
      ! Delete the matrix
      CALL lsysbl_releaseMatrix (rproblem%p_RlevelInfo(i)%rmatrix)

      ! Delete the variables from the collection.
      CALL collct_deletevalue (rproblem%rcollection,'SYSTEMMAT',i)
      CALL collct_deletevalue (rproblem%rcollection,'LAPLACE',i)
      
      ! Release Laplace, B1 and B2 matrix
      CALL lsyssc_releaseMatrix (rproblem%p_RlevelInfo(i)%rmatrixB3)
      CALL lsyssc_releaseMatrix (rproblem%p_RlevelInfo(i)%rmatrixB2)
      CALL lsyssc_releaseMatrix (rproblem%p_RlevelInfo(i)%rmatrixB1)
      CALL lsyssc_releaseMatrix (rproblem%p_RlevelInfo(i)%rmatrixLaplace)
      
      ! Remove the temp vector that was used for interpolating the solution
      ! from higher to lower levels in the nonlinear iteration.
      IF (i .LT. rproblem%NLMAX) THEN
        CALL lsysbl_releaseVector(rproblem%p_RlevelInfo(i)%rtempVector)
        CALL collct_deletevalue(rproblem%rcollection,'RTEMPVEC',i)
      END IF
      
    END DO

    ! Delete solution/RHS vector
    CALL lsysbl_releaseVector (rproblem%rvector)
    CALL lsysbl_releaseVector (rproblem%rrhs)

    ! Delete the variables from the collection.
    CALL collct_deletevalue (rproblem%rcollection,'RHS')
    CALL collct_deletevalue (rproblem%rcollection,'SOLUTION')

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_doneBC (rproblem)
  
!<description>
  ! Releases discrete and analytic boundary conditions from the heap.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i

    DO i=rproblem%NLMAX,rproblem%NLMIN,-1
      ! Release our discrete version of the boundary conditions
      CALL bcasm_releaseDiscreteBC (rproblem%p_RlevelInfo(i)%rdiscreteBC)
    END DO
    
  END SUBROUTINE


  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_doneDiscretisation (rproblem)
  
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

    DO i=rproblem%NLMAX,rproblem%NLMIN,-1
      ! Remove the block discretisation structure and all the substructures.
      CALL spdiscr_releaseBlockDiscr(rproblem%p_RlevelInfo(i)%p_rdiscretisation)
      
      ! Remove the discretisation from the heap.
      DEALLOCATE(rproblem%p_RlevelInfo(i)%p_rdiscretisation)
    END DO
    
  END SUBROUTINE
    
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE c3d1_doneParamTriang (rproblem)
  
!<description>
  ! Releases the triangulation and parametrisation from the heap.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i

    ! Release the triangulation on all levels
    DO i=rproblem%NLMAX,rproblem%NLMIN,-1
      CALL tria_done (rproblem%p_RlevelInfo(i)%rtriangulation)
    END DO
    
    CALL collct_deleteValue(rproblem%rcollection,'NLMAX')
    CALL collct_deleteValue(rproblem%rcollection,'NLMIN')

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE cc3dmini1
  
!<description>
  ! This is a 'separated' Navier-Stokes solver for solving a Navier-Stokes
  ! problem. The different tasks of the problem are separated into
  ! subroutines. The problem uses a problem-specific structure for the 
  ! communication: All subroutines add their generated information to the
  ! structure, so that the other subroutines can work with them.
  ! (This is somehow a cleaner implementation than using a collection!).
  ! For the communication to callback routines of black-box subroutines
  ! (matrix-assembly), a collection is used.
  !
  ! The following tasks are performed by the subroutines:
  !
  ! 1.) Read in parametrisation
  ! 2.) Read in triangulation
  ! 3.) Set up RHS
  ! 4.) Set up matrix
  ! 5.) Create solver structure
  ! 6.) Solve the problem
  ! 7.) Write solution to GMV file
  ! 8.) Release all variables, finish
!</description>

!</subroutine>

    ! LV receives the level where we want to solve
    INTEGER :: NLMAX,NLMIN
    REAL(DP) :: dnu
    
    ! A problem structure for our problem
    TYPE(t_problem), POINTER :: p_rproblem
    
    INTEGER :: i
    
    ! Ok, let's start. 
    !
    ! Allocate the problem structure on the heap -- it's rather large.
    ALLOCATE(p_rproblem)
    
    ! NLMIN receives the minimal level where to discretise for supporting
    ! the solution process.
    ! NLMAX receives the level where we want to solve.
    NLMIN = 2
    NLMAX = 4
    
    ! Allocate the level structures
    ALLOCATE(p_rproblem%p_RlevelInfo(NLMIN:NLMAX))
    
    ! Viscosity parameter:
    dnu = 1.0_DP / 1000.0_DP
    
    p_rproblem%dnu = dnu
    
    ! Initialise the collection
    CALL collct_init (p_rproblem%rcollection)
    DO i=1,NLMAX
      CALL collct_addlevel_all (p_rproblem%rcollection)
    END DO

    ! Add the (global) viscosity parameter
    CALL collct_setvalue_real(p_rproblem%rcollection,'NU',dnu,.TRUE.)

    ! So now the different steps - one after the other.
    !
    ! Initialisation
    CALL c3d1_initParamTriang (NLMIN,NLMAX,p_rproblem)
    CALL c3d1_initDiscretisation (p_rproblem)    
    CALL c3d1_initMatVec (p_rproblem)    
    CALL c3d1_initDiscreteBC (p_rproblem)
    
    ! Implementation of boundary conditions
    CALL c3d1_implementBC (p_rproblem)
    
    ! Solve the problem
    CALL c3d1_solve (p_rproblem)
    
    ! Postprocessing
    CALL c3d1_postprocessing (p_rproblem)
    
    ! Cleanup
    CALL c3d1_doneMatVec (p_rproblem)
    CALL c3d1_doneBC (p_rproblem)
    CALL c3d1_doneDiscretisation (p_rproblem)
    CALL c3d1_doneParamTriang (p_rproblem)

    CALL collct_deletevalue(p_rproblem%rcollection,'NU')

    ! Print some statistical data about the collection - anything forgotten?
    PRINT *
    PRINT *,'Remaining collection statistics:'
    PRINT *,'--------------------------------'
    PRINT *
    CALL collct_printStatistics (p_rproblem%rcollection)
    
    ! Finally release the collection and the problem structure.
    CALL collct_done (p_rproblem%rcollection)
    
    ! Deallocate the level structures
    DEALLOCATE(p_rproblem%p_RlevelInfo)
    
    ! And deallocate the problem structure
    DEALLOCATE(p_rproblem)
    
  END SUBROUTINE

END MODULE
