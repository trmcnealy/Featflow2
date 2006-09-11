!##############################################################################
!# ****************************************************************************
!# <name> matrixfilters </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains a set of filters that can be applied to a scalar
!# or block matrix. They can be used e.g. to modify a matrix during a nonlinear
!# solution process to prepare it for a linear solver (like implementing
!# boundary conditions).
!#
!# Typical matrix filters are those working together with discrete
!# boundary conditions. For Dirichlet boundary conditions e.g. some lines
!# of the global matrix are usually replaced by unit vectors. The corresponding
!# matrix modification routine is a kind of 'filter' for a matrix and
!# can be found in this module.
!#
!# The following routines can be found here:
!#
!#  1.) matfil_discreteBC
!#      -> Apply the 'discrete boundary conditions for matrices' filter
!#         onto a given (block) matrix.
!#         This e.g. replaces lines of a matrix corresponding to Dirichlet DOF's
!#         by unit vectors for all scalar submatrices where configured.
!#
!#  2.) matfil_discreteFBC
!#      -> Apply the 'discrete fictitious boundary conditions for matr�ces'
!#         filter onto a given (block) matrix.
!#         This e.g. replaces lines of a matrix corresponding to Dirichlet DOF's
!#         by unit vectors for all scalar submatrices where configured.
!#
!#  3.) matfil_discreteNLSlipBC
!#      -> Implement slip boundary conditions into a matrix.
!#         Slip boundary conditions are not implemented by matfil_discreteBC!
!#         They must be implemented separately, as they are a special type
!#         of boundary conditions.
!#
!# </purpose>
!##############################################################################

MODULE matrixfilters

  USE fsystem
  USE linearsystemscalar
  USE linearsystemblock
  USE discretebc
  USE discretefbc
  USE dofmapping
  USE matrixmodification
  
  IMPLICIT NONE

CONTAINS

! *****************************************************************************
! Scalar matrix filters
! *****************************************************************************

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE matfil_imposeDirichletBC (rmatrix,boffDiag,rdbcStructure)
  
!<description>
  ! Implements discrete Dirichlet BC's into a scalar matrix.
  ! This is normally done by replacing some lines of the matrix rmatrix
  ! (those belonging to Dirichlet nodes) by unit vectors or by zero-vectors
  ! (depending on whether the matrix is a 'diagonal' matrix or an
  ! 'off-diagonal' matrix in a larger block-system).
!</description>

!<input>
  
  ! The t_discreteBCDirichlet that describes the discrete Dirichlet BC's
  TYPE(t_discreteBCDirichlet), INTENT(IN), TARGET  :: rdbcStructure
  
  ! Off-diagonal matrix.
  ! If this is present and set to TRUE, it's assumed that the matrix is not
  ! a main, guiding system matrix, but an 'off-diagonal' matrix in a
  ! system with block-matrices (e.g. a matrix at position (2,1), (3,1),...
  ! or somewhere else in a block system). This modifies the way,
  ! boundary conditions are implemented into the matrix.
  LOGICAL :: boffDiag

!</input>

!<inputoutput>

  ! The scalar matrix where the boundary conditions should be imposed.
  TYPE(t_matrixScalar), INTENT(INOUT), TARGET :: rmatrix
  
!</inputoutput>
  
!</subroutine>
    
  ! local variables
  INTEGER(I32), DIMENSION(:), POINTER :: p_idx
  INTEGER, PARAMETER :: NBLOCKSIZE = 1000
  INTEGER(PREC_VECIDX), DIMENSION(1000) :: Idofs
  INTEGER(PREC_VECIDX), DIMENSION(:), POINTER :: p_Iperm
  INTEGER i,ilenleft

  ! If nDOF=0, there are no DOF's the current boundary condition segment,
  ! so we don't have to do anything. Maybe the case if the user selected
  ! a boundary region that is just too small.
  IF (rdbcStructure%nDOF .EQ. 0) RETURN

  ! Get pointers to the structures. For the vector, get the pointer from
  ! the storage management.
  
  CALL storage_getbase_int(rdbcStructure%h_IdirichletDOFs,p_idx)

  ! Impose the DOF value directly into the vector - more precisely, into the
  ! components of the subvector that is indexed by icomponent.
  
  IF (.NOT.ASSOCIATED(p_idx)) THEN
    PRINT *,'Error: DBC not configured'
    STOP
  END IF
  
  ! Only handle nDOF DOF's, not the complete array!
  ! Probably, the array is longer (e.g. has the length of the vector), but
  ! contains only some entries...
  !
  ! Is the matrix sorted?
  IF (rmatrix%isortStrategy .LE. 0) THEN
    ! Use mmod_replaceLinesByUnit/mmod_replaceLinesByZero to replace the 
    ! corresponding rows in the matrix by unit vectors. 
    ! For more complicated FE spaces, this might have
    ! to be modified in the future...
    !
    ! We use mmod_replaceLinesByUnit for 'diagonal' matrix blocks (main
    ! system matrices) and mmod_replaceLinesByZero for 'off-diagonal'
    ! matrix blocks (in case of larger block systems)
    
    IF (boffDiag) THEN
      CALL mmod_replaceLinesByZero (rmatrix,p_idx(1:rdbcStructure%nDOF))
    ELSE
      CALL mmod_replaceLinesByUnit (rmatrix,p_idx(1:rdbcStructure%nDOF))
    END IF
  ELSE
    ! Ok, matrix is sorted, so we have to filter all the DOF's through the
    ! permutation before using them for implementing boundary conditions.
    ! We do this in blocks with 1000 DOF's each to prevent the stack
    ! from being destroyed!
    !
    ! Get the permutation from the matrix - or more precisely, the
    ! back-permutation, as we need this one for the loop below.
    CALL storage_getbase_int (rmatrix%h_IsortPermutation,p_Iperm)
    p_Iperm => p_Iperm(rmatrix%NEQ+1:)
    
    ! How many entries to handle in the first block?
    ilenleft = MIN(rdbcStructure%nDOF,NBLOCKSIZE)
    
    ! Loop through the DOF-blocks
    DO i=0,rdbcStructure%nDOF / NBLOCKSIZE
      ! Filter the DOF's through the permutation
      Idofs(1:ilenleft) = p_Iperm(p_idx(1+i*NBLOCKSIZE:i*NBLOCKSIZE+ilenleft))
      
      ! And implement the BC's with mmod_replaceLinesByUnit/
      ! mmod_replaceLinesByZero, depending on whether the matrix is a
      ! 'main' system matrix or an 'off-diagonal' system matrix in a larger
      ! block system.
      IF (boffDiag) THEN
        CALL mmod_replaceLinesByZero (rmatrix,Idofs(1:ilenleft))
      ELSE
        CALL mmod_replaceLinesByUnit (rmatrix,Idofs(1:ilenleft))
      END IF

      ! How many DOF's are left?
      ilenleft = MIN(rdbcStructure%nDOF-(i+1)*NBLOCKSIZE,NBLOCKSIZE)
    END DO
  
  END IF
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE matfil_imposeNLSlipBC (rmatrix,boffDiag,bforprec,rslipBCStructure)
  
!<description>
  ! Implements discrete Slip BC's into a scalar matrix.
  ! Slip BC's are treated like Dirichlet BC's.
  ! This is normally done by replacing some lines of the matrix rmatrix
  ! (those belonging to Dirichlet nodes) by unit vectors or by zero-vectors
  ! (depending on whether the matrix is a 'diagonal' matrix or an
  ! 'off-diagonal' matrix in a larger block-system).
!</description>

!<input>
  ! Prepare matrix for preconditioning.
  ! =false: Slip-nodes are handled as Dirichlet. Rows in the
  !         matrix are replaced by unit vectors.
  ! =true : Standard. Prepare matrix for preconditioning.
  !         Only the off-diagonals of rows corresponding to 
  !         the slip-nodes are cleared.
  !         The matrix therefore is prepared to act as 
  !         Jacobi-preconditioner for all slip-nodes.
  LOGICAL, INTENT(IN) :: bforprec
  
  ! The t_discreteBCSlip that describes the discrete Slip BC's
  TYPE(t_discreteBCSlip), INTENT(IN), TARGET  :: rslipBCStructure
  
  ! Off-diagonal matrix.
  ! If this is present and set to TRUE, it's assumed that the matrix is not
  ! a main, guiding system matrix, but an 'off-diagonal' matrix in a
  ! system with block-matrices (e.g. a matrix at position (2,1), (3,1),...
  ! or somewhere else in a block system). This modifies the way,
  ! boundary conditions are implemented into the matrix.
  LOGICAL, INTENT(IN) :: boffDiag
!</input>

!<inputoutput>

  ! The scalar matrix where the boundary conditions should be imposed.
  TYPE(t_matrixScalar), INTENT(INOUT), TARGET :: rmatrix
  
!</inputoutput>
  
!</subroutine>
    
  ! local variables
  INTEGER(I32), DIMENSION(:), POINTER :: p_idx
  INTEGER, PARAMETER :: NBLOCKSIZE = 1000
  INTEGER(PREC_VECIDX), DIMENSION(1000) :: Idofs
  INTEGER(PREC_VECIDX), DIMENSION(:), POINTER :: p_Iperm
  INTEGER i,ilenleft
  
  ! If nDOF=0, there are no DOF's the current boundary condition segment,
  ! so we don't have to do anything. Maybe the case if the user selected
  ! a boundary region that is just too small.
  IF (rslipBCStructure%nDOF .EQ. 0) RETURN

  ! Get pointers to the structures. For the vector, get the pointer from
  ! the storage management.
  
  CALL storage_getbase_int(rslipBCStructure%h_IslipDOFs,p_idx)

  ! Impose the DOF value directly into the vector - more precisely, into the
  ! components of the subvector that is indexed by icomponent.
  
  IF (.NOT.ASSOCIATED(p_idx)) THEN
    PRINT *,'Error: DBC not configured'
    STOP
  END IF
  
  ! Only handle nDOF DOF's, not the complete array!
  ! Probably, the array is longer (e.g. has the length of the vector), but
  ! contains only some entries...
  !
  ! Is the matrix sorted?
  IF (rmatrix%isortStrategy .LE. 0) THEN
    ! Use mmod_clearOffdiags/mmod_replaceLinesByZero clear the
    ! offdiagonals of the system matrix.
    ! For more complicated FE spaces, this might have
    ! to be modified in the future...
    !
    ! We use mmod_clearOffdiags for 'diagonal' matrix blocks (main
    ! system matrices) and mmod_replaceLinesByZero for 'off-diagonal'
    ! matrix blocks (in case of larger block systems)
    
    IF (boffDiag) THEN
      CALL mmod_replaceLinesByZero (rmatrix,p_idx(1:rslipBCStructure%nDOF))
    ELSE
      IF (bforprec) THEN
        CALL mmod_clearOffdiags (rmatrix,p_idx(1:rslipBCStructure%nDOF))
      ELSE
        CALL mmod_replaceLinesByUnit (rmatrix,p_idx(1:rslipBCStructure%nDOF))
      END IF
    END IF
  ELSE
    ! Ok, matrix is sorted, so we have to filter all the DOF's through the
    ! permutation before using them for implementing boundary conditions.
    ! We do this in blocks with 1000 DOF's each to prevent the stack
    ! from being destroyed!
    !
    ! Get the permutation from the matrix - or more precisely, the
    ! back-permutation, as we need this one for the loop below.
    CALL storage_getbase_int (rmatrix%h_IsortPermutation,p_Iperm)
    p_Iperm => p_Iperm(rmatrix%NEQ+1:)
    
    ! How many entries to handle in the first block?
    ilenleft = MIN(rslipBCStructure%nDOF,NBLOCKSIZE)
    
    ! Loop through the DOF-blocks
    DO i=0,rslipBCStructure%nDOF / NBLOCKSIZE
      ! Filter the DOF's through the permutation
      Idofs(1:ilenleft) = p_Iperm(p_idx(1+i*NBLOCKSIZE:i*NBLOCKSIZE+ilenleft))
      
      ! And implement the BC's with mmod_clearOffdiags/
      ! mmod_replaceLinesByZero, depending on whether the matrix is a
      ! 'main' system matrix or an 'off-diagonal' system matrix in a larger
      ! block system.
      IF (boffDiag) THEN
        CALL mmod_replaceLinesByZero (rmatrix,Idofs(1:ilenleft))
      ELSE
        IF (bforprec) THEN
          CALL mmod_clearOffdiags (rmatrix,Idofs(1:ilenleft))
        ELSE
          CALL mmod_replaceLinesByUnit (rmatrix,Idofs(1:ilenleft))
        END IF
      END IF
      
      ! How many DOF's are left?
      ilenleft = MIN(rslipBCStructure%nDOF-(i+1)*NBLOCKSIZE,NBLOCKSIZE)
    END DO
  
  END IF
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE matfil_imposeDirichletFBC (rmatrix,boffDiag,rdbcStructure)
  
!<description>
  ! Implements discrete Dirichlet BC's of fictitious boundary components
  ! into a scalar matrix.
  ! This is normally done by replacing some lines of the matrix rmatrix
  ! (those belonging to Dirichlet nodes) by unit vectors or by zero-vectors
  ! (depending on whether the matrix is a 'diagonal' matrix or an
  ! 'off-diagonal' matrix in a larger block-system).
!</description>

!<input>
  
  ! The t_discreteFBCDirichlet that describes the discrete Dirichlet BC's
  TYPE(t_discreteFBCDirichlet), INTENT(IN), TARGET  :: rdbcStructure
  
  ! Off-diagonal matrix.
  ! If this is present and set to TRUE, it's assumed that the matrix is not
  ! a main, guiding system matrix, but an 'off-diagonal' matrix in a
  ! system with block-matrices (e.g. a matrix at position (2,1), (3,1),...
  ! or somewhere else in a block system). This modifies the way,
  ! boundary conditions are implemented into the matrix.
  LOGICAL :: boffDiag

!</input>

!<inputoutput>

  ! The scalar matrix where the boundary conditions should be imposed.
  TYPE(t_matrixScalar), INTENT(INOUT), TARGET :: rmatrix
  
!</inputoutput>
  
!</subroutine>
    
  ! local variables
  INTEGER(I32), DIMENSION(:), POINTER :: p_idx
  INTEGER, PARAMETER :: NBLOCKSIZE = 1000
  INTEGER(PREC_VECIDX), DIMENSION(1000) :: Idofs
  INTEGER(PREC_VECIDX), DIMENSION(:), POINTER :: p_Iperm
  INTEGER i,ilenleft

  ! If nDOF=0, there are no DOF's the current boundary condition segment,
  ! so we don't have to do anything. Maybe the case if the user selected
  ! a boundary region that is just too small.
  IF (rdbcStructure%nDOF .EQ. 0) RETURN

  ! Get pointers to the structures. For the vector, get the pointer from
  ! the storage management.
  
  CALL storage_getbase_int(rdbcStructure%h_IdirichletDOFs,p_idx)

  ! Impose the DOF value directly into the vector - more precisely, into the
  ! components of the subvector that is indexed by icomponent.
  
  IF (.NOT.ASSOCIATED(p_idx)) THEN
    PRINT *,'Error: DBC not configured'
    STOP
  END IF
  
  ! Only handle nDOF DOF's, not the complete array!
  ! Probably, the array is longer (e.g. has the length of the vector), but
  ! contains only some entries...
  !
  ! Is the matrix sorted?
  IF (rmatrix%isortStrategy .LE. 0) THEN
    ! Use mmod_replaceLinesByUnit/mmod_replaceLinesByZero to replace the 
    ! corresponding rows in the matrix by unit vectors. 
    ! For more complicated FE spaces, this might have
    ! to be modified in the future...
    !
    ! We use mmod_replaceLinesByUnit for 'diagonal' matrix blocks (main
    ! system matrices) and mmod_replaceLinesByZero for 'off-diagonal'
    ! matrix blocks (in case of larger block systems)
    
    IF (boffDiag) THEN
      CALL mmod_replaceLinesByZero (rmatrix,p_idx(1:rdbcStructure%nDOF))
    ELSE
      CALL mmod_replaceLinesByUnit (rmatrix,p_idx(1:rdbcStructure%nDOF))
    END IF
  ELSE
    ! Ok, matrix is sorted, so we have to filter all the DOF's through the
    ! permutation before using them for implementing boundary conditions.
    ! We do this in blocks with 1000 DOF's each to prevent the stack
    ! from being destroyed!
    !
    ! Get the permutation from the matrix - or more precisely, the
    ! back-permutation, as we need this one for the loop below.
    CALL storage_getbase_int (rmatrix%h_IsortPermutation,p_Iperm)
    p_Iperm => p_Iperm(rmatrix%NEQ+1:)
    
    ! How many entries to handle in the first block?
    ilenleft = MIN(rdbcStructure%nDOF,NBLOCKSIZE)
    
    ! Loop through the DOF-blocks
    DO i=0,rdbcStructure%nDOF / NBLOCKSIZE
      ! Filter the DOF's through the permutation
      Idofs(1:ilenleft) = p_Iperm(p_idx(1+i*NBLOCKSIZE:i*NBLOCKSIZE+ilenleft))
      
      ! And implement the BC's with mmod_replaceLinesByUnit/
      ! mmod_replaceLinesByZero, depending on whether the matrix is a
      ! 'main' system matrix or an 'off-diagonal' system matrix in a larger
      ! block system.
      IF (boffDiag) THEN
        CALL mmod_replaceLinesByZero (rmatrix,Idofs(1:ilenleft))
      ELSE
        CALL mmod_replaceLinesByUnit (rmatrix,Idofs(1:ilenleft))
      END IF
    END DO
  
  END IF
  
  END SUBROUTINE
  
! ***************************************************************************
! Block matrix filters
! ***************************************************************************

  ! *************************************************************************
  ! Implementation of discrete boundary conditions into block matrices
  ! *************************************************************************

!<subroutine>

  SUBROUTINE matfil_discreteBC (rmatrix,rdiscreteBC)

!<description>
  ! This routine realises the 'impose discrete boundary conditions to 
  ! block matrix' filter.
  ! The matrix is modified either to rdiscreteBC (if specified) or
  ! to the default boundary conditions associated to the matrix 
  ! (if rdiscreteBC is not specified).
!</description>

!<input>
  ! OPTIONAL: boundary conditions to impose into the matrix.
  ! If not specified, the default boundary conditions associated to the
  ! matrix rmatrix are imposed to the matrix.
  TYPE(t_discreteBC), OPTIONAL, INTENT(IN), TARGET :: rdiscreteBC
!</input>
  
!<inputoutput>
  ! The block matrix where the boundary conditions should be imposed.
  TYPE(t_matrixBlock), INTENT(INOUT),TARGET :: rmatrix
!</inputoutput>

!</subroutine>

    INTEGER :: iblock,jblock,i,icp
    TYPE(t_discreteBCEntry), DIMENSION(:), POINTER :: p_RdiscreteBC
    
    ! Imposing boundary conditions normally changes the whole matrix!
    ! Grab the boundary condition entry list from the matrix. This
    ! is a list of all discretised boundary conditions in the system.
    p_RdiscreteBC => rmatrix%p_rdiscreteBC%p_RdiscBCList  
    
    IF (.NOT. ASSOCIATED(p_RdiscreteBC)) RETURN
    
    ! Now loop through all entries in this list:
    DO i=1,SIZE(p_RdiscreteBC)
    
      ! What for BC's do we have here?
      SELECT CASE (p_RdiscreteBC(i)%itype)
      CASE (DISCBC_TPUNDEFINED)
        ! Do-nothing
        
      CASE (DISCBC_TPDIRICHLET)
        ! Dirichlet boundary conditions.
        ! On which component are they defined? The component specifies
        ! the row of the block matrix that is to be altered.
        iblock = p_RdiscreteBC(i)%rdirichletBCs%icomponent
        
        ! Loop through this matrix row and implement the boundary conditions
        ! into the scalar submatrices.
        ! For now, this implements unit vectors into the diagonal matrices
        ! and zero-vectors into the offdiagonal matrices.
        DO jblock = 1,rmatrix%ndiagBlocks
          IF (rmatrix%RmatrixBlock(iblock,jblock)%NEQ .NE. 0) THEN
            CALL matfil_imposeDirichletBC (&
                        rmatrix%RmatrixBlock(iblock,jblock), &
                        iblock .NE. jblock,p_RdiscreteBC(i)%rdirichletBCs)
          END IF
        END DO
        
      CASE (DISCBC_TPPRESSUREDROP)  
        ! Nothing to do; pressure drop BC's are implemented only into the RHS.

      CASE (DISCBC_TPSLIP)  
        ! Slip boundary conditions are treated like Dirichlet for all
        ! velocity components.
        ! This is a separate filter must be called manually.
        ! Therefore, there's nothing to do here.
        
      CASE DEFAULT
        PRINT *,'matfil_discreteBC: unknown boundary condition: ',&
                p_RdiscreteBC(i)%itype
        STOP
        
      END SELECT
    END DO
  
  END SUBROUTINE

  ! *************************************************************************

!<subroutine>

  SUBROUTINE matfil_discreteNLSlipBC (rmatrix,bforprec,rdiscreteBC)

!<description>
  ! Imposes nonlinear slip boundary conditions into a given matrix.
  ! The matrix is modified either to rdiscreteBC (if specified) or
  ! to the default boundary conditions associated to the matrix 
  ! (if rdiscreteBC is not specified).
  !
  ! Note that slip boundary conditions are implemented by so called
  ! 'nonlinear filters' (c.f. vectorfilters.f). Similarly to the vector
  ! filters, slip boundary conditions are not automatically implemented
  ! by matfil_discreteBC. To implement them, this routine must be called
  ! separately from matfil_discreteBC.
!</description>

!<input>
  ! Prepare matrix for preconditioning.
  ! =false: Slip-nodes are handled as Dirichlet. Rows in the
  !         matrix are replaced by unit vectors.
  ! =true : Standard. Prepare matrix for preconditioning.
  !         Only the off-diagonals of rows corresponding to 
  !         the slip-nodes are cleared.
  !         The matrix therefore is prepared to act as 
  !         Jacobi-preconditioner for all slip-nodes.
  LOGICAL, INTENT(IN) :: bforprec

  ! OPTIONAL: boundary conditions to impose into the matrix.
  ! If not specified, the default boundary conditions associated to the
  ! matrix rmatrix are imposed to the matrix.
  TYPE(t_discreteBC), OPTIONAL, INTENT(IN), TARGET :: rdiscreteBC
!</input>
  
!<inputoutput>
  ! The block matrix where the boundary conditions should be imposed.
  TYPE(t_matrixBlock), INTENT(INOUT),TARGET :: rmatrix
!</inputoutput>

!</subroutine>

    INTEGER :: iblock,jblock,i,icp
    TYPE(t_discreteBCEntry), DIMENSION(:), POINTER :: p_RdiscreteBC
    
    ! Imposing boundary conditions normally changes the whole matrix!
    ! Grab the boundary condition entry list from the matrix. This
    ! is a list of all discretised boundary conditions in the system.
    p_RdiscreteBC => rmatrix%p_rdiscreteBC%p_RdiscBCList  
    
    IF (.NOT. ASSOCIATED(p_RdiscreteBC)) RETURN
    
    ! Now loop through all entries in this list:
    DO i=1,SIZE(p_RdiscreteBC)
    
      ! Only implement slip boundary conditions.
      IF (p_RdiscreteBC(i)%itype .EQ. DISCBC_TPSLIP) THEN
        ! Slip boundary conditions are treated like Dirichlet for all
        ! velocity components.

        ! Loop through all affected components to implement the BC's.
        DO icp = 1,p_RdiscreteBC(i)%rslipBCs%ncomponents
          iblock = p_RdiscreteBC(i)%rslipBCs%Icomponents(icp)

          DO jblock = 1,rmatrix%ndiagBlocks
            IF (rmatrix%RmatrixBlock(iblock,jblock)%NEQ .NE. 0) THEN
              CALL matfil_imposeNLSlipBC (&
                          rmatrix%RmatrixBlock(iblock,jblock), &
                          iblock .NE. jblock,bforprec,&
                          p_RdiscreteBC(i)%rslipBCs)
            END IF
          END DO
          
        END DO
      END IF
    
    END DO
  
  END SUBROUTINE

  ! ***************************************************************************
  ! Implementation of discrete fictitious boundary conditions into 
  ! block matrices
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE matfil_discreteFBC (rmatrix,rdiscreteFBC)

!<description>
  ! This routine realises the 'impose discrete fictitious boundary 
  ! conditions to block matrix' filter.
  ! The matrix is modified either to rdiscreteFBC (if specified) or
  ! to the default boundary conditions associated to the matrix 
  ! (if rdiscreteFBC is not specified).
!</description>

!<input>
  ! OPTIONAL: boundary conditions to impose into the matrix.
  ! If not specified, the default boundary conditions associated to the
  ! matrix rmatrix are imposed to the matrix.
  TYPE(t_discreteFBC), OPTIONAL, INTENT(IN), TARGET :: rdiscreteFBC
!</input>
  
!<inputoutput>
  ! The block matrix where the boundary conditions should be imposed.
  TYPE(t_matrixBlock), INTENT(INOUT),TARGET :: rmatrix
!</inputoutput>

!</subroutine>

    INTEGER :: iblock,jblock,i,j
    TYPE(t_discreteFBCEntry), DIMENSION(:), POINTER :: p_RdiscreteFBC
    
    ! Imposing boundary conditions normally changes the whole matrix!
    ! Grab the boundary condition entry list from the matrix. This
    ! is a list of all discretised boundary conditions in the system.
    p_RdiscreteFBC => rmatrix%p_rdiscreteBCfict%p_RdiscFBCList  
    
    IF (.NOT. ASSOCIATED(p_RdiscreteFBC)) RETURN
    
    ! Now loop through all entries in this list:
    DO i=1,SIZE(p_RdiscreteFBC)
    
      ! What for BC's do we have here?
      SELECT CASE (p_RdiscreteFBC(i)%itype)
      CASE (DISCFBC_TPUNDEFINED)
        ! Do-nothing
        
      CASE (DISCFBC_TPDIRICHLET)
        ! Dirichlet boundary conditions.
        ! 
        ! Loop through all blocks where to impose the BC's:
        DO j=1,p_RdiscreteFBC(i)%rdirichletFBCs%ncomponents
        
          iblock = p_RdiscreteFBC(i)%rdirichletFBCs%Icomponents(j)
        
          ! Loop through this matrix row and implement the boundary conditions
          ! into the scalar submatrices.
          ! For now, this implements unit vectors into the diagonal matrices
          ! and zero-vectors into the offdiagonal matrices.
          DO jblock = 1,rmatrix%ndiagBlocks
            IF (rmatrix%RmatrixBlock(iblock,jblock)%NEQ .NE. 0) THEN
              CALL matfil_imposeDirichletFBC (&
                          rmatrix%RmatrixBlock(iblock,jblock), &
                          iblock .NE. jblock,p_RdiscreteFBC(i)%rdirichletFBCs)
            END IF
          END DO
          
        END DO
        
      CASE DEFAULT
        PRINT *,'matfil_discreteFBC: unknown boundary condition: ',&
                p_RdiscreteFBC(i)%itype
        STOP
        
      END SELECT
    END DO
  
  END SUBROUTINE

END MODULE
