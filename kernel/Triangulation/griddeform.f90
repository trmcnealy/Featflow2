!##############################################################################
!# ****************************************************************************
!# <name> griddeform </name>
!# ****************************************************************************
!#
!# <purpose>
!# 
!# <todo> Mal andere Elementtypen ausprobieren, eine Callbackfunction für 
!#        die Monitorfunktion
!#
!# 1.) griddef_deformationInit
!#     -> Initialise a griddeform structure
!# 2.) griddef_DeformationDone
!#     -> release a griddeform structure
!# 3.) griddef_freeWorkDef
!#     -> release the resources we needed for
!#        the grid deformation
!# 4.) griddef_calcMonitorFunction
!#     -> creates a monitor function from a given error distribution
!# 5.) griddef_prepareDeformation
!#     -> allocate needed resources
!# 6.) griddef_performDeformation
!#     -> main routine for the grid deformation process
!# 6a.)griddef_computeAdapSteps
!#     -> computes the number of adaption steps
!# 7.) griddef_performOneDefStep
!#     -> performs one deformation step of the (basic,enhanced) deformation method
!# 8.) griddef_getArea
!#     -> auxilliary function to get the area in all the elements,
!#     -> put it in a Q0 vector and then project the Q0 Vector to a Q1 vector
!# 9.) griddef_buildMonFuncTest
!#    -> build a test monitor function
!# 10.)  griddef_normaliseFctsNum
!#     -> normalise our functions
!# 11.) griddef_blendmonitor
!#     -> blend the monitor function
!# 12.) griddef_normaliseFctsInv
!#     -> normalise the function inverse
!# 13.) griddef_normaliseFctsInvAux
!#     -> auxilliary routine for the function inverse
!# 14.) griddef_createMatrixDef
!#     -> create the matrix of the deformation poisson problem
!# 15.) griddef_createRHS
!#     -> create the rhs of the deformation poisson problem
!# 16.) griddef_moveMesh
!#     -> solve the ode and move the mesh
!# 17.) griddef_performEE
!#     -> performs Explicit euler to solve the ODE for all 
!#        innter vertices
!# 18.) griddef_perform_boundary2
!#     -> performs the explicit euler on the boundary
!#        vertices.
!# 19.) griddef_evalPhi_Known
!#    -> auxilliary routine for the ODE solver
!# 20.) griddef_evalphi_ray
!#    -> auxilliary routine for the ODE solver
!# 21.) griddef_evalphi_ray_bound
!#    -> auxilliary routine for the ODE solver
!# 22.) griddef_getAreaDeformed
!#    -> compute the area distribution in the deformed, mainly
!#       for debugging purposes
!# 23.) griddef_qMeasureM1
!#    -> compute the quality measure m1
!# 24.) griddef_buildHGrid
!#    -> ?
!# </purpose>
!##############################################################################


module griddeform

  use fsystem
  use genoutput
  use storage
  use basicgeometry
  use geometryaux
  use boundary
  use triangulation
  use triasearch
  use linearsystemscalar
  use linearsystemblock
  use spatialdiscretisation
  use dofmapping
  use stdoperators
  use bcassembly
  use bilinearformevaluation
  use linearformevaluation
  use spdiscprojection
  use pprocerror
  use cubature
  use derivatives
  use element
  use elementpreprocessing
  use pprocgradients
  use vectorfilters
  use matrixfilters
  use filtersupport 
  use transformation
  use linearsolver
  use feevaluation
  use ucd  
  
  implicit none
  
  private

!<constants>

  integer, parameter, public :: GRIDDEF_CLASSICAL  = 0

  integer, parameter, public :: GRIDDEF_MULTILEVEL = -1
  
  integer, parameter, public :: GRIDDEF_FIXED      = 2
  
  integer, parameter, public :: GRIDDEF_USER       = 3

!</constants>

!<types>

  !<typeblock>
  ! This type contains the different levels of a multigrid 
  ! so that they can be efficiently used in the deformation routine
  type t_hgridLevels
  
    ! An object for saving the triangulation on the domain
    type(t_triangulation) :: rtriangulation

  ! An object specifying the block discretisation
  ! (size of subvectors in the solution vector, trial/test functions,...)
  ! type(t_blockDiscretisation) :: rdiscretisation
  
  end type
  
  public :: t_hgridLevels
  
  !<\typeblock>

  !<typeblock>
  ! This type contains everything which is necessary to define
  ! a certain deformation algorithm.
  type t_griddefInfo

    ! 
    type(t_hgridLevels), dimension(:), pointer :: p_rhLevels

    ! this is a Pointer to the original triangulation structure,
    ! when our deformation was a success, we will overwrite 
    ! this structure with the deformed vertex coordinates
    type(t_triangulation), pointer :: p_rtriangulation => NULL()
    
    ! Pointer to a triangulation structure, we use this one
    ! as our local copy, in case of a successful deformation
    ! it will be become the new triangulation
    ! type(t_triangulation) :: rDeftriangulation 
    
    ! the boundary information of the undeformed grid
    type(t_boundary), pointer :: p_rboundary

    ! description missing
    integer:: cdefStyle

    ! number of time steps in ODE solver
    integer:: ntimeSteps

    ! type of ODE solver
    integer:: codeMethod

    ! regularisation parameter for monitor function
    ! if dregpar .lt. 0: dregpar is weighted by <tex>$0.5^{maxMGLevel}$</tex>
    real(dp) :: dregpar

    ! form parameter for monitor function
    real(dp) ::dexponent
    
    ! Blending parameter for basic deformation     
    real(dp) :: dblendPar

    ! number of adaptation steps
    integer :: nadaptionSteps

    ! admissible quality number (stopping criterion for correction)
    real(dp) :: dtolQ = ST_NOHANDLE

    ! description missing
    integer :: h_Dql2 = ST_NOHANDLE
    
    ! description missing
    integer :: h_Dqlinfty = ST_NOHANDLE

    ! number of adaption steps during deformation
    integer :: h_nadapSteps = ST_NOHANDLE

    ! description missing
    integer :: h_calcAdapSteps = ST_NOHANDLE

    ! number of adaption steps during deformation really performed
    ! (may differ from nadapSteps: if nadapSteps .lt.0, then compute
    ! nadapSteps according to the deformation problem)
    integer :: h_nadapStepsReally = ST_NOHANDLE

    ! maximal number of correction steps
    integer :: h_nmaxCorrSteps = ST_NOHANDLE

    ! number of correction steps really performed
    integer :: h_ncorrSteps = ST_NOHANDLE

    ! ODE level for deformation
    integer :: h_ilevelODE = ST_NOHANDLE

    ! ODE level for correction
    integer :: h_ilevelODECorr = ST_NOHANDLE

    ! number of smoothing steps for creating the monitor function
    ! if .lt. 0: values are multiplied by current level
    integer :: h_npreSmoothSteps = ST_NOHANDLE
    ! number of smoothing steps for creating the monitor function
    ! if .lt. 0: values are multiplied by current level
    integer :: h_npostSmoothSteps = ST_NOHANDLE
    ! number of smoothing steps for creating the monitor function
    ! if .lt. 0: values are multiplied by current level
    integer :: h_nintSmoothSteps = ST_NOHANDLE

    ! number of smoothing steps for monitor function
    integer :: h_nmonSmoothsteps = ST_NOHANDLE

    ! smoothing method used:
    integer :: h_cpreSmoothMthd = ST_NOHANDLE
    ! smoothing method used:
    integer :: h_cpostSmoothMthd = ST_NOHANDLE
    ! smoothing method used:
    integer :: h_cintSmoothMthd = ST_NOHANDLE

    ! handle for the vector containing the blending parameters
    integer:: h_DblendPar = ST_NOHANDLE

    ! method for gradient recovery (1: SPR, 2 : PPR, 3: interpolation)
    integer:: crecMethod

    ! if true, use the FEM-interpolant of the monitor function instead of the
    ! monitor function directly
    integer:: cMonFctEvalMethod

    ! if true, use the error distribution to obtain the monitor function
    logical ::buseErrorDistr

    ! description missing
    real(DP) :: damplification

    ! if true, perform relative deformation
    logical :: brelDef

    ! description missing
    integer:: iminDefLevel

    ! description missing
    integer:: idefLevIncr

    ! scaling factor for the monitor function itself such that
    ! \int dscalefmon f = |\Omega|
    real(DP) :: dscalefmon

    ! same for the reciprocal of the monitor function
    real(DP) :: dscalefmonInv

    ! Feat-vector with boundary description
    integer:: h_IboundCompDescr_handles = ST_NOHANDLE
    
    ! save the minimum level
    integer :: NLMIN
    
    ! save the maximum level
    integer :: NLMAX

  end type t_griddefInfo
  
  public :: t_griddefInfo
  !</typeblock>
  
  !<typeblock>
  ! description missing
  type t_griddefWork

    ! handle of vector containing the area distribution (nodewise representation)
    
    ! A block vector to store the are distribution
    type(t_vectorBlock)  :: rvectorAreaBlockQ1    
        ! A block vector where we store the monitor function
    type(t_vectorBlock)  :: rvectorMonFuncQ1      
    ! A scalar matrix and vector. The vector accepts the RHS of the problem
    ! in scalar form.
    type(t_matrixScalar) :: rmatrix
    ! A block matrix and a couple of block vectors. These will be filled
    ! with data for the linear solver.
    type(t_matrixBlock) :: rmatDeform
    ! handle for solution of Poisson problem in deformation method
    type(t_vectorBlock) :: rSolBlock
    ! handle for rhs of Poisson problem in deformation method
    type(t_vectorBlock) :: rrhsBlock
    ! handle for rhs of Poisson problem in deformation method
    type(t_vectorBlock) :: rtempBlock
    ! block vector for the recovered gradient
    type(t_vectorBlock) :: rvecGradBlock
    ! tells whether the structure needs to be reinitialised
    logical             :: breinit = .false.

  end type t_griddefWork
  
  public :: t_griddefWork
  !</typeblock>
!</types>    

  public :: griddef_deformationInit
  public :: griddef_DeformationDone
  public :: griddef_freeWorkDef
  public :: griddef_calcMonitorFunction
  public :: griddef_prepareDeformation
  public :: griddef_performDeformation
  public :: griddef_computeAdapSteps
  public :: griddef_performOneDefStep
  public :: griddef_getArea
  public :: griddef_buildMonFuncTest
  public :: griddef_normaliseFctsNum
  public :: griddef_blendmonitor
  public :: griddef_normaliseFctsInv
  public :: griddef_normaliseFctsInvAux
  public :: griddef_createMatrixDef
  public :: griddef_createRHS
  public :: griddef_moveMesh
  public :: griddef_performEE
  public :: griddef_perform_boundary2
  public :: griddef_evalPhi_Known
  public :: griddef_evalphi_ray
  public :: griddef_evalphi_ray_bound
  public :: griddef_getAreaDeformed
  public :: griddef_qMeasureM1
  public :: griddef_buildHGrid

contains

!<subroutine>
  subroutine griddef_deformationInit(rgriddefInfo,rtriangulation,NLMIN,NLMAX,&
                    rboundary,iStyle,iadaptSteps)
  
!<description>
  ! This subroutine initialises the rgriddefinfo structure which describes the
  ! grid deformation algorithm. The values for the certain parameters defining
  ! the deformation process are read in from the master.dat file. This routine
  ! has to be called before starting grid deformation.
!</description>  

!<inputoutput>  
  ! We will fill this structure with useful values
  type(t_griddefInfo), intent(inout) :: rgriddefInfo
  
  ! The underlying triangulation
  type(t_triangulation), intent(inout), target :: rtriangulation
  
  ! the boundary information
  type(t_boundary), intent(inout), target :: rboundary
  
  ! user defined number of adaptation steps
  integer, optional :: iadaptSteps
  
!</inputoutput>

!<input>
  integer, intent(in) :: NLMAX 
  
  integer, intent(in) :: NLMIN
  
  ! the deformation method to use multilevel or classical
  ! GRIDDEF_CLASSICAL or GRIDDEF_MULTILEVEL
  integer, intent(in) :: iStyle
!</input>  
!</subroutine>
  
  ! Local variables
  integer :: iaux
  ! pointers to the arrays, we need to fill 
  ! with useful default parameters
  integer, dimension(:), pointer :: p_Dql2
  integer, dimension(:), pointer :: p_Dqlinfty  
  integer, dimension(:), pointer :: p_nadapSteps  
  integer, dimension(:), pointer :: p_calcAdapSteps    
  integer, dimension(:), pointer :: p_nadapStepsReally      
  integer, dimension(:), pointer :: p_nmaxCorrSteps        
  integer, dimension(:), pointer :: p_ncorrSteps          
  integer, dimension(:), pointer :: p_ilevelODE          
  integer, dimension(:), pointer :: p_ilevelODECorr         
  integer, dimension(:), pointer :: p_npreSmoothSteps          
  integer, dimension(:), pointer :: p_npostSmoothSteps          
  integer, dimension(:), pointer :: p_nintSmoothSteps          
  integer, dimension(:), pointer :: p_nmonSmoothsteps          
  integer, dimension(:), pointer :: p_cpreSmoothMthd          
  integer, dimension(:), pointer :: p_cpostSmoothMthd          
  integer, dimension(:), pointer :: p_cintSmoothMthd            
  real(dp), dimension(:), pointer :: p_DblendPar            
  
  ! We store a pointer to the input triangulation
  ! in the moveMesh subroutine we dublicate it and
  ! and only share the vertex coordinates...
  rgriddefInfo%p_rtriangulation => rtriangulation 
  
  rgriddefInfo%p_rboundary => rboundary
  
  rgriddefInfo%dblendPar = 1.0_dp
  
  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_Dql2',&
                   NLMAX, ST_INT, rgriddefInfo%h_Dql2,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_Dqlinfty',&
                   NLMAX, ST_INT, rgriddefInfo%h_Dqlinfty,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_nadapSteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_nadapSteps,&
                   ST_NEWBLOCK_ZERO)    
                   
  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_calcAdapSteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_calcAdapSteps,&
                   ST_NEWBLOCK_ZERO)    


  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_nadapStepsReally',&
                   NLMAX, ST_INT, rgriddefInfo%h_nadapStepsReally,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_nmaxCorrSteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_nmaxCorrSteps,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_ncorrSteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_ncorrSteps,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_ilevelODE',&
                   NLMAX, ST_INT, rgriddefInfo%h_ilevelODE,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_ilevelODECorr',&
                   NLMAX, ST_INT, rgriddefInfo%h_ilevelODECorr,&
                   ST_NEWBLOCK_ZERO)    


  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_npreSmoothSteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_npreSmoothSteps,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_npostSmoothSteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_npostSmoothSteps,&
                   ST_NEWBLOCK_ZERO)    


  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_nintSmoothSteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_nintSmoothSteps,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_nmonSmoothsteps',&
                   NLMAX, ST_INT, rgriddefInfo%h_nmonSmoothsteps,&
                   ST_NEWBLOCK_ZERO)    


  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_cpreSmoothMthd',&
                   NLMAX, ST_INT, rgriddefInfo%h_cpreSmoothMthd,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_cpostSmoothMthd',&
                   NLMAX, ST_INT, rgriddefInfo%h_cpostSmoothMthd,&
                   ST_NEWBLOCK_ZERO)    

  ! now allocate memory for the arrays
  call storage_new('griddef_deformationInit', 'rgriddefInfo%h_cintSmoothMthd',&
                   NLMAX, ST_INT, rgriddefInfo%h_cintSmoothMthd,&
                   ST_NEWBLOCK_ZERO)    

    
  
  ! Now get all the just allocated pointers
  call storage_getbase_int(rgriddefInfo%h_Dql2,p_Dql2)
  
  call storage_getbase_int(rgriddefInfo%h_Dqlinfty,p_Dqlinfty)  

  call storage_getbase_int(rgriddefInfo%h_nadapSteps,p_nadapSteps)  
  
  call storage_getbase_int(rgriddefInfo%h_calcAdapSteps,p_calcAdapSteps)    
  
  call storage_getbase_int(rgriddefInfo%h_nadapStepsReally,p_nadapStepsReally)      
  
  call storage_getbase_int(rgriddefInfo%h_nmaxCorrSteps,p_nmaxCorrSteps)        
  
  call storage_getbase_int(rgriddefInfo%h_ncorrSteps,p_ncorrSteps)          

  call storage_getbase_int(rgriddefInfo%h_ilevelODE,p_ilevelODE)          

  call storage_getbase_int(rgriddefInfo%h_ilevelODECorr,p_ilevelODECorr)          
  
  call storage_getbase_int(rgriddefInfo%h_npreSmoothSteps,p_npreSmoothSteps)          

  call storage_getbase_int(rgriddefInfo%h_npostSmoothSteps,p_npostSmoothSteps)          

  call storage_getbase_int(rgriddefInfo%h_nintSmoothSteps,p_nintSmoothSteps)          
    
  call storage_getbase_int(rgriddefInfo%h_nmonSmoothsteps,p_nmonSmoothsteps)          
      
  call storage_getbase_int(rgriddefInfo%h_cpreSmoothMthd,p_cpreSmoothMthd)          

  call storage_getbase_int(rgriddefInfo%h_cpostSmoothMthd,p_cpostSmoothMthd)          
  
  call storage_getbase_int(rgriddefInfo%h_cintSmoothMthd,p_cintSmoothMthd)            


  ! Set the deformation style to classical
  rgriddefInfo%cdefStyle = iStyle

  ! temp variable 
  iaux = 0
  
  ! set the multigrid level for the deformation PDE
  rgriddefInfo%iminDefLevel = NLMAX
  
  ! Here we initialize the structure with the standard values according to
  ! the desired grid deformation method.
  select case(rgriddefInfo%cdefStyle)
  
      case(GRIDDEF_CLASSICAL)

        ! initialise... here should be the absolute PDE Level
        ! where the deformation takes place.     
        iaux = 1
      
        ! initialise the tolerance
        rgriddefInfo%dtolQ = 1.0E10_DP      
        
        ! set the multigrid level for the deformation PDE(really ?)
        p_ilevelODE(rgriddefInfo%iminDefLevel) = rgriddefInfo%iminDefLevel

        ! number of smoothing steps for creating the monitor function
        p_nintSmoothSteps(rgriddefInfo%iminDefLevel) = 0
        
        ! smoothing method used
        p_CintSmoothMthd(rgriddefInfo%iminDefLevel) = 0

        ! number of smoothing steps for monitor function
        p_NMonSmoothSteps(rgriddefInfo%iminDefLevel) = 0
        
        ! set standard value for number of correction steps
        p_nmaxCorrSteps(iaux) = 0
        
        ! set standard value for number of ODE correction steps        
        p_ilevelODECorr(iaux) = 0
        
        ! initialize the blending parameter
        rgriddefInfo%dblendPar = 1.0_dp
        
        if(present(iadaptSteps))then
          ! initialize the number of adaptation steps
          rgriddefInfo%nadaptionSteps = iadaptSteps
          
          ! set Adaptive control
          ! the number of steps on all levels is user defined
          p_calcAdapSteps(:) = GRIDDEF_USER
        else
          ! initialize the number of adaptation steps
          rgriddefInfo%nadaptionSteps = 1
          
          ! the number of steps on all levels is
          ! fixed
          p_calcAdapSteps(:) = GRIDDEF_FIXED
        end if
        
     case(GRIDDEF_MULTILEVEL)
     
     ! do something here in the future        
      call output_line ('MULTILEVEL method not yet implemented', &
          OU_CLASS_ERROR,OU_MODE_STD,'griddef_deformationInit')
      call sys_halt()     
        
  end select
  
  ! get number of correction steps on level iaux
  p_nmaxCorrSteps(rgriddefInfo%iminDefLevel) = 0

  ! get the minimum deformation level
  p_ilevelODECorr(rgriddefInfo%iminDefLevel) = rgriddefInfo%iminDefLevel
  
  ! store the value of NLMIN
  rgriddefInfo%NLMIN = NLMIN

  ! store the value of NLMAX  
  rgriddefInfo%NLMAX = NLMAX
  
  ! Allocate memory for all the levels.
  allocate(rgriddefInfo%p_rhLevels(1:NLMAX))

  end subroutine 

!****************************************************************************************
  
!<subroutine>
  subroutine griddef_buildHGrid(rgriddefInfo,rtriangulation,iLevel)
!<description>
  ! In this routine we build the HGridstructure that
  ! represent the levels of the grid, this structure has an own working copy
  ! of all the vertices and boundary parameter values of the original grid.
  ! The other grid information is merely shared and not copied.
!</description>  

!<inputoutput>  
  ! We will fill this structure with useful values
  type(t_griddefInfo), intent(inout) :: rgriddefInfo
  
  ! The underlying triangulation
  type(t_triangulation), intent(inout), target :: rtriangulation
  
!</inputoutput>

!<input>
  integer, intent(in) :: iLevel  
!</input>  

!</subroutine>
  
  ! Local variables
  integer :: i,idupFlag
  
  ! we dublicate all levels of the grid hierachy and
  ! share the vertices, only on the level NLMAX we
  ! actually copy the vertex coordinates
  ! Set it up to share all 
  idupFlag = TR_SHARE_ALL
  if(iLevel .lt. rgriddefInfo%NLMIN)then
    !nothing
  else if((iLevel .ge. rgriddefInfo%NLMIN).and.(iLevel .lt. rgriddefInfo%NLMAX))then
    ! share all
    call tria_duplicate(rtriangulation,&
         rgriddefInfo%p_rhLevels(iLevel)%rtriangulation,idupFlag)
  else if(iLevel .eq. rgriddefInfo%NLMAX)then
    ! we only want to dublicate the vertexcoords
    ! and boundary parameters
    idupFlag = idupFlag - TR_SHARE_DVERTEXCOORDS
    idupFlag = idupFlag - TR_SHARE_DVERTEXPARAMETERVALUE

    ! We copy only the vertex coordinates and the boundary parameter values
    call tria_duplicate(rtriangulation,&
         rgriddefInfo%p_rhLevels(iLevel)%rtriangulation,idupFlag)
  else
    call output_line ('Level input not valid', &
        OU_CLASS_ERROR,OU_MODE_STD,'griddef_buildHGrid')
    call sys_halt()     
  end if
 
  end subroutine ! griddef_buildHGrid

!****************************************************************************************

!<subroutine>  
  subroutine griddef_DeformationDone(rgriddefInfo,rgriddefWork)
!<description>
  ! 
  ! Here we release the rgriddefInfo structure
  ! and all the elements that are contained
  ! within it.
  !
!</description>
  
!<inputoutput>  
  ! We will fill this structure with useful values
  type(t_griddefInfo), intent(inout) :: rgriddefInfo
  
  !
  type(t_griddefWork), intent(inout) :: rgriddefWork
!</inputoutput>
!</subroutine>

  ! deallocate memory
  if (rgriddefInfo%h_Dql2 .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_Dql2)
  end if
  
  ! deallocate memory
  if (rgriddefInfo%h_Dqlinfty .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_Dqlinfty)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_calcAdapSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_calcAdapSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nadapSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nadapSteps)
  end if


  ! deallocate memory
  if (rgriddefInfo%h_nadapStepsReally .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nadapStepsReally)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nmaxCorrSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nmaxCorrSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_ncorrSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_ncorrSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_ilevelODE .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_ilevelODE)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_ilevelODECorr .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_ilevelODECorr)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_npreSmoothSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_npreSmoothSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_npostSmoothSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_npostSmoothSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nintSmoothSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nintSmoothSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nmonSmoothsteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nmonSmoothsteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_cpreSmoothMthd .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_cpreSmoothMthd)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_cpostSmoothMthd .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_cpostSmoothMthd)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_cintSmoothMthd .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_cintSmoothMthd)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_DblendPar .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_DblendPar)
  end if
  
  call tria_done (rgriddefInfo%p_rhLevels(rgriddefInfo%NLMAX)%rtriangulation)
  
  ! release copied memory on the NLMAX level
  
  ! deallocate the levels structure
  deallocate(rgriddefInfo%p_rhLevels)
  
  if(rgriddefWork%breinit)then  
    call griddef_freeWorkDef(rgriddefWork)
  end if
  
  end subroutine  
  
!****************************************************************************************


!<subroutine>
  subroutine griddef_freeWorkDef(rgriddefWork)
!<description>
  ! release the memory used in the rgriddefWork 
  ! structure.
!</description>
  
  !<inputoutput>
  type(t_griddefWork), intent(inout) :: rgriddefWork
  !</inputoutput>
  
!</subroutine>

  ! free the vectors
  call lsysbl_releaseVector(rgriddefWork%rvectorAreaBlockQ1)
  call lsysbl_releaseVector(rgriddefWork%rvectorMonFuncQ1)
  call lsysbl_releaseVector(rgriddefWork%rSolBlock)
  call lsysbl_releaseVector(rgriddefWork%rrhsBlock)
  call lsysbl_releaseVector(rgriddefWork%rtempBlock)
  call lsysbl_releaseVector(rgriddefWork%rvecGradBlock)
  
  ! free the matrices
  call lsysbl_releaseMatrix(rgriddefWork%rmatDeform)
  call lsyssc_releaseMatrix(rgriddefWork%rmatrix)

  
  end subroutine ! griddef_WorkDef

!****************************************************************************************

!<subroutine>  
  subroutine griddef_reinitDefInfo(rgriddefInfo)
!<description>
  ! 
  ! Here we release the rgriddefInfo structure
  ! and all the elements that are contained
  ! within it.
  !
!</description>
  
!<inputoutput>  
  ! We will fill this structure with useful values
  type(t_griddefInfo), intent(inout) :: rgriddefInfo
!</inputoutput>
!</subroutine>

  ! deallocate memory
  if (rgriddefInfo%h_Dql2 .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_Dql2)
  end if
  
  ! deallocate memory
  if (rgriddefInfo%h_Dqlinfty .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_Dqlinfty)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_calcAdapSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_calcAdapSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nadapSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nadapSteps)
  end if


  ! deallocate memory
  if (rgriddefInfo%h_nadapStepsReally .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nadapStepsReally)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nmaxCorrSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nmaxCorrSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_ncorrSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_ncorrSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_ilevelODE .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_ilevelODE)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_ilevelODECorr .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_ilevelODECorr)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_npreSmoothSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_npreSmoothSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_npostSmoothSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_npostSmoothSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nintSmoothSteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nintSmoothSteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_nmonSmoothsteps .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_nmonSmoothsteps)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_cpreSmoothMthd .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_cpreSmoothMthd)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_cpostSmoothMthd .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_cpostSmoothMthd)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_cintSmoothMthd .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_cintSmoothMthd)
  end if

  ! deallocate memory
  if (rgriddefInfo%h_DblendPar .NE. ST_NOHANDLE) then
    call storage_free(rgriddefInfo%h_DblendPar)
  end if
  
  
  end subroutine  
  
!****************************************************************************************


!<subroutine>
  subroutine griddef_reinitWork(rgriddefWork)
!<description>
  ! release the memory used in the rgriddefWork 
  ! structure.
!</description>
  
  !<inputoutput>
  type(t_griddefWork), intent(inout) :: rgriddefWork
  !</inputoutput>
  
!</subroutine>

  if(rgriddefWork%breinit)then
    ! free the vectors
    call lsysbl_releaseVector(rgriddefWork%rvectorAreaBlockQ1)
    call lsysbl_releaseVector(rgriddefWork%rvectorMonFuncQ1)
    call lsysbl_releaseVector(rgriddefWork%rSolBlock)
    call lsysbl_releaseVector(rgriddefWork%rrhsBlock)
    call lsysbl_releaseVector(rgriddefWork%rtempBlock)
    call lsysbl_releaseVector(rgriddefWork%rvecGradBlock)
    
    ! free the matrices
    call lsysbl_releaseMatrix(rgriddefWork%rmatDeform)
    call lsyssc_releaseMatrix(rgriddefWork%rmatrix)
    rgriddefWork%breinit = .false.
  end if
  
  end subroutine ! griddef_reinitWork


!****************************************************************************************
  
!<subroutine>   
  subroutine griddef_calcMonitorFunction(rgriddefInfo, rdiscretisation, &
                                      rgriddefWork,def_monitorfct)
  !<description>
    ! 
    ! In this subroutine we calculate the values of the monitor
    ! function by means of the given monitor function.
    !
  !</description>

  !<inputout>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork), intent(inout) :: rgriddefWork

    ! An object specifying the discretisation.
    ! This contains also information about trial/test functions,...
    type(t_blockDiscretisation), intent(in)  :: rdiscretisation    

  !</inputout>

    ! A callback routine for the monitor function
    include 'intf_monitorfct.inc'
    optional :: def_monitorfct

!</subroutine>

  ! local variables
  real(dp), dimension(:,:), pointer :: p_DvertexCoords
  real(dp), dimension(:), pointer :: p_Dentries
  type(t_vectorScalar), pointer :: p_rvectorMonFuncQ1 
  
  ! get the pointer to the coords of the grid
  ! this only works for Q1
  call storage_getbase_double2D (rgriddefInfo%p_rtriangulation%h_DvertexCoords,&
    p_DvertexCoords)
    
  ! Set up an empty block vector    
  call lsysbl_createVecBlockByDiscr(rdiscretisation,rgriddefWork%rvectorMonFuncQ1,.TRUE.) 

  ! Get a pointer just not to write such a long name  
  p_rvectorMonFuncQ1 => rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1)
  
  ! get the data
  call storage_getbase_double(p_rvectorMonFuncQ1%h_ddata,p_Dentries)
  
  ! calculate monitor function
  call def_monitorfct(p_DvertexCoords,p_Dentries)

   
  end subroutine
  
!****************************************************************************************

!<subroutine>  
  subroutine griddef_prepareDeformation(rgriddefInfo,rgriddefWork)
  !<description>
    ! This subroutine performs all preparations for deformation which are necessary
    ! for the first deformation run in the program and after every change of the compute
    ! level. 
  !</description>

  !<inputout>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork), intent(inout) :: rgriddefWork

  !</inputout>

!</subroutine>

  ! local variables
  
  ! maximum number of correction steps (local instance)
  integer:: idupFlag, NEL, NVT, NLMAX

  ! get these numbers 
  NEL   = rgriddefInfo%p_rtriangulation%NEL
  NVT   = rgriddefInfo%p_rtriangulation%NVT
  NLMAX = rgriddefInfo%iminDefLevel
                                        
  end subroutine ! end griddef_prepareDeformation

! ****************************************************************************************  

!<subroutine>
  subroutine griddef_performDeformation(rgriddefInfo, rgriddefWork, &
                                        h_Dcontrib,&
                                        bstartNew, blevelHasChanged, bterminate, &
                                        bdegenerated, imgLevelCalc, iiteradapt, ibcIdx,& 
                                        def_monitorfct)
  !<description>
    ! This subroutine is the main routine for the grid deformation process, as all 
    ! necessary steps are included here. For performing grid deformation, it is sufficient
    ! to define a monitor function and call this routine or to have an error distribution
    ! at hand and call this subroutine.
  !</description>

  !<input>
    ! A block matrix and a couple of block vectors. These will be filled
    ! with data for the linear solver.

    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo
    
    type(t_griddefWork), intent(inout) :: rgriddefWork
    
    ! if true, start from scratch: new vectors, new boundary conditions structures
    logical, intent(in) :: bstartNew

    ! if true, adjust the vectors after level change since a previous deformation call
    logical, intent(in) :: blevelHasChanged

    logical, intent(in) :: bterminate
    
    ! number of adaptive iteration
    integer, intent(in) :: iiterAdapt

    ! multigrid level on which the simulation was computed
    integer, intent(in) :: imgLevelCalc

    ! index of boundary condition related to the deformation PDE
    integer, intent(in):: ibcIdx
  !</input>

    ! flag for grid checking: if true, the deformation process would lead to
    ! a grid with tangled elements
    logical , intent(in):: bdegenerated

  !<inoutput>
    ! handle of vector with elementwise error contributions
    integer, intent(inout):: h_Dcontrib
  !</inoutput>
  
    ! A callback routine for the monitor function
    include 'intf_monitorfct.inc'
    optional :: def_monitorfct
  

!</subroutine>

  ! local variables
  integer :: nmaxCorrSteps, NLMAX,ilevelODE,idef
  ! A scalar matrix and vector. The vector accepts the RHS of the problem
  ! in scalar form.
  
  integer, dimension(:), pointer :: p_nadapStepsReally
  real(dp), dimension(:), pointer :: p_DblendPar    
  integer, dimension(:), pointer :: p_ilevelODE  
  
  ! We deform on level nlmax
  NLMAX = rgriddefInfo%iminDefLevel
  
  ! get some needed pointers
  call storage_getbase_int(rgriddefInfo%h_nadapStepsReally,p_nadapStepsReally)
  
  call storage_getbase_int(rgriddefInfo%h_ilevelODE,p_ilevelODE)            

  ! necessary for boundary projection only, not for adding the Neumann boundary
  ! condition

  ! create and modify all vectors necessary for deformation steps
  call griddef_prepareDeformation(rgriddefInfo,rgriddefWork)

  ! Compute the number of deformation steps 
  call griddef_computeAdapSteps(rgriddefInfo,rgriddefWork)
  ! Compute the blending parameter
  
  ! compute number of deformation steps on current level ilevel
  !call griddef_computeAdapSteps(rparBlock, rgriddefInfo, ilevel, pfmon)

  nmaxCorrSteps = 0

  call storage_getbase_double(rgriddefInfo%h_DblendPar,p_DblendPar)

  ! loop over adaption cycles
    do idef = 1,rgriddefInfo%nadaptionSteps

    call output_lbrk ()
    print *,"Adaptation Step: ",idef
    call output_line ('-------------------')
    call output_lbrk ()

    call griddef_reinitWork(rgriddefWork)
    ! perform one deformation step: This routine appplies deformation to the
    call  griddef_performOneDefStep(rgriddefInfo, rgriddefWork,&
                                       p_DblendPar(idef), NLMAX, NLMAX,&
                                       def_monitorfct)
                                     
  end do ! end do  

  end subroutine
 
 ! **************************************************************************************** 
 
!<subroutine>
  subroutine griddef_computeAdapSteps(rgriddefInfo,rgriddefWork) 

  !<description>
    ! This subroutine performs all preparations for deformation which are necessary
    ! for the first deformation run in the program and after every change of the compute
    ! level. 
  !</description>

  !<inputout>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork), intent(inout) :: rgriddefWork
    
    ! this function should get the current level, do dedide, if
    ! the number of steps should be adaptively on this level.
    
!<\subroutine>

    ! local variables
    integer :: ilevel,idef
    
    integer,dimension(:), pointer :: p_calcAdapSteps
    
    real(dp), dimension(:), pointer :: p_DblendPar
    
    call storage_getbase_int(rgriddefInfo%h_calcAdapSteps,p_calcAdapSteps) 
    
    ! we prescribe a fixed number of adaptation steps
    if(p_calcAdapSteps(rgriddefInfo%iminDefLevel) .eq. GRIDDEF_FIXED)then
    
      rgriddefInfo%nadaptionSteps = 20
    
    end if
    if(p_calcAdapSteps(rgriddefInfo%iminDefLevel) .eq. GRIDDEF_USER)then
      ! the Steps are not really set adaptively in 
      ! case we enter this branch, the p_calcAdapSteps have already been
      ! set.
    end if
    
    
    ! now allocate memory for the parameters
    call storage_new('griddef_computeAdapSteps','rgriddefInfo%h_DblendPar',&
          rgriddefInfo%nadaptionSteps,ST_doUBLE,rgriddefInfo%h_DblendPar,&
          ST_NEWBLOCK_ZERO)
          
    call storage_getbase_double(rgriddefInfo%h_DblendPar,p_DblendPar)   
    
    ! compute the blending parameter
    do idef=1,rgriddefInfo%nadaptionSteps-1
      ! evaluate formula
      p_DblendPar(idef) = &
      sqrt(sqrt(real(idef)/real(rgriddefInfo%nadaptionSteps)))
    end do ! end idef
    
    ! set the parameter for the final step
    p_DblendPar(rgriddefInfo%nadaptionSteps) = 1.0_dp
                                      
  end subroutine ! griddef_computeAdapSteps
  
! **************************************************************************************** 
 

!<subroutine>
  subroutine griddef_performOneDefStep(rgriddefInfo, rgriddefWork,&
                                       dblendpar, ilevelODE, ilevel,&
                                       def_monitorfct)
  !<description>
    ! This subroutine performs one deformation step of the enhanced deformation method.
  !</description>

  !<inputoutput>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork), intent(inout) :: rgriddefWork
  !</inputoutput>
  
  !<input>  
    ! absolute level on which the points are moved
    integer, intent(in) :: ilevelODE

    ! absolute level on which the deformation PDE is solved
    integer, intent(in) :: ilevel
    
    ! blending parameter for monitorfunction sf + (1-s)g
    real(DP), intent(inout) :: dblendpar
  !</input>
    ! A callback routine for the monitor function
    include 'intf_monitorfct.inc'
    optional :: def_monitorfct

!</subroutine>

    ! local variables
    real(dp), dimension(:,:), pointer :: Dresults
    ! scaling factor for monitor function (exact case only)
    real(dp) :: dscalefmon
    ! scaling factor for the reciprocal of the blended monitor function (exact case only)
    real(dp) :: dscalefmonInv
    ! weighting parameter for Laplacian smoothing of the vector field
    real(dp) :: dscale1,dscale2
    logical :: bBlending
    
    ! An object specifying the discretisation.
    ! This contains also information about trial/test functions,...
    type(t_blockDiscretisation) :: rdiscretisation,rDubDiscretisation   
         
    
    ! A solver node that accepts parameters for the linear solver    
    type(t_linsolNode), pointer :: p_rsolverNode,p_rpreconditioner

    ! An array for the system matrix(matrices) during the initialisation of
    ! the linear solver.
    type(t_matrixBlock), dimension(1) :: Rmatrices

    ! A filter chain that describes how to filter the matrix/vector
    ! before/during the solution process. The filters usually implement
    ! boundary conditions.
    type(t_filterChain), dimension(2), target :: RfilterChain
    type(t_filterChain), dimension(:), pointer :: p_RfilterChain
    
    ! Error indicator during initialisation of the solver
    integer :: ierror,NLMAX    
    
    NLMAX=rgriddefInfo%NLMAX
    
    ! initialise Dresults
    Dresults  => NULL()

    ! no blending
    bBlending = .TRUE.
    
!    call spdiscr_initBlockDiscr (rdiscretisation,1,&
!         rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation, rgriddefInfo%p_rboundary)

    ! Now we can start to initialise the discretisation. At first, set up
    ! a block discretisation structure that specifies the blocks in the
    ! solution vector. In this simple problem, we only have one block.
    call spdiscr_initBlockDiscr (rdiscretisation,1,&
         rgriddefInfo%p_rtriangulation, rgriddefInfo%p_rboundary)


    
!    call spdiscr_initDiscr_simple (rdiscretisation%RspatialDiscr(1), &
!                                   EL_E011,CUB_G2X2,&
!                                   rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation,&
!                                   rgriddefInfo%p_rboundary)
    

    ! rdiscretisation%Rdiscretisations is a list of scalar discretisation
    ! structures for every component of the solution vector.
    ! Initialise the first element of the list to specify the element
    ! and cubature rule for this solution component:
    call spdiscr_initDiscr_simple (rdiscretisation%RspatialDiscr(1), &
                                   EL_E011,CUB_G2X2,&
                                   rgriddefInfo%p_rtriangulation,&
                                   rgriddefInfo%p_rboundary)


    ! compute the original area distribution g(x)
    call griddef_getArea(rgriddefInfo, rgriddefWork,rdiscretisation)

    if(present(def_monitorfct))then
      ! calculate the monitor/target grid area distribution f(x)
      call griddef_calcMonitorFunction(rgriddefInfo,rdiscretisation,&
                                       rgriddefWork,def_monitorfct)
    else
      ! or build a test monitor function
      call griddef_buildMonFuncTest(rgriddefInfo, rgriddefWork,rdiscretisation)
    end if
    

    ! blend monitor with current area distribution, if necessary
    if(bBlending) then
      ! Compute the scaling factors dscale1 and dscale2 for f and g and scale them
      call griddef_normaliseFctsNum(rgriddefInfo,rgriddefWork,dscale1,dscale2)
      call griddef_blendmonitor(rgriddefInfo,rgriddefWork,dblendpar)
    end if

    ! normalise the reciprocal of the functions
    call griddef_normaliseFctsInv(rgriddefInfo,rgriddefWork,rdiscretisation)

    ! create the matrix for the poisson problem
    call griddef_createMatrixDef(rgriddefWork,rdiscretisation)

    ! create rhs for deformation problem
    call griddef_createRhs(rgriddefWork,rdiscretisation)
    
    ! During the linear solver, the boundary conditions are also
    ! frequently imposed to the vectors. But as the linear solver
    ! does not work with the actual solution vectors but with
    ! defect vectors instead.
    ! So, set up a filter chain that filters the defect vector
    ! during the solution process to implement discrete boundary conditions.
    RfilterChain(1)%ifilterType = FILTER_DISCBCDEFreal
    RfilterChain(2)%ifilterType = FILTER_SMALLL1TO0
    RfilterChain(2)%ismallL1to0component = 1
    
    ! Create a BiCGStab-solver. Attach the above filter chain
    ! to the solver, so that the solver automatically filters
    ! the vector during the solution process.
    p_RfilterChain => RfilterChain
    nullify(p_rpreconditioner)
    call linsol_initBiCgStab (p_rsolverNode,p_rpreconditioner,p_RfilterChain)    
    !call linsol_initBi (p_rsolverNode)    
    
    ! Set the output level of the solver to 2 for some output
    p_rsolverNode%ioutputLevel = 2    
    
    p_rsolverNode%nmaxIterations = 500
    
    ! Attach the system matrix to the solver.
    ! First create an array with the matrix data (on all levels, but we
    ! only have one level here), then call the initialisation 
    ! routine to attach all these matrices.
    ! Remark: Do not make a call like
    !    call linsol_setMatrices(p_RsolverNode,(/p_rmatrix/))
    ! This does not work on all compilers, since the compiler would have
    ! to create a temp array on the stack - which does not always work!
    Rmatrices = (/rgriddefWork%rmatDeform/)
    call linsol_setMatrices(p_RsolverNode,Rmatrices)
    
    ! Initialise structure/data of the solver. This allows the
    ! solver to allocate memory / perform some precalculation
    ! to the problem.
    call linsol_initStructure (p_rsolverNode, ierror)
    if (ierror .NE. LINSOL_ERR_NOERROR) stop
    call linsol_initData (p_rsolverNode, ierror)
    if (ierror .NE. LINSOL_ERR_NOERROR) stop
    
    ! Finally solve the system. As we want to solve Ax=b with
    ! b being the real RHS and x being the real solution vector,
    ! we use linsol_solveAdaptively. If b is a defect
    ! RHS and x a defect update to be added to a solution vector,
    ! we would have to use linsol_precondDefect instead.
    call linsol_solveAdaptively (p_rsolverNode,rgriddefWork%rSolBlock,&
                                 rgriddefWork%rrhsBlock,rgriddefWork%rtempBlock)    

    call spdiscr_initBlockDiscr (rDubDiscretisation,2,&
                                 rgriddefInfo%p_rtriangulation)

    call spdiscr_deriveSimpleDiscrSc (&
                 rdiscretisation%RspatialDiscr(1), &
                 EL_Q1, CUB_G2X2, rDubDiscretisation%RspatialDiscr(1))
                 
    call spdiscr_deriveSimpleDiscrSc (&
                 rdiscretisation%RspatialDiscr(1), &
                 EL_Q1, CUB_G2X2, rDubDiscretisation%RspatialDiscr(2))
                 
                 
    ! initialise the block vector that should hold the solution
    call lsysbl_createVecBlockByDiscr(rDubDiscretisation,rgriddefWork%rvecGradBlock,.TRUE.)
    
    ! get the recovered gradient of the solution
    call ppgrd_calcGradient(rgriddefWork%rSolBlock%RvectorBlock(1),&
                            rgriddefWork%rvecGradBlock,PPGRD_INTERPOL)

    ! Solve the ODE and move the mesh
    call griddef_moveMesh(rgriddefInfo, rgriddefWork)
    
    ! Release solver data and structure
    call linsol_doneData (p_rsolverNode)
    call linsol_doneStructure (p_rsolverNode)
    
    ! Release the solver node and all subnodes attached to it (if at all):
    call linsol_releaseSolver (p_rsolverNode)
    
    ! The vertices of the triangulation
    ! we have a dirty work structure
    rgriddefWork%breinit= .true.
    
    ! Release the discretisation structure and all spatial discretisation
    ! structures in it.
    call spdiscr_releaseBlockDiscr(rdiscretisation)
    call spdiscr_releaseBlockDiscr(rDubDiscretisation)
    
  
  end subroutine ! end griddef_performOneDefStep

  ! *************************************************************************** 

!<subroutine>  
  subroutine griddef_getArea(rgriddefInfo, rgriddefWork,rdiscretisation)
  
  !<description>
    ! In this function we build the nodewise area distribution out 
    ! of an elementwise distribution
  !</description>

  !<inputoutput>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork), intent(inout) :: rgriddefWork
    
    type(t_blockDiscretisation), intent(inout) :: rdiscretisation    
    
  !</inputoutput>

!</subroutine>

    ! local variables
    integer, dimension(:,:), pointer :: p_IverticesAtElement
    integer, dimension(:), pointer :: p_DareaLevel
    real(DP), dimension(:,:), pointer :: p_DvertexCoords
    real(DP), dimension(:), pointer :: p_Darea
    real(DP), dimension(:), pointer :: p_DareaProj    
    integer :: iel
    real(DP), dimension(NDIM2D,TRIA_MAXNVE2D) :: Dpoints
    integer :: ive
    type(t_vectorScalar) :: rvectorAreaQ0 
    type(t_vectorBlock) :: rvectorAreaBlockQ0
    type(t_blockDiscretisation) :: rprjDiscretisation
    
    ! Is everything here we need?
    if (rgriddefInfo%p_rtriangulation%h_DvertexCoords .EQ. ST_NOHANDLE) then
      call output_line ('h_DvertexCoords not available!', &
                        OU_CLASS_ERROR,OU_MODE_STD,'tria_genElementVolume2D')
      call sys_halt()
    end if

    if (rgriddefInfo%p_rtriangulation%h_IverticesAtElement .EQ. ST_NOHANDLE) then
      call output_line ('IverticesAtElement  not available!', &
                        OU_CLASS_ERROR,OU_MODE_STD,'tria_genElementVolume2D')
      call sys_halt()
    end if
    
    ! Do we have (enough) memory for that array?
    if (rgriddefInfo%p_rtriangulation%h_DelementVolume .EQ. ST_NOHANDLE) then
      call storage_new ('tria_genElementVolume2D', 'DAREA', &
          int(rgriddefInfo%p_rtriangulation%NEL+1,I32), ST_doUBLE, &
          rgriddefInfo%p_rtriangulation%h_DelementVolume, ST_NEWBLOCK_NOINIT)
    end if
    
    
    ! Get the arrays
    call storage_getbase_double2D (rgriddefInfo%p_rtriangulation%h_DvertexCoords,&
        p_DvertexCoords)
    call storage_getbase_int2D (rgriddefInfo%p_rtriangulation%h_IverticesAtElement,&
        p_IverticesAtElement)
    
    ! Set up an empty block vector    
    call lsysbl_createVecBlockByDiscr(rdiscretisation,rgriddefWork%rvectorAreaBlockQ1,.TRUE.)        
        
    ! Create a discretisation structure for Q0, based on our
    ! previous discretisation structure:
    call spdiscr_duplicateBlockDiscr(rdiscretisation,rprjDiscretisation)
    call spdiscr_deriveSimpleDiscrSc (&
                 rdiscretisation%RspatialDiscr(1), &
                 EL_Q0, CUB_G2X2, rprjDiscretisation%RspatialDiscr(1))
                 
    ! Initialise a Q0 vector from the newly created discretisation         
    call lsyssc_createVecByDiscr(rprjDiscretisation%RspatialDiscr(1), &
    rvectorAreaQ0,.true.)
    
    ! get the pointer to the entries of this vector
    call lsyssc_getbase_double(rvectorAreaQ0,p_Darea)    
    
    ! Loop over all elements calculate the area 
    ! and save it in our vector
    do iel=1,rgriddefInfo%p_rtriangulation%NEL
      
      if (p_IverticesAtElement(4,iel) .EQ. 0) then
        ! triangular element
        do ive=1,TRIA_NVETRI2D
          Dpoints(1,ive) = p_DvertexCoords(1,p_IverticesAtElement(ive,iel))
          Dpoints(2,ive) = p_DvertexCoords(2,p_IverticesAtElement(ive,iel))
        end do
        p_Darea(iel) = gaux_getArea_tria2D(Dpoints)
      else
        ! quad element
        do ive=1,TRIA_NVEQUAD2D
          Dpoints(1,ive) = p_DvertexCoords(1,p_IverticesAtElement(ive,iel))
          Dpoints(2,ive) = p_DvertexCoords(2,p_IverticesAtElement(ive,iel))
        end do
        p_Darea(iel) = gaux_getArea_quad2D(Dpoints)
      end if

    end do ! end iel
    
    ! now transform the q0 vector into a q1 vector
    ! Setup a new solution vector based on this discretisation,
    ! allocate memory.
    call lsysbl_createVecFromScalar(rvectorAreaQ0,rvectorAreaBlockQ0,rprjDiscretisation)
 
    ! Take the original solution vector and convert it according to the
    ! new discretisation:
    call spdp_projectSolution(rvectorAreaBlockQ0,rgriddefWork%rvectorAreaBlockQ1)
    
    call lsysbl_releaseVector(rvectorAreaBlockQ0)
    call lsyssc_releaseVector(rvectorAreaQ0)
  
  end subroutine

  ! *************************************************************************** 
  
!<subroutine>  
  subroutine griddef_buildMonFuncTest(rgriddefInfo, rgriddefWork,rdiscretisation)
  
  !<description>
    ! In this function we build the nodewise area distribution out 
    ! of an elementwise distribution
  !</description>

  !<inputoutput>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork), intent(inout) :: rgriddefWork
    
    type(t_blockDiscretisation), intent(inout) :: rdiscretisation    
    
  !</inputoutput>

!</subroutine>

  ! local variables
  integer, dimension(:,:), pointer :: p_IverticesAtElement
  real(DP), dimension(:,:), pointer :: p_DvertexCoords
  real(DP), dimension(:), pointer :: p_Dentries
  integer :: ive
  type(t_vectorScalar), pointer :: p_rvectorMonFuncQ1 
  integer :: iMethod
  real(DP) :: Dist
  iMethod = 1
  
  ! get the pointer to the coords of the grid
  ! this only works for Q1
  call storage_getbase_double2D (rgriddefInfo%p_rtriangulation%h_DvertexCoords,&
    p_DvertexCoords)
    
  ! Set up an empty block vector    
  call lsysbl_createVecBlockByDiscr(rdiscretisation,rgriddefWork%rvectorMonFuncQ1,.TRUE.) 

  ! Get a pointer just not to write such a long name  
  p_rvectorMonFuncQ1 => rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1)
  
  ! get the data
  call storage_getbase_double(p_rvectorMonFuncQ1%h_ddata,p_Dentries)
  
  select case(imethod)
    case(0)
      ! loop over all vertices and compute the monitor function
      do ive=1,rgriddefInfo%p_rtriangulation%NVT
        p_Dentries(ive) = 0.5_dp + p_DvertexCoords(1,ive)
        !p_Dentries(ive) = 1.0_dp
      end do
    case(1)
      ! loop over all vertices and compute the monitor function
      do ive=1,rgriddefInfo%p_rtriangulation%NVT
        Dist = sqrt((0.5_dp - p_DvertexCoords(1,ive))**2 + (0.5_dp - p_DvertexCoords(2,ive))**2)
        ! Good now define the monitor function
        Dist = abs(Dist - 0.2_dp)/0.2_dp
        Dist=max(dist,0.1_dp)
        Dist=min(1.0_dp,dist)
        p_Dentries(ive)=Dist
      end do
    case default
  end select
  
  end subroutine ! end griddef_buildMonFuncTest
  
  ! *************************************************************************** 
  
!<subroutine>     
  subroutine griddef_normaliseFctsNum(rgriddefInfo, rgriddefWork,dScale1,dScale2)
  !<description>
    ! We normalize the functions f and g so that
    ! dScale1 * int_omega f = dScale2 * int_omega g = |omega|
    ! 
  !</description>

  !<inputoutput>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork), intent(inout) :: rgriddefWork
    
  !</inputoutput>
  
  !<output>
  real(dp),intent(inout) :: dScale1    
  real(dp),intent(inout) :: dScale2      
  !</output>  

!</subroutine>

  ! local variables
  ! a shorthand to the functions
  type(t_vectorScalar) , pointer :: p_Df1
  type(t_vectorScalar) , pointer :: p_Df2
  real(DP), dimension(:), pointer :: p_Data1
  real(DP), dimension(:), pointer :: p_Data2  
  ! These will be the values of the integral  
  real(DP) :: dIntF1, dIntF2,Domega
  ! Element area 
  real(DP), dimension(:), pointer :: p_DelementVolume
      
  ! initialise integral value with zero
  dIntF1 = 0.0_dp
  dIntF2 = 0.0_dp
  ! we do not want to write this name 
  p_Df1 => rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1)
  ! we do not want to write this name 
  p_Df2 => rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1)  
  
  
  call storage_getbase_double(rgriddefInfo%p_rtriangulation%h_DelementVolume, &
                              p_DelementVolume)
  
  ! Integrate
  call pperr_scalar (p_Df1,PPERR_L1ERROR,dIntF1)
  call pperr_scalar (p_Df2,PPERR_L1ERROR,dIntF2)
  
  ! compute the area for each element and add up
  call tria_genElementVolume2D(rgriddefInfo%p_rtriangulation)
  
  ! The omega value is the total area of the domain
  Domega = p_DelementVolume(rgriddefInfo%p_rtriangulation%NEL+1)
  
  ! compute the scaling factors
  dScale1 = Domega/dIntF1 
  dScale2 = Domega/dIntF2
  
  ! get the function data
  call lsyssc_getbase_double(p_Df1,p_Data1)
  call lsyssc_getbase_double(p_Df2,p_Data2)
  
  ! scale the functions
  p_Data1(:) =  p_Data1(:) *  dScale1    
  p_Data2(:) =  p_Data2(:) *  dScale2      
                                     
  end subroutine  ! end griddef_normaliseFctsNum
  
  ! ***************************************************************************   

!<subroutine>   
  subroutine griddef_normaliseFctsInv(rgriddefInfo, rgriddefWork,rdiscretisation)
  !<description>
    ! 
    ! 
  !</description>

  !<inputoutput>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo),intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork),intent(inout) :: rgriddefWork
    
    type(t_blockDiscretisation),intent(inout) :: rdiscretisation    
    
  !</inputoutput>

!</subroutine>

  ! local variables
  ! a shorthand to the functions
  type(t_vectorScalar) , pointer :: p_Df1
  type(t_vectorScalar) , pointer :: p_Df2
  real(dp), dimension(:), pointer :: p_Data1
  real(dp), dimension(:), pointer :: p_Data2  
  ! These will be the values of the integral  
  real(dp) :: dIntF1, dIntF2,domega,dScale1,dScale2
  ! Element area 
  real(dp), dimension(:), pointer :: p_DelementVolume
      
  ! initialise integral value with zero
  dIntF1 = 0.0_dp
  dIntF2 = 0.0_dp
  ! we do not want to write this name 
  p_Df1 => rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1)
  ! we do not want to write this name 
  p_Df2 => rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1)  
  
  ! get the function data
  call lsyssc_getbase_double(p_Df1,p_Data1)
  call lsyssc_getbase_double(p_Df2,p_Data2)
  
  ! get the element area pointer
  call storage_getbase_double(rgriddefInfo%p_rtriangulation%h_DelementVolume, &
                              p_DelementVolume)
  
  ! Integrate the functions f and g
  call griddef_normaliseFctsInvAux(rgriddefWork,rdiscretisation,dIntF1,dIntF2,domega)
  
  ! compute the area for each element and add up
  call tria_genElementVolume2D(rgriddefInfo%p_rtriangulation)
  
  ! compute the scaling factor
  dScale1 = dintF1/domega 
  dScale2 = dintF2/domega
  
  ! scale the functions
  p_Data1(:) =  p_Data1(:) *  dScale1    
  p_Data2(:) =  p_Data2(:) *  dScale2         
  
  end subroutine ! end griddef_normaliseFctsInv
  
  !****************************************************************************

!<subroutine>    
  subroutine griddef_normaliseFctsInvAux(rgriddefWork,rdiscretisation,&
                                         dValue1,dValue2,dOm)

!<description>
  !
  ! Auxiliary function: Here we perform the actual
  ! evaluation of the function on the elements.
  !
!</description>

!<inputoutput>
  ! structure containing all vector handles for the deformation algorithm
  type(t_griddefWork), intent(inout)  :: rgriddefWork

  type(t_blockDiscretisation), intent(inout)  :: rdiscretisation 
!</inputoutput>

!</subroutine>

!<output>
  ! Array receiving the calculated error.
  real(dp), intent(out) :: dValue1,dValue2,dOm
!</output>

!</subroutine>

  ! Pointer to the vector entries
  real(dp), dimension(:), pointer :: p_DdataMon,p_DdataArea

  ! Allocateable arrays for the values of the basis functions - 
  ! for test space.
  real(dp), dimension(:,:,:,:), allocatable, target :: DbasTest,DbasFunc
  
  ! Number of local degees of freedom for test functions
  integer :: indofTest,indofFunc
  
  type(t_vectorScalar), pointer :: rvectorArea,rvectorMon
  
  ! The FE solution vector. Represents a scalar FE function.
  type(t_vectorScalar), pointer :: rvectorScalar


  integer :: i,k,icurrentElementDistr, ICUBP, NVE
  integer :: IEL, IELmax, IELset, IdoFE
  real(dp) :: OM
  
  ! Array to tell the element which derivatives to calculate
  logical, dimension(el_maxnder) :: Bder
  
  ! Cubature point coordinates on the reference element
  real(dp), dimension(cub_maxcubp, ndim3d) :: Dxi

  ! For every cubature point on the reference element,
  ! the corresponding cubature weight
  real(dp), dimension(cub_maxcubp) :: Domega
  
  ! number of cubature points on the reference element
  integer :: ncubp
  
  ! The triangulation structure - to shorten some things...
  type(t_triangulation), pointer :: p_rtriangulation
  
  ! A pointer to an element-number list
  integer, dimension(:), pointer :: p_IelementList
  
  ! An array receiving the coordinates of cubature points on
  ! the reference element for all elements in a set.
  real(dp), dimension(:,:), allocatable :: p_DcubPtsRef

  ! Arrays for saving Jacobian determinants and matrices
  real(dp), dimension(:,:), pointer :: p_Ddetj
  
  ! Current element distribution
  type(t_elementDistribution), pointer :: p_relementDistribution
  
  ! Number of elements in the current element distribution
  integer :: NEL

  ! Pointer to the values of the function that are computed by the callback routine.
  real(dp), dimension(:,:,:), allocatable :: Dcoefficients
  
  ! Number of elements in a block. Normally =BILF_NELEMSIM,
  ! except if there are less elements in the discretisation.
  integer :: nelementsPerBlock
  
  ! A t_domainIntSubset structure that is used for storing information
  ! and passing it to callback routines.
  type(t_evalElementSet) :: rintSubset
  
  ! An allocateable array accepting the doF`s of a set of elements.
  integer, dimension(:,:), allocatable, target :: IdofsTest,IdofFunc

  ! Type of transformation from the reference to the real element 
  integer :: ctrafoType
  
  ! Element evaluation tag; collects some information necessary for evaluating
  ! the elements.
  integer :: cevaluationTag
  
  real(dp) :: daux1,daux2

    ! Which derivatives of basis functions are needed?
    ! Check the descriptors of the bilinear form and set BDER
    ! according to these.

    ! we do not want to write this name every time  
    rvectorArea => rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1)
    rvectorMon  => rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1)
    rvectorScalar => rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1)      

    call lsyssc_getbase_double (rvectorMon,p_DdataMon)
    call lsyssc_getbase_double (rvectorArea,p_DdataArea)
  !-------------------------------------------------------------  


    Bder = .FALSE.
    Bder(DER_FUNC) = .TRUE.
    
    ! Get a pointer to the triangulation - for easier access.
    p_rtriangulation => rdiscretisation%p_rtriangulation
    
    ! For saving some memory in smaller discretisations, we calculate
    ! the number of elements per block. For smaller triangulations,
    ! this is NEL. If there are too many elements, it is at most
    ! BILF_NELEMSIM. This is only used for allocating some arrays.
    nelementsPerBlock = MIN(PPERR_NELEMSIM,p_rtriangulation%NEL)
    
    dValue1 = 0.0_DP
    dValue2 = 0.0_DP
    dOm     = 0.0_DP

    ! Now loop over the different element distributions (=combinations
    ! of trial and test functions) in the discretisation.

    do icurrentElementDistr = 1,rdiscretisation%RspatialDiscr(1)%inumFESpaces
    
      ! Activate the current element distribution
      p_relementDistribution => rdiscretisation%RspatialDiscr(1)%RelementDistr(icurrentElementDistr)
    
      ! Cancel if this element distribution is empty.
      if (p_relementDistribution%NEL .EQ. 0) cycle

      ! Get the number of local doF`s for trial functions
      indofTest = elem_igetNDofLoc(p_relementDistribution%celement)
      
      ! Get the number of corner vertices of the element
      NVE = elem_igetNVE(p_relementDistribution%celement)
      
      ! Initialise the cubature formula,
      ! Get cubature weights and point coordinates on the reference element
      call cub_getCubPoints(p_relementDistribution%ccubTypeEval, ncubp, Dxi, Domega)
      
      ! Get from the trial element space the type of coordinate system
      ! that is used there:
      ctrafoType = elem_igetTrafoType(p_relementDistribution%celement)

      ! Allocate some memory to hold the cubature points on the reference element
      allocate(p_DcubPtsRef(trafo_igetReferenceDimension(ctrafoType),CUB_MAXCUBP))

      ! Reformat the cubature points; they are in the wrong shape!
      do i=1,ncubp
        do k=1,UBOUND(p_DcubPtsRef,1)
          p_DcubPtsRef(k,i) = Dxi(i,k)
        end do
      end do
      
      ! Allocate arrays for the values of the test functions.
      allocate(DbasTest(indofTest,elem_getMaxDerivative(p_relementDistribution%celement),&
               ncubp,nelementsPerBlock))
      
      ! Allocate memory for the doF`s of all the elements.
      allocate(IdofsTest(indofTest,nelementsPerBlock))

      ! Initialisation of the element set.
      call elprep_init(rintSubset)

      ! Get the element evaluation tag of all FE spaces. We need it to evaluate
      ! the elements later. All of them can be combined with OR, what will give
      ! a combined evaluation tag. 
      cevaluationTag = elem_getEvaluationTag(p_relementDistribution%celement)
               
                      
      ! Make sure that we have determinants.
      cevaluationTag = IOR(cevaluationTag,EL_EVLTAG_DETJ)

      ! p_IelementList must point to our set of elements in the discretisation
      ! with that combination of trial functions
      call storage_getbase_int (p_relementDistribution%h_IelementList, &
                                p_IelementList)
                     
      ! Get the number of elements there.
      NEL = p_relementDistribution%NEL
    
      ! Loop over the elements - blockwise.
      do IELset = 1, NEL, PPERR_NELEMSIM
      
        ! We always handle LINF_NELEMSIM elements simultaneously.
        ! How many elements have we actually here?
        ! Get the maximum element number, such that we handle at most LINF_NELEMSIM
        ! elements simultaneously.
        
        IELmax = MIN(NEL,IELset-1+PPERR_NELEMSIM)
      
        ! Calculate the global doF`s into IdofsTrial.
        !
        ! More exactly, we call dof_locGlobMapping_mult to calculate all the
        ! global doF`s of our LINF_NELEMSIM elements simultaneously.
        call dof_locGlobMapping_mult(rdiscretisation%RspatialDiscr(1),&
                                     p_IelementList(IELset:IELmax),IdofsTest)
                                     
        ! Calculate all information that is necessary to evaluate the finite element
        ! on all cells of our subset. This includes the coordinates of the points
        ! on the cells.
        call elprep_prepareSetForEvaluation (rintSubset,&
            cevaluationTag, p_rtriangulation, p_IelementList(IELset:IELmax), &
            ctrafoType, p_DcubPtsRef(:,1:ncubp))
            
        p_Ddetj => rintSubset%p_Ddetj

        ! In the next loop, we do not have to evaluate the coordinates
        ! on the reference elements anymore.
        cevaluationTag = IAND(cevaluationTag,NOT(EL_EVLTAG_REFPOINTS))

        ! Calculate the values of the basis functions.
        call elem_generic_sim2 (p_relementDistribution%celement, &
            rintSubset, Bder, DbasTest)
        
        do IEL=1,IELmax-IELset+1
        
          ! Loop over all cubature points on the current element
          do icubp = 1, ncubp
          
            ! calculate the current weighting factor in the cubature formula
            ! in that cubature point.

            OM = Domega(ICUBP)*p_Ddetj(ICUBP,IEL)
            
            daux1 = 0.0_DP
            daux2 = 0.0_DP
            
            do IdoFE = 1,indofTest
              daux1 = daux1 + p_DdataArea(IdofsTest(IdoFE,IEL))* &
              DbasTest(IdoFE,DER_FUNC,ICUBP,IEL)
              daux2 = daux2 + p_DdataMon(IdofsTest(IdoFE,IEL))* &
              DbasTest(IdoFE,DER_FUNC,ICUBP,IEL)
              dOm = dOm + OM * DbasTest(IdoFE,DER_FUNC,ICUBP,IEL)           
            end do
            
            dValue1 = dValue1 + OM/daux1
            dValue2 = dValue2 + OM/daux2

          end do ! ICUBP 

        end do ! IEL
    
      end do ! IELset
      
      ! Release memory
      call elprep_releaseElementSet(rintSubset)

      deallocate(p_DcubPtsRef)

    end do ! icurrentElementDistr

  end subroutine ! griddef_normaliseFctsInvAux
  
  !****************************************************************************

  
!<subroutine>     
  subroutine griddef_blendmonitor(rgriddefInfo, rgriddefWork,dBlendPar)
  
  !<description>
    ! This subroutine performs the blending between the monitor function and the area
    ! distribution function during the grid deformation process. The blending performed
    ! is a linear combination of these two functions:
    ! <tex>$ f_{mon}  \rightarrow t * f_{mon} + (1-t)*darea$</tex>.
    ! If the deformation is too harsh, the resulting grid can become invalid due to
    ! numerical errors. In this case, one performs several deformations with the blended
    ! monitor function, such that every single step results in relatively mild deformation.
  !</description>

  !<inputoutput>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo),intent(inout) :: rgriddefInfo

    ! structure containing all vector handles for the deformation algorithm
    type(t_griddefWork),intent(inout) :: rgriddefWork
    
  !</inputoutput>
    real(DP),intent(inout)  :: dBlendPar
!</subroutine>

    ! local variables
    ! a shorthand to the functions
    integer :: i
    type(t_vectorScalar) , pointer :: p_Df1
    type(t_vectorScalar) , pointer :: p_Df2
    real(DP), dimension(:), pointer :: p_Data1
    real(DP), dimension(:), pointer :: p_Data2  
   ! blending parameter
        
    ! we do not want to write this name 
    p_Df1 => rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1)
    ! we do not want to write this name 
    p_Df2 => rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1)  

    ! if the blending parameter is 1, nothing has to be done
    if (dblendPar .eq. 1.0_DP) then
      return
    endif

    ! ensure that the blending parameter is between 0 and 1
    if (dblendPar .gt. 1.0_DP) dblendPar = 1.0_DP
    if (dblendPar .lt. 0.0_DP) dblendPar = 0.0_DP

    ! get the function data
    call lsyssc_getbase_double(p_Df1,p_Data1)
    call lsyssc_getbase_double(p_Df2,p_Data2)

    ! scale the functions
    ! p_Data1(:) =  p_Data1(:) *  (dblendPar - 1.0_dp)
    do i=1,ubound(p_Data2,1)    
      p_Data2(i) = dblendPar * p_Data2(i) + (1.0_dp - dblendPar) * p_Data1(i)
    end do
    
  end subroutine  ! end griddef_blendmonitor

  ! *************************************************************************** 

!<subroutine>   
  subroutine griddef_createMatrixDef(rgriddefWork,rdiscretisation)
!<description>
  !
  ! Here we create the matrix for the deformation problem 
  ! 
!</description>

!<inputoutput>
  ! structure containing all vector handles for the deformation algorithm
  type(t_griddefWork), intent(inout)  :: rgriddefWork

  type(t_blockDiscretisation), intent(inout)  :: rdiscretisation 
!</inputoutput>

!</subroutine>

  ! We create a scalar matrix, based on the discretisation structure
  ! for our one and only solution component.
  call bilf_createMatrixStructure (rdiscretisation%RspatialDiscr(1),&
                                   LSYSSC_MATRIX9,rgriddefWork%rmatrix)    

  call stdop_assembleLaplaceMatrix(rgriddefWork%rmatrix,.TRUE.,1.0_dp)

  ! The linear solver only works for block matrices/vectors - so make the
  ! the matrix for the deformation problem a block matrix
  call lsysbl_createMatFromScalar (rgriddefWork%rmatrix,rgriddefWork%rmatDeform, &
                                   rdiscretisation)
     
  call lsysbl_createVecBlockIndMat(rgriddefWork%rmatDeform,rgriddefWork%rrhsBlock,.TRUE.)     
  
  ! Now we have block vectors for the RHS and the matrix. What we
  ! need additionally is a block vector for the solution and
  ! temporary data. Create them using the RHS as template.
  ! Fill the solution vector with 0:
  call lsysbl_createVecBlockIndirect (rgriddefWork%rrhsBlock, rgriddefWork%rSolBlock, .TRUE.)
  call lsysbl_createVecBlockIndirect (rgriddefWork%rrhsBlock, rgriddefWork%rtempBlock, .TRUE.)

  end subroutine  

  !****************************************************************************

!<subroutine>
  subroutine griddef_createRHS (rgriddefWork,rdiscretisation)
!<description>
  ! This routine calculates the entries of a discretised finite element vector.
  ! The discretisation is assumed to be conformal, i.e. the doF`s
  ! of all finite elements must 'match'. 
  ! The linear form is defined by
  !        (f,$phi_i$), i=1..*
  ! with $Phi_i$ being the test functions defined in the discretisation
  ! structure.
  ! In case the array for the vector entries does not exist, the routine
  ! allocates memory in size of the matrix of the heap for the matrix entries
  ! and initialises all necessary variables of the vector according to the
  ! parameters (NEQ, pointer to the discretisation,...)
  !
  ! Double-precision version.
!</description>

!<input>
!</input>

!<inputoutput>
  ! structure containing all vector handles for the deformation algorithm
  type(t_griddefWork), intent(inout)  :: rgriddefWork

  type(t_blockDiscretisation), intent(inout)  :: rdiscretisation 
!</inputoutput>

!</subroutine>

  ! local variables
  integer :: i,k,icurrentElementDistr, ICUBP
  integer :: IEL, IELmax, IELset, IdoFE
  real(dp) :: OM
  
  ! Array to tell the element which derivatives to calculate
  logical, dimension(el_maxnder) :: Bder
  
  ! Cubature point coordinates on the reference element
  real(dp), dimension(cub_maxcubp, ndim3d) :: Dxi

  ! For every cubature point on the reference element,
  ! the corresponding cubature weight
  real(dp), dimension(cub_maxcubp) :: Domega
  
  ! number of cubature points on the reference element
  integer :: ncubp
  
  ! Pointer to the vector entries
  real(dp), dimension(:), pointer :: p_DdataMon,p_DdataArea

  ! An allocateable array accepting the doF`s of a set of elements.
  integer, dimension(:,:), allocatable, target :: IdofsTest
  integer, dimension(:,:), allocatable, target :: IdofsFunc
  
  ! Allocateable arrays for the values of the basis functions - 
  ! for test space.
  real(dp), dimension(:,:,:,:), allocatable, target :: DbasTest,DbasFunc
  
  ! Number of entries in the vector - for quicker access
  integer :: NEQ
  
  ! Type of transformation from the reference to the real element 
  integer :: ctrafoType
  
  ! Element evaluation tag; collects some information necessary for evaluating
  ! the elements.
  integer :: cevaluationTag

  ! Number of local degees of freedom for test functions
  integer :: indofTest,indofFunc
  
  ! The triangulation structure - to shorten some things...
  type(t_triangulation), pointer :: p_rtriangulation
  
  ! A pointer to an element-number list
  integer, dimension(:), pointer :: p_IelementList
  
  ! A small vector holding only the additive controbutions of
  ! one element
  real(dp), dimension(el_maxnbas) :: DlocalData
  
  ! An array that takes coordinates of the cubature formula on the reference element
  real(dp), dimension(:,:), allocatable :: p_DcubPtsRef

  ! Pointer to the jacobian determinants
  real(dp), dimension(:,:), pointer :: p_Ddetj
  
  ! Entries of the right hand side
  real(dp), dimension(:), pointer :: p_Ddata
  
  ! Current element distribution
  type(t_elementDistribution), pointer :: p_elementDistribution
  type(t_elementDistribution), pointer :: p_elementDistributionFunc
  
  ! Number of elements in the current element distribution
  integer :: NEL

  ! Number of elements in a block. Normally =BILF_NELEMSIM,
  ! except if there are less elements in the discretisation.
  integer :: nelementsPerBlock
  
  ! Pointer to the coefficients that are computed by the callback routine.
  real(dp) :: dcoeff,dmonVal,dareaVal
  
  ! A t_domainIntSubset structure that is used for storing information
  ! and passing it to callback routines.
  type(t_evalElementSet) :: revalSubset
  logical :: bcubPtsInitialised
  type(t_vectorScalar), pointer :: rvectorArea,rvectorMon,rvectorRhs
  ! Create a t_discreteBC structure where we store all discretised boundary
  ! conditions.
  
  ! we do not want to write this name every time  
  rvectorArea => rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1)
  rvectorMon  => rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1)      
  
  ! Which derivatives of basis functions are needed?
  ! Check the descriptors of the bilinear form and set BDER
  ! according to these.
  Bder(:) = .FALSE.
  Bder(DER_FUNC) = .true.
  
  ! Get information about the vector:
  NEQ = rvectorMon%NEQ

  rvectorRhs  => rgriddefWork%rrhsBlock%RvectorBlock(1)
  call lsyssc_getbase_double(rvectorRhs,p_Ddata)
  call lsyssc_getbase_double(rvectorMon,p_DdataMon)
  call lsyssc_getbase_double(rvectorArea,p_DdataArea)
  

  
  ! Get a pointer to the triangulation - for easier access.
  p_rtriangulation => rdiscretisation%p_rtriangulation
  
  ! For saving some memory in smaller discretisations, we calculate
  ! the number of elements per block. For smaller triangulations,
  ! this is NEL. If there are too many elements, it is at most
  ! LINF_NELEMSIM. This is only used for allocating some arrays.
  nelementsPerBlock = min(LINF_NELEMSIM,p_rtriangulation%NEL)
  
  ! Now loop over the different element distributions (=combinations
  ! of trial and test functions) in the discretisation.
  !call ZTIME(DT(2))

  do icurrentElementDistr = 1,rdiscretisation%RspatialDiscr(1)%inumFESpaces
  
    ! Activate the current element distribution
    p_elementDistribution => &
        rvectorRhs%p_rspatialDiscr%RelementDistr(icurrentElementDistr)
    p_elementDistributionFunc => &
        rvectorMon%p_rspatialDiscr%RelementDistr(icurrentElementDistr)
  
    ! Cancel if this element distribution is empty.
    if (p_elementDistribution%NEL .EQ. 0) cycle

    ! Get the number of local doF`s for trial and test functions
    indofTest = elem_igetNDofLoc(p_elementDistribution%celement)
    indofFunc = elem_igetNDofLoc(p_elementDistributionFunc%celement)
    
    ! Get from the trial element space the type of coordinate system
    ! that is used there:
    ctrafoType = elem_igetTrafoType(p_elementDistribution%celement)

    ! Allocate some memory to hold the cubature points on the reference element
    allocate(p_DcubPtsRef(trafo_igetReferenceDimension(ctrafoType),CUB_MAXCUBP))
    
    ! Initialise the cubature formula,
    ! Get cubature weights and point coordinates on the reference element
    call cub_getCubPoints(p_elementDistribution%ccubTypeBilForm, ncubp, Dxi, Domega)
    
    ! Reformat the cubature points; they are in the wrong shape!
    do i=1,ncubp
      do k=1,ubound(p_DcubPtsRef,1)
        p_DcubPtsRef(k,i) = Dxi(i,k)
      end do
    end do
    
    ! Allocate arrays for the values of the test- and trial functions.
    ! This is done here in the size we need it. Allocating it in-advance
    ! with something like
    !  ALLOCATE(DbasTest(EL_MAXNBAS,EL_MAXNDER,ncubp,nelementsPerBlock))
    !  ALLOCATE(DbasTrial(EL_MAXNBAS,EL_MAXNDER,ncubp,nelementsPerBlock))
    ! would lead to nonused memory blocks in these arrays during the assembly, 
    ! which reduces the speed by 50%!
    allocate(DbasTest(indofTest,elem_getMaxDerivative(p_elementDistribution%celement),&
             ncubp,nelementsPerBlock))
    allocate(DbasFunc(indofTest,elem_getMaxDerivative(p_elementDistributionFunc%celement),&
             ncubp,nelementsPerBlock))

    ! Allocate memory for the doF`s of all the elements.
    allocate(IdofsTest(indofTest,nelementsPerBlock))
    allocate(IdofsFunc(indofFunc,nelementsPerBlock))

    ! Initialisation of the element set.
    call elprep_init(revalSubset)

    ! Indicate that cubature points must still be initialised in the element set.
    bcubPtsInitialised = .false.
    
    !call ZTIME(DT(3))
    ! p_IelementList must point to our set of elements in the discretisation
    ! with that combination of trial/test functions
    call storage_getbase_int (p_elementDistribution%h_IelementList, &
                              p_IelementList)
                              
    ! Get the number of elements there.
    NEL = p_elementDistribution%NEL
  
    ! Loop over the elements - blockwise.
    do IELset = 1, NEL, LINF_NELEMSIM
    
      ! We always handle LINF_NELEMSIM elements simultaneously.
      ! How many elements have we actually here?
      ! Get the maximum element number, such that we handle at most LINF_NELEMSIM
      ! elements simultaneously.
      
      IELmax = MIN(NEL,IELset-1+LINF_NELEMSIM)
    
      ! Calculate the global doF`s into IdofsTest.
      !
      ! More exactly, we call dof_locGlobMapping_mult to calculate all the
      ! global doF`s of our LINF_NELEMSIM elements simultaneously.
      call dof_locGlobMapping_mult(rdiscretisation%RspatialDiscr(1), p_IelementList(IELset:IELmax), &
                                   IdofsTest)
      call dof_locGlobMapping_mult(rdiscretisation%RspatialDiscr(1), p_IelementList(IELset:IELmax), &
                                   IdofsFunc)
                                   
      !call ZTIME(DT(4))
      
      ! -------------------- ELEMENT EVALUATION PHASE ----------------------
      
      ! Ok, we found the positions of the local matrix entries
      ! that we have to change.
      ! To calculate the matrix contributions, we have to evaluate
      ! the elements to give us the values of the basis functions
      ! in all the doF`s in all the elements in our set.

      ! Get the element evaluation tag of all FE spaces. We need it to evaluate
      ! the elements later. All of them can be combined with OR, what will give
      ! a combined evaluation tag. 
      cevaluationTag = elem_getEvaluationTag(p_elementDistribution%celement)
      cevaluationTag = IOR(elem_getEvaluationTag(p_elementDistributionFunc%celement),&
      cevaluationTag)
                      
      ! In the first loop, calculate the coordinates on the reference element.
      ! In all later loops, use the precalculated information.
      !
      ! Note: Why not using
      !   if (IELset .EQ. 1) then
      ! here, but this strange concept with the boolean variable?
      ! Because the if-command does not work with OpenMP! bcubPtsInitialised
      ! is a local variable and will therefore ensure that every thread
      ! is initialising its local set of cubature points!
      if (.NOT. bcubPtsInitialised) then
        bcubPtsInitialised = .true.
        cevaluationTag = IOR(cevaluationTag,EL_EVLTAG_REFPOINTS)
      else
        cevaluationTag = IAND(cevaluationTag,NOT(EL_EVLTAG_REFPOINTS))
      end if

      ! Calculate all information that is necessary to evaluate the finite element
      ! on all cells of our subset. This includes the coordinates of the points
      ! on the cells.
      call elprep_prepareSetForEvaluation (revalSubset,&
          cevaluationTag, p_rtriangulation, p_IelementList(IELset:IELmax), &
          ctrafoType, p_DcubPtsRef(:,1:ncubp))
          
      p_Ddetj => revalSubset%p_Ddetj
      
      ! Calculate the values of the basis functions.
      call elem_generic_sim2 (p_elementDistribution%celement, &
          revalSubset, Bder, DbasTest)
      call elem_generic_sim2 (p_elementDistributionFunc%celement, &
          revalSubset, Bder, DbasFunc)

      ! --------------------- doF COMBINATION PHASE ------------------------
      
      ! Values of all basis functions calculated. Now we can start 
      ! to integrate!
      !
      ! Loop through elements in the set and for each element,
      ! loop through the doF`s and cubature points to calculate the
      ! integral:
      
      do IEL=1,IELmax-IELset+1
        
        ! Loop over all cubature points on the current element
        do ICUBP = 1, ncubp
        
          ! calculate the current weighting factor in the cubature formula
          ! in that cubature point.
          !
          ! Take the absolut value of the determinant of the mapping.
          ! In 2D, the determinant is always positive, whereas in 3D,
          ! the determinant might be negative -- that is normal!

          OM = Domega(ICUBP)*ABS(p_Ddetj(ICUBP,IEL))
          
          ! Calculate 1/f-1/g in our cubature point
          dcoeff = 0.0_DP
          dmonVal  = 0.0_dp
          dareaVal = 0.0_dp
          do IdoFE=1,indofFunc
            dmonVal = dmonVal+DbasFunc(IdoFE,DER_FUNC,ICUBP,IEL)*p_DdataMon(IdofsFunc(IdoFE,IEL))
            dareaVal = dareaVal+DbasFunc(IdoFE,DER_FUNC,ICUBP,IEL)*p_DdataArea(IdofsFunc(IdoFE,IEL))
          end do ! IdoFE
          
          dmonVal = 1.0_dp/dmonVal - 1.0_dp/dareaVal
          ! Now loop through all possible combinations of doF`s
          ! in the current cubature point. Incorporate the data to the FEM vector

          do IdoFE=1,indofTest
            p_Ddata(IdofsTest(IdoFE,IEL)) = p_Ddata(IdofsTest(IdoFE,IEL)) + &
              DbasTest(IdoFE,DER_FUNC,ICUBP,IEL)*OM*dmonVal
          end do ! IdoFE
            
        end do ! ICUBP 

      end do ! IEL

    end do ! IELset
    
    ! Release memory
    deallocate(IdofsTest,IdofsFunc)
    deallocate(DbasTest,DbasFunc)

    call elprep_releaseElementSet(revalSubset)
    
    deallocate(p_DcubPtsRef)

  end do ! icurrentElementDistr
  
  end subroutine ! griddef_createRHS

  !****************************************************************************
 
!<subroutine>  
  subroutine griddef_moveMesh(rgriddefInfo, rgriddefWork)
!<description>
    ! This subroutine performs the actual deformation of the mesh. To do this, the grid 
    ! points are moved in a vector field represented by DphiX and DphiY, the monitor 
    ! function Dfmon and the area distribution Darea.
    ! The following ODE is solved:
    !<tex>
    ! \begin{displaymath}
    !   \frac{\partial \varphi(x,t)}{\partial t} = \eta(\varphi(x,t),t),
    !   \quad 0\leq t \leq  1, \quad
    !   \varphi(x,0) = x
    ! \end{displaymath}
    ! \begin{displaymath}
    !   \eta(y,s) := \frac{v(y)}{s\tilde{f}(y) + (1-s)\tilde{g}(y)}, \quad y \in \Omega,
    !   s \in [0,1].
    ! \end{displaymath}
    !</tex>
    ! To solve the ODE which describes the movement of the grid points, several ODE
    ! solvers are avialable. The type of solver is chosen by codeMethod. Currently, we
    ! support:
    !
    ! 1) explicit Euler (GRIDDEF_EXPL_EULER)
    !
    ! 6) RK4 (GRIDDEF_RK4)
    !

!</description>

!<input>
!</input>

!<inputoutput>
  ! structure containing all parameter settings for grid deformation
  type(t_griddefInfo), intent(inout)  :: rgriddefInfo

  ! structure containing all vector handles for the deformation algorithm
  type(t_griddefWork), intent(inout)  :: rgriddefWork
!</inputoutput>

!</subroutine>

  ! local variables
  real(dp), dimension(:,:), pointer :: p_DvertexCoordsReal
  real(dp), dimension(:,:), pointer :: p_DvertexCoords
  real(dp), dimension(:), pointer :: p_DvertexParametersReal
  real(dp), dimension(:), pointer :: p_DvertexParameters
  integer :: i,NLMAX
  
  NLMAX=rgriddefInfo%NLMAX
  
  
  call storage_getbase_double2d(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_dvertexCoords,&
  p_DvertexCoords)    

  call storage_getbase_double2d(rgriddefInfo%p_rtriangulation%h_dvertexCoords,&
  p_DvertexCoordsReal)   
  
  call storage_getbase_double(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_DvertexParameterValue,&
  p_DvertexParameters)
  
  call storage_getbase_double(rgriddefInfo%p_rtriangulation%h_DvertexParameterValue,&
  p_DvertexParametersReal)   
  
  call output_lbrk ()
  print *,"Starting Explicit Euler..."
  call output_line ('--------------------------------------------------------------------------------')
  call output_lbrk ()
  
  ! call the explicit euler to move the grid points
  call griddef_performEE(rgriddefInfo, rgriddefWork)
      
  ! write back coordinates
  do i=1,rgriddefInfo%p_rtriangulation%NVT
    p_DvertexCoordsReal(1,i) = p_DvertexCoords(1,i)
    p_DvertexCoordsReal(2,i) = p_DvertexCoords(2,i)
  end do

  ! write back coordinates
  do i=1,rgriddefInfo%p_rtriangulation%NVBD
    p_DvertexParametersReal(i) = p_DvertexParameters(i)
  end do
  
  end subroutine ! end griddef_moveMesh
  
  !****************************************************************************

!<subroutine>  
  subroutine griddef_performEE(rgriddefInfo, rgriddefWork)
!<description>
  !
  !
  !
!</description>

!<input>
!</input>

!<inputoutput>
  ! structure containing all parameter settings for grid deformation
  type(t_griddefInfo), intent(inout)  :: rgriddefInfo

  ! structure containing all vector handles for the deformation algorithm
  type(t_griddefWork), intent(inout)  :: rgriddefWork
!</inputoutput>

!</subroutine>

  ! local variables
  
  ! true, if the point is not inside the domain
  logical :: bsearchFailed

  ! coordinates of evaluation point
  real(dp) :: dx, dy, dx_old, dy_old

  ! time and step size for ODE solving
  real(dp) :: dtime, dstepSize,deps,dist

  ! level diference between PDE and PDE level
  integer:: ilevDiff

  ! number of ODE time steps
  integer::  ntimeSteps, ive, ielement,ivbd,nlmax

  real(dp), dimension(:,:), pointer :: p_DvertexCoords
  
  integer, dimension(:), pointer :: p_IelementsAtVertex  
  integer, dimension(:), pointer :: p_IelementsAtVertexIdx
  integer, dimension(:), pointer :: p_InodalProperty

  real(dp), dimension(4) :: Dvalues  
  real(dp), dimension(2) :: Dpoint

  deps = 0.0000000001_dp

  NLMAX=rgriddefInfo%NLMAX
  
  ! get the elements at vertex index array
  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IelementsAtVertexIdx,&
  p_IelementsAtVertexIdx)

  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_InodalProperty,&
  p_InodalProperty)
  
  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IelementsAtVertex,&
  p_IelementsAtVertex)
  
  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IelementsAtVertex,&
  p_IelementsAtVertex)
  
  call storage_getbase_double2d(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_dvertexCoords,&
  p_DvertexCoords)    

  ntimeSteps = rgriddefInfo%ntimeSteps
  ! difference between grid level for ODE and PDE solving
  ! write the coordinates of the moved points to the actual coordinate vector
  ! Here, only the case ilevelODE < ilevel is considered, the opposite case
  ! is treated by prolongating the vector field to ODE level.
  ilevDiff = rgriddefInfo%imindefLevel

  do ive=1, rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%NVT
  
      dx_old = p_DvertexCoords(1,ive)
      dy_old = p_DvertexCoords(2,ive)
      
      dx = p_DvertexCoords(1,ive)
      dy = p_DvertexCoords(2,ive)
      
    ! if we have a boundary node we treat it in a special routine
    if(p_InodalProperty(ive) .ne. 0)then
      call griddef_perform_boundary2(rgriddefInfo, rgriddefWork,ive)
    else
      ! inner node      
      ! initialise time variable
      dtime = 0.0_DP

      ! initialise flag for failed search
      bsearchFailed = .FALSE.
      ! initial coordinates of the vertex
      dx = p_DvertexCoords(1,ive)
      dy = p_DvertexCoords(2,ive)
      
      dx_old = p_DvertexCoords(1,ive)
      dy_old = p_DvertexCoords(2,ive)
      
      
      ! here we store the coordinates
      Dpoint(1) = dx
      Dpoint(2) = dy
      
      ! zero the Dvalues
      Dvalues(:) = 0.0_dp
      
      ! for the first element read the element index
      ielement = p_IelementsAtVertex(p_IelementsAtVertexIdx(ive))
      
      ! evaluate the functions on the element
      call griddef_evalPhi_Known(DER_FUNC, Dvalues, &
           rgriddefWork%rvecGradBlock%RvectorBlock(1), &
           rgriddefWork%rvecGradBlock%RvectorBlock(2), &
           rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1), &
           rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1), &
           Dpoint,ielement)

      ! compute step size for next time step
      dstepSize = 0.05_dp

      ! so this means in Dvalues(1) there is the
      ! x coordinate of the recovered gradient
      ! so this means in Dvalues(2) there is the
      ! y coordinate of the recovered gradient        
      !((1.0_DP - dtime)*Dvalues(4) + &
      !dtime*(Dvalues(3)))
      ! In Dvalues(4) we find the g function(area distribution)
      ! In Dvalues(3) the f function (monitor)
      ! perform the actual Euler step
      dx = dx + dstepSize* Dvalues(1)/((1.0_DP - dtime)*Dvalues(4) + &
           dtime*(Dvalues(3)))
      dy = dy + dstepSize* Dvalues(2)/((1.0_DP - dtime)*Dvalues(4) + &
           dtime*(Dvalues(3)))

      ! update time
      dtime = dtime + dstepSize

      ! While the current time is less than 1.0-eps
      if (dtime .le. 1.0_DP - deps) then

         ! for the other time steps, we have really to search
        calculationloopEE_inner : do
        
          ! zero the Dvalues
          Dvalues(:) = 0.0_dp
          
          ! here we store the coordinates
          Dpoint(1) = dx
          Dpoint(2) = dy      
          
          call griddef_evalphi_ray(DER_FUNC, Dvalues, &
             rgriddefWork%rvecGradBlock%RvectorBlock(1), &
             rgriddefWork%rvecGradBlock%RvectorBlock(2), &
             rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1), &
             rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1), &
             Dpoint,bsearchFailed,ielement)        

          ! if the point is outside the domain, stop moving it
          if (bsearchFailed) then
            bsearchFailed = .FALSE.
            exit calculationloopEE_inner
          endif

          ! compute step size for next time step
          ! griddef_computeStepSize(dtime, ntimeSteps)
          dstepSize = 0.05_dp 

          ! perform the actual Euler step
          dx = dx + dstepSize* Dvalues(1)/((1.0_DP - dtime)*Dvalues(4) + &
               dtime*(Dvalues(3)))
          dy = dy + dstepSize* Dvalues(2)/((1.0_DP - dtime)*Dvalues(4) + &
               dtime*(Dvalues(3)))

          ! advance in time
          dtime = dtime + dstepSize
          ivbd = 0
          
          ! if time interval greater 1.0_-eps, we are finished
          if (dtime .ge. 1.0_DP - deps) then
          
!                if(dx .gt. 1.0_dp)then
!                  print *,ive
!                end if
                p_DvertexCoords(1,ive) = dx
                p_DvertexCoords(2,ive) = dy
              exit calculationloopEE_inner
            end if ! (dtime .ge. 1.0_DP - deps)
        
        enddo calculationloopEE_inner
        
      ! in case time interval exhausted in the first time step  
      else
        ! write the coordinates
              if(dx .gt. 1.0_dp)then
                print *,ive
              end if
        p_DvertexCoords(1,ive) = dx
        p_DvertexCoords(2,ive) = dy     
      endif ! dtime
      
  end if ! nodal_property .ne. 0
  
  end do ! ive
  
  end subroutine ! end griddef_performEE
  
  !****************************************************************************  

!<subroutine>
subroutine griddef_perform_boundary2(rgriddefInfo,rgriddefWork,ive)
!<description>
  !
  !
  !
!</description>

!<input>
  ! Global vertex index
  integer:: ive
!</input>

!<inputoutput>
  ! structure containing all parameter settings for grid deformation
  type(t_griddefInfo), intent(inout)  :: rgriddefInfo

  ! structure containing all vector handles for the deformation algorithm
  TYPe(t_griddefWork), intent(inout)  :: rgriddefWork
!</inputoutput>

!</subroutine>

  ! local variables
  
  ! true, if the point is not inside the domain
  logical :: bsearchFailed

  ! coordinates of evaluation point
  real(DP) :: dx, dy, dparam1,dparam2,dparam,dalpha_01,dnx,dny,dtmp

  ! time and step size for ODE solving
  real(DP) :: dtime, dstepSize,deps,dalpha,dalpha_old,dalpha_start

  ! level diference between PDE and PDE level
  integer:: ilevDiff

  ! number of ODE time steps
  integer::  ntimeSteps,ielement,icp1,icp2,ivbd,ibd,iboundary

  real(dp), dimension(:,:), pointer :: p_DvertexCoords
  
  integer, dimension(:), pointer :: p_IelementsAtVertex  
  integer, dimension(:), pointer :: p_IelementsAtVertexIdx
  integer, dimension(:), pointer :: p_InodalProperty

  ! these arrays are needed when we treat boundary vertices      
  integer, dimension(:), pointer :: p_IboundaryCpIdx  
  integer, dimension(:), pointer :: p_IverticesAtBoundary
  real(dp), dimension(:), pointer :: p_DvertexParameterValue  
  real(dp), dimension(:), pointer :: p_DvertexParameterValueNew  
  
  integer, dimension(:,:), pointer :: p_IverticesAtEdge
  integer, dimension(:,:), pointer :: p_IelementsAtEdge
  integer, dimension(:), pointer ::   p_IedgesAtBoundary      
  
  integer, dimension(4) :: Ivalues  
  real(dp), dimension(4) :: Dvalues  
  real(dp), dimension(2) :: Dpoint
  
  ! make all the regions
  type(t_boundaryRegion), dimension(:),pointer :: p_rregion
  
  integer, dimension(:), allocatable :: rElements
  
  ! integer
  integer :: iregions,iedge,iupper,ivertex,icount,iinelement,iend,NLMAX

  deps = 0.0000000001_dp
  
  NLMAX=rgriddefInfo%NLMAX

  ! Get the boundary information we need
  call storage_getbase_double(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_DvertexParameterValue,&
  p_DvertexParameterValueNew)
  
  call storage_getbase_double(rgriddefInfo%p_rtriangulation%h_DvertexParameterValue,&
  p_DvertexParameterValue)
  

  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IboundaryCpIdx,&
  p_IboundaryCpIdx)
  
  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IverticesAtBoundary,&
  p_IverticesAtBoundary)  

  ! get the elements at vertex index array
  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IelementsAtVertexIdx,&
  p_IelementsAtVertexIdx)

  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_InodalProperty,&
  p_InodalProperty)
  
  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IelementsAtVertex,&
  p_IelementsAtVertex)
  
  call storage_getbase_int (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IelementsAtVertex,&
  p_IelementsAtVertex)
  
  call storage_getbase_double2d(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_dvertexCoords,&
  p_DvertexCoords)    
  
  call storage_getbase_int(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IedgesAtBoundary,&
  p_IedgesAtBoundary)    
  
  call storage_getbase_int2d(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IverticesAtEdge,&
  p_IverticesAtEdge)    
  
  call storage_getbase_int2d(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%h_IelementsAtEdge,&
  p_IelementsAtEdge)        
  
  Ivalues = (/1,2,3,4/)

  ! allocate the regions
  iupper = ubound(p_IedgesAtBoundary,1)
  ! ALLOCATE(p_DcubPtsRef(trafo_igetReferenceDimension(ctrafoType),CUB_MAXCUBP))
  allocate(p_rregion(boundary_igetNsegments &
  (rgriddefInfo%p_rboundary,p_InodalProperty(ive)))) 

  allocate(rElements(iupper))

  ntimeSteps = rgriddefInfo%ntimeSteps
  ! difference between grid level for ODE and PDE solving
  ! write the coordinates of the moved points to the actual coordinate vector
  ! Here, only the case ilevelODE < ilevel is considered, the opposite case
  ! is treated by prolongating the vector field to ODE level.
  ilevDiff = rgriddefInfo%imindefLevel

  do ivbd=1,4
    if(ive .eq. Ivalues(ivbd))then
    return
    end if
  end do

  iboundary = 0
  
  ! get parameter value
  ! get the index of ive in the p_IverticesAtBoundary array
  icp1 = p_IboundaryCpIdx(p_InodalProperty(ive))
  icp2 = p_IboundaryCpIdx(p_InodalProperty(ive)+1)-1
  do ibd=icp1,icp2
    iboundary = iboundary + 1
    if(p_IverticesAtBoundary(ibd).eq.ive)then
    exit
    end if        
  end do
  
  ! get the number of boundary segments in
  ! the boundary component 
  iend = boundary_igetNsegments(rgriddefInfo%p_rboundary,p_InodalProperty(ive))
  
  ! create the boundary regions
  do iregions=1,iend
  ! Idea: create the regions, check in which region the parameter is
    call boundary_createRegion(rgriddefInfo%p_rboundary, p_InodalProperty(ive),&
                             iregions,p_rregion(iregions))
  end do

  ! with this information we can assign the
  ! parameter value
  dalpha = p_DvertexParameterValue(iboundary)
  
  ! this will be the start alpha
  ! we also have a copy of the 01 parameterisation
  dalpha_start = dalpha
  
  ! convert this parameter in to length parameterisation
  dalpha = boundary_convertParameter(rgriddefInfo%p_rboundary, &
                                 p_InodalProperty(ive), dalpha,&
                                 BDR_PAR_01, BDR_PAR_LENGTH)

  ! we want to stay in this boundary region
  do iregions=1,iend
  ! Idea: create the regions, check in which region the parameter is
    if(boundary_isInRegion (p_rregion(iregions),p_InodalProperty(ive),dalpha_start))then
      exit
    end if
  end do   
      
  ! inner node      
  ! initialise time variable
  dtime = 0.0_DP

  ! initialise flag for failed search
  bsearchFailed = .true.

  ! initial coordinates of the vertex
  dx = p_DvertexCoords(1,ive)
  dy = p_DvertexCoords(2,ive)
  
  ! here we store the coordinates
  Dpoint(1) = dx
  Dpoint(2) = dy
  
  ! zero the Dvalues
  Dvalues(:) = 0.0_dp
  
  ! for the first element read the element index
  ielement = p_IelementsAtVertex(p_IelementsAtVertexIdx(ive))
  
  ! so this means in Dvalues(1) there is the
  ! x coordinate of the recovered gradient
  ! so this means in Dvalues(2) there is the
  ! y coordinate of the recovered gradient        
  !((1.0_DP - dtime)*Dvalues(4) + &
  !dtime*(Dvalues(3)))
  ! In Dvalues(4) we find the g function(area distribution)
  ! In Dvalues(3) the f function (monitor)
  ! evaluate the functions on the element
  call griddef_evalPhi_Known(DER_FUNC, Dvalues, &
       rgriddefWork%rvecGradBlock%RvectorBlock(1), &
       rgriddefWork%rvecGradBlock%RvectorBlock(2), &
       rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1), &
       rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1), &
       Dpoint,Ielement)

  ! compute step size for next time step
  dstepSize = 0.05_dp

  
  ! perform the actual Euler step
  ! get the normal vector
  call boundary_getNormalVec2D(rgriddefInfo%p_rboundary,p_InodalProperty(ive),&
                             dalpha,dnx, dny, BDR_NORMAL_MEAN, BDR_PAR_LENGTH)
  ! get the tangential vector
  dtmp = dnx
  dnx  = -dny
  dny  = dtmp
  ! project the recovered gradient(x,y) on (dnx,dny)
  dtmp = Dvalues(1) * dnx + Dvalues(2) * dny
                               
  ! project the speed vector on the tangential vector
  dalpha = dalpha + dstepSize * dtmp/((1.0_DP - dtime)*Dvalues(4) + &
       dtime*(Dvalues(3)))

  ! update time
  dtime = dtime + dstepSize

  ! While we are still in the [0,1] interval(with a small tolerance)
  if (dtime .le. 1.0_DP - deps) then

    !--------------------IHATETHIStypeOFLOOP----------------------
     ! for the other time steps, we have really to search
    calculationloopEE_bdy : do
    
    ! the alpha at the beginning of the loop in lngthParam
    dalpha_old = dalpha
    
    ! zero the Dvalues
    Dvalues(:) = 0.0_dp
    
    bsearchFailed = .true.
    icount = 0

    ! we need a 01 parameterisation for this search
    dalpha_01 = boundary_convertParameter(rgriddefInfo%p_rboundary, &
                                     p_InodalProperty(ive), dalpha,&
                                     BDR_PAR_LENGTH,BDR_PAR_01)
    
    ! loop over the edges
    do iedge=1,iupper
      ivertex = p_IedgesAtBoundary(iedge)
      ivertex = p_IverticesAtEdge(1,ivertex)
      ivbd = 0
      ! get parameter value
      icp1 = p_IboundaryCpIdx(p_InodalProperty(ivertex))
      icp2 = p_IboundaryCpIdx(p_InodalProperty(ivertex)+1)-1
      do ibd=icp1,icp2
        ivbd = ivbd + 1
        if(p_IverticesAtBoundary(ibd).eq.ivertex)then
        exit
        end if        
      end do      
      dparam = p_DvertexParameterValue(ivbd)
      
      if(.not.(boundary_isInRegion(p_rregion(iregions),p_InodalProperty(ive),dparam)))then
        !add the element add the edge
        cycle        
      end if
      
      ! Get the second vertex at this edge
      ivertex = p_IedgesAtBoundary(iedge)
      ivertex = p_IverticesAtEdge(2,ivertex)

      ivbd = 0
      ! get parameter value
      icp1 = p_IboundaryCpIdx(p_InodalProperty(ivertex))
      icp2 = p_IboundaryCpIdx(p_InodalProperty(ivertex)+1)-1
      do ibd=icp1,icp2
        ivbd = ivbd + 1
        if(p_IverticesAtBoundary(ibd).eq.ivertex)then
        exit
        end if        
      end do      
      dparam2 = p_DvertexParameterValue(ivbd)
      
      if(dparam2 .gt. dparam)then
        dparam1 = dparam
      else
        dparam1 = dparam2
        dparam2 = dparam
      end if
      
      ! 
      ! Find the boundary edge that corresponds to
      ! the current parameter
      if((dalpha_01 .ge. dparam1) .and. (dalpha_01 .le. dparam2))then
        iinelement = p_IelementsAtEdge(1,p_IedgesAtBoundary(iedge))
        bsearchFailed = .false.
        
        exit
      end if

    end do ! end do (for all boundary edges)

 !----------------------------------We either found the edge or not---------------------------------------   

    ! time interval exhausted, calculation finished and exit
    if (bsearchFailed) then
    
      ! convert and write
      dalpha_old = boundary_convertParameter(rgriddefInfo%p_rboundary, &
                                     p_InodalProperty(ive), dalpha_old,&
                                     BDR_PAR_LENGTH,BDR_PAR_01)
      
      ! get the x,y coordinates for the current parameter value      
      call boundary_getCoords(rgriddefInfo%p_rboundary, p_InodalProperty(ive),&
                              dalpha_old, dx, dy)        
    
      ! write
      p_DvertexCoords(1,ive) = dx
      p_DvertexCoords(2,ive) = dy     
      exit calculationloopEE_bdy
    end if ! (dtime .ge. 1.0_DP - deps)

    ! evaluate phi now in element iinelement    
    ! convert the parameter value and evaluate
    dalpha_01 = boundary_convertParameter(rgriddefInfo%p_rboundary, &
                                     p_InodalProperty(ive), dalpha,&
                                     BDR_PAR_LENGTH,BDR_PAR_01)

    ! evaluate the parameter value and get the coordinates    
    call boundary_getCoords(rgriddefInfo%p_rboundary, p_InodalProperty(ive),&
                            dalpha_01, dx, dy)

    
    ! get the x,y coordinates from the parameter value
    Dpoint(1) = dx
    Dpoint(2) = dy      
   
    ! search in which element the point is
    ! iel ivbd param value  
    call griddef_evalphi_ray_bound(DER_FUNC, Dvalues, &
       rgriddefWork%rvecGradBlock%RvectorBlock(1), &
       rgriddefWork%rvecGradBlock%RvectorBlock(2), &
       rgriddefWork%rvectorMonFuncQ1%RvectorBlock(1), &
       rgriddefWork%rvectorAreaBlockQ1%RvectorBlock(1), &
       Dpoint,iinelement)        


    ! compute step size for next time step
    dstepSize = 0.05_dp !griddef_computeStepSize(dtime, ntimeSteps)
    
    ! Get the normal vector on the boundary for the current parameter
    ! value.
    call boundary_getNormalVec2D(rgriddefInfo%p_rboundary,p_InodalProperty(ive),&
                               dalpha_01,dnx, dny, BDR_NORMAL_MEAN, BDR_PAR_01)
                               
    ! get the tangential vector
    dtmp = dnx
    dnx  = -dny
    dny  = dtmp
    ! project the recovered gradient(x,y) on (dnx,dny)
    dtmp = Dvalues(1) * dnx + Dvalues(2) * dny    

    ! perform the actual Euler step
    dalpha = dalpha + dstepSize* dtmp/((1.0_DP - dtime)*Dvalues(4) + &
       dtime*(Dvalues(3)))

    ! advance in time
    dtime = dtime + dstepSize
    ivbd = 0
    
    ! update the 01 param value
    dalpha_01 = boundary_convertParameter(rgriddefInfo%p_rboundary, &
                                     p_InodalProperty(ive), dalpha,&
                                     BDR_PAR_LENGTH,BDR_PAR_01)
    
    ! if the point is outside the domain, stop moving it
    if ((dalpha_01 .lt. p_rregion(iregions)%dminParam) .or. & 
        (dalpha_01 .gt. p_rregion(iregions)%dmaxParam)) then
        
        ! convert and write
        dalpha_old = boundary_convertParameter(rgriddefInfo%p_rboundary, &
                                       p_InodalProperty(ive), dalpha_old,&
                                       BDR_PAR_LENGTH,BDR_PAR_01)
         
        ! get the x,y coordinates of the current parameter value
        call boundary_getCoords(rgriddefInfo%p_rboundary, p_InodalProperty(ive),&
                                dalpha_old, dx, dy)
        
!        ! write back the parameter value of the vertex
        p_DvertexParameterValueNew(iboundary) = dalpha_old 
                                
        ! write the coordindates                                
        p_DvertexCoords(1,ive) = dx
        p_DvertexCoords(2,ive) = dy     
      exit calculationloopEE_bdy
    endif
    
    ! time interval exhausted, calculation finished and exit
    if (dtime .ge. 1.0_DP - deps) then

      ! convert from length parameterisation to 01
      dalpha = boundary_convertParameter(rgriddefInfo%p_rboundary, &
                                     p_InodalProperty(ive), dalpha,&
                                     BDR_PAR_LENGTH,BDR_PAR_01)
    
      ! get the x,y coordinates of the current parameter value
      call boundary_getCoords(rgriddefInfo%p_rboundary, p_InodalProperty(ive),&
                              dalpha, dx, dy)
      
      p_DvertexParameterValueNew(iboundary) = dalpha                              
      ! write the coordindates                                
      p_DvertexCoords(1,ive) = dx
      p_DvertexCoords(2,ive) = dy     
      exit calculationloopEE_bdy
    end if ! (dtime .ge. 1.0_DP - deps)
    
    enddo calculationloopEE_bdy
  ! in case time interval exhausted in the first time step  
  else
    ! write the coordinates
    p_DvertexCoords(1,ive) = dx
    p_DvertexCoords(2,ive) = dy     
  endif ! dtime

  deallocate(p_rregion)

  end subroutine
 
 !****************************************************************************  

!<subroutine>  
  subroutine griddef_evalPhi_Known(iderType, Dvalues, rvecGradX, &
             rvecGradY,rvecMon,rvecArea,Dpoint, &
             Ielements, IelementsHint, cnonmeshPoints)
!<description>
  ! This is the most general (and completely slowest) finite element evaluation
  ! routine. It allows to evaluate a general (scalar) FE function specified
  ! by rvecMon in a set of points Dpoints. The values of the
  ! FE function are written into Dvalues.
!</description>

!<input>
  ! type of function value to evaluate. One of the DER_xxxx constants
  integer, intent(in)           :: idertype
  
  ! the scalar solution vector that is to be evaluated.
  type(t_vectorScalar), intent(in)              :: rvecMon
  
  type(t_vectorScalar), intent(in)              :: rvecGradX
  
  type(t_vectorScalar), intent(in)              :: rvecGradY  
  
  type(t_vectorScalar), intent(in)              :: rvecArea    
  
  ! a list of points where to evaluate
  ! dimension(1..ndim,1..npoints)
  real(dp), dimension(:), intent(in) :: Dpoint
  
  ! optional: a list of elements containing the points Dpoints.
  ! if this is not specified the elment numbers containing the points 
  ! are determined automatically
  integer, intent(in), optional :: Ielements

  ! OPTIONAL: A list of elements that are near the points in Dpoints.
  ! This gives only a hint where to start searching for the actual elements
  ! containing the points. This is ignored if Ielements is specified!
  integer, intent(in), optional :: IelementsHint
  
  ! OPTIONAL: A FEVL_NONMESHPTS_xxxx constant that defines what happens
  ! if a point is located outside of the domain. May happen e.g. in
  ! nonconvex domains. FEVL_NONMESHPTS_NONE is the default 
  ! parameter if cnonmeshPoints is not specified. 
  integer, intent(in), optional :: cnonmeshPoints  
  
!</input>


!<output>
  ! Values of the FE function at the points specified by Dpoints.
  real(dp), dimension(:), intent(out) :: Dvalues
  

  
!</output>      

  ! local variables
  integer :: cnonmesh
  integer :: ieltype,indof,nve,ibas
  integer :: iel
  integer, dimension(:), pointer :: p_IelementDistr
  logical, dimension(el_maxnder) :: Bder
  
  real(dp), dimension(:), pointer :: p_ddatamon
  real(dp), dimension(:), pointer :: p_ddataarea
  real(dp), dimension(:), pointer :: p_ddatagradx
  real(dp), dimension(:), pointer :: p_ddatagrady
  
  ! Transformation
  integer :: ctrafotype
  real(dp), dimension(trafo_maxdimrefcoord) :: dparpoint 
  
  ! Values of basis functions and doF`s
  real(DP), dimension(el_maxnbas,el_maxnder) :: Dbas
  integer, dimension(el_maxnbas) :: Idofs
  
  ! List of element distributions in the discretisation structure
  type(t_elementDistribution), dimension(:), pointer :: p_RelementDistribution

  ! Evaluation structure and tag
  type(t_evalElement) :: revalElement
  integer :: cevaluationTag  
  
  p_RelementDistribution => rvecMon%p_rspatialDiscr%RelementDistr
  
  ! for uniform discretisations, we get the element type in advance...
  if(rvecMon%p_rspatialDiscr%ccomplexity .EQ. SPDISC_UNifORM) then
  
    ! Element type
    ieltype = rvecMon%p_rspatialDiscr%RelementDistr(1)%celement
    
    ! get the number of local doF`s for trial and test functions
    indof = elem_igetNDofLoc(ieltype)
    
    ! number of vertices on the element
    nve = elem_igetNDofLoc(ieltype)
    
    ! type of transformation from/to the reference element
    ctrafoType = elem_igetTrafoType(ieltype)
    
    ! Get the element evaluation tag; neccessary for preparation
    cevaluationTag = elem_getEvaluationTag(ieltype)
    
    NULLifY(p_IelementDistr)
  else
     call storage_getbase_int (&
          rvecMon%p_rspatialDiscr%h_IelementDistr,p_IelementDistr)    
  end if
  
  ! get the data vector
  select case (rvecMon%cdataType)
  case (ST_doUBLE) 
    call lsyssc_getbase_double(rvecMon,p_DdataMon)
    call lsyssc_getbase_double(rvecArea,p_DdataArea)
    call lsyssc_getbase_double(rvecGradX,p_DdataGradX)
    call lsyssc_getbase_double(rvecGradY,p_DdataGradY)    
  case (ST_SINGLE)
  case default
    call output_line ('Unsupported vector precision!',&
        OU_CLASS_ERROR,OU_MODE_STD,'fevl_evaluate')
    call sys_halt()
  end SELECT  

  ! What to evaluate
  Bder = .FALSE.
  Bder(iderType) = .TRUE.
  
  cnonmesh = FEVL_NONMESHPTS_NONE
  if (PRESENT(cnonmeshPoints)) cnonmesh = cnonmeshPoints
  
  ! We loop over all points
  iel = 1
  
  ! Get the element number that contains the point
  if(PRESENT(Ielements))then
    ! we have it...
    iel = Ielements
  end if
  
  ! get the type of the element iel
  if(associated(p_ielementdistr))then
    ieltype = p_RelementDistribution(p_IelementDistr(iel))%celement
    
    ! Get the number of local doF`s for trial and test functions
    indof = elem_igetNDofLoc(ieltype)
    
    ! Number of vertices on the element
    nve = elem_igetNVE(ieltype)
    
    ! Type of transformation from /to the reference element
    ctrafoType = elem_igetTrafoType(ieltype)
    
    ! get the element evaluation tag; necessary for the preparation of the element
    cevaluationTag = elem_getEvaluationTag(ieltype)
  end if
  
  ! Calculate the global doF`s on that element into IdofsTest.
  call dof_locGlobMapping(rvecMon%p_rspatialDiscr, iel, Idofs)
  
  ! Get the element shape information
  call elprep_prepareForEvaluation(revalElement, EL_EVLTAG_COORDS, &
       rvecMon%p_rspatialDiscr%p_rtriangulation, iel, ctrafoType)
       
  ! calculate the transformation of the point to the reference element
  call trafo_calcRefCoords(ctrafoType, revalElement%Dcoords, &
       Dpoint(:), DparPoint)
       
  ! Now calculate everything else what is necessary for the element
  call elprep_prepareForEvaluation (revalElement, &
      IAND(cevaluationTag,NOT(EL_EVLTAG_COORDS)), &
      rvecMon%p_rspatialDiscr%p_rtriangulation, iel, &
      ctrafoType, DparPoint, Dpoint(:))    
  
  ! Call the element to calculate the values of the basis functions
  ! in the point
  call elem_generic2(ieltype, revalElement, Bder, Dbas)
  
  ! Combine the basis functions to get the function value
  Dvalues(:) = 0.0_DP
  
  ! Now that we have the basis functions, we want to have the function values.
  ! We get them by multiplying the FE-coefficients with the values of the
  ! basis functions and summing up.
  !          
  ! Calculate the value in the point
  do ibas = 1, indof
    Dvalues(1) = Dvalues(1) + p_DdataGradX(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(2) = Dvalues(2) + p_DdataGradY(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(3) = Dvalues(3) + p_DdataMon(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(4) = Dvalues(4) + p_DdataArea(Idofs(ibas)) * Dbas(ibas,iderType)
  end do
  
  Dvalues(3) = 1.0_DP/Dvalues(3)
  Dvalues(4) = 1.0_DP/Dvalues(4)
  
  end subroutine ! end griddef_evalPhi_Known
  
  !**************************************************************************** 
  
!<subroutine>  
  subroutine griddef_evalphi_ray(iderType, Dvalues, rvecGradX, &
             rvecGradY,rvecMon,rvecArea,Dpoint,bsearchFailed, &
             ielement)
!<description>
  ! This is the most general (and completely slowest) finite element evaluation
  ! routine. It allows to evaluate a general (scalar) FE function specified
  ! by rvecMon in a set of points Dpoints. The values of the
  ! FE function are written into Dvalues.
!</description>

!<input>
  ! type of function value to evaluate. One of the DER_xxxx constants
  integer, intent(in)           :: iderType
  
  ! the scalar solution vector that is to be evaluated.
  type(t_vectorScalar), intent(in)              :: rvecMon
  
  type(t_vectorScalar), intent(in)              :: rvecGradX
  
  type(t_vectorScalar), intent(in)              :: rvecGradY  
  
  type(t_vectorScalar), intent(in)              :: rvecArea    
  
  ! a list of points where to evaluate
  ! dimension(1..ndim,1..npoints)
  real(dp), dimension(:), intent(in) :: Dpoint
  
  ! Previous element containing the point
  integer, intent(in) :: ielement
  
!</input>


!<inputoutput>
  logical, intent(inout) :: bsearchFailed
!</inputoutput>

!<output>
  ! Values of the FE function at the points specified by Dpoints.
  real(dp), dimension(:), intent(out) :: Dvalues
!</output>      

!</subroutine>

  ! local variables
  integer :: ieltype,indof,nve,ibas
  integer :: iel
  integer, dimension(:), pointer :: p_IelementDistr
  logical, dimension(el_maxnder) :: Bder
  
  real(dp), dimension(:), pointer :: p_DdataMon
  real(dp), dimension(:), pointer :: p_DdataArea
  real(dp), dimension(:), pointer :: p_DdataGradX
  real(dp), dimension(:), pointer :: p_DdataGradY
  
  ! Transformation
  integer :: ctrafotype,iresult,ilastElement,ilastEdge
  real(dp), dimension(trafo_maxdimrefcoord) :: DparPoint 
  
  ! Values of basis functions and doF`s
  real(dp), dimension(el_maxnbas,el_maxnder) :: Dbas
  integer, dimension(el_maxnbas) :: Idofs
  
  ! List of element distributions in the discretisation structure
  type(t_elementDistribution), dimension(:), pointer :: p_RelementDistribution

  ! Evaluation structure and tag
  type(t_evalElement) :: revalElement
  integer :: cevaluationTag  
  
  p_RelementDistribution => rvecMon%p_rspatialDiscr%RelementDistr
  
  ! for uniform discretisations, we get the element type in advance...
  if(rvecMon%p_rspatialDiscr%ccomplexity .EQ. SPDISC_UNifORM) then
  
    ! Element type
    ieltype = rvecMon%p_rspatialDiscr%RelementDistr(1)%celement
    
    ! get the number of local doF`s for trial and test functions
    indof = elem_igetNDofLoc(ieltype)
    
    ! number of vertices on the element
    nve = elem_igetNDofLoc(ieltype)
    
    ! type of transformation from/to the reference element
    ctrafoType = elem_igetTrafoType(ieltype)
    
    ! Get the element evaluation tag; neccessary for preparation
    cevaluationTag = elem_getEvaluationTag(ieltype)
    
    nullify(p_IelementDistr)
  else
     call storage_getbase_int (&
          rvecMon%p_rspatialDiscr%h_IelementDistr,p_IelementDistr)    
  end if
  
  ! get the data vector
  select case (rvecMon%cdataType)
  case (ST_doUBLE) 
    call lsyssc_getbase_double(rvecMon,p_DdataMon)
    call lsyssc_getbase_double(rvecArea,p_DdataArea)
    call lsyssc_getbase_double(rvecGradX,p_DdataGradX)
    call lsyssc_getbase_double(rvecGradY,p_DdataGradY)    
  case (ST_SINGLE)
  case default
    call output_line ('Unsupported vector precision!',&
        OU_CLASS_ERROR,OU_MODE_STD,'fevl_evaluate')
    call sys_halt()
  end select  

  ! What to evaluate
  Bder = .FALSE.
  Bder(iderType) = .TRUE.
  
  ! We loop over all points
  iel = ielement
  
  ! Use raytracing search to find the element
  ! containing the point.
  call tsrch_getElem_raytrace2D (&
    Dpoint(:),rvecMon%p_rspatialDiscr%p_rtriangulation,iel,&
    iresult,ilastElement,ilastEdge,200)
  ! Fehler, wenn die Iterationen ausgehen wird
  ! das letzte Element zurückgegeben... verkehrt...
  ! Ok, not found... Brute force search
  
  if((iel .eq. 0) .or. (iresult .le. 0))then
    call tsrch_getElem_BruteForce (Dpoint(:), &
      rvecMon%p_rspatialDiscr%p_rtriangulation,iel)
  end if
  
  if((iel .eq. 0))then
    bsearchFailed = .true.
    return
  end if  
  
  ! get the type of the element iel
  if(ASSOCIATED(p_IelementDistr))then
    ieltype = p_RelementDistribution(p_IelementDistr(iel))%celement
    
    ! Get the number of local doF`s for trial and test functions
    indof = elem_igetNDofLoc(ieltype)
    
    ! Number of vertices on the element
    nve = elem_igetNVE(ieltype)
    
    ! Type of transformation from /to the reference element
    ctrafoType = elem_igetTrafoType(ieltype)
    
    ! get the element evaluation tag; necessary for the preparation of the element
    cevaluationTag = elem_getEvaluationTag(ieltype)
  end if
  
  ! Calculate the global doF`s on that element into IdofsTest.
  call dof_locGlobMapping(rvecMon%p_rspatialDiscr, iel, Idofs)
  
  ! Get the element shape information
  call elprep_prepareForEvaluation(revalElement, EL_EVLTAG_COORDS, &
       rvecMon%p_rspatialDiscr%p_rtriangulation, iel, ctrafoType)
       
  ! calculate the transformation of the point to the reference element
  call trafo_calcRefCoords(ctrafoType, revalElement%Dcoords, &
       Dpoint(:), DparPoint)
       
  ! Now calculate everything else what is necessary for the element
  call elprep_prepareForEvaluation (revalElement, &
      IAND(cevaluationTag,NOT(EL_EVLTAG_COORDS)), &
      rvecMon%p_rspatialDiscr%p_rtriangulation, iel, &
      ctrafoType, DparPoint, Dpoint(:))    
  
  ! Call the element to calculate the values of the basis functions
  ! in the point
  call elem_generic2(ieltype, revalElement, Bder, Dbas)
  
  ! Combine the basis functions to get the function value
  Dvalues(:) = 0.0_DP
  
  ! Now that we have the basis functions, we want to have the function values.
  ! We get them by multiplying the FE-coefficients with the values of the
  ! basis functions and summing up.
  !          
  ! Calculate the value in the point
  do ibas = 1, indof
    Dvalues(1) = Dvalues(1) + p_DdataGradX(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(2) = Dvalues(2) + p_DdataGradY(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(3) = Dvalues(3) + p_DdataMon(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(4) = Dvalues(4) + p_DdataArea(Idofs(ibas)) * Dbas(ibas,iderType)
  end do
  
  Dvalues(3) = 1.0_DP/Dvalues(3)
  Dvalues(4) = 1.0_DP/Dvalues(4)  
  
  
  end subroutine ! end griddef_evalphi_ray

! ***************************************************************************   
 
!<subroutine>  
  subroutine griddef_evalphi_ray_bound(iderType, Dvalues, rvecGradX, &
             rvecGradY,rvecMon,rvecArea,Dpoint,iinelement)
!<description>
  ! This is the most general (and completely slowest) finite element evaluation
  ! routine. It allows to evaluate a general (scalar) FE function specified
  ! by rvecMon in a set of points Dpoints. The values of the
  ! FE function are written into Dvalues.
!</description>

!<input>
  ! type of function value to evaluate. One of the DER_xxxx constants
  integer, intent(in)           :: iderType
  integer, intent(in)           :: iinelement
  
  ! the scalar solution vector that is to be evaluated.
  type(t_vectorScalar), intent(in)              :: rvecMon
  
  type(t_vectorScalar), intent(in)              :: rvecGradX
  
  type(t_vectorScalar), intent(in)              :: rvecGradY  
  
  type(t_vectorScalar), intent(in)              :: rvecArea    
  
  ! a list of points where to evaluate
  ! dimension(1..ndim,1..npoints)
  real(dp), dimension(:), intent(in) :: Dpoint
  
!</input>

!<output>
  ! Values of the FE function at the points specified by Dpoints.
  real(dp), dimension(:), intent(out) :: Dvalues
!</output>      

!</subroutine>

  ! local variables
  integer :: cnonmesh
  integer :: ieltype,indof,nve,ibas
  integer :: iel
  integer, dimension(:), pointer :: p_IelementDistr
  logical, dimension(el_maxnder) :: Bder
  
  real(dp), dimension(:), pointer :: p_DdataMon
  real(dp), dimension(:), pointer :: p_DdataArea
  real(dp), dimension(:), pointer :: p_DdataGradX
  real(dp), dimension(:), pointer :: p_DdataGradY
  
  ! Transformation
  integer :: ctrafoType
  real(DP), dimension(TRAFO_MAXDIMREFCOORD) :: DparPoint 
  
  ! Values of basis functions and doF`s
  real(DP), dimension(EL_MAXNBAS,EL_MAXNDER) :: Dbas
  integer, dimension(EL_MAXNBAS) :: Idofs
  
  ! List of element distributions in the discretisation structure
  type(t_elementDistribution), dimension(:), pointer :: p_RelementDistribution

  ! Evaluation structure and tag
  type(t_evalElement) :: revalElement
  integer :: cevaluationTag  
  
  p_RelementDistribution => rvecMon%p_rspatialDiscr%RelementDistr
  
  ! for uniform discretisations, we get the element type in advance...
  if(rvecMon%p_rspatialDiscr%ccomplexity .EQ. SPDISC_UNifORM) then
  
    ! Element type
    ieltype = rvecMon%p_rspatialDiscr%RelementDistr(1)%celement
    
    ! get the number of local doF`s for trial and test functions
    indof = elem_igetNDofLoc(ieltype)
    
    ! number of vertices on the element
    nve = elem_igetNDofLoc(ieltype)
    
    ! type of transformation from/to the reference element
    ctrafoType = elem_igetTrafoType(ieltype)
    
    ! Get the element evaluation tag; neccessary for preparation
    cevaluationTag = elem_getEvaluationTag(ieltype)
    
    NULLifY(p_IelementDistr)
  else
     call storage_getbase_int (&
          rvecMon%p_rspatialDiscr%h_IelementDistr,p_IelementDistr)    
  end if
  
  ! get the data vector
  select case (rvecMon%cdataType)
  case (ST_doUBLE) 
    call lsyssc_getbase_double(rvecMon,p_DdataMon)
    call lsyssc_getbase_double(rvecArea,p_DdataArea)
    call lsyssc_getbase_double(rvecGradX,p_DdataGradX)
    call lsyssc_getbase_double(rvecGradY,p_DdataGradY)    
  case (ST_SINGLE)
  case default
    call output_line ('Unsupported vector precision!',&
        OU_CLASS_ERROR,OU_MODE_STD,'fevl_evaluate')
    call sys_halt()
  end SELECT  

  ! What to evaluate
  Bder = .FALSE.
  Bder(iderType) = .TRUE.
  
  ! We loop over all points
  iel = iinelement
  
  ! get the type of the element iel
  if(ASSOCIATED(p_IelementDistr))then
    ieltype = p_RelementDistribution(p_IelementDistr(iel))%celement
    
    ! Get the number of local doF`s for trial and test functions
    indof = elem_igetNDofLoc(ieltype)
    
    ! Number of vertices on the element
    nve = elem_igetNVE(ieltype)
    
    ! Type of transformation from /to the reference element
    ctrafoType = elem_igetTrafoType(ieltype)
    
    ! get the element evaluation tag; necessary for the preparation of the element
    cevaluationTag = elem_getEvaluationTag(ieltype)
  end if
  
  ! Calculate the global doF`s on that element into IdofsTest.
  call dof_locGlobMapping(rvecMon%p_rspatialDiscr, iel, Idofs)
  
  ! Get the element shape information
  call elprep_prepareForEvaluation(revalElement, EL_EVLTAG_COORDS, &
       rvecMon%p_rspatialDiscr%p_rtriangulation, iel, ctrafoType)
       
  ! calculate the transformation of the point to the reference element
  call trafo_calcRefCoords(ctrafoType, revalElement%Dcoords, &
       Dpoint(:), DparPoint)
       
  ! Now calculate everything else what is necessary for the element
  call elprep_prepareForEvaluation (revalElement, &
      IAND(cevaluationTag,NOT(EL_EVLTAG_COORDS)), &
      rvecMon%p_rspatialDiscr%p_rtriangulation, iel, &
      ctrafoType, DparPoint, Dpoint(:))    
  
  ! Call the element to calculate the values of the basis functions
  ! in the point
  call elem_generic2(ieltype, revalElement, Bder, Dbas)
  
  ! Combine the basis functions to get the function value
  Dvalues(:) = 0.0_DP
  
  ! Now that we have the basis functions, we want to have the function values.
  ! We get them by multiplying the FE-coefficients with the values of the
  ! basis functions and summing up.
  !          
  ! Calculate the value in the point
  do ibas = 1, indof
    Dvalues(1) = Dvalues(1) + p_DdataGradX(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(2) = Dvalues(2) + p_DdataGradY(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(3) = Dvalues(3) + p_DdataMon(Idofs(ibas)) * Dbas(ibas,iderType)
    Dvalues(4) = Dvalues(4) + p_DdataArea(Idofs(ibas)) * Dbas(ibas,iderType)
  end do
  
  Dvalues(3) = 1.0_DP/Dvalues(3)
  Dvalues(4) = 1.0_DP/Dvalues(4)  

  end subroutine ! griddef_evalphi_ray_bound
 
 !****************************************************************************  
  
!<subroutine>  
  subroutine griddef_getAreaDeformed(rgriddefInfo,&
             rvectorAreaBlockQ0,rvectorAreaBlockQ1,rvectorAreaQ0)
  
  !<description>
    ! In this function we build the nodewise area distribution and 
    ! the elementwise distribution, for debugging purposes
  !</description>

  !<inputoutput>
    ! structure containing all parameter settings for grid deformation
    type(t_griddefInfo), intent(inout) :: rgriddefInfo

    type(t_vectorBlock),intent(inout)  :: rvectorAreaBlockQ0
    type(t_vectorBlock),intent(inout)  :: rvectorAreaBlockQ1 
    type(t_vectorScalar),intent(inout) :: rvectorAreaQ0  
  !</output>  

!</subroutine>

    ! local variables
    integer, dimension(:,:), pointer :: p_IverticesAtElement
    integer, dimension(:), pointer :: p_DareaLevel
    real(dp), dimension(:,:), pointer :: p_DvertexCoords
    real(dp), dimension(:), pointer :: p_Darea
    real(dp), dimension(:), pointer :: p_DareaProj    
    integer :: iel
    real(dp), dimension(ndim2d,tria_maxnve2d) :: Dpoints
    integer :: ive,NLMAX

    type(t_blockDiscretisation) :: rprjDiscretisation
    type(t_blockDiscretisation) :: rdiscretisation  
    
    
    NLMAX=rgriddefInfo%NLMAX   
        
    ! Is everything here we need?
    if (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   %h_DvertexCoords .EQ. ST_NOHANDLE) then
      call output_line ('h_DvertexCoords not available!', &
                        OU_CLASS_ERROR,OU_MODE_STD,'tria_genElementVolume2D')
      call sys_halt()
    end if

    if (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   %h_IverticesAtElement .EQ. ST_NOHANDLE) then
      call output_line ('IverticesAtElement  not available!', &
                        OU_CLASS_ERROR,OU_MODE_STD,'tria_genElementVolume2D')
      call sys_halt()
    end if
    
    ! Do we have (enough) memory for that array?
    if (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   %h_DelementVolume .EQ. ST_NOHANDLE) then
      call storage_new ('tria_genElementVolume2D', 'DAREA', &
          INT(rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   %NEL+1,I32), ST_doUBLE, &
          rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   %h_DelementVolume, ST_NEWBLOCK_NOINIT)
    end if
    
    call spdiscr_initBlockDiscr (rdiscretisation,1,&
                                 rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   )
                                   
    call spdiscr_initDiscr_simple (rdiscretisation%RspatialDiscr(1), &
                                   EL_E011,CUB_G2X2,rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation)
                                   
    
    ! Get the arrays
    call storage_getbase_double2D (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   %h_DvertexCoords,&
        p_DvertexCoords)
    call storage_getbase_int2D (rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation   %h_IverticesAtElement,&
        p_IverticesAtElement)
    
    ! Set up an empty block vector    
    call lsysbl_createVecBlockByDiscr(rdiscretisation,rvectorAreaBlockQ1,.TRUE.)        
        
    ! Create a discretisation structure for Q0, based on our
    ! previous discretisation structure:
    call spdiscr_duplicateBlockDiscr(rdiscretisation,rprjDiscretisation)
    call spdiscr_deriveSimpleDiscrSc (&
                 rdiscretisation%RspatialDiscr(1), &
                 EL_Q0, CUB_G2X2, rprjDiscretisation%RspatialDiscr(1))
                 
    ! Initialise a Q0 vector from the newly created discretisation         
    call lsyssc_createVecByDiscr(rprjDiscretisation%RspatialDiscr(1), &
    rvectorAreaQ0,.true.)
    
    ! get the pointer to the entries of this vector
    call lsyssc_getbase_double(rvectorAreaQ0,p_Darea)    
    
    ! Loop over all elements calculate the area 
    ! and save it in our vector
    do iel=1,rgriddefInfo%p_rhLevels(NLMAX)%rtriangulation%NEL
      
      if (p_IverticesAtElement(4,iel) .EQ. 0) then
        ! triangular element
        do ive=1,TRIA_NVETRI2D
          Dpoints(1,ive) = p_DvertexCoords(1,p_IverticesAtElement(ive,iel))
          Dpoints(2,ive) = p_DvertexCoords(2,p_IverticesAtElement(ive,iel))
        end do
        p_Darea(iel) = gaux_getArea_tria2D(Dpoints)
      else
        ! quad element
        do ive=1,TRIA_NVEQUAD2D
          Dpoints(1,ive) = p_DvertexCoords(1,p_IverticesAtElement(ive,iel))
          Dpoints(2,ive) = p_DvertexCoords(2,p_IverticesAtElement(ive,iel))
        end do
        p_Darea(iel) = gaux_getArea_quad2D(Dpoints)
      end if

    end do ! end iel
    ! now transform the q0 vector into a q1 vector
    ! Setup a new solution vector based on this discretisation,
    ! allocate memory.
    call lsysbl_createVecFromScalar(rvectorAreaQ0,rvectorAreaBlockQ0,rprjDiscretisation)
 
 
    ! Take the original solution vector and convert it according to the
    ! new discretisation:
    call spdp_projectSolution(rvectorAreaBlockQ0,rvectorAreaBlockQ1)

    !call lsyssc_releaseVector(rvectorAreaQ0)
    call spdiscr_releaseBlockDiscr(rdiscretisation)

  
  end subroutine ! griddef_getAreaDeformed
  
  ! ***************************************************************************   
 
!<subroutine>
 subroutine griddef_qMeasureM1(rgriddefInfo,rgriddefWork)
!<description>
  !
  !
  !
!</description>

!<inputoutput>
  ! structure containing all parameter settings for grid deformation
  type(t_griddefInfo), intent(inout)  :: rgriddefInfo

  ! structure containing all vector handles for the deformation algorithm
  type(t_griddefWork), intent(inout)  :: rgriddefWork

!</inputoutput>
!</subroutine>
 
 end subroutine ! griddef_qMeasureM1
 
  ! ***************************************************************************   
 
end module
