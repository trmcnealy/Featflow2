!##############################################################################
!# ****************************************************************************
!# <name> boundaryaux </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains auxiliary routines for handling boundary components.
!#
!# It contains the following set of routines:
!#
!# 1.) bdraux_getElementsAtBoundaryRegion
!#     -> Calculates the list of elements at a boundary region.
!# </purpose>
!##############################################################################
module boundaryaux

  use boundary
  use fsystem
  use genoutput
  use spatialdiscretisation
  use storage
  use triangulation

  private

  public :: bdraux_getElementsAtBoundaryRegion
  
contains

  !****************************************************************************

!<subroutine>

  subroutine bdraux_getElementsAtBoundaryRegion(rboundaryRegion, rdiscretisation,&
      NELbdc, IelementList, IelementOrientation, celement, DedgePosition)

!<description>
    ! This subroutine calculates the list of elements which are
    ! adjacent to the boundary region. If the number of elements
    ! exceeds the size of the working arrays an error is thrown.

!</description>

!<input>
    ! A t_boundaryRegion specifying the boundary region where
    ! to calculate. 
    type(t_boundaryRegion), intent(IN) :: rboundaryRegion

    ! A discretisation structure
    type(t_spatialdiscretisation), intent(IN) :: rdiscretisation
!</input>

!<output>
    ! The number of elements at the boundary region
    integer, intent(OUT) :: NELbdc

    ! The list of elements adjacent to the boundary region
    integer, dimension(:), intent(OUT) :: IelementList

    ! The orientation of elements adjacent to the boundary region
    integer, dimension(:), intent(OUT) :: IelementOrientation

    ! OPTIOANL: Element type to be considered. If not present, then
    ! all elements adjacent to the boundary are inserted into the list
    integer(I32), intent(IN), optional :: celement

    ! OPTIONAL: The start- and end-parameter values of the edges on
    ! the boundary region
    real(DP), dimension(:,:), intent(OUT), optional :: DedgePosition
!</output>
!</subroutine>

    ! local variables
    type(t_elementDistribution), dimension(:), pointer :: p_RelementDistribution
    type(t_triangulation), pointer :: p_rtriangulation
    real(DP), dimension(:), pointer :: p_DedgeParameterValue
    real(DP), dimension(:), pointer :: p_DvertexParameterValue
    real(DP), dimension(:,:), pointer :: p_DvertexCoordinates
    integer, dimension(:), pointer :: p_IboundaryCpIdx
    integer, dimension(:), pointer :: p_IedgesAtBoundary
    integer, dimension(:), pointer :: p_IelementsAtBoundary
    integer, dimension(:), pointer :: p_IelementDistr
    integer, dimension(:,:), pointer :: p_IedgesAtElement
    integer, dimension(:,:), pointer :: p_IverticesAtElement
    integer :: ibdc,iedge,iel,ilocaledge
    real(DP) :: dpar1,dpar2

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
    
    if (present(celement)) then
      call storage_getbase_int (rdiscretisation%h_IelementDistr,&
          p_IelementDistr)
    end if

    ! Boundary component?
    ibdc = rboundaryRegion%iboundCompIdx

    ! Number of elements on that boundary component?
    NELbdc = p_IboundaryCpIdx(ibdc+1)-p_IboundaryCpIdx(ibdc)

    if (NELbdc .gt. ubound(IelementList,1) .or.&
        NELbdc .gt. ubound(IelementOrientation,1)) then
      call output_line('Insufficient memory',&
          OU_CLASS_ERROR,OU_MODE_STD,'bdraux_getElementsAtBoundaryRegion')
      call sys_halt()
    end if

    if (present(DedgePosition)) then
      if (NELbdc .gt. ubound(DedgePosition,2)) then
        call output_line('Insufficient memory',&
            OU_CLASS_ERROR,OU_MODE_STD,'bdraux_getElementsAtBoundaryRegion')
        call sys_halt()
      end if
    end if
    
    ! Loop through the edges on the boundary component ibdc. If the
    ! edge is inside, remember the element number and figure out the
    ! orientation of the edge, whereby iel counts the total number of
    ! elements in the region.
    iel = 0
    do iedge = 1,NELbdc
      if (boundary_isInRegion(rboundaryRegion, ibdc,&
          p_DedgeParameterValue(iedge))) then

        ! Check if we are the correct element distribution
        if (present(celement)) then
          if (celement .ne. p_RelementDistribution(&
              p_IelementDistr(iel+1))%celement) cycle
        end if
        iel = iel + 1

        ! Element number
        IelementList(iel) = p_IelementsAtBoundary(iedge)
        
        ! Element orientation; i.e. the local number of the boundary edge 
        do ilocaledge = 1,ubound(p_IedgesAtElement,1)
          if (p_IedgesAtElement(ilocaledge, p_IelementsAtBoundary(iedge)) .eq. &
              p_IedgesAtBoundary(iedge)) exit
        end do
        IelementOrientation(iel) = ilocaledge
        
        if (present(DedgePosition)) then
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
          
          DedgePosition(1,iel) = dpar1
          DedgePosition(2,iel) = dpar2
        end if
        
      end if
    end do
    
  end subroutine bdraux_getElementsAtBoundaryRegion

end module boundaryaux
