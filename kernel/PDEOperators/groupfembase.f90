!##############################################################################
!# ****************************************************************************
!# <name> groupfembase </name>
!# ****************************************************************************
!#
!# <purpose>
!#
!# This module contains a set of constant definitions and structures
!# which are used by the different group finite element modules.
!#
!# The following routines are available:
!#
!# 1.) gfem_initGroupFEMSet = gfem_initGFEMSetDirect /
!#                            gfem_initGFEMSetByMatrix
!#     -> Initialises a group finite element structure.
!#
!# 2.) gfem_initGroupFEMBlock
!#     -> Initialises a block of group finite element structures.
!#
!# 3.) gfem_releaseGroupFEMSet
!#     -> Releases a group finite element structure.
!#
!# 4.) gfem_releaseGroupFEMBlock
!#     -> Releases a block of group finite element structures.
!#
!# 5.) gfem_resizeGroupFEMSet = gfem_resizeGFEMSetDirect /
!#                              gfem_resizeGFEMSetByMatrix
!#     -> Resizes a group finite element structure.
!#
!# 6.) gfem_resizeGroupFEMBlock = gfem_resizeGFEMBlockDirect /
!#                                gfem_resizeGFEMBlockByMatrix
!#     -> Resizes a block of group finite element structures.
!#
!# 7.) gfem_copyGroupFEMSet
!#     -> Copies a group finite element structure to another structure
!#
!# 8.) gfem_copyGroupFEMBlock
!#     -> Copies a block of group finite element structures to another block
!#
!# 9.) gfem_duplicateGroupFEMSet
!#     -> Duplicates a group finite element structure
!#
!# 10.) gfem_duplicateGroupFEMBlock
!#      -> Duplicates a block of group finite element structures
!#
!# 11.)  gfem_initCoeffsFromMatrix
!#       -> Initialises precomputed coefficients from matrix
!#
!# 12.) gfem_isMatrixCompatible = gfem_isMatrixCompatibleSc /
!#                                gfem_isMatrixCompatibleBl
!#     -> Checks whether a matrix and a group finite element set are compatible
!#
!# 13.) gfem_isVectorCompatible = gfem_isVectorCompatibleSc /
!#                                gfem_isVectorCompatibleBl
!#     -> Checks whether a vector and a group finite element set are compatible
!#
!# 14.) gfem_getbase_IedgeListIdx
!#      -> Returns pointer to the index pointer for the edge list
!#
!# 15.) gfem_getbase_IedgeList
!#      -> Returns pointer to the edge list
!#
!# 16.) gfem_getbase_DcoeffsAtNode / gfem_getbase_FcoeffsAtNode
!#      -> Returns pointer to the coefficients at nodes
!#
!# 17.) gfem_getbase_DcoeffsAtEdge / gfem_getbase_FcoeffsAtEdge
!#      -> Returns pointer to the coefficients at edges
!#
!# 18.) gfem_genEdgeList
!#      -> Generates the edge list for a given matrix
!#
!# The following auxiliary routines are available:
!#
!# 1.) gfem_copyH2D_IedgeList
!#      -> Copies the edge structure from the host memory
!#         to the device memory.
!#
!# 2.) gfem_copyD2H_IedgeList
!#      -> Copies the edge structure from the device memory
!#         to the host memory.
!#
!# 3.) gfem_copyH2D_CoeffsAtNode
!#     -> Copies the coefficients at nodes from the host memory
!#        to the device memory.
!#
!# 4.) gfem_copyD2H_CoeffsAtNode
!#     -> Copies the coefficients at nodes from the device memory
!#        to the host  memory.
!#
!# 5.) gfem_copyH2D_CoeffsAtEdge
!#     -> Copies the coefficients at edges from the host memory
!#        to the device memory.
!#
!# 6.) gfem_copyD2H_CoeffsAtEdge
!#     -> Copies the coefficients at edges from the device memory
!#        to the host  memory.
!#
!# 7.) gfem_allocCoeffs = gfem_allocCoeffsDirect
!#                        gfem_allocCoeffsByMatrix
!#     -> Initialises memory for precomputed coefficients
!#
!# 8.) gfem_calcDimsFromMatrix
!#     -> Calculates dimensions NA, NEQ, and NEDGE from matrix
!#
!# </purpose>
!##############################################################################

module groupfembase

  use fsystem
  use genoutput
  use linearsystemscalar
  use linearsystemblock
  use storage

  implicit none

  private

  public :: t_groupFEMSet,t_groupFEMBlock
  public :: gfem_initGroupFEMSet
  public :: gfem_initGroupFEMBlock
  public :: gfem_releaseGroupFEMSet
  public :: gfem_releaseGroupFEMBlock
  public :: gfem_resizeGroupFEMBlock
  public :: gfem_copyGroupFEMSet
  public :: gfem_copyGroupFEMBlock
  public :: gfem_duplicateGroupFEMSet
  public :: gfem_duplicateGroupFEMBlock
  public :: gfem_initCoeffsFromMatrix
  public :: gfem_isMatrixCompatible
  public :: gfem_isVectorCompatible
  public :: gfem_getbase_IedgeListIdx
  public :: gfem_getbase_IedgeList
  public :: gfem_getbase_DcoeffsAtNode
  public :: gfem_getbase_DcoeffsAtEdge
  public :: gfem_genEdgeList

  public :: gfem_copyH2D_IedgeList
  public :: gfem_copyD2H_IedgeList
  public :: gfem_copyH2D_CoeffsAtNode
  public :: gfem_copyD2H_CoeffsAtNode
  public :: gfem_copyH2D_CoeffsAtEdge
  public :: gfem_copyD2H_CoeffsAtEdge
  public :: gfem_allocCoeffs
  public :: gfem_calcDimsFromMatrix

!<constants>
!<constantblock description="Global format flag for group FEM assembly">

  ! Assembly is undefined
  integer, parameter, public :: GFEM_UNDEFINED = 0

  ! Node-based assembly
  integer, parameter, public :: GFEM_NODEBASED = 1

  ! Edge-based assembly
  integer, parameter, public :: GFEM_EDGEBASED = 2
!</constantblock>


!<constantblock description="Bitfield identifiers for properties of the \
!                            group finite element set">

  ! Edge-based structure has been computed: IedgeListIdx, IedgeList
  integer(I32), parameter, public :: GFEM_HAS_EDGESTRUCTURE = 2_I32**1

  ! Nodal coefficient array has been computed: DcoeffsAtNode
  integer(I32), parameter, public :: GFEM_HAS_NODEDATA      = 2_I32**2

  ! Edge-based coefficient array has been computed: DcoeffsAtEdge
  integer(I32), parameter, public :: GFEM_HAS_EDGEDATA      = 2_I32**3
!</constantblock>


!<constantblock description="Duplication flags. Specifies which information is duplicated \
!                            between group finite element structures">
  
  ! Duplicate atomic structure
  integer(I32), parameter, public :: GFEM_DUP_STRUCTURE     = 2_I32**0

  ! Duplicate edge-based structure: IedgeListIdx, IedgeList
  integer(I32), parameter, public :: GFEM_DUP_EDGESTRUCTURE = GFEM_HAS_EDGESTRUCTURE

  ! Duplicate nodal coefficient array: DcoeffsAtNode
  integer(I32), parameter, public :: GFEM_DUP_NODEDATA      = GFEM_HAS_NODEDATA

  ! Duplicate edge-based coefficient array: DcoeffsAtEdge
  integer(I32), parameter, public :: GFEM_DUP_EDGEDATA      = GFEM_HAS_EDGEDATA
!</constantblock>


!<constantblock description="Duplication flags. Specifies which information is shared \
!                            between group finite element structures">
  
  ! Share atomic structure
  integer(I32), parameter, public :: GFEM_SHARE_STRUCTURE     = GFEM_DUP_STRUCTURE

  ! Share edge-based structure: IedgeListIdx, IedgeList
  integer(I32), parameter, public :: GFEM_SHARE_EDGESTRUCTURE = GFEM_DUP_EDGESTRUCTURE

  ! Share nodal coefficient array: DcoeffsAtNode
  integer(I32), parameter, public :: GFEM_SHARE_NODEDATA      = GFEM_DUP_NODEDATA

  ! Share edge-based coefficient array: DcoeffsAtEdge
  integer(I32), parameter, public :: GFEM_SHARE_EDGEDATA      = GFEM_DUP_EDGEDATA
!</constantblock>
!</constants>


!<types>
!<typeblock>

  ! This structure holds all required information to evaluate a set of
  ! degrees of freedom by the group finite element formulation.

  type t_groupFEMSet

    ! Format Tag: Identifies the type of assembly
    integer :: cassemblyType = GFEM_UNDEFINED

    ! Format Tag: Identifies the format of the scalar template matrix
    ! underlying the edge-based sparsity structure (if any)
    integer :: cmatrixFormat = LSYSSC_MATRIXUNDEFINED

    ! Format Tag: Identifies the data type
    integer :: cdataType = ST_DOUBLE

    ! Duplication Flag: This is a bitfield coming from an OR
    ! combination of different GFEM_SHARE_xxxx constants and
    ! specifies which parts of the structure are shared with
    ! another structure.
    integer(I32) :: iduplicationFlag = 0

    ! Specification Flag: Specifies the group finite element set. This
    ! is a bitfield coming from an OR combination of different
    ! GFEM_HAS_xxxx constants and specifies various properties of the
    ! structure.
    integer(I32) :: isetSpec = 0
    
    ! Number of non-zero entries of the sparsity pattern
    integer :: NA = 0

    ! Number of equations of the sparsity pattern
    integer :: NEQ = 0

    ! Number of edges of the sparsity pattern
    integer :: NEDGE = 0

    ! Number of local variables; in general scalar solution vectors of
    ! size NEQ posses NEQ entries. However, scalar vectors can be
    ! interleaved, that is, each of the NEQ entries stores NVAR local
    ! variables. In this case, NEQ remains unmodified but NVAR>1 such
    ! that the physical length of the vector is NEQ*NVAR.
    integer :: NVAR = 1

    ! Number of precomputed coefficients stored DcoeffsAtNode.
    integer :: ncoeffsAtNode = 0

    ! Number of precomputed coefficients stored DcoeffsAtEdge.
    integer :: ncoeffsAtEdge = 0

    ! Handle to index pointer for edge structure
    ! The numbers IedgeListIdx(k):IedgeListIdx(k+1)-1
    ! denote the edge numbers of the k-th group of edges.
    integer :: h_IedgeListIdx = ST_NOHANDLE

    ! Handle to edge structure
    ! IedgeList(1:2,1:NEDGE) : the two end-points of the edge
    ! IedgeList(3:4,1:NEDGE) : the two matrix position that
    !                                correspond to the edge
    integer :: h_IedgeList = ST_NOHANDLE

    ! Handle to precomputed coefficients at nodes
    integer :: h_CoeffsAtNode = ST_NOHANDLE

    ! Handle to precomputed coefficients at edges
    integer :: h_CoeffsAtEdge = ST_NOHANDLE
  end type t_groupFEMSet
!</typeblock>


!<typeblock>

  ! This structure holds multiple sets of degrees of freedom
  
  type t_groupFEMBlock

    ! Number of blocks
    integer :: nblocks = 0

    ! A 1D array with sets of degrees of freedom
    type(t_groupFEMSet), dimension(:), pointer :: RgroupFEMBlock => null() 

  end type t_groupFEMBlock
!</typeblock>
!</types>


  interface gfem_initGroupFEMSet
    module procedure gfem_initGFEMSetDirect
    module procedure gfem_initGFEMSetByMatrix
  end interface gfem_initGroupFEMSet

  interface gfem_resizeGroupFEMSet
    module procedure gfem_resizeGFEMSetDirect
    module procedure gfem_resizeGFEMSetByMatrix
  end interface

  interface gfem_resizeGroupFEMBlock
    module procedure gfem_resizeGFEMBlockDirect
    module procedure gfem_resizeGFEMBlockByMatrix
  end interface

  interface gfem_isMatrixCompatible
    module procedure gfem_isMatrixCompatibleSc
    module procedure gfem_isMatrixCompatibleBl
  end interface

  interface gfem_isVectorCompatible
    module procedure gfem_isVectorCompatibleSc
    module procedure gfem_isVectorCompatibleBl
  end interface

  interface gfem_allocCoeffs
    module procedure gfem_allocCoeffsDirect
    module procedure gfem_allocCoeffsByMatrix
  end interface

contains

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_initGFEMSetDirect(rgroupFEMSet, NA, NEQ, NEDGE, NVAR,&
      ncoeffsAtNode, ncoeffsAtEdge, cassembly, cdataType)

!<description>
    ! This subroutine initialises a set of degrees of freedom for
    ! using the group finite element formulation directly. By setting
    ! some parameters to zero, some internla data structures are not
    ! generated which can be postponed to other subroutine calls.
!</description>

!<input>
    ! Number of non-zero entries
    integer, intent(in) :: NA

    ! Number of equations
    integer, intent(in) :: NEQ

    ! Number of edges
    integer, intent(in) :: NEDGE
    
    ! Number of local variables
    integer, intent(in) :: NVAR

    ! Number of precomputed coefficients
    integer, intent(in) :: ncoeffsAtNode
    integer, intent(in) :: ncoeffsAtEdge

    ! Type of assembly
    integer, intent(in) :: cassembly

    ! OPTIONAL: data type
    ! If not present, ST_DOUBLE will be used
    integer, intent(in), optional :: cdataType
!</input>

!<output>
    ! Group finite element set
    type(t_groupFEMSet), intent(out) :: rgroupFEMSet
!</output>
!</subroutine>

    ! Set data
    rgroupFEMSet%NA            = NA
    rgroupFEMSet%NEQ           = NEQ
    rgroupFEMSet%NEDGE         = NEDGE
    rgroupFEMSet%cassemblyType = cassembly
    rgroupFEMSet%cdataType     = ST_DOUBLE
    if (present(cdataType))&
        rgroupFEMSet%cdataType = cdataType

    ! Allocate memory for precomputed coefficients; if some of the
    ! necessary data is not available, no memory will be allocated
    call gfem_allocCoeffs(rgroupFEMSet, ncoeffsAtNode, ncoeffsAtEdge)

  end subroutine gfem_initGFEMSetDirect

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_initGFEMSetByMatrix(rgroupFEMSet, rmatrix, ncoeffsAtNode,&
      ncoeffsAtEdge, cassembly, cdataType, IdofList)

!<description>
    ! This subroutine initialises a set of degrees of freedom for
    ! using the group finite element formulation indirectly by
    ! deriving all information from the scalar template matrix.
    ! If IdofList is given, then its entries are used as degrees
    ! of freedom to which the group finite elment set should be
    ! restricted to.
!</description>

!<input>
    ! Scalar template matrix
    type(t_matrixScalar), intent(in) :: rmatrix

    ! Number of precomputed coefficients
    integer, intent(in) :: ncoeffsAtNode
    integer, intent(in) :: ncoeffsAtEdge

    ! Type of assembly
    integer, intent(in) :: cassembly

    ! OPTIONAL: data type
    ! If not present, ST_DOUBLE will be used
    integer, intent(in), optional :: cdataType

    ! OPTIONAL: a list of degress of freedoms to which the edge
    ! structure should be restricted.
    integer, dimension(:), intent(in), optional :: IdofList
!</input>

!<output>
    ! group finite element set
    type(t_groupFEMSet), intent(out) :: rgroupFEMSet
!</output>
!</subroutine>

    ! local variables
    integer :: na,nedge,neq

    ! Calculate dimensions of matrix (possible with restriction)
    call gfem_calcDimsFromMatrix(rmatrix, na, neq, nedge, IdofList)
    
    ! Call initialisation routine
    call gfem_initGroupFEMSet(rgroupFEMSet, na, neq, nedge,&
        rmatrix%NVAR, ncoeffsAtNode, ncoeffsAtEdge, cassembly, cdataType)
    
  end subroutine gfem_initGFEMSetByMatrix

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_initGroupFEMBlock(rgroupFEMBlock, nblocks)

!<description>
    ! This subroutine initialises a block of group finite element sets.
    ! If rgroupFEMBlock has already some blocks associated, then the
    ! array is re-allocated internally and data is copied accordingly.
!</description>

!<input>
    ! Number of blocks
    integer, intent(in) :: nblocks
!</input>

!<inputoutput>
    ! Block of group finite element sets
    type(t_groupFEMBlock), intent(inout) :: rgroupFEMBlock
!</inputoutput>

    ! local variables
    type(t_groupFEMSet), dimension(:), allocatable :: p_RgroupFEMBlock
    integer :: i

    if (rgroupFEMBlock%nblocks .eq. 0) then
      rgroupFEMBlock%nblocks = nblocks
      allocate(rgroupFEMBlock%RgroupFEMBlock(nblocks))
    else
      ! Make backup of group finite element sets
      allocate(p_RgroupFEMBlock(rgroupFEMBlock%nblocks))
      do i = 1, rgroupFEMBlock%nblocks
        p_RgroupFEMBlock(i) = rgroupFEMBlock%RgroupFEMBlock(i)
      end do

      ! Re-allocate memory
      deallocate(rgroupFEMBlock%RgroupFEMBlock)
      allocate(rgroupFEMBlock%RgroupFEMBlock(nblocks))
      
      ! Copy data from backup
      do i = 1, min(nblocks,rgroupFEMBlock%nblocks)
        rgroupFEMBlock%RgroupFEMBlock(i) = p_RgroupFEMBlock(i)
      end do

      ! Deallocate backup
      deallocate(p_RgroupFEMBlock)

      ! Set new blocksize
      rgroupFEMBlock%nblocks = nblocks
    end if

  end subroutine gfem_initGroupFEMBlock

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_releaseGroupFEMSet(rgroupFEMSet)

!<description>
    ! This subroutine releases a group finite element set
!</description>

!<inputoutput>
    ! group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSet
!</inputoutput>
!</subroutine>

    ! Release edge structure
    if (check(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_EDGESTRUCTURE)) then
      if (rgroupFEMSet%h_IedgeList .ne. ST_NOHANDLE)&
          call storage_free(rgroupFEMSet%h_IedgeList)
      if (rgroupFEMSet%h_IedgeListIdx .ne. ST_NOHANDLE)&
          call storage_free(rgroupFEMSet%h_IedgeListIdx)
    end if
    rgroupFEMSet%h_IedgeList = ST_NOHANDLE
    rgroupFEMSet%h_IedgeListIdx = ST_NOHANDLE

    ! Release precomputed coefficients at nodes
    if (check(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_NODEDATA)) then
      if (rgroupFEMSet%h_CoeffsAtNode .ne. ST_NOHANDLE)&
          call storage_free(rgroupFEMSet%h_CoeffsAtNode)
    end if
    rgroupFEMSet%h_CoeffsAtNode = ST_NOHANDLE

    ! Release precomputed coefficients at edges
    if (check(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_EDGEDATA)) then
      if (rgroupFEMSet%h_CoeffsAtEdge .ne. ST_NOHANDLE)&
          call storage_free(rgroupFEMSet%h_CoeffsAtEdge)
    end if
    rgroupFEMSet%h_CoeffsAtEdge = ST_NOHANDLE

    ! Reset ownerships
    rgroupFEMSet%iduplicationFlag = iand(rgroupFEMSet%iduplicationFlag,&
                                         not(GFEM_SHARE_EDGESTRUCTURE))
    rgroupFEMSet%iduplicationFlag = iand(rgroupFEMSet%iduplicationFlag,&
                                         not(GFEM_SHARE_NODEDATA))
    rgroupFEMSet%iduplicationFlag = iand(rgroupFEMSet%iduplicationFlag,&
                                         not(GFEM_SHARE_EDGEDATA))

    ! Reset specification
    rgroupFEMSet%isetSpec = iand(rgroupFEMSet%isetSpec,&
                                 not(GFEM_HAS_EDGESTRUCTURE))
    rgroupFEMSet%isetSpec = iand(rgroupFEMSet%isetSpec,&
                                 not(GFEM_HAS_NODEDATA))
    rgroupFEMSet%isetSpec = iand(rgroupFEMSet%isetSpec,&
                                 not(GFEM_HAS_EDGEDATA))

    ! Reset data
    rgroupFEMSet%cassemblyType = GFEM_UNDEFINED
    rgroupFEMSet%cmatrixFormat = LSYSSC_MATRIXUNDEFINED
    rgroupFEMSet%cdataType     = ST_DOUBLE
    rgroupFEMSet%NA    = 0
    rgroupFEMSet%NEQ   = 0
    rgroupFEMSet%NEDGE = 0
    rgroupFEMSet%NVAR  = 1
    rgroupFEMSet%ncoeffsAtNode = 0
    rgroupFEMSet%ncoeffsAtEdge = 0

  contains

    !**************************************************************
    ! Checks if bitfield ibitfield in iflag is not set.
    
    pure function check(iflag, ibitfield)
      
      integer(I32), intent(in) :: iflag,ibitfield
      
      logical :: check
      
      check = (iand(iflag,ibitfield) .ne. ibitfield)
      
    end function check
    
  end subroutine gfem_releaseGroupFEMSet

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_releaseGroupFEMBlock(rgroupFEMBlock)

!<description>
    ! This subroutine releases a block of group finite element sets
!</description>

!<inputoutput>
    ! group finite element block
    type(t_groupFEMBlock), intent(inout) :: rgroupFEMBlock
!</inputoutput>
!</subroutine>

    ! local variables
    integer :: i

    if (rgroupFEMBlock%nblocks > 0) then
      do i = 1, rgroupFEMBlock%nblocks
        call gfem_releaseGroupFEMSet(rgroupFEMBlock%RgroupFEMBlock(i))
      end do
      
      deallocate(rgroupFEMBlock%RgroupFEMBlock)
    end if
    
    rgroupFEMBlock%nblocks = 0

  end subroutine gfem_releaseGroupFEMBlock

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_resizeGFEMSetDirect(rgroupFEMSet, NA, NEQ, NEDGE)

!<description>
    ! This subroutine resizes a set of degrees of freedom for
    ! using the group finite element formulation directly.
!</description>

!<input>
    ! Number of non-zero entries
    integer, intent(in) :: NA

    ! Number of equations
    integer, intent(in) :: NEQ

    ! Number of edges
    integer, intent(in) :: NEDGE   
!</input>

!<inputoutput>
    ! group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSet
!</inputoutput>
!</subroutine>
  
    ! Resize non-zero entries
    if (rgroupFEMSet%NA .ne. NA) then

      ! Set new number of nonzero entries
      rgroupFEMSet%NA = NA
      
      if (rgroupFEMSet%cassemblyType .eq. GFEM_NODEBASED) then
        if (check(rgroupFEMSet%isetSpec, GFEM_HAS_NODEDATA)) then
          if (check(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_NODEDATA)) then
            call output_line('Handle h_CoeffsAtNode '//&
                'is shared and cannot be resized!',&
                OU_CLASS_WARNING,OU_MODE_STD,'gfem_resizeGFEMSetDirect')
          else
            call storage_realloc('gfem_resizeGFEMSetDirect',&
                rgroupFEMSet%NA, rgroupFEMSet%h_CoeffsAtNode,&
                ST_NEWBLOCK_NOINIT, .false.)
            
            ! Reset specifiert
            rgroupFEMSet%isetSpec = iand(rgroupFEMSet%isetSpec,&
                                         not(GFEM_HAS_NODEDATA))
          end if
        end if
      end if
    end if

    ! Resize nodal quantities
    if (rgroupFEMSet%NEQ .ne. NEQ) then
      
      ! Set new number of nodes
      rgroupFEMSet%NEQ = NEQ

      if (rgroupFEMSet%cassemblyType .eq. GFEM_EDGEBASED) then
        if (check(rgroupFEMSet%isetSpec, GFEM_HAS_NODEDATA)) then
          if (check(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_NODEDATA)) then
            call output_line('Handle h_CoeffsAtNode '//&
                'is shared and cannot be resized!',&
                OU_CLASS_WARNING,OU_MODE_STD,'gfem_resizeGFEMSetDirect')
          else
            call storage_realloc('gfem_resizeGFEMSetDirect',&
                rgroupFEMSet%NEQ, rgroupFEMSet%h_CoeffsAtNode,&
                ST_NEWBLOCK_NOINIT, .false.)
            
            ! Reset specifiert
            rgroupFEMSet%isetSpec = iand(rgroupFEMSet%isetSpec,&
                                         not(GFEM_HAS_NODEDATA))
          end if
        end if
      end if
    end if


    ! Resize edge-based quantities
    if (rgroupFEMSet%NEDGE .ne. NEDGE) then
      
      ! Set new number of edges
      rgroupFEMSet%NEDGE = NEDGE

      if (check(rgroupFEMSet%isetSpec, GFEM_HAS_EDGESTRUCTURE)) then
        if (check(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_EDGESTRUCTURE)) then
          call output_line('Handle h_IedgeList '//&
              'is shared and cannot be resized!',&
              OU_CLASS_WARNING,OU_MODE_STD,'gfem_resizeGFEMSetDirect')
        else
          ! Resize array
          call storage_realloc('gfem_resizeGFEMSetDirect',&
              rgroupFEMSet%NEDGE, rgroupFEMSet%h_IedgeList,&
              ST_NEWBLOCK_NOINIT, .false.)
          
          ! Reset specifiert
          rgroupFEMSet%isetSpec = iand(rgroupFEMSet%isetSpec,&
                                       not(GFEM_HAS_EDGESTRUCTURE))
        end if
      end if

      if (check(rgroupFEMSet%isetSpec, GFEM_HAS_EDGEDATA)) then
        if (check(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_EDGEDATA)) then
          call output_line('Handle h_CoeffsAtEdge '//&
              'is shared and cannot be resized!',&
              OU_CLASS_WARNING,OU_MODE_STD,'gfem_resizeGFEMSetDirect')
        else
          ! Reseiz array
          call storage_realloc('gfem_resizeGFEMSetDirect',&
              rgroupFEMSet%NEDGE, rgroupFEMSet%h_CoeffsAtEdge,&
              ST_NEWBLOCK_NOINIT, .false.)

          ! Reset specifiert
          rgroupFEMSet%isetSpec = iand(rgroupFEMSet%isetSpec,&
                                       not(GFEM_HAS_EDGEDATA))
        end if
      end if
    end if

  contains

    !**************************************************************
    ! Checks if bitfield ibitfield in iflag is set.
    
    pure function check(iflag, ibitfield)

      integer(I32), intent(in) :: iflag,ibitfield
      
      logical :: check
      
      check = (iand(iflag,ibitfield) .eq. ibitfield)

    end function check

  end subroutine gfem_resizeGFEMSetDirect
  
  ! ***************************************************************************

!<subroutine>

  subroutine gfem_resizeGFEMSetByMatrix(rgroupFEMSet, rmatrix, IdofList)

!<description>
    ! This subroutine resizes a set of degrees of freedom for
    ! using the group finite element formulation indirectly by
    ! deriving all information from the scalar template matrix.
    ! If IdofList is given, then its entries are used as degrees
    ! of freedom to which the group finite elment set should be
    ! restricted to.
!</description>

!<input>
    ! Scalar template matrix
    type(t_matrixScalar), intent(in) :: rmatrix

    ! OPTIONAL: a list of degress of freedoms to which the edge
    ! structure should be restricted.
    integer, dimension(:), intent(in), optional :: IdofList
!</input>

!<inputoutput>
    ! group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSet
!</inputoutput>
!</subroutine>

    ! local variables
    integer :: na,neq,nedge

    ! Calculate dimensions of matrix (possible with restriction)
    call gfem_calcDimsFromMatrix(rmatrix, na, neq, nedge, IdofList)

    ! Call resize routine
    call gfem_resizeGroupFEMSet(rgroupFEMSet, rmatrix%NA, rmatrix%NEQ, nedge)

  end subroutine gfem_resizeGFEMSetByMatrix

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_resizeGFEMBlockDirect(rgroupFEMBlock, NA, NEQ, NEDGE)

!<description>
    ! This subroutine resizes block of sets of degrees of freedom for
    ! using the group finite element formulation directly.
!</description>

!<input>
    ! Number of non-zero entries
    integer, intent(in) :: NA

    ! Number of equations
    integer, intent(in) :: NEQ

    ! Number of edges
    integer, intent(in) :: NEDGE   
!</input>

!<inputoutput>
    ! Block of group finite element sets
    type(t_groupFEMBlock), intent(inout) :: rgroupFEMBlock
!</inputoutput>
!</subroutine>

    ! local variables
    integer :: i
    
    do i = 1, rgroupFEMBlock%nblocks
      call gfem_resizeGroupFEMSet(rgroupFEMBlock%RgroupFEMBlock(i), NA, NEQ, NEDGE)
    end do
  
  end subroutine gfem_resizeGFEMBlockDirect

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_resizeGFEMBlockByMatrix(rgroupFEMBlock, rmatrix, IdofList)

!<description>
    ! This subroutine resizes a block of sets of degrees of freedom
    ! for using the group finite element formulation indirectly by
    ! deriving all information from the scalar template matrix.
    ! If IdofList is given, then its entries are used as degrees
    ! of freedom to which the group finite elment set should be
    ! restricted to.
!</description>

!<input>
    ! Scalar template matrix
    type(t_matrixScalar), intent(in) :: rmatrix
    
    ! OPTIONAL: a list of degress of freedoms to which the edge
    ! structure should be restricted.
    integer, dimension(:), intent(in), optional :: IdofList
!</input>

!<inputoutput>
    ! Block of group finite element sets
    type(t_groupFEMBlock), intent(inout) :: rgroupFEMBlock
!</inputoutput>
!</subroutine>

    ! local variables
    integer :: i
    
    do i = 1, rgroupFEMBlock%nblocks
      call gfem_resizeGroupFEMSet(rgroupFEMBlock%RgroupFEMBlock(i), rmatrix, IdofList)
    end do

  end subroutine gfem_resizeGFEMBlockByMatrix

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_copyGroupFEMSet(rgroupFEMSetSrc, rgroupFEMSetDest, idupFlag,&
      bpreserveContent)

!<description>
    ! This subroutine selectively copies data from the source
    ! structure rgroupFEMSetSrc to the destination structure
    ! rgroupFEMSetDest. If the optional flag bpreserveContent
    ! is set to TRUE, then the existing content is not removed
    ! before copying some content from the source structure.
!<description>

!<input>
    ! Source group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSetSrc

    ! Duplication flag that decides on how to set up the structure
    integer(I32), intent(in) :: idupFlag

    ! OPTIONAL: Flag to force that existing content is preserved
    logical, intent(in), optional :: bpreserveContent
!</input>

!<inputoutput>
    ! Destination group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSetDest
!</inputoutput>
!</subroutine>

    ! local variables
    logical :: bclear

    ! Clear destination structre unless preservation of existing
    ! content is explicitly enforced by the calling routine
    bclear = .true.
    if (present(bpreserveContent)) bclear=.not.bpreserveContent
    if (bclear) call gfem_releaseGroupFEMSet(rgroupFEMSetDest)

    ! Copy structural data
    if (check(idupFlag, GFEM_DUP_STRUCTURE)) then
      rgroupFEMSetDest%cassemblyType = rgroupFEMSetSrc%cassemblyType
      rgroupFEMSetDest%cmatrixFormat = rgroupFEMSetSrc%cmatrixFormat
      rgroupFEMSetDest%cdataType     = rgroupFEMSetSrc%cdataType
      rgroupFEMSetDest%isetSpec      = rgroupFEMSetSrc%isetSpec
      rgroupFEMSetDest%NA            = rgroupFEMSetSrc%NA
      rgroupFEMSetDest%NEQ           = rgroupFEMSetSrc%NEQ
      rgroupFEMSetDest%NEDGE         = rgroupFEMSetSrc%NEDGE
      rgroupFEMSetDest%NVAR          = rgroupFEMSetSrc%NVAR
      rgroupFEMSetDest%ncoeffsAtNode = rgroupFEMSetSrc%ncoeffsAtNode
      rgroupFEMSetDest%ncoeffsAtEdge = rgroupFEMSetSrc%ncoeffsAtEdge
    end if

    ! Copy edge structure
    if (check(idupFlag, GFEM_DUP_EDGESTRUCTURE)) then
      ! Remove existing data owned by the destination structure
      if (.not.(check(rgroupFEMSetDest%iduplicationFlag,&
                      GFEM_SHARE_EDGESTRUCTURE))) then
        call storage_free(rgroupFEMSetDest%h_IedgeListIdx)
        call storage_free(rgroupFEMSetDest%h_IedgeList)
      end if

      ! Copy content from source to destination structure
      call storage_copy(rgroupFEMSetSrc%h_IedgeListIdx,&
          rgroupFEMSetDest%h_IedgeListIdx)
      call storage_copy(rgroupFEMSetSrc%h_IedgeList,&
          rgroupFEMSetDest%h_IedgeList)

      ! Adjust specifier of the destination structure
      rgroupFEMSetDest%isetSpec = ior(rgroupFEMSetDest%isetSpec,&
          iand(rgroupFEMSetSrc%isetSpec, GFEM_HAS_EDGESTRUCTURE))
      
      ! Reset ownership
      rgroupFEMSetDest%iduplicationFlag =&
          iand(rgroupFEMSetDest%iduplicationFlag, not(GFEM_SHARE_EDGESTRUCTURE))
    end if

    ! Copy coefficients at nodes
    if (check(idupFlag, GFEM_DUP_NODEDATA)) then
      ! Remove existing data owned by the destination structure
      if (.not.(check(rgroupFEMSetDest%iduplicationFlag,&
                      GFEM_SHARE_NODEDATA))) then
        call storage_free(rgroupFEMSetDest%h_CoeffsAtNode)
      end if

      ! Copy content from source to destination structure
      call storage_copy(rgroupFEMSetSrc%h_CoeffsAtNode,&
          rgroupFEMSetDest%h_CoeffsAtNode)

      ! Adjust specifier of the destination structure
      rgroupFEMSetDest%isetSpec = ior(rgroupFEMSetDest%isetSpec,&
          iand(rgroupFEMSetSrc%isetSpec, GFEM_HAS_NODEDATA))
      
      ! Reset ownership
      rgroupFEMSetDest%iduplicationFlag =&
          iand(rgroupFEMSetDest%iduplicationFlag, not(GFEM_SHARE_NODEDATA))
    end if

    ! Copy coefficients at edges
    if (check(idupFlag, GFEM_DUP_EDGEDATA)) then
      ! Remove existing data owned by the destination structure
      if (.not.(check(rgroupFEMSetDest%iduplicationFlag,&
                      GFEM_SHARE_EDGEDATA))) then
        call storage_free(rgroupFEMSetDest%h_CoeffsAtEdge)
      end if

      ! Copy content from source to destination structure
      call storage_copy(rgroupFEMSetSrc%h_CoeffsAtEdge,&
          rgroupFEMSetDest%h_CoeffsAtEdge)

      ! Adjust specifier of the destination structure
      rgroupFEMSetDest%isetSpec = ior(rgroupFEMSetDest%isetSpec,&
          iand(rgroupFEMSetSrc%isetSpec, GFEM_HAS_EDGEDATA))
      
      ! Reset ownership
      rgroupFEMSetDest%iduplicationFlag =&
          iand(rgroupFEMSetDest%iduplicationFlag, not(GFEM_SHARE_EDGEDATA))
    end if

  contains

    !**************************************************************
    ! Checks if idupFlag has all bits ibitfield set.

    pure function check(idupFlag, ibitfield)
      
      integer(I32), intent(in) :: idupFlag,ibitfield
      
      logical :: check
      
      check = (iand(idupFlag,ibitfield) .eq. ibitfield)

    end function check

  end subroutine gfem_copyGroupFEMSet

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_copyGroupFEMBlock(rgroupFEMBlockSrc, rgroupFEMBlockDest, idupFlag)

!<description>
    ! This subroutine selectively copies data from the source
    ! structure rgroupFEMBlockSrc to the destination structure
    ! rgroupFEMBlockDest.
!<description>

!<input>
    ! Source block of group finite element sets
    type(t_groupFEMBlock), intent(in) :: rgroupFEMBlockSrc

    ! Duplication flag that decides on how to set up the structure
    integer(I32), intent(in) :: idupFlag
!</input>

!<inputoutput>
    ! Destination block of group finite element sets
    type(t_groupFEMBlock), intent(inout) :: rgroupFEMBlockDest
!</inputoutput>
!</subroutine>

    ! local variables
    integer :: i

    ! Check if block structure needs to be (re-)allocated
    if (rgroupFEMBlockSrc%nblocks .ne. rgroupFEMBlockDest%nblocks) then
      call gfem_releaseGroupFEMBlock(rgroupFEMBlockDest)
      rgroupFEMBlockDest%nblocks = rgroupFEMBlockSrc%nblocks
      allocate(rgroupFEMBlockDest%RgroupFEMBlock(rgroupFEMBlockDest%nblocks))
    end if
    
    do i = 1, rgroupFEMBlockSrc%nblocks
      call gfem_copyGroupFEMSet(rgroupFEMBlockSrc%RgroupFEMBlock(i),&
          rgroupFEMBlockDest%RgroupFEMBlock(i), idupFlag)
    end do
    
  end subroutine gfem_copyGroupFEMBlock

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_duplicateGroupFEMSet(rgroupFEMSetSrc, rgroupFEMSetDest,&
      idupFlag, bpreserveContent)

!<description>
    ! This subroutine duplicates parts of the source structure
    ! rgroupFEMSetSrc in the destination structure rgroupFEMSetDest.
    ! Note that rgroupFEMSetScr is still the owner of the duplicated
    ! content. If the optional flag bpreserveContent is set to TRUE,
    ! then the existing content is not removed before copying some
    ! content from the source structure.
!<description>

!<input>
    ! Source group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSetSrc

    ! Duplication flag that decides on how to set up the structure
    integer(I32), intent(in) :: idupFlag

    ! OPTIONAL: Flag to force that existing content is preserved
    logical, intent(in), optional :: bpreserveContent
!</input>

!<inputoutput>
    ! Destination group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSetDest
!</inputoutput>
!</subroutine>

    ! local variables
    logical :: bclear

    ! Clear destination structre unless preservation of existing
    ! content is explicitly enforced by the calling routine
    bclear = .true.
    if (present(bpreserveContent)) bclear=.not.bpreserveContent
    if (bclear) call gfem_releaseGroupFEMSet(rgroupFEMSetDest)

    ! Copy structural data
    if (check(idupFlag, GFEM_DUP_STRUCTURE)) then
      rgroupFEMSetDest%cassemblyType = rgroupFEMSetSrc%cassemblyType
      rgroupFEMSetDest%cmatrixFormat = rgroupFEMSetSrc%cmatrixFormat
      rgroupFEMSetDest%cdataType     = rgroupFEMSetSrc%cdataType
      rgroupFEMSetDest%isetSpec      = rgroupFEMSetSrc%isetSpec
      rgroupFEMSetDest%NA            = rgroupFEMSetSrc%NA
      rgroupFEMSetDest%NEQ           = rgroupFEMSetSrc%NEQ
      rgroupFEMSetDest%NEDGE         = rgroupFEMSetSrc%NEDGE
      rgroupFEMSetDest%NVAR          = rgroupFEMSetSrc%NVAR
      rgroupFEMSetDest%ncoeffsAtNode = rgroupFEMSetSrc%ncoeffsAtNode
      rgroupFEMSetDest%ncoeffsAtEdge = rgroupFEMSetSrc%ncoeffsAtEdge
    end if

    ! Duplicate edge structure
    if (check(idupFlag, GFEM_DUP_EDGESTRUCTURE)) then
      ! Remove existing data owned by the destination structure
      if (.not.(check(rgroupFEMSetDest%iduplicationFlag,&
                      GFEM_SHARE_EDGESTRUCTURE))) then
        call storage_free(rgroupFEMSetDest%h_IedgeListIdx)
        call storage_free(rgroupFEMSetDest%h_IedgeList)
      end if

      ! Copy handle from source to destination structure
      rgroupFEMSetDest%h_IedgeListIdx = rgroupFEMSetSrc%h_IedgeListIdx
      rgroupFEMSetDest%h_IedgeList = rgroupFEMSetSrc%h_IedgeList

      ! Adjust specifier of the destination structure
      rgroupFEMSetDest%isetSpec = ior(rgroupFEMSetDest%isetSpec,&
          iand(rgroupFEMSetSrc%isetSpec, GFEM_HAS_EDGESTRUCTURE))
      
      ! Reset ownership
      rgroupFEMSetDest%iduplicationFlag =&
          iand(rgroupFEMSetDest%iduplicationFlag, GFEM_SHARE_EDGESTRUCTURE)
    end if

    ! Copy coefficients at nodes
    if (check(idupFlag, GFEM_DUP_NODEDATA)) then
      ! Remove existing data owned by the destination structure
      if (.not.(check(rgroupFEMSetDest%iduplicationFlag,&
                      GFEM_SHARE_NODEDATA))) then
        call storage_free(rgroupFEMSetDest%h_CoeffsAtNode)
      end if

      ! Copy handle from source to destination structure
      rgroupFEMSetDest%h_CoeffsAtNode = rgroupFEMSetSrc%h_CoeffsAtNode

      ! Adjust specifier of the destination structure
      rgroupFEMSetDest%isetSpec = ior(rgroupFEMSetDest%isetSpec,&
          iand(rgroupFEMSetSrc%isetSpec, GFEM_HAS_NODEDATA))
      
      ! Reset ownership
      rgroupFEMSetDest%iduplicationFlag =&
          iand(rgroupFEMSetDest%iduplicationFlag, GFEM_SHARE_NODEDATA)
    end if

    ! Copy coefficients at edges
    if (check(idupFlag, GFEM_DUP_EDGEDATA)) then
      ! Remove existing data owned by the destination structure
      if (.not.(check(rgroupFEMSetDest%iduplicationFlag,&
                      GFEM_SHARE_EDGEDATA))) then
        call storage_free(rgroupFEMSetDest%h_CoeffsAtEdge)
      end if

      ! Copy handle from source to destination structure
      rgroupFEMSetDest%h_CoeffsAtEdge = rgroupFEMSetSrc%h_CoeffsAtEdge

      ! Adjust specifier of the destination structure
      rgroupFEMSetDest%isetSpec = ior(rgroupFEMSetDest%isetSpec,&
          iand(rgroupFEMSetSrc%isetSpec, GFEM_HAS_EDGEDATA))
      
      ! Reset ownership
      rgroupFEMSetDest%iduplicationFlag =&
          iand(rgroupFEMSetDest%iduplicationFlag, GFEM_SHARE_EDGEDATA)
    end if

  contains

    !**************************************************************
    ! Checks if idupFlag has all bits ibitfield set.

    pure function check(idupFlag, ibitfield)
      
      integer(I32), intent(in) :: idupFlag,ibitfield
      
      logical :: check
      
      check = (iand(idupFlag,ibitfield) .eq. ibitfield)

    end function check

  end subroutine gfem_duplicateGroupFEMSet

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_duplicateGroupFEMBlock(rgroupFEMBlockSrc, rgroupFEMBlockDest, idupFlag)

!<description>
    ! This subroutine duplicates parts of the source structure
    ! rgroupFEMBlockSrc in the destination structure rgroupFEMBlockDest.
    ! Note that rgroupFEMBlockScr is still the owner of the duplicated content.
!<description>

!<input>
    ! Source block of group finite element sets
    type(t_groupFEMBlock), intent(in) :: rgroupFEMBlockSrc

    ! Duplication flag that decides on how to set up the structure
    integer(I32), intent(in) :: idupFlag
!</input>

!<inputoutput>
    ! Destination block of group finite element sets
    type(t_groupFEMBlock), intent(inout) :: rgroupFEMBlockDest
!</inputoutput>
!</subroutine>

    ! local variables
    integer :: i

    ! Check if block structure needs to be (re-)allocated
    if (rgroupFEMBlockSrc%nblocks .ne. rgroupFEMBlockDest%nblocks) then
      call gfem_releaseGroupFEMBlock(rgroupFEMBlockDest)
      rgroupFEMBlockDest%nblocks = rgroupFEMBlockSrc%nblocks
      allocate(rgroupFEMBlockDest%RgroupFEMBlock(rgroupFEMBlockDest%nblocks))
    end if
    
    do i = 1, rgroupFEMBlockSrc%nblocks
      call gfem_duplicateGroupFEMSet(rgroupFEMBlockSrc%RgroupFEMBlock(i),&
          rgroupFEMBlockDest%RgroupFEMBlock(i), idupFlag)
    end do
        
  end subroutine gfem_duplicateGroupFEMBlock

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_initCoeffsFromMatrix(rgroupFEMSet, Rmatrices, Iposition, IdofList)

!<description>
    ! This subroutine initialises the arrays of precomputed
    ! coefficient with the data given by the matrices. Depending on
    ! the type of assembly, the coefficients are stored in
    ! CoeffsAtNode and/or CcoeffsAtEdge. If these arrays have not
    ! been initialised before, then new memory is allocated.
    !
    ! If the optional parameter IdofList is given, then only those
    ! degrees of freedom are considered which are given by the list.
    ! Note that if IdofList is given, it must be identical to the list
    ! of degrees of freedom which was used to generate the list of
    ! edges and/or for initialising the arrays CoeffsAtNode and/or
    ! CcoeffsAtEdge. The latter is not checked but it will lead to
    ! violations of array bounds. So, be warned!
!</description>

!<input>
    ! Array of scalar coefficient matrices
    type(t_matrixScalar), dimension(:), intent(in) :: Rmatrices
    
    ! OPTIONAL: Array of integers which indicate the positions of the
    ! given matrices. If this parameter is not given, then the
    ! matrices are stored starting at position one.
    integer, dimension(:), intent(in), optional, target :: Iposition

    ! OPTIONAL: a list of degress of freedoms to which the edge
    ! structure should be restricted.
    integer, dimension(:), intent(in), optional :: IdofList
!</input>

!<inputoutpu>
    ! group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSet
!</inputoutput>
!</subroutine>

    ! local variables
    logical, dimension(:), allocatable :: BisActive
    real(DP), dimension(:,:,:), pointer :: p_DcoeffsAtEdge
    real(DP), dimension(:,:), pointer :: p_DcoeffsAtNode
    real(DP), dimension(:), pointer :: p_Ddata
    integer, dimension(:,:), pointer :: p_IedgeList
    integer, dimension(:), pointer :: p_Iposition,p_Kdiagonal,p_Kld,p_Kcol
    integer, dimension(2) :: Isize2D
    integer, dimension(3) :: Isize3D
    integer :: i,icount,iedge,ij,imatrix,ipos,j,ji,nmatrices,nmaxpos

    ! Check if structure provides edge-based structure and generate it
    ! otherwise based on the first matrix and the list of DOFs (if any)
    if (iand(rgroupFEMSet%isetSpec, GFEM_HAS_EDGESTRUCTURE) .eq. 0) then
      call gfem_genEdgeList(Rmatrices(1), rgroupFEMSet, IdofList)
    end if

    ! Set number of matrices
    nmatrices = size(Rmatrices)
    
    ! Set pointer to matrix positions
    if (present(Iposition)) then
      p_Iposition => Iposition
    else
      allocate(p_Iposition(size(Rmatrices)))
      do imatrix = 1, nmatrices
        p_Iposition(imatrix) = imatrix
      end do
    end if
    
    ! Set maximum position
    nmaxpos = maxval(p_Iposition)

    ! Check if array Rmatrices and Iposition have the same size
    if (nmatrices .ne. size(p_Iposition)) then
      call output_line('size(Rmatrices) /= size(Iposition)!',&
          OU_CLASS_ERROR,OU_MODE_STD,'gfem_initCoeffsFromMatrix')
      call sys_halt()
    end if

    ! Check if auxiliary data arrays for coefficients are initialised
    if ((rgroupFEMSet%h_CoeffsAtNode .eq. ST_NOHANDLE) .and.&
        (rgroupFEMSet%h_CoeffsAtEdge .eq. ST_NOHANDLE)) then
      call gfem_allocCoeffs(rgroupFEMSet, Rmatrices(1),&
          nmaxpos, nmaxpos, IdofList)
    else
      if (rgroupFEMSet%h_CoeffsAtNode .ne. ST_NOHANDLE) then
        call storage_getsize(rgroupFEMSet%h_CoeffsAtNode, Isize2D)
        if (nmaxpos .gt. Isize2D(2)) then
          call output_line('Number of matrices exceeds pre-initialised arrays!',&
              OU_CLASS_ERROR,OU_MODE_STD,'gfem_initCoeffsFromMatrix')
          call sys_halt()
        end if
      end if
      
      if (rgroupFEMSet%h_CoeffsAtEdge .ne. ST_NOHANDLE) then
        call storage_getsize(rgroupFEMSet%h_CoeffsAtEdge, Isize3D)
        if (nmaxpos .gt. Isize3D(3)) then
          call output_line('Number of matrices exceeds pre-initialised arrays!',&
              OU_CLASS_ERROR,OU_MODE_STD,'gfem_initCoeffsFromMatrix')
          call sys_halt()
        end if
      end if
    end if
    
    ! Check if first matrix is compatible with group finite element set
    if ((rgroupFEMSet%cmatrixFormat .ne. Rmatrices(1)%cmatrixFormat) .or.&
        (rgroupFEMSet%cdataType     .ne. Rmatrices(1)%cdataType)) then
      call output_line('Matrix/group finite element set are incompatible!',&
          OU_CLASS_ERROR,OU_MODE_STD,'gfem_initCoeffsFromMatrix')
      call sys_halt()
    end if

    ! Check if other matrices are compatible to the first matrix
    do imatrix = 2, nmatrices
      call lsyssc_isMatrixCompatible(Rmatrices(1), Rmatrices(imatrix))
    end do

    ! What type of assembly are we?
    select case(rgroupFEMSet%cassemblyType)
    case (GFEM_NODEBASED)
      ! Set pointers
      call gfem_getbase_IedgeList(rgroupFEMSet, p_IedgeList)
      call gfem_getbase_DcoeffsAtNode(rgroupFEMSet, p_DcoeffsAtNode)

      ! Generate set of active degrees of freedom
      if (present(IdofList)) then
        allocate(BisActive(max(Rmatrices(1)%NEQ,Rmatrices(1)%NCOLS))); BisActive=.false.
        do i = 1, size(IdofList)
          BisActive(IdofList(i))=.true.
        end do
      end if

      ! Associate data of each matrix separately
      do imatrix = 1, nmatrices
        
        ! Get matrix position
        ipos = p_Iposition(imatrix)
        
        ! What kind of matrix are we?
        select case(Rmatrices(imatrix)%cmatrixFormat)
        case(LSYSSC_MATRIX7, LSYSSC_MATRIX9)
          !---------------------------------------------------------------------
          ! Matrix format 7 and 9
          !---------------------------------------------------------------------
          
          ! Set pointer to matrix data
          call lsyssc_getbase_double(Rmatrices(imatrix), p_Ddata)
          
          ! Set diagonal pointer
          call lsyssc_getbase_Kld(Rmatrices(imatrix), p_Kld)
          call lsyssc_getbase_Kcol(Rmatrices(imatrix), p_Kcol)

          if (present(IdofList)) then
            
            icount=0
            do i = 1, rgroupFEMSet%NEQ
              ! Check if this row belongs to an active DOF
              if (.not.BisActive(i)) cycle
              do ij = p_Kld(i), p_Kld(i+1)-1
                j = p_Kcol(ij)
                ! Check if this edge connects two DOFs which are marked active
                if (.not.BisActive(j)) cycle
                ! Increment counter and store data
                icount = icount+1
                p_DcoeffsAtNode(ipos,icount) = p_Ddata(ij)
              end do
            end do

          else

            ! Loop over all non-zero matrix entries
            do i = 1, rgroupFEMSet%NEQ
              do ij = p_Kld(i), p_Kld(i+1)-1
                p_DcoeffsAtNode(ipos,ij) = p_Ddata(ij)
              end do
            end do

          end if
          
        case(LSYSSC_MATRIX1)
          !---------------------------------------------------------------------
          ! Matrix format 1
          !---------------------------------------------------------------------
          
          ! Set pointer to matrix data
          call lsyssc_getbase_double(Rmatrices(imatrix), p_Ddata)

          if (present(IdofList)) then

            icount=0
            do i = 1, rgroupFEMSet%NEQ
              ! Check if this row belongs to an active DOF
              if (.not.BisActive(i)) cycle
              do j = 1, rgroupFEMSet%NEQ
                ! Check if this edge connects two DOFs which are marked active
                if (.not.BisActive(j)) cycle
                ! Increment counter and store data
                icount = icount+1
                p_DcoeffsAtNode(ipos,icount) =&
                    p_Ddata(Rmatrices(imatrix)%NCOLS*(i-1)+j)
              end do
            end do

          else
            
            ! Loop over all non-zero matrix entries
            do i = 1, rgroupFEMSet%NEQ
              do j = 1, rgroupFEMSet%NEQ
                p_DcoeffsAtNode(ipos,rgroupFEMSet%NEQ*(i-1)+j) =&
                    p_Ddata(Rmatrices(imatrix)%NCOLS*(i-1)+j)
              end do
            end do

          end if

        case default
          call output_line('Unsupported matrix format!',&
              OU_CLASS_ERROR,OU_MODE_STD,'gfem_initCoeffsFromMatrix')
          call sys_halt()
        end select
      end do

      ! Deallocate temporal memory
      if (present(IdofList)) deallocate(BisActive)
               
    case (GFEM_EDGEBASED)

      ! Set pointers
      call gfem_getbase_IedgeList(rgroupFEMSet, p_IedgeList)
      call gfem_getbase_DcoeffsAtNode(rgroupFEMSet, p_DcoeffsAtNode)
      call gfem_getbase_DcoeffsAtEdge(rgroupFEMSet, p_DcoeffsAtEdge)
      
      ! Associate data of each matrix separately
      do imatrix = 1, nmatrices
        
        ! Get matrix position
        ipos = p_Iposition(imatrix)
        
        ! What kind of matrix are we?
        select case(Rmatrices(imatrix)%cmatrixFormat)
        case(LSYSSC_MATRIX7, LSYSSC_MATRIX9)
          !---------------------------------------------------------------------
          ! Matrix format 7 and 9
          !---------------------------------------------------------------------
          
          ! Set pointer to matrix data
          call lsyssc_getbase_double(Rmatrices(imatrix), p_Ddata)
          
          ! Set diagonal pointer
          if (Rmatrices(imatrix)%cmatrixFormat .eq. LSYSSC_MATRIX7) then
            call lsyssc_getbase_Kld(Rmatrices(imatrix), p_Kdiagonal)
          else
            call lsyssc_getbase_Kdiagonal(Rmatrices(imatrix), p_Kdiagonal)
          end if

          ! Loop over all rows and copy diagonal entries
          if (present(IdofList)) then
            do i = 1, rgroupFEMSet%NEQ
              p_DcoeffsAtNode(ipos,i) = p_Ddata(p_Kdiagonal(IdofList(i)))
            end do
          else
            do i = 1, rgroupFEMSet%NEQ
              p_DcoeffsAtNode(ipos,i) = p_Ddata(p_Kdiagonal(i))
            end do
          end if
          
          ! Loop over all edges and copy off-diagonal entries
          do iedge = 1, rgroupFEMSet%NEDGE
            ij = p_IedgeList(3,iedge)
            ji = p_IedgeList(4,iedge)
            p_DcoeffsAtEdge(ipos,1,iedge) = p_Ddata(ij)
            p_DcoeffsAtEdge(ipos,2,iedge) = p_Ddata(ji)
          end do
          
        case(LSYSSC_MATRIX1)
          !---------------------------------------------------------------------
          ! Matrix format 1
          !---------------------------------------------------------------------
          
          ! Set pointer to matrix data
          call lsyssc_getbase_double(Rmatrices(imatrix), p_Ddata)
          
          ! Loop over all rows and copy diagonal entries
          if (present(IdofList)) then
            do i = 1, rgroupFEMSet%NEQ
              p_DcoeffsAtNode(ipos,i) =&
                  p_Ddata(Rmatrices(imatrix)%NEQ*(IdofList(i)-1)+IdofList(i))
            end do
          else
            do i = 1, rgroupFEMSet%NEQ
              p_DcoeffsAtNode(ipos,i) =&
                  p_Ddata(Rmatrices(imatrix)%NEQ*(i-1)+i)
            end do
          end if
          
          ! Loop over all edges and copy off-diagonal entries
          do iedge = 1, rgroupFEMSet%NEDGE
            ij = p_IedgeList(3,iedge)
            ji = p_IedgeList(4,iedge)
            p_DcoeffsAtEdge(ipos,1,iedge) = p_Ddata(ij)
            p_DcoeffsAtEdge(ipos,2,iedge) = p_Ddata(ji)
          end do

        case default
          call output_line('Unsupported matrix format!',&
              OU_CLASS_ERROR,OU_MODE_STD,'gfem_initCoeffsFromMatrix')
          call sys_halt()
        end select
      end do
  
    case default
      call output_line('Unsupported type of assembly!',&
          OU_CLASS_ERROR,OU_MODE_STD,'gfem_initCoeffsFromMatrix')
      call sys_halt()
    end select

  end subroutine gfem_initCoeffsFromMatrix

  !*****************************************************************************

!<subroutine>

  subroutine gfem_isMatrixCompatibleSc(rgroupFEMSet, rmatrix, bcompatible)

!<description>
    ! This subroutine checks if a scalar matrix and a group finite
    ! element set compatible to each other, i.e. if they share the
    ! same structure, size and so on.
!</description>

!<input>
    ! Scalar matrix
    type(t_matrixScalar), intent(in) :: rmatrix

    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! OPTIONAL: If given, the flag will be set to TRUE or FALSE
    ! depending on whether the matrix and the group finite element set
    ! are compatible or not.  If not given, an error will inform the
    ! user if the matrix/operator are not compatible and the program
    ! will halt.
    logical, intent(out), optional :: bcompatible
!</output>
!</subroutine>

    ! Matrix/group finite element set must have the same size
    if (rgroupFEMSet%NA    .ne. rmatrix%NA    .or.&
        rgroupFEMSet%NEQ   .ne. rmatrix%NEQ  .or.&
        rgroupFEMSet%NVAR  .ne. rmatrix%NVAR .or.&
        rgroupFEMSet%NEDGE .ne. (rmatrix%NA-rmatrix%NEQ)/2) then
      if (present(bcompatible)) then
        bcompatible = .false.
        return
      else
        call output_line('Matrix/group finite element set not compatible, different structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'afcstab_isMatrixCompatibleSc')
        call sys_halt()
      end if
    end if
    
  end subroutine gfem_isMatrixCompatibleSc

  ! *****************************************************************************
  
!<subroutine>

  subroutine gfem_isMatrixCompatibleBl(rgroupFEMSet, rmatrixBlock, bcompatible)

!<description>
    ! This subroutine checks whether a block matrix and a group finite
    ! element set are compatible to each other, i.e. if they share the
    ! same structure, size and so on.
    !
    ! If the matrix has only one block, then the scalar counterpart of this
    ! subroutine is called with the corresponding scalar submatrix.
    ! Otherwise, the matrix is required to possess group structure.
!</description>

!<input>
    ! Block matrix
    type(t_matrixBlock), intent(in) :: rmatrixBlock
    
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! OPTIONAL: If given, the flag will be set to TRUE or FALSE
    ! depending on whether the matrix and the group finite element set
    ! are compatible or not.  If not given, an error will inform the
    ! user if the matrix/operator are not compatible and the program
    ! will halt.
    logical, intent(out), optional :: bcompatible
!</output>
!</subroutine>
    

    ! Check if matrix has only one block
    if ((rmatrixBlock%nblocksPerCol .eq. 1) .and.&
        (rmatrixBlock%nblocksPerRow .eq. 1)) then
      call gfem_isMatrixCompatible(rgroupFEMSet,&
          rmatrixBlock%RmatrixBlock(1,1), bcompatible)
      return
    end if

    ! Check if number of columns equans number of rows
    if (rmatrixBlock%nblocksPerCol .ne.&
        rmatrixBlock%nblocksPerRow) then
      call output_line('Block matrix must have equal number of columns and rows!',&
          OU_CLASS_ERROR,OU_MODE_STD,'gfem_isMatrixCompatibleBl')
      call sys_halt()
    end if

    ! Check if matrix exhibits group structure
    if (rmatrixBlock%imatrixSpec .ne. LSYSBS_MSPEC_GROUPMATRIX) then
      if (present(bcompatible)) then
        bcompatible = .false.
        return
      else
        call output_line('Block matrix must have group structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'gfem_isMatrixCompatibleBl')
        call sys_halt()
      end if
    end if

    ! Matrix/operator must have the same size
    if (rgroupFEMSet%NVAR  .ne. rmatrixBlock%nblocksPerCol         .or.&
        rgroupFEMSet%NA    .ne. rmatrixBlock%RmatrixBlock(1,1)%NA  .or.&
        rgroupFEMSet%NEQ   .ne. rmatrixBlock%RmatrixBlock(1,1)%NEQ .or.&
        rgroupFEMSet%NEDGE .ne. (rmatrixBlock%RmatrixBlock(1,1)%NA-&
                             rmatrixBlock%RmatrixBlock(1,1)%NEQ)/2) then
      if (present(bcompatible)) then
        bcompatible = .false.
        return
      else
        call output_line('Matrix/group finite element set not compatible, different structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'gfem_isMatrixCompatibleBl')
        call sys_halt()
      end if
    end if

  end subroutine gfem_isMatrixCompatibleBl

  !*****************************************************************************

!<subroutine>

  subroutine gfem_isVectorCompatibleSc(rgroupFEMSet, rvector, bcompatible)

!<description>
    ! This subroutine checks if a vector and a group finite element
    ! set are compatible to each other, i.e., share the same
    ! structure, size and so on.
!</description>

!<input>
    ! Scalar vector
    type(t_vectorScalar), intent(in) :: rvector

    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! OPTIONAL: If given, the flag will be set to TRUE or FALSE
    ! depending on whether the matrix and the group finite element set
    ! are compatible or not.  If not given, an error will inform the
    ! user if the matrix/operator are not compatible and the program
    ! will halt.
    logical, intent(out), optional :: bcompatible
!</output>
!</subroutine>

    ! Matrix/group finite element set must have the same size
    if (rgroupFEMSet%NEQ   .ne. rvector%NEQ .or.&
        rgroupFEMSet%NVAR  .ne. rvector%NVAR) then
      if (present(bcompatible)) then
        bcompatible = .false.
        return
      else
        call output_line('Vector/group finite element set not compatible, different structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'afcstab_isVectorCompatibleSc')
        call sys_halt()
      end if
    end if
  end subroutine gfem_isVectorCompatibleSc

!*****************************************************************************

!<subroutine>

  subroutine gfem_isVectorCompatibleBl(rgroupFEMSet, rvectorBlock, bcompatible)

!<description>
    ! This subroutine checks whether a block vector and a group finite
    ! element set are compatible to each other, i.e., share the same
    ! structure, size and so on.
    !
    ! If the vectors has only one block, then the scalar counterpart of
    ! this subroutine is called with the corresponding scalar subvector.
!</description>

!<input>
    ! Block vector
    type(t_vectorBlock), intent(in) :: rvectorBlock

    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! OPTIONAL: If given, the flag will be set to TRUE or FALSE depending on
    ! whether matrix and stabilisation are compatible or not.
    ! If not given, an error will inform the user if the matrix/operator are
    ! not compatible and the program will halt.
    logical, intent(out), optional :: bcompatible
!</output>
!</subroutine>

    ! Check if block vectors has just one block
    if (rvectorBlock%nblocks .eq. 1) then
      call gfem_isVectorCompatible(rgroupFEMSet,&
          rvectorBlock%RvectorBlock(1), bcompatible)
      return
    end if

    ! Vector/operator must have the same size
    if (rgroupFEMSet%NEQ*rgroupFEMSet%NVAR .ne. rvectorBlock%NEQ) then
      if (present(bcompatible)) then
        bcompatible = .false.
        return
      else
        call output_line('Vector/group finite element set not compatible, different structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'gfem_isVectorCompatibleBl')
        call sys_halt()
      end if
    end if
  end subroutine gfem_isVectorCompatibleBl

  !*****************************************************************************

!<subroutine>

  subroutine gfem_getbase_IedgeListIdx(rgroupFEMSet, p_IedgeListIdx)

!<description>
    ! Returns a pointer to the index pointer for the edge structure
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! Pointer to the edge index structure
    ! NULL() if the structure rgroupFEMSet does not provide it.
    integer, dimension(:), pointer :: p_IedgeListIdx
!</output>
!</subroutine>

    ! Do we edge structure at all?
    if (rgroupFEMSet%h_IedgeListIdx .eq. ST_NOHANDLE) then
      nullify(p_IedgeListIdx)
      return
    end if
    
    ! Get the array
    call storage_getbase_int(rgroupFEMSet%h_IedgeListIdx,&
        p_IedgeListIdx)

  end subroutine gfem_getbase_IedgeListIdx
  
  !*****************************************************************************

!<subroutine>

  subroutine gfem_getbase_IedgeList(rgroupFEMSet, p_IedgeList)

!<description>
    ! Returns a pointer to the edge structure
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! Pointer to the edge structure
    ! NULL() if the structure rgroupFEMSet does not provide it.
    integer, dimension(:,:), pointer :: p_IedgeList
!</output>
!</subroutine>

    ! Do we edge structure at all?
    if ((rgroupFEMSet%h_IedgeList .eq. ST_NOHANDLE) .or.&
        (rgroupFEMSet%NEDGE       .eq. 0)) then
      nullify(p_IedgeList)
      return
    end if
    
    ! Get the array
    call storage_getbase_int2D(rgroupFEMSet%h_IedgeList,&
        p_IedgeList, rgroupFEMSet%NEDGE)

  end subroutine gfem_getbase_IedgeList

  !*****************************************************************************

!<subroutine>

  subroutine gfem_getbase_DcoeffsAtNode(rgroupFEMSet, p_DcoeffsAtNode)

!<description>
    ! Returns a pointer to the double-valued coefficients at nodes
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! Pointer to the precomputed coefficients at nodes
    ! NULL() if the structure rgroupFEMSet does not provide it.
    real(DP), dimension(:,:), pointer :: p_DcoeffsAtNode
!</output>
!</subroutine>

    ! Do we have coefficients at nodes at all?
    if (rgroupFEMSet%h_CoeffsAtNode .eq. ST_NOHANDLE) then
      nullify(p_DcoeffsAtNode)
      return
    end if
    
    ! Get the array
    select case(rgroupFEMSet%cassemblyType)
    case (GFEM_NODEBASED)
      if (rgroupFEMSet%NA .eq. 0) then
        nullify(p_DcoeffsAtNode)
      else
        call storage_getbase_double2D(rgroupFEMSet%h_CoeffsAtNode,&
            p_DcoeffsAtNode, rgroupFEMSet%NA)
      end if

    case (GFEM_EDGEBASED)
      if (rgroupFEMSet%NEQ .eq. 0) then
        nullify(p_DcoeffsAtNode)
      else
        call storage_getbase_double2D(rgroupFEMSet%h_CoeffsAtNode,&
            p_DcoeffsAtNode, rgroupFEMSet%NEQ)
      end if

    case default
      nullify(p_DcoeffsAtNode)
    end select

  end subroutine gfem_getbase_DcoeffsAtNode

  !*****************************************************************************

!<subroutine>

  subroutine gfem_getbase_FcoeffsAtNode(rgroupFEMSet, p_FcoeffsAtNode)

!<description>
    ! Returns a pointer to the single-valued coefficients at nodes
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! Pointer to the precomputed coefficients at nodes
    ! NULL() if the structure rgroupFEMSet does not provide it.
    real(SP), dimension(:,:), pointer :: p_FcoeffsAtNode
!</output>
!</subroutine>

    ! Do we have coefficients at nodes at all?
    if (rgroupFEMSet%h_CoeffsAtNode .eq. ST_NOHANDLE) then
      nullify(p_FcoeffsAtNode)
      return
    end if
    
    ! Get the array
    select case(rgroupFEMSet%cassemblyType)
    case (GFEM_NODEBASED)
      if (rgroupFEMSet%NA .eq. 0) then
        nullify(p_FcoeffsAtNode)
      else
        call storage_getbase_single2D(rgroupFEMSet%h_CoeffsAtNode,&
            p_FcoeffsAtNode, rgroupFEMSet%NA)
      end if

    case (GFEM_EDGEBASED)
      if (rgroupFEMSet%NEQ .eq. 0) then
        nullify(p_FcoeffsAtNode)
      else
        call storage_getbase_single2D(rgroupFEMSet%h_CoeffsAtNode,&
            p_FcoeffsAtNode, rgroupFEMSet%NEQ)
      end if

    case default
      nullify(p_FcoeffsAtNode)
    end select

  end subroutine gfem_getbase_FcoeffsAtNode

  !*****************************************************************************

!<subroutine>

  subroutine gfem_getbase_DcoeffsAtEdge(rgroupFEMSet,p_DcoeffsAtEdge)

!<description>
    ! Returns a pointer to the double-valued coefficients at edges
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! Pointer to the precomputed coefficients at edges
    ! NULL() if the structure rgroupFEMSet does not provide it.
    real(DP), dimension(:,:,:), pointer :: p_DcoeffsAtEdge
!</output>
!</subroutine>

    ! Do we have double-valued edge data at all?
    if ((rgroupFEMSet%h_CoeffsAtEdge .eq. ST_NOHANDLE) .or.&
        (rgroupFEMSet%NEDGE          .eq. 0)) then
      nullify(p_DcoeffsAtEdge)
      return
    end if
    
    ! Get the array
    call storage_getbase_double3D(rgroupFEMSet%h_CoeffsAtEdge,&
        p_DcoeffsAtEdge, rgroupFEMSet%NEDGE)

  end subroutine gfem_getbase_DcoeffsAtEdge

  !*****************************************************************************

!<subroutine>

  subroutine gfem_getbase_FcoeffsAtEdge(rgroupFEMSet, p_FcoeffsAtEdge)

!<description>
    ! Returns a pointer to the single-valued coefficients at edges
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet
!</input>

!<output>
    ! Pointer to the precomputed coefficients at edges
    ! NULL() if the structure rgroupFEMSet does not provide it.
    real(SP), dimension(:,:), pointer :: p_FcoeffsAtEdge
!</output>
!</subroutine>

    ! Do we have double-valued edge data at all?
    if ((rgroupFEMSet%h_CoeffsAtEdge .eq. ST_NOHANDLE) .or.&
        (rgroupFEMSet%NEDGE          .eq. 0)) then
      nullify(p_FcoeffsAtEdge)
      return
    end if
    
    ! Get the array
    call storage_getbase_single2D(rgroupFEMSet%h_CoeffsAtEdge,&
        p_FcoeffsAtEdge, rgroupFEMSet%NEDGE)

  end subroutine gfem_getbase_FcoeffsAtEdge

  !*****************************************************************************

!<subroutine>

  subroutine gfem_genEdgeList(rmatrix, rgroupFEMSet, IdofList)

!<description>
    ! This subroutine generates the list of edges which are
    ! characterised by their two endpoints (i,j) and the absolute
    ! position of matrix entries ij and ji.
!</description>

!<input>
    ! Scalar matrix
    type(t_matrixScalar), intent(in) :: rmatrix

    ! OPTIONAL: a list of degress of freedoms to which the edge
    ! structure should be restricted.
    integer, dimension(:), intent(in), optional :: IdofList
!</input>

!<inputoutput>
    ! Group finite element structure
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSet
!</inputoutput>
!</subroutine>

    ! local variables
    integer, dimension(:,:), pointer :: p_IedgeList
    integer, dimension(:), pointer :: p_IedgeListIdx

    ! Check if edge structure is owned by the stabilisation structure
    if (iand(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_EDGESTRUCTURE) .eq.&
             GFEM_SHARE_EDGESTRUCTURE) then
      call output_line('Edge list is not owned by structure and '//&
          'therefore cannot be generated',&
          OU_CLASS_WARNING,OU_MODE_STD,'gfem_genEdgeList')
      return
    end if

    ! Set matrix format
    select case(rmatrix%cmatrixFormat)
    case (LSYSSC_MATRIX1)
      rgroupFEMSet%cmatrixFormat = LSYSSC_MATRIX1
    case (LSYSSC_MATRIX7, LSYSSC_MATRIX7INTL)
      rgroupFEMSet%cmatrixFormat = LSYSSC_MATRIX7
    case (LSYSSC_MATRIX9, LSYSSC_MATRIX9INTL)
      rgroupFEMSet%cmatrixFormat = LSYSSC_MATRIX9
      
    case default
      call output_line('Unsupported matrix format!',&
          OU_CLASS_ERROR,OU_MODE_STD,'gfem_genEdgeList')
      call sys_halt()
    end select

    ! Generate edge list for a matrix which is structurally symmetric,
    ! i.e. edge (i,j) exists if and only if edge (j,i) exists without
    ! storing the diagonal edges (i,i).
    call lsyssc_genEdgeList(rmatrix, rgroupFEMSet%h_IedgeList,&
        LSYSSC_EDGELIST_NODESANDPOS, .true., .true., IdofList)

    ! Allocate memory
    if (rgroupFEMSet%h_IedgeListIdx .eq. ST_NOHANDLE) then
      call storage_new('gfem_genEdgeList', 'IedgeListIdx',&
          2, ST_INT, rgroupFEMSet%h_IedgeListIdx, ST_NEWBLOCK_ZERO)
    end if
    
    ! Set pointer to edge structure
    call gfem_getbase_IedgeListIdx(rgroupFEMSet, p_IedgeListIdx)
    
    ! If no OpenMP is used, then all edges belong to the same
    ! group. Otherwise, the edges will be reordered below.
    p_IedgeListIdx    = rgroupFEMSet%NEDGE+1
    p_IedgeListIdx(1) = 1
    
    ! OpenMP-Extension: Perform edge-coloring to find groups of
    ! edges which can be processed in parallel, that is, the
    ! vertices of the edges in the group are all distinct
    call gfem_getbase_IedgeList(rgroupFEMSet, p_IedgeList)
    !$ if (rmatrix%cmatrixFormat .eq. LSYSSC_MATRIX1) then
    !$   call lsyssc_regroupEdgeList(rmatrix%NEQ, p_IedgeList,&
    !$       rgroupFEMSet%h_IedgeListIdx, 2*(rmatrix%NEQ-1))
    !$ else
    !$   call lsyssc_regroupEdgeList(rmatrix%NEQ, p_IedgeList,&
    !$       rgroupFEMSet%h_IedgeListIdx)
    !$ end if

    ! Set state of structure
    rgroupFEMSet%isetSpec = ior(rgroupFEMSet%isetSpec, GFEM_HAS_EDGESTRUCTURE)
    
    ! If the number of edges has not been set before then it is set below;
    ! otherwise an error is thrown if the number of edges mismatch
    if (rgroupFEMSet%NEDGE .eq. 0) then
      rgroupFEMSet%NEDGE = size(p_IedgeList,2)
    elseif (rgroupFEMSet%NEDGE .ne. size(p_IedgeList,2)) then
      call output_line('Number of edges mismatch!',&
          OU_CLASS_ERROR,OU_MODE_STD,'gfem_genEdgeList')
      call sys_halt()
    end if

  end subroutine gfem_genEdgeList
  
  !*****************************************************************************

!<subroutine>

  subroutine gfem_copyH2D_IedgeList(rgroupFEMSet, btranspose)

!<description>
    ! This subroutine copies the edge structure from the host memory
    ! to the memory of the coprocessor device. If no device is
    ! available, then an error is thrown.
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet

    ! If true then the memory is transposed.
    logical, intent(in) :: btranspose
!</input>
!</subroutine>


    if (rgroupFEMSet%h_IedgeList .ne. ST_NOHANDLE)&
        call storage_syncMemory(rgroupFEMSet%h_IedgeList,&
        ST_SYNCBLOCK_COPY_H2D, btranspose)

  end subroutine gfem_copyH2D_IedgeList

  !*****************************************************************************

!<subroutine>

  subroutine gfem_copyD2H_IedgeList(rgroupFEMSet, btranspose)

!<description>
    ! This subroutine copies the edge structure from the memory of the
    ! coprocessor device to the host memory. If no device is
    ! available, then an error is thrown.
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet

    ! If true then the memory is transposed.
    logical, intent(in) :: btranspose
!</input>
!</subroutine>

    if (rgroupFEMSet%h_IedgeList .ne. ST_NOHANDLE)&
        call storage_syncMemory(rgroupFEMSet%h_IedgeList,&
        ST_SYNCBLOCK_COPY_D2H, btranspose)

  end subroutine gfem_copyD2H_IedgeList

  !*****************************************************************************

!<subroutine>

  subroutine gfem_copyH2D_CoeffsAtNode(rgroupFEMSet, btranspose)

!<description>
    ! This subroutine copies the coefficients at nodes from the host
    ! memory to the memory of the coprocessor device. If no device is
    ! available, then an error is thrown.
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet

    ! If true then the memory is transposed.
    logical, intent(in) :: btranspose
!</input>
!</subroutine>


    if (rgroupFEMSet%h_CoeffsAtNode .ne. ST_NOHANDLE)&
        call storage_syncMemory(rgroupFEMSet%h_CoeffsAtNode,&
        ST_SYNCBLOCK_COPY_H2D, btranspose)

  end subroutine gfem_copyH2D_CoeffsAtNode

  !*****************************************************************************

!<subroutine>

  subroutine gfem_copyD2H_CoeffsAtNode(rgroupFEMSet, btranspose)

!<description>
    ! This subroutine copies the coefficients at nodes from the memory
    ! of the coprocessor device to the host memory. If no device is
    ! available, then an error is thrown.
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet

    ! If true then the memory is transposed.
    logical, intent(in) :: btranspose
!</input>
!</subroutine>

    if (rgroupFEMSet%h_CoeffsAtNode .ne. ST_NOHANDLE)&
        call storage_syncMemory(rgroupFEMSet%h_CoeffsAtNode,&
        ST_SYNCBLOCK_COPY_D2H, btranspose)

  end subroutine gfem_copyD2H_CoeffsAtNode

  !*****************************************************************************

!<subroutine>

  subroutine gfem_copyH2D_CoeffsAtEdge(rgroupFEMSet, btranspose)

!<description>
    ! This subroutine copies the coefficients at edges from the host
    ! memory to the memory of the coprocessor device. If no device is
    ! available, then an error is thrown.
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet

    ! If true then the memory is transposed.
    logical, intent(in) :: btranspose
!</input>
!</subroutine>


    if (rgroupFEMSet%h_CoeffsAtEdge .ne. ST_NOHANDLE)&
        call storage_syncMemory(rgroupFEMSet%h_CoeffsAtEdge,&
        ST_SYNCBLOCK_COPY_H2D, btranspose)
    
  end subroutine gfem_copyH2D_CoeffsAtEdge

  !*****************************************************************************

!<subroutine>

  subroutine gfem_copyD2H_CoeffsAtEdge(rgroupFEMSet, btranspose)

!<description>
    ! This subroutine copies the coefficients at edges from the memory
    ! of the coprocessor device to the host memory. If no device is
    ! available, then an error is thrown.
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet

    ! If true then the memory is transposed.
    logical, intent(in) :: btranspose
!</input>
!</subroutine>

    if (rgroupFEMSet%h_CoeffsAtEdge .ne. ST_NOHANDLE)&
        call storage_syncMemory(rgroupFEMSet%h_CoeffsAtEdge,&
        ST_SYNCBLOCK_COPY_D2H, btranspose)

  end subroutine gfem_copyD2H_CoeffsAtEdge

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_allocCoeffsDirect(rgroupFEMSet, ncoeffsAtNode, ncoeffsAtEdge,&
      NA, NEQ, NEDGE)

!<description>
    ! This subroutine initialises memory for storing precomputed
    ! coefficients at nodes and/or edges.
!</description>

!<input>
    ! Number of precomputed coefficients
    integer, intent(in) :: ncoeffsAtNode
    integer, intent(in) :: ncoeffsAtEdge

    ! OPTIONAL: Number of non-zero entries
    integer, intent(in), optional :: NA

    ! OPTIONAL: Number of equations
    integer, intent(in), optional :: NEQ

    ! OPTIONAL: Number of edges
    integer, intent(in), optional :: NEDGE
!</input>

!<inputoutput>
    ! Group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSet
!</inputoutput>
!</subroutine>

    ! local variables
    integer, dimension(2) :: Isize2D
    integer, dimension(3) :: Isize3D

    ! Remove auxiliary memory if not shared with others
    if ((iand(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_NODEDATA) .eq. 0)&
        .and.(rgroupFEMSet%h_CoeffsAtNode .ne. ST_NOHANDLE))&
        call storage_free(rgroupFEMSet%h_CoeffsAtNode)
    if ((iand(rgroupFEMSet%iduplicationFlag, GFEM_SHARE_EDGEDATA) .eq. 0)&
        .and.(rgroupFEMSet%h_CoeffsAtEdge .ne. ST_NOHANDLE))&
        call storage_free(rgroupFEMSet%h_CoeffsAtEdge)

    ! Set dimensions
    rgroupFEMSet%ncoeffsAtNode = ncoeffsAtNode
    rgroupFEMSet%ncoeffsAtEdge = ncoeffsAtEdge
    
    ! Set additional dimensions with consistency check
    if (present(NA)) then
      if (rgroupFEMSet%NA .eq. 0) then
        rgroupFEMSet%NA = NA
      elseif (rgroupFEMSet%NA .ne. NA) then
        call output_line('Number of non-zero entries mismatch!',&
            OU_CLASS_ERROR,OU_MODE_STD,'gfem_allocCoeffsDirect')
        call sys_halt()
      end if
    end if

    if (present(NEQ)) then
      if (rgroupFEMSet%NEQ .eq. 0) then
        rgroupFEMSet%NEQ = NEQ
      elseif (rgroupFEMSet%NEQ .ne. NEQ) then
        call output_line('Number of equations entries mismatch!',&
            OU_CLASS_ERROR,OU_MODE_STD,'gfem_allocCoeffsDirect')
        call sys_halt()
      end if
    end if

    if (present(NEDGE)) then
      if (rgroupFEMSet%NEDGE .eq. 0) then
        rgroupFEMSet%NEDGE = NEDGE
      elseif (rgroupFEMSet%NEDGE .ne. NEDGE) then
        call output_line('Number of edges entries mismatch!',&
            OU_CLASS_ERROR,OU_MODE_STD,'gfem_allocCoeffsDirect')
        call sys_halt()
      end if
    end if

    ! What type of assembly are we?
    select case(rgroupFEMSet%cassemblyType)

    case (GFEM_NODEBASED)
      ! Nodes-based assembly
      if ((rgroupFEMSet%NA .gt. 0) .and. (rgroupFEMSet%ncoeffsAtNode .gt. 0)) then
        Isize2D = (/rgroupFEMSet%ncoeffsAtNode, rgroupFEMSet%NA/)
        call storage_new('gfem_allocCoeffsDirect', 'CoeffsAtNode', Isize2D,&
            rgroupFEMSet%cdataType, rgroupFEMSet%h_CoeffsAtNode, ST_NEWBLOCK_ZERO)
      end if

    case (GFEM_EDGEBASED)
      ! Edge-based assembly
      if ((rgroupFEMSet%NEQ .gt. 0) .and. (rgroupFEMSet%ncoeffsAtNode .gt. 0)) then
        Isize2D = (/rgroupFEMSet%ncoeffsAtNode, rgroupFEMSet%NEQ/)
        call storage_new('gfem_allocCoeffsDirect', 'CoeffsAtNode', Isize2D,&
            rgroupFEMSet%cdataType, rgroupFEMSet%h_CoeffsAtNode, ST_NEWBLOCK_ZERO)
      end if

      if ((rgroupFEMSet%NEDGE .gt. 0) .and. (rgroupFEMSet%ncoeffsAtEdge .gt. 0)) then
        Isize3D = (/rgroupFEMSet%ncoeffsAtEdge, 2, rgroupFEMSet%NEDGE/)  
        call storage_new('gfem_allocCoeffsDirect', 'CoeffsAtEdge', Isize3D,&
            rgroupFEMSet%cdataType, rgroupFEMSet%h_CoeffsAtEdge, ST_NEWBLOCK_ZERO)
      end if

    end select

  end subroutine gfem_allocCoeffsDirect

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_allocCoeffsByMatrix(rgroupFEMSet, rmatrix, ncoeffsAtNode,&
      ncoeffsAtEdge, IdofList)

!<description>
    ! This subroutine initialises memory for storing precomputed
    ! coefficients at nodes and/or edges undirectly by deriving all
    ! information from the scalar template matrix rmatrix. If
    ! IdofList is given, then its entries are used as degrees of
    ! freedom to which the group finite elment set should be
    ! restricted to.
!</description>

!<input>
    ! Scalar template matrix
    type(t_matrixScalar), intent(in) :: rmatrix

    ! Number of precomputed coefficients
    integer, intent(in) :: ncoeffsAtNode
    integer, intent(in) :: ncoeffsAtEdge

    ! OPTIONAL: a list of degress of freedoms to which the edge
    ! structure should be restricted.
    integer, dimension(:), intent(in), optional :: IdofList
!</input>

!<inputoutput>
    ! Group finite element set
    type(t_groupFEMSet), intent(inout) :: rgroupFEMSet
!</inputoutput>
!</subroutine>

    ! local variables
    integer :: na,neq,nedge

    ! Calculate dimensions of matrix (possible with restriction)
    call gfem_calcDimsFromMatrix(rmatrix, na, neq, nedge, IdofList)
    
    ! Call allocation routine
    call gfem_allocCoeffs(rgroupFEMSet, ncoeffsAtNode, ncoeffsAtEdge,&
        na, neq, nedge)

  end subroutine gfem_allocCoeffsByMatrix

  ! ***************************************************************************

!<subroutine>

  subroutine gfem_calcDimsFromMatrix(rmatrix, na, neq, nedge, IdofList)

!<description>
    ! This subroutine calculates the number of non-zero matrix entries
    ! NA, the number of equations NEQ and the number of edges for the
    ! given matrix rmatrix. If IdofList is given, then its entries are
    ! used as degrees of freedom to which the group finite elment set
    ! should be restricted to.
!</description>

!<input>
    ! Scalar matrix
    type(t_matrixScalar), intent(in) :: rmatrix

    ! OPTIONAL: a list of degress of freedoms to which the edge
    ! structure should be restricted.
    integer, dimension(:), intent(in), optional :: IdofList
!</intput>

!<output>
    ! Number of non-zero matrix entries
    integer, intent(out) :: na

    ! Number of equations
    integer, intent(out) :: neq

    ! Number of edges
    integer, intent(out) :: nedge
!</output>

    ! local variables
    logical, dimension(:), allocatable :: BisActive
    integer, dimension(:), pointer :: p_Kld, p_Kcol
    integer :: i,ij,j

    if (present(IdofList)) then

      ! Generate set of active degrees of freedom
      allocate(BisActive(max(rmatrix%NEQ,rmatrix%NCOLS))); BisActive=.false.
      do i = 1, size(IdofList)
        BisActive(IdofList(i)) = .true.
      end do

      ! Initialisation
      na=0; neq=0; nedge=0
      
      ! What type of matrix are we?
      select case(rmatrix%cmatrixFormat)
      case(LSYSSC_MATRIX1)
        
        ! Determine number of non-zero matrix entries, equations and edges
        do i = 1, rmatrix%NEQ
          if (.not.BisActive(i)) cycle
          neq = neq+1
          do j = 1, rmatrix%NCOLS
            if (.not.BisActive(j)) cycle
            nedge = nedge+1
          end do
        end do
        na = 2*nedge+neq
        
      case(LSYSSC_MATRIX7, LSYSSC_MATRIX7INTL,&
           LSYSSC_MATRIX9, LSYSSC_MATRIX9INTL)
        
        ! Set pointers
        call lsyssc_getbase_Kld(rmatrix, p_Kld)
        call lsyssc_getbase_Kcol(rmatrix, p_Kcol)
        
        ! Determine number of non-zero matrix entries, equations and edges
        do i=1, rmatrix%NEQ
          if (.not.BisActive(i)) cycle
          neq = neq+1; na = na+1
          do ij = p_Kld(i), p_Kld(i+1)-1
            j = p_Kcol(ij)
            if (.not.BisActive(j)) cycle
            na = na+1
          end do
        end do
        nedge = (na-neq)/2
        
      case default
        call output_line('Unsupported matrix format!',&
            OU_CLASS_WARNING,OU_MODE_STD,'gfem_calcDimsFromMatrix')        
        call sys_halt()
      end select
      
      ! Deallocate temporal memory
      deallocate(BisActive)

    else
      
      na = rmatrix%NA
      neq = rmatrix%NEQ
      nedge = (na-neq)/2

    end if

  end subroutine gfem_calcDimsFromMatrix

end module groupfembase
