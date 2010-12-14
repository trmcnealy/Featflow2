!##############################################################################
!# ****************************************************************************
!# <name> heatcond_method2 </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module is a demonstation program how to solve a simple heat conduction
!# problem with constant coefficients on a simple domain.
!#
!# The head conduction equation solved in this module is the simplest at all:
!#
!#    d/dt u  - Laplace u  =  f
!#
!# With the RHS f and the boundary conditions being constant in time.
!# The equation is discretised in time by implicit Euler, prividing the
!# following discrete equation:
!#
!#    (1/dt M  +  L) u_{n+1}  =  f  +  1/dt M u_n
!#
!# with M=Mass matrix, L=-Laplace, dt=time step size.
!#
!# The whole solution process is implemented into one routine, using a standard
!# linear solver (not multigrid) for solving the linear subproblems in every
!# timestep. The time domain is [0,T] and discretised by a simple implicit
!# Euler.
!#
!# The module is an extension of the standard poisson solver.
!# Right hand side and boundary conditions are precomputed and kept constant
!# over time to reduce computational time.
!# </purpose>
!##############################################################################

module heatcond_method2

  use fsystem
  use genoutput
  use storage
  use boundary
  use cubature
  use derivatives
  use matrixfilters
  use vectorfilters
  use discretebc
  use bcassembly
  use sortstrategy
  use triangulation
  use element
  use spatialdiscretisation
  use coarsegridcorrection
  use filtersupport
  use linearsystemscalar
  use linearsystemblock
  use scalarpde
  use bilinearformevaluation
  use linearformevaluation
  use linearsolver
  use discretebc
  use ucd
    
  use heatcond_callback
  
  implicit none

contains

  ! ***************************************************************************

!<subroutine>

  subroutine heatcond2
  
!<description>
  ! This is an all-in-one poisson solver for directly solving a Poisson
  ! problem without making use of special features like collections
  ! and so on. The routine performs the following tasks:
  !
  !  1.) Read in parametrisation
  !  2.) Read in triangulation
  !  3.) Set up boundary conditions
  !  4.) Set up matrices
  !  5.) Set up RHS
  !  6.) Create solver structure
  !  7.) Loop over all timesteps
  !  8.)  Solve the problem
  !  9.)  Write solution to GMV file
  ! 10.) Release all variables, finish
!</description>

!</subroutine>

    ! Definitions of variables.
    !
    ! We need a couple of variables for this problem. Let us see...
    !
    ! An object for saving the domain:
    type(t_boundary) :: rboundary
    
    ! An object for saving the triangulation on the domain
    type(t_triangulation) :: rtriangulation

    ! Path to the mesh
    character(len=SYS_STRLEN) :: spredir

    ! An object specifying the discretisation.
    ! This contains also information about trial/test functions,...
    type(t_blockDiscretisation) :: rdiscretisation
    
    ! A bilinear and linear form describing the analytic problem to solve
    type(t_bilinearForm) :: rform
    type(t_linearForm) :: rlinform
    
    ! A scalar mass matrix, Laplace matrix, temporary matrix and
    ! a vector. The vector accepts the RHS of the problem in scalar form.
    type(t_matrixScalar) :: rmatrixLaplace, rmatrixMass, rmatrix
    type(t_vectorScalar) :: rrhs

    ! A block matrix and a couple of block vectors. These will be filled
    ! with data for the linear solver.
    type(t_matrixBlock) :: rmatrixBlock,rmatrixMassBlock
    type(t_vectorBlock) :: rvectorBlock,rrhsBlock,rtempBlock,rtimeRhsBlock

    ! A set of variables describing the analytic and discrete boundary
    ! conditions.    
    type(t_boundaryRegion) :: rboundaryRegion
    type(t_discreteBC), target :: rdiscreteBC

    ! A solver node that accepts parameters for the linear solver    
    type(t_linsolNode), pointer :: p_rsolverNode,p_rpreconditioner

    ! An array for the system matrix(matrices) during the initialisation of
    ! the linear solver.
    type(t_matrixBlock), dimension(1) :: Rmatrices

    ! A filter chain that describes how to filter the matrix/vector
    ! before/during the solution process. The filters usually implement
    ! boundary conditions.
    type(t_filterChain), dimension(1), target :: RfilterChain
    
    ! NLMAX receives the level where we want to solve.
    integer :: NLMAX
    
    ! Time step size, number of timesteps.
    real(DP) :: dtstep
    integer :: ntimesteps
    
    ! Error indicator during initialisation of the solver
    integer :: ierror    
    
    ! Time and time step counter
    real(DP) :: dtime
    integer :: itimestep
    
    ! Output block for UCD output to GMV file
    type(t_ucdExport) :: rexport
    character(len=SYS_STRLEN) :: sucddir
    real(DP), dimension(:), pointer :: p_Ddata

    ! Ok, let us start. 
    !
    ! We want to solve our heat equation problem on level...
    NLMAX = 6
    
    ! Initialise time step size and number of timesteps
    dtstep = 0.01_DP
    ntimesteps = 10

    ! We start at time 0.0.
    dtime = 0.0_DP
    
    ! Get the path $PREDIR from the environment, where to read .prm/.tri files 
    ! from. If that does not exist, write to the directory "./pre".
    if (.not. sys_getenv_string("PREDIR", spredir)) spredir = './pre'

    ! At first, read in the parametrisation of the boundary and save
    ! it to rboundary.
    call boundary_read_prm(rboundary, trim(spredir)//'/QUAD.prm')
        
    ! Now read in the basic triangulation.
    call tria_readTriFile2D (rtriangulation, trim(spredir)//'/QUAD.tri', rboundary)
    
    ! Refine it.
    call tria_quickRefine2LevelOrdering (NLMAX-1,rtriangulation,rboundary)
    
    ! And create information about adjacencies and everything one needs from
    ! a triangulation.
    call tria_initStandardMeshFromRaw (rtriangulation,rboundary)
    
    ! Now we can start to initialise the discretisation. At first, set up
    ! a block discretisation structure that specifies the blocks in the
    ! solution vector. In this simple problem, we only have one block.
    call spdiscr_initBlockDiscr (rdiscretisation,1,&
                                 rtriangulation, rboundary)
    
    ! rdiscretisation%Rdiscretisations is a list of scalar discretisation
    ! structures for every component of the solution vector.
    ! Initialise the first element of the list to specify the element
    ! and cubature rule for this solution component:
    call spdiscr_initDiscr_simple (rdiscretisation%RspatialDiscr(1), &
                                   EL_E011,CUB_TRZ,rtriangulation, rboundary)
                                   !CUB_G2X2

    ! Up to now, everything is 'analytical'.
    ! Let us change that, let us start to discretise!
    !
    ! 1.) Boundary conditions
    !
    ! For implementing boundary conditions, we use a `filter technique with
    ! discretised boundary conditions`. This means, we first have to calculate
    ! a discrete version of the analytic BC, which we can implement into the
    ! solution/RHS vectors using the corresponding filter.
    !
    ! Create a t_discreteBC structure where we store all discretised boundary
    ! conditions.
    call bcasm_initDiscreteBC(rdiscreteBC)
    !
    ! We 'know' already (from the problem definition) that we have four boundary
    ! segments in the domain. Each of these, we want to use for enforcing
    ! some kind of boundary condition.
    !
    ! We ask the bondary routines to create a 'boundary region' - which is
    ! simply a part of the boundary corresponding to a boundary segment.
    ! A boundary region roughly contains the type, the min/max parameter value
    ! and whether the endpoints are inside the region or not.
    call boundary_createRegion(rboundary,1,1,rboundaryRegion)
    
    ! We use this boundary region and specify that we want to have Dirichlet
    ! boundary there. The following call does the following:
    ! - Create Dirichlet boundary conditions on the region rboundaryRegion.
    !   We specify icomponent='1' to indicate that we set up the
    !   Dirichlet BC`s for the first (here: one and only) component in the 
    !   solution vector.
    ! - Discretise the boundary condition so that the BC`s can be applied
    !   to matrices and vectors
    ! - Add the calculated discrete BC`s to rdiscreteBC for later use.
    call bcasm_newDirichletBConRealBD (rdiscretisation,1,&
                                      rboundaryRegion,rdiscreteBC,&
                                      getBoundaryValues)
                              
    ! Now to the edge 2 of boundary component 1 the domain.
    call boundary_createRegion(rboundary,1,2,rboundaryRegion)
    call bcasm_newDirichletBConRealBD (rdiscretisation,1,&
                                      rboundaryRegion,rdiscreteBC,&
                                      getBoundaryValues)
                              
    ! Edge 3 of boundary component 1.
    call boundary_createRegion(rboundary,1,3,rboundaryRegion)
    call bcasm_newDirichletBConRealBD (rdiscretisation,1,&
                                      rboundaryRegion,rdiscreteBC,&
                                      getBoundaryValues)
    
    ! Edge 4 of boundary component 1. That is it.
    call boundary_createRegion(rboundary,1,4,rboundaryRegion)
    call bcasm_newDirichletBConRealBD (rdiscretisation,1,&
                                      rboundaryRegion,rdiscreteBC,&
                                      getBoundaryValues)

    ! 2.) Matrices
    !
    ! At first: create the structure of the system matrix which is to solve.
    ! We create a scalar matrix, based on the discretisation structure
    ! for our one and only solution component.
    call bilf_createMatrixStructure (rdiscretisation%RspatialDiscr(1),&
                                     LSYSSC_MATRIX9,rmatrix)
                                     
    ! For the time dependent problem, we need a Laplace matrix and a
    ! Mass matrix. Both have exactly the same structure as rmatrix, but they
    ! have different entries!
    ! We 'copy' the structure of rmatrix to the Mass and Laplace matrix in that
    ! sense, that they 'share' their structure with rmatrix. This means, all
    ! three matrices rmatrix, rmatrixMass and rmatrixLaplace have exactly
    ! the same structure. The arrays in memory defining that structure is
    ! shared among the matrices. This helps to save memory!
    call lsyssc_duplicateMatrix (rmatrix,rmatrixLaplace,&
        LSYSSC_DUP_SHARE,LSYSSC_DUP_IGNORE)

    call lsyssc_duplicateMatrix (rmatrix,rmatrixMass,&
        LSYSSC_DUP_SHARE,LSYSSC_DUP_IGNORE)
        
    ! Now to the entries of the Laplace matrix. For assembling of the entries,
    ! we need a bilinear form, which first has to be set up manually.
    ! We specify the bilinear form (grad Psi_j, grad Phi_i) for the
    ! scalar system matrix in 2D.
    rform%itermCount = 2
    rform%Idescriptors(1,1) = DER_DERIV_X
    rform%Idescriptors(2,1) = DER_DERIV_X
    rform%Idescriptors(1,2) = DER_DERIV_Y
    rform%Idescriptors(2,2) = DER_DERIV_Y

    ! In the standard case, we have constant coefficients:
    rform%ballCoeffConstant = .true.
    rform%BconstantCoeff = .true.
    rform%Dcoefficients(1)  = 1.0 
    rform%Dcoefficients(2)  = 1.0 

    ! Now we can build the matrix entries.
    ! By specifying ballCoeffConstant = BconstantCoeff = .FALSE. above,
    ! the framework will use constant coefficients.
    call bilf_buildMatrixScalar (rform,.true.,rmatrixLaplace)
    
    ! The same way, we create a mass matrix.
    ! We specify the bilinear form (Psi_j, Phi_i) for the
    ! scalar system matrix in 2D.
    
    rform%itermCount = 1
    rform%Idescriptors(1,1) = DER_FUNC
    rform%Idescriptors(2,1) = DER_FUNC

    ! In the standard case, we have constant coefficients:
    rform%ballCoeffConstant = .true.
    rform%BconstantCoeff = .true.
    rform%Dcoefficients(1)  = 1.0 
    rform%Dcoefficients(2)  = 1.0 

    ! Build the entries.
    call bilf_buildMatrixScalar (rform,.true.,rmatrixMass)

    ! Allocate memory for a temporary matrix. 
    call lsyssc_allocEmptyMatrix(rmatrix,LSYSSC_SETM_ZERO)
    
    ! From the temp matrix and from the mass matrix, we derive 'block' versions.
    ! These are 1x1 block matrices that share their data with the mass matrix
    ! and the temporary matrix, respectively. This helps to deal more easily with
    ! the linear solver later.
    call lsysbl_createMatFromScalar (rmatrix,rmatrixBlock,rdiscretisation)
    call lsysbl_createMatFromScalar (rmatrixMass,rmatrixMassBlock,rdiscretisation)
    
    ! Hang the pointer of the boudnary conditions into the matrix. That way, these
    ! boundary conditions are always connected to that matrix.
    rmatrixBlock%p_rdiscreteBC => rdiscreteBC
    
    ! To give an overview, we now have (concerning the matrices):
    !
    ! - Laplace matrix -> rmatrixLaplace
    ! - Mass matrix    -> rmatrixMass and rmatrixMassBlock
    ! - Temp matrix    -> rmatrix     and rmatrixBlock (knowing the BC`s)
    !
    ! 3.) Vectors
    !
    ! Now we come to the stuff with the vectors. Th�s starts with the RHS vector.
    !
    ! For setting up up a RHS vector during the time stepping, we have to
    ! set up the description of the corresponding linear form.
    ! The same has to be done for the right hand side of the problem.
    ! At first set up the corresponding linear form (f,Phi_j):
    rlinform%itermCount = 1
    rlinform%Idescriptors(1) = DER_FUNC
    
    ! ... and then discretise the RHS to get a discrete version of it.
    ! Again we simply create a scalar vector based on the one and only
    ! discretisation structure.
    ! This scalar vector will later be used as the one and only first
    ! component in a block vector.
    call linf_buildVectorScalar (rdiscretisation%RspatialDiscr(1),&
                                 rlinform,.true.,rrhs,coeff_RHS)

    ! Immediately create a 1-block version of the scalar RHS.
    ! This is then compatible to the 1x1 block matrix rmatrixBlock
    call lsysbl_createVecFromScalar (rrhs,rrhsBlock,rdiscretisation)
    
    ! Hang the pointer into the vector. That way, these
    ! boundary conditions are always connected to that vector.
    rrhsBlock%p_rdiscreteBC => rdiscreteBC
                             
    ! We have a block vector for the RHS, but that is not enough. What we
    ! need in total is
    ! - A RHS vector (we have)
    ! - A RHS vector for the solver (changing in every time step, missing)
    ! - A solution vector (changing in every time step, missing)
    ! Allocate memory for the missing vectors. They have exactly the same shape as
    ! our RHS vector, so we can use the RHS to 'derive' the missing vectors.
    ! Note that this will also transfer the connected boundary conditions
    ! to the new vectors.
    ! Btw., the (initial) solution vector is filled with 0.
    call lsysbl_createVecBlockIndirect (rrhsBlock, rvectorBlock, .true.)
    call lsysbl_createVecBlockIndirect (rrhsBlock, rtimeRhsBlock, .false.)
    call lsysbl_createVecBlockIndirect (rrhsBlock, rtempBlock, .false.)
    
    ! To give an overview, we now have (concerning the matrices):
    !
    ! - RHS vector "f"            -> rrhs and rrhsBlock (knowing the BC`s)
    ! - RHS vector for the solver ->          rtimeRhsBlock (knowing the BC`s)
    ! - Solution vector           ->          rvectorBlock (knowing the BC`s)
    !
    ! Discretisation Finished!
    
    ! Next step: Set up the solvers!
    !
    ! During the linear solver, the boundary conditions are also
    ! frequently imposed to the vectors. But as the linear solver
    ! does not work with the actual solution vectors but with
    ! defect vectors instead.
    ! So, set up a filter chain that filters the defect vector
    ! during the solution process to implement discrete boundary conditions.
    RfilterChain(1)%ifilterType = FILTER_DISCBCDEFREAL

    ! Create a BiCGStab-solver. Attach the above filter chain
    ! to the solver, so that the solver automatically filters
    ! the vector during the solution process.
    nullify(p_rpreconditioner)
    call linsol_initBiCGStab (p_rsolverNode,p_rpreconditioner,RfilterChain)
    
    ! Set the output level of the solver to 2 for some output
    p_rsolverNode%ioutputLevel = 2
    
    ! Ok, now it gets interesting. The linear solver needs a matrix.
    ! Using the mass and Laplace matrix, we set up
    !      A = 1/dt M + L
    ! in rmatrix. This is the system matrix, which is valid in all time steps
    ! as we use implicit Euler with a fixed time step!
    !
    ! The boolean parameters in this call say:
    ! - Sum up the entries from rmatrixMass and rmatrixLaplace.
    ! - All matrices have the same structure, even the destination matrix.
    !   So it is not necessary to allocate any memory.
    !
    ! Note that rmatrix shares its data with rmatrixBlock(1,1) so by modifying
    ! rmatrix, we simultaneously modify rmatrixBlock(1,1).
    call lsyssc_matrixLinearComb (&
        rmatrixMass, rmatrixLaplace, 1.0_DP/dtstep, 1.0_DP,&
        .false.,.false.,.true.,.true., rmatrix)
        
    ! Next step is to implement boundary conditions into the matrix.
    ! This is done using a vector/matrix filter for discrete boundary 
    ! conditions.
    ! The discrete boundary conditions are already attached to the
    ! matrix. Call the appropriate matrix filter that modifies the 
    ! matrix according to the boundary conditions.
    call matfil_discreteBC (rmatrixBlock)

    ! Attach the system matrix to the solver.
    ! First create an array with the matrix data (on all levels, but we
    ! only have one level here), then call the initialisation 
    ! routine to attach all these matrices.
    ! Remark: Do not make a call like
    !    CALL linsol_setMatrices(p_RsolverNode,(/rmatrixBlock/))
    ! This does not work on all compilers, since the compiler would have
    ! to create a temp array on the stack - which does not always work!
    Rmatrices = (/rmatrixBlock/)
    call linsol_setMatrices(p_RsolverNode,Rmatrices)
    
    ! Initialise structure/data of the solver. This allows the
    ! solver to allocate memory / perform some precalculation
    ! to the problem.
    call linsol_initStructure (p_rsolverNode, ierror)
    if (ierror .ne. LINSOL_ERR_NOERROR) stop
    call linsol_initData (p_rsolverNode, ierror)
    if (ierror .ne. LINSOL_ERR_NOERROR) stop
    
    ! Start the time-loop.
    do itimestep = 1,ntimesteps
      
      ! Next time step.
      dtime = dtime + dtstep
      
      call output_separator(OU_SEP_MINUS)
      call output_line ('Time step '//trim(sys_siL(itimestep,6))// &
                        '     Time '//trim(sys_sdL(dtime,5)))
      call output_lbrk ()

      ! Create the new RHS for the solver. To do this, calculate:
      !
      !    RHS = f + 1/dt M u

      call lsysbl_copyVector (rrhsBlock, rtimeRhsBlock)
      call lsysbl_blockMatVec (rmatrixMassBlock, rvectorBlock, rtimeRhsBlock, &
          1.0_DP/dtstep, 1.0_DP)
          
      ! Implement the boundary conditions into the RHS and into the solution vector.
      call vecfil_discreteBCrhs (rtimeRhsBlock)
      call vecfil_discreteBCsol (rvectorBlock)
      
      ! Solve the system for the new time step:
      !
      !    (M/dt + L) u  =  f + M/dt u_{old}
      !    ^^^^^^^^^^       ^^^^^^^^^^^^^^^^
      !   rmatrixBlock       rtimeRhsBlock
      !
      ! <=>         A x  = b    
      !
      ! As we want to solve Ax=b with b being the real RHS and 
      ! x being the real solution vector,
      ! we use linsol_solveAdaptively. If b is a defect
      ! RHS and x a defect update to be added to a solution vector,
      ! we would have to use linsol_precondDefect instead.
      call linsol_solveAdaptively (p_rsolverNode,rvectorBlock,rtimeRhsBlock,rtempBlock)
      
      ! That is it, rvectorBlock now contains our solution. We can now
      ! start the postprocessing. 
      !
      ! Get the path for writing postprocessing files from the environment variable
      ! $UCDDIR. If that does not exist, write to the directory "./gmv".
      if (.not. sys_getenv_string("UCDDIR", sucddir)) sucddir = './gmv'

      ! Start UCD export to GMV file:
      call ucd_startGMV (rexport,UCD_FLAG_STANDARD,rtriangulation,&
                        trim(sucddir)//'/u2.gmv.'//trim(sys_si0L(itimestep,5)))
      
      call lsyssc_getbase_double (rvectorBlock%RvectorBlock(1),p_Ddata)
      call ucd_addVariableVertexBased (rexport,'sol',UCD_VAR_STANDARD, p_Ddata)
      
      ! Write the file to disc, that is it.
      call ucd_write (rexport)
      call ucd_release (rexport)
      
    end do
    
    ! We are finished - but not completely!
    ! Now, clean up so that all the memory is available again.
    !
    ! Release solver data and structure
    call linsol_doneData (p_rsolverNode)
    call linsol_doneStructure (p_rsolverNode)
    
    ! Release the solver node and all subnodes attached to it (if at all):
    call linsol_releaseSolver (p_rsolverNode)
    
    ! Release the block matrix/vectors
    call lsysbl_releaseVector (rtempBlock)
    call lsysbl_releaseVector (rvectorBlock)
    call lsysbl_releaseVector (rtimeRhsBlock)
    call lsysbl_releaseVector (rrhsBlock)
    call lsysbl_releaseMatrix (rmatrixBlock)
    call lsysbl_releaseMatrix (rmatrixMassBlock)

    ! Release the matrices -- after releasing the block matrices!
    ! These must exist as long as the block matrices exist, as the block 
    ! matrices/vectors are only 'copies' of the scalar ones, sharing the 
    ! same handles!
    call lsyssc_releaseVector (rrhs)
    call lsyssc_releaseMatrix (rmatrix)
    call lsyssc_releaseMatrix (rmatrixLaplace)
    call lsyssc_releaseMatrix (rmatrixMass)
    
    ! Release our discrete version of the boundary conditions
    call bcasm_releaseDiscreteBC (rdiscreteBC)

    ! Release the discretisation structure and all spatial discretisation
    ! structures in it.
    call spdiscr_releaseBlockDiscr(rdiscretisation)
    
    ! Release the triangulation. 
    call tria_done (rtriangulation)
    
    ! Finally release the domain, that is it.
    call boundary_release (rboundary)
    
  end subroutine

end module
