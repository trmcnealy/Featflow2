!##############################################################################
!# ****************************************************************************
!# <name> linearformevaluation </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains routines for the discretisation of linear forms,
!# i.e. the creation of vectors (which usually appear as RHS vectors). 
!# It contains the
!# following set of routines:
!#
!# 1.) linf_buildVectorScalar
!#     -> Assembles the entries of a vector according to a linear form
!#        defined in terms of a volume integral.
!#
!# 2.) linf_buildVectorScalarBdr2d
!#     -> Assembles the entries of a vector according to a linear form
!#        defined in terms of a boundary integral.
!#
!# Frequently asked questions
!# --------------------------
!#
!# 1.) How to assemble a rhs-vector?
!#
!#  To assemble a vector, you first have to specify a linear form, a vector and
!#  a spatial discretisation structure that defines the FE spaces to use.
!#
!#    type(t_linearForm) :: rform
!#    type(t_vectorScalar) :: rvector
!#    type(t_spatialDiscretisation) :: rdiscretisation
!#
!#  We set up a linear form structure, e.g. for the Laplace operator:
!#
!#    rform%itermCount = 1
!#    rform%Idescriptors(1) = DER_FUNC
!#
!#  This e.g. initialises a linear form for evaluating a function.
!#  In the next step, use the linear form to create the matrix entries:
!#
!#    call bilf_buildVectorScalar (rdiscretisation,rform,.true.,rvector,coeff_RHS)
!#
!#  where coeff_RHS is a callback routine returning the RHS function. That's it.
!#
!# 2.) What is the 'manual matrix assembly'?
!#
!#  This is a possibility to assemble parts of the vector by specifying
!#  an element, a cubature formula and a list of elements where to assemble.
!#  The call
!#
!#    call linf_buildVectorScalar2 (rdiscretisation,rform,.true.,rvector,coeff_RHS)
!#
!#  assembles a vectpr just like the call to bilf_buildVectorScalar, but using
!#  another technique which you can also use if you want to assemble parts
!#  of the vector on your own. 
!# 
!#  To 'manually' assemble parts of the matrix, you can use the
!#  linf_initAssembly / linf_doneAssembly / linf_assembleSubvector
!#  subroutines in conjunction with the linf_assembleSubvector structure.
!#  Assume e.g. that elements 501..750 of a mesh are discretised with Q1
!#  and the Gauss 2x2 cubature formula in 2D. We now want to assemble a
!#  RHS on these elements. We start like before, defining
!#  a linear form, some structures and create the matrix structure:
!#
!#    type(t_linearForm) :: rform
!#    type(t_vectorScalar) :: rvector
!#    type(t_vectorAssembly) :: rvectorAssembly
!#    type(t_spatialDiscretisation) :: rdiscretisation
!#
!#  We set up a linear form structure, e.g. for the Laplace operator:
!#
!#    rform%itermCount = 1
!#    rform%Idescriptors(1) = DER_FUNC
!#
!#  Create the vector:
!#
!#    call lsyssc_createVecByDiscr (rdiscretisation,rx,.true.)
!#
!#  Initialise the vector assembly structure for the assembly
!#
!#    call linf_initAssembly(rvectorAssembly,rform,EL_Q1,CUB_G2_2D)
!#
!#  and assemble only on the elements 501..750 which we specify in Ielements:
!#
!#    do i=501,750
!#      Ielements(i-500) = i
!#    end do
!#    call linf_assembleSubvector (rvectorAssembly,rvector,IelementList)
!#
!#  Finally, we release the assembly structure.
!#
!#    call linf_doneAssembly(rvectorAssembly)
!#
!#  So the result is a vector with the RHS assembled only in
!#  the elements 501..750. That way, the user has the ability to
!#  specify element type, element numbers and cubature formula manually
!#  without having to specify everything in a discretisation structure;
!#  that's the reason why this assembly is called 'manual' assembly.
!#
!#  This method is extremely useful when one wants to assemble vectors with
!#  adaptive/summed cubature formulas. Some parts of the domain can that way
!#  be assembled with a cubature formula which is high enough to capture the
!#  behaviour of the integral for nonsmooth, nonconstant coefficients, while
!#  other parts of the domain may be assembled with the standard cubature 
!#  formula.
!# </purpose>
!##############################################################################

module linearformevaluation

  use basicgeometry
  use boundary
  use collection, only: t_collection
  use cubature
  use derivatives
  use dofmapping
  use domainintegration
  use element
  use elementpreprocessing
  use fsystem
  use genoutput
  use linearalgebra
  use linearsystemscalar
  use mprimitives
  use scalarpde
  use spatialdiscretisation
  use storage
  use transformation
  use triangulation
  
  implicit none
  
  private

!<types>
!<typeblock>

  ! A vector assembly structure that saves crucial data during the vector assembly.
  type t_linfVectorAssembly
  
    ! The bilinear form specifying the underlying PDE of the discretisation.
    type(t_linearForm) :: rform

    ! Number of local DOF's.
    integer :: indof
    
    ! Array to tell the element which derivatives to calculate.
    logical, dimension(EL_MAXNDER) :: Bder

    ! Maximum number of elements to handle simultaneously.
    integer :: nelementsPerBlock
    
    ! Number of vertices per element
    integer :: NVE
    
    ! Type of element to evaluate.
    integer(I32) :: celement
    
    ! Type of transformation
    integer(I32) :: ctrafoType
    
    ! Basic evaluation tag of the element spaces
    integer(I32) :: cevaluationTag
    
    ! Type of cubature formula to use.
    integer(I32) :: ccubType
    
    ! Number of cubature points per element
    integer :: ncubp
    
    ! The number of elements in revalElementSet whose cubature points on the
    ! reference element(s) have already been initialised.
    integer :: iinitialisedElements
    
    ! Cubature weights
    real(DP), dimension(:), pointer :: p_Domega
    
    ! An array that takes coordinates of the cubature formula on the reference element
    real(DP), dimension(:,:), pointer :: p_DcubPtsRef
    
    ! Arrays for the basis function values in the cubature points
    real(DP), dimension(:,:,:,:), pointer :: p_Dbas
    
    ! Arrays saving the DOF's in the elements
    integer, dimension(:,:), pointer :: p_Idofs

    ! Element set used for evaluating elements
    type(t_evalElementSet) :: revalElementSet
    
    ! Pointer to the coefficients that are computed by the callback routine.
    real(DP), dimension(:,:,:), pointer :: p_Dcoefficients
  
  end type
  
!</typeblock>

  public :: t_linfVectorAssembly

!</types>

!<constants>
!<constantblock description="Constants defining the blocking of the assembly">

  ! Number of elements to handle simultaneously when building vectors
  integer,public :: LINF_NELEMSIM   = 1000
  
!</constantblock>
!</constants>

  public :: linf_buildVectorScalar
  public :: linf_buildVectorScalarBdr2d
  public :: linf_initAssembly
  public :: linf_doneAssembly
  public :: linf_assembleSubvector
  public :: linf_buildVectorScalar2

contains

  !****************************************************************************

!<subroutine>

  subroutine linf_buildVectorScalar (rdiscretisation, rform, bclear, rvectorScalar,&
                                     fcoeff_buildVectorSc_sim, rcollection)
  
!<description>
  ! This routine assembles the entries of a vector according to a linear form
  ! (typically used for assembling RHS vectors).
  !
  ! If bclear=TRUE, the vector is cleared before the assembly and any 
  ! sorting of the entries is switched off - the vector is set up unsorted.
  !
  ! If bclear=FALSE, the vector must be unsorted when this routine is called, 
  ! otherwise an error is thrown.
!</description>

!<input>
  ! The underlying discretisation structure which is to be used to
  ! create the vector.
  type(t_spatialDiscretisation), intent(IN), target :: rdiscretisation
  
  ! The linear form specifying the underlying PDE of the discretisation.
  type(t_linearForm), intent(IN) :: rform
  
  ! Whether to clear the vector before calculating the entries.
  ! If .FALSE., the new entries are added to the existing entries.
  logical, intent(IN) :: bclear
  
  ! OPTIONAL: A collection structure. This structure is 
  ! given to the callback function for calculating the function
  ! which should be discretised in the linear form.
  type(t_collection), intent(INOUT), target, optional :: rcollection
  
  ! A callback routine for the function to be discretised.
  include 'intf_coefficientVectorSc.inc'
  optional :: fcoeff_buildVectorSc_sim
!</input>

!<inputoutput>
  ! The FE vector. Calculated entries are imposed to this vector.
  type(t_vectorScalar), intent(INOUT) :: rvectorScalar
!</inputoutput>

!</subroutine>
  
  ! If the vector is not set up as new vector, it has to be unsorted.
  ! If it's a new vector, we switch off the sorting.
  if (bclear) then
    rvectorScalar%isortStrategy = -abs(rvectorScalar%isortStrategy)
  end if
  
  ! The vector must be unsorted, otherwise we can't set up the vector.
  if (rvectorScalar%isortStrategy .gt. 0) then
    call output_line('Vector must be unsorted!',&
                     OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalar')
    call sys_halt()
  end if

  ! Do we have a uniform triangulation? Would simplify a lot...
  if ((rdiscretisation%ccomplexity .eq. SPDISC_UNIFORM) .or.&
      (rdiscretisation%ccomplexity .eq. SPDISC_CONFORMAL)) then 
    
    select case(rvectorScalar%cdataType)
      
    case(ST_DOUBLE)
      call linf_buildVectorDble_conf (rdiscretisation, rform, bclear, rVectorScalar,&  
                                      fcoeff_buildVectorSc_sim, rcollection)

    case DEFAULT
      call output_line('Single precision vectors currently not supported!',&
                       OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalar')
      call sys_halt()
    end select
    
  else
    call output_line('General discretisation not implemented!',&
                     OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalar')
    call sys_halt()
  end if

  end subroutine linf_buildVectorScalar  
  
  !****************************************************************************

!<subroutine>

  subroutine linf_buildVectorDble_conf (rdiscretisation, rform, bclear, rVectorScalar,&
                                        fcoeff_buildVectorSc_sim, rcollection)

!<description>
  ! This routine calculates the entries of a discretised finite element vector.
  ! The discretisation is assumed to be conformal, i.e. the DOF's
  ! of all finite elements must 'match'. 
  ! The linear form is defined by
  !        (f,$phi_i$), i=1..*
  ! with $Phi_i$ being the test functions defined in the discretisation
  ! structure.
  ! In case the array for the vector entries does not exist, the routine
  ! allocates memory in size of the vector of the heap for the vector entries
  ! and initialises all necessary variables of the vector according to the
  ! parameters (NEQ, pointer to the discretisation,...)
  !
  ! Double-precision version.
!</description>

!<input>
  ! The underlying discretisation structure which is to be used to
  ! create the vector.
  type(t_spatialDiscretisation), intent(IN), target :: rdiscretisation
  
  ! The linear form specifying the underlying PDE of the discretisation.
  type(t_linearForm), intent(IN) :: rform
  
  ! Whether to clear the vector before calculating the entries.
  ! If .FALSE., the new vector entries are added to the existing entries.
  logical, intent(IN) :: bclear
  
  ! OPTIONAL: A pointer to a collection structure. This structure is given to the
  ! callback function for nonconstant coefficients to provide additional
  ! information. 
  type(t_collection), intent(INOUT), target, optional :: rcollection
  
  ! A callback routine which is able to calculate the values of the
  ! function $f$ which is to be discretised.
  include 'intf_coefficientVectorSc.inc'
  optional :: fcoeff_buildVectorSc_sim
!</input>

!<inputoutput>
  ! The FE vector. Calculated vector entries are added to this vector.
  type(t_vectorScalar), intent(INOUT) :: rvectorScalar
!</inputoutput>

!</subroutine>

  ! local variables
  integer :: i,i1,icurrentElementDistr, ICUBP, IALBET, IA
  integer :: IEL, IELmax, IELset, IDOFE
  real(DP) :: OM,AUX
  
  ! Array to tell the element which derivatives to calculate
  logical, dimension(EL_MAXNDER) :: Bder
  
  ! For every cubature point on the reference element,
  ! the corresponding cubature weight
  real(DP), dimension(:), allocatable :: Domega
  
  ! number of cubature points on the reference element
  integer :: ncubp
  
  ! Pointer to the vector entries
  real(DP), dimension(:), pointer :: p_Ddata

  ! An allocateable array accepting the DOF's of a set of elements.
  integer, dimension(:,:), allocatable, target :: IdofsTest
  
  ! Allocateable arrays for the values of the basis functions - 
  ! for test space.
  real(DP), dimension(:,:,:,:), allocatable, target :: DbasTest
  
  ! Number of entries in the vector - for quicker access
  integer :: NEQ
  
  ! Type of transformation from the reference to the real element 
  integer(I32) :: ctrafoType
  
  ! Element evaluation tag; collects some information necessary for evaluating
  ! the elements.
  integer(I32) :: cevaluationTag

  ! Number of local degees of freedom for test functions
  integer :: indofTest
  
  ! The triangulation structure - to shorten some things...
  type(t_triangulation), pointer :: p_rtriangulation
  
  ! A pointer to an element-number list
  integer, dimension(:), pointer :: p_IelementList
  
  ! A small vector holding only the additive controbutions of
  ! one element
  real(DP), dimension(EL_MAXNBAS) :: DlocalData
  
  ! An array that takes coordinates of the cubature formula on the reference element
  real(DP), dimension(:,:), allocatable :: p_DcubPtsRef

  ! Pointer to the jacobian determinants
  real(DP), dimension(:,:), pointer :: p_Ddetj
  
  ! Current element distribution
  type(t_elementDistribution), pointer :: p_elementDistribution
  
  ! Number of elements in the current element distribution
  integer :: NEL

  ! Number of elements in a block. Normally =BILF_NELEMSIM,
  ! except if there are less elements in the discretisation.
  integer :: nelementsPerBlock
  
  ! Pointer to the coefficients that are computed by the callback routine.
  real(DP), dimension(:,:,:), allocatable :: Dcoefficients
  
  ! A t_domainIntSubset structure that is used for storing information
  ! and passing it to callback routines.
  type(t_domainIntSubset) :: rintSubset
  type(t_evalElementSet) :: revalElementSet
  logical :: bcubPtsInitialised
  
  
  ! Which derivatives of basis functions are needed?
  ! Check the descriptors of the bilinear form and set BDER
  ! according to these.
  
  Bder = .false.
  
  ! Loop through the additive terms
  do i = 1, rform%itermCount
    ! The desriptor Idescriptors gives directly the derivative
    ! which is to be computed!
    I1 = rform%Idescriptors(i)
    
    if ((I1 .le.0) .or. (I1 .gt. DER_MAXNDER)) then
      call output_line('Invalid descriptor',&
                       OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorDble_conf')
      call sys_halt()
    endif
    
    Bder(I1)=.true.
  end do
  
  if (rvectorScalar%h_Ddata .eq. ST_NOHANDLE) then
  
    ! Get the size of the vector and put it to the vector structure.
    NEQ = dof_igetNDofGlob(rdiscretisation)
    
    ! Initialise the vector parameters
    rvectorScalar%NEQ             = NEQ
    rvectorScalar%iidxFirstEntry  = 1
    rvectorScalar%p_rspatialDiscr => rdiscretisation
    rvectorScalar%cdataType       = ST_DOUBLE

    ! Clear the entries in the vector - we need to start with zero
    ! when assembling a new vector.
    call storage_new ('linf_buildVectorDble_conf', 'vector', &
                        NEQ, ST_DOUBLE, rvectorScalar%h_Ddata, &
                        ST_NEWBLOCK_ZERO)
    call storage_getbase_double (rvectorScalar%h_Ddata,p_Ddata)

  else
  
    ! Get information about the vector:
    NEQ = rvectorScalar%NEQ
  
    call storage_getbase_double (rvectorScalar%h_Ddata,p_Ddata)
    
    ! Maybe the vector is a partial vector of a larger one.
    ! Let the pointer point to the right position.
    if (rvectorScalar%iidxFirstEntry .ne. 1) then
      p_Ddata => p_Ddata (rvectorScalar%iidxFirstEntry : &
                          rvectorScalar%iidxFirstEntry + rvectorScalar%NEQ - 1)
    end if

    ! If desired, clear the vector before assembling.
    if (bclear) then
      call lalg_clearVectorDble (p_Ddata)
    end if
    
  end if
  
  ! Get a pointer to the triangulation - for easier access.
  p_rtriangulation => rdiscretisation%p_rtriangulation
  
  ! For saving some memory in smaller discretisations, we calculate
  ! the number of elements per block. For smaller triangulations,
  ! this is NEL. If there are too many elements, it's at most
  ! BILF_NELEMSIM. This is only used for allocating some arrays.
  nelementsPerBlock = min(LINF_NELEMSIM,p_rtriangulation%NEL)
  
  ! Now loop over the different element distributions (=combinations
  ! of trial and test functions) in the discretisation.
  do icurrentElementDistr = 1,rdiscretisation%inumFESpaces
  
    ! Activate the current element distribution
    p_elementDistribution => rdiscretisation%RelementDistr(icurrentElementDistr)
  
    ! Cancel if this element distribution is empty.
    if (p_elementDistribution%NEL .eq. 0) cycle

    ! Get the number of local DOF's for trial and test functions
    indofTest = elem_igetNDofLoc(p_elementDistribution%celement)
    
    ! Get from the trial element space the type of coordinate system
    ! that is used there:
    ctrafoType = elem_igetTrafoType(p_elementDistribution%celement)

    ! Get the number of cubature points for the cubature formula
    ncubp = cub_igetNumPts(p_elementDistribution%ccubTypeLinForm)

    ! Allocate two arrays for the points and the weights
    allocate(Domega(ncubp))
    allocate(p_DcubPtsRef(trafo_igetReferenceDimension(ctrafoType),ncubp))
    
    ! Get the cubature formula
    call cub_getCubature(p_elementDistribution%ccubTypeLinForm,p_DcubPtsRef, Domega)
    
    ! Open-MP-Extension: Open threads here.
    ! Each thread will allocate its own local memory...
    !
    !%OMP PARALLEL PRIVATE(rintSubset, revalElementSet,&
    !%OMP   p_Ddetj,DbasTest, cevaluationTag, bcubPtsInitialised,&
    !%OMP   IdofsTest,&
    !%OMP   Dcoefficients, &
    !%OMP   ielmax,IEL, idofe, &
    !%OMP   ICUBP, IALBET,OM,IA,aux)    
    
    ! Quickly check if one of the specified derivatives is out of the allowed range:
    do IALBET = 1,rform%itermcount
      IA = rform%Idescriptors(IALBET)
      if ((IA.lt.0) .or. &
          (IA .gt. elem_getMaxDerivative(p_elementDistribution%celement))) then
        call output_line('Specified test-derivative '//trim(sys_siL(IA,3))//' not available!',&
                         OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorDble_conf')
        call sys_halt()
      end if
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

    ! Allocate memory for the DOF's of all the elements.
    allocate(IdofsTest(indofTest,nelementsPerBlock))

    ! Allocate memory for the coefficients
    allocate(Dcoefficients(rform%itermCount,ncubp,nelementsPerBlock))
  
    ! Initialisation of the element set.
    call elprep_init(revalElementSet)

    ! Indicate that cubature points must still be initialised in the element set.
    bcubPtsInitialised = .false.
    
    ! p_IelementList must point to our set of elements in the discretisation
    ! with that combination of trial/test functions
    call storage_getbase_int (p_elementDistribution%h_IelementList, &
                              p_IelementList)
                              
    ! Get the number of elements there.
    NEL = p_elementDistribution%NEL
  
  
    ! Loop over the elements - blockwise.
    !%OMP do schedule(static,1)
    do IELset = 1, NEL, LINF_NELEMSIM
    
      ! We always handle LINF_NELEMSIM elements simultaneously.
      ! How many elements have we actually here?
      ! Get the maximum element number, such that we handle at most LINF_NELEMSIM
      ! elements simultaneously.
      
      IELmax = min(NEL,IELset-1+LINF_NELEMSIM)
    
      ! Calculate the global DOF's into IdofsTest.
      !
      ! More exactly, we call dof_locGlobMapping_mult to calculate all the
      ! global DOF's of our LINF_NELEMSIM elements simultaneously.
      call dof_locGlobMapping_mult(rdiscretisation, p_IelementList(IELset:IELmax), &
                                   IdofsTest)
      
      ! -------------------- ELEMENT EVALUATION PHASE ----------------------
      
      ! Ok, we found the positions of the local vector entries
      ! that we have to change.
      ! To calculate the vector contributions, we have to evaluate
      ! the elements to give us the values of the basis functions
      ! in all the DOF's in all the elements in our set.

      ! Get the element evaluation tag of all FE spaces. We need it to evaluate
      ! the elements later. All of them can be combined with OR, what will give
      ! a combined evaluation tag. 
      cevaluationTag = elem_getEvaluationTag(p_elementDistribution%celement)
                      
      ! Evaluate real coordinates; they are needed in the callback function.
      cevaluationTag = ior(cevaluationTag,EL_EVLTAG_REALPOINTS)
      
      ! In the first loop, calculate the coordinates on the reference element.
      ! In all later loops, use the precalculated information.
      !
      ! Note: Why not using
      !   IF (IELset .EQ. 1) THEN
      ! here, but this strange concept with the boolean variable?
      ! Because the IF-command does not work with OpenMP! bcubPtsInitialised
      ! is a local variable and will therefore ensure that every thread
      ! is initialising its local set of cubature points!
      if (.not. bcubPtsInitialised) then
        bcubPtsInitialised = .true.
        cevaluationTag = ior(cevaluationTag,EL_EVLTAG_REFPOINTS)
      else
        cevaluationTag = iand(cevaluationTag,not(EL_EVLTAG_REFPOINTS))
      end if

      ! Calculate all information that is necessary to evaluate the finite element
      ! on all cells of our subset. This includes the coordinates of the points
      ! on the cells.
      call elprep_prepareSetForEvaluation (revalElementSet,&
          cevaluationTag, p_rtriangulation, p_IelementList(IELset:IELmax), &
          ctrafoType, p_DcubPtsRef(:,1:ncubp))
          
      p_Ddetj => revalElementSet%p_Ddetj

      ! Now it's time to call our coefficient function to calculate the
      ! function values in the cubature points:
      call domint_initIntegrationByEvalSet (revalElementSet,rintSubset)
      rintSubset%ielementDistribution = icurrentElementDistr
      rintSubset%ielementStartIdx = IELset
      rintSubset%p_Ielements => p_IelementList(IELset:IELmax)
      rintSubset%p_IdofsTrial => IdofsTest
      rintSubset%celement = p_elementDistribution%celement
      
      if (present(fcoeff_buildVectorSc_sim)) then
        call fcoeff_buildVectorSc_sim (rdiscretisation,rform, &
            IELmax-IELset+1,ncubp,revalElementSet%p_DpointsReal(:,:,1:IELmax-IELset+1), &
            IdofsTest,rintSubset, &
            Dcoefficients(:,:,1:IELmax-IELset+1),rcollection)
      else
        Dcoefficients(:,:,1:IELmax-IELset+1) = 1.0_DP
      end if
        
      ! Release the domain integration subset again
      call domint_doneIntegration(rintSubset)
      
      ! Calculate the values of the basis functions.
      call elem_generic_sim2 (p_elementDistribution%celement, &
          revalElementSet, Bder, DbasTest)
      
      ! --------------------- DOF COMBINATION PHASE ------------------------
      
      ! Values of all basis functions calculated. Now we can start 
      ! to integrate!
      !
      ! Loop through elements in the set and for each element,
      ! loop through the DOF's and cubature points to calculate the
      ! integral:
      
      do IEL=1,IELmax-IELset+1
        
        ! We make a 'local' approach, i.e. we calculate the values of the
        ! integral into the vector DlocalData and add them later into
        ! the large solution vector.
        
        ! Clear the output vector.
        DlocalData(1:indofTest) = 0.0_DP

        ! Loop over all cubature points on the current element
        do ICUBP = 1, ncubp
        
          ! calculate the current weighting factor in the cubature formula
          ! in that cubature point.
          !
          ! Take the absolut value of the determinant of the mapping.
          ! In 2D, the determinant is always positive, whereas in 3D,
          ! the determinant might be negative -- that's normal!

          OM = Domega(ICUBP)*abs(p_Ddetj(ICUBP,IEL))

          ! Loop over the additive factors in the linear form.
          do IALBET = 1,rform%itermcount
          
            ! Get from Idescriptors the type of the derivatives for the 
            ! test and trial functions. The summand we calculate
            ! here will be:
            !
            ! int_...  f * ( phi_i )_IA
            !
            ! -> IA=0: function value, 
            !      =1: first derivative, 
            !      =2: 2nd derivative,...
            !    as defined in the module 'derivative'.
            
            IA = rform%Idescriptors(IALBET)
            
            ! Multiply OM with the coefficient of the form.
            ! This gives the actual value to multiply the
            ! function value with before summing up to the integral.
            ! Get the precalculated coefficient from the coefficient array.
            AUX = OM * Dcoefficients(IALBET,ICUBP,IEL)
          
            ! Now loop through all possible combinations of DOF's
            ! in the current cubature point. 

            do IDOFE=1,indofTest
            
              ! Get the value of the basis function 
              ! phi_o in the cubature point. 
              ! Them multiply:
              !    DBAS(..) * AUX
              ! ~= phi_i * coefficient * cub.weight
              ! Summing this up gives the integral, so the contribution
              ! to the vector. 
              !
              ! Simply summing up DBAS(..) * AUX would give
              ! the additive contribution for the vector. We save this
              ! contribution in the local array.

              DlocalData(IDOFE) = DlocalData(IDOFE)+DbasTest(IDOFE,IA,ICUBP,IEL)*AUX
            
            end do ! IDOFE
            
          end do ! IALBET

        end do ! ICUBP 

        ! Incorporate the local vector into the global one.
        ! The 'local' DOF 1..indofTest is mapped to the global DOF using
        ! the IdofsTest array.
        do IDOFE=1,indofTest
          p_Ddata(IdofsTest(IDOFE,IEL)) = p_Ddata(IdofsTest(IDOFE,IEL)) + DlocalData(IDOFE)
        end do

      end do ! IEL
      
    end do ! IELset
    !%OMP END DO
    
    ! Release memory
    deallocate(Dcoefficients)
    deallocate(IdofsTest)
    deallocate(DbasTest)

    call elprep_releaseElementSet(revalElementSet)
    
    !%OMP END PARALLEL

    deallocate(p_DcubPtsRef)
    deallocate(Domega)

  end do ! icurrentElementDistr
  
  end subroutine linf_buildVectorDble_conf

  !****************************************************************************

!<subroutine>

  subroutine linf_buildVectorScalarBdr2d (rdiscretisation, rform, ccubType, bclear,&
                                          rvectorScalar, fcoeff_buildVectorScBdr2D_sim,&
                                          rboundaryRegion, rcollection)
  
!<description>
  ! This routine assembles the entries of a vector according to a linear form
  ! (typically used for assembling RHS vectors).
  !
  ! If bclear=TRUE, the vector is cleared before the assembly and any 
  ! sorting of the entries is switched off - the vector is set up unsorted.
  !
  ! If bclear=FALSE, the vector must be unsorted when this routine is called, 
  ! otherwise an error is thrown.
!</description>

!<input>
  ! The underlying discretisation structure which is to be used to
  ! create the vector.
  type(t_spatialDiscretisation), intent(IN), target :: rdiscretisation
  
  ! The linear form specifying the underlying PDE of the discretisation.
  type(t_linearForm), intent(IN) :: rform

  ! A line cubature formula CUB_xxxx_1D to be used for line integration.
  integer(I32), intent(IN) :: ccubType
  
  ! Whether to clear the vector before calculating the entries.
  ! If .FALSE., the new entries are added to the existing entries.
  logical, intent(IN) :: bclear
  
  ! OPTIONAL: A t_boundaryRegion specifying the boundary region where
  ! to calculate. If not specified, the computation is done over
  ! the whole boundary.
  type(t_boundaryRegion), intent(IN), optional :: rboundaryRegion
  
  ! OPTIONAL: A collection structure. This structure is 
  ! given to the callback function for calculating the function
  ! which should be discretised in the linear form.
  type(t_collection), intent(INOUT), target, optional :: rcollection
  
  ! A callback routine for the function to be discretised.
  include 'intf_coefficientVectorScBdr2D.inc'
  optional :: fcoeff_buildVectorScBdr2D_sim
!</input>

!<inputoutput>
  ! The FE vector. Calculated entries are imposed to this vector.
  type(t_vectorScalar), intent(INOUT) :: rvectorScalar
!</inputoutput>

!</subroutine>

  ! local variables
  type(t_boundary), pointer :: p_rboundary
  type(t_boundaryRegion) :: rboundaryReg
  integer :: ibdc

  ! If the vector is not set up as new vector, it has to be unsorted.
  ! If it's a new vector, we switch off the sorting.
  if (bclear) then
    rvectorScalar%isortStrategy = -abs(rvectorScalar%isortStrategy)
  end if
  
  ! The vector must be unsorted, otherwise we can't set up the vector.
  if (rvectorScalar%isortStrategy .gt. 0) then
    call output_line('Vector must be unsorted!',&
                     OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalarBdr2d')
    call sys_halt()
  end if

  ! The discretisation must provide a boundary structure
  if (associated(rdiscretisation%p_rboundary)) then
    p_rboundary => rdiscretisation%p_rboundary
  else
    call output_line('Discretisation does not provide boundary structure!',&
                     OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalarBdr2d')
    call sys_halt()
  end if

  ! Do we have a uniform triangulation? Would simplify a lot...
  if ((rdiscretisation%ccomplexity .eq. SPDISC_UNIFORM) .or.&
      (rdiscretisation%ccomplexity .eq. SPDISC_CONFORMAL)) then 
    
    select case(rvectorScalar%cdataType)
      
    case(ST_DOUBLE)
      
      ! If the boundary region is specified, call linf_buildVecDbleBdr2d_conf
      ! for that boundary region. Otherwise, call linf_buildVecDbleBdr2d_conf
      ! for all possible boundary regions
      if (present(rboundaryRegion)) then
        call linf_buildVecDbleBdr2d_conf (rboundaryRegion, rdiscretisation,&
                                          rform, ccubType, bclear, rVectorScalar,&
                                          fcoeff_buildVectorScBdr2D_sim, rcollection)
      else
        ! Create a boundary region for each boundary component and call
        ! the calculation routine for that.
        do ibdc = 1, boundary_igetNBoundComp(p_rboundary)
          call boundary_createRegion (p_rboundary, ibdc, 0, rboundaryReg)
          call linf_buildVecDbleBdr2d_conf (rboundaryReg, rdiscretisation,&
                                            rform, ccubType, bclear, rVectorScalar,&
                                            fcoeff_buildVectorScBdr2D_sim, rcollection)
        end do
      end if

    case DEFAULT
      call output_line('Single precision vectors currently not supported!',&
                       OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalarBdr2d')
      call sys_halt()
    end select
    
  else
    call output_line('General discretisation not implemented!',&
                     OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalarBdr2d')
    call sys_halt()
  end if

  end subroutine linf_buildVectorScalarBdr2d

!****************************************************************************

!<subroutine>

  subroutine linf_buildVecDbleBdr2d_conf (rboundaryRegion, rdiscretisation,&
                                          rform, ccubType, bclear, rVectorScalar,&
                                          fcoeff_buildVectorScBdr2D_sim, rcollection)

!<description>
  ! This routine calculates the entries of a discretised finite element vector.
  ! The discretisation is assumed to be conformal, i.e. the DOF's
  ! of all finite elements must 'match'. 
  ! The linear form is defined by
  !        (f,$phi_i$), i=1..*
  ! with $Phi_i$ being the test functions defined in the discretisation
  ! structure.
  ! In case the array for the vector entries does not exist, the routine
  ! allocates memory in size of the vector of the heap for the vector entries
  ! and initialises all necessary variables of the vector according to the
  ! parameters (NEQ, pointer to the discretisation,...)
  !
  ! Double-precision version.
!</description>

!<input>
  ! A t_boundaryRegion specifying the boundary region where
  ! to calculate. 
  type(t_boundaryRegion), intent(IN) :: rboundaryRegion

  ! The underlying discretisation structure which is to be used to
  ! create the vector.
  type(t_spatialDiscretisation), intent(IN), target :: rdiscretisation
  
  ! The linear form specifying the underlying PDE of the discretisation.
  type(t_linearForm), intent(IN) :: rform
  
  ! A line cubature formula CUB_xxxx_1D to be used for line integration.
  integer(I32), intent(IN) :: ccubType

  ! Whether to clear the vector before calculating the entries.
  ! If .FALSE., the new vector entries are added to the existing entries.
  logical, intent(IN) :: bclear
  
  ! OPTIONAL: A pointer to a collection structure. This structure is given to the
  ! callback function for nonconstant coefficients to provide additional
  ! information. 
  type(t_collection), intent(INOUT), target, optional :: rcollection
  
  ! A callback routine which is able to calculate the values of the
  ! function $f$ which is to be discretised.
  include 'intf_coefficientVectorScBdr2D.inc'
  optional :: fcoeff_buildVectorScBdr2D_sim
!</input>

!<inputoutput>
  ! The FE vector. Calculated vector entries are added to this vector.
  type(t_vectorScalar), intent(INOUT) :: rvectorScalar
!</inputoutput>

!</subroutine>

  ! local variables
  integer, dimension(:), allocatable :: IelementOrientation
  integer, dimension(:), allocatable, target :: Ielements
  real(DP), dimension(:,:), allocatable :: DedgePosition
  
  integer :: ibdc,iedge,ilocaledge
  integer :: i1,ICUBP,IALBET,IA
  integer :: IEL, IDOFE
  real(DP) :: OM,AUX
  integer :: i,k
  
  ! The triangulation structure - to shorten some things...
  type(t_triangulation), pointer :: p_rtriangulation
  integer, dimension(:), pointer :: p_IboundaryCpIdx
  integer, dimension(:), pointer :: p_IedgesAtBoundary
  integer, dimension(:), pointer :: p_IelementsAtBoundary
  real(DP), dimension(:), pointer :: p_DedgeParameterValue
  real(DP), dimension(:,:), pointer :: p_DvertexCoordinates
  real(DP), dimension(:), pointer :: p_DvertexParameterValue
  integer, dimension(:,:), pointer :: p_IedgesAtElement
  integer, dimension(:,:), pointer :: p_IverticesAtElement
  
  ! Arrays for cubature points
  real(DP), dimension(CUB_MAXCUBP, NDIM3D) :: Dxi1D
  real(DP), dimension(:,:,:), allocatable :: Dxi2D,Dpoints,DpointsRef
  real(DP), dimension(:,:), allocatable :: DpointPar
  real(DP), dimension(CUB_MAXCUBP) :: Domega1D
  real(DP), dimension(:,:,:), allocatable :: Dcoefficients
  integer :: ncubp,ipoint
  integer(I32) :: celement
  integer(i32) :: icoordSystem
  real(DP) :: dlen,dpar1,dpar2
  
  ! Arrays for element distributions for every element
  integer, dimension(:), pointer :: p_IelementDistr
  
  ! List of element distributions in the discretisation structure
  type(t_elementDistribution), dimension(:), pointer :: p_RelementDistribution
  
  ! Array to tell the element which derivatives to calculate
  logical, dimension(EL_MAXNDER) :: Bder

  ! Pointer to the vector entries
  real(DP), dimension(:), pointer :: p_Ddata

  ! Number of entries in the vector - for quicker access
  integer :: NEQ

  ! Type of transformation from the reference to the real element 
  integer(I32) :: ctrafoType

  ! Element evaluation tag; collects some information necessary for evaluating
  ! the elements.
  integer(I32) :: cevaluationTag

  ! Number of elements in the boundary region
  integer :: NEL
  
  ! Number of elements on the current boundary component
  integer :: NELbdc

  ! Number of local degees of freedom for test functions
  integer :: indofTest

  ! A small vector holding only the additive controbutions of
  ! one element
  real(DP), dimension(EL_MAXNBAS) :: DlocalData

  ! An allocateable array accepting the DOF's of a set of elements.
  integer, dimension(:,:), allocatable, target :: IdofsTest

  ! Allocateable arrays for the values of the basis functions - 
  ! for test space.
  real(DP), dimension(:,:,:,:), allocatable, target :: DbasTest

  ! A t_domainIntSubset structure that is used for storing information
  ! and passing it to callback routines.
  type(t_domainIntSubset) :: rintSubset
  type(t_evalElementSet) :: revalElementSet


  ! Which derivatives of basis functions are needed?
  ! Check the descriptors of the bilinear form and set BDER
  ! according to these.

  Bder = .false.

  ! Loop through the additive terms
  do i = 1, rform%itermCount
    ! The desriptor Idescriptors gives directly the derivative
    ! which is to be computed!
    I1 = rform%Idescriptors(i)
    
    if ((I1 .le.0) .or. (I1 .gt. DER_MAXNDER)) then
      call output_line('Invalid descriptor',&
                       OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVecDbleBdr2d_conf')
      call sys_halt()
    endif
    
    Bder(I1)=.true.
  end do

  if (rvectorScalar%h_Ddata .eq. ST_NOHANDLE) then
  
    ! Get the size of the vector and put it to the vector structure.
    NEQ = dof_igetNDofGlob(rdiscretisation)
    
    ! Initialise the vector parameters
    rvectorScalar%NEQ             = NEQ
    rvectorScalar%iidxFirstEntry  = 1
    rvectorScalar%p_rspatialDiscr => rdiscretisation
    rvectorScalar%cdataType       = ST_DOUBLE

    ! Clear the entries in the vector - we need to start with zero
    ! when assembling a new vector.
    call storage_new ('linf_buildVectorDble_conf', 'vector', &
                        NEQ, ST_DOUBLE, rvectorScalar%h_Ddata, &
                        ST_NEWBLOCK_ZERO)
    call storage_getbase_double (rvectorScalar%h_Ddata, p_Ddata)

  else
  
    ! Get information about the vector:
    NEQ = rvectorScalar%NEQ
  
    call storage_getbase_double (rvectorScalar%h_Ddata, p_Ddata)
    
    ! Maybe the vector is a partial vector of a larger one.
    ! Let the pointer point to the right position.
    if (rvectorScalar%iidxFirstEntry .ne. 1) then
      p_Ddata => p_Ddata (rvectorScalar%iidxFirstEntry : &
                          rvectorScalar%iidxFirstEntry + rvectorScalar%NEQ - 1)
    end if

    ! If desired, clear the vector before assembling.
    if (bclear) then
      call lalg_clearVectorDble (p_Ddata)
    end if
    
  end if

  ! Get some pointers and arrays for quicker access
  p_rtriangulation => rdiscretisation%p_rtriangulation
  p_RelementDistribution => rdiscretisation%RelementDistr
  
  call storage_getbase_int (p_rtriangulation%h_IboundaryCpIdx,&
      p_IboundaryCpIdx)
  call storage_getbase_int (p_rtriangulation%h_IedgesAtBoundary,&
      p_IedgesAtBoundary)
  call storage_getbase_int (p_rtriangulation%h_IelementsAtBoundary,&
      p_IelementsAtBoundary)
  call storage_getbase_int2d (p_rtriangulation%h_IedgesAtElement,&
      p_IedgesAtElement)
  call storage_getbase_int2d (p_rtriangulation%h_IverticesAtElement,&
      p_IverticesAtElement)
  call storage_getbase_double2d (p_rtriangulation%h_DvertexCoords,&
      p_DvertexCoordinates)
  call storage_getbase_double (p_rtriangulation%h_DedgeParameterValue,&
      p_DedgeParameterValue)
  call storage_getbase_double (p_rtriangulation%h_DvertexParameterValue,&
      p_DvertexParameterValue)

  ! Boundary component?
  ibdc = rboundaryRegion%iboundCompIdx
  
  ! Number of elements on that boundary component?
  NELbdc = p_IboundaryCpIdx(ibdc+1)-p_IboundaryCpIdx(ibdc)
    
  ! In a first step, we figure out the elements on the boundary and their
  ! orientation. Allocate arrays that are large enough to hold
  ! even all elements on the boundary if necessary.
  allocate(Ielements(NELbdc), IelementOrientation(NELbdc))
  
  ! Allocate an array saving the start- and end-parameter values
  ! of the edges on the boundary.
  allocate(DedgePosition(2,NELbdc))

  ! Loop through the edges on the boundary component ibdc.
  ! If the edge is inside, remember the element number and figure out
  ! the orientation of the edge.
  ! NEL counts the total number of elements in the region.
  NEL = 0
  do iedge = 1,NELbdc
    if (boundary_isInRegion(rboundaryRegion, ibdc,&
        p_DedgeParameterValue(iedge))) then
      NEL = NEL + 1
      
      ! Element number
      Ielements(NEL) = p_IelementsAtBoundary(iedge)
      
      ! Element orientation; i.e. the local number of the boundary edge 
      do ilocaledge = 1,ubound(p_IedgesAtElement,1)
        if (p_IedgesAtElement(ilocaledge, p_IelementsAtBoundary(iedge)) .eq. &
            p_IedgesAtBoundary(iedge)) exit
      end do
      IelementOrientation(NEL) = ilocaledge
      
      ! Save the start parameter value of the edge -- in length
      ! parametrisation.
      dpar1 = boundary_convertParameter(rdiscretisation%p_rboundary, &
          ibdc, p_DvertexParameterValue(iedge), rboundaryRegion%cparType, &
          BDR_PAR_LENGTH)
      
      ! Save the end parameter value. Be careful: The last edge
      ! must be treated differently!
      if (iedge .ne. NELbdc) then
        dpar2 = boundary_convertParameter(rdiscretisation%p_rboundary, &
            ibdc, p_DvertexParameterValue(iedge+1), rboundaryRegion%cparType, &
            BDR_PAR_LENGTH)
        
      else
        dpar2 = boundary_dgetMaxParVal(&
          rdiscretisation%p_rboundary,ibdc,BDR_PAR_LENGTH)
      end if
      
      DedgePosition(1,NEL) = dpar1
      DedgePosition(2,NEL) = dpar2
      
    end if
  end do
  
  ! Get the parameter values of the 1D cubature formula
  ! as well as the number of cubature points ncubp
  call cub_getCubPoints(ccubType, ncubp, Dxi1D, Domega1D)

  ! Map the 1D cubature points to the edges in 2D.
  allocate(Dxi2D(ncubp,NDIM2D+1,NEL))
  if (rdiscretisation%ccomplexity .eq. SPDISC_UNIFORM) then
    
    ! All elements have the same type. Get the type of the
    ! corresponding coordinate system and transform the coordinates.
    icoordSystem = elem_igetCoordSystem(&
        p_RelementDistribution(1)%celement)
    do IEL = 1,NEL
      call trafo_mapCubPts1Dto2D(icoordSystem, IelementOrientation(IEL), &
          ncubp, Dxi1D, Dxi2D(:,:,IEL))
    end do
    
  else
    ! The type of the coordinate system may change with every element.
    ! So we may have to switch... celements in the discretisation
    ! structure informs us about the element type.
    call storage_getbase_int (rdiscretisation%h_IelementDistr, p_IelementDistr)

    do IEL = 1,NEL
      celement = p_RelementDistribution(p_IelementDistr(Ielements(IEL)))%celement
      icoordSystem = elem_igetCoordSystem(celement)
      call trafo_mapCubPts1Dto2D(icoordSystem, IelementOrientation(IEL), &
          ncubp, Dxi1D, Dxi2D(:,:,IEL))     
    end do
  end if
  
  ! Transpose the coordinate array such that we get coordinates
  ! we can work with.
  allocate(DpointsRef(NDIM2D+1,ncubp,NEL))
  do IEL = 1,NEL
    do i = 1,ncubp
      do k = 1,ubound(DpointsRef,1)
        DpointsRef(k,i,IEL) = Dxi2D(i,k,IEL)
      end do
    end do
  end do
  
  ! Dxi2D is not needed anymore.
  deallocate(Dxi2D)

  
  ! Allocate memory for the real coordinates of the points
  allocate(Dpoints(NDIM2D+1,ncubp,NEL))
  
  ! Allocate memory for the parameter values of the points
  allocate (DpointPar(ncubp, NEL))

  ! Calculate the parameter values of the points on the boundary
  do iel = 1,NEL
    do ipoint = 1,ncubp
      ! Dxi1D is in [-1,1] while the current edge has parmeter values
      ! [DedgePosition(1),DedgePosition(2)]. So do a linear
      ! transformation to transform Dxi1D into that interval, this 
      ! gives the parameter values in length parametrisation
      call mprim_linearRescale(Dxi1D(ipoint,1), -1.0_DP, 1.0_DP,&
          DedgePosition(1,iel), DedgePosition(2,iel), DpointPar(ipoint,iel))
    end do
  end do
  
  ! Check if discretisation is uniform - this would save a lot
  if (rdiscretisation%ccomplexity .eq. SPDISC_UNIFORM) then

    ! Get the number of local DOF's for trial and test functions
    indofTest = elem_igetNDofLoc(p_RelementDistribution(1)%celement)

    ! Get from the trial element space the type of coordinate system
    ! that is used there:
    ctrafoType = elem_igetTrafoType(p_RelementDistribution(1)%celement)
    
    ! Quickly check if one of the specified derivatives is out of the allowed range:
    do IALBET = 1,rform%itermcount
      IA = rform%Idescriptors(IALBET)
      if ((IA.lt.0) .or. &
          (IA .gt. elem_getMaxDerivative(p_RelementDistribution(1)%celement))) then
        call output_line('Specified test-derivative '//trim(sys_siL(IA,3))//' not available!',&
                         OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVecDbleBdr2d_conf')
        call sys_halt()
      end if
    end do
    
    ! Allocate arrays for the values of the test- and trial functions.
    allocate(DbasTest(indofTest, elem_getMaxDerivative(p_RelementDistribution(1)%celement),&
             ncubp, NEL))

    ! Allocate memory for the DOF's of all the elements.
    allocate(IdofsTest(indofTest, NEL))

    ! Allocate memory for the coefficients
    allocate(Dcoefficients(rform%itermCount, ncubp, NEL))
    
    ! Calculate the global DOF's into IdofsTest.
    !
    ! More exactly, we call dof_locGlobMapping_mult to calculate all the
    ! global DOF's of our NEL elements simultaneously.
    call dof_locGlobMapping_mult(rdiscretisation, Ielements, IdofsTest)
    
    ! -------------------- ELEMENT EVALUATION PHASE ----------------------
    
    ! Ok, we found the positions of the local vector entries
    ! that we have to change.
    ! To calculate the vector contributions, we have to evaluate
    ! the elements to give us the values of the basis functions
    ! in all the DOF's in all the elements in our set.

    ! Initialisation of the element set.
    call elprep_init(revalElementSet)
    
    ! Get the element evaluation tag of all FE spaces. We need it to evaluate
    ! the elements later. All of them can be combined with OR, what will give
    ! a combined evaluation tag. 
    cevaluationTag = elem_getEvaluationTag(p_RelementDistribution(1)%celement)
    
    ! Calculate the real coordinates; they are needed in the callback functionthere
    cevaluationTag = ior(cevaluationTag,EL_EVLTAG_REALPOINTS)

    ! Do NOT calculate the coordinates on the reference element; they are already there
    cevaluationTag = iand(cevaluationTag,not(EL_EVLTAG_REFPOINTS))
    
    ! Calculate all information that is necessary to evaluate the finite element
    ! on all cells of our subset. This includes the coordinates of the points
    ! on the cells.
    call elprep_prepareSetForEvaluation (revalElementSet,&
        cevaluationTag, p_rtriangulation, Ielements, &
        ctrafoType, DpointsRef=DpointsRef)
    
    ! Now it's time to call our coefficient function to calculate the
    ! function values in the cubature points:
    call domint_initIntegrationByEvalSet (revalElementSet, rintSubset)
    rintSubset%ielementDistribution = 1
    rintSubset%ielementStartIdx = 1
    rintSubset%p_Ielements => Ielements
    rintSubset%p_IdofsTrial => IdofsTest
    rintSubset%celement = p_RelementDistribution(1)%celement
        
    if (present(fcoeff_buildVectorScBdr2D_sim)) then
      call fcoeff_buildVectorScBdr2D_sim (rdiscretisation, rform, &
          NEL, ncubp, revalElementSet%p_DpointsReal(:,:,1:NEL), &
          rboundaryRegion%iboundCompIdx, DpointPar,&
          IdofsTest, rintSubset, &
          Dcoefficients(:,:,1:NEL), rcollection)
    else
      Dcoefficients = 1.0_DP
    end if
    
    ! Release the domain integration subset again
    call domint_doneIntegration(rintSubset)
    
    ! Calculate the values of the basis functions.
    call elem_generic_sim2 (p_RelementDistribution(1)%celement, &
        revalElementSet, Bder, DbasTest)

    ! --------------------- DOF COMBINATION PHASE ------------------------
    
    ! Values of all basis functions calculated. Now we can start 
    ! to integrate!
    !
    ! Loop through elements in the set and for each element,
    ! loop through the DOF's and cubature points to calculate the
    ! integral:
    
    do IEL = 1,NEL
      
      ! We make a 'local' approach, i.e. we calculate the values of the
      ! integral into the vector DlocalData and add them later into
      ! the large solution vector.
      
      ! Clear the output vector.
      DlocalData(1:indofTest) = 0.0_DP
      
      ! Get the length of the edge. Let's use the parameter values
      ! on the boundary for that purpose; this is a more general
      ! implementation than using simple lines as it will later 
      ! support isoparametric elements.
      !
      ! The length of the current edge serves as a "determinant"
      ! in the cubature, so we have to divide it by 2 as an edge on 
      ! the unit inverval [-1,1] has length 2.
      dlen = 0.5_DP*(DedgePosition(2,IEL)-DedgePosition(1,IEL))

      ! Loop over all cubature points on the current element
      do ICUBP = 1, ncubp
        
        ! calculate the current weighting factor in the cubature formula
        ! in that cubature point.      
        
        OM = dlen * Domega1D(ICUBP)
        
        ! Loop over the additive factors in the linear form.
        do IALBET = 1,rform%itermcount
          
          ! Get from Idescriptors the type of the derivatives for the 
          ! test and trial functions. The summand we calculate
          ! here will be:
          !
          ! int_...  f * ( phi_i )_IA
          !
          ! -> IA=0: function value, 
          !      =1: first derivative, 
          !      =2: 2nd derivative,...
          !    as defined in the module 'derivative'.
          
          IA = rform%Idescriptors(IALBET)
          
          ! Multiply OM with the coefficient of the form.
          ! This gives the actual value to multiply the
          ! function value with before summing up to the integral.
          ! Get the precalculated coefficient from the coefficient array.
          AUX = OM * Dcoefficients(IALBET,ICUBP,IEL)
          
          ! Now loop through all possible combinations of DOF's
          ! in the current cubature point. 
          
          do IDOFE = 1,indofTest
            
            ! Get the value of the basis function 
            ! phi_o in the cubature point. 
            ! Them multiply:
            !    DBAS(..) * AUX
            ! ~= phi_i * coefficient * cub.weight
            ! Summing this up gives the integral, so the contribution
            ! to the vector. 
            !
            ! Simply summing up DBAS(..) * AUX would give
            ! the additive contribution for the vector. We save this
            ! contribution in the local array.
            
            DlocalData(IDOFE) = DlocalData(IDOFE)+DbasTest(IDOFE,IA,ICUBP,IEL)*AUX
            
          end do ! IDOFE
          
        end do ! IALBET
        
      end do ! ICUBP 
      
      ! Incorporate the local vector into the global one.
      ! The 'local' DOF 1..indofTest is mapped to the global DOF using
      ! the IdofsTest array.
      do IDOFE = 1,indofTest
        p_Ddata(IdofsTest(IDOFE,IEL)) = p_Ddata(IdofsTest(IDOFE,IEL)) + DlocalData(IDOFE)
      end do
      
    end do ! IEL

  else

    ! For nonuniform case
    print *, "NOT IMPLEMENTED YET"
    stop

  end if

  end subroutine linf_buildVecDbleBdr2d_conf

  !****************************************************************************

!<subroutine>

  subroutine linf_initAssembly(rvectorAssembly,rform,&
      celement,ccubType,nelementsPerBlock)

!<description>
  ! Initialise a vector assembly structure for assembling a linear form.
!</description>

!<input>
  ! The bilinear form specifying the underlying PDE of the discretisation.
  type(t_linearForm), intent(in) :: rform
  
  ! Type of element in the test space.
  integer(I32), intent(in) :: celement
  
  ! Type of cubature formula to use.
  integer(I32), intent(in) :: ccubType
  
  ! Optional: Maximum number of elements to process simultaneously.
  ! If not specified, BILF_NELEMSIM is assumed.
  integer, intent(in), optional :: nelementsPerBlock
!</input>

!<output>
  ! A vector assembly structure.
  type(t_linfVectorAssembly), intent(out) :: rvectorAssembly
!</output>

!</subroutine>
  
    ! local variables
    integer :: i,i1
  
    ! Initialise the structure.
    rvectorAssembly%rform = rform
    rvectorAssembly%ccubType = ccubType
    rvectorAssembly%nelementsPerBlock = LINF_NELEMSIM
    if (present(nelementsPerBlock)) &
        rvectorAssembly%nelementsPerBlock = nelementsPerBlock
    rvectorAssembly%celement = celement
    
    ! Get the number of local DOF's for trial and test functions
    rvectorAssembly%indof = elem_igetNDofLoc(celement)
    
    ! Which derivatives of basis functions are needed?
    ! Check the descriptors of the bilinear form and set BDERxxxx
    ! according to these.
    rvectorAssembly%Bder(:) = .false.
    
    ! Loop through the additive terms
    do i=1,rform%itermCount
      ! The desriptor Idescriptors gives directly the derivative
      ! which is to be computed! Build template's for BDER.
      ! We don't compute the actual BDER here, as there might be some special
      ! processing if trial/test functions are identical!
      !
      ! At first build the descriptors for the trial functions
      I1=rform%Idescriptors(i)
      
      if ((I1 .le.0) .or. (I1 .gt. DER_MAXNDER)) then
        call output_line ('Invalid descriptor!',&
            OU_CLASS_ERROR,OU_MODE_STD,'linf_initAssembly')
        call sys_halt()
      endif
      
      rvectorAssembly%Bder(I1)=.true.
    end do

    ! Get the number of vertices of the element, specifying the transformation
    ! form the reference to the real element.
    rvectorAssembly%NVE = elem_igetNVE(celement)
    
      ! Get from the element space the type of coordinate system
    ! that is used there:
    rvectorAssembly%ctrafoType = elem_igetTrafoType(celement)
    
    ! Get the number of cubature points for the cubature formula
    rvectorAssembly%ncubp = cub_igetNumPts(ccubType)

    ! Allocate two arrays for the points and the weights
    allocate(rvectorAssembly%p_Domega(rvectorAssembly%ncubp))
    allocate(rvectorAssembly%p_DcubPtsRef(&
        trafo_igetReferenceDimension(rvectorAssembly%ctrafoType),&
        rvectorAssembly%ncubp))
    
    ! Get the cubature formula
    call cub_getCubature(ccubType,rvectorAssembly%p_DcubPtsRef,rvectorAssembly%p_Domega)

    ! Get the element evaluation tag of all FE spaces. We need it to evaluate
    ! the elements later. All of them can be combined with OR, what will give
    ! a combined evaluation tag. 
    rvectorAssembly%cevaluationTag = elem_getEvaluationTag(rvectorAssembly%celement)
        
  end subroutine
  
  !****************************************************************************

!<subroutine>
  
  subroutine linf_doneAssembly(rvectorAssembly)

!<description>
  ! Clean up a vector assembly structure.
!</description>  

!<inputoutput>
  ! Matrix assembly structure to clean up
  type(t_linfVectorAssembly), intent(inout) :: rvectorAssembly
!</inputoutput>  

!</subroutine>
  
    deallocate(rvectorAssembly%p_DcubPtsRef)
    deallocate(rvectorAssembly%p_Domega)
  
  end subroutine

  !****************************************************************************

!<subroutine>

  subroutine linf_allocAssemblyData(rvectorAssembly)

!<description>
  ! Auxiliary subroutine. Allocate 'local' memory, needed for assembling vector entries.
!</description>

!<inputoutput>
  ! A vector assembly structure.
  type(t_linfVectorAssembly), intent(inout) :: rvectorAssembly
!</inputoutput>

!</subroutine>

    ! Evaluate real coordinates.
    rvectorAssembly%cevaluationTag = &
        ior(rvectorAssembly%cevaluationTag,EL_EVLTAG_REALPOINTS)
    
    ! Allocate an array for the coefficients computed by the callback routine.
    allocate(rvectorAssembly%p_Dcoefficients(rvectorAssembly%rform%itermCount,&
        rvectorAssembly%ncubp,rvectorAssembly%nelementsPerBlock))

    ! Allocate arrays for the values of the test functions.
    allocate(rvectorAssembly%p_Dbas(rvectorAssembly%indof,&
             elem_getMaxDerivative(rvectorAssembly%celement),&
             rvectorAssembly%ncubp,rvectorAssembly%nelementsPerBlock))

    ! Allocate memory for the DOF's of all the elements.
    allocate(rvectorAssembly%p_Idofs(&
        rvectorAssembly%indof,rvectorAssembly%nelementsPerBlock))

    ! Initialisation of the element set.
    call elprep_init(rvectorAssembly%revalElementSet)
  
    ! No cubature points initalised up to now.
    rvectorAssembly%iinitialisedElements = 0
  
  end subroutine
  
  !****************************************************************************
  
!<subroutine>
  
  subroutine linf_releaseAssemblyData(rvectorAssembly)

  ! Auxiliary subroutine. Release 'local' memory.

!<inputoutput>
  ! Vector assembly structure to clean up
  type(t_linfVectorAssembly), intent(inout) :: rvectorAssembly
!</inputoutput>

!</subroutine>
  
    ! Release all information in the structure.
    call elprep_releaseElementSet(rvectorAssembly%revalElementSet)

    deallocate(rvectorAssembly%p_Dcoefficients)
    deallocate(rvectorAssembly%p_Idofs)
    deallocate(rvectorAssembly%p_Dbas)

  end subroutine
  
  !****************************************************************************
  
!<subroutine>  
  
  subroutine linf_assembleSubvector (rvectorAssembly,rvector,IelementList,&
      fcoeff_buildVectorSc_sim,rcollection)
  
!<inputoutput>
  
  ! A vector assembly structure prepared with bilf_initAssembly.
  type(t_linfVectorAssembly), intent(inout), target :: rvectorAssembly
  
  ! A vector where to assemble the contributions to.
  type(t_vectorScalar), intent(inout) :: rvector
  
!</inputoutput>
  
!<input>
  
  ! List of elements where to assemble the bilinear form.
  integer, dimension(:), intent(in), target :: IelementList
  
  ! A callback routine which is able to calculate the values of the
  ! function $f$ which is to be discretised.
  include 'intf_coefficientVectorSc.inc'
  optional :: fcoeff_buildVectorSc_sim

  ! OPTIONAL: A pointer to a collection structure. This structure is given to the
  ! callback function for nonconstant coefficients to provide additional
  ! information. 
  type(t_collection), intent(INOUT), target, optional :: rcollection
  
!</input>
  
!</subroutine>
  
    ! local variables, used by all processors
    real(DP), dimension(:), pointer :: p_Ddata
    integer :: indof,ncubp
    
    ! local data of every processor when using OpenMP
    integer :: ielset,ielmax
    integer :: iel,icubp,ialbet,ia,idofe
    real(DP) :: domega,daux
    integer(I32) :: cevaluationTag
    type(t_linfVectorAssembly), target :: rlocalVectorAssembly
    type(t_domainIntSubset) :: rintSubset
    real(DP), dimension(:,:), pointer :: p_Ddetj
    real(DP), dimension(:), pointer :: p_Domega
    real(DP), dimension(:,:,:,:), pointer :: p_Dbas
    real(DP), dimension(:,:,:), pointer :: p_Dcoefficients
    integer, dimension(:),pointer :: p_Idescriptors
    integer, dimension(:,:), pointer :: p_Idofs
    type(t_evalElementSet), pointer :: p_revalElementSet

    ! A small vector holding only the additive controbutions of
    ! one element
    real(DP), dimension(EL_MAXNBAS) :: DlocalData
  
    ! Get some pointers for faster access
    call lsyssc_getbase_double (rvector,p_Ddata)
    indof = rvectorAssembly%indof
    ncubp = rvectorAssembly%ncubp

    ! Copy the assembly data to the local assembly data,
    ! where we can allocate memory.
    ! For single processor machines, this is actually boring and nonsense.
    ! But using OpenMP, here we get a local copy of the vector
    ! assembly structure to where we can add some local data which
    ! is released upon return without changing the original assembly
    ! stucture or disturbing the data of the other processors.
    rlocalVectorAssembly = rvectorAssembly
    call linf_allocAssemblyData(rlocalVectorAssembly)
    
    ! Get some more pointers to local data.
    p_Domega => rlocalVectorAssembly%p_Domega
    p_Dbas => rlocalVectorAssembly%p_Dbas
    p_Dcoefficients => rlocalVectorAssembly%p_Dcoefficients
    p_Idescriptors => rlocalVectorAssembly%rform%Idescriptors
    p_Idofs => rlocalVectorAssembly%p_Idofs
    p_revalElementSet => rlocalVectorAssembly%revalElementSet
        
    ! Loop over the elements - blockwise.
    !
    ! Open-MP-Extension: Each loop cycle is executed in a different thread,
    ! so nelementsPerBlock local matrices are simultaneously calculated in the
    ! inner loop(s).
    ! The blocks have all the same size, so we can use static scheduling.
    !
    !%OMP do schedule(static,1)
    do ielset = 1, size(IelementList), rlocalVectorAssembly%nelementsPerBlock
    
      ! We always handle nelementsPerBlock elements simultaneously.
      ! How many elements have we actually here?
      ! Get the maximum element number, such that we handle at most BILF_NELEMSIM
      ! elements simultaneously.
      
      ielmax = min(size(IelementList),ielset-1+rlocalVectorAssembly%nelementsPerBlock)
    
      ! --------------------- DOF SEARCH PHASE ------------------------
    
      ! The outstanding feature with finite elements is: A basis
      ! function for a DOF on one element has common support only
      ! with the DOF's on the same element! E.g. for Q1:
      !
      !        #. . .#. . .#. . .#
      !        .     .     .     .
      !        .  *  .  *  .  *  .
      !        #-----O-----O. . .#
      !        |     |     |     .
      !        |     | iel |  *  .
      !        #-----X-----O. . .#
      !        |     |     |     .
      !        |     |     |  *  .
      !        #-----#-----#. . .#
      !
      ! --> On element iel, the basis function at "X" only interacts
      !     with the basis functions in "O". Elements in the 
      !     neighbourhood ("*") have no support, therefore we only have
      !     to collect all "O" DOF's.
      !
      ! Calculate the global DOF's into IdofsTrial / IdofsTest.
      !
      ! More exactly, we call dof_locGlobMapping_mult to calculate all the
      ! global DOF's of our BILF_NELEMSIM elements simultaneously.
      call dof_locGlobMapping_mult(rvector%p_rspatialDiscr, &
          IelementList(ielset:ielmax), p_Idofs)
                                   
      ! -------------------- ELEMENT EVALUATION PHASE ----------------------
      
      ! To calculate the element contributions, we have to evaluate
      ! the elements to give us the values of the basis functions
      ! in all the DOF's in all the elements in our set.

      ! Get the element evaluation tag of all FE spaces. We need it to evaluate
      ! the elements later. All of them can be combined with OR, what will give
      ! a combined evaluation tag. 
      cevaluationTag = rlocalVectorAssembly%cevaluationTag
      
      ! In the first loop, calculate the coordinates on the reference element.
      ! In all later loops, use the precalculated information.
      !
      ! If the cubature points are already initialised, don't do it again.
      ! We check this by taking a look to iinitialisedElements which
      ! gives the current maximum of initialised elements.
      if (ielmax .gt. rlocalVectorAssembly%iinitialisedElements) then

        ! (Re-)initialise!
        cevaluationTag = ior(cevaluationTag,EL_EVLTAG_REFPOINTS)

        ! Remember the new number of initialised elements
        rlocalVectorAssembly%iinitialisedElements = ielmax

      else
        ! No need.
        cevaluationTag = iand(cevaluationTag,not(EL_EVLTAG_REFPOINTS))
      end if

      ! Calculate all information that is necessary to evaluate the finite element
      ! on all cells of our subset. This includes the coordinates of the points
      ! on the cells.
      call elprep_prepareSetForEvaluation (p_revalElementSet,&
          cevaluationTag, rvector%p_rspatialDiscr%p_rtriangulation, &
          IelementList(ielset:ielmax), rlocalVectorAssembly%ctrafoType, &
          rlocalVectorAssembly%p_DcubPtsRef(:,1:ncubp))
      p_Ddetj => p_revalElementSet%p_Ddetj
      
      ! Now it's time to call our coefficient function to calculate the
      ! function values in the cubature points:
      if (present(fcoeff_buildVectorSc_sim)) then
        call domint_initIntegrationByEvalSet (p_revalElementSet,rintSubset)
        rintSubset%ielementDistribution = 0
        rintSubset%ielementStartIdx = ielset
        rintSubset%p_Ielements => IelementList(ielset:ielmax)
        rintSubset%p_IdofsTrial => p_Idofs
        rintSubset%celement = rlocalVectorAssembly%celement
        call fcoeff_buildVectorSc_sim (rvector%p_rspatialDiscr,rlocalVectorAssembly%rform, &
            ielmax-ielset+1,ncubp,&
            p_revalElementSet%p_DpointsReal(:,:,1:ielmax-ielset+1),&
            p_Idofs,rintSubset, &
                  p_Dcoefficients(:,:,1:ielmax-ielset+1),&
                  rcollection)
        call domint_doneIntegration (rintSubset)
      else
        p_Dcoefficients(:,:,1:IELmax-IELset+1) = 1.0_DP
      end if
      
      ! Calculate the values of the basis functions.
      call elem_generic_sim2 (rlocalVectorAssembly%celement, &
          p_revalElementSet, rlocalVectorAssembly%Bder, &
          rlocalVectorAssembly%p_Dbas)
      
      ! --------------------- DOF COMBINATION PHASE ------------------------
      
      ! Values of all basis functions calculated. Now we can start 
      ! to integrate!
      !
      ! Loop through elements in the set and for each element,
      ! loop through the DOF's and cubature points to calculate the
      ! integral:

      do iel=1,ielmax-ielset+1
        
        ! We make a 'local' approach, i.e. we calculate the values of the
        ! integral into the vector DlocalData and add them later into
        ! the large solution vector.
        
        ! Clear the output vector.
        DlocalData(1:indof) = 0.0_DP

        ! Loop over all cubature points on the current element
        do icubp = 1, ncubp

          ! calculate the current weighting factor in the cubature formula
          ! in that cubature point.
          !
          ! Take the absolut value of the determinant of the mapping.
          ! In 2D, the determinant is always positive, whereas in 3D,
          ! the determinant might be negative -- that's normal!

          domega = p_Domega(icubp)*abs(p_Ddetj(icubp,iel))

          ! Loop over the additive factors in the bilinear form.
          do ialbet = 1,rlocalVectorAssembly%rform%itermcount
          
            ! Get from Idescriptors the type of the derivatives for the 
            ! test and trial functions. The summand we calculate
            ! here will be:
            !
            ! int_...  f * ( phi_i )_IA
            !
            ! -> IA=0: function value, 
            !      =1: first derivative, 
            !      =2: 2nd derivative,...
            !    as defined in the module 'derivative'.
            
            ia = p_Idescriptors(ialbet)
            
            ! Multiply domega with the coefficient of the form.
            ! This gives the actual value to multiply the
            ! function value with before summing up to the integral.
            ! Get the precalculated coefficient from the coefficient array.
            daux = domega * p_Dcoefficients(ialbet,icubp,iel)
          
            ! Now loop through all possible combinations of DOF's
            ! in the current cubature point. 

            do idofe=1,indof
              
              ! Get the value of the basis function 
              ! phi_o in the cubature point. 
              ! Them multiply:
              !    DBAS(..) * AUX
              ! ~= phi_i * coefficient * cub.weight
              ! Summing this up gives the integral, so the contribution
              ! to the vector. 
              !
              ! Simply summing up DBAS(..) * AUX would give
              ! the additive contribution for the vector. We save this
              ! contribution in the local array.
              
              DlocalData(idofe) = DlocalData(idofe)+p_Dbas(idofe,ia,icubp,iel)*daux
              
            end do ! jdofe
            
          end do ! ialbet

        end do ! icubp 
        
        ! Incorporate the local vector into the global one.
        ! The 'local' DOF 1..indofTest is mapped to the global DOF using
        ! the IdofsTest array.
        do IDOFE=1,indof
          p_Ddata(p_Idofs(idofe,iel)) = p_Ddata(p_Idofs(idofe,iel)) + DlocalData(idofe)
        end do

      end do ! iel

    end do ! ielset
    
    ! Release the local vector assembly structure
    call linf_releaseAssemblyData(rlocalVectorAssembly)
  
  end subroutine

  !****************************************************************************

!<subroutine>

  subroutine linf_buildVectorScalar2 (rdiscretisation, rform, bclear, rvectorScalar,&
                                      fcoeff_buildVectorSc_sim, rcollection)
  
!<description>
  ! This routine assembles the entries of a vector according to a linear form
  ! (typically used for assembling RHS vectors).
  !
  ! If bclear=TRUE, the vector is cleared before the assembly and any 
  ! sorting of the entries is switched off - the vector is set up unsorted.
  !
  ! If bclear=FALSE, the vector must be unsorted when this routine is called, 
  ! otherwise an error is thrown.
  !
  ! IMPLEMENTATIONAL REMARK:
  ! This is a new implementation of the vector assembly using element subsets.
  ! In contrast to bilf_buildMatrixScalar, this routine loops itself about
  ! the element subsets and calls linf_initAssembly/
  ! linf_assembleSubvector/linf_doneAssembly to assemble subvectors.
  ! The linf_assembleSubvector interface allows to assemble parts of a
  ! vector based on an arbitrary element list which is not bound to an
  ! element distribution.
!</description>

!<input>
  ! The underlying discretisation structure which is to be used to
  ! create the vector.
  type(t_spatialDiscretisation), intent(IN), target :: rdiscretisation
  
  ! The linear form specifying the underlying PDE of the discretisation.
  type(t_linearForm), intent(IN) :: rform
  
  ! Whether to clear the vector before calculating the entries.
  ! If .FALSE., the new entries are added to the existing entries.
  logical, intent(IN) :: bclear
  
  ! OPTIONAL: A collection structure. This structure is 
  ! given to the callback function for calculating the function
  ! which should be discretised in the linear form.
  type(t_collection), intent(INOUT), target, optional :: rcollection
  
  ! A callback routine for the function to be discretised.
  include 'intf_coefficientVectorSc.inc'
  optional :: fcoeff_buildVectorSc_sim
!</input>

!<inputoutput>
  ! The FE vector. Calculated entries are imposed to this vector.
  type(t_vectorScalar), intent(INOUT) :: rvectorScalar
!</inputoutput>

!</subroutine>

  ! local variables
  type(t_linfVectorAssembly) :: rvectorAssembly
  integer :: ielementDistr
  integer, dimension(:), pointer :: p_IelementList

  ! If the vector does not exist, create it.
  if (rvectorScalar%h_Ddata .eq. ST_NOHANDLE) then  
    call lsyssc_createVecByDiscr (rdiscretisation,rvectorScalar,bclear)
  else
    ! Otherwise, probably clear the vector.
    if (bclear) then
      call lsyssc_clearVector (rvectorScalar)

      ! If the vector is not set up as new vector, it has to be unsorted.
      ! If it's a new vector, we switch off the sorting.
      rvectorScalar%isortStrategy = -abs(rvectorScalar%isortStrategy)
    end if
  end if

  ! The vector must be unsorted, otherwise we can't set up the vector.
  if (rvectorScalar%isortStrategy .gt. 0) then
    call output_line('Vector must be unsorted!',&
                     OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalar')
    call sys_halt()
  end if

  ! Do we have a uniform triangulation? Would simplify a lot...
  if ((rdiscretisation%ccomplexity .eq. SPDISC_UNIFORM) .or.&
      (rdiscretisation%ccomplexity .eq. SPDISC_CONFORMAL)) then 
    
    select case(rvectorScalar%cdataType)
      
    case(ST_DOUBLE)
      ! Loop over the element distributions.
      do ielementDistr = 1,rvectorScalar%p_rspatialDiscr%inumFESpaces
        call storage_getbase_int(&
            rvectorScalar%p_rspatialDiscr%RelementDistr(ielementDistr)%h_IelementList,&
            p_IelementList)

        ! Initialise a vector assembly structure for that element distribution
        call linf_initAssembly(rvectorAssembly,rform,&
            rvectorScalar%p_rspatialDiscr%RelementDistr(ielementDistr)%celement,&
            rvectorScalar%p_rspatialDiscr%RelementDistr(ielementDistr)%ccubTypeLinForm,&
            min(LINF_NELEMSIM,size(p_IelementList)))
            
        ! Assemble the data for all elements in this element distribution
        call linf_assembleSubvector (rvectorAssembly,rvectorScalar,&
            p_IelementList,fcoeff_buildVectorSc_sim,rcollection)
        
        ! Release the assembly structure.
        call linf_doneAssembly(rvectorAssembly)
      end do

    case DEFAULT
      call output_line('Single precision vectors currently not supported!',&
                       OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalar')
    end select
    
  else
    call output_line('General discretisation not implemented!',&
                     OU_CLASS_ERROR,OU_MODE_STD,'linf_buildVectorScalar')
    call sys_halt()
  end if

  end subroutine  

end module linearformevaluation
