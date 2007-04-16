!##############################################################################
!# ****************************************************************************
!# <name> dofmapping </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module is a basic module of the discretisation. It contains routines
!# to map local degrees of freedom on one element primitive onto the global
!# degrees of freedom of a solution vector.
!#
!# The following functions provide support for global DOF's:
!#
!# 1.) dof_igetNDofGlob
!#     -> Get number of global DOF's to a given discretisation
!#
!# 2.) dof_locGlobMapping
!#     -> Map the 'local' degrees of freedom 1..n on one element to the global 
!#        degrees of freedom according to a discretisaion
!#
!# 3.) dof_locGlobMapping_mult
!#     -> Map the 'local' degrees of freedom 1..n on a set of elements to 
!#        the global degrees of freedom according to a discretisaion. 
!#
!# </purpose>
!##############################################################################

MODULE dofmapping

  USE fsystem
  USE spatialdiscretisation
  USE triangulation
  USE element
  
  IMPLICIT NONE

!<constants>

  !<constantblock description="Kind values for global DOF's">

  ! kind value for indexing global DOF's
  INTEGER, PARAMETER :: PREC_DOFIDX     = I32

  !</constantblock>

!</constants>

CONTAINS

  ! ***************************************************************************

!<function>  

  INTEGER(PREC_DOFIDX) FUNCTION dof_igetNDofGlob(rdiscretisation,btestSpace)

!<description>
  ! This function returns for a given discretisation the number of global
  ! degrees of freedom in the corresponding scalar DOF vector.
!</description>

!<input>    
  ! The discretisation structure that specifies the (scalar) discretisation.
  TYPE(t_spatialDiscretisation), INTENT(IN) :: rdiscretisation

  ! OPTIONAL: Use test space.
  ! Normally, dof_igetNDofGlob returns the number of DOF's in the trial
  ! space of the discretisation. If btestSpace is present and set to TRUE,
  ! dof_igetNDofGlob will determine the number of DOF's in the test space
  ! of the discretisation instead of the trial space.
  ! This is used e.g. to determine the number of rows in a system matrix,
  ! while btestSpace=false returns the number of columns.
  LOGICAL, OPTIONAL, INTENT(IN)             :: btestSpace
!</input>

!<result>
  !global number of equations on current grid
!</result>

!</function>

  INTEGER(I32) :: ieltyp

  dof_igetNDofGlob = 0

  ! 3D currently not supported
  IF (rdiscretisation%ndimension .NE. NDIM2D) THEN
    PRINT *,'dof_igetNDofGlob: Only 2D supported at the moment!'
    STOP
  END IF

  IF (rdiscretisation%ccomplexity .EQ. SPDISC_UNIFORM) THEN
  
    ieltyp = rdiscretisation%RelementDistribution(1)%itrialElement
    IF (PRESENT (btestSpace)) THEN
      IF (btestSpace) ieltyp = rdiscretisation%RelementDistribution(1)%itestElement
    END IF

    ! Uniform discretisation - fall back to the old FEAT mapping
    dof_igetNDofGlob = NDFG_uniform2D (rdiscretisation%p_rtriangulation, ieltyp)
  
  END IF
  
  CONTAINS
  
    ! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ! Internal subroutine: Get global DOF number for uniform discretisation
    ! with only one element type.
    ! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ! This is roughly the NDFG routine of the old FEAT library...
    
    INTEGER(PREC_DOFIDX) FUNCTION NDFG_uniform2D (rtriangulation, ieltype)
    
    ! IN: The underlying triangulation
    TYPE(t_triangulation), INTENT(IN) :: rtriangulation
    
    ! IN: The element type of the discretisation
    INTEGER(I32), INTENT(IN) :: ieltype
    
    ! OUT: number of global DOF's.
    
    ! The number of global DOF's depends on the element type...
    SELECT CASE (elem_getPrimaryElement(ieltype))
    CASE (EL_P0, EL_Q0)
      ! DOF's in the cell midpoints
      NDFG_uniform2D = rtriangulation%NEL
    CASE (EL_P1, EL_Q1)
      ! DOF's in the vertices
      NDFG_uniform2D = rtriangulation%NVT
    CASE (EL_P2)
      ! DOF's in the vertices and edge midpoints
      NDFG_uniform2D = rtriangulation%NVT + rtriangulation%NMT
    CASE (EL_Q2)
      ! DOF's in the vertices, edge midpoints and element midpoints
      NDFG_uniform2D = rtriangulation%NVT + rtriangulation%NMT + rtriangulation%NEL
    CASE (EL_P3)
      ! 1 DOF's per vertices, 2 DOF per edge 
      NDFG_uniform2D = rtriangulation%NVT + 2*rtriangulation%NMT
    CASE (EL_Q3)
      ! 1 DOF's per vertices, 2 DOF per edge, 4 DOF in the inner
      NDFG_uniform2D = rtriangulation%NVT + 2*rtriangulation%NMT + 4*rtriangulation%NEL
    CASE (EL_QP1)
      ! 3 DOF's in the midpoint of the element.
      NDFG_uniform2D = 3*rtriangulation%NEL
    CASE (EL_Q1T)
      ! 1 DOF per edge
      NDFG_uniform2D = rtriangulation%NMT
    END SELECT
    
    END FUNCTION

  END FUNCTION 

  ! ***************************************************************************
!<subroutine>

  SUBROUTINE dof_locGlobMapping(rdiscretisation, ielIdx, btestFct, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the element ielIdx. It is a wrapper routine
  ! for the corresponding routines for a specific element type.
  !
  ! On each element, there are a number of local DOF's 1..n (where n can
  ! be obtained using elem_igetNDofLoc). This subroutine returns the
  ! corresponding global degrees of freedom, corresponding to these local
  ! ones.
!</description>

!<input>

  ! The discretisation structure that specifies the (scalar) discretisation.
  TYPE(t_spatialDiscretisation), INTENT(IN) :: rdiscretisation

  ! Element index, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), INTENT(IN) :: ielIdx

  ! If =false, the DOF's of the trial functions are computed. If =true,
  ! the DOF's of the test functions are computed.
  LOGICAL, INTENT(IN) :: btestFct

!</input>
    
!<output>

  ! array of global DOF numbers
  INTEGER(PREC_DOFIDX), DIMENSION(:), INTENT(OUT) :: IdofGlob

!</output>

! </subroutine>

  ! local variables
  INTEGER(PREC_ELEMENTIDX), DIMENSION(1) :: ielIdx_array
  INTEGER(PREC_DOFIDX), DIMENSION(SIZE(IdofGlob),1) :: IdofGlob_array

  ! Wrapper to dof_locGlobMapping_mult - better use this directly!
  ielIdx_array(1) = ielidx
  CALL dof_locGlobMapping_mult (rdiscretisation, ielIdx_array, btestFct, &
                                IdofGlob_array)
  IdofGlob = IdofGlob_array(:,1)

  END SUBROUTINE

  ! ***************************************************************************
!<subroutine>

  SUBROUTINE dof_locGlobMapping_mult(rdiscretisation, IelIdx, btestFct, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the elements IelIdx. It is a wrapper routine
  ! for the corresponding routines for a specific element type.
  !
  ! On each element, there are a number of local DOF's 1..n (where n can
  ! be obtained using elem_igetNDofLoc). This subroutine returns the
  ! corresponding global degrees of freedom, corresponding to these local
  ! ones.
  ! The routine allows to calculate the DOF's to a list of elements
  ! which are all of the same type. IelIdx is this list of elements and
  ! IdofGlob is a 2D array which receives for every element the
  ! corresponding global DOF's.
!</description>

!<input>

  ! The discretisation structure that specifies the (scalar) discretisation.
  TYPE(t_spatialDiscretisation), INTENT(IN) :: rdiscretisation

  ! Element indices, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), DIMENSION(:), INTENT(IN) :: IelIdx
  
  ! If =false, the DOF's of the trial functions are computed. If =true,
  ! the DOF's of the test functions are computed.
  LOGICAL, INTENT(IN) :: btestFct

!</input>
    
!<output>

  ! Array of global DOF numbers; for every element in IelIdx there is
  ! a subarray in this list receiving the corresponding global DOF's.
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(OUT) :: IdofGlob

!</output>

! </subroutine>

  ! local variables
  INTEGER(I32), DIMENSION(:,:), POINTER :: p_2darray,p_2darray2
  TYPE(t_triangulation), POINTER :: p_rtriangulation     
  INTEGER(I32) :: ieltype

  ! 3D currently not supported
  IF (rdiscretisation%ndimension .NE. NDIM2D) THEN
    PRINT *,'dof_locGlobMapping_mult: Only 2D supported at the moment!'
    STOP
  END IF

  ! At first we deal only with uniform discretisations
  IF (rdiscretisation%ccomplexity .EQ. SPDISC_UNIFORM) THEN
  
    p_rtriangulation => rdiscretisation%p_rtriangulation
  
    ! Call the right 'multiple-get' routines for global DOF's.
    ! For this purpose we evaluate the pointers in the discretisation
    ! structure (if necessary) to prevent another call using pointers...
    ! The number of global DOF's depends on the element type...
    
    IF (btestFct) THEN
      ieltype = rdiscretisation%RelementDistribution(1)%itestElement
    ELSE
      ieltype = rdiscretisation%RelementDistribution(1)%itrialElement
    END IF
    
    SELECT CASE (elem_getPrimaryElement(ieltype))
    CASE (EL_P0, EL_Q0)
      ! DOF's for Q0
      CALL dof_locGlobUniMult_P0Q0(IelIdx, IdofGlob)
    CASE (EL_P1, EL_Q1)
      ! DOF's in the vertices
      CALL storage_getbase_int2D (p_rtriangulation%h_IverticesAtElement,p_2darray)
      CALL dof_locGlobUniMult_P1Q1(p_2darray, IelIdx, IdofGlob)
    CASE (EL_P2)
      ! DOF's in the vertices and egde midpoints
      CALL storage_getbase_int2D (p_rtriangulation%h_IverticesAtElement,p_2darray)
      CALL storage_getbase_int2D (p_rtriangulation%h_IedgesAtElement,p_2darray2)
      CALL dof_locGlobUniMult_P2(p_2darray, p_2darray2, IelIdx, IdofGlob)
    CASE (EL_Q2)
      ! DOF's in the vertices, egde midpoints and element midpoints
      CALL storage_getbase_int2D (p_rtriangulation%h_IverticesAtElement,p_2darray)
      CALL storage_getbase_int2D (p_rtriangulation%h_IedgesAtElement,p_2darray2)
      CALL dof_locGlobUniMult_Q2(p_rtriangulation%NVT,p_rtriangulation%NMT,&
                                 p_2darray, p_2darray2, IelIdx, IdofGlob)
    CASE (EL_P3) 
    CASE (EL_Q3) 

    CASE (EL_QP1)
      ! DOF's for Q1
      CALL dof_locGlobUniMult_QP1(p_rtriangulation%NEL,IelIdx, IdofGlob)
    CASE (EL_Q1T)
      ! DOF's in the edges
      CALL storage_getbase_int2D (p_rtriangulation%h_IedgesAtElement,p_2darray)
      CALL dof_locGlobUniMult_E30(p_rtriangulation%NVT,p_2darray, IelIdx, IdofGlob)
    END SELECT
  
  END IF

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  PURE SUBROUTINE dof_locGlobUniMult_P0Q0(IelIdx, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the elements in the list IelIdx.
  ! all elements in the list are assumed to be P0 or Q0.
  ! A uniform grid is assumed, i.e. a grid completely discretised the
  ! same element.
!</description>

!<input>

  ! Element indices, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), DIMENSION(:), INTENT(IN) :: IelIdx

!</input>
    
!<output>

  ! Array of global DOF numbers; for every element in IelIdx there is
  ! a subarray in this list receiving the corresponding global DOF's.
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(OUT) :: IdofGlob

!</output>

!</subroutine>

  ! local variables 
  INTEGER(I32) :: i
  
  ! Loop through the elements to handle
  DO i=1,SIZE(IelIdx)
    ! Global DOF = number of the element
    IdofGlob(1,i) = IelIdx(i)
  END DO

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  PURE SUBROUTINE dof_locGlobUniMult_P1Q1(IverticesAtElement, IelIdx, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the elements in the list IelIdx.
  ! all elements in the list are assumed to be Q1.
  ! A uniform grid is assumed, i.e. a grid completely discretised the
  ! same element.
!</description>

!<input>

  ! An array with the number of vertices adjacent to each element of the
  ! triangulation.
  INTEGER(I32), DIMENSION(:,:), INTENT(IN) :: IverticesAtElement

  ! Element indices, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), DIMENSION(:), INTENT(IN) :: IelIdx
  
!</input>
    
!<output>

  ! Array of global DOF numbers; for every element in IelIdx there is
  ! a subarray in this list receiving the corresponding global DOF's.
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(OUT) :: IdofGlob

!</output>

!</subroutine>

  ! local variables 
  INTEGER(I32) :: i,j
  
  ! Get the number of local DOF's - usually either 3 or 4, depending on
  ! the element. The first dimension of IdofGlob indicates the number of 
  ! DOF's.
  j = MIN(UBOUND(IverticesAtElement,1),UBOUND(IdofGlob,1))
  
  ! Loop through the elements to handle
  DO i=1,SIZE(IelIdx)
    ! Calculate the global DOF's - which are simply the vertex numbers of the 
    ! corners.
    IdofGlob(1:j,i) = IverticesAtElement(1:j,IelIdx(i))
  END DO

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  PURE SUBROUTINE dof_locGlobUniMult_P2(IverticesAtElement, &
                                        IedgesAtElement,IelIdx, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the elements in the list IelIdx.
  ! all elements in the list are assumed to be P2.
  ! A uniform grid is assumed, i.e. a grid completely discretised the
  ! same element.
!</description>

!<input>
  ! An array with the number of vertices adjacent to each element of the
  ! triangulation.
  INTEGER(I32), DIMENSION(:,:), INTENT(IN) :: IverticesAtElement

  ! An array with the number of edges adjacent to each element of the
  ! triangulation.
  INTEGER(I32), DIMENSION(:,:), INTENT(IN) :: IedgesAtElement

  ! Element indices, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), DIMENSION(:), INTENT(IN) :: IelIdx
  
!</input>
    
!<output>

  ! Array of global DOF numbers; for every element in IelIdx there is
  ! a subarray in this list receiving the corresponding global DOF's.
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(OUT) :: IdofGlob

!</output>

!</subroutine>

  ! local variables 
  INTEGER(I32) :: i
  
  ! Loop through the elements to handle
  DO i=1,SIZE(IelIdx)
    ! Calculate the global DOF's.
    ! The P2 element has global DOF's in the corners and edge midpoints
    ! of the triangles. 
    !
    ! Take the numbers of the corners of the triangles at first.
    IdofGlob(1:3,i) = IverticesAtElement(1:3,IelIdx(i))

    ! Then append the numbers of the edges as midpoint numbers.
    ! Note that the number in this array is NVT+1..NVT+NMT.
    IdofGlob(4:6,i) = IedgesAtElement(1:3,IelIdx(i))
    
  END DO

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  PURE SUBROUTINE dof_locGlobUniMult_Q2(NVT,NMT,IverticesAtElement, &
                                        IedgesAtElement,IelIdx, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the elements in the list IelIdx.
  ! all elements in the list are assumed to be Q2.
  ! A uniform grid is assumed, i.e. a grid completely discretised the
  ! same element.
!</description>

!<input>
  ! An array with the number of vertices adjacent to each element of the
  ! triangulation.
  INTEGER(I32), DIMENSION(:,:), INTENT(IN) :: IverticesAtElement

  ! An array with the number of edges adjacent to each element of the
  ! triangulation.
  INTEGER(I32), DIMENSION(:,:), INTENT(IN) :: IedgesAtElement

  ! Element indices, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), DIMENSION(:), INTENT(IN) :: IelIdx
  
  ! Number of corner vertices in the triangulation
  INTEGER(PREC_POINTIDX), INTENT(IN) :: NVT
  
  ! Number of edes in the triangulation
  INTEGER(PREC_EDGEIDX), INTENT(IN) :: NMT
!</input>
    
!<output>

  ! Array of global DOF numbers; for every element in IelIdx there is
  ! a subarray in this list receiving the corresponding global DOF's.
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(OUT) :: IdofGlob

!</output>

!</subroutine>

  ! local variables 
  INTEGER(I32) :: i
  
  ! Loop through the elements to handle
  DO i=1,SIZE(IelIdx)
    ! Calculate the global DOF's.
    ! The Q2 element has global DOF's in the corners, edge midpoints
    ! and element midpoints of the quads.
    !
    ! Take the numbers of the corners of the triangles at first.
    IdofGlob(1:4,i) = IverticesAtElement(1:4,IelIdx(i))

    ! Then append the numbers of the edges as midpoint numbers.
    ! Note that the number in this array is NVT+1..NVT+NMT.
    IdofGlob(5:8,i) = IedgesAtElement(1:4,IelIdx(i))
    
    ! At last append the element number - shifted by NVT+NMT to get
    ! a number behind.
    IdofGlob(9,i) = IelIdx(i)+NVT+NMT
    
  END DO

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  PURE SUBROUTINE dof_locGlobUniMult_QP1(NEL, IelIdx, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the elements in the list IelIdx.
  ! all elements in the list are assumed to be QP1.
  ! A uniform grid is assumed, i.e. a grid completely discretised the
  ! same element.
!</description>

!<input>

  ! Number of elements in the triangulation
  INTEGER(PREC_ELEMENTIDX), INTENT(IN) :: NEL

  ! Element indices, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), DIMENSION(:), INTENT(IN) :: IelIdx

!</input>
    
!<output>

  ! Array of global DOF numbers; for every element in IelIdx there is
  ! a subarray in this list receiving the corresponding global DOF's.
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(OUT) :: IdofGlob

!</output>

!</subroutine>

  ! local variables 
  INTEGER(I32) :: i
  
  ! Loop through the elements to handle
  DO i=1,SIZE(IelIdx)
    ! 1st Global DOF = number of the element = function value
    IdofGlob(1,i) = IelIdx(i)
    ! 2nd Global DOF = NEL + number of the element = X-derivative
    IdofGlob(2,i) = NEL+IelIdx(i)
    ! 3rd Global DOF = 2*NEL + number of the element = Y-derivative
    IdofGlob(3,i) = 2*NEL+IelIdx(i)
  END DO

  END SUBROUTINE

  ! ***************************************************************************
  
!<subroutine>

  PURE SUBROUTINE dof_locGlobUniMult_E30(iNVT, IedgesAtElement, IelIdx, IdofGlob)
  
!<description>
  ! This subroutine calculates the global indices in the array IdofGlob
  ! of the degrees of freedom of the elements in the list IelIdx.
  ! All elements in the list are assumed to be E030, E031, EM30 or EM31.
  ! A uniform grid is assumed, i.e. a grid completely discretised the
  ! same element.
!</description>

!<input>

  ! Number of vertices in the triangulation.
  INTEGER(I32), INTENT(IN) :: iNVT

  ! An array with the number of edges adjacent on each element of the
  ! triangulation.
  INTEGER(I32), DIMENSION(:,:), INTENT(IN) :: IedgesAtElement

  ! Element indices, where the mapping should be computed.
  INTEGER(PREC_ELEMENTIDX), DIMENSION(:), INTENT(IN) :: IelIdx
  
!</input>
    
!<output>

  ! Array of global DOF numbers; for every element in IelIdx there is
  ! a subarray in this list receiving the corresponding global DOF's.
  INTEGER(PREC_DOFIDX), DIMENSION(:,:), INTENT(OUT) :: IdofGlob

!</output>

!</subroutine>

  ! local variables 
  INTEGER(I32) :: i
  
  ! Loop through the elements to handle
  DO i=1,SIZE(IelIdx)
    ! Calculate the global DOF's - which are simply the vertex numbers of the 
    ! corners.
    ! We always copy all elements of IedgesAtElement (:,.).
    ! There's no harm and the compiler can optimise better.
    
    IdofGlob(1:TRIA_NVEQUAD2D,i) = IedgesAtElement(1:TRIA_NVEQUAD2D,IelIdx(i))-iNVT
  END DO

  END SUBROUTINE

END MODULE
