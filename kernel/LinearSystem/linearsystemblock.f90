!##############################################################################
!# ****************************************************************************
!# <name> linearsystemblock </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains the basic definitions and routines to maintain block
!# matrices and block vectors. A block matrix is realised as 2D-array of
!# scalar matrices, while a block vector is realised as 1D-array of
!# scalar vectors.
!#
!# The following routines can be found here:
!#
!#  1.) lsysbl_createVecBlockDirect
!#      -> Create a block vector by specifying the size of the subblocks
!# 
!#  2.) lsysbl_createVecBlockIndirect
!#      -> Create a block vector by copying the structure of another block
!#         vector
!#
!#  3.) lsysbl_createVecBlockByDiscr
!#      -> Create a block vector using a block discretisation structure
!#
!#  4.) lsysbl_createVecBlockIndMat
!#      -> Create a block vector according to a block matrix.
!#
!#  5.) lsysbl_createMatFromScalar
!#      -> Create a 1x1 block matrix from a scalar matrix
!#
!#  6.) lsysbl_createVecFromScalar
!#      -> Create a 1-block vector from a scalar vector
!#
!#  7.) lsysbl_createMatBlockByDiscr
!#      -> Create an empty block matrix using a block discretisation structure
!#
!#  8.) lsysbl_createEmptyMatrix
!#      -> Creates an empty block matrix
!#
!#  9.) lsysbl_duplicateMatrix
!#      -> Duplicates a block matrix by duplicating all sub-matrices
!#
!# 10.) lsysbl_duplicateVector
!#      -> Duplicates a block vector by duplicating all sub-vectors
!#
!# 10.) lsysbl_enforceStructure
!#      -> Enforces the structure of a given block vector in another
!#         block vector
!#
!#      lsysbl_enforceStructureDirect
!#      -> Enforces a subvector structure according to a length definition
!#         to a block vector
!#
!# 11.) lsysbl_assignDiscretIndirect
!#      -> Assign discretisation related information of one vector
!#         to another
!#
!# 12.) lsysbl_assignDiscretIndirectMat
!#      -> Assign discretisation related information of a matrix
!#         to a vector to make it compatible.
!#
!# 13.) lsysbl_updateMatStrucInfo
!#      -> Recalculate structural data of a block matrix from
!#         the submatrices
!#
!# 14.) lsysbl_releaseVector
!#      -> Release a block vector from memory
!#
!# 15.) lsysbl_releaseMatrix
!#      -> Releases a block matrix and all submatrices
!#
!# 16.) lsysbl_releaseMatrixRow
!#      -> Releases a row of submatrices from a block matrix
!#
!# 17.) lsysbl_releaseMatrixColumn
!#      -> Releases a column of submatrices from a block matrix
!#
!# 18.) lsysbl_blockMatVec
!#      -> Multiply a block matrix with a block vector
!#
!# 19.) lsysbl_copyVector
!#       -> Copy a block vector over to another one
!#
!# 20.) lsysbl_scaleVector
!#      -> Scale a block vector by a constant
!#
!# 21.) lsysbl_clearVector
!#      -> Clear a block vector
!#
!# 22.) lsysbl_vectorLinearComb
!#      -> Linear combination of two block vectors
!#
!# 23.) lsysbl_scalarProduct
!#      -> Calculate a scalar product of two vectors
!#
!# 24.) lsysbl_setSortStrategy
!#      -> Assigns a sorting strategy/permutation to every subvector
!#
!# 25.) lsysbl_sortVectorInSitu
!#      -> Resort the entries of all subvectors according to an assigned
!#         sorting strategy
!#
!# 26.) lsysbl_isVectorCompatible
!#      -> Checks whether two vectors are compatible to each other
!#
!# 27.) lsysbl_isMatrixCompatible
!#      -> Checks whether a matrix and a vector are compatible to each other
!#
!# 28.) lsysbl_isMatrixSorted
!#      -> Checks if a block matrix is sorted
!#
!# 29.) lsysbl_isVectorSorted
!#      -> Checks if a block vector is sorted
!#
!# 30.) lsysbl_getbase_double
!#      -> Get a pointer to the double precision data array of the vector
!#
!# 31.) lsysbl_getbase_single
!#      -> Get a pointer to the single precision data array of the vector
!#
!# 32.) lsysbl_vectorNorm
!#      -> Calculates the norm of a vector. the vector is treated as one
!#         long data array.
!#
!# 33.) lsysbl_vectorNormBlock
!#      -> Calculates the norm of all subvectors in a given block vector.
!#
!# 34.) lsysbl_invertedDiagMatVec
!#      -> Multiply a vector with the inverse of the diagonal of a matrix
!#
!# 35.) lsysbl_swapVectors
!#      -> Swap two vectors
!#
!# 36.) lsysbl_deriveSubvector
!#      -> Derives a blockvector as a subset of another blockvector
!#
!# 37.) lsysbl_deriveSubmatrix
!#      -> Extracts a submatrix from a block matrix
!#
!# 38.) lsysbl_isSubmatrixPresent
!#      -> Checks if a submatrix of a blockmatrix is present
!#
!# 39.) lsysbl_resizeVectorBlock
!#      -> Resize a block vector
!#
!# 40.) lsysbl_resizeVecBlockIndMat
!#      -> Resize a block vector according to a block matrix
!#
!# 41.) lsysbl_infoVector
!#      -> Outputs information about the vector (mostly used for debugging)
!#
!# 42.) lsysbl_infoMatrix
!#      -> Outputs information about the matrix (mostly used for debugging)
!# </purpose>
!##############################################################################

MODULE linearsystemblock

  USE fsystem
  USE storage
  USE spatialdiscretisation
  USE linearsystemscalar
  USE linearalgebra
  USE dofmapping
  USE discretebc
  USE discretefbc
  
  IMPLICIT NONE

!<constants>

!<constantblock description="Flags for the matrix specification bitfield">

  ! Standard matrix
  INTEGER(I32), PARAMETER :: LSYSBS_MSPEC_GENERAL           =        0
  
  ! Block matrix is a scalar (i.e. 1x1) matrix.
  INTEGER(I32), PARAMETER :: LSYSBS_MSPEC_SCALAR            =        1

  ! Block matrix is of saddle-point type:
  !  (A  B1)
  !  (B2 0 )
  INTEGER(I32), PARAMETER :: LSYSBS_MSPEC_SADDLEPOINT       =        2

  ! Block matrix is nearly of saddle-point type 
  !  (A  B1)
  !  (B2 C )
  ! with C~0 being a stabilisation matrix
  INTEGER(I32), PARAMETER :: LSYSBS_MSPEC_NEARLYSADDLEPOINT =        3

  ! The block matrix is a submatrix of another block matrix and not
  ! located at the diagonal of its parent. 
  ! This e.g. modifies the way, boundary conditions are implemented
  ! into a matrix; see in the boundary condition implementation
  ! routines for details.
  INTEGER(I32), PARAMETER :: LSYSBS_MSPEC_OFFDIAGSUBMATRIX  =        4

!</constantblock>

!</constants>

!<types>
  
!<typeblock>
  
  ! A block vector that can be used by block linear algebra routines.
  
  TYPE t_vectorBlock
    
    ! Total number of equations in the vector
    INTEGER(PREC_DOFIDX)       :: NEQ = 0
    
    ! Handle identifying the vector entries or = ST_NOHANDLE if not
    ! allocated.
    INTEGER                    :: h_Ddata = ST_NOHANDLE
    
    ! Start position of the vector data in the array identified by
    ! h_Ddata. Normally = 1. Can be set to > 1 if the vector is a subvector
    ! in a larger memory block allocated on the heap.
    INTEGER(PREC_VECIDX)       :: iidxFirstEntry = 1

    ! Data type of the entries in the vector. Either ST_SINGLE or
    ! ST_DOUBLE. The subvectors are all of the same type.
    INTEGER                    :: cdataType = ST_DOUBLE

    ! Is set to true, if the handle h_Ddata belongs to another vector,
    ! i.e. when this vector shares data with another vector.
    LOGICAL                    :: bisCopy   = .FALSE.

    ! Number of blocks allocated in RvectorBlock
    INTEGER                    :: nblocks = 0
    
    ! Pointer to a block discretisation structure that specifies
    ! the discretisation of all the subblocks in the vector.
    ! Points to NULL(), if there is no underlying block discretisation
    ! structure.
    TYPE(t_blockDiscretisation), POINTER :: p_rblockDiscretisation

    ! A pointer to discretised boundary conditions for real boundary components.
    ! These boundary conditions allow to couple multiple equations in the 
    ! system and don't belong only to one single scalar component of the
    ! solution.
    ! If no system-wide boundary conditions are specified, p_rdiscreteBC
    ! can be set to NULL().
    TYPE(t_discreteBC), POINTER  :: p_rdiscreteBC => NULL()
    
    ! A pointer to discretised boundary conditions for fictitious boundary
    ! components.
    ! These boundary conditions allow to couple multiple equations in the 
    ! system and don't belong only to one single scalar component of the
    ! solution.
    ! If no system-wide boundary conditions are specified, p_rdiscreteBCfict
    ! can be set to NULL().
    TYPE(t_discreteFBC), POINTER  :: p_rdiscreteBCfict => NULL()
    
    ! A 1D array with scalar vectors for all the blocks.
    ! The handle identifier inside of these blocks are set to h_Ddata.
    ! The iidxFirstEntry index pointer in each subblock is set according
    ! to the position inside of the large vector.
    TYPE(t_vectorScalar), DIMENSION(:), POINTER :: RvectorBlock => NULL()
    
  END TYPE
  
!</typeblock>

!<typeblock>
  
  ! A block matrix that can be used by scalar linear algebra routines.
  ! Note that a block matrix is always quadratic with ndiagBlocks
  ! block rows and ndiagBlock block columns!
  ! If necessary, the corresponding block rows/columns are filled
  ! up with zero matrices!
  
  TYPE t_matrixBlock
    
    ! Total number of equations = rows in the whole matrix.
    ! This usually coincides with NCOLS. NCOLS > NEQ indicates, that 
    ! at least one block row in the block matrix is completely zero.
    INTEGER(PREC_DOFIDX)       :: NEQ         = 0

    ! Total number of columns in the whole matrix.
    ! This usually coincides with NEQ. NCOLS < NEQ indicates, that
    ! at least one block column in the block matrix is completely zero.
    INTEGER(PREC_DOFIDX)       :: NCOLS       = 0
    
    ! Number of diagonal blocks in the matrix.
    INTEGER                    :: ndiagBlocks = 0

    ! Matrix specification tag. This is a bitfield coming from an OR 
    ! combination of different LSYSBS_MSPEC_xxxx constants and specifies
    ! various details of the matrix. If it is =LSYSBS_MSPEC_GENERAL,
    ! the matrix is a usual matrix that needs no special handling.
    INTEGER(I32) :: imatrixSpec = LSYSBS_MSPEC_GENERAL
    
    ! Pointer to a block discretisation structure that specifies
    ! the discretisation of all the subblocks in the vector.
    ! Points to NULL(), if there is no underlying block discretisation
    ! structure.
    TYPE(t_blockDiscretisation), POINTER :: p_rblockDiscretisation

    ! A pointer to discretised boundary conditions for real boundary 
    ! components. If no boundary conditions are specified, p_rdiscreteBC
    ! can be set to NULL().
    TYPE(t_discreteBC), POINTER  :: p_rdiscreteBC => NULL()
    
    ! A pointer to discretised boundary conditions for fictitious boundary
    ! components. If no fictitious boundary conditions are specified, 
    ! p_rdiscreteBCfict can be set to NULL().
    TYPE(t_discreteFBC), POINTER  :: p_rdiscreteBCfict => NULL()
    
    ! A 2D array with scalar matrices for all the blocks.
    ! A submatrix is assumed to be empty (zero-block) if the corresponding
    ! NEQ=NCOLS=0.
    TYPE(t_matrixScalar), DIMENSION(:,:), POINTER :: RmatrixBlock => NULL()
    
  END TYPE
  
!</typeblock>

!</types>

  INTERFACE lsysbl_createVectorBlock
    MODULE PROCEDURE lsysbl_createVecBlockDirect 
    MODULE PROCEDURE lsysbl_createVecBlockDirectDims
    MODULE PROCEDURE lsysbl_createVecBlockIndirect 
    MODULE PROCEDURE lsysbl_createVecBlockByDiscr
  END INTERFACE

  INTERFACE lsysbl_resizeVectorBlock
    MODULE PROCEDURE lsysbl_resizeVecBlockDirect
    MODULE PROCEDURE lsysbl_resizeVecBlockDirectDims
    MODULE PROCEDURE lsysbl_resizeVecBlockIndirect
  END INTERFACE

CONTAINS

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_isVectorCompatible (rvector1,rvector2,bcompatible)
  
!<description>
  ! Checks whether two vectors are compatible to each other.
  ! Two vectors are compatible if
  ! - they have the same size,
  ! - they have the same structure of subvectors,
  ! - they have the same sorting strategy OR they are both unsorted
!</description>

!<input>
  ! The first vector
  TYPE(t_vectorBlock), INTENT(IN) :: rvector1
  
  ! The second vector
  TYPE(t_vectorBlock), INTENT(IN) :: rvector2
!</input>

!<output>
  ! OPTIONAL: If given, the flag will be set to TRUE or FALSE depending on
  ! whether the vectors are compatible or not.
  ! If not given, an error will inform the user if the two vectors are
  ! not compatible and the program will halt.
  LOGICAL, INTENT(OUT), OPTIONAL :: bcompatible
!</output>

!</subroutine>

  ! local variables
  INTEGER :: i

  ! We assume that we are not compatible
  IF (PRESENT(bcompatible)) bcompatible = .FALSE.
  
  ! Vectors must have the same size and number of blocks
  IF (rvector1%NEQ .NE. rvector2%NEQ) THEN
    IF (PRESENT(bcompatible)) THEN
      bcompatible = .FALSE.
      RETURN
    ELSE
      PRINT *,'Vectors not compatible, different size!'
      STOP
    END IF
  END IF

  IF (rvector1%nblocks .NE. rvector2%nblocks) THEN
    IF (PRESENT(bcompatible)) THEN
      bcompatible = .FALSE.
      RETURN
    ELSE
      PRINT *,'Vectors not compatible, different block structure!'
      STOP
    END IF
  END IF
  
  ! All the subblocks must be the same size and must be sorted the same way.
  DO i=1,rvector1%nblocks
    IF (rvector1%RvectorBlock(i)%NEQ .NE. rvector2%RvectorBlock(i)%NEQ) THEN
      IF (PRESENT(bcompatible)) THEN
        bcompatible = .FALSE.
        RETURN
      ELSE
        PRINT *,'Vectors not compatible, different block structure!'
        STOP
      END IF
    END IF
    
    ! isortStrategy < 0 means unsorted. Both unsorted is ok.
    
    IF ((rvector1%RvectorBlock(i)%isortStrategy .GT. 0) .OR. &
        (rvector2%RvectorBlock(i)%isortStrategy .GT. 0)) THEN

      IF (rvector1%RvectorBlock(i)%isortStrategy .NE. &
          rvector2%RvectorBlock(i)%isortStrategy) THEN
        IF (PRESENT(bcompatible)) THEN
          bcompatible = .FALSE.
          RETURN
        ELSE
          PRINT *,'Vectors not compatible, differently sorted!'
          STOP
        END IF
      END IF

      IF (rvector1%RvectorBlock(i)%h_isortPermutation .NE. &
          rvector2%RvectorBlock(i)%h_isortPermutation) THEN
        IF (PRESENT(bcompatible)) THEN
          bcompatible = .FALSE.
          RETURN
        ELSE
          PRINT *,'Vectors not compatible, differently sorted!'
          STOP
        END IF
      END IF
    END IF
  END DO

  ! Ok, they are compatible
  IF (PRESENT(bcompatible)) bcompatible = .TRUE.

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_isMatrixCompatible (rvector,rmatrix,bcompatible)
  
!<description>
  ! Checks whether a vector and a matrix are compatible to each other.
  ! A vector and a matrix are compatible if
  ! - they have the same NEQ,
  ! - they have the same structure of subvectors and diagonal blocks,
  ! - they have the same sorting strategy OR they are both unsorted
  ! Currently disabled checks:
  ! - they have the same spatial discretisation,
  ! - they have the same boundary conditions.
!</description>

!<input>
  ! The vector
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
  
  ! The matrix
  TYPE(t_matrixBlock), INTENT(IN) :: rmatrix
!</input>

!<output>
  ! OPTIONAL: If given, the flag will be set to TRUE or FALSE depending on
  ! whether vector and matrix are compatible or not.
  ! If not given, an error will inform the user if the vector/matrix are
  ! not compatible and the program will halt.
  LOGICAL, INTENT(OUT), OPTIONAL :: bcompatible
!</output>

!</subroutine>

  ! local variables
  INTEGER :: i,j
  !LOGICAL :: b1,b2,b3

  ! We assume that we are not compatible
  IF (PRESENT(bcompatible)) bcompatible = .FALSE.
  
  ! Vector/Matrix must have the same size and number of blocks and equations
  IF (rvector%NEQ .NE. rmatrix%NEQ) THEN
    IF (PRESENT(bcompatible)) THEN
      bcompatible = .FALSE.
      RETURN
    ELSE
      PRINT *,'Vector/Matrix not compatible, different size!'
      STOP
    END IF
  END IF

  IF (rvector%nblocks .NE. rmatrix%ndiagBlocks) THEN
    IF (PRESENT(bcompatible)) THEN
      bcompatible = .FALSE.
      RETURN
    ELSE
      PRINT *,'Vector/Matrix not compatible, different block structure!'
      STOP
    END IF
  END IF
  
!  ! Vector and matrix must share the same BC's.
!  b1 = ASSOCIATED(rvector%p_rdiscreteBC)
!  b2 = ASSOCIATED(rmatrix%p_rdiscreteBC)
!  b3 = ASSOCIATED(rvector%p_rdiscreteBC,rmatrix%p_rdiscreteBC)
!  IF ((b1 .OR. b2) .AND. .NOT. (b1 .AND. b2 .AND. b3)) THEN
!    IF (PRESENT(bcompatible)) THEN
!      bcompatible = .FALSE.
!      RETURN
!    ELSE
!      PRINT *,'Vector/Matrix not compatible, different boundary conditions!'
!      STOP
!    END IF
!  END IF
!
!  b1 = ASSOCIATED(rvector%p_rdiscreteBCfict)
!  b2 = ASSOCIATED(rmatrix%p_rdiscreteBCfict)
!  b3 = ASSOCIATED(rvector%p_rdiscreteBCfict,rmatrix%p_rdiscreteBCfict)
!  IF ((b1 .OR. b2) .AND. .NOT. (b1 .AND. b2 .AND. b3)) THEN
!    IF (PRESENT(bcompatible)) THEN
!      bcompatible = .FALSE.
!      RETURN
!    ELSE
!      PRINT *,'Vector/Matrix not compatible, different fict. boundary conditions!'
!      STOP
!    END IF
!  END IF
  
  ! All the subblocks must be the same size and must be sorted the same way.
  ! Each subvector corresponds to one 'column' in the block matrix.
  !
  ! Loop through all columns (!) of the matrix
  DO j=1,rvector%nblocks
  
    ! Loop through all rows of the matrix
    DO i=1,rvector%nblocks
    
      IF (rmatrix%RmatrixBlock(i,j)%NEQ .NE. 0) THEN

!        b1 = ASSOCIATED(rvector%RvectorBlock(i)%p_rspatialDiscretisation)
!        b2 = ASSOCIATED(rmatrix%RmatrixBlock(i,j)%p_rspatialDiscretisation)
!        b3 = ASSOCIATED(rvector%RvectorBlock(i)%p_rspatialDiscretisation, &
!                        rmatrix%RmatrixBlock(i,j)%p_rspatialDiscretisation)
!        IF ((b1 .OR. b2) .AND. .NOT. (b1 .AND. b2 .AND. b3)) THEN
!          IF (PRESENT(bcompatible)) THEN
!            bcompatible = .FALSE.
!            RETURN
!          ELSE
!            PRINT *,'Vector/Matrix not compatible, different discretisation!'
!            STOP
!          END IF
!        END IF

        IF (rvector%RvectorBlock(j)%NEQ .NE. rmatrix%RmatrixBlock(i,j)%NCOLS) THEN
          IF (PRESENT(bcompatible)) THEN
            bcompatible = .FALSE.
            RETURN
          ELSE
            PRINT *,'Vector/Matrix not compatible, different block structure!'
            STOP
          END IF
        END IF

        ! isortStrategy < 0 means unsorted. Both unsorted is ok.

        IF ((rvector%RvectorBlock(j)%isortStrategy .GT. 0) .OR. &
            (rmatrix%RmatrixBlock(i,j)%isortStrategy .GT. 0)) THEN

          IF (rvector%RvectorBlock(j)%isortStrategy .NE. &
              rmatrix%RmatrixBlock(i,j)%isortStrategy) THEN
            IF (PRESENT(bcompatible)) THEN
              bcompatible = .FALSE.
              RETURN
            ELSE
              PRINT *,'Vector/Matrix not compatible, differently sorted!'
              STOP
            END IF
          END IF

          IF (rvector%RvectorBlock(j)%h_isortPermutation .NE. &
              rmatrix%RmatrixBlock(i,j)%h_isortPermutation) THEN
            IF (PRESENT(bcompatible)) THEN
              bcompatible = .FALSE.
              RETURN
            ELSE
              PRINT *,'Vector/Matrix not compatible, differently sorted!'
              STOP
            END IF
          END IF
        END IF
      
      END IF
      
    END DO
  END DO

  ! Ok, they are compatible
  IF (PRESENT(bcompatible)) bcompatible = .TRUE.

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_getbase_double (rvector,p_Ddata)
  
!<description>
  ! Returns a pointer to the double precision data array of the vector.
  ! An error is thrown if the vector is not double precision.
!</description>

!<input>
  ! The vector
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
!</input>

!<output>
  ! Pointer to the double precision data array of the vector.
  ! NULL() if the vector has no data array.
  REAL(DP), DIMENSION(:), POINTER :: p_Ddata
!</output>

!</subroutine>

  ! Do we have data at all?
 IF ((rvector%NEQ .EQ. 0) .OR. (rvector%h_Ddata .EQ. ST_NOHANDLE)) THEN
   NULLIFY(p_Ddata)
   RETURN
 END IF

  ! Check that the vector is really double precision
  IF (rvector%cdataType .NE. ST_DOUBLE) THEN
    PRINT *,'lsysbl_getbase_double: Vector is of wrong precision!'
    STOP
  END IF

  ! Get the data array
  CALL storage_getbase_double (rvector%h_Ddata,p_Ddata)

  ! Modify the starting address/length to get the real array.
  p_Ddata => p_Ddata(rvector%iidxFirstEntry:rvector%iidxFirstEntry+rvector%NEQ-1)

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_getbase_single (rvector,p_Fdata)
  
!<description>
  ! Returns a pointer to the single precision data array of the vector.
  ! An error is thrown if the vector is not single precision.
!</description>

!<input>
  ! The vector
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
!</input>

!<output>
  ! Pointer to the double precision data array of the vector.
  ! NULL() if the vector has no data array.
  REAL(SP), DIMENSION(:), POINTER :: p_Fdata
!</output>

!</subroutine>

  ! Do we have data at all?
 IF ((rvector%NEQ .EQ. 0) .OR. (rvector%h_Ddata .EQ. ST_NOHANDLE)) THEN
   NULLIFY(p_Fdata)
   RETURN
 END IF

  ! Check that the vector is really double precision
  IF (rvector%cdataType .NE. ST_SINGLE) THEN
    PRINT *,'lsysbl_getbase_single: Vector is of wrong precision!'
    STOP
  END IF

  ! Get the data array
  CALL storage_getbase_single (rvector%h_Ddata,p_Fdata)
  
  ! Modify the starting address/length to get the real array.
  p_Fdata => p_Fdata(rvector%iidxFirstEntry:rvector%iidxFirstEntry+rvector%NEQ-1)
  
  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_getbase_int (rvector,p_Idata)
  
!<description>
  ! Returns a pointer to the integer data array of the vector.
  ! An error is thrown if the vector is not integer.
!</description>

!<input>
  ! The vector
  TYPE(t_vectorBlock), INTENT(IN) :: rvector
!</input>

!<output>
  ! Pointer to the integer data array of the vector.
  ! NULL() if the vector has no data array.
  INTEGER, DIMENSION(:), POINTER :: p_Idata
!</output>

!</subroutine>

  ! Do we have data at all?
 IF ((rvector%NEQ .EQ. 0) .OR. (rvector%h_Ddata .EQ. ST_NOHANDLE)) THEN
   NULLIFY(p_Idata)
   RETURN
 END IF

  ! Check that the vector is really integer
  IF (rvector%cdataType .NE. ST_INT) THEN
    PRINT *,'lsysbl_getbase_int: Vector is of wrong precision!'
    STOP
  END IF

  ! Get the data array
  CALL storage_getbase_int (rvector%h_Ddata,p_Idata)
  
  ! Modify the starting address/length to get the real array.
  p_Idata => p_Idata(rvector%iidxFirstEntry:rvector%iidxFirstEntry+rvector%NEQ-1)
  
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_createVecBlockDirect (rx, Isize, bclear, cdataType)
  
!<description>
  ! Initialises the vector block structure rx. Isize is an array
  ! of integers containing the length of the individual blocks.
  ! Memory is allocated on the heap to hold vectors of the size
  ! according to Isize.
  !
  ! Remark: There is no block discretisation structure attached to the vector!
!</description>

!<input>
  ! An array with length-tags for the different blocks
  INTEGER(PREC_VECIDX), DIMENSION(:), INTENT(IN) :: Isize
  
  ! Optional: If set to YES, the vector will be filled with zero initially.
  LOGICAL, INTENT(IN), OPTIONAL             :: bclear
  
  ! OPTIONAL: Data type identifier for the entries in the vector. 
  ! Either ST_SINGLE or ST_DOUBLE. If not present, ST_DOUBLE is assumed.
  INTEGER, INTENT(IN),OPTIONAL              :: cdataType
!</input>

!<output>
  
  ! Destination structure. Memory is allocated for each of the blocks.
  TYPE(t_vectorBlock),INTENT(OUT) :: rx
  
!</output>
  
!</subroutine>

  ! local variables
  INTEGER :: i,n
  INTEGER :: cdata
  
  cdata = ST_DOUBLE
  IF (PRESENT(cdataType)) cdata = cdataType
  
  ! rx is initialised by INTENT(OUT) with the most common data.
  ! What is missing is the data array.
  !
  ! Allocate one large vector holding all data.
  CALL storage_new1D ('lsysbl_createVecBlockDirect', 'Vector', SUM(Isize), cdata, &
                      rx%h_Ddata, ST_NEWBLOCK_NOINIT)
  rx%cdataType = cdata
  
  ! Initialise the sub-blocks. Save a pointer to the starting address of
  ! each sub-block.
  ! Denote in the subvector that the handle belongs to us - not to
  ! the subvector.
  ALLOCATE(rx%RvectorBlock(SIZE(Isize)))
  
  n=1
  DO i = 1,SIZE(Isize)
    IF (Isize(i) .GT. 0) THEN
      rx%RvectorBlock(i)%NEQ = Isize(i)
      rx%RvectorBlock(i)%iidxFirstEntry = n
      rx%RvectorBlock(i)%h_Ddata = rx%h_Ddata
      rx%RvectorBlock(i)%cdataType = rx%cdataType
      rx%RvectorBlock(i)%bisCopy = .TRUE.
      n = n+Isize(i)
    ELSE
      rx%RvectorBlock(i)%NEQ = 0
      rx%RvectorBlock(i)%iidxFirstEntry = 0
      rx%RvectorBlock(i)%h_Ddata = ST_NOHANDLE
    END IF
  END DO
  
  rx%NEQ = n-1
  rx%nblocks = SIZE(Isize)
  
  ! The data of the vector belongs to us (we created the handle), 
  ! not to somebody else.
  rx%bisCopy = .FALSE.
  
  ! Warning: don't reformulate the following check into one IF command
  ! as this might give problems with some compilers!
  IF (PRESENT(bclear)) THEN
    IF (bclear) THEN
      CALL lsysbl_clearVector (rx)
    END IF
  END IF
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_createVecBlockDirectDims (rx, isize, iblocks, bclear, cdataType)
  
!<description>
  ! Initialises the vector block structure rx. Isize is an integer
  ! which describes the length of each block. Iblocks denotes the
  ! number of similar vector blocks.
  ! Memory is allocated on the heap to hold vectors of the size
  ! according to Isize.
  !
  ! Remark: There is no block discretisation structure attached to the vector!
!</description>

!<input>
  ! An integer describing the length of each block
  INTEGER(PREC_VECIDX), INTENT(IN) :: isize

  ! An integer describing the number of vector blocks
  INTEGER, INTENT(IN) :: iblocks
  
  ! Optional: If set to YES, the vector will be filled with zero initially.
  LOGICAL, INTENT(IN), OPTIONAL             :: bclear
  
  ! OPTIONAL: Data type identifier for the entries in the vector. 
  ! Either ST_SINGLE or ST_DOUBLE. If not present, ST_DOUBLE is assumed.
  INTEGER, INTENT(IN),OPTIONAL              :: cdataType
!</input>

!<output>
  
  ! Destination structure. Memory is allocated for each of the blocks.
  TYPE(t_vectorBlock),INTENT(OUT) :: rx
  
!</output>
  
!</subroutine>

  ! local variables
  INTEGER :: i,n
  INTEGER :: cdata
  
  cdata = ST_DOUBLE
  IF (PRESENT(cdataType)) cdata = cdataType
  
  ! rx is initialised by INTENT(OUT) with the most common data.
  ! What is missing is the data array.
  !
  ! Allocate one large vector holding all data.
  CALL storage_new1D ('lsysbl_createVecBlockDirect', 'Vector', &
                      INT(isize*iblocks,I32), cdata, &
                      rx%h_Ddata, ST_NEWBLOCK_NOINIT)
  rx%cdataType = cdata
  
  ! Initialise the sub-blocks. Save a pointer to the starting address of
  ! each sub-block.
  ! Denote in the subvector that the handle belongs to us - not to
  ! the subvector.
  ALLOCATE(rx%RvectorBlock(iblocks))
  
  n=1
  DO i = 1,iblocks
    IF (isize .GT. 0) THEN
      rx%RvectorBlock(i)%NEQ = isize
      rx%RvectorBlock(i)%iidxFirstEntry = n
      rx%RvectorBlock(i)%h_Ddata = rx%h_Ddata
      rx%RvectorBlock(i)%cdataType = rx%cdataType
      rx%RvectorBlock(i)%bisCopy = .TRUE.
      rx%RvectorBlock(i)%cdataType = cdata
      n = n+isize
    ELSE
      rx%RvectorBlock(i)%NEQ = 0
      rx%RvectorBlock(i)%iidxFirstEntry = 0
      rx%RvectorBlock(i)%h_Ddata = ST_NOHANDLE
    END IF
  END DO
  
  rx%NEQ = n-1
  rx%nblocks = iblocks
  
  ! The data of the vector belongs to us (we created the handle), 
  ! not to somebody else.
  rx%bisCopy = .FALSE.
  
  ! Warning: don't reformulate the following check into one IF command
  ! as this might give problems with some compilers!
  IF (PRESENT(bclear)) THEN
    IF (bclear) THEN
      CALL lsysbl_clearVector (rx)
    END IF
  END IF
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_createVecBlockIndirect (rtemplate,rx,bclear,cdataType)
  
!<description>
  ! Initialises the vector block structure rx. rtemplate is an
  ! existing block vector structure.
  ! Memory is allocated on the heap for rx, the different components
  ! of rx will have the same size as the corresponding ones in rtemplate.
!</description>
  
!<input>
  ! A template vector structure
  TYPE(t_vectorBlock),INTENT(IN) :: rtemplate
  
  ! Optional: If set to YES, the vector will be filled with zero initially.
  ! Otherwise the content of rx is undefined.
  LOGICAL, INTENT(IN), OPTIONAL             :: bclear
  
  ! OPTIONAL: Data type identifier for the entries in the vector. 
  ! Either ST_SINGLE or ST_DOUBLE. If not present, the new vector will
  ! receive the same data type as rtemplate.
  INTEGER, INTENT(IN),OPTIONAL              :: cdataType
!</input>

!<output>
  
  ! Destination structure. Memory is allocated for each of the blocks.
  TYPE(t_vectorBlock),INTENT(OUT) :: rx
  
!</output>
  
!</subroutine>

  INTEGER :: cdata,i
  INTEGER(PREC_VECIDX) :: n
  
  cdata = rtemplate%cdataType
  IF (PRESENT(cdataType)) cdata = cdataType

  ! Copy the vector structure with all pointers.
  ! The handle identifying the vector data on the heap will be overwritten later.
  rx = rtemplate
  NULLIFY(rx%RvectorBlock)
  
  ! Check if number of diagonal blocks is nonzero, otherwise exit
  IF (rx%nblocks <= 0) RETURN
  ALLOCATE(rx%RvectorBlock(rx%nblocks))
  rx%RvectorBlock = rtemplate%RvectorBlock
  
  ! Allocate one large new vector holding all data.
  CALL storage_new1D ('lsysbl_createVecBlockDirect', 'Vector', rtemplate%NEQ, cdata, &
                      rx%h_Ddata, ST_NEWBLOCK_NOINIT)
  rx%cdataType = cdata
  
  ! As we have a new handle, reset the starting index of the vector
  ! in the array back to 1. This is necessary, as "rx = rtemplate" copied
  ! the of index from rtemplate to rx.
  rx%iidxFirstEntry = 1
  
  WHERE (rtemplate%RvectorBlock%h_Ddata .NE. ST_NOHANDLE)
    ! Initialise the data type
    rx%RvectorBlock%cdataType = cdata
                     
    ! Put the new handle to all subvectors
    rx%RvectorBlock(:)%h_Ddata = rx%h_Ddata
  
    ! Note in the subvectors, that the handle belongs to somewhere else... to us!
    rx%RvectorBlock%bisCopy = .TRUE.
  END WHERE
  
  ! Relocate the starting indices of the subvector.
  n = 1
  DO i=1,rx%nblocks
    rx%RvectorBlock(i)%iidxFirstEntry = n
    n = n + rx%RvectorBlock(i)%NEQ
  END DO
  
  ! Our handle belongs to us, so it's not a copy of another vector.
  rx%bisCopy = .FALSE.

  ! Warning: don't reformulate the following check into one IF command
  ! as this might give problems with some compilers!
  IF (PRESENT(bclear)) THEN
    IF (bclear) THEN
      CALL lsysbl_clearVector (rx)
    END IF
  END IF
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_createVecBlockByDiscr (rblockDiscretisation,rx,bclear,&
                                           cdataType)
  
!<description>
  ! Initialises the vector block structure rx based on a block discretisation
  ! structure rblockDiscretisation. 
  !
  ! Memory is allocated on the heap for rx. The size of the subvectors in rx
  ! is calculated according to the number of DOF's indicated by the
  ! spatial discretisation structures in rblockDiscretisation.
!</description>
  
!<input>
  ! A block discretisation structure specifying the spatial discretisations
  ! for all the subblocks in rx.
  TYPE(t_blockDiscretisation),INTENT(IN), TARGET :: rblockDiscretisation
  
  ! Optional: If set to YES, the vector will be filled with zero initially.
  ! Otherwise the content of rx is undefined.
  LOGICAL, INTENT(IN), OPTIONAL             :: bclear
  
  ! OPTIONAL: Data type identifier for the entries in the vector. 
  ! Either ST_SINGLE or ST_DOUBLE. If not present, ST_DOUBLE is used.
  INTEGER, INTENT(IN),OPTIONAL              :: cdataType
!</input>

!<output>
  ! Destination structure. Memory is allocated for each of the blocks.
  ! A pointer to rblockDiscretisation is saved to rx.
  TYPE(t_vectorBlock),INTENT(OUT) :: rx
!</output>
  
!</subroutine>

  INTEGER :: cdata,i,inum
  INTEGER(PREC_VECIDX), DIMENSION(SPDISC_MAXEQUATIONS) :: Isize
  
  cdata = ST_DOUBLE
  IF (PRESENT(cdataType)) cdata = cdataType
  
  ! Loop to the blocks in the block discretisation. Calculate size (#DOF's)
  ! of all the subblocks.
  DO i=1,rblockDiscretisation%ncomponents
    Isize(i) = dof_igetNDofGlob(rblockDiscretisation%RspatialDiscretisation(i))
  END DO
  inum = MIN(SPDISC_MAXEQUATIONS,rblockDiscretisation%ncomponents)
  
  ! Create a new vector with that block structure
  CALL lsysbl_createVecBlockDirect (rx, Isize(1:inum), bclear, cdataType)
  
  ! Initialise further data of the block vector
  rx%p_rblockDiscretisation => rblockDiscretisation
  
  ! Initialise further data in the subblocks
  DO i=1,inum
    rx%RvectorBlock(i)%p_rspatialDiscretisation => &
      rblockDiscretisation%RspatialDiscretisation(i)
  END DO

  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_createMatBlockByDiscr (rblockDiscretisation,rmatrix)
  
!<description>
  ! Initialises the matrix block structure rmatrix based on a block 
  ! discretisation structure rblockDiscretisation. 
  !
  ! The basic variables of the structure are initialised (number of blocks,
  ! pointer to the block discretisation). The submatrices of the matrix
  ! are not initialised; this must be done by the application afterwards.
!</description>
  
!<input>
  ! A block discretisation structure specifying the spatial discretisations
  ! for all the subblocks in rx.
  TYPE(t_blockDiscretisation),INTENT(IN), TARGET :: rblockDiscretisation
!</input>

!<output>
  ! Destination structure. Memory is allocated for each of the blocks.
  ! A pointer to rblockDiscretisation is saved to rx.
  TYPE(t_matrixBlock),INTENT(OUT) :: rmatrix
!</output>
  
!</subroutine>

  INTEGER :: i,inum
  INTEGER(PREC_VECIDX) :: NEQ
  INTEGER(PREC_VECIDX), DIMENSION(SPDISC_MAXEQUATIONS) :: Isize
  
  ! Loop to the blocks in the block discretisation. Calculate size (#DOF's)
  ! of all the subblocks.
  DO i=1,rblockDiscretisation%ncomponents
    Isize(i) = dof_igetNDofGlob(rblockDiscretisation%RspatialDiscretisation(i))
  END DO
  inum = MIN(SPDISC_MAXEQUATIONS,rblockDiscretisation%ncomponents)
  NEQ = SUM(Isize(1:inum))
  
  ! The 'INTENT(OUT)' already initialised the structure with the most common
  ! values. What is still missing, we now initialise:
  
  ! Initialise a pointer to the block discretisation
  rmatrix%p_rblockDiscretisation => rblockDiscretisation
  
  ! Initialise NEQ/NCOLS by default for a quadrativ matrix
  rmatrix%NEQ = NEQ
  rmatrix%NCOLS = NEQ
  rmatrix%ndiagBlocks = rblockDiscretisation%ncomponents
  
  ! Check if number of diagonal blocks is nonzeri, otherwise exit
  IF (rmatrix%ndiagblocks <= 0) RETURN
  ALLOCATE(rmatrix%RmatrixBlock(rmatrix%ndiagBlocks,rmatrix%ndiagBlocks))
  
  IF (rmatrix%ndiagBlocks .EQ. 1) THEN
    rmatrix%imatrixSpec = LSYSBS_MSPEC_SCALAR
  END IF
  
  END SUBROUTINE
  
  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_createEmptyMatrix (rmatrix,nblocks)
  
!<description>
  ! Creates a basic (nblocks x nblocks) block matrix. Reserves memory for
  ! all the submatrices but does not initialise any submatrix.
  !
  ! This routine can be used to create a totally empty matrix without any
  ! discretisation structure in the background.
  !
  ! The caller can manually fill in scalar matrices in rmatrix%RmatrixBlock
  ! as necessary. Afterwards, lsysbl_updateMatrixStruc can be used to
  ! calculate the actual matrix dimensions (NEQ,NCOLS,...).
!</description>

!<input>
  ! Number of diagonal blocks in the matrix
  INTEGER, INTENT(IN) :: nblocks
!</input>

!<output>
  ! Block matrix structure to be initialised.
  TYPE(t_matrixBlock), INTENT(OUT) :: rmatrix
!</output>

!</subroutine>
  
    ! Check if number of giagonal blocks is nonzero, otherwise exit
    IF (nblocks <= 0) RETURN

    ! Allocate memory for the blocks, that's it.
    ALLOCATE(rmatrix%RmatrixBlock(nblocks,nblocks))
    rmatrix%ndiagBlocks = nblocks

    IF (rmatrix%ndiagBlocks .EQ. 1) THEN
      rmatrix%imatrixSpec = LSYSBS_MSPEC_SCALAR
    END IF

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_createVecBlockIndMat (rtemplateMat,rx, bclear, cdataType)
  
!<description>
  ! Initialises the vector block structure rx. rtemplateMat is an
  ! existing block matrix structure. The vector rx will be created
  ! according to the size of the blocks of the submatrices.
  !
  ! Memory is allocated on the heap for rx. The different components
  ! of rx will have the same size as the corresponding column
  ! blocks in rtemplateMat.
  ! The sorting strategies of the subvectors are initialised
  ! with the sorting strategies of the column blocks of rtemplateMat.
!</description>
  
!<input>
  ! A template vector structure
  TYPE(t_matrixBlock), INTENT(IN) :: rtemplateMat
  
  ! OPTIONAL: If set to TRUE, the vector will be filled with zero initially.
  ! Otherwise the content of rx is undefined.
  LOGICAL, INTENT(IN), OPTIONAL   :: bclear
  
  ! OPTIONAL: Data type identifier for the entries in the vector. 
  ! Either ST_SINGLE or ST_DOUBLE. If not present, ST_DOUBLE is assumed.
  INTEGER, INTENT(IN),OPTIONAL              :: cdataType
!</input>

!<output>
  ! Destination structure. Memory is allocated for each of the blocks.
  TYPE(t_vectorBlock),INTENT(OUT) :: rx
!</output>
  
!</subroutine>

  ! local variables
  INTEGER :: i,n,j
  INTEGER :: cdata
  
  cdata = ST_DOUBLE
  IF (PRESENT(cdataType)) cdata = cdataType
  
  ! Allocate one large vector holding all data.
  CALL storage_new1D ('lsysbl_createVecBlockDirect', 'Vector', &
                      rtemplateMat%NCOLS, &
                      cdata, rx%h_Ddata, ST_NEWBLOCK_NOINIT)
  
  ! Check if number of diagonal bocks is nonzero, otherwise exit
  IF (rtemplateMat%ndiagBlocks <= 0) RETURN

  ! Initialise the sub-blocks. Save a pointer to the starting address of
  ! each sub-block.
  ALLOCATE(rx%RvectorBlock(rtemplateMat%ndiagBlocks))
  
  n=1
  DO i = 1,rtemplateMat%ndiagBlocks
    ! Search for the first matrix in column i of the block matrix -
    ! this will give us information about the vector. Note that the
    ! diagonal blocks does not necessarily have to exist!
    DO j=1,rtemplateMat%ndiagBlocks
    
      ! Check if the matrix is not empty
      IF (rtemplateMat%RmatrixBlock(j,i)%NCOLS .GT. 0) THEN
        
        ! Found a template matrix we can use :-)
        rx%RvectorBlock(i)%NEQ = rtemplateMat%RmatrixBlock(j,i)%NCOLS
        
        ! Take the handle of the complete-solution vector, but set the index of
        ! the first entry to a value >= 1 - so that it points to the first
        ! entry in the global solution vector!
        rx%RvectorBlock(i)%h_Ddata = rx%h_Ddata
        rx%RvectorBlock(i)%iidxFirstEntry = n
        
        ! Give the vector the discretisation of the matrix
        rx%RvectorBlock(i)%p_rspatialDiscretisation => &
          rtemplateMat%RmatrixBlock(j,i)%p_rspatialDiscretisation
          
        ! Give the vector the same sorting strategy as the matrix, so that
        ! the matrix and vector get compatible. Otherwise, things
        ! like matrix vector multiplication won't work...
        rx%RvectorBlock(i)%isortStrategy = &
          rtemplateMat%RmatrixBlock(j,i)%isortStrategy
        rx%RvectorBlock(i)%h_IsortPermutation = &
          rtemplateMat%RmatrixBlock(j,i)%h_IsortPermutation
        
        ! Denote in the subvector that the handle belongs to us - not to
        ! the subvector.
        rx%RvectorBlock(i)%bisCopy = .TRUE.
        
        ! Set the data type
        rx%RvectorBlock(i)%cdataType = cdata
        
        n = n+rtemplateMat%RmatrixBlock(j,i)%NCOLS
        
        ! Finish this loop, continue with the next column
        EXIT
        
      END IF
      
    END DO
    
    IF (j .GT. rtemplateMat%ndiagBlocks) THEN
      ! Let's hope this situation (an empty equation) never occurs - 
      ! might produce some errors elsewhere :)
      rx%RvectorBlock(i)%NEQ = 0
      rx%RvectorBlock(i)%iidxFirstEntry = 0
    END IF
    
  END DO
  
  rx%NEQ = rtemplateMat%NCOLS
  rx%nblocks = rtemplateMat%ndiagBlocks
  rx%cdataType = cdata

  ! Transfer the boundary conditions and block discretisation pointers
  ! from the matrix to the vector.
  rx%p_rblockDiscretisation => rtemplateMat%p_rblockDiscretisation
  rx%p_rdiscreteBC     => rtemplateMat%p_rdiscreteBC
  rx%p_rdiscreteBCfict => rtemplateMat%p_rdiscreteBCfict
  
  ! Warning: don't reformulate the following check into one IF command
  ! as this might give problems with some compilers!
  IF (PRESENT(bclear)) THEN
    IF (bclear) THEN
      CALL lsysbl_clearVector (rx)
    END IF
  END IF

  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_assignDiscretIndirect (rtemplate,rx)
  
!<description>
  ! Assigns discretisation-related information (spatial discretisation, 
  ! boundary conditions,...) to rx. The vector rtemplate is used as a
  ! template, so at the end of the routine, rx and rtemplate share the
  ! same discretisation.
!</description>
  
!<input>
  ! A template vector structure
  TYPE(t_vectorBlock),INTENT(IN) :: rtemplate
!</input>

!<inputoutput>
  ! Destination structure. Discretisation-related information of rtemplate
  ! is assigned to rx.
  TYPE(t_vectorBlock),INTENT(INOUT) :: rx
!</inputoutput>
  
!</subroutine>

  ! local variables
  INTEGER :: i

  ! Simply modify all pointers of all subvectors, that's it.
  DO i=1,rx%nblocks
    ! Spatial discretisation
    rx%RvectorBlock(i)%p_rspatialDiscretisation => &
      rtemplate%RvectorBlock(i)%p_rspatialDiscretisation 
  END DO
  
  ! Transfer the boundary conditions and block discretisation pointers
  ! from the template to the vector.
  rx%p_rblockDiscretisation => rtemplate%p_rblockDiscretisation
  rx%p_rdiscreteBC     => rtemplate%p_rdiscreteBC
  rx%p_rdiscreteBCfict => rtemplate%p_rdiscreteBCfict
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_assignDiscretIndirectMat (rtemplateMat,rx)
  
!<description>
  ! Assigns discretisation-related information (spatial discretisation, 
  ! boundary conditions,...) of a matrix to rx. The matrix rtemplateMat is 
  ! used as a template, so at the end of the routine, rx and rtemplate 
  ! share the same discretisation and boundary conditions.
  ! (More precisely, the blocks in rx and the diagonal blocks of
  !  rtemplateMat!)
  !
  ! In case the vector is completely incompatiblew to the matrix
  ! (different number of blocks, different NEQ), an error is thrown.
!</description>
  
!<input>
  ! A template vector structure
  TYPE(t_matrixBlock),INTENT(IN) :: rtemplateMat
!</input>

!<inputoutput>
  ! Destination structure. Discretisation-related information of rtemplate
  ! is assigned to rx.
  TYPE(t_vectorBlock),INTENT(INOUT) :: rx
!</inputoutput>
  
!</subroutine>

  ! local variables
  INTEGER :: i,j

  ! There must be at least some compatibility between the matrix
  ! and the vector!
  IF ((rtemplateMat%NEQ .NE. rx%NEQ) .OR. &
      (rtemplateMat%ndiagBlocks .NE. rx%nblocks)) THEN
    PRINT *,'lsysbl_assignDiscretIndirectMat error: Matrix/Vector incompatible!'
    STOP
  END IF

  ! Simply modify all pointers of all subvectors, that's it.
  DO i=1,rx%nblocks
    DO j=1,rx%nblocks
      ! Search for the first matrix in the 'column' of the block matrix and use
      ! its properties to initialise
      IF (rtemplateMat%RmatrixBlock(j,i)%NEQ .NE. 0) THEN
        ! Spatial discretisation
        rx%RvectorBlock(i)%p_rspatialDiscretisation => &
          rtemplateMat%RmatrixBlock(j,i)%p_rspatialDiscretisation 
        EXIT
      END IF
    END DO
  END DO
  
  ! Transfer the boundary conditions and block discretisation pointers
  ! from the matrix to the vector.
  rx%p_rblockDiscretisation => rtemplateMat%p_rblockDiscretisation
  rx%p_rdiscreteBC     => rtemplateMat%p_rdiscreteBC
  rx%p_rdiscreteBCfict => rtemplateMat%p_rdiscreteBCfict

  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_releaseVector (rx)
  
!<description>
  ! Releases the memory that is reserved by rx.
  ! Remark: The memory associated to the vector is only released if this
  !  vector structure is the owner of the data.
!</description>
  
!<inputoutput>
  
  ! Vector structure that is to be released.
  TYPE(t_vectorBlock),INTENT(INOUT) :: rx
  
!</inputoutput>
  
!</subroutine>

  ! local variables
  INTEGER :: i
  
  IF (rx%h_Ddata .EQ. ST_NOHANDLE) THEN
    PRINT *,'lsysbl_releaseVector warning: releasing unused vector.'
  END IF
  
  ! Release the data - if the handle is not a copy of another vector!
  IF ((.NOT. rx%bisCopy) .AND. (rx%h_Ddata .NE. ST_NOHANDLE)) THEN
    CALL storage_free (rx%h_Ddata)
  ELSE
    rx%h_Ddata = ST_NOHANDLE
  END IF
  
  ! Clean up the structure
  DO i = 1,rx%nblocks
    CALL lsyssc_releaseVector (rx%RvectorBlock(i))
  END DO
  rx%NEQ = 0
  rx%nblocks = 0
  rx%iidxFirstEntry = 1
  
  NULLIFY(rx%p_rblockDiscretisation)
  NULLIFY(rx%p_rdiscreteBC)
  NULLIFY(rx%p_rdiscreteBCfict)
  IF (ASSOCIATED(rx%RvectorBlock)) DEALLOCATE(rx%RvectorBlock)
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>
  
  SUBROUTINE lsysbl_releaseMatrix (rmatrix)
 
!<description>
  ! Releases the memory that is reserved by rmatrix (including all submatrices).
!</description>
  
!<inputoutput>
  ! Block matrix to be released
  TYPE(t_matrixBlock), INTENT(INOUT)                :: rMatrix
!</inputoutput>

!</subroutine>
  
  ! local variables
  INTEGER :: x,y
  
  ! loop through all the submatrices and release them
  DO x=1,rmatrix%ndiagBlocks
    DO y=1,rmatrix%ndiagBlocks
      
      ! Only release the matrix if there is one.
      IF (rmatrix%RmatrixBlock(y,x)%NA .NE. 0) THEN
        CALL lsyssc_releaseMatrix (rmatrix%RmatrixBlock(y,x))
      END IF
      
    END DO
  END DO
  
  ! Clean up the other variables, finish
  rmatrix%NEQ = 0
  rmatrix%ndiagBlocks = 0
  
  NULLIFY(rmatrix%p_rblockDiscretisation)
  NULLIFY(rmatrix%p_rdiscreteBC)
  NULLIFY(rmatrix%p_rdiscreteBCfict)
  IF (ASSOCIATED(rmatrix%RmatrixBlock)) DEALLOCATE(rmatrix%RmatrixBlock)
  
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>
  
  SUBROUTINE lsysbl_releaseMatrixRow (rmatrix,irow)
 
!<description>
  ! Releases all submatrices in row irow from the block matrix rmatrix.
!</description>
  
!<input>
  ! Matrix row which should be released.
  INTEGER, INTENT(IN)                               :: irow
!</input>
  
!<inputoutput>
  ! Block matrix to be released (partially)
  TYPE(t_matrixBlock), INTENT(INOUT)                :: rMatrix
!</inputoutput>

!</subroutine>
  
  ! local variables
  INTEGER :: x
  
  ! loop through all the submatrices in row irow and release them
  DO x=1,rmatrix%ndiagBlocks
    ! Only release the matrix if there is one.
    IF (rmatrix%RmatrixBlock(irow,x)%NA .NE. 0) THEN
      CALL lsyssc_releaseMatrix (rmatrix%RmatrixBlock(irow,x))
    END IF
  END DO
  
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>
  
  SUBROUTINE lsysbl_releaseMatrixColumn (rmatrix,icolumn)
 
!<description>
  ! Releases all submatrices in column icolumn from the block matrix rmatrix.
!</description>
  
!<input>
  ! Matrix column which should be released.
  INTEGER, INTENT(IN)                               :: icolumn
!</input>
  
!<inputoutput>
  ! Block matrix to be released (partially)
  TYPE(t_matrixBlock), INTENT(INOUT)                :: rMatrix
!</inputoutput>

!</subroutine>
  
  ! local variables
  INTEGER :: y
  
  ! loop through all the submatrices in row irow and release them
  DO y=1,rmatrix%ndiagBlocks
    ! Only release the matrix if there is one.
    IF (rmatrix%RmatrixBlock(y,icolumn)%NA .NE. 0) THEN
      CALL lsyssc_releaseMatrix (rmatrix%RmatrixBlock(y,icolumn))
    END IF
  END DO
  
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>
  
  SUBROUTINE lsysbl_blockMatVec (rmatrix, rx, ry, cx, cy)
 
!<description>
  ! Performs a matrix vector multiplicationwith a given scalar matrix:
  !    $$ Dy   =   cx * rMatrix * rx   +   cy * ry $$
  ! Vector and matrix must be compatible to each other (same size, sorting 
  ! strategy,...).
!</description>
  
!<input>
  
  ! Block matrix
  TYPE(t_matrixBlock), INTENT(IN)                   :: rmatrix

  ! Block vector to multiply with the matrix.
  TYPE(t_vectorBlock), INTENT(IN)                   :: rx
  
  ! Multiplicative factor for rx
  REAL(DP), INTENT(IN)                              :: cx

  ! Multiplicative factor for ry
  REAL(DP), INTENT(IN)                              :: cy
  
!</input>

!<inputoutput>
  
  ! Additive vector. Receives the result of the matrix-vector multiplication
  TYPE(t_vectorBlock), INTENT(INOUT)                :: ry
  
!</inputoutput>

!</subroutine>
  
  ! local variables
  INTEGER :: x,y,mvok
  REAL(DP)     :: cyact
  
  ! The vectors must be compatible to each other.
  CALL lsysbl_isVectorCompatible (rx,ry)

  ! and compatible to the matrix
  CALL lsysbl_isMatrixCompatible (rx,rmatrix)

  ! loop through all the sub matrices and multiply.
  DO y=1,rmatrix%ndiagBlocks
  
    ! The original vector ry must only be respected once in the first
    ! matrix-vector multiplication. The additive contributions of
    ! the other blocks must simply be added to ry without ry being multiplied
    ! by cy again!
  
    cyact = cy
    MVOK = NO
    DO x=1,rMatrix%ndiagBlocks
      
      ! Only call the MV when there is a scalar matrix that we can use!
      IF (lsysbl_isSubmatrixPresent (rmatrix,y,x)) THEN
        CALL lsyssc_scalarMatVec (rMatrix%RmatrixBlock(y,x), rx%RvectorBlock(x), &
                                  ry%RvectorBlock(y), cx, cyact)
        cyact = 1.0_DP
        mvok = YES
      END IF
      
    END DO
    
    ! If mvok=NO here, there was no matrix in the current line!
    ! A very special case, but nevertheless may happen. In this case,
    ! simply scale the vector ry by cyact!
    
    IF (mvok .EQ.NO) THEN
      CALL lsysbl_scaleVector (ry,cy)
    END IF
    
  END DO
   
  END SUBROUTINE
  
  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_invertedDiagMatVec (rmatrix,rvectorSrc,dscale,rvectorDst)
  
!<description>
  ! This routine multiplies the weighted inverted diagonal $domega*D^{-1}$
  ! of the diagonal blocks in the matrix rmatrix with the vector rvectorSrc and 
  ! stores the result into the vector rvectorDst:
  !   $$rvectorDst_i = dscale * D_i^{-1} * rvectorSrc_i  , i=1..nblocks$$
  ! Both, rvectorSrc and rvectorDst may coincide.
!</description>
  
!<input>
  ! The matrix. 
  TYPE(t_matrixBlock), INTENT(IN) :: rmatrix

  ! The source vector.
  TYPE(t_vectorBlock), INTENT(IN) :: rvectorSrc

  ! A multiplication factor. Standard value is 1.0_DP
  REAL(DP), INTENT(IN) :: dscale
!</input>

!<inputoutput>
  ! The destination vector which receives the result.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvectorDst
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: iblock
  
    ! Vectors and matrix must be compatible
    CALL lsysbl_isVectorCompatible (rvectorSrc,rvectorDst)
    CALL lsysbl_isMatrixCompatible (rvectorSrc,rmatrix)
  
    ! Loop over the blocks
    DO iblock = 1,rvectorSrc%nblocks
      ! Multiply with the inverted diagonal of the submatrix.
      CALL lsyssc_invertedDiagMatVec (rmatrix%RmatrixBlock(iblock,iblock),&
            rvectorSrc%RvectorBlock(iblock),dscale,&
            rvectorDst%RvectorBlock(iblock))
    END DO

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_copyVector (rx,ry)
  
!<description>
  ! Copies vector data: ry = rx.
  ! If the destination vector is empty, a new vector is created and all
  ! data of rx is copied into that.
  ! If the destination vector ry exists in memory, it must be at least
  ! as large as rx. All structural data as well as the content of rx is  
  ! transferred to ry, so rx and ry are compatible to each other afterwards.
!</description>

!<input>
  
  ! Source vector
  TYPE(t_vectorBlock),INTENT(IN) :: rx
  
!</input>

!<inputoutput>
  
  ! Destination vector
  TYPE(t_vectorBlock),INTENT(INOUT) :: ry
  
!</inputoutput>
  
!</subroutine>

  ! local variables
  INTEGER :: h_Ddata, cdataType
  INTEGER(I32) :: isize,NEQ
  LOGICAL :: bisCopy
  REAL(DP), DIMENSION(:), POINTER :: p_Dsource,p_Ddest
  REAL(SP), DIMENSION(:), POINTER :: p_Fsource,p_Fdest
  TYPE(t_vectorScalar), DIMENSION(:), POINTER :: p_rblocks
  
  ! If the destination vector does not exist, create a new one
  ! based on rx.
  IF (ry%h_Ddata .EQ. ST_NOHANDLE) THEN
    CALL lsysbl_createVecBlockIndirect (rx,ry,.FALSE.)
  END IF
  
  CALL storage_getsize1D (ry%h_Ddata, isize)
  NEQ = rx%NEQ
  IF (isize .LT. NEQ) THEN
    PRINT *,'lsysbl_copyVector: Destination vector too small!'
    STOP
  END IF
  
  IF (rx%cdataType .NE. ry%cdataType) THEN
    PRINT *,'lsysbl_copyVector: Destination vector has different type &
            &than source vector!'
    STOP
  END IF
  
  ! First, make a backup of some crucial data so that it does not
  ! get destroyed.
  h_Ddata = ry%h_Ddata
  cdataType = ry%cdataType
  bisCopy = ry%bisCopy
  p_rblocks => ry%RvectorBlock
  
  ! Then transfer all structural information of rx to ry.
  ! This automatically makes both vectors compatible to each other.
  ry = rx
  
  ! Restore crucial data
  ry%h_Ddata = h_Ddata
  ry%bisCopy = bisCopy
  ry%RvectorBlock => p_rblocks
  
  ! If necessary, allocate new memory for the blocks.
  IF (.NOT. ASSOCIATED(ry%RvectorBlock)) THEN
    ALLOCATE(ry%RvectorBlock(ry%nblocks))
  END IF
  ry%RvectorBlock = rx%RvectorBlock
  
  ! Restore the handle in all subvectors
  ry%RvectorBlock(1:ry%nblocks)%h_Ddata = h_Ddata
  ry%RvectorBlock(1:ry%nblocks)%cdataType = cdataType
  
  ! And finally copy the data. 
  SELECT CASE (rx%cdataType)
  CASE (ST_DOUBLE)
    CALL lsysbl_getbase_double (rx,p_Dsource)
    CALL lsysbl_getbase_double (ry,p_Ddest)
    CALL lalg_copyVectorDble (p_Dsource(1:NEQ),p_Ddest(1:NEQ))
    
  CASE (ST_SINGLE)
    CALL lsysbl_getbase_single (rx,p_Fsource)
    CALL lsysbl_getbase_single (ry,p_Fdest)
    CALL lalg_copyVectorSngl (p_Fsource(1:NEQ),p_Fdest(1:NEQ))

  CASE DEFAULT
    PRINT *,'lsysbl_copyVector: Unsupported data type!'
    STOP
  END SELECT
   
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_scaleVector (rx,c)
  
!<description>
  ! Scales a vector vector rx: rx = c * rx
!</description>
  
!<inputoutput>
  ! Source and destination vector
  TYPE(t_vectorBlock), INTENT(INOUT) :: rx
!</inputoutput>

!<input>
  ! Multiplication factor
  REAL(DP), INTENT(IN) :: c
!</input>
  
!</subroutine>

  ! local variables
  REAL(DP), DIMENSION(:), POINTER :: p_Ddata
  REAL(SP), DIMENSION(:), POINTER :: p_Fdata
  
  ! Taje care of the data type!
  SELECT CASE (rx%cdataType)
  CASE (ST_DOUBLE)
    ! Get the pointer and scale the whole data array.
    CALL lsysbl_getbase_double(rx,p_Ddata)
    CALL lalg_scaleVectorDble (p_Ddata,c)  

  CASE (ST_SINGLE)
    ! Get the pointer and scale the whole data array.
    CALL lsysbl_getbase_single(rx,p_Fdata)
    CALL lalg_scaleVectorSngl (p_Fdata,REAL(c,SP))  

  CASE DEFAULT
    PRINT *,'lsysbl_scaleVector: Unsupported data type!'
    STOP
  END SELECT
  
  END SUBROUTINE
  
  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_clearVector (rx)
  
!<description>
  ! Clears the block vector dx: Dx = 0
!</description>

!<inputoutput>
  ! Destination vector to be cleared
  TYPE(t_vectorBlock), INTENT(INOUT) :: rx
!</inputoutput>
  
!</subroutine>

  ! local variables
  REAL(DP), DIMENSION(:), POINTER :: p_Dsource
  REAL(SP), DIMENSION(:), POINTER :: p_Ssource
  
  ! Take care of the data type
  SELECT CASE (rx%cdataType)
  CASE (ST_DOUBLE)
    ! Get the pointer and scale the whole data array.
    CALL lsysbl_getbase_double(rx,p_Dsource)
    CALL lalg_clearVectorDble (p_Dsource)
  
  CASE (ST_SINGLE)
    ! Get the pointer and scale the whole data array.
    CALL lsysbl_getbase_single(rx,p_Ssource)
    CALL lalg_clearVectorSngl (p_Ssource)

  CASE DEFAULT
    PRINT *,'lsysbl_clearVector: Unsupported data type!'
    STOP
  END SELECT
  
  END SUBROUTINE
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_vectorLinearComb (rx,ry,cx,cy,rdest)
  
!<description>
  ! Performs a linear combination: ry = cx * rx  +  cy * ry
  ! If rdest is given, the routine calculates rdest = cx * rx  +  cy * ry
  ! without overwriting ry.
  ! All vectors must be compatible to each other (same size, sorting 
  ! strategy,...).
!</description>  
  
!<input>
  ! First source vector
  TYPE(t_vectorBlock), INTENT(IN)    :: rx
  
  ! Scaling factor for Dx
  REAL(DP), INTENT(IN)               :: cx

  ! Scaling factor for Dy
  REAL(DP), INTENT(IN)               :: cy
!</input>

!<inputoutput>
  ! Second source vector; also receives the result if rdest is not given.
  TYPE(t_vectorBlock), INTENT(INOUT) :: ry
  
  ! OPTIONAL: Destination vector. If not given, ry is overwritten.
  TYPE(t_vectorBlock), INTENT(INOUT), OPTIONAL :: rdest
!</inputoutput>
  
!</subroutine>

  ! local variables
  REAL(DP), DIMENSION(:), POINTER :: p_Dsource, p_Ddest, p_Ddest2
  REAL(SP), DIMENSION(:), POINTER :: p_Ssource, p_Sdest, p_Sdest2
  
  ! The vectors must be compatible to each other.
  CALL lsysbl_isVectorCompatible (rx,ry)
  
  IF (PRESENT(rdest)) THEN
    CALL lsysbl_isVectorCompatible (rx,rdest)
  END IF

  IF (rx%cdataType .NE. ry%cdataType) THEN
    PRINT *,'lsysbl_vectorLinearComb: different data types not supported!'
    STOP
  END IF
  
  SELECT CASE (rx%cdataType)
  CASE (ST_DOUBLE)
    ! Get the pointers and copy the whole data array.
    CALL lsysbl_getbase_double(rx,p_Dsource)
    IF (.NOT. PRESENT(rdest)) THEN
      CALL lsysbl_getbase_double(ry,p_Ddest)
    ELSE
      CALL lsysbl_getbase_double(rdest,p_Ddest)
      CALL lsysbl_getbase_double(ry,p_Ddest2)
      CALL lalg_copyVectorDble (p_Ddest2,p_Ddest)
    END IF
    
    CALL lalg_vectorLinearCombDble (p_Dsource,p_Ddest,cx,cy)

  CASE (ST_SINGLE)
    ! Get the pointers and copy the whole data array.
    CALL lsysbl_getbase_single(rx,p_Ssource)
    IF (.NOT. PRESENT(rdest)) THEN
      CALL lsysbl_getbase_single(ry,p_Sdest)
    ELSE
      CALL lsysbl_getbase_single(rdest,p_Sdest)
      CALL lsysbl_getbase_single(ry,p_Sdest2)
      CALL lalg_copyVectorSngl (p_Sdest2,p_Sdest)
    END IF
    
    CALL lalg_vectorLinearCombSngl (p_Ssource,p_Sdest,REAL(cx,SP),REAL(cy,SP))
  
  CASE DEFAULT
    PRINT *,'lsysbl_vectorLinearComb: Unsupported data type!'
    STOP
  END SELECT

  END SUBROUTINE
  
  !****************************************************************************
!<function>
  
  REAL(DP) FUNCTION lsysbl_scalarProduct (rx, ry)
  
!<description>
  ! Calculates a scalar product of two block vectors.
  ! Both vectors must be compatible to each other (same size, sorting 
  ! strategy,...).
!</description>
  
!<input>
  ! First vector
  TYPE(t_vectorBlock), INTENT(IN)                  :: rx

  ! Second vector
  TYPE(t_vectorBlock), INTENT(IN)                  :: ry

!</input>

!<result>
  ! The scalar product (rx,ry) of the two block vectors.
!</result>

!</function>

  ! local variables
  REAL(DP), DIMENSION(:), POINTER :: p_Ddata1dp
  REAL(DP), DIMENSION(:), POINTER :: p_Ddata2dp
  REAL(SP), DIMENSION(:), POINTER :: p_Fdata1dp
  REAL(SP), DIMENSION(:), POINTER :: p_Fdata2dp
  ! INTEGER(PREC_VECIDX) :: i
  REAL(DP) :: res

  ! The vectors must be compatible to each other.
  CALL lsysbl_isVectorCompatible (rx,ry)

  ! Is there data at all?
  res = 0.0_DP
  
  IF ( (rx%NEQ .EQ. 0) .OR. (ry%NEQ .EQ. 0) .OR. (rx%NEQ .NE. rx%NEQ)) THEN
    PRINT *,'Error in lsysbl_scalarProduct: Vector dimensions wrong!'
    STOP
  END IF

  IF (rx%cdataType .NE. ry%cdataType) THEN
    PRINT *,'lsysbl_scalarProduct: Data types different!'
    STOP
  END IF

  ! Take care of the data type before doing a scalar product!
  SELECT CASE (rx%cdataType)
  CASE (ST_DOUBLE)

    ! Get the data arrays
    CALL lsysbl_getbase_double (rx,p_Ddata1dp)
    CALL lsysbl_getbase_double (ry,p_Ddata2dp)
    
    ! Perform the scalar product
    res=lalg_scalarProductDble(p_Ddata1dp,p_Ddata2dp)
!!$      res = 0.0_DP
!!$      DO i=1,rx%NEQ
!!$        res = res + p_Ddata1dp(i)*p_Ddata2dp(i)
!!$      END DO
    
  CASE (ST_SINGLE)

    ! Get the data arrays
    CALL lsysbl_getbase_single (rx,p_Fdata1dp)
    CALL lsysbl_getbase_single (ry,p_Fdata2dp)

    ! Perform the scalar product
    res=lalg_scalarProductSngl(p_Fdata1dp,p_Fdata2dp)

  CASE DEFAULT
    PRINT *,'lsysbl_scalarProduct: Not supported precision combination'
    STOP
  END SELECT
  
  ! Return the scalar product, finish
  lsysbl_scalarProduct = res

  END FUNCTION

  !****************************************************************************
!<subroutine>
  
  REAL(DP) FUNCTION lsysbl_vectorNorm (rx,cnorm,iposMax)
  
!<description>
  ! Calculates the norm of a vector. cnorm specifies the type of norm to
  ! calculate.
!</description>
  
!<input>
  ! Vector to calculate the norm of.
  TYPE(t_vectorBlock), INTENT(IN)                  :: rx

  ! Identifier for the norm to calculate. One of the LINALG_NORMxxxx constants.
  INTEGER, INTENT(IN) :: cnorm
!</input>

!<output>
  ! OPTIONAL: If the MAX norm is to calculate, this returns the
  ! position of the largest element. If another norm is to be
  ! calculated, the result is undefined.
  INTEGER(I32), INTENT(OUT), OPTIONAL :: iposMax
!</output>

!<result>
  ! The norm of the given array.
  ! < 0, if an error occurred (unknown norm).
!</result>

!</subroutine>

  ! local variables
  REAL(DP), DIMENSION(:), POINTER :: p_Ddata
  REAL(SP), DIMENSION(:), POINTER :: p_Fdata

  ! Is there data at all?
  IF (rx%h_Ddata .EQ. ST_NOHANDLE) THEN
    PRINT *,'Error in lsysbl_vectorNorm: Vector empty!'
    STOP
  END IF
  
  ! Take care of the data type before doing a scalar product!
  SELECT CASE (rx%cdataType)
  CASE (ST_DOUBLE)
    ! Get the array and calculate the norm
    CALL lsysbl_getbase_double (rx,p_Ddata)
    lsysbl_vectorNorm = lalg_normDble (p_Ddata,cnorm,iposMax) 
    
  CASE (ST_SINGLE)
    ! Get the array and calculate the norm
    CALL lsysbl_getbase_single (rx,p_Fdata)
    lsysbl_vectorNorm = lalg_normSngl (p_Fdata,cnorm,iposMax) 
    
  CASE DEFAULT
    PRINT *,'lsysbl_vectorNorm: Unsupported data type!'
    STOP
  END SELECT
  
  END FUNCTION

  !****************************************************************************
!<subroutine>
  
  FUNCTION lsysbl_vectorNormBlock (rx,Cnorms,IposMax) RESULT (Dnorms)
  
!<description>
  ! Calculates the norms of all subvectors in a given block vector.
  ! Cnorms is an array containing the type of norm to compute for each
  ! subvector.
  !
  ! If the arrays Cnorms or IposMax are sre smaller than rx%nblocks,
  ! only the first couple of subvectors are processed until the
  ! forst array (Cnorms or IposMax) is completely filled.
!</description>
  
!<input>
  ! Vector to calculate the norm of.
  TYPE(t_vectorBlock), INTENT(IN)                   :: rx

  ! Identifier list. For every subvector in rx, this identifies the norm 
  ! to calculate. Each entry is a LINALG_NORMxxxx constants.
  INTEGER, DIMENSION(:), INTENT(IN)                 :: Cnorms
!</input>

!<output>
  ! OPTIONAL: For each subvector: if the MAX norm is to calculate, 
  ! this returns the position of the largest element in that subvector. 
  ! If another norm is to be calculated, the result is undefined.
  INTEGER(I32), DIMENSION(:), INTENT(OUT), OPTIONAL :: IposMax
!</output>

!<result>
  ! An array of norms for each subvector.
  ! An entry might be < 0, if an error occurred (unknown norm).
  REAL(DP), DIMENSION(SIZE(Cnorms)) :: Dnorms
!</result>

!</subroutine>

  ! local variables
  INTEGER :: i,nblk

  nblk = MIN(rx%nblocks,SIZE(Cnorms))
  IF (PRESENT(IposMax)) nblk = MIN(nblk,SIZE(IposMax))

  ! Loop over the subvectors. Don't calculate more subvectors as we 
  ! are allowed to.
  DO i=1,nblk
    ! Calculate the norm of that subvector.
    IF (PRESENT(IposMax)) THEN
      Dnorms(i) = lsyssc_vectorNorm (rx%RvectorBlock(i),Cnorms(i),IposMax(i))
    ELSE
      Dnorms(i) = lsyssc_vectorNorm (rx%RvectorBlock(i),Cnorms(i))
    END IF
  END DO
  
  END FUNCTION

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_createMatFromScalar (rscalarMat,rmatrix,&
                                         rblockDiscretisation)
  
!<description>
  ! This routine creates a 1x1 block matrix rmatrix from a scalar matrix
  ! rscalarMat. Both, rscalarMat and rmatrix will share the same handles,
  ! so changing the content of rmatrix will change rscalarMat, too.
  ! Therefore, the imatrixSpec flag of the submatrix in the block matrix
  ! will be set to LSYSSC_MSPEC_ISCOPY to indicate that the matrix is a
  ! copy of another one.
!</description>
  
!<input>
  ! The scalar matrix which should provide the data
  TYPE(t_matrixScalar), INTENT(IN) :: rscalarMat
  
  ! OPTIONAL: A block discretisation structure.
  ! A pointer to this will be saved to the matrix.
  TYPE(t_blockDiscretisation), INTENT(IN), OPTIONAL, TARGET :: rblockDiscretisation
!</input>

!<output>
  ! The 1x1 block matrix, created from rscalarMat.
  TYPE(t_matrixBlock), INTENT(OUT) :: rmatrix
!</output>
  
!</subroutine>

    ! Fill the rmatrix structure with data.
    rmatrix%NEQ         = rscalarMat%NEQ * rscalarMat%NVAR
    rmatrix%NCOLS       = rscalarMat%NCOLS * rscalarMat%NVAR
    rmatrix%ndiagBlocks = 1
    rmatrix%imatrixSpec = LSYSBS_MSPEC_SCALAR
    
    ! Copy the content of the scalar matrix structure into the
    ! first block of the block matrix
    ALLOCATE(rmatrix%RmatrixBlock(1,1))
    rmatrix%RmatrixBlock(1,1)             = rscalarMat

    ! The matrix is a copy of another one. Note this!
    rmatrix%RmatrixBlock(1,1)%imatrixSpec = &
      IOR(rmatrix%RmatrixBlock(1,1)%imatrixSpec,LSYSSC_MSPEC_ISCOPY)
      
    ! Save a pointer to the discretisation structure if that one
    ! is specified.
    IF (PRESENT(rblockDiscretisation)) THEN
      rmatrix%p_rblockDiscretisation => rblockDiscretisation
    ELSE
      NULLIFY(rmatrix%p_rblockDiscretisation)
    END IF
    
  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_createVecFromScalar (rscalarVec,rvector,&
                                         rblockDiscretisation,nblocks)
  
!<description>
  ! This routine creates a 1-block vector rvector from a scalar vector
  ! rscalarVec. Both, rscalarVec and rvector will share the same handles,
  ! so changing the content of rvector will change rscalarVec, too.
  ! Therefore, the bisCopy flag of the subvector in the block vector
  ! will be set to TRUE.
!</description>
  
!<input>
  ! The scalar vector which should provide the data
  TYPE(t_vectorScalar), INTENT(IN) :: rscalarVec

  ! OPTIONAL: A block discretisation structure.
  ! A pointer to this will be saved to the vector.
  TYPE(t_blockDiscretisation), INTENT(IN), OPTIONAL, TARGET :: rblockDiscretisation
  
  ! OPTIONAL: Number of blocks to reserve.
  ! Normally, the created scalar vector has only one block. If nblocks
  ! is specified, the resulting vector will have more blocks while only
  ! the first block vector is used.
  INTEGER, INTENT(IN), OPTIONAL :: nblocks
!</input>

!<output>
  ! The 1x1 block matrix, created from rscalarMat.
  TYPE(t_vectorBlock), INTENT(OUT) :: rvector
!</output>
  
!</subroutine>

    INTEGER :: nactblocks
    
    nactblocks = 1
    IF (PRESENT(nblocks)) nactblocks = MAX(nblocks,nactblocks)
    IF (PRESENT(rblockDiscretisation)) &
      nactblocks = MAX(rblockDiscretisation%ncomponents,nactblocks)

    ! Fill the rvector structure with data.
    rvector%NEQ         = rscalarVec%NEQ * rscalarVec%NVAR
    rvector%cdataType   = rscalarVec%cdataType
    rvector%h_Ddata     = rscalarVec%h_Ddata
    rvector%nblocks     = nactblocks
    
    ! Copy the content of the scalar matrix structure into the
    ! first block of the block vector
    ALLOCATE(rvector%RvectorBlock(nactblocks))
    rvector%RvectorBlock(1) = rscalarVec
    
    ! Copy the starting address of the scalar vector to our block vector.
    rvector%iidxFirstEntry  = rscalarVec%iidxFirstEntry

    ! The handle belongs to another vector - note this in the structure.
    rvector%RvectorBlock(1)%bisCopy     = .TRUE.
    
    ! The data of the vector actually belongs to another one - to the
    ! scalar one. Note this in the structure.
    rvector%bisCopy = .TRUE.

    ! Save a pointer to the discretisation structure if that one
    ! is specified.
    IF (PRESENT(rblockDiscretisation)) THEN
      rvector%p_rblockDiscretisation => rblockDiscretisation
    ELSE
      NULLIFY(rvector%p_rblockDiscretisation)
    END IF
    
  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_enforceStructure (rtemplateVec,rvector)
  
!<description>
  ! This routine enforces the structure of the vector rtemplate
  ! in the vector rvector. 
  !
  ! WARNING: This routine should be used with care if you know
  !          what you are doing !!!
  ! All structural data of rtemplate (boundary conditions, spatial 
  ! discretisation, size,sorting,...) are copied from rtemplate to 
  ! rvector without checking the compatibility!!!
  !
  ! The only check in this routine is that rvector%NEQ is
  ! at least as large as rtemplate%NEQ; otherwise an error
  ! is thrown. The data type of rvector is also not changed.
!</description>
  
!<input>
  ! A template vector specifying structural data
  TYPE(t_vectorBlock), INTENT(IN) :: rtemplateVec
!</input>

!<inputoutput>
  ! The vector which structural data should be overwritten
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector
!</inputoutput>
  
!</subroutine>

  ! local variables
  INTEGER :: cdata,h_Ddata,i
  LOGICAL :: biscopy
  INTEGER(PREC_VECIDX) :: istart,n !,length
  TYPE(t_vectorScalar), DIMENSION(:), POINTER :: p_Rblocks

!  REAL(DP), DIMENSION(:), POINTER :: p_Ddata
!  REAL(SP), DIMENSION(:), POINTER :: p_Fdata
!
! Here, we check the real size of the array on the heap, not
! simply NEQ. Allows to enlarge a vector if there's enough space.
!    SELECT CASE (rvector%cdataType)
!    CASE (ST_DOUBLE)
!      CALL storage_getbase_double (rvector%h_Ddata,p_Ddata)
!      length = SIZE(p_Ddata)-rvector%iidxFirstEntry+1
!    CASE (ST_SINGLE)
!      CALL storage_getbase_double (rvector%h_Ddata,p_Fdata)
!      length = SIZE(p_Fdata)-rvector%iidxFirstEntry+1
!    CASE DEFAULT
!      PRINT *,'lsysbl_enforceStructure: Unsupported data type'
!      STOP
!    END SELECT
    
    ! Only basic check: there must be enough memory.
    IF (rvector%NEQ .LT. rtemplateVec%NEQ) THEN
      PRINT *,'lsysbl_enforceStructure: Destination vector too small!'
      STOP
    END IF
  
    ! Get data type and handle from rvector
    cdata = rvector%cdataType
    h_Ddata = rvector%h_Ddata
    istart = rvector%iidxFirstEntry
    biscopy = rvector%bisCopy
    p_Rblocks => rvector%RvectorBlock
    
    ! Overwrite rvector
    rvector = rtemplateVec
    
    ! Restore the data array
    rvector%cdataType = cdata
    rvector%h_Ddata = h_Ddata
    rvector%iidxFirstEntry = istart
    rvector%bisCopy = biscopy
    rvector%RvectorBlock => p_Rblocks
    
    ! If RvectorBlock is too small, reallocate
    IF (SIZE(rvector%RvectorBlock) .LT. rtemplateVec%nblocks) THEN
      DEALLOCATE(rvector%RvectorBlock)
      ALLOCATE(rvector%RvectorBlock(rtemplateVec%nblocks))
    END IF
    
    ! Copy the subvector data
    rvector%RvectorBlock = rtemplateVec%RvectorBlock
    
    ! Relocate the starting indices of the subvectors.
    n = istart
    DO i=1,rvector%nblocks
      rvector%RvectorBlock(i)%iidxFirstEntry = n
      n = n + rvector%RvectorBlock(i)%NEQ
    END DO
    
  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_enforceStructureDirect (Isize,rvector)
  
!<description>
  ! This routine enforces the structure of the vector rtemplate
  ! in the vector rvector. 
  !
  ! WARNING: This routine should be used with care if you know
  !          what you are doing !!!
  ! 
  ! The routine enforces SIZE(Isize) subvectors in rvector and
  ! sets the size of the i'thg subvector to Isize(i).
  !
  ! The only check in this routine is that rvector%NEQ is
  ! at least as large as SUM(Isize); otherwise an error
  ! is thrown. The data type of rvector is also not changed.
!</description>
  
!<input>
  ! An array with size definitions. Isize(j) specifies the length of the j'th
  ! subvector.
  INTEGER(PREC_VECIDX), DIMENSION(:), INTENT(IN) :: Isize
!</input>

!<inputoutput>
  ! The vector which structural data should be overwritten
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector
!</inputoutput>
  
!</subroutine>

  ! local variables
  INTEGER :: i
  INTEGER(PREC_VECIDX) :: n !,length

!  REAL(DP), DIMENSION(:), POINTER :: p_Ddata
!  REAL(SP), DIMENSION(:), POINTER :: p_Fdata
!
    ! Only basic check: there must be enough memory.
    IF (rvector%NEQ .LT. SUM(Isize)) THEN
      PRINT *,'lsysbl_enforceStructureDirect: Destination vector too small!'
      STOP
    END IF
  
    ! Set the attributes of the vector
    rvector%nblocks = SIZE(Isize)
   
    ! If RvectorBlock is wrong, reallocate
    IF (SIZE(rvector%RvectorBlock) .NE. rvector%nblocks) THEN
      DEALLOCATE(rvector%RvectorBlock)
      ALLOCATE(rvector%RvectorBlock(rvector%nblocks))
    END IF

    rvector%RvectorBlock(1:rvector%nblocks)%h_Ddata = rvector%h_Ddata
    rvector%RvectorBlock(1:rvector%nblocks)%bisCopy = .TRUE.
    rvector%RvectorBlock(1:rvector%nblocks)%cdataType = rvector%cdataType
    
    ! Relocate the starting indices of the subvectors.
    n = rvector%iidxFirstEntry
    DO i=1,rvector%nblocks
      rvector%RvectorBlock(i)%iidxFirstEntry = n
      rvector%RvectorBlock(i)%NEQ = Isize(i)
      n = n + Isize(i)
    END DO
    
    
  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_updateMatStrucInfo (rmatrix)
  
!<description>
  ! Updates structural information of a block matrix by recalculation
  ! from submatrices.
  ! This routine must be called, if the application changes structural
  ! information in one or more of the matrix blocks of a submatrix.
  ! In this case, this routine recalculates crucial information
  ! of the global matrix (number of blocks, global NEQ,...) by checking 
  ! the submatrices.
!</description>
  
!<inputoutput>
  ! The block matrix which is to be updated.
  TYPE(t_matrixBlock), INTENT(INOUT) :: rmatrix
!</inputoutput>

!</subroutine>

  INTEGER :: i,j,k,NEQ,NCOLS
  
  ! At first, recalculate the number of diagonal blocks in the
  ! block matrix
  outer: DO i=UBOUND(rmatrix%RmatrixBlock,2),1,-1
    DO j=UBOUND(rmatrix%RmatrixBlock,1),1,-1
      IF (rmatrix%RmatrixBlock(j,i)%NEQ .NE. 0) EXIT outer
    END DO
  END DO outer
  
  ! The maximum of i and j is the new number of diagonal blocks
  rmatrix%ndiagBlocks = MAX(i,j)
  
  ! Calculate the new NEQ and NCOLS. Go through all 'columns' and 'rows
  ! of the block matrix and sum up their dimensions.
  NCOLS = 0
  DO j=1,UBOUND(rmatrix%RmatrixBlock,2)
    DO k=1,UBOUND(rmatrix%RmatrixBlock,1)
      IF (rmatrix%RmatrixBlock(k,j)%NCOLS .NE. 0) THEN
        NCOLS = NCOLS + rmatrix%RmatrixBlock(k,j)%NCOLS
        EXIT
      END IF
    END DO
  END DO

  ! Loop in the transposed way to calculate NEQ.
  NEQ = 0
  DO j=1,UBOUND(rmatrix%RmatrixBlock,1)
    DO k=1,UBOUND(rmatrix%RmatrixBlock,2)
      IF (rmatrix%RmatrixBlock(j,k)%NEQ .NE. 0) THEN
        NEQ = NEQ + rmatrix%RmatrixBlock(j,k)%NEQ
        EXIT
      END IF
    END DO
  END DO
  
  rmatrix%NEQ = NEQ
  rmatrix%NCOLS = NCOLS

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_clearMatrix (rmatrix)
  
!<description>
  ! Clears the entries in all submatrices of a block matrix. 
  ! All entries are overwritten with 0.0.
!</description>
  
!<inputoutput>
  ! The block matrix which is to be updated.
  TYPE(t_matrixBlock), INTENT(INOUT) :: rmatrix
!</inputoutput>

!</subroutine>

  INTEGER :: i,j
  
  ! Loop through all blocks and clear the matrices
  ! block matrix
  DO i=1,rmatrix%ndiagBlocks
    DO j=1,rmatrix%ndiagBlocks
      CALL lsyssc_clearMatrix (rmatrix%RmatrixBlock(i,j))
    END DO
  END DO

  END SUBROUTINE

  !****************************************************************************
  
!<subroutine>
  
  SUBROUTINE lsysbl_duplicateMatrix (rsourceMatrix,rdestMatrix,&
                                     idupStructure, idupContent)
  
!<description>
  ! Duplicates an existing matrix, creates a new matrix rdestMatrix based
  ! on a template matrix rsourceMatrix. To duplicate a block matrix means here
  ! to copy all the existing submatrices in the block matrix in the same way.
  !
  ! Duplicating a matrix does not necessarily mean that new memory is
  ! allocated and the matrix entries are copied to that. The two flags
  ! idupStructure and idupContent decide on how to set up rdestMatrix.
  ! Depending on their setting, it's possible to copy only the handles
  ! of such dynamic information, so that both matrices share the same
  ! information.
  !
  ! We follow the following convention:
  !  Structure = Column structure, Row structure, Sorting permutation,
  !              Discretisation-related information
  !  Content   = Enties in a matrix.
  !
  ! Remark: There is never memory allocated on the heap for the sorting
  !  permutation. A matrix is never the 'owner' of a permutation, i.e.
  !  does not maintain it. Therefore, copying a permutation in one of
  !  the submatrices means copying the corresponding handle. 
  !  The application must keep track of the permutations.
!</description>
  
!<input>
  ! Source matrix.
  TYPE(t_matrixBlock), INTENT(IN)               :: rsourceMatrix
  
  ! Duplication flag that decides on how to set up the structure
  ! of rdestMatrix. This duplication flag is applied to all submatrices
  ! of rsourceMatrix.
  !
  ! One of the LSYSSC_DUP_xxxx flags:
  ! LSYSSC_DUP_IGNORE     : Don't set up the structure of rdestMatrix. Any
  !   matrix structure is ignored and therefore preserved.
  ! LSYSSC_DUP_REMOVE     : Removes any existing matrix structure from 
  !   rdestMatrix if there is any. Releases memory if necessary.
  !   Does not delete 'static' information like NEQ,NCOLS,NA,...
  ! LSYSSC_DUP_DISMISS    : Removes any existing matrix structure from 
  !   rdestMatrix if there is any. No memory is released, handles are simply
  !   dismissed. Does not delete 'static' information like NEQ,NCOLS,NA,...
  ! LSYSSC_DUP_SHARE      : rdestMatrix receives the same handles for
  !   structural data as rsourceMatrix and therefore shares the same structure.
  ! LSYSSC_DUP_COPY       : rdestMatrix gets a copy of the structure of 
  !   rsourceMatrix. If necessary, new memory is allocated for the structure. 
  !   If rdestMatrix already contains allocated memory, structural data
  !   is simply copied from rsourceMatrix into that.
  ! LSYSSC_DUP_ASIS       : Duplicate by ownership. If the structure of 
  !   rsourceMatrix belongs to rsourceMatrix, rdestMatrix gets a copy
  !   of the structure; new memory is allocated if necessary (the same as 
  !   LSYSSC_DUP_COPY). If the structure of rsourceMatrix belongs to another
  !   matrix than rsourceMatrix, rdestMatrix receives the same handles as
  !   rsourceMatrix and is therefore a third matrix sharing the same structure
  !   (the same as LSYSSC_DUP_SHARE, so rsourceMatrix, rdestMatrix and the 
  !   other matrix have the same structure).
  ! LSYSSC_DUP_EMPTY      : New memory is allocated for the structure in the
  !   same size as the structure in rsourceMatrix but no data is copied;
  !   the arrays are left uninitialised.
  ! LSYSSC_DUP_TEMPLATE   : Copies statis structural information about the
  !   structure (NEQ, NCOLS,...) to the destination matrix. Dynamic information
  !   is removed from the destination matrix, all handles are reset.
  INTEGER, INTENT(IN)                            :: idupStructure
  
  ! Duplication flag that decides on how to set up the content
  ! of rdestMatrix. This duplication flag is applied to all submatrices
  ! of rsourceMatrix.
  !
  ! One of the LSYSSC_DUP_xxxx flags:
  ! LSYSSC_DUP_IGNORE     : Don't set up the content of rdestMatrix. Any
  !   matrix content is ignored and therefore preserved.
  ! LSYSSC_DUP_REMOVE     : Removes any existing matrix content from 
  !   rdestMatrix if there is any. Releases memory if necessary.
  ! LSYSSC_DUP_DISMISS    : Removes any existing matrix content from 
  !   rdestMatrix if there is any. No memory is released, handles are simply
  !   dismissed.
  ! LSYSSC_DUP_SHARE      : rdestMatrix receives the same handles for
  !   matrix content data as rsourceMatrix and therefore shares the same content.
  ! LSYSSC_DUP_COPY       : rdestMatrix gets a copy of the content of rsourceMatrix.
  !   If necessary, new memory is allocated for the content.
  !   If rdestMatrix already contains allocated memory, content data
  !   is simply copied from rsourceMatrix into that.
  ! LSYSSC_DUP_ASIS       : Duplicate by ownership. If the content of 
  !   rsourceMatrix belongs to rsourceMatrix, rdestMatrix gets a copy
  !   of the content; new memory is allocated if necessary (the same as 
  !   LSYSSC_DUP_COPY). If the content of rsourceMatrix belongs to another
  !   matrix than rsourceMatrix, rdestMatrix receives the same handles as
  !   rsourceMatrix and is therefore a third matrix sharing the same content
  !   (the same as LSYSSC_DUP_SHARE, so rsourceMatrix, rdestMatrix and the 
  !   other matrix have the same content).
  ! LSYSSC_DUP_EMPTY      : New memory is allocated for the content in the
  !   same size as the structure in rsourceMatrix but no data is copied;
  !   the arrays are left uninitialised.
  ! LSYSSC_DUP_TEMPLATE   : Copies statis structural information about the
  !   structure (NEQ, NCOLS,...) to the destination matrix. Dynamic information
  !   is removed from the destination matrix, all handles are reset.
  INTEGER, INTENT(IN)                            :: idupContent
!</input>

!<output>
  ! Destination matrix.
  TYPE(t_matrixBlock), INTENT(INOUT)            :: rdestMatrix
!</output>  

!</subroutine>

    ! local variables
    INTEGER(PREC_MATIDX) :: i,j
    TYPE(t_matrixScalar), DIMENSION(:,:), POINTER :: p_rblocks
    
    ! Copy the matrix structure of rsourceMatrix to rdestMatrix. This will also
    ! copy the structures of the submatrices, what we have to correct later.
    p_rblocks => rdestMatrix%RmatrixBlock
    rdestMatrix = rsourceMatrix
    rdestMatrix%RmatrixBlock => p_rblocks
    IF (.NOT. ASSOCIATED(rdestMatrix%RmatrixBlock)) THEN
      ! Check if number of diagonal blocks is nonzero, otherwise exit
      IF (rdestMatrix%ndiagblocks <= 0) RETURN
      ALLOCATE(rdestMatrix%RmatrixBlock(rdestMatrix%ndiagBlocks,rdestMatrix%ndiagBlocks))
    END IF
    rdestMatrix%RmatrixBlock = rsourceMatrix%RmatrixBlock
    
    ! For every submatrix in the source matrix, call the 'scalar' variant
    ! of duplicateMatrix. Dismiss all old information and replace it by
    ! the new one.
    DO j=1,rsourceMatrix%ndiagBlocks
      DO i=1,rsourceMatrix%ndiagBlocks
        IF (rdestMatrix%RmatrixBlock(i,j)%cmatrixFormat .NE. LSYSSC_MATRIXUNDEFINED) THEN
        
          ! Set the specification flags to "matrix is copy", so the releaseMatrix
          ! routine will not release any memory but only dismiss all information.
          rdestMatrix%RmatrixBlock(i,j)%imatrixSpec = &
              IOR(rdestMatrix%RmatrixBlock(i,j)%imatrixSpec,LSYSSC_MSPEC_ISCOPY)
          CALL lsyssc_releaseMatrix (rdestMatrix%RmatrixBlock(i,j))
              
          CALL lsyssc_duplicateMatrix ( &
              rsourceMatrix%RmatrixBlock(i,j), rdestMatrix%RmatrixBlock(i,j),&
              idupStructure, idupContent)
                                       
        END IF
      END DO
    END DO
    
    ! Update the structural information of the block matrix for completeness.
    CALL lsysbl_updateMatStrucInfo(rdestMatrix)
    
  END SUBROUTINE
    
  !****************************************************************************
  
!<subroutine>
  
  SUBROUTINE lsysbl_duplicateVector (rsourceVector,rdestVector,&
                                     idupStructure, idupContent)
  
!<description>
  ! Duplicates an existing vector, creates a new vector rdestVector based
  ! on a template vector rsourceVector. To duplicate a block vector means here
  ! to copy all the existing subvectors in the block vector in the same way.
  !
  ! Duplicating a vector does not necessarily mean that new memory is
  ! allocated and the vector entries are copied to that. The two flags
  ! idupStructure and idupContent decide on how to set up rdestVector.
  ! Depending on their setting, it's possible to copy only then handles
  ! of such dynamic information, so that both vectors share the same
  ! information.
!</description>

!<input>
  ! Source vector.
  TYPE(t_vectorBlock), INTENT(IN) :: rsourceVector

  ! Duplication flag that decides on how to set up the structure
  ! of rdestVector. This duplication flag is applied to all subvectors
  ! of rsourceVector.
  INTEGER, INTENT(IN) :: idupStructure

  ! Duplication flag that decides on how to set up the content
  ! of rdestVector. This duplication flag is applied to all subvectors
  ! of rsourceVector.
  INTEGER, INTENT(IN) :: idupContent
!</input>

!<output>
  ! Destination vector.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rdestVector
!</output>
!</subroutine>

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_sortVectorInSitu (rvector,rtemp,bsort)
  
!<description>
  ! This routine sorts a block vector or unsorts it.
  ! If bsort=TRUE, the vector is sorted, otherwise it's unsorted.
  !
  ! The sorting uses the associated permutation of every subvector,
  ! so before calling this routine, a permutation should be assigned
  ! to every subvector, either manually or using lsysbl_setSortStrategy.
  ! The associated sorting strategy tag will change to
  !  + |subvector%isortStrategy|  - if bsort = TRUE
  !  - |subvector%isortStrategy|  - if bsort = false
  ! so the absolute value of rvector%isortStrategy indicates the sorting
  ! strategy and the sign determines whether the (sub)vector is
  ! actually sorted for the associated sorting strategy.
!</description>

!<input>
  ! Whether to sort the vector (TRUE) or sort it back to unsorted state
  ! (FALSE).
  LOGICAL, INTENT(IN) :: bsort
!</input>
  
!<inputoutput>
  ! The vector which is to be resorted
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector

  ! A scalar temporary vector. Must be of the same data type as rvector.
  ! Must be at least as large as the longest subvector in rvector.
  TYPE(t_vectorScalar), INTENT(INOUT) :: rtemp
!</inputoutput>

!</subroutine>

  INTEGER :: iblock
  
  ! Loop over the blocks
  IF (bsort) THEN
    DO iblock = 1,rvector%nblocks
      CALL lsyssc_sortVectorInSitu (&
          rvector%RvectorBlock(iblock), rtemp,&
          ABS(rvector%RvectorBlock(iblock)%isortStrategy))
    END DO
  ELSE
    DO iblock = 1,rvector%nblocks
      CALL lsyssc_sortVectorInSitu (&
          rvector%RvectorBlock(iblock), rtemp,&
          -ABS(rvector%RvectorBlock(iblock)%isortStrategy))
    END DO
  END IF

  END SUBROUTINE

  !****************************************************************************
  
!<subroutine>
  
  SUBROUTINE lsysbl_synchroniseSortVecVec (rvectorSrc,rvectorDst,rtemp)
  
!<description>
  ! Synchronises the sorting strategy of rvectorDest according to rvectorSrc:
  ! If rvectorSrc is unsorted, rvectorDest will be unsorted (without changing
  ! the attached sorting permutation).
  ! If rvectorSrc is sorted differently to rvectorDest, rvectorDest is
  ! sorted according to rvectorSrc.
  ! Therefore if the routine is finished, rvectorDest 'looks like'
  ! rvectorSrc according to the sorting strategy.
!</description>

!<input>
  ! Source vector defining the sorting strategy.
  TYPE(t_vectorBlock), INTENT(IN)               :: rvectorSrc
!</input>

!<inputoutput>
  ! Destination vector; is resorted according to the sort strategy in rvectorSrc
  ! or is unsorted, if rvectorSrc is unsorted.
  ! Must have the same size as rvectorSrc.
  TYPE(t_vectorBlock), INTENT(INOUT)            :: rvectorDst

  ! A scalar temporary vector. Must be of the same data type as rvector.
  ! Must be at least as large as the longest subvector in rvector.
  TYPE(t_vectorScalar), INTENT(INOUT) :: rtemp
!</inputoutput>

!</subroutine>

    INTEGER :: iblock
    
    ! Loop over the blocks
    DO iblock = 1,rvectorDst%nblocks
      ! Synchronise every subvector
      CALL lsyssc_synchroniseSortVecVec (rvectorSrc%RvectorBlock(iblock),&
          rvectorDst%RvectorBlock(iblock),rtemp)
    END DO

  END SUBROUTINE

  !****************************************************************************
  
!<subroutine>
  
  SUBROUTINE lsysbl_synchroniseSortMatVec (rmatrixSrc,rvectorDst,rtemp)
  
!<description>
  ! Synchronises the sorting strategy of rvectorDest according to rmatrixSrc:
  ! If rmatrixSrc is unsorted, rvectorDest will be unsorted (without changing
  ! the attached sorting permutation).
  ! If rmatrixSrc is sorted differently to rvectorDest, rvectorDest is
  ! sorted according to rmatrixSrc.
  ! Therefore if the routine is finished, rvectorDest is compatible to
  ! rmatrixSrc according to the sorting strategy.
!</description>

!<input>
  ! Source matrix defining the sorting strategy.
  TYPE(t_matrixBlock), INTENT(IN)               :: rmatrixSrc
!</input>

!<inputoutput>
  ! Destination vector; is resorted according to the sort strategy in rmatrixSrc
  ! or is unsorted, if rmatrixSrc is unsorted.
  ! Must have the same size (NEQ) as rmatrixSrc.
  TYPE(t_vectorBlock), INTENT(INOUT)            :: rvectorDst

  ! A temporary vector. Must be of the same data type as rvector.
  ! Must be at least as large as rvectorDst.
  TYPE(t_vectorScalar), INTENT(INOUT)            :: rtemp
!</inputoutput>

!</subroutine>

    INTEGER :: i,j
    
    ! Loop over the columns of the block matrix
    DO j=1,rmatrixSrc%ndiagBlocks
      ! Loop through all rows in that column. Find the first matrix that can
      ! provide us with a sorting strategy we can use.
      ! We can assume that all submatrices in that matrix column have 
      ! the same sorting strategy, otherwise something like matrix-vector
      ! multiplication will quickly lead to a program failure...
      DO i = 1,rmatrixSrc%ndiagBlocks
        IF (rmatrixSrc%RmatrixBlock(i,j)%NEQ .NE. 0) THEN
          CALL lsyssc_synchroniseSortMatVec (rmatrixSrc%RmatrixBlock(i,j),&
              rvectorDst%RvectorBlock(i),rtemp)
          ! Next column / subvector
          EXIT
        END IF
      END DO
    END DO

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  SUBROUTINE lsysbl_setSortStrategy (rvector,IsortStrategy,Hpermutations)
  
!<description>
  ! This routine simultaneously connects all subvectors of a block
  ! vector with a sorting strategy. IsortStrategy is an array of tags
  ! that identify the sorting strategy of each subvector. Hpermutation
  ! is an array of handles. Each handle identifies the permutation
  ! that is to assign to the corresponding subvector.
  !
  ! The routine does not resort the vector. Only the identifier in
  ! IsortStrategy and the handle of the permutation are saved to the
  ! vector. To indicate that the subvector is not sorted, the negative
  ! value of IsortStrategy is saved to subvector%isortStrategy.
!</description>

!<inputoutput>
  ! The vector which is to be resorted
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector
!</inputoutput>

!<input>
  ! An array of sorting strategy identifiers (SSTRAT_xxxx), each for one
  ! subvector of the global vector. 
  ! The negative value of this identifier is saved to the corresponding
  ! subvector.
  ! DIMENSION(rvector\%nblocks)
  INTEGER, DIMENSION(:), INTENT(IN) :: IsortStrategy
  
  ! An array of handles. Each handle corresponds to a subvector and
  ! defines a permutation how to resort the subvector.
  ! Each permutation associated to a handle must be of the form
  !    array [1..2*NEQ] of integer  (NEQ=NEQ(subvector))
  ! with entries (1..NEQ)       = permutation
  ! and  entries (NEQ+1..2*NEQ) = inverse permutation.
  ! DIMENSION(rvector\%nblocks)
  INTEGER, DIMENSION(:), INTENT(IN) :: Hpermutations

!</input>
  
!</subroutine>

  ! Install the sorting strategy in every block. 
  rvector%RvectorBlock(1:rvector%nblocks)%isortStrategy = &
    -ABS(IsortStrategy(1:rvector%nblocks))
  rvector%RvectorBlock(1:rvector%nblocks)%h_IsortPermutation = &
    Hpermutations(1:rvector%nblocks)

  END SUBROUTINE

  !****************************************************************************

!<function>
  
  LOGICAL FUNCTION lsysbl_isMatrixSorted (rmatrix)
  
!<description>
  ! Loops through all submatrices in a block matrix and checks if any of
  ! them is sorted. If yes, the block matrix is given the state 'sorted'.
  ! If not, the matrix is stated 'unsorted'
!</description>
  
!<input>
  ! Block matrix to check
  TYPE(t_matrixBlock), INTENT(IN)                  :: rmatrix
!</input>

!<result>
  ! Whether the matrix is sorted or not.
!</result>

!</function>

  INTEGER(PREC_VECIDX) :: i,j,k
  
  ! Loop through all matrices and get the largest sort-identifier
  k = 0
  DO j=1,rmatrix%ndiagBlocks
    DO i=1,rmatrix%ndiagBlocks
      IF (rmatrix%RmatrixBlock(i,j)%NEQ .NE. 0) THEN
        k = MAX(k,rmatrix%RmatrixBlock(i,j)%isortStrategy)
      END IF
    END DO
  END DO
  
  ! If k is greater than 0, at least one submatrix is sorted
  lsysbl_isMatrixSorted = k .GT. 0

  END FUNCTION

  !****************************************************************************

!<function>
  
  LOGICAL FUNCTION lsysbl_isVectorSorted (rvector)
  
!<description>
  ! Loops through all subvectors in a block vector and checks if any of
  ! them is sorted. If yes, the block vector is given the state 'sorted'.
  ! If not, the vector is stated 'unsorted'
!</description>
  
!<input>
  ! Block matrix to check
  TYPE(t_vectorBlock), INTENT(IN)                  :: rvector
!</input>

!<result>
  ! Whether the vector is sorted or not.
!</result>

!</function>

  INTEGER(PREC_VECIDX) :: i,k
  
  ! Loop through all matrices and get the largest sort-identifier
  k = 0
  DO i=1,rvector%nblocks
    IF (rvector%RvectorBlock(i)%NEQ .NE. 0) THEN
      k = MAX(k,rvector%RvectorBlock(i)%isortStrategy)
    END IF
  END DO
  
  ! If k is greater than 0, at least one submatrix is sorted
  lsysbl_isVectorSorted = k .GT. 0

  END FUNCTION

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_swapVectors(rvector1,rvector2)

!<description>
    ! This subroutine swaps two vectors
!</description>

!<inputoutput>
    ! first block vector
    TYPE(t_vectorBlock), INTENT(INOUT) :: rvector1

    ! second block vector
    TYPE(t_vectorBlock), INTENT(INOUT) :: rvector2
!</inputoutput>
!</subroutine>

    ! local variables
    TYPE(t_vectorBlock) :: rvector
    INTEGER :: iblock

    ! Vcetor1 -> Vector
    rvector = rvector1
    rvector%p_rblockDiscretisation => rvector1%p_rblockDiscretisation
    rvector%p_rdiscreteBC          => rvector1%p_rdiscreteBC
    rvector%p_rdiscreteBCfict      => rvector1%p_rdiscreteBCfict
    DO iblock=1,rvector%nblocks
      rvector1%RvectorBlock(iblock)=rvector%RvectorBlock(iblock)
      rvector1%RvectorBlock(iblock)%p_rspatialDiscretisation =>&
          rvector%RvectorBlock(iblock)%p_rspatialDiscretisation
    END DO

    ! Vector2 -> Vector1
    rvector1 = rvector2
    rvector1%p_rblockDiscretisation => rvector2%p_rblockDiscretisation
    rvector1%p_rdiscreteBC          => rvector2%p_rdiscreteBC
    rvector1%p_rdiscreteBCfict      => rvector2%p_rdiscreteBCfict
    DO iblock=1,rvector1%nblocks
      rvector1%RvectorBlock(iblock)=rvector2%RvectorBlock(iblock)
      rvector1%RvectorBlock(iblock)%p_rspatialDiscretisation =>&
          rvector2%RvectorBlock(iblock)%p_rspatialDiscretisation
    END DO

    ! Vector -> Vector2
    rvector2 = rvector2
    rvector2%p_rblockDiscretisation => rvector%p_rblockDiscretisation
    rvector2%p_rdiscreteBC          => rvector%p_rdiscreteBC
    rvector2%p_rdiscreteBCfict      => rvector%p_rdiscreteBCfict
    DO iblock=1,rvector2%nblocks
      rvector2%RvectorBlock(iblock)=rvector%RvectorBlock(iblock)
      rvector2%RvectorBlock(iblock)%p_rspatialDiscretisation =>&
          rvector%RvectorBlock(iblock)%p_rspatialDiscretisation
    END DO
  END SUBROUTINE lsysbl_swapVectors

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_deriveSubvector(rvectorSrc,rvectorDest, &
      ifirstSubvector,ilastSubvector,bshare)

!<description>
    ! This routine derives a block vector as a subset of another block vector.
    !
    ! ifirstSubvector is the index of a scalar subvector in rvectorSrc
    ! which should be used as the first vector in rvectorDest.
    ! ilastSubvector is the index of a scalar subvector in rvectorSrc
    ! which should be used as the last vector in rvectorDest.
    !
    ! rvectorDest will therefore contain the subvectors 
    ! ifirstSubvector..ilastSubvector of rvectorSrc.
    !
    ! If bshare=TRUE, the vector rvectorDest will be created by copying
    ! handles instead of memory from rvectorSrc. Every change in rvectorDest
    ! will therefore also affect rvectorSrc.
    !
    ! If bshare=FALSE (the standard setting), a new vector will be created
    ! and the content of the specified subvectors will be copied to that.
    !
    ! The newly created block vector will not have any block discretisation 
    ! structure attached!
!</description>

!<input>
  ! Source block vector
  TYPE(t_vectorBlock), INTENT(IN) :: rvectorSrc

  ! OPTIONAL: Number of the subvector of rvectorSrc that should be used as first 
  ! subvector in rvectorDest. Default value is =1.
  INTEGER, INTENT(IN), OPTIONAL :: ifirstSubvector

  ! OPTIONAL: Number of the subvector of rvectorSrc that should be used as 
  ! last subvector in rvectorDest. Default value is the number of blocks
  ! in rvectorSrc.
  INTEGER, INTENT(IN), OPTIONAL :: ilastSubvector

  ! OPTIONAL: Whether to share the content between rvectorSrc and rvectorDest.
  ! = TRUE: Create a 'virtual' copy of rvectorSrc in rvectorDest that uses
  !         the same memory.
  ! =FALSE: Copy the sub-content of rvectorSrc to rvectorDest.
  LOGICAL, INTENT(IN), OPTIONAL :: bshare
!</input>

!<inputoutput>
    ! Destination block vector. Any previous data is discarded, so the
    ! application must take care of that no allocated handles are inside here!
    TYPE(t_vectorBlock), INTENT(OUT) :: rvectorDest
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER :: ifirst, ilast, ncount, i
    INTEGER(PREC_VECIDX) :: n
    LOGICAL :: bshareContent
    INTEGER(PREC_VECIDX), DIMENSION(MAX(rvectorSrc%nblocks,1)) :: Isize
    
    ! Evaluate the optional parameters
    ifirst = 1
    ilast = rvectorSrc%nblocks
    bshareContent = .FALSE.
    
    IF (PRESENT(ifirstSubvector)) THEN
      ifirst = MIN(MAX(ifirst,ifirstSubvector),ilast)
    END IF
    
    IF (PRESENT(ilastSubvector)) THEN
      ilast = MAX(MIN(ilast,ilastSubvector),ifirst)
    END IF
    
    IF (PRESENT(bshare)) THEN
      bshareContent = bshare
    END IF
    
    ! Let's start. At first, create a new vector based on the old, which contains
    ! only those subvectors specified in ifirst..ilast.
    ncount = ilast-ifirst+1
    Isize(1:ncount) = rvectorSrc%RvectorBlock(ifirst:ilast)%NEQ

    ! Data type
    rvectorDest%cdataType = rvectorDest%cdataType
    
    ! Initialise the sub-blocks. Save a pointer to the starting address of
    ! each sub-block.
    ! Denote in the subvector that the handle belongs to us - not to
    ! the subvector.
    ALLOCATE(rvectorDest%RvectorBlock(ncount))
    
    n=1
    DO i = 1,ncount
      IF (Isize(i) .GT. 0) THEN
        rvectorDest%RvectorBlock(i)%NEQ = Isize(i)
        rvectorDest%RvectorBlock(i)%iidxFirstEntry = n
        rvectorDest%RvectorBlock(i)%h_Ddata = rvectorSrc%h_Ddata
        rvectorDest%RvectorBlock(i)%cdataType = rvectorSrc%cdataType
        rvectorDest%RvectorBlock(i)%bisCopy = .TRUE.
        n = n+Isize(i)
      ELSE
        rvectorDest%RvectorBlock(i)%NEQ = 0
        rvectorDest%RvectorBlock(i)%iidxFirstEntry = 0
        rvectorDest%RvectorBlock(i)%h_Ddata = ST_NOHANDLE
      END IF
    END DO
    
    rvectorDest%NEQ = n-1
    rvectorDest%nblocks = ncount
    
    ! Next question: should we share the vector content or not?
    IF (.NOT. bshareContent) THEN
      ! Allocate a new large vector holding all data.
      CALL storage_new1D ('lsysbl_createVecBlockDirect', 'Vector', SUM(Isize), &
                          rvectorDest%cdataType, &
                          rvectorDest%h_Ddata, ST_NEWBLOCK_NOINIT)
      rvectorDest%RvectorBlock(1:ncount)%h_Ddata = rvectorDest%h_Ddata
    ELSE
      ! The new vector should be a subvector of the old one. 
      ! That means, we have to set the index of the first entry 
      ! in rvectorDest to the first entry of the specified first 
      ! subvector in rvectorSrc.
      rvectorDest%iidxFirstEntry = rvectorSrc%RvectorBlock(ifirst)%iidxFirstEntry
      
      ! Copy the data handle
      rvectorDest%h_Ddata = rvectorSrc%h_Ddata
      
      ! Furthermore, we have to shift the starting addresses in all
      ! subvectors such that they point to the correct place in the
      ! global vector.
      rvectorDest%RvectorBlock(1:ncount)%iidxFirstEntry = &
          rvectorDest%RvectorBlock(1:ncount)%iidxFirstEntry + &
          rvectorDest%iidxFirstEntry - 1
    END IF

    rvectorDest%bisCopy = bshareContent

    ! Everything is prepared, just copy -- either only the structure or
    ! the structure as well as the content.
    DO i=1,ncount
      CALL lsyssc_copyVector (rvectorSrc%RvectorBlock(i),rvectorDest%RvectorBlock(i),&
          .TRUE.,.NOT. bshareContent)
    END DO
    
  END SUBROUTINE 

  !****************************************************************************
  
!<subroutine>
  
  SUBROUTINE lsysbl_deriveSubmatrix (rsourceMatrix,rdestMatrix,&
                                     idupStructure, idupContent,&
                                     ifirstBlock,ilastBlock)
  
!<description>
  ! This routine derives a block matrix as a subset of another block matrix.
  !
  ! ifirstBlock is the number of the first diagonal block in rsourceMatrix
  ! which should be put to position (1,1) in rdestMatrix.
  ! ilastBlock is the index the last diagonal block in rdestMatrix
  ! which should be put to rdestMatrix
  !
  ! rvectorDest will therefore contain the submatrix
  ! (ifirstSubvector..ilastSubvector , ifirstSubvector..ilastSubvector)
  ! of rdestMatrix.
  !
  ! The newly created block vector will not have any block discretisation 
  ! structure attached!
  !
  ! Duplicating a matrix does not necessarily mean that new memory is
  ! allocated and the matrix entries are copied to that. The two flags
  ! idupStructure and idupContent decide on how to set up rdestMatrix.
  ! Depending on their setting, it's possible to copy only the handles
  ! of such dynamic information, so that both matrices share the same
  ! information.
  !
  ! We follow the following convention:
  !  Structure = Column structure, Row structure, Sorting permutation,
  !              Discretisation-related information
  !  Content   = Enties in a matrix.
  !
  ! Remark: There is never memory allocated on the heap for the sorting
  !  permutation. A matrix is never the 'owner' of a permutation, i.e.
  !  does not maintain it. Therefore, copying a permutation in one of
  !  the submatrices means copying the corresponding handle. 
  !  The application must keep track of the permutations.
!</description>
  
!<input>
  ! Source matrix.
  TYPE(t_matrixBlock), INTENT(IN)               :: rsourceMatrix
  
  ! OPTIONAL: Number of the block in rsourceMatrix that should be put to 
  ! position (1,1) into rdestMatrix. Default value is =1.
  INTEGER, INTENT(IN), OPTIONAL :: ifirstBlock

  ! OPTIONAL: Number of the last block in rsourceMatrix that should be put to 
  ! rdestMatrix. Default value is the number of blocks in rsourceMatrix.
  INTEGER, INTENT(IN), OPTIONAL :: ilastBlock

  ! Duplication flag that decides on how to set up the structure
  ! of rdestMatrix. This duplication flag is applied to all submatrices
  ! of rsourceMatrix.
  !
  ! One of the LSYSSC_DUP_xxxx flags:
  ! LSYSSC_DUP_IGNORE     : Don't set up the structure of rdestMatrix. Any
  !   matrix structure is ignored and therefore preserved.
  ! LSYSSC_DUP_REMOVE     : Removes any existing matrix structure from 
  !   rdestMatrix if there is any. Releases memory if necessary.
  !   Does not delete 'static' information like NEQ,NCOLS,NA,...
  ! LSYSSC_DUP_DISMISS    : Removes any existing matrix structure from 
  !   rdestMatrix if there is any. No memory is released, handles are simply
  !   dismissed. Does not delete 'static' information like NEQ,NCOLS,NA,...
  ! LSYSSC_DUP_SHARE      : rdestMatrix receives the same handles for
  !   structural data as rsourceMatrix and therefore shares the same structure.
  ! LSYSSC_DUP_COPY       : rdestMatrix gets a copy of the structure of 
  !   rsourceMatrix. If necessary, new memory is allocated for the structure. 
  !   If rdestMatrix already contains allocated memory, structural data
  !   is simply copied from rsourceMatrix into that.
  ! LSYSSC_DUP_ASIS       : Duplicate by ownership. If the structure of 
  !   rsourceMatrix belongs to rsourceMatrix, rdestMatrix gets a copy
  !   of the structure; new memory is allocated if necessary (the same as 
  !   LSYSSC_DUP_COPY). If the structure of rsourceMatrix belongs to another
  !   matrix than rsourceMatrix, rdestMatrix receives the same handles as
  !   rsourceMatrix and is therefore a third matrix sharing the same structure
  !   (the same as LSYSSC_DUP_SHARE, so rsourceMatrix, rdestMatrix and the 
  !   other matrix have the same structure).
  ! LSYSSC_DUP_EMPTY      : New memory is allocated for the structure in the
  !   same size as the structure in rsourceMatrix but no data is copied;
  !   the arrays are left uninitialised.
  ! LSYSSC_DUP_TEMPLATE   : Copies statis structural information about the
  !   structure (NEQ, NCOLS,...) to the destination matrix. Dynamic information
  !   is removed from the destination matrix, all handles are reset.
  INTEGER, INTENT(IN)                            :: idupStructure
  
  ! Duplication flag that decides on how to set up the content
  ! of rdestMatrix. This duplication flag is applied to all submatrices
  ! of rsourceMatrix.
  !
  ! One of the LSYSSC_DUP_xxxx flags:
  ! LSYSSC_DUP_IGNORE     : Don't set up the content of rdestMatrix. Any
  !   matrix content is ignored and therefore preserved.
  ! LSYSSC_DUP_REMOVE     : Removes any existing matrix content from 
  !   rdestMatrix if there is any. Releases memory if necessary.
  ! LSYSSC_DUP_DISMISS    : Removes any existing matrix content from 
  !   rdestMatrix if there is any. No memory is released, handles are simply
  !   dismissed.
  ! LSYSSC_DUP_SHARE      : rdestMatrix receives the same handles for
  !   matrix content data as rsourceMatrix and therefore shares the same content.
  ! LSYSSC_DUP_COPY       : rdestMatrix gets a copy of the content of rsourceMatrix.
  !   If necessary, new memory is allocated for the content.
  !   If rdestMatrix already contains allocated memory, content data
  !   is simply copied from rsourceMatrix into that.
  ! LSYSSC_DUP_ASIS       : Duplicate by ownership. If the content of 
  !   rsourceMatrix belongs to rsourceMatrix, rdestMatrix gets a copy
  !   of the content; new memory is allocated if necessary (the same as 
  !   LSYSSC_DUP_COPY). If the content of rsourceMatrix belongs to another
  !   matrix than rsourceMatrix, rdestMatrix receives the same handles as
  !   rsourceMatrix and is therefore a third matrix sharing the same content
  !   (the same as LSYSSC_DUP_SHARE, so rsourceMatrix, rdestMatrix and the 
  !   other matrix have the same content).
  ! LSYSSC_DUP_EMPTY      : New memory is allocated for the content in the
  !   same size as the structure in rsourceMatrix but no data is copied;
  !   the arrays are left uninitialised.
  ! LSYSSC_DUP_TEMPLATE   : Copies statis structural information about the
  !   structure (NEQ, NCOLS,...) to the destination matrix. Dynamic information
  !   is removed from the destination matrix, all handles are reset.
  INTEGER, INTENT(IN)                            :: idupContent
!</input>

!<output>
  ! Destination matrix. Any previous data is discarded, so the
  ! application must take care of that no allocated handles are inside here!
  TYPE(t_matrixBlock), INTENT(OUT)            :: rdestMatrix
!</output>  

!</subroutine>

    ! local variables
    INTEGER(PREC_MATIDX) :: i,j
    INTEGER :: ifirst, ilast
    
    ! Evaluate the optional parameters
    ifirst = 1
    ilast = rsourceMatrix%ndiagBlocks
    
    IF (PRESENT(ifirstBlock)) THEN
      ifirst = MIN(MAX(ifirst,ifirstBlock),ilast)
    END IF
    
    IF (PRESENT(ilastBlock)) THEN
      ilast = MAX(MIN(ilast,ilastBlock),ifirst)
    END IF
    
    ! For every submatrix in the source matrix, call the 'scalar' variant
    ! of duplicateMatrix. 
    ALLOCATE(rdestMatrix%RmatrixBlock((ilast-ifirst+1),(ilast-ifirst+1)))
    DO j=ifirst,ilast
      DO i=ifirst,ilast
        IF (rsourceMatrix%RmatrixBlock(i,j)%cmatrixFormat .NE. LSYSSC_MATRIXUNDEFINED) THEN
        
          CALL lsyssc_duplicateMatrix ( &
              rsourceMatrix%RmatrixBlock(i,j), &
              rdestMatrix%RmatrixBlock(i-ifirst+1,j-ifirst+1),&
              idupStructure, idupContent)
                                       
        END IF
      END DO
    END DO
    
    ! Update the structural information of the block matrix for completeness.
    CALL lsysbl_updateMatStrucInfo(rdestMatrix)
    
  END SUBROUTINE
    
  !****************************************************************************
  
!<function>
  
  ELEMENTAL LOGICAL FUNCTION lsysbl_isSubmatrixPresent (rmatrix, &
      irow,icolumn,bignoreScaleFactor) RESULT (bispresent)
  
!<description>
  ! This routine checks if the submatrix at position (irow,icolumn)
  ! is present in the matrix rmatrix or not.
!</description>
  
!<input>
  ! The block matrix.
  TYPE(t_matrixBlock), INTENT(IN)               :: rmatrix
  
  ! Submatrix row to be checked
  INTEGER, INTENT(IN) :: irow
  
  ! Submatrix column to be checked
  INTEGER, INTENT(IN) :: icolumn
  
  ! OPTIONAL: Whether to check the scaling factor.
  ! FALSE: A scaling factor of 0.0 disables a submatrix. 
  !        This is the standard setting.
  ! TRUE: The scaling factor is ignored.
  LOGICAL, INTENT(IN), OPTIONAL :: bignoreScaleFactor
!</input>

!<output>
  ! Whether the submatrix at position (irow,icolumn) exists or not.
!</output>  

!</function>
    LOGICAL :: bscale

    IF (PRESENT(bignoreScaleFactor)) THEN
      bscale = bignoreScaleFactor
    ELSE
      bscale = .FALSE.
    END IF

    bispresent = &
      (rmatrix%RmatrixBlock(irow,icolumn)%cmatrixFormat .NE. LSYSSC_MATRIXUNDEFINED) &
      .AND. (bscale .OR. &
             (rmatrix%RmatrixBlock(irow,icolumn)%dscaleFactor .NE. 0.0_DP))

  END FUNCTION

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_resizeVecBlockDirect (rx, Isize, bclear, NEQMAX)

!<description>
  ! Resize the vector block structure rx. Isize is an array
  ! of integers containing the length of the individual blocks.
  ! 
  ! Remark: If the vector structure rx is not initialized, then
  ! it cannot be resized and the routine stops with an error.
  ! If it exists already, then the total memory on the heap is
  ! reallocated if "SUM(Isize) > SIZE(rx)", that is, the new
  ! dimension of rx exceeds that of the old vectors. If the old
  ! vector is larger than the new one, then the dimensions of the
  ! subvectors are only adjusted without reallocation.
  ! If the optional parameter NEQMAX is specified, then this value
  ! is taken as upper bound for the total memory.
  !
  ! If the parameter bclear=.TRUE., then the resized vector is cleared.
  ! Otherwise it is left 'as is'.
  !
  ! Remark: In contrast to scalar vectors where the content of the vector
  ! can be copied upon resize this is not possible for block vectors.
  ! Theoretically, this would be possible. However, some subvectors may
  ! have increased whereas other may have decreased, so that an additional
  ! vector is mandatory to reorganize the global array. This is not efficient.
!</description>

!<input>
    
    ! An array with desired length-tags for the different blocks
    INTEGER(PREC_VECIDX), DIMENSION(:), INTENT(IN) :: Isize

    ! Whether to fill the vector with zero initially
    LOGICAL, INTENT(IN)                            :: bclear

    ! OPTIONAL: Maximum length of the vector
    INTEGER(PREC_VECIDX), INTENT(IN), OPTIONAL     :: NEQMAX

!</input>

!<inputoutput>

    ! Block vector structure
    TYPE(t_vectorBlock), INTENT(INOUT)             :: rx

!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER(PREC_VECIDX) :: iNEQ,iisize,i,n

    ! Check, that the vector is not a copy of another (possibly larger) vector
    IF (rx%bisCopy) THEN
      PRINT *, "lsysbl_resizeVecBlockDirect: A copied vector cannot be resized!"
      STOP
    END IF
    
    ! Check, if vector has been initialized before
    IF (rx%NEQ == 0 .OR. rx%h_Ddata == ST_NOHANDLE) THEN
      PRINT *, "lsysbl_resizeVecBlockDirect: A vector can only be resized &
          & uf it has been created correctly!"
      STOP
    END IF

    ! Update the global NEQ and set working dimensions
    rx%NEQ = MAX (0,SUM(Isize))
    iNEQ   = rx%NEQ
    IF (PRESENT(NEQMAX)) iNEQ = MAX(iNEQ,NEQMAX)

    ! Get current size of vector memory
    CALL storage_getsize(rx%h_Ddata, iisize)

    ! Do we really have to reallocate the vector physically?
    IF (rx%NEQ > iisize) THEN

      ! Yes, so adopt the new size. Note that some extra memory is
      ! allocated if the optional argument NEQMAX is specified
      iisize = iNEQ

      ! Reallocate the memory for handle h_Ddata
      CALL storage_realloc('lsysbl_resizeVecBlockDirect', iisize, rx%h_Ddata, &
          ST_NEWBLOCK_NOINIT, .FALSE.)  
      
    ELSEIF (PRESENT(NEQMAX)) THEN

      ! The available memory suffices for all componenets of the block vector.
      ! Let's check if the user supplied a new upper limit which makes it
      ! mandatory to "shrink" the allocated memory. Note that memory for at
      ! least NEQ=SUM(Isize) vector entries as allocated in any case.
      IF (iisize > iNEQ) THEN
        
        ! Compute new size, i.e. MAX(0,NEQ,NEQMAX)
        iisize = iNEQ

        IF (iisize == 0) THEN
          ! If nothing is left, then the vector can also be release
          CALL lsysbl_releaseVector(rx)
          RETURN
        ELSE
          ! Otherwise, 
          CALL storage_realloc('lsysbl_resizeVecBlockDirect', iisize, rx%h_Ddata, &
              ST_NEWBLOCK_NOINIT, .FALSE.)
        END IF
      END IF
    END IF
    
    ! Should the vector be cleared?
    IF (bclear) CALL storage_clear(rx%h_Ddata)
        
    ! Restore the structure of the scalar subvectors
    n=1
    DO i=1,rx%nblocks
      rx%RvectorBlock(i)%NEQ = Isize(i)
      rx%RvectorBlock(i)%iidxFirstEntry = n
      n = n + rx%RvectorBlock(i)%NEQ

      ! Remove any sorting strategy 
      rx%RvectorBlock(i)%isortStrategy      = 0
      rx%RvectorBlock(i)%h_iSortPermutation = ST_NOHANDLE
    END DO

  END SUBROUTINE lsysbl_resizeVecBlockDirect

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_resizeVecBlockDirectDims (rx, isize, bclear, NEQMAX)

!<description>
  ! Resize the vector block structure rx. Isize is an integer value
  ! which denotes the new length of all blocks of the global block vector.
  !
  ! Remark: If the vector structure rx is not initialized, then
  ! it cannot be resized and the routine stops with an error.
  ! If it exists already, then the total memory on the heap is
  ! reallocated if "(rx%nblocks*isize) > SIZE(rx)", that is, 
  ! the new dimension of rx exceeds that of the old vectors. If the old
  ! vector is larger than the new one, then the dimensions of the
  ! subvectors are only adjusted without reallocation.
  ! If the optional parameter NEQMAX is specified, then this value
  ! is taken as upper bound for the total memory.
  !
  ! If the parameter bclear=.TRUE., then the resized vector is cleared.
  ! Otherwise it is left 'as is'.
  !
  ! Remark: In contrast to scalar vectors where the content of the vector
  ! can be copied upon resize this is not possible for block vectors.
  ! Theoretically, this would be possible. However, some subvectors may
  ! have increased whereas other may have decreased, so that an additional
  ! vector is mandatory to reorganize the global array. This is not efficient.
!</description>

!<input>
    
    ! Integer with desired length of all vector blocks
    INTEGER(PREC_VECIDX), INTENT(IN) :: isize

    ! Whether to fill the vector with zero initially
    LOGICAL, INTENT(IN)                            :: bclear

    ! OPTIONAL: Maximum length of the vector
    INTEGER(PREC_VECIDX), INTENT(IN), OPTIONAL     :: NEQMAX

!</input>

!<inputoutput>

    ! Block vector structure
    TYPE(t_vectorBlock), INTENT(INOUT)             :: rx

!</inputoutput>

!</subroutine>
    
    ! local variabls
    INTEGER(PREC_VECIDX), DIMENSION(MAX(rx%nblocks,1)) :: Isubsize

    ! Fill auxiliary vector Iisize
    Isubsize(1:rx%nblocks) = isize

    ! Call the direct resize routine
    CALL lsysbl_resizeVecBlockDirect(rx, Isubsize(1:rx%nblocks), bclear, NEQMAX)
  END SUBROUTINE

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_resizeVecBlockIndirect (rx, rTemplate, bclear)

!<description>
  ! Resize the vector block structure rx so that is resembles that of
  ! the template vector. If rx has not been initialized, than it is
  ! initialized adopting the same memory layout as the template vector.
  !
  ! Remark: If the vector exists already, then the total memory on 
  ! the heap is reallocated if "SIZE(rTemplate) > SIZE(rx)", that is, 
  ! the new dimension of rx exceeds that of the old vectors. If the old
  ! vector is larger than the new one, then the dimensions of the
  ! subvectors are only adjusted without reallocation.
  !
  ! If the parameter bclear=.TRUE., then the resized vector is cleared.
  ! Otherwise it is left 'as is'.
  !
  ! Remark: In contrast to scalar vectors where the content of the vector
  ! can be copied upon resize this is not possible for block vectors.
  ! Theoretically, this would be possible. However, some subvectors may
  ! have increased whereas other may have decreased, so that an additional
  ! vector is mandatory to reorganize the global array. This is not efficient.
!</description>

!<input>

    ! Template block vector structure
    TYPE(t_vectorBlock), INTENT(IN)                :: rTemplate

    ! Whether to fill the vector with zero initially
    LOGICAL, INTENT(IN)                            :: bclear

!</input>

!<inputoutput>

    ! Block vector structure
    TYPE(t_vectorBlock), INTENT(INOUT)             :: rx

!</inputoutput>

!</subroutine>

    ! local variabls
    INTEGER(PREC_VECIDX), DIMENSION(MAX(rx%nblocks,1)) :: Isize
    INTEGER(PREC_VECIDX) :: NEQMAX
    INTEGER :: i

    ! Check if vector is initialized
    IF (rx%NEQ == 0 .OR. rx%h_Ddata == ST_NOHANDLE) THEN
      CALL lsysbl_createVectorBlock(rTemplate, rx, bclear)
      
    ELSE
      
      ! Check if vectors are compatible
      IF ((rx%cdataType /= rTemplate%cdataType) .OR. &
          (rx%nblocks /= rTemplate%nblocks)) THEN
        PRINT *, "lsysbl_resizeVecBlockIndirect: Vectors are incompatible!"
        STOP
      END IF

      ! Fill auxiliary vector Iisize
      DO i=1,rTemplate%nblocks
        Isize(i) = rTemplate%RvectorBlock(i)%NEQ
      END DO

      ! Get current size of global vector
      CALL storage_getsize(rTemplate%h_Ddata,NEQMAX)
      
      ! Resize vector directly
      CALL lsysbl_resizeVecBlockDirect(rx, Isize(1:rx%nblocks), bclear, NEQMAX)
    END IF

  END SUBROUTINE

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_resizeVecBlockIndMat (rtemplateMat, rx, bclear)

!<description>
    ! Resize the vector block structure rx so that it is compatible with
    ! the template matrix. If rx has not been initialized, than it is
    ! initialized adopting the same memory layout as the template matrix.
    !
    ! Remark: If the vector exists already, then the total memory on 
    ! the heap is reallocated if "rtemplateMat%NCOLS > SIZE(rx)", that is, 
    ! the new dimension of rx exceeds that of the old vector. If the old
    ! vector is larger than the new one, then the dimensions of the
    ! subvectors are only adjusted without reallocation.
    !
    ! If the parameter bclear=.TRUE., then the resized vector is cleared.
    ! Otherwise it is left 'as is'.
    !
    ! Remark: In contrast to scalar vectors where the content of the vector
    ! can be copied upon resize this is not possible for block vectors.
    ! Theoretically, this would be possible. However, some subvectors may
    ! have increased whereas other may have decreased, so that an additional
    ! vector is mandatory to reorganize the global array. This is not efficient.
!</description>

!<input>
    ! A template matrix structure
    TYPE(t_matrixBlock), INTENT(IN) :: rtemplateMat

    ! OPTIONAL: If set to TRUE, the vector will be filled with zero initially.
    ! Otherwise the content of rx is undefined.
    LOGICAL, INTENT(IN), OPTIONAL   :: bclear
!</input>

!<inputoutput>
    ! Block vector structure
    TYPE(t_vectorBlock), INTENT(INOUT) :: rx
!</inputoutput>

!</subroutine>

    ! local variables
    INTEGER(PREC_VECIDX) :: isize,i,j,n

    ! Check, that the vector is not a copy of another (possibly larger) vector
    IF (rx%bisCopy) THEN
      PRINT *, "lsysbl_resizeVecBlockIndMat: A copied vector cannot be resized!"
      STOP
    END IF

    ! Check if vector exists?
    IF (rx%NEQ == 0 .OR.&
        rx%h_DData == ST_NOHANDLE) THEN

      CALL lsysbl_createVecBlockIndMat(rtemplateMat,rx,bclear)

    ELSE
      
      ! Check if vector/matrix are compatible
      IF (rx%nblocks /= rtemplateMat%ndiagblocks) THEN
        PRINT *, "lsysbl_resizeVecBlockIndMat: Matrix/Vector incompatible!"
        STOP
      END IF

      ! Update the global NEQ
      rx%NEQ = rtemplateMat%NCOLS
      CALL storage_getsize(rx%h_Ddata, isize)

      ! Do we really have to reallocate the vector physically?
      IF (rx%NEQ > isize) THEN

        ! Yes, reallocate memory for handle h_Ddata
        CALL storage_realloc('lsysbl_resizeVecBlockIndMat', rx%NEQ, rx%h_Ddata, &
            ST_NEWBLOCK_NOINIT, .FALSE.)
      END IF

      n=1
      DO i = 1,rtemplateMat%ndiagBlocks
        ! Search for the first matrix in column i of the block matrix -
        ! this will give us information about the vector. Note that the
        ! diagonal blocks does not necessarily have to exist!
        DO j=1,rtemplateMat%ndiagBlocks
          
          ! Check if the matrix is not empty
          IF (rtemplateMat%RmatrixBlock(j,i)%NCOLS .GT. 0) THEN
            
            ! Found a template matrix we can use :-)
            rx%RvectorBlock(i)%NEQ = rtemplateMat%RmatrixBlock(j,i)%NCOLS
            
            ! Take the handle of the complete-solution vector, but set the index of
            ! the first entry to a value >= 1 - so that it points to the first
            ! entry in the global solution vector!
            rx%RvectorBlock(i)%h_Ddata = rx%h_Ddata
            rx%RvectorBlock(i)%iidxFirstEntry = n
            
            ! Give the vector the discretisation of the matrix
            rx%RvectorBlock(i)%p_rspatialDiscretisation => &
                rtemplateMat%RmatrixBlock(j,i)%p_rspatialDiscretisation
            
            ! Give the vector the same sorting strategy as the matrix, so that
            ! the matrix and vector get compatible. Otherwise, things
            ! like matrix vector multiplication won't work...
            rx%RvectorBlock(i)%isortStrategy = &
                rtemplateMat%RmatrixBlock(j,i)%isortStrategy
            rx%RvectorBlock(i)%h_IsortPermutation = &
                rtemplateMat%RmatrixBlock(j,i)%h_IsortPermutation
            
            ! Denote in the subvector that the handle belongs to us - not to
            ! the subvector.
            rx%RvectorBlock(i)%bisCopy = .TRUE.
            
            n = n+rtemplateMat%RmatrixBlock(j,i)%NCOLS
            
            ! Finish this loop, continue with the next column
            EXIT
            
          END IF
          
        END DO

        IF (j .GT. rtemplateMat%ndiagBlocks) THEN
          ! Let's hope this situation (an empty equation) never occurs - 
          ! might produce some errors elsewhere :)
          rx%RvectorBlock(i)%NEQ = 0
          rx%RvectorBlock(i)%iidxFirstEntry = 0
        END IF

      END DO
    END IF

    ! Transfer the boundary conditions and block discretisation pointers
    ! from the matrix to the vector.
    rx%p_rblockDiscretisation => rtemplateMat%p_rblockDiscretisation
    rx%p_rdiscreteBC     => rtemplateMat%p_rdiscreteBC
    rx%p_rdiscreteBCfict => rtemplateMat%p_rdiscreteBCfict
    
    ! Should the vector be cleared?
    IF (bclear) THEN
      CALL lsysbl_clearVector (rx)
    END IF
    
  END SUBROUTINE

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_infoVector(rvector)

!<description>
    ! This subroutine outputs information about the block vector
!</description>

!<input>
    ! block vector
    TYPE(t_vectorBlock), INTENT(IN) :: rvector
!</input>
!</subroutine>

    ! local variables
    INTEGER :: iblock

    DO iblock=1,rvector%nblocks
      CALL output_line ('Vector-block #'//TRIM(sys_siL(iblock,0)))
      CALL lsyssc_infoVector(rvector%RvectorBlock(iblock))
    END DO

  END SUBROUTINE lsysbl_infoVector

  !****************************************************************************

!<subroutine>

  SUBROUTINE lsysbl_infoMatrix(rmatrix)

!<description>
    ! This subroutine outputs information about the block matrix
!</description>

!<input>
    ! block matrix
    TYPE(t_matrixBlock) :: rmatrix
!</input>
!</subroutine>

    ! local variables
    INTEGER :: iblock,jblock
    
    CALL output_line ('Matrix is a ('&
        //TRIM(sys_siL(rmatrix%ndiagBlocks,3))//','&
        //TRIM(sys_siL(rmatrix%ndiagBlocks,3))//') matrix.')
    DO jblock=1,rmatrix%ndiagBlocks
      DO iblock=1,rmatrix%ndiagBlocks
        IF ((rmatrix%RmatrixBlock(iblock,jblock)%NEQ /= 0) .AND.&
            (rmatrix%RmatrixBlock(iblock,jblock)%NCOLS /= 0)) THEN
          CALL output_line ('Matrix-block #('//TRIM(sys_siL(iblock,2))//','//&
              TRIM(sys_siL(jblock,2))//')')
          CALL lsyssc_infoMatrix(rmatrix%RmatrixBlock(iblock,jblock))
        END IF
      END DO
    END DO
  END SUBROUTINE lsysbl_infoMatrix
  
END MODULE
