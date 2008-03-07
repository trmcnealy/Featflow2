!##############################################################################
!# ****************************************************************************
!# <name> cc2dminim2boundary </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains the definition of the analytic boundary conditions
!# as well as discretisation routines for the boundary.
!#
!# The following files can be found here:
!#
!# 1.) cc_initDiscreteBC
!#     -> Discretise analytic boundary conditions, create discrete
!#        boundary conditions
!#
!# 2.) cc_updateDiscreteBC
!#     -> Reassemble discrete boundary conditions
!#
!# 3.) cc_doneBC
!#     -> Release discrete and analytic boundary conditions
!#
!# 4.) cc_implementBC
!#     -> Implement discrete boundary conditions into solution/RHS vectors
!#        and matrix on finest level
!#
!# </purpose>
!##############################################################################

MODULE cc2dmediumm2boundary

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
    
  USE cc2dmediumm2basic
  USE cc2dmediumm2boundarydef
  USE cc2dmedium_callback
  
  IMPLICIT NONE

CONTAINS
  
  ! ***************************************************************************

!<subroutine>

  SUBROUTINE cc_initDiscreteBC (rproblem,rvector,rrhs)
  
!<description>
  ! This calculates the discrete version of the boundary conditions and
  ! assigns it to the system matrix and RHS vector.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem
  
  ! A vector structure for the solution vector. The discrete BC structures are 
  ! attached to that.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rvector

  ! A vector structure for the RHS vector. The discrete BC structures are 
  ! attached to that.
  TYPE(t_vectorBlock), INTENT(INOUT) :: rrhs
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: i

  ! A pointer to the system matrix and the RHS vector as well as 
  ! the discretisation
  TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation

  ! Pointer to structure for saving discrete BC's:
  TYPE(t_discreteBC), POINTER :: p_rdiscreteBC
  TYPE(t_discreteFBC), POINTER :: p_rdiscreteFBC
    
    DO i=rproblem%NLMIN,rproblem%NLMAX
    
      ! From the matrix or the RHS we have access to the discretisation and the
      ! analytic boundary conditions.
      p_rdiscretisation => rproblem%RlevelInfo(i)%rdiscretisation
      
      ! Initialise the BC/FBC structures.
      ALLOCATE(rproblem%RlevelInfo(i)%p_rdiscreteBC)
      CALL bcasm_initDiscreteBC(rproblem%RlevelInfo(i)%p_rdiscreteBC)
      
      ALLOCATE(rproblem%RlevelInfo(i)%p_rdiscreteFBC)
      CALL bcasm_initDiscreteFBC(rproblem%RlevelInfo(i)%p_rdiscreteFBC)
      ! Hang the pointer into the the matrix. That way, these
      ! boundary conditions are always connected to that matrix and that
      ! vector.
      p_rdiscreteBC => rproblem%RlevelInfo(i)%p_rdiscreteBC
      
      ! Also hang in the boundary conditions into the temporary vector that is
      ! used for the creation of solutions on lower levels.
      ! This allows us to filter this vector when we create it.
      rproblem%RlevelInfo(i)%rtempVector1%p_rdiscreteBC => p_rdiscreteBC
      rproblem%RlevelInfo(i)%rtempVector2%p_rdiscreteBC => p_rdiscreteBC
      rproblem%RlevelInfo(i)%rtempVector3%p_rdiscreteBC => p_rdiscreteBC
      
      ! The same for the fictitious boudary boundary conditions.
      p_rdiscreteFBC => rproblem%RlevelInfo(i)%p_rdiscreteFBC
      rproblem%RlevelInfo(i)%rtempVector1%p_rdiscreteBCfict => p_rdiscreteFBC
      rproblem%RlevelInfo(i)%rtempVector2%p_rdiscreteBCfict => p_rdiscreteFBC
      rproblem%RlevelInfo(i)%rtempVector3%p_rdiscreteBCfict => p_rdiscreteFBC
      
    END DO

    ! On the finest level, attach the discrete BC also
    ! to the solution and RHS vector. They need it to be compatible
    ! to the matrix on the finest level.
    p_rdiscreteBC => rproblem%RlevelInfo(rproblem%NLMAX)%p_rdiscreteBC
    
    rrhs%p_rdiscreteBC => p_rdiscreteBC
    rvector%p_rdiscreteBC => p_rdiscreteBC

    ! The same with the fictitious boundary BC's
    p_rdiscreteFBC => rproblem%RlevelInfo(rproblem%NLMAX)%p_rdiscreteFBC
    rrhs%p_rdiscreteBCfict => p_rdiscreteFBC
    rvector%p_rdiscreteBCfict => p_rdiscreteFBC
                
    ! Call the update routine to assemble the BC's.
    CALL cc_updateDiscreteBC (rproblem)

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE cc_updateDiscreteBC (rproblem)
  
!<description>
  ! This updates the discrete version of the boundary conditions. The BC's
  ! are reassembled according to the current situation of the simulation.
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
    TYPE(t_blockDiscretisation), POINTER :: p_rdiscretisation

    ! Initialise the collection for the assembly process with callback routines.
    ! Basically, this stores the simulation time in the collection if the
    ! simulation is nonstationary.
    CALL cc_initCollectForAssembly (rproblem,rproblem%rcollection)

    DO i=rproblem%NLMIN,rproblem%NLMAX
    
      ! From the matrix or the RHS we have access to the discretisation and the
      ! analytic boundary conditions.
      p_rdiscretisation => rproblem%RlevelInfo(i)%rdiscretisation
      
      ! Clear the last discretised BC's. We are reassembling them.
      CALL bcasm_clearDiscreteBC(rproblem%RlevelInfo(i)%p_rdiscreteBC)
      CALL bcasm_clearDiscreteFBC(rproblem%RlevelInfo(i)%p_rdiscreteFBC)
      
      ! Assemble boundary conditions
      CALL cc_assembleBDconditions (rproblem,p_rdiscretisation,&
          rproblem%RlevelInfo(i)%p_rdiscreteBC,rproblem%rcollection)
      
      ! Assemble the boundary conditions of fictitious boundary components
      CALL cc_assembleFBDconditions (rproblem,p_rdiscretisation,&
          rproblem%RlevelInfo(i)%p_rdiscreteFBC,rproblem%rcollection)

    END DO

    ! Clean up the collection (as we are done with the assembly, that's it.
    CALL cc_doneCollectForAssembly (rproblem,rproblem%rcollection)

  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE cc_implementBC (rproblem,rvector,rrhs,rdefect)
  
!<description>
  ! Implements boundary conditions into the RHS and into a given solution vector.
  ! Implements boundary conditions into the system matrix on every level
  ! defined by rproblem.
!</description>

!<inputoutput>
  ! A problem structure saving problem-dependent information.
  TYPE(t_problem), INTENT(INOUT), TARGET :: rproblem

  ! A vector structure of a solution vector. The discrete BC's are implemented
  ! into that.
  TYPE(t_vectorBlock), INTENT(INOUT), OPTIONAL :: rvector

  ! A vector structure of a RHS vector. The discrete BC's are implamented into that.
  TYPE(t_vectorBlock), INTENT(INOUT), OPTIONAL :: rrhs

  ! A vector structure of a defect vector. The discrete BC's are implamented into that.
  TYPE(t_vectorBlock), INTENT(INOUT), OPTIONAL :: rdefect
  
!</inputoutput>

!</subroutine>

  ! local variables
  INTEGER :: ilvmax
  
    ! Get our the right hand side and solution from the problem structure
    ! on the finest level
    ilvmax = rproblem%NLMAX
    
    IF (PRESENT(rvector)) THEN
    
      ! Implement discrete boundary conditions into solution vector by
      ! filtering the vector.
      CALL vecfil_discreteBCsol (rvector)
      
      ! Implement discrete boundary conditions of fictitioous boundary comnponents
      ! into solution vector by filtering the vector.
      CALL vecfil_discreteFBCsol (rvector)
      
    END IF
    
    IF (PRESENT(rdefect)) THEN
    
      ! Implement discrete boundary conditions into solution vector by
      ! filtering the vector.
      CALL vecfil_discreteBCdef (rdefect)
      
      ! Implement discrete boundary conditions of fictitioous boundary comnponents
      ! into solution vector by filtering the vector.
      CALL vecfil_discreteFBCdef (rdefect)
      
    END IF
    
    IF (PRESENT(rrhs)) THEN
    
      ! Implement pressure drop boundary conditions into RHS vector
      ! if there are any.
      CALL vecfil_discreteNLPDropBCrhs (rrhs)
      
      ! Implement discrete boundary conditions into RHS vector by 
      ! filtering the vector.
      CALL vecfil_discreteBCrhs (rrhs)

      ! Implement discrete boundary conditions of fictitious boundary components
      ! into RHS vector by filtering the vector.
      CALL vecfil_discreteFBCrhs (rrhs)

    END IF
    
  END SUBROUTINE

  ! ***************************************************************************

!<subroutine>

  SUBROUTINE cc_doneBC (rproblem)
  
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
      CALL bcasm_releaseDiscreteBC (rproblem%RlevelInfo(i)%p_rdiscreteBC)
      DEALLOCATE(rproblem%RlevelInfo(i)%p_rdiscreteBC)
      
      ! as well as the discrete version of the BC's for fictitious boundaries
      CALL bcasm_releaseDiscreteFBC (rproblem%RlevelInfo(i)%p_rdiscreteFBC)
      DEALLOCATE(rproblem%RlevelInfo(i)%p_rdiscreteFBC)
    END DO
    
  END SUBROUTINE

END MODULE
