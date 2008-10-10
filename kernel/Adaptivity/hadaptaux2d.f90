!##############################################################################
!# ****************************************************************************
!# <name> hadaptaux2d </name>
!# ****************************************************************************
!#
!# <purpose>
!#
!# WARNING: Do not USE this module in your applications unless you really
!#          know what you are doing. This module does no error checking!!!
!#
!# This module contains all auxiliary routines which are required for
!# performing h-adaptivity in 2D. Unlike other modules, all subroutines
!# are declared PUBLIC since they are used by module HADAPTIVITY.
!#
!# The following routines are available:
!#
!#  1.) add_vertex2D = add_vertex_atEdgeMidpoint2D /
!#                     add_vertex_atElementCenter2D
!#      -> Adds a new vertex to the adaptation data structure in 2D
!#
!#  2.) remove_vertex2D
!#      -> Removes an existing vertex from the adaptation data structure in 2D
!#
!#  3.) replace_element2D = replace_elementTria /
!#                          replace_elementQuad
!#      -> Replaces an existing element by another element of he same type in 2D
!#
!#  4.) add_element2D = add_elementTria /
!#                      add_elementQuad
!#      -> Adds a new element to the adaptation data structure in 2D
!#
!#  5.) remove_element2D
!#      -> Removes an existing element from the adaptation data structure in 2D
!#
!#  6.) update_ElementNeighbors2D = update_ElemNeighb2D_1to2 /
!#                                  update_ElemNeighb2D_2to2
!#      -> Updates the list of neighboring elements  in 2D
!#
!#  7.) update_AllElementNeighbors2D
!#      -> Updates the lists of neighboring elements of ALL adjacent elements
!#
!#  8.) refine_Tria2Tria
!#      -> Refines a triangle by subdivision into two triangles
!#
!#  9.) refine_Tria3Tria
!#      -> Refines a triangle by subdivision into three triangles
!#
!# 10.) refine_Tria4Tria
!#      -> Refines a triangle by subdivision into four triangles
!#
!# 11.) refine_Quad2Quad
!#      -> Refines a quadrilateral by subdivision into two quadrilaterals
!#
!# 12.) refine_Quad3Tria
!#      -> Refines a quadrilateral by subdivision into three triangles
!#
!# 13.) refine_Quad4Tria
!#      -> Refines a quadrilateral by subdivision into four triangles
!#
!# 14.) refine_Quad4Quad
!#      -> Refines a quadrilateral by subdivision into four quadrilaterals
!#
!# 15.) convert_Tria2Tria
!#      -> Converts two neighboring triangles into four similar triangle
!#
!# 16.) convert_Quad2Quad
!#      -> Converts two neighboring quadrilaterals into four similar quadrilaterals
!#
!# 17.) convert_Quad3Tria
!#      -> Converts three neighboring triangles into four similar quadrilaterals
!#
!# 18.) convert_Quad4Tria
!#      -> Converts four neighboring triangles into four similar quadrilaterals
!#
!# 19.) coarsen_2Tria1Tria
!#      -> Coarsens two green triangles by combining them to the macro element
!#
!# 20.) coarsen_4Tria1Tria
!#      -> Coarsens four red triangles by combining them to the macro element
!#
!# 21.) coarsen_4Tria2Tria
!#      -> Coarsens four red triangles by combining them to two green elements
!#
!# 22.) coarsen_4Quad1Quad
!#      -> Coarsens four red quadrilaterals by combining them to the macro element
!#
!# 23.) coarsen_4Quad2Quad
!#      -> Coarsens four red quadrilaterals by combining them to two green elements
!#
!# 24.) coarsen_4Quad3Tria
!#      -> Coarsens four red quadrilaterals by combining them to three green elements
!#
!# 25.) coarsen_4Quad4Tria
!#      -> Coarsens four red quadrilaterals by combining them to four green elements
!#
!# 26.) coarsen_2Quad1Quad
!#      -> Coarsens two green quadrilaterals by combining them to the macro element
!#
!# 27.) coarsen_2Quad3Tria
!#      -> Coarsens two green quadrilaterals by combining them to three green triangles
!#
!# 28.) coarsen_3Tria1Quad
!#      -> Coarsens three green triangles by combining them to the macro element
!#
!# 29.) coarsen_4Tria1Quad
!#      -> Coarsens four green triangles by combining them to the macro element
!#
!# 30.) coarsen_4Tria3Tria
!#      -> Coarsens four green triangles by combining them to three green triangles
!#
!# 31.) mark_refinement2D
!#      -> Marks elements for refinement in 2D
!#
!# 32.) redgreen_mark_coarsening2D
!#      -> Marks elements for coarsening in 2D
!#
!# 33.) redgreen_mark_refinement2D
!#      -> Marks elements for refinement due to Red-Green strategy in 2D
!#
!# 34. redgreen_getState2D
!#      -> Returns the state of an element in 2D
!#
!# 35.) redgreen_getStateTria
!#      -> Returns the state of a triangle
!#
!# 36.) redgreen_getStateQuad
!#      -> Returns the state of a quadrilateral
!#
!# 37.) redgreen_rotateState2D
!#      -> Computes the state of an element after rotation in 2D
!# </purpose>
!##############################################################################

module hadaptaux2d

  use collection
  use fsystem
  use hadaptaux

  implicit none

  public

!<constantblock description="Constants for element marker in 2D">

  ! Mark sub-element for generic recoarsening. Note that the detailed
  ! recoarsening strategy must be determined form the element state.
  integer, parameter :: MARK_CRS_GENERIC            = -1

  ! Mark inner triangle of a 1-tria : 4-tria refinement for
  ! recoarsening into the macro element
  integer, parameter :: MARK_CRS_4TRIA1TRIA         = -2

  ! Mark inner triangle of a 1-tria : 4-tria refinement for
  ! recoarsening into two green triangles, whereby the first vertex
  ! if the inner triangle is connected to the opposite vertex
  integer, parameter :: MARK_CRS_4TRIA2TRIA_1       = -3

  ! Mark inner triangle of a 1-tria : 4-tria refinement for
  ! recoarsening into two green triangles, whereby the second vertex
  ! if the inner triangle is connected to the opposite vertex
  integer, parameter :: MARK_CRS_4TRIA2TRIA_2       = -4

  ! Mark inner triangle of a 1-tria : 4-tria refinement for
  ! recoarsening into two green triangles, whereby the third vertex
  ! if the inner triangle is connected to the opposite vertex
  integer, parameter :: MARK_CRS_4TRIA2TRIA_3       = -5

  ! Mark inner green triangle of a 1-quad : 3-tria refinement for
  ! recoarsening into the macro quadrilateral together with its neighbors
  integer, parameter :: MARK_CRS_3TRIA1QUAD         = -6

  ! Mark (left) green triangle of a 1-tria : 2-tria refinement for 
  ! recoarsening into the macro triangle together with its right neighbor
  integer, parameter :: MARK_CRS_2TRIA1TRIA         = -7

  ! Mark "most inner" green triangle of a 1-quad : 4-tria refinement for
  ! recoarsening into the macro quadrilateral together with its three neighbors
  integer, parameter :: MARK_CRS_4TRIA1QUAD         = -8

  ! Mark "most inner" green triangle of a 1-quad : 4-tria refinement for
  ! conversion into three triangles keeping the left neighboring triangle
  integer, parameter :: MARK_CRS_4TRIA3TRIA_LEFT    = -9

  ! Mark "most inner" green triangle of a 1-quad : 4-tria refinement for
  ! conversion into three triangles keeping the right neighboring triangle
  integer, parameter :: MARK_CRS_4TRIA3TRIA_RIGHT   = -10

  ! Mark green quadrilateral of a 1-quad : 2-quad refinement for
  ! recoarsening into the macro quadrilateral together with its neighbor
  integer, parameter :: MARK_CRS_2QUAD1QUAD         = -11
  
  ! Mark green quadrilateral of a 1-quad : 2-quad refinement for
  ! conversion into three triangles keeping the second vertex
  integer, parameter :: MARK_CRS_2QUAD3TRIA         = -12

  ! Mark red quadrilateral of a 1-quad : 4-quad refinement for 
  ! recoarsening into the macro quadrilateral together with its neighbors
  integer, parameter :: MARK_CRS_4QUAD1QUAD         = -13

  ! Mark red quadrilateral of a 1-quad : 4-quad refinement for 
  ! recoarsening into two quadrilaterals
  integer, parameter :: MARK_CRS_4QUAD2QUAD         = -14

  ! Mark red quadrilateral of a 1-quad : 4-quad refinement for 
  ! recoarsening into three triangles
  integer, parameter :: MARK_CRS_4QUAD3TRIA         = -15

  ! Mark red quadrilateral of a 1-quad : 4-quad refinement for 
  ! recoarsening into four triangles
  integer, parameter :: MARK_CRS_4QUAD4TRIA         = -16
  
  ! Mark for keeping element 'as is'
  integer, parameter :: MARK_ASIS                   = 0
  integer, parameter :: MARK_ASIS_TRIA              = 0
  integer, parameter :: MARK_ASIS_QUAD              = 1

  ! Mark element for 1-tria : 2-tria refinement along first edge
  integer, parameter :: MARK_REF_TRIA2TRIA_1        = 2

  ! Mark element for 1-tria : 2-tria refinement along second edge
  integer, parameter :: MARK_REF_TRIA2TRIA_2        = 4

  ! Mark element for 1-tria : 2-tria refinement along third edge
  integer, parameter :: MARK_REF_TRIA2TRIA_3        = 8

  ! Mark element for 1-tria : 3-tria refinement along first and second edge
  integer, parameter :: MARK_REF_TRIA3TRIA_12       = 6

  ! Mark element for 1-tria : 3-tria refinement along second and third edge
  integer, parameter :: MARK_REF_TRIA3TRIA_23       = 12

  ! Mark element for 1-tria : 3-tria refinement along first and third edge
  integer, parameter :: MARK_REF_TRIA3TRIA_13       = 10

  ! Mark element for 1-tria : 4-tria red refinement
  integer, parameter :: MARK_REF_TRIA4TRIA          = 14

  ! Mark element for 1-quad : 3-tria refinement along first edge
  integer, parameter :: MARK_REF_QUAD3TRIA_1        = 3
  
  ! Mark element for 1-quad : 3-tria refinement along second edge
  integer, parameter :: MARK_REF_QUAD3TRIA_2        = 5
  
  ! Mark element for 1-quad : 3-tria refinement along third edge
  integer, parameter :: MARK_REF_QUAD3TRIA_3        = 9
  
  ! Mark element for 1-quad : 3-tria refinement along fourth edge
  integer, parameter :: MARK_REF_QUAD3TRIA_4        = 17

  ! Mark element for 1-quad : 4-tria refinement along first and second edge
  integer, parameter :: MARK_REF_QUAD4TRIA_12       = 7

  ! Mark element for 1-quad : 4-tria refinement along second and third edge
  integer, parameter :: MARK_REF_QUAD4TRIA_23       = 13

  ! Mark element for 1-quad : 4-tria refinement along third and fourth edge
  integer, parameter :: MARK_REF_QUAD4TRIA_34       = 25

  ! Mark element for 1-quad : 4-tria refinement along first and fourth edge
  integer, parameter :: MARK_REF_QUAD4TRIA_14       = 19

  ! Mark element for 1-quad : 4-quad red refinement
  integer, parameter :: MARK_REF_QUAD4QUAD          = 31

  ! Mark element for 1-quad : 2-quad refinement along first and third edge
  integer, parameter :: MARK_REF_QUAD2QUAD_13       = 11

  ! Mark element for 1-quad : 2-quad refinement along second and fourth edge
  integer, parameter :: MARK_REF_QUAD2QUAD_24       = 21

  ! Mark element for 1-quad blue refinement
  integer, parameter :: MARK_REF_QUADBLUE_412       = 23
  integer, parameter :: MARK_REF_QUADBLUE_234       = 29
  integer, parameter :: MARK_REF_QUADBLUE_123       = 15
  integer, parameter :: MARK_REF_QUADBLUE_341       = 27
  
!</constantblock>

!<constantblock description="Constants for element states in 2D">

  ! Triangle from the root triangulation
  integer, parameter :: STATE_TRIA_ROOT             = 0

  ! Inner triangle of a 1-tria : 4-tria red refinement
  integer, parameter :: STATE_TRIA_REDINNER         = 14

  ! Outer triangle of a 1-tria : 4-tria red refinement or
  ! outer/inner triangle of 1-quad : 4-tria refinement
  integer, parameter :: STATE_TRIA_OUTERINNER       = 4
  integer, parameter :: STATE_TRIA_OUTERINNER1      = 2   ! only theoretically
  integer, parameter :: STATE_TRIA_OUTERINNER2      = 8   ! only theoretically

  ! Inner triangle of a 1-quad : 3-tria refinement
  integer, parameter :: STATE_TRIA_GREENINNER       = -2

  ! Outer trignale of a green refinement
  integer, parameter :: STATE_TRIA_GREENOUTER_LEFT  = -4
  integer, parameter :: STATE_TRIA_GREENOUTER_RIGHT = -8

  ! Quadrilateral form the root triangulation
  integer, parameter :: STATE_QUAD_ROOT             = 1

  ! Quadrilateral of a 1-quad : 4-quad red refinement
  integer, parameter :: STATE_QUAD_RED1             = 25
  integer, parameter :: STATE_QUAD_RED2             = 19
  integer, parameter :: STATE_QUAD_RED3             = 7
  integer, parameter :: STATE_QUAD_RED4             = 13

  ! Quadrilateral of a 1-quad : 2-quad refinement
  integer, parameter :: STATE_QUAD_HALF1            = 5
  integer, parameter :: STATE_QUAD_HALF2            = 21
  
!</constantblock>

!<constantblock description="Global constants for grid modification operations in 2D">

  ! Operation identifier for initialization of callback function
  integer, parameter, public :: HADAPT_OPR_INITCALLBACK     = -1

  ! Operation identifier for finalization of callback function
  integer, parameter, public :: HADAPT_OPR_DONECALLBACK     = -2

  ! Operation identifier for adjustment of vertex dimension
  integer, parameter, public :: HADAPT_OPR_ADJUSTVERTEXDIM  = 1

  ! Operation identifier for vertex insertion at edge midpoint
  integer, parameter, public :: HADAPT_OPR_INSERTVERTEXEDGE = 2

  ! Operation identifier for vertex insertion at element centroid
  integer, parameter, public :: HADAPT_OPR_INSERTVERTEXCENTR= 3

  ! Operation identifier for vertex removal
  integer, parameter, public :: HADAPT_OPR_REMOVEVERTEX     = 4

  ! Operation identifier for refinment: 1-tria : 2-tria
  integer, parameter, public :: HADAPT_OPR_REF_TRIA2TRIA    = 5

  ! Operation identifier for refinment: 1-tria : 3-tria
  integer, parameter, public :: HADAPT_OPR_REF_TRIA3TRIA12  = 6
  integer, parameter, public :: HADAPT_OPR_REF_TRIA3TRIA23  = 7
 
  ! Operation identifier for refinment: 1-tria : 4-tria
  integer, parameter, public :: HADAPT_OPR_REF_TRIA4TRIA    = 8

  ! Operation identifier for refinment: 1-quad : 2-quad
  integer, parameter, public :: HADAPT_OPR_REF_QUAD2QUAD    = 9
  
  ! Operation identifier for refinment: 1-quad : 3-tria
  integer, parameter, public :: HADAPT_OPR_REF_QUAD3TRIA    = 10

  ! Operation identifier for refinment: 1-quad : 4-tria
  integer, parameter, public :: HADAPT_OPR_REF_QUAD4TRIA    = 11

  ! Operation identifier for refinment: 1-quad : 4-quad
  integer, parameter, public :: HADAPT_OPR_REF_QUAD4QUAD    = 12

  ! Operation identifier for conversion: 2-tria : 4-tria
  integer, parameter, public :: HADAPT_OPR_CVT_TRIA2TRIA    = 13

  ! Operation identifier for conversion: 2-quad : 4-tria
  integer, parameter, public :: HADAPT_OPR_CVT_QUAD2QUAD    = 14

  ! Operation identifier for conversion: 3-tria : 4-quad
  integer, parameter, public :: HADAPT_OPR_CVT_QUAD3TRIA    = 15

  ! Operation identifier for conversion: 4-tria : 4-quad
  integer, parameter, public :: HADAPT_OPR_CVT_QUAD4TRIA    = 16

  ! Operation identifier for coarsening: 2-tria : 1-tria
  integer, parameter, public :: HADAPT_OPR_CRS_2TRIA1TRIA   = 17

  ! Operation identifier for coarsening: 4-tria : 1-tria
  integer, parameter, public :: HADAPT_OPR_CRS_4TRIA1TRIA   = 18

  ! Operation identifier for coarsening: 4-tria : 2-tria
  integer, parameter, public :: HADAPT_OPR_CRS_4TRIA2TRIA1  = 19
  integer, parameter, public :: HADAPT_OPR_CRS_4TRIA2TRIA2  = 20
  integer, parameter, public :: HADAPT_OPR_CRS_4TRIA2TRIA3  = 21

  ! Operation identifier for coarsening: 4-quad : 1-quad
  integer, parameter, public :: HADAPT_OPR_CRS_4QUAD1QUAD   = 22

  ! Operation identifier for coarsening: 4-quad : 2-quad
  integer, parameter, public :: HADAPT_OPR_CRS_4QUAD2QUAD   = 23

  ! Operation identifier for coarsening: 4-quad : 3-tria
  integer, parameter, public :: HADAPT_OPR_CRS_4QUAD3TRIA   = 24

  ! Operation identifier for coarsening: 4-quad : 4-tria
  integer, parameter, public :: HADAPT_OPR_CRS_4QUAD4TRIA   = 25

  ! Operation identifier for coarsening: 2-quad : 1-quad
  integer, parameter, public :: HADAPT_OPR_CRS_2QUAD1QUAD   = 26

  ! Operation identifier for coarsening: 2-quad : 3-tria
  integer, parameter, public :: HADAPT_OPR_CRS_2QUAD3TRIA   = 27

  ! Operation identifier for coarsening: 3-tria : 1-quad
  integer, parameter, public :: HADAPT_OPR_CRS_3TRIA1QUAD   = 28

  ! Operation identifier for coarsening: 4-tria : 1-quad
  integer, parameter, public :: HADAPT_OPR_CRS_4TRIA1QUAD   = 29

  ! Operation identifier for coarsening: 4-tria : 3-tria
  integer, parameter, public :: HADAPT_OPR_CRS_4TRIA3TRIA2  = 30
  integer, parameter, public :: HADAPT_OPR_CRS_4TRIA3TRIA3  = 31

!</constantblock>

!</constants>

  ! ***************************************************************************
  ! ***************************************************************************
  ! ***************************************************************************

  interface add_vertex2D
    module procedure add_vertex_atEdgeMidpoint2D
    module procedure add_vertex_atElementCenter2D
  end interface

  interface replace_element2D
    module procedure replace_elementTria
    module procedure replace_elementQuad
  end interface

  interface add_element2D
    module procedure add_elementTria
    module procedure add_elementQuad
  end interface
  
  interface update_ElementNeighbors2D
    module procedure update_ElemNeighb2D_1to2
    module procedure update_ElemNeighb2D_2to2
  end interface

contains

  ! ***************************************************************************
  ! ***************************************************************************
  ! ***************************************************************************

!<subroutine>

  subroutine add_vertex_atEdgeMidpoint2D(rhadapt, i1, i2, e1, i12,&
                                         rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine adds a new vertex at the midpoint of a given egde. 
    ! First, the coordinates of the new vertex are computed and added to
    ! the quadtree. If the new vertex is located at the boundary then its
    ! parametrization is computed and its normal vector is stored in
    ! the boundary data structure.
!</description>

!<input>
    ! First point of edge on which new vertex will be added
    integer(PREC_VERTEXIDX), intent(IN)         :: i1

    ! Second point of edge on which new vertex will be added
    integer(PREC_VERTEXIDX), intent(IN)         :: i2

    ! Number of the right-adjacent element w.r.t. to the oriented edge (I1,I2)
    integer(PREC_ELEMENTIDX), intent(IN)        :: e1

    ! Callback routines
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>

!<output>
    ! Number of the new vertex located between i1 and i2
    integer(PREC_VERTEXIDX), intent(OUT)        :: i12
!</output>
!</subroutine>

    ! local variables
    real(DP), dimension(NDIM2D) :: Dcoord
    real(DP), dimension(1)      :: Ddata
    real(DP)                    :: x1,y1,x2,y2,dvbdp1,dvbdp2
    integer(PREC_VERTEXIDX),  dimension(3) :: Ivertices
    integer(PREC_ELEMENTIDX), dimension(1) :: Ielements
    integer, dimension(2)       :: Idata
    integer(PREC_QTREEIDX)      :: inode
    integer(PREC_TREEIDX)       :: ipred,ipos
    integer                     :: ibct
    
    ! Get coordinates of edge vertices
    x1 = qtree_getX(rhadapt%rVertexCoordinates2D, i1)
    y1 = qtree_getY(rhadapt%rVertexCoordinates2D, i1)
    x2 = qtree_getX(rhadapt%rVertexCoordinates2D, i2)
    y2 = qtree_getY(rhadapt%rVertexCoordinates2D, i2)

    ! Compute coordinates of new vertex 
    Dcoord = 0.5_DP*(/x1+x2, y1+y2/)

    ! Search for vertex coordinates in quadtree: 
    ! If the vertex already exists, e.g., it was added when the adjacent element
    ! was refined, then nothing needs to be done for this vertex
    if (qtree_searchInQuadtree(rhadapt%rVertexCoordinates2D, Dcoord,&
                               inode, ipos,i12) .eq. QTREE_FOUND) return
    
    ! Otherwise, update number of vertices
    rhadapt%NVT = rhadapt%NVT+1
    i12         = rhadapt%NVT

    ! Set age of vertex
    rhadapt%p_IvertexAge(i12) = &
        1+max(abs(rhadapt%p_IvertexAge(i1)),&
              abs(rhadapt%p_IvertexAge(i2)))
    
    ! Set nodal property
    if (e1 .eq. 0) then
      rhadapt%p_InodalProperty(i12) = rhadapt%p_InodalProperty(i1)
    else
      rhadapt%p_InodalProperty(i12) = 0
    end if
    
    ! Add new entry to vertex coordinates
    call qtree_insertIntoQuadtree(rhadapt%rVertexCoordinates2D, i12, Dcoord, inode)
    
    ! Are we at the boundary?
    if (e1 .eq. 0) then
      ! Increment number of boundary nodes
      rhadapt%NVBD = rhadapt%NVBD+1
      
      ! Get number of boundary component
      ibct = rhadapt%p_InodalProperty(i1)
      
      ! Get parameter values of the boundary nodes
      if (btree_searchInTree(rhadapt%rBoundary(ibct), i1, ipred) .eq. BTREE_NOT_FOUND) then
        call output_line('Unable to find first vertex in boudary data structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'add_vertex_atEdgeMidpoint2D')
        call sys_halt()
      end if
      ipos   = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT, TRIGHT, ipred < 0), abs(ipred))
      dvbdp1 = rhadapt%rBoundary(ibct)%p_DData(BdrValue, ipos)
      
      if (btree_searchInTree(rhadapt%rBoundary(ibct), i2, ipred) .eq. BTREE_NOT_FOUND) then
        call output_line('Unable to find second vertex in boudary data structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'add_vertex_atEdgeMidpoint2D')
        call sys_halt()
      end if
      ipos   = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT, TRIGHT, ipred < 0), abs(ipred))
      dvbdp2 = rhadapt%rBoundary(ibct)%p_DData(BdrValue, ipos)
      
      ! If I2 is last(=first) node on boundary component IBCT round DVBDP2 to next integer
      if (dvbdp2 .le. dvbdp1) dvbdp2 = ceiling(dvbdp1)
      
      ! Add new entry to boundary structure
      Idata = (/i1, i2/)
      Ddata = (/0.5_DP*(dvbdp1+dvbdp2)/)
      call btree_insertIntoTree(rhadapt%rBoundary(ibct), i12,&
                                Idata=Idata, Ddata=Ddata)
    end if
      
    ! Optionally, invoke callback function
    if (present(fcb_hadaptCallback) .and. present(rcollection)) then
      Ivertices = (/i12, i1, i2/)
      Ielements = (/0/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_INSERTVERTEXEDGE,&
                              Ivertices, Ielements)
    end if
  end subroutine add_vertex_atEdgeMidpoint2D

  ! ***************************************************************************
  
!<subroutine>

  subroutine add_vertex_atElementCenter2D(rhadapt, i1, i2, i3, i4, i5,&
                                          rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine adds a new vertex at the center of a given quadtrilateral.
    ! First, the coordinates of the new vertex computed and added to the
    ! quadtree. The new vertex cannot be located at the boundary.
!</description>

!<input>
    ! Four corners of the quadrilateral
    integer(PREC_VERTEXIDX), intent(IN)         :: i1,i2,i3,i4

    ! Callback routine
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>

!<output>
    ! Number of the new vertex
    integer(PREC_VERTEXIDX), intent(OUT)        :: i5
!</output>
!</subroutine>

    ! local variables
    real(DP), dimension(NDIM2D) :: Dcoord
    integer(PREC_ELEMENTIDX), dimension(1) :: Ielements
    integer(PREC_VERTEXIDX), dimension(5)  :: Ivertices
    real(DP) :: x1,y1,x2,y2,x3,y3,x4,y4,x21,y21,x31,y31,x24,y24,alpha
    integer(PREC_QTREEIDX) :: inode,ipos
    
    ! Compute coordinates of new vertex
    x1 = qtree_getX(rhadapt%rVertexCoordinates2D, i1)
    y1 = qtree_getY(rhadapt%rVertexCoordinates2D, i1)
    x2 = qtree_getX(rhadapt%rVertexCoordinates2D, i2)
    y2 = qtree_getY(rhadapt%rVertexCoordinates2D, i2)
    x3 = qtree_getX(rhadapt%rVertexCoordinates2D, i3)
    y3 = qtree_getY(rhadapt%rVertexCoordinates2D, i3)
    x4 = qtree_getX(rhadapt%rVertexCoordinates2D, i4)
    y4 = qtree_getY(rhadapt%rVertexCoordinates2D, i4)

    x21 = x2-x1; x31 = x3-x1; x24 = x2-x4
    y21 = y2-y1; y31 = y3-y1; y24 = y2-y4
    alpha = (x21*y24-y21*x24)/(x31*y24-y31*x24)
    
    Dcoord = (/x1+alpha*x31, y1+alpha*y31/)

    ! Search for vertex coordinates in quadtree
    if (qtree_searchInQuadtree(rhadapt%rVertexCoordinates2D, Dcoord,&
                               inode, ipos, i5) .eq. QTREE_NOT_FOUND) then
      
      ! Update number of vertices
      rhadapt%NVT = rhadapt%NVT+1
      i5          = rhadapt%NVT
      
      ! Set age of vertex
      rhadapt%p_IvertexAge(I5) = &
          1+max(abs(rhadapt%p_IvertexAge(i1)),&
                abs(rhadapt%p_IvertexAge(i2)),&
                abs(rhadapt%p_IvertexAge(i3)),&
                abs(rhadapt%p_IvertexAge(i4)))

      ! Set nodal property
      rhadapt%p_InodalProperty(i5) = 0
      
      ! Add new entry to vertex coordinates
      call qtree_insertIntoQuadtree(rhadapt%rVertexCoordinates2D,&
                                    i5, Dcoord, inode)
    end if
    
    ! Optionally, invoke callback function
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i5, i1, i2, i3, i4/)
      Ielements = (/0/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_INSERTVERTEXCENTR,&
                              Ivertices, Ielements)
    end if
  end subroutine add_vertex_atElementCenter2D

  ! ***************************************************************************

!<subroutine>
  
  subroutine remove_vertex2D(rhadapt, ivt, ivtReplace)
  
!<description>
    ! This subroutine removes an existing vertex from the adaptivity structure
    ! and moves the last vertex at its position. The number of the replacement
    ! vertex is returned as ivtReplace. If the vertex to be replace is the last
    ! vertex then ivtReplace=0 is returned on output.
!</description>

!<input>
    ! Number of the vertex to be deleted
    integer(PREC_VERTEXIDX), intent(IN) :: ivt

    
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT) :: rhadapt
!</inputoutput>

!<output>
    ! Number of the vertex to replace the deleted one
    integer(PREC_VERTEXIDX), intent(OUT) :: ivtReplace
!</output>
!</subroutine>

    ! local variables
    integer(PREC_VERTEXIDX) :: i1,i2
    integer(PREC_TREEIDX)   :: ipred,ipos
    integer :: ibct

    ! Remove vertex from coordinates and get number of replacement vertex
    if (qtree_deleteFromQuadtree(rhadapt%rVertexCoordinates2D,&
                                 ivt, ivtReplace) .eq. QTREE_NOT_FOUND) then
      call output_line('Unable to delete vertex coordinates!',&
          OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
      call sys_halt()
    end if
    
    ! Decrease number of vertices by one
    rhadapt%NVT = rhadapt%NVT-1
    
    ! If IVT is a boundary node remove it from the boundary and
    ! connect its boundary neighbors with each other
    ibct = rhadapt%p_InodalProperty(ivt)
    
    ! Are we at the boundary?
    if (ibct .ne. 0) then
      
      ! Find position of vertex IVT in boundary array
      if (btree_searchInTree(rhadapt%rBoundary(ibct),&
                             ivt, ipred) .eq. BTREE_NOT_FOUND) then
        call output_line('Unable to find vertex in boundary data structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
        call sys_halt()
      end if
      ipos = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT,TRIGHT, ipred < 0), abs(ipred))
      
      ! Get the two boundary neighbors: I1 <- IVT -> I2
      i1 = rhadapt%rBoundary(ibct)%p_IData(BdrPrev, ipos)
      i2 = rhadapt%rBoundary(ibct)%p_IData(BdrNext, ipos)
      
      ! Connect the boundary neighbors with each other: I1 <=> I2
      ! First, set I2 as next neighboring of I1
      if (btree_searchInTree(rhadapt%rBoundary(ibct),&
                             i1, ipred) .eq. BTREE_NOT_FOUND) then
        call output_line('Unable to find left neighboring vertex in boundary data structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
        call sys_halt()
      end if
      ipos = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT,TRIGHT, ipred < 0), abs(ipred))
      rhadapt%rBoundary(ibct)%p_IData(BdrNext, ipos) = i2
      
      ! Second, set I1 as previous neighbor of I2
      if (btree_searchInTree(rhadapt%rBoundary(ibct),&
                             i2, ipred) .eq. BTREE_NOT_FOUND) then
        call output_line('Unable to find right neighboring vertex in boundary data structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
        call sys_halt()
      end if
      ipos = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT,TRIGHT, ipred < 0), abs(ipred))
      rhadapt%rBoundary(ibct)%p_IData(BdrPrev, ipos) = i1
      
      ! And finally, delete IVT from the boundary
      if (btree_deleteFromTree(rhadapt%rBoundary(ibct),&
                               ivt) .eq. BTREE_NOT_FOUND) then
        call output_line('Unable to delete vertex from boundary data structure!',&
            OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
        call sys_halt()
      end if
    end if
    
    ! If IVT is not the last node then copy the data for vertex IVTREPLACE
    ! to IVT and prepare IVTREPLACE for elimination
    if (ivt < ivtReplace) then
      
      ! If IVTREPLACE is a boundary node then remove IVTREPLACE from the boundary
      ! vector, insert IVT into the boundary vector instead, and connect the
      ! boundary neighbors of IVTREPLACE with IVT
      ibct = rhadapt%p_InodalProperty(ivtReplace)

      ! Are we at the boundary?
      if (ibct .ne. 0) then

        if (btree_searchInTree(rhadapt%rBoundary(ibct),&
                               ivtReplace, ipred) .eq. BTREE_NOT_FOUND) then
          call output_line('Unable to find replacement vertex in boundary data structure!',&
              OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
          call sys_halt()
        end if
        ipos = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT,TRIGHT, ipred < 0), abs(ipred))
        
        ! Insert IVT into the boundary vector
        call btree_insertIntoTree(rhadapt%rBoundary(ibct), ivt,&
                                  Idata=rhadapt%rBoundary(ibct)%p_IData(:, ipos),&
                                  Ddata=rhadapt%rBoundary(ibct)%p_DData(:, ipos))
        
        ! Get the two boundary neighbors: I1 <- IVTREPLACE -> I2
        i1 = rhadapt%rBoundary(ibct)%p_IData(BdrPrev, ipos)
        i2 = rhadapt%rBoundary(ibct)%p_IData(BdrNext, ipos)
        
        ! Connect the boundary neighbors with IVT: I1 <- IVT -> I2
        ! First, set IVT as next neighbor of I1
        if (btree_searchInTree(rhadapt%rBoundary(ibct),&
                               i1, ipred) .eq. BTREE_NOT_FOUND) then
          call output_line('Unable to find left neighboring vertex in boundary data structure!',&
              OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
          call sys_halt()
        end if
        ipos = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT,TRIGHT, ipred < 0), abs(ipred))
        rhadapt%rBoundary(ibct)%p_IData(BdrNext, ipos) = ivt
        
        ! Second, set IVT as previous neighbor of I2
        if (btree_searchInTree(rhadapt%rBoundary(ibct),&
                               i2, ipred) .eq. BTREE_NOT_FOUND) then
          call output_line('Unable to find right neighboring vertex in boundary data structure!',&
              OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
          call sys_halt()
        end if
        ipos = rhadapt%rBoundary(ibct)%p_Kchild(merge(TLEFT,TRIGHT, ipred < 0), abs(ipred))
        rhadapt%rBoundary(ibct)%p_IData(BdrPrev, ipos) = ivt
        
        ! Finally, delete IVTREPLACE from the boundary
        if (btree_deleteFromTree(rhadapt%rBoundary(ibct),&
                                 ivtReplace) .eq. BTREE_NOT_FOUND) then
          call output_line('Unable to delete vertex from the boundary data structure!',&
              OU_CLASS_ERROR,OU_MODE_STD,'remove_vertex2D')
          call sys_halt()
        end if
      end if
      
      ! Copy data from node IVTREPLACE to node IVT
      rhadapt%p_InodalProperty(ivt) = rhadapt%p_InodalProperty(ivtReplace)
      rhadapt%p_IvertexAge(ivt)     = rhadapt%p_IvertexAge(ivtReplace)

      ! Clear data for node IVTREPLACE
      rhadapt%p_InodalProperty(ivtReplace) = 0
      rhadapt%p_IvertexAge(ivtReplace)     = 0
      
    else

      ! IVT is the last vertex of the adaptivity structure
      ivtReplace = 0

      ! Clear data for node IVT
      rhadapt%p_InodalProperty(ivt) = 0
      rhadapt%p_IvertexAge(ivt)     = 0
      
    end if
  end subroutine remove_vertex2D

  ! ***************************************************************************

!<subroutine>

  subroutine replace_elementTria(rhadapt, ipos, i1, i2, i3,&
                                 e1, e2, e3, e4, e5, e6)
  
!<description>
    ! This subroutine replaces the vertices and adjacent elements for
    ! a given triangular element
!</description>

!<input>
    ! position number of the element in dynamic data structure
    integer(PREC_TREEIDX), intent(IN)    :: ipos

    ! numbers of the element nodes
    integer(PREC_VERTEXIDX), intent(IN)  :: i1,i2,i3

    ! numbers of the surrounding elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e1,e2,e3

    ! numbers of the surrounding mid-elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e4,e5,e6
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT)  :: rhadapt
!</inputoutput>
!</subroutine

    ! Replace triangular element
    rhadapt%p_IverticesAtElement(:,ipos)      = (/i1,i2,i3,0/)
    rhadapt%p_IneighboursAtElement(:,ipos)    = (/e1,e2,e3,0/)
    rhadapt%p_ImidneighboursAtElement(:,ipos) = (/e4,e5,e6,0/)    
  end subroutine replace_elementTria

  ! ***************************************************************************
  
!<subroutine>

  subroutine replace_elementQuad(rhadapt, ipos, i1, i2, i3, i4,&
                                 e1, e2, e3, e4, e5, e6, e7, e8)
  
!<description>
    ! This subroutine replaces the vertices and adjacent elements for
    ! a given quadrilateral element
!</description>

!<input>
    ! position number of the element in dynamic data structure
    integer(PREC_TREEIDX), intent(IN)    :: ipos

    ! numbers of the element nodes
    integer(PREC_VERTEXIDX), intent(IN)  :: i1,i2,i3,i4

    ! numbers of the surrounding elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e1,e2,e3,e4

    ! numbers of the surrounding mid-elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e5,e6,e7,e8
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT)     :: rhadapt
!</inputoutput>
!</subroutine

    ! Replace quadrilateral element
    rhadapt%p_IverticesAtElement(:,ipos)      = (/i1,i2,i3,i4/)
    rhadapt%p_IneighboursAtElement(:,ipos)    = (/e1,e2,e3,e4/)
    rhadapt%p_ImidneighboursAtElement(:,ipos) = (/e5,e6,e7,e8/)
  end subroutine replace_elementQuad

  ! ***************************************************************************

!<subroutine>

  subroutine add_elementTria(rhadapt, i1, i2, i3, e1, e2, e3, e4, e5, e6)

!<description>
    ! This subroutine adds a new element connected to three vertices 
    ! and surrounded by three adjacent elements
!</description>

!<input>
    ! numbers of the element nodes
    integer(PREC_VERTEXIDX), intent(IN)  :: i1,i2,i3

    ! numbers of the surrounding elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e1,e2,e3

    ! numbers of the surrounding mid-elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e4,e5,e6
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT)     :: rhadapt
!</inputoutput>
!</subroutine
    
    ! Increase number of elements and number of triangles
    rhadapt%NEL = rhadapt%NEL+1
    rhadapt%InelOfType(TRIA_NVETRI2D) = rhadapt%InelOfType(TRIA_NVETRI2D)+1

    rhadapt%p_IverticesAtElement(:,rhadapt%NEL)      = (/i1,i2,i3,0/)
    rhadapt%p_IneighboursAtElement(:,rhadapt%NEL)    = (/e1,e2,e3,0/)
    rhadapt%p_ImidneighboursAtElement(:,rhadapt%NEL) = (/e4,e5,e6,0/)
  end subroutine add_elementTria

  ! ***************************************************************************

!<subroutine>
  
  subroutine add_elementQuad(rhadapt, i1, i2, i3, i4,&
                             e1, e2, e3, e4, e5, e6, e7, e8)

!<description>
    ! This subroutine adds a new element connected to four vertices 
    ! and surrounded by four adjacent elements
!</description>

!<input>
    ! numbers of the element nodes
    integer(PREC_VERTEXIDX), intent(IN)  :: i1,i2,i3,i4

    ! numbers of the surrounding elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e1,e2,e3,e4

    ! numbers of the surrounding mid-elements
    integer(PREC_ELEMENTIDX), intent(IN) :: e5,e6,e7,e8
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT)     :: rhadapt
!</inputoutput>
!</subroutine
    
    ! Increase number of elements and number of quadrilaterals
    rhadapt%NEL = rhadapt%NEL+1
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)+1

    rhadapt%p_IverticesAtElement(:,rhadapt%NEL)      = (/i1,i2,i3,i4/)
    rhadapt%p_IneighboursAtElement(:,rhadapt%NEL)    = (/e1,e2,e3,e4/)
    rhadapt%p_ImidneighboursAtElement(:,rhadapt%NEL) = (/e5,e6,e7,e8/)
  end subroutine add_elementQuad

  ! ***************************************************************************

!<subroutine>

  subroutine remove_element2D(rhadapt, iel, ielReplace)
  
!<description>
    ! This subroutine removes an existing element and moves the last
    ! element of the adaptation data structure to its position.
    ! The routine returns the former number ielReplace of the last 
    ! element. If iel is the last element, then ielReplace=0 is returned.
!</description>

!<input>
    ! Number of the element that should be removed
    integer(PREC_ELEMENTIDX), intent(IN)  :: iel
!</input>

!<inputoutput>
    ! Adaptivity structure
    type(t_hadapt), intent(INOUT)      :: rhadapt
!</inputoutput>

!<output>
    ! Former number of the replacement element
    integer(PREC_ELEMENTIDX), intent(OUT) :: ielReplace
!</output>
!</subroutine>

    ! local variables
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_VERTEXIDX)    :: ivt
    integer(PREC_ELEMENTIDX)   :: jel,jelmid
    integer :: ive,jve
    logical :: bfound

    ! Which kind of element are we?
    select case(hadapt_getNVE(rhadapt, iel))
    case(TRIA_NVETRI2D)
      rhadapt%InelOfType(TRIA_NVETRI2D) = rhadapt%InelOfType(TRIA_NVETRI2D)-1

    case(TRIA_NVEQUAD2D)
      rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)-1

    case DEFAULT
      call output_line('Invalid element type!',&
          OU_CLASS_ERROR,OU_MODE_STD,'remove_element2D')
      call sys_halt()
    end select

    ! Replace element by the last element and delete last element
    ielReplace = rhadapt%NEL

    ! Check if we are the last element
    if (iel .ne. ielReplace) then
      
      ! Element is not the last one. Then the element that should be removed must
      ! have a smaller element number. If this is not the case, something is wrong.
      if (iel > ielReplace) then
        call output_line('Number of replacement element must not be smaller than that of&
            & the removed elements!',OU_CLASS_ERROR,OU_MODE_STD,'remove_element2D')
        call sys_halt()
      end if

      ! The element which formally was labeled ielReplace is now labeled IEL.
      ! This modification must be updated in the list of adjacent element
      ! neighbors of all surrounding elements. Moreover, the modified element
      ! number must be updated in the "elements-meeting-at-vertex" lists of the
      ! corner nodes of element IEL. Both operations are performed below.
      update: do ive = 1, hadapt_getNVE(rhadapt, ielReplace)
        
        ! Get vertex number of corner node
        ivt = rhadapt%p_IverticesAtElement(ive, ielReplace)

        ! Start with first element in "elements-meeting-at-vertex" list
        ipos = arrlst_getNextInArraylist(rhadapt%rElementsAtVertex, ivt, .true.)
        elements: do while(ipos .gt. ARRLST_NULL)
          
          ! Check if element number corresponds to the replaced element
          if (rhadapt%rElementsAtVertex%p_IData(ipos) .eq. ielReplace) then
            rhadapt%rElementsAtVertex%p_IData(ipos) = iel
            exit elements
          end if
          
          ! Proceed to next element in list
          ipos = arrlst_getNextInArraylist(rhadapt%rElementsAtVertex, ivt, .false.)
        end do elements

                
        ! Get element number of element JEL and JELMID which 
        ! are (mid-)adjacent to element ielReplace
        jel    = rhadapt%p_IneighboursAtElement(ive, ielReplace)
        jelmid = rhadapt%p_ImidneighboursAtElement(ive, ielReplace)

        
        ! Do we have different neighbours along the first part and the
        ! second part of the common edge?
        if (jel .ne. jelmid) then
          ! There are two elements sharing the common edge with ielReplace. 
          ! We have to find the position of element ielReplace in the lists
          ! of (mid-)adjacent elements for both element JEL and JELMID
          ! seperately. If we are at the boundary of ir element IEL to be 
          ! removed is adjacent to element ielReplace, the skip this edge.
          bfound = .false.
          
          ! Find position of replacement element in adjacency list of 
          ! element JEL and update the entry to new element number IEL
          if (jel .eq. 0 .or. jel .eq. iel) then
            bfound = .true.
          else
            adjacent1: do jve = 1, hadapt_getNVE(rhadapt, jel)
              if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. ielReplace) then
                rhadapt%p_IneighboursAtElement(jve, jel)    = iel
                rhadapt%p_ImidneighboursAtElement(jve, jel) = iel
                bfound = .true.
                exit adjacent1
              end if
            end do adjacent1
          end if
          
          ! Find position of replacement element in adjacentcy list of
          ! element JELMID and update the entry to new element number IEL
          if (jelmid .eq. 0 .or. jelmid .eq. iel) then
            bfound = bfound .and. .true.
          else
            adjacent2: do jve = 1, hadapt_getNVE(rhadapt, jelmid)
              if (rhadapt%p_IneighboursAtElement(jve, jelmid) .eq. ielReplace) then
                rhadapt%p_IneighboursAtElement(jve, jelmid)    = iel
                rhadapt%p_ImidneighboursAtElement(jve, jelmid) = iel
                bfound = bfound .and. .true.
                exit adjacent2
              end if
            end do adjacent2
          end if

        else
          ! There is only one element sharing the common edge with ielReplace.
          ! If we are at he boundary or if element IEL to be removed is
          ! adjacent to element ielReplace, then skip this edge.
          if (jel .eq. 0 .or. jel .eq. iel) cycle update

          ! We have to consider two possible situations. The neighbouring element
          ! JEL can be completely aligned with element ielReplace so that the
          ! element number must be updated in the list of adjacent and mid-
          ! adjacent elements. On the other hand, element JEL can share one
          ! half of the common edge with element ielReplace and the other half-
          ! edge with another element. In this case, the number ielReplace can
          ! only be found in either the list of adjacent or mid-adjacent elements.
          bfound = .false.
          adjacent3: do jve = 1, hadapt_getNVE(rhadapt, jel)
            if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. ielReplace) then
              rhadapt%p_IneighboursAtElement(jve, jel) = iel
              bfound = bfound .or. .true.
            end if

            if (rhadapt%p_ImidneighboursAtElement(jve, jel) .eq. ielReplace) then
              rhadapt%p_ImidneighboursAtElement(jve, jel) = iel
              bfound = bfound .or. .true.
            end if
            
            if (bfound) exit adjacent3
          end do adjacent3
          
        end if

        ! If the element could not be found, something is wrong
        if (.not.bfound) then
          call output_line('Unable to update element neighbor!',&
              OU_CLASS_ERROR,OU_MODE_STD,'remove_element2D')         
          call sys_halt()
        end if
        
      end do update
      
      ! Copy data from element ielReplace to element IEL
      rhadapt%p_IverticesAtElement(:,iel) =&
          rhadapt%p_IverticesAtElement(:,ielReplace)
      rhadapt%p_IneighboursAtElement(:,iel) =&
          rhadapt%p_IneighboursAtElement(:,ielReplace)
      rhadapt%p_ImidneighboursAtElement(:,iel) =&
          rhadapt%p_ImidneighboursAtElement(:,ielReplace)
      
    else

      ! Element iel is the last element
      ielReplace = 0
    end if

    ! Decrease number of elements
    rhadapt%NEL = rhadapt%NEL-1
  end subroutine remove_element2D

  ! ***************************************************************************

!<subroutine>
  
  subroutine update_ElemNeighb2D_1to2(rhadapt, jel, jelmid,&
                                      iel0, iel, ielmid)

!<description>
    ! This subroutine updates the list of elements adjacent to another 
    ! element and the list of elements mid-adjacent to another element.
    !
    ! The situation is as follows:
    !
    !  +---------------------+            +---------------------+
    !  |                     |            |          .          |
    !  |                     |            |          .          |
    !  |        IEL0         |            |  IELMID  .    IEL   |
    !  |                     |            |          .          |
    !  |                     |            |          .          |
    !  +---------------------+    --->    +----------+----------+
    !  |          .          |            |          .          |
    !  |          .          |            |          .          |
    !  |    JEL   .  JELMID  |            |   JEL    .  JELMID  |
    !  |          .          |            |          .          |
    !  |          .          |            |          .          |
    !  +---------------------+            +---------------------+
    !
    ! "Sitting" on element IEL0 we want to update the element lists:
    !
    ! 1) If IEL0 is located at the boundary then nothing needs to be done.
    ! 2) If the adjacent element has not been subdivided, that is,
    !    JEL = JELMID then it suffices to update its adjacency
    !    list for the entry IEL0 adopting the values IEL and IELMID.
    ! 3) If the adjacent element has been subdivided, that is,
    !    JEL != JELMID then the adjacency list if each of these two 
    !    elements is updated by the value IEL and IELMID, respectively.
!</description>

!<input>
    ! Number of the neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: jel

    ! Number of the mid-neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: jelmid

    ! Number of the updated macro-element
    integer(PREC_ELEMENTIDX), intent(IN) :: iel0

    ! Number of the new neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Number of the new mid-neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: ielmid
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT) :: rhadapt
!</inputoutput>
!</subroutine>
    
    ! local variables
    integer :: ive,nve
    logical :: bfound1,bfound2,bfound

    ! Do nothing for elements adjacent to the boundary
    if (jel .eq. 0 .or. jelmid .eq. 0) return

    ! Check if adjacent and mid-adjacent elements are the same.
    if (jel .eq. jelmid) then

      ! Case 1: Adjacent element has not been subdivided.
      bfound1 = .false.; bfound2 = .false.

      ! What kind of element is neighboring element?
      nve = hadapt_getNVE(rhadapt, jel)
      
      ! Loop over all entries in the list of adjacent and/or mid-adjacent
      ! elements for element JEL and check if the value IEL0 is present. 
      ! The situation may occur that element IEL0 is only adjacent to one
      ! "half" of the edge of element JEL. This may be the case, if element
      ! IEL0 was a green triangle which has already been subdivided in the
      ! marking procedure, whiereby element JEL is marked for red refinement.
      ! In order to consider this situation we are looking for element IEL0
      ! both in the list of adjacent and mid-adjacent elements of JEL.
      ! It suffices if IEL0 is found in one of these lists.
      do ive = 1, nve
        if (rhadapt%p_IneighboursAtElement(ive, jel) .eq. iel0) then
          rhadapt%p_IneighboursAtElement(ive, jel) = iel
          bfound1 = .true.
        end if

        if (rhadapt%p_ImidneighboursAtElement(ive, jel) .eq. iel0) then
          rhadapt%p_ImidneighboursAtElement(ive, jel) = ielmid
          bfound2 = .true.
        end if
        
        ! Exit if IEL0 has been found in the either the adjacency or the 
        ! mid-adjacency list of element JEL.
        bfound = bfound1 .or. bfound2
        if (bfound) exit
      end do

    else
      
      ! Case 2: Adjacent element has already been subdivided.
      bfound1 = .false.; bfound2 = .false.
      
      ! What kind of element is neighboring element 
      nve = hadapt_getNVE(rhadapt, jel)

      ! Loop over all entries in the list of adjacent elements for element
      ! JEL and check if the value IEL0 is present. 
      ! If this is the case,  then update the corrseponding entries in the 
      ! lists of (mid-)adjacent element neighbors.
      do ive = 1, nve
        if (rhadapt%p_IneighboursAtElement(ive, jel) .eq. iel0) then
          rhadapt%p_IneighboursAtElement(ive, jel)    = ielmid
          rhadapt%p_ImidneighboursAtElement(ive, jel) = ielmid
          bfound1 = .true.
          exit
        end if
      end do
      
      ! What kind of element is neighboring element 
      nve = hadapt_getNVE(rhadapt, jelmid)
      
      ! Loop over all entries in the list of adjacent elements for element
      ! JELMID and check if the value IEL0 is present.
      ! If this is the case, then update the corrseponding entries in the 
      ! lists of (mid-)adjacent element neighbors.
      do ive = 1, nve
        if (rhadapt%p_IneighboursAtElement(ive, jelmid) .eq. iel0) then
          rhadapt%p_IneighboursAtElement(ive, jelmid)    = iel
          rhadapt%p_ImidneighboursAtElement(ive, jelmid) = iel
          bfound2 = .true.
          exit
        end if
      end do

      ! Check success of both searches
      bfound = bfound1 .and. bfound2

    end if

    if (.not.bfound) then
      call output_line('Inconsistent adjacency lists!',&
          OU_CLASS_ERROR,OU_MODE_STD,'update_ElemNeighb2D_1to2')
      call sys_halt()
    end if
  end subroutine update_ElemNeighb2D_1to2

  ! ***************************************************************************

!<subroutine>
  
  subroutine update_ElemNeighb2D_2to2(rhadapt, jel, jelmid,&
                                      iel0, ielmid0, iel, ielmid)

!<description>
    ! This subroutine updates the list of elements adjacent to another 
    ! element and the list of elements mid-adjacent to another element.
    !
    ! The situation is as follows:
    !
    !  +---------------------+            +---------------------+
    !  |          .          |            |          .          |
    !  |          .          |            |          .          |
    !  | IELMID0  .   IEL0   |            | IELMID   .   IEL    |
    !  |          .          |            |          .          |
    !  |          .          |            |          .          |
    !  +---------------------+    --->    +----------+----------+
    !  |          .          |            |          .          |
    !  |          .          |            |          .          |
    !  |    JEL   .  JELMID  |            |    JEL   .   JELMID |
    !  |          .          |            |          .          |
    !  |          .          |            |          .          |
    !  +---------------------+            +---------------------+
    !
    ! If IEL0 and IELMID0 are the same, then thins subroutine is identical
    ! to subroutine update_EkemNeighb2D_1to2 which is called in this case
!</description>

!<input>
    ! Number of the neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: jel

    ! Number of the mid-neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: jelmid

    ! Number of the updated macro-element
    integer(PREC_ELEMENTIDX), intent(IN) :: iel0

    ! Number of the updated macro-element
    integer(PREC_ELEMENTIDX), intent(IN) :: ielmid0

    ! Number of the new neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Number of the new mid-neighboring element
    integer(PREC_ELEMENTIDX), intent(IN) :: ielmid
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT) :: rhadapt
!</inputoutput>
!</subroutine>
    
    ! local variables
    integer :: ive,nve
    logical :: bfound1,bfound2,bfound
    
    ! Check if IEL0 and IELMID0 are the same. 
    ! In this case call the corresponding subroutine
    if (iel0 .eq. ielmid0) then
      call update_ElemNeighb2D_1to2(rhadapt, jel, jelmid,&
                                    iel0, iel, ielmid)
      return
    end if

    ! Do nothing for elements adjacent to the boundary
    if (jel .eq. 0 .or. jelmid .eq. 0) return
    
    ! Check if adjacent and mid-adjacent elements are the same.
    if (jel .eq. jelmid) then

      ! Case 1: Adjacent element has not been subdivided, that is, the 
      !         current edge contains a hanging node for the adjacent element.
      bfound = .false.

      ! What kind of element is neighboring element?
      nve = hadapt_getNVE(rhadapt, jel)
      
      ! Loop over all entries in the list of adjacent elements for element 
      ! JEL and check if the value IEL0 or IELMID0 is present. 
      ! If this is the case, then update the corrseponding entries in the 
      ! lists of (mid-)adjacent element neighbors.
      do ive = 1, nve
        if (rhadapt%p_IneighboursAtElement(ive, jel)    .eq. iel0 .and.&
            rhadapt%p_ImidneighboursAtElement(ive, jel) .eq. ielmid0) then
          rhadapt%p_IneighboursAtElement(ive, jel)    = iel
          rhadapt%p_ImidneighboursAtElement(ive, jel) = ielmid
          bfound = .true.
          exit
        end if
      end do
                
    else
      
      ! Case 2: Adjacent element has already been subdivided.
      bfound1 = .false.; bfound2 = .false.
      
      ! What kind of element is neighboring element 
      nve = hadapt_getNVE(rhadapt, jel)

      ! Loop over all entries in the list of adjacent elements for element
      ! JEL and check if the value IELMID0 is present. 
      ! If this is the case,  then update the corrseponding entries in the 
      ! lists of (mid-)adjacent element neighbors.
      do ive = 1, nve
        if (rhadapt%p_IneighboursAtElement(ive, jel) .eq. ielmid0 .and.&
            rhadapt%p_ImidneighboursAtElement(ive, jel) .eq. ielmid0) then
          rhadapt%p_IneighboursAtElement(ive, jel)    = ielmid
          rhadapt%p_ImidneighboursAtElement(ive, jel) = ielmid
          bfound1 = .true.
          exit
        end if
      end do
      
      ! What kind of element is neighboring element 
      nve = hadapt_getNVE(rhadapt, jelmid)
      
      ! Loop over all entries in the list of adjacent elements for element
      ! JELMID and check if the value IEL0 is present.
      ! If this is the case, then update the corrseponding entries in the 
      ! lists of (mid-)adjacent element neighbors.
      do ive = 1, nve
        if (rhadapt%p_IneighboursAtElement(ive, jelmid) .eq. iel0 .and.&
            rhadapt%p_ImidneighboursAtElement(ive, jelmid) .eq. iel0) then
          rhadapt%p_IneighboursAtElement(ive, jelmid)    = iel
          rhadapt%p_ImidneighboursAtElement(ive, jelmid) = iel
          bfound2 = .true.
          exit
        end if
      end do

      bfound = bfound1 .and. bfound2
    end if

    if (.not.bfound) then
      call output_line('Inconsistent adjacency lists!',&
          OU_CLASS_ERROR,OU_MODE_STD,'update_ElemNeighb2D_2to2')
      call sys_halt()
    end if
  end subroutine update_ElemNeighb2D_2to2

  ! ***************************************************************************

!<subroutine>

  subroutine update_AllElementNeighbors2D(rhadapt, iel0, iel)

!<description>
    ! This subroutine updates the list of elements adjacent to another elements.
    ! For all elements jel which are adjacent to the old element iel0 the new 
    ! value iel is stored in the neighbours-at-element structure.
!</description>

!<input>
    ! Number of the element to be updated
    integer(PREC_ELEMENTIDX), intent(IN) :: iel0

    ! New value of the element
    integer(PREC_ELEMENTIDX), intent(IN) :: iel
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT) :: rhadapt
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX) :: jel
    integer :: ive,jve
    logical :: bfound

    ! Check if the old element is still present in the triangulation
    if (iel0 > rhadapt%NEL) then
      return
    end if

    ! Loop over adjacent elements
    adjacent: do ive = 1, hadapt_getNVE(rhadapt, iel0)
      ! Get number of adjacent element
      jel = rhadapt%p_IneighboursAtElement(ive, iel0)

      ! Are we at the boundary?
      if (jel .eq. 0) cycle adjacent

      ! Initialize indicator
      bfound = .false.

      ! Find position of element IEL0 in adjacent element JEL
      do jve = 1, hadapt_getNVE(rhadapt, jel)
        if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel0) then
          rhadapt%p_IneighboursAtElement(jve, jel) = iel
          bfound = .true.
          exit
        end if
      end do

      ! Find position of element IEL0 in mid-adjacent element JEL
      do jve = 1, hadapt_getNVE(rhadapt, jel)
        if (rhadapt%p_ImidneighboursAtElement(jve, jel) .eq. iel0) then
          rhadapt%p_ImidneighboursAtElement(jve, jel) = iel
          bfound = (bfound .and. .true.)
          exit
        end if
      end do

      ! If the old element number was not found in adjacent element JEL
      ! then something went wrong and we should not proceed.
      if (.not.bfound) then
        call output_line('Inconsistent adjacency lists!',&
            OU_CLASS_ERROR,OU_MODE_STD,'update_AllElementNeighbors2D')
        call sys_halt()
      end if
    end do adjacent
  end subroutine update_AllElementNeighbors2D

  ! ***************************************************************************

!<subroutine>

  subroutine refine_Tria2Tria(rhadapt, iel, imarker,&
                              rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine subdivides one triangular element into two triangular 
    ! elements by subdividing one edge. The local number of the edge that is
    ! subdivided can be uniquely determined from the element marker.
    !
    ! In the illustration, i1,i2,i3 and i4 denote the vertices whereby i4 
    ! is the new vertex. Moreover, (e1)-(e6) stand for the element numbers
    ! which are adjecent and mid-adjacent to the current element.
    ! The new element is assigned the total number of elements currently present
    ! in the triangulation increased by one.
    !
    !    initial triangle           subdivided triangle
    !
    !            i3                            i3
    !            +                             +
    !           / \                           /|\
    !     (e3) /   \ (e5)               (e3) / | \ (e5)
    !         /     \                       /  |  \
    !        /       \          ->         /   |   \
    !       /   iel   \                   /    |    \
    ! (e6) /           \ (e2)       (e6) / iel |nel+1\ (e2)
    !     /*            \               /*     |     *\
    !    +---------------+             +-------+-------+
    !   i1 (e1)     (e4) i2            i1 (e1) i4 (e4) i2
    !
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel
    
    ! Identifiert for element marker
    integer, intent(IN)                  :: imarker

    ! Callback routines
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>
    
    ! local variables
    integer(PREC_ELEMENTIDX), dimension(6) :: Ielements
    integer(PREC_VERTEXIDX), dimension(4)  :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4
    integer                    :: loc1,loc2,loc3
    
    ! Determine the local position of edge to 
    ! be subdivided from the element marker
    select case(imarker)
    case(MARK_REF_TRIA2TRIA_1)
      loc1=1; loc2=2; loc3=3

    case(MARK_REF_TRIA2TRIA_2)
      loc1=2; loc2=3; loc3=1

    case(MARK_REF_TRIA2TRIA_3)
      loc1=3; loc2=1; loc3=2

    case DEFAULT
      call output_line('Invalid element marker!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria2Tria')
      call sys_halt()
    end select
    
    ! Store vertex- and element-values of the current element
    i1 = rhadapt%p_IverticesAtElement(loc1, iel)
    i2 = rhadapt%p_IverticesAtElement(loc2, iel)
    i3 = rhadapt%p_IverticesAtElement(loc3, iel)

    e1 = rhadapt%p_IneighboursAtElement(loc1, iel)
    e2 = rhadapt%p_IneighboursAtElement(loc2, iel)
    e3 = rhadapt%p_IneighboursAtElement(loc3, iel)
    
    e4 = rhadapt%p_ImidneighboursAtElement(loc1, iel)
    e5 = rhadapt%p_ImidneighboursAtElement(loc2, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(loc3, iel)
    
    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL

    
    ! Add one new vertex I4 at the midpoint of edge (I1,I2).
    call add_vertex2D(rhadapt, i1, i2, e1, i4,&
                      rcollection, fcb_hadaptCallback)
    
    ! Replace element IEL and add one new element numbered NEL0+1
    call replace_element2D(rhadapt, iel, i1, i4, i3,&
                           e1, nel0+1, e3, e1, nel0+1, e6)
    call add_element2D(rhadapt, i2, i3, i4,&
                       e2, iel, e4, e5, iel, e4)

    
    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e4, iel, nel0+1, iel)
    call update_ElementNeighbors2D(rhadapt, e2, e5, iel, nel0+1, nel0+1)

    
    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria2Tria')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, iel,    ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices =(/i1,i2,i3,i4/)
      Ielements = (/e1,e2,e3,e4,e5,e6/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_TRIA2TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine refine_Tria2Tria

  ! ***************************************************************************
  
!<subroutine>

  subroutine refine_Tria3Tria(rhadapt, iel, imarker,&
                              rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine subdivides one triangular element into three triangular 
    ! elements by subdividing the longest edge and connecting the new vertex 
    ! with the opposite midpoint. The local numbers of the two edges that are
    ! subdivided can be uniquely determined from the element marker.
    !
    ! In the illustration, i1,i2,i3,i4 and i5 denote the vertices whereby i4 and
    ! i5 are the new vertices. Moreover, (e1)-(e6) stand for the element numbers
    ! which are adjecent and mid-adjacent to the current element.
    ! The new elements are assigned the total number of elements currently present
    ! in the triangulation increased by one and two, respectively.
    !
    !    initial triangle           subdivided triangle
    !
    !            i3                        i3
    !            +                         +
    !           / \                       /|\
    !     (e3) /   \ (e5)           (e3) / |*\ (e5)
    !         /     \                   /  |ne\
    !        /       \          ->     /   |l+2+i5
    !       /   iel   \               /    |  / \
    ! (e6) /           \ (e2)   (e6) / iel | /nel\ (e2)
    !     /*            \           /*     |/ +1 *\
    !    +---------------+         +-------+-------+
    !   i1 (e1)     (e4) i2       i1 (e1) i4  (e4) i2
    !
!</description>

!<input> 
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel
    
    ! Identifier for element marker
    integer, intent(IN)                  :: imarker

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(5) :: Ielements
    integer(PREC_VERTEXIDX), dimension(5)  :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5
    integer                    :: loc1,loc2,loc3
    real(DP)                   :: dlen12,dlen23,x,y
    
    ! Find corresponding edges according to convention to be subdivided
    select case(imarker)
    case(MARK_REF_TRIA3TRIA_12)
      loc1=1; loc2=2; loc3=3

    case(MARK_REF_TRIA3TRIA_23)
      loc1=2; loc2=3; loc3=1

    case(MARK_REF_TRIA3TRIA_13)
      loc1=3; loc2=1; loc3=2

    case DEFAULT
      call output_line('Invalid element marker!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria3Tria')
      call sys_halt()
    end select

    ! Store vertex- and element-values of the current element
    i1 = rhadapt%p_IverticesAtElement(loc1, iel)
    i2 = rhadapt%p_IverticesAtElement(loc2, iel)
    i3 = rhadapt%p_IverticesAtElement(loc3, iel)

    e1 = rhadapt%p_IneighboursAtElement(loc1, iel)
    e2 = rhadapt%p_IneighboursAtElement(loc2, iel)
    e3 = rhadapt%p_IneighboursAtElement(loc3, iel)

    e4 = rhadapt%p_ImidneighboursAtElement(loc1, iel)
    e5 = rhadapt%p_ImidneighboursAtElement(loc2, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(loc3, iel)
    
    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL
    

    ! Add two new vertices I4 and I5 at the midpoint of edges (I1,I2) and (I2,I3).
    call add_vertex2D(rhadapt, i1, i2, e1, i4,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i2, i3, e2, i5,&
                      rcollection, fcb_hadaptCallback)
    
    ! Compute the length of edges (I1,I2) and (I2,I3)
    x = qtree_getX(rhadapt%rVertexCoordinates2D, i1)-&
        qtree_getX(rhadapt%rVertexCoordinates2D, i2)
    y = qtree_getY(rhadapt%rVertexCoordinates2D, i1)-&
        qtree_getY(rhadapt%rVertexCoordinates2D, i2)
    dlen12 = sqrt(x*x+y*y)

    x = qtree_getX(rhadapt%rVertexCoordinates2D, i2)-&
        qtree_getX(rhadapt%rVertexCoordinates2D, i3)
    y = qtree_getY(rhadapt%rVertexCoordinates2D, i2)-&
        qtree_getY(rhadapt%rVertexCoordinates2D, i3)
    dlen23 = sqrt(x*x+y*y)
    
    if (dlen12 > dlen23) then
      
      ! 1st CASE: longest edge is (I1,I2)
      
      ! Replace element IEL and add two new elements numbered NEL0+1 and NEL0+2
      call replace_element2D(rhadapt, iel, i1, i4, i3,&
                             e1, nel0+2, e3, e1, nel0+2, e6)
      call add_element2D(rhadapt, i2, i5, i4,&
                         e2, nel0+2, e4, e2, nel0+2, e4)
      call add_element2D(rhadapt, i3, i4, i5,&
                         iel, nel0+1, e5, iel, nel0+1, e5)
      

      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt, e1, e4, iel, nel0+1, iel)
      call update_ElementNeighbors2D(rhadapt, e2, e5, iel, nel0+2, nel0+1)

            
      ! Update list of elements meeting at vertices
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria3Tria')
        call sys_halt()
      end if
      
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, iel,    ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, iel,    ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+2, ipos)


      ! Optionally, invoke callback routine
      if (present(fcb_hadaptCallback).and.present(rcollection)) then
        Ivertices = (/i1,i2,i3,i4,i5/)
        Ielements = (/e1,e2,e3,e4,e5/)
        call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_TRIA3TRIA12,&
                                Ivertices, Ielements)
      end if
      
    else
      
      ! 2nd CASE: longest edge is (I2,I3)
      
      ! Replace element IEL and add two new elements numbered NEL0+1 and NEL0+2
      call replace_element2D(rhadapt, iel, i1, i5, i3,&
                             nel0+2, e5, e3, nel0+2, e5, e6)
      call add_element2D(rhadapt, i2, i5, i4,&
                         e2, nel0+2, e4, e2, nel0+2, e4)
      call add_element2D(rhadapt, i1, i4, i5,&
                         e1, nel0+1, iel, e1, nel0+1, iel)
      
      
      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt, e1, e4, iel, nel0+1, nel0+2)
      call update_ElementNeighbors2D(rhadapt, e2, e5, iel, iel, nel0+1)
      
      
      ! Update list of elements meeting at vertices
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria3Tria')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, nel0+1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, nel0+2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, iel,    ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+2, ipos)


      ! Optionally, invoke callback routine
      if (present(fcb_hadaptCallback).and.present(rcollection)) then
        Ivertices = (/i1,i2,i3,i4,i5/)
        Ielements = (/e1,e2,e3,e4,e5/)
        call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_TRIA3TRIA23,&
                                Ivertices, Ielements)
      end if
    end if
  end subroutine refine_Tria3Tria

  ! ***************************************************************************

!<subroutine>

  subroutine refine_Tria4Tria(rhadapt, iel, rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine subdivides one triangular element into four similar 
    ! triangular elements by connecting the three edge midpoints.
    !
    ! In the illustration, i1-i6 denote the vertices whereby i4-i6 are the 
    ! new vertices. Moreover, (e1)-(e6) stand for the element numbers which
    ! are adjecent and mid-adjacent to the current element.
    ! The new elements are assigned the total number of elements currently present
    ! in the triangulation increased by one, two and three, respectively.
    !
    !    initial triangle           subdivided triangle
    !
    !            i3                        i3
    !            +                         +
    !           / \                       /*\
    !     (e3) /   \ (e5)           (e3) /nel\ (e5)
    !         /     \                   / +3  \
    !        /       \          ->  i6 +-------+ i5
    !       /   iel   \               / \ iel / \
    ! (e6) /           \ (e2)   (e6) /nel\   /nel\ (e2)
    !     /*            \           /* +1 \*/ +2 *\
    !    +---------------+         +-------+-------+
    !   i1 (e1)     (e4) i2       i1 (e1)  i4 (e4) i2
    !
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(6) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(6) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6

    ! Store vertex- and element-values of the current element
    i1 = rhadapt%p_IverticesAtElement(1, iel)
    i2 = rhadapt%p_IverticesAtElement(2, iel)
    i3 = rhadapt%p_IverticesAtElement(3, iel)

    e1 = rhadapt%p_IneighboursAtElement(1, iel)
    e2 = rhadapt%p_IneighboursAtElement(2, iel)
    e3 = rhadapt%p_IneighboursAtElement(3, iel)

    e4 = rhadapt%p_ImidneighboursAtElement(1, iel)
    e5 = rhadapt%p_ImidneighboursAtElement(2, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(3, iel)
        
    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL


    ! Add three new vertices I4,I5 and I6 at the midpoint of edges (I1,I2),
    ! (I2,I3) and (I1,I3), respectively. 
    call add_vertex2D(rhadapt, i1, i2, e1, i4,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i2, i3, e2, i5,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i3, i1, e3, i6,&
                      rcollection, fcb_hadaptCallback)
    

    ! Replace element IEL and add three new elements NEL0+1, NEL0+2 and NEL0+3
    call replace_element2D(rhadapt, iel, i4, i5, i6,&
                           nel0+2, nel0+3, nel0+1, nel0+2, nel0+3, nel0+1)
    call add_element2D(rhadapt, i1, i4, i6, e1, iel, e6, e1, iel, e6)
    call add_element2D(rhadapt, i2, i5, i4, e2, iel, e4, e2, iel, e4)
    call add_element2D(rhadapt, i3, i6, i5, e3, iel, e5, e3, iel, e5)

    
    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e4, iel, nel0+2, nel0+1)
    call update_ElementNeighbors2D(rhadapt, e2, e5, iel, nel0+3, nel0+2)
    call update_ElementNeighbors2D(rhadapt, e3, e6, iel, nel0+1, nel0+3)

    
    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i1, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria4Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria4Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Tria4Tria')
      call sys_halt()
    end if
   
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, iel   , ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, iel   , ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, iel   , ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+3, ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6/)
      Ielements = (/e1,e2,e3,e4,e5,e6/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_TRIA4TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine refine_Tria4Tria

  ! ***************************************************************************

!<subroutine>
  
  subroutine refine_Quad2Quad(rhadapt, iel, imarker,&
                              rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine subdivides one quadrilateral element into two quadrilateral
    ! elements. The local number of the edge that is subdivided can be uniquely
    ! determined from the element marker.
    !
    ! In the illustration, i1-i6 denote the vertices whereby i5 and i6
    ! are the new vertices. Moreover, (e1)-(e8) stand for the element numbers
    ! which are adjecent and mid-adjacent to the current element.
    ! The new element is assigned the total number of elements currently present
    ! in the triangulation increased by one.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)     (e3) i3          i4 (e7)  i6 (e3) i3
    !      +---------------+            +-------+-------+
    !      |               |            |       |      *|
    ! (e4) |               | (e6)  (e4) |       |       | (e6)
    !      |               |            |       |       |
    !      |     iel       |     ->     |  iel  | nel+1 |
    !      |               |            |       |       |
    ! (e8) |               | (e2)  (e8) |       |       | (e2)
    !      |*              |            |*      |       |
    !      +---------------+            +-------+-------+
    !     i1 (e1)     (e5) i2          i1 (e1)  i5 (e5) i2
    ! 
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Identifier for element marker
    integer, intent(IN)                  :: imarker

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>    

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(6) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6
    integer                    :: loc1,loc2,loc3,loc4
    
    ! Find local position of edge to be subdivided
    select case(imarker)
    case(MARK_REF_QUAD2QUAD_13)
      loc1=1; loc2=2; loc3=3; loc4=4

    case(MARK_REF_QUAD2QUAD_24)
      loc1=2; loc2=3; loc3=4; loc4=1

    case DEFAULT
      call output_line('Invalid element marker!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad2Quad')
      call sys_halt()
    end select
    
    ! Store vertex- and element-values of the current element
    i1 = rhadapt%p_IverticesAtElement(loc1, iel)
    i2 = rhadapt%p_IverticesAtElement(loc2, iel)
    i3 = rhadapt%p_IverticesAtElement(loc3, iel)
    i4 = rhadapt%p_IverticesAtElement(loc4, iel)

    e1 = rhadapt%p_IneighboursAtElement(loc1, iel)
    e2 = rhadapt%p_IneighboursAtElement(loc2, iel)
    e3 = rhadapt%p_IneighboursAtElement(loc3, iel)
    e4 = rhadapt%p_IneighboursAtElement(loc4, iel)

    e5 = rhadapt%p_ImidneighboursAtElement(loc1, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(loc2, iel)
    e7 = rhadapt%p_ImidneighboursAtElement(loc3, iel)
    e8 = rhadapt%p_ImidneighboursAtElement(loc4, iel)
    
    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL
    
    ! Add two new vertices I5 and I6 at the midpoint of edges (I1,I2) and
    ! (I3,I4), respectively.
    call add_vertex2D(rhadapt, i1, i2, e1, i5,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i3, i4, e3, i6,&
                      rcollection, fcb_hadaptCallback)
    

    ! Replace element IEL and add one new element NEL0+1
    call replace_element2D(rhadapt, iel, i1, i5, i6, i4,&
                           e1, nel0+1, e7, e4, e1, nel0+1, e7, e8)
    call add_element2D(rhadapt, i3, i6, i5, i2,&
                       e3, iel, e5, e2, e3, iel, e5, e6)
    

    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e5, iel, nel0+1, iel)
    call update_ElementNeighbors2D(rhadapt, e2, e6, iel, nel0+1, nel0+1)
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel, iel, nel0+1)

    
    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad2Quad')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+1, ipos)
    

    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_QUAD2QUAD,&
                              Ivertices, Ielements)
    end if
  end subroutine refine_Quad2Quad

  ! ***************************************************************************

!<subroutine>

  subroutine refine_Quad3Tria(rhadapt, iel, imarker,&
                              rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine subdivides one quadrilateral element into three triangular
    ! elements. The local number of the edge that is
    ! subdivided can be uniquely determined from the element marker.
    !
    ! In the illustration, i1-i5 denote the vertices whereby i5 is the new 
    ! vertex. Moreover, (e1)-(e8) stand for the element numbers which are 
    ! adjecent and mid-adjacent to the current element.
    ! The new elements are assigned the total number of elements currently 
    ! present in the triangulation increased by one and two, respectively.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)      (e3) i3          i4 (e7)     (e3) i3
    !      +----------------+            +---------------+
    !      |                |            |\             /|
    ! (e4) |                | (e6)  (e4) | \           / | (e6)
    !      |                |            |  \  nel+2  /  |
    !      |      iel       |     ->     |   \       /   |
    !      |                |            |    \     /    |
    ! (e8) |                | (e2)  (e8) |     \   / nel | (e2)
    !      |*               |            |* iel \*/  +1 *| 
    !      +----------------+            +-------+-------+
    !     i1 (e1)      (e5) i2          i1 (e1)  i5 (e5) i2
    !
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Identifier for element marker
    integer, intent(IN)                  :: imarker

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(5) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5
    integer                    :: loc1,loc2,loc3,loc4
    
    ! Find local position of edge to be subdivided
    select case(imarker)
    case(MARK_REF_QUAD3TRIA_1)
      loc1=1; loc2=2; loc3=3; loc4=4

    case(MARK_REF_QUAD3TRIA_2)
      loc1=2; loc2=3; loc3=4; loc4=1

    case(MARK_REF_QUAD3TRIA_3)
      loc1=3; loc2=4; loc3=1; loc4=2

    case(MARK_REF_QUAD3TRIA_4)
      loc1=4; loc2=1; loc3=2; loc4=3

    case DEFAULT
      call output_line('Invalid element marker!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad3Tria')
      call sys_halt()
    end select
    

    ! Store vertex- and element-values of the current element
    i1 = rhadapt%p_IverticesAtElement(loc1, iel)
    i2 = rhadapt%p_IverticesAtElement(loc2, iel)
    i3 = rhadapt%p_IverticesAtElement(loc3, iel)
    i4 = rhadapt%p_IverticesAtElement(loc4, iel)


    e1 = rhadapt%p_IneighboursAtElement(loc1, iel)
    e2 = rhadapt%p_IneighboursAtElement(loc2, iel)
    e3 = rhadapt%p_IneighboursAtElement(loc3, iel)
    e4 = rhadapt%p_IneighboursAtElement(loc4, iel)

    e5 = rhadapt%p_ImidneighboursAtElement(loc1, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(loc2, iel)
    e7 = rhadapt%p_ImidneighboursAtElement(loc3, iel)
    e8 = rhadapt%p_ImidneighboursAtElement(loc4, iel)

    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL
    

    ! Add one new vertex I5 it the midpoint of edge (I1,I2)
    call add_vertex2D(rhadapt, i1, i2, e1, i5,&
                      rcollection, fcb_hadaptCallback)

    
    ! Replace element IEL and add two new elements NEL0+1 and NEL0+2
    call replace_element2D(rhadapt, iel, i1, i5, i4,&
                           e1, nel0+2, e4, e1, nel0+2, e8)
    call add_element2D(rhadapt, i2, i3, i5,&
                       e2, nel0+2, e5, e6, nel0+2, e5)
    call add_element2D(rhadapt, i5, i3, i4,&
                       nel0+1, e3, iel, nel0+1, e7, iel)    
    

    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e5, iel, nel0+1, iel)
    call update_ElementNeighbors2D(rhadapt, e2, e6, iel, nel0+1, nel0+1)
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel, nel0+2, nel0+2)
    

    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad3Tria')
      call sys_halt()
    end if   
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad3Tria')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+2, ipos)


    ! Adjust number of elements
    rhadapt%InelOfType(TRIA_NVETRI2D)  = rhadapt%InelOfType(TRIA_NVETRI2D)+1
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)-1
    

    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_QUAD3TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine refine_Quad3Tria
  
  ! ***************************************************************************

!<subroutine>

  subroutine refine_Quad4Tria(rhadapt, iel, imarker,&
                              rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine subdivides one quadrilateral element into four triangular
    ! elements. The local numbers of the edges that are subdivided can be 
    ! uniquely determined from the element marker.
    !
    ! In the illustration, i1-i6 denote the vertices whereby i5 and i6 are the 
    ! new vertices. Moreover, (e1)-(e8) stand for the element numbers which are
    ! adjecent and mid-adjacent to the current element.
    ! The new elements are assigned the total number of elements currently 
    ! present in the triangulation increased by one, two an three, respectively.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)      (e3) i3          i4 (e7)     (e3) i3
    !      +----------------+            +---------------+
    !      |                |            |\\\\          *|
    ! (e4) |                | (e6)  (e4) | \*  \\\ nel+2 | (e6)
    !      |                |            |  \      \\\   | 
    !      |      iel       |     ->     |   \         \\+i6
    !      |                |            |    \ nel+3  / |
    ! (e8) |                | (e2)  (e8) | iel \     /nel| (e2)
    !      |*               |            |*     \  / +1 *|
    !      +----------------+            +-------+-------+
    !     i1 (e1)      (e5) i2          i1 (e1)  i5 (e5) i2
    !
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Identifier for element marker
    integer, intent(IN)                  :: imarker

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(6) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6
    integer                    :: loc1,loc2,loc3,loc4
    
    ! Find local position of edge to be subdivided
    select case(imarker)
    case(MARK_REF_QUAD4TRIA_12)
      loc1=1; loc2=2; loc3=3; loc4=4

    case(MARK_REF_QUAD4TRIA_23)
      loc1=2; loc2=3; loc3=4; loc4=1

    case(MARK_REF_QUAD4TRIA_34)
      loc1=3; loc2=4; loc3=1; loc4=2

    case(MARK_REF_QUAD4TRIA_14)
      loc1=4; loc2=1; loc3=2; loc4=3

    case DEFAULT
      call output_line('Invalid element marker!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad4Tria')
      call sys_halt()
    end select

    ! Store vertex- and element-values of the current element
    i1 = rhadapt%p_IverticesAtElement(loc1, iel)
    i2 = rhadapt%p_IverticesAtElement(loc2, iel)
    i3 = rhadapt%p_IverticesAtElement(loc3, iel)
    i4 = rhadapt%p_IverticesAtElement(loc4, iel)

    e1 = rhadapt%p_IneighboursAtElement(loc1, iel)
    e2 = rhadapt%p_IneighboursAtElement(loc2, iel)
    e3 = rhadapt%p_IneighboursAtElement(loc3, iel)
    e4 = rhadapt%p_IneighboursAtElement(loc4, iel)

    e5 = rhadapt%p_ImidneighboursAtElement(loc1, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(loc2, iel)
    e7 = rhadapt%p_ImidneighboursAtElement(loc3, iel)
    e8 = rhadapt%p_ImidneighboursAtElement(loc4, iel)
    
    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL
    

    ! Add new vertices I5 and I6 at the midpoint of edges (I1,I2) and
    ! (I2,I3), respectively.
    call add_vertex2D(rhadapt, i1, i2, e1, i5,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i2, i3, e2, i6,&
                      rcollection, fcb_hadaptCallback)

    
    ! Replace element IEL and add three new elements NEL0+1,NEL0+2 and NEL0+3
    call replace_element2D(rhadapt, iel, i1, i5, i4,&
                           e1, nel0+3, e4, e1, nel0+3, e8)
    call add_element2D(rhadapt, i2, i6, i5,&
                       e2, nel0+3, e5, e2, nel0+3, e5)
    call add_element2D(rhadapt, i3, i4, i6,&
                       e3, nel0+3, e6, e7, nel0+3, e6)
    call add_element2D(rhadapt, i4, i5, i6,&
                       iel, nel0+1, nel0+2, iel, nel0+1, nel0+2)
    

    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e5, iel, nel0+1, iel)
    call update_ElementNeighbors2D(rhadapt, e2, e6, iel, nel0+2, nel0+1)
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel, nel0+2, nel0+2)

    
    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad4Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad4Tria')
      call sys_halt()
    end if
    
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+3, ipos)


    ! Adjust number of elements
    rhadapt%InelOfType(TRIA_NVETRI2D)  = rhadapt%InelOfType(TRIA_NVETRI2D)+1
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)-1


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_QUAD4TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine refine_Quad4Tria
    
  ! ***************************************************************************

!<subroutine>
  
  subroutine refine_Quad4Quad(rhadapt, iel,&
                              rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine subdivides one quadrilateral element four similar 
    ! quadrilateral elements.
    !
    ! In the illustration, i1-i9 denote the vertices whereby i5-i9 are the new 
    ! vertices. Moreover, (e1)-(e8) stand for the element numbers which are 
    ! adjacent and mid-adjacent to the current element.
    ! The new elements are assigned the total number of elements currently present
    ! in the triangulation increased by one, two and three, respectively.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)      (e3) i3          i4 (e7) i7  (e3) i3
    !      +----------------+            +-------+-------+
    !      |                |            |*      |      *|
    ! (e4) |                | (e6)  (e4) | nel+3 | nel+2 | (e6)
    !      |                |            |       |       |
    !      |       iel      |     ->   i8+-------+-------+i6
    !      |                |            |     i9|       |
    ! (e8) |                | (e2)  (e8) | iel   | nel+1 | (e2)
    !      |*               |            |*      |      *|
    !      +----------------+            +-------+-------+
    !     i1 (e1)      (e5) i2          i1 (e1) i5  (e5) i2
    !
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9
    
    ! Store vertex- and element-values of the current element
    i1 = rhadapt%p_IverticesAtElement(1, iel)
    i2 = rhadapt%p_IverticesAtElement(2, iel)
    i3 = rhadapt%p_IverticesAtElement(3, iel)
    i4 = rhadapt%p_IverticesAtElement(4, iel)

    e1 = rhadapt%p_IneighboursAtElement(1, iel)
    e2 = rhadapt%p_IneighboursAtElement(2, iel)
    e3 = rhadapt%p_IneighboursAtElement(3, iel)
    e4 = rhadapt%p_IneighboursAtElement(4, iel)

    e5 = rhadapt%p_ImidneighboursAtElement(1, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(2, iel)
    e7 = rhadapt%p_ImidneighboursAtElement(3, iel)
    e8 = rhadapt%p_ImidneighboursAtElement(4, iel)

    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL
    
    
    ! Add five new vertices I5,I6,I7,I8 and I9 at the midpoint of edges
    ! (I1,I2), (I2,I3), (I3,I4) and (I1,I4) and at the center of element IEL
    call add_vertex2D(rhadapt, i1, i2, e1, i5,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i2, i3, e2, i6,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i3, i4, e3, i7,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i4, i1, e4, i8,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i1, i2, i3, i4, i9,&
                      rcollection, fcb_hadaptCallback)
    

    ! Replace element IEL and add three new elements NEL0+1,NEL0+2 and NEL0+3
    call replace_element2D(rhadapt, iel, i1, i5, i9, i8,&
                           e1, nel0+1, nel0+3, e8, e1, nel0+1, nel0+3, e8)
    call add_element2D(rhadapt, i2, i6, i9, i5,&
                       e2, nel0+2, iel, e5, e2, nel0+2, iel, e5)
    call add_element2D(rhadapt, i3, i7, i9, i6,&
                       e3, nel0+3, nel0+1, e6, e3, nel0+3, nel0+1, e6)
    call add_element2D(rhadapt,i4, i8, i9, i7,&
                       e4, iel, nel0+2, e7, e4, iel, nel0+2, e7)

    
    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e5, iel, nel0+1, iel)
    call update_ElementNeighbors2D(rhadapt, e2, e6, iel, nel0+2, nel0+1)
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel, nel0+3, nel0+2)
    call update_ElementNeighbors2D(rhadapt, e4, e8, iel, iel, nel0+3)

        
    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad4Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad4Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i4, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'refine_Quad4Quad')
      call sys_halt()
    end if
    
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, nel0+3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, nel0+3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, nel0+3, ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_REF_QUAD4QUAD,&
                              Ivertices, Ielements)
    end if
  end subroutine refine_Quad4Quad
  
  ! ***************************************************************************

!<subroutine>

  subroutine convert_Tria2Tria(rhadapt, iel, jel,&
                               rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines two neighboring triangles into one triangle 
    ! and performs regular refinement into four similar triangles afterwards.
    ! The local orientation of both elements can be uniquely determined
    ! from the elemental states so that the first node of each triangle
    ! is located at the midpoint of the bisected edge.
    !
    !    initial triangle           subdivided triangle
    !
    !            i3                         i3
    !            +                          +
    !           /|\                        /*\
    !     (e3) / | \ (e5)            (e3) /   \ (e5)
    !         /  |  \                    /nel+1\
    !        /   |   \        ->      i6+-------+i5
    !       /    |    \                / \nel+2/ \
    ! (e6) / iel | jel \ (e2)    (e6) /   \   /   \ (e2)
    !     /*     |     *\            /* iel\*/jel *\
    !    +-------+-------+          +-------+-------+
    !   i1(e1,e7)i4(e4,e8)i2       i1(e1,e7)i4(e4,e8)i2
    !
!</description>

!<input>
    ! Number of first (left) element
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Number of second (right) element
    integer(PREC_ELEMENTIDX), intent(IN) :: jel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adaptive data structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(6) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6,e7,e8

    ! Find local positions of elements IEL and JEL
    i1 = rhadapt%p_IverticesAtElement(1, iel)
    i4 = rhadapt%p_IverticesAtElement(2, iel)
    i3 = rhadapt%p_IverticesAtElement(3, iel)
    i2 = rhadapt%p_IverticesAtElement(1, jel)
    
    e1 = rhadapt%p_IneighboursAtElement(1, iel)
    e3 = rhadapt%p_IneighboursAtElement(3, iel)
    e2 = rhadapt%p_IneighboursAtElement(1, jel)
    e4 = rhadapt%p_IneighboursAtElement(3, jel)
    
    e7 = rhadapt%p_ImidneighboursAtElement(1, iel)
    e6 = rhadapt%p_ImidneighboursAtElement(3, iel)
    e5 = rhadapt%p_ImidneighboursAtElement(1, jel)
    e8 = rhadapt%p_ImidneighboursAtElement(3, jel)
    
    ! Store total number of elements before conversion
    nel0 = rhadapt%NEL

    
    ! Add two new vertices I5 and I6 at the midpoint of edges (I2,I3)
    ! and (I1,I3), respectively.
    call add_vertex2D(rhadapt, i2, i3, e2, i5,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i3, i1, e3, i6,&
                      rcollection, fcb_hadaptCallback)


    ! Replace elements IEL and JEL and add two new elements NEL0+1 and NEL0+2
    call replace_element2D(rhadapt, iel, i1, i4, i6,&
                           e1, nel0+2, e6, e7, nel0+2, e6)
    call replace_element2D(rhadapt, jel, i2, i5, i4,&
                           e2, nel0+2, e4, e2, nel0+2, e8)
    call add_element2D(rhadapt, i3, i6, i5,&
                       e3, nel0+2, e5, e3, nel0+2, e5)
    call add_element2D(rhadapt, i4, i5, i6,&
                       jel, nel0+1, iel, jel, nel0+1, iel)

    
    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e2, e5, jel, nel0+1, jel)
    call update_ElementNeighbors2D(rhadapt, e3, e6, iel, iel, nel0+1)


    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Tria2Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, jel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Tria2Tria')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, jel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+2, ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_CVT_TRIA2TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine convert_Tria2Tria

  ! ***************************************************************************

!<subroutine>

  subroutine convert_Quad2Quad(rhadapt, iel, jel,&
                               rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines two neighboring quadrilaterals into one
    ! and performs regular refinement into four similar quadrilaterals.
    ! The local orientation of both elements can be uniquely determined
    ! from the elemental states so that the first node of each
    ! Depending on the given state of the element, the corresponding
    ! neighboring element is given explicitly.
    !
    !     initial quadrilateral      subdivided quadrilateral
    !
    !     i4(e7,e3)i7(f5,f1)i3         i4(e7,e3)i7(f5,f1)i3
    !      +-------+-------+            +-------+-------+
    !      |       |      *|            |*      |      *|
    ! (e4) |       |       | (f8)  (e4) | nel+2 | nel+1 | (f8)
    !      |       |       |            |       |       |
    !      |  iel  | jel   |     ->   i8+-------+-------+i6
    !      |       |       |            |       |i9     |
    ! (e8) |       |       | (f4)  (e8) |  iel  |  jel  | (f4)
    !      |*      |       |            |*      |      *|
    !      +-------+-------+            +-------+-------+
    !     i1(e1,e5)i5(f3,f7)i2         i1(e1,e5)i5(f3,f7)i2
    ! 
!</description>

!<input>
    ! Number of first element
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Number of second element
    integer(PREC_ELEMENTIDX), intent(IN) :: jel
    
    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>
    
    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e3,e4,e5,e7,e8,f1,f3,f4,f5,f7,f8
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9

    ! Find local positions of elements IEL and JEL
    i1 = rhadapt%p_IverticesAtElement(1, iel)
    i5 = rhadapt%p_IverticesAtElement(2, iel)
    i7 = rhadapt%p_IverticesAtElement(3, iel)
    i4 = rhadapt%p_IverticesAtElement(4, iel)
    i3 = rhadapt%p_IverticesAtElement(1, jel)
    i2 = rhadapt%p_IverticesAtElement(4, jel)

    e1 = rhadapt%p_IneighboursAtElement(1, iel)
    e3 = rhadapt%p_IneighboursAtElement(3, iel)
    e4 = rhadapt%p_IneighboursAtElement(4, iel)
    f1 = rhadapt%p_IneighboursAtElement(1, jel)   
    f3 = rhadapt%p_IneighboursAtElement(3, jel)
    f4 = rhadapt%p_IneighboursAtElement(4, jel)
    
    e5 = rhadapt%p_ImidneighboursAtElement(1, iel)
    e7 = rhadapt%p_ImidneighboursAtElement(3, iel)
    e8 = rhadapt%p_ImidneighboursAtElement(4, iel)
    f5 = rhadapt%p_ImidneighboursAtElement(1, jel)
    f7 = rhadapt%p_ImidneighboursAtElement(3, jel)
    f8 = rhadapt%p_ImidneighboursAtElement(4, jel)

    ! Store total number of elements before conversion
    nel0 = rhadapt%NEL

    
    ! Add two new vertices I6, I8, and I9 at the midpoint of edges (I2,I3),
    ! (I1,I4) and (I1,I2), respectively.
    call add_vertex2D(rhadapt, i2, i3, f4, i6,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i4, i1, e4, i8,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i1, i2, i3, i4, i9,&
                      rcollection, fcb_hadaptCallback)


    ! Replace element IEL and JEL and add two new elements NEL0+1 and NEL0+2
    call replace_element2D(rhadapt, iel, i1, i5, i9, i8,&
                           e1, jel, nel0+2, e8, e5, jel, nel0+2, e8)
    call replace_element2D(rhadapt, jel, i2, i6, i9, i5,&
                           f4, nel0+1, iel, f3, f4, nel0+1, iel, f7)
    call add_element2D(rhadapt, i3, i7, i9, i6,&
                       f1, nel0+2, jel, f8, f5, nel0+2, jel, f8)
    call add_element2D(rhadapt, i4, i8, i9, i7,&
                       e4, iel, nel0+1, e3, e4, iel, nel0+1, e7)


    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, f4, f8, jel, nel0+1, jel)
    call update_ElementNeighbors2D(rhadapt, e4, e8, iel, iel, nel0+2)
    call update_ElementNeighbors2D(rhadapt, f1, f5, jel, nel0+1, nel0+1)
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel, nel0+2, nel0+2)


    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, jel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i4, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i7, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i7, jel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad2Quad')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, jel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, nel0+2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, jel,    ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, nel0+2, ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,f4,f1,e4,f3,f8,e3,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_CVT_QUAD2QUAD,&
                              Ivertices, Ielements)
    end if
  end subroutine convert_Quad2Quad

  ! ***************************************************************************

!<subroutine>

  subroutine convert_Quad3Tria(rhadapt, iel1, iel2, iel3,&
                               rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines three neighboring triangles which result
    ! from a Quad4Tria refinement into one quadrilateral and performs
    ! regular refinement into four quadrilaterals afterwards.
    ! This subroutine is based on the convention that IEL1 denotes the
    ! left element, IEL2 denots the right element and IEL3 stands for 
    ! the triangle which connects IEL1 and IEL2.
    !
    ! initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)     (e3) i2          i4 (e7)  i7 (e3)  i3
    !      +---------------+            +-------+-------+
    !      |\             /|            |*      |      *|
    ! (e4) | \           / | (e6)  (e4) | nel+1 | iel3  | (e6)
    !      |  \   iel3  /  |            |       |       |
    !      |   \       /   |     ->   i8+-------+-------+i6
    !      |    \     /    |            |       |i9     |
    ! (e8) | iel1\   /iel2 | (e2)  (e8) | iel1  | iel2  | (e2)
    !      |*     \*/     *|            |*      |      *|
    !      +-------+-------+            +-------+-------+
    !     i1(e1,e9)i5(e5,e10)i2        i1(e1,e9)i5(e5,e10)i2
    !
!</description>

!<input>
    ! Number of first triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel1

    ! Number of second triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel2
    
    ! Number of third triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel3

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: nel0,e1,e2,e3,e4,e5,e6,e7,e8,e9,e10
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9

    ! Get local data from elements IEL1, IEL2 and IEL3
    i1 = rhadapt%p_IverticesAtElement(1, iel1)
    i5 = rhadapt%p_IverticesAtElement(2, iel1)
    i4 = rhadapt%p_IverticesAtElement(3, iel1)
    i2 = rhadapt%p_IverticesAtElement(1, iel2)
    i3 = rhadapt%p_IverticesAtElement(2, iel2)

    e1 = rhadapt%p_IneighboursAtElement(1, iel1)
    e4 = rhadapt%p_IneighboursAtElement(3, iel1)
    e2 = rhadapt%p_IneighboursAtElement(1, iel2)
    e5 = rhadapt%p_IneighboursAtElement(3, iel2)
    e3 = rhadapt%p_IneighboursAtElement(2, iel3)
    
    e9  = rhadapt%p_ImidneighboursAtElement(1, iel1)
    e8  = rhadapt%p_ImidneighboursAtElement(3, iel1)
    e6  = rhadapt%p_ImidneighboursAtElement(1, iel2)
    e10 = rhadapt%p_ImidneighboursAtElement(3, iel2)
    e7  = rhadapt%p_ImidneighboursAtElement(2, iel3)
    
    ! Store total number of elements before conversion
    nel0 = rhadapt%NEL

    
    ! Add four new vertices I6,I7,I8 and I9 at the midpoint of edges 
    ! (I2,I3), (I3,I4) and (I1,I4) and at the center of element IEL
    call add_vertex2D(rhadapt, i2, i3, e2, i6,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i3, i4, e3, i7,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i4, i1, e4, i8,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i1, i2, i3, i4, i9,&
                      rcollection, fcb_hadaptCallback)

    
    ! Replace elements IEL1, IEL2 and IEL3 and add one new element
    call replace_element2D(rhadapt, iel1, i1, i5, i9, i8,&
                           e1, iel2, nel0+1, e8, e9, iel2, nel0+1, e8)
    call replace_element2D(rhadapt, iel2, i2, i6, i9, i5,&
                           e2, iel3, iel1, e5, e2, iel3, iel1, e10)
    call replace_element2D(rhadapt, iel3, i3, i7, i9, i6,&
                           e3, nel0+1, iel2, e6, e3, nel0+1, iel2, e6)
    call add_element2D(rhadapt, i4, i8, i9, i7,&
                       e4, iel1, iel3, e7, e4, iel1, iel3, e7)


    ! Update element neighbors
    call update_ElementNeighbors2D(rhadapt, e2, e6, iel2, iel3, iel2)
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel3, nel0+1, iel3)
    call update_ElementNeighbors2D(rhadapt, e4, e8, iel1, iel1, nel0+1)


    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel2) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i4, iel1) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i4, iel3) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i5, iel3) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad3Tria')
      call sys_halt()
    end if
    
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, iel2,   ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, iel3,   ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, iel3,   ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, nel0+1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, iel1,   ipos)    
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel1,   ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel2,   ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel3,   ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, nel0+1, ipos)

    ! Finally, adjust numbers of triangles/quadrilaterals
    rhadapt%InelOfType(TRIA_NVETRI2D)  = rhadapt%InelOfType(TRIA_NVETRI2D)-3
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)+3


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_CVT_QUAD3TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine convert_Quad3Tria

  ! ***************************************************************************

!<subroutine>
  
  subroutine convert_Quad4Tria(rhadapt, iel1, iel2, iel3, iel4,&
                               rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines four neighboring triangles which result
    ! from a Quad4Tria refinement into one quadrilateral and performs
    ! regular refinement into four quadrilaterals afterwards.
    ! This subroutine is based on the convention, that all four elements
    ! are given in couterclockwise order. More precisely, IEL2 and IEL3
    ! make up the inner "diamond" of the refinement, whereas IEL1 and IEL4
    ! are the right and left outer triangles, respectively.
    !
    !    initial quadrilateral         subdivided quadrilateral
    !
    !     i4 (e7)     (e3) i3           i4 (e7)  i7 (e3) i3
    !      +---------------+             +-------+-------+
    !      |\\\\    iel3  *| (e12)       |*      |      *| (e12)
    ! (e4) | \*  \\\       | (e6)   (e4) | iel4  | iel3  | (e6)
    !      |  \      \\\   |             |       |       | 
    !      |   \  iel4   \\+i6    ->   i8+-------+-------+i6
    !      |    \        / |             |       |i9     |
    ! (e8) | iel1\     /   | (e11)  (e8) | iel1  | iel2  | (e11)
    !      |*     \  /iel2*| (e2)        |*      |      *| (e2)
    !      +-------+-------+             +-------+-------+
    !     i1(e1,e9)i5(e5,e10)i2         i1(e1,e9)i5(e5,e10)i2
    !
!</description>

!<input>
    ! Number of first triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel1

    ! Number of second triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel2

    ! Number of third triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel3

    ! Number of fourth triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel4

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: e1,e2,e3,e4,e5,e6,e7,e8,e9,e10,e11,e12
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9
    
    ! Get local data from elements IEL1, IEL2 and IEL3
    i1 = rhadapt%p_IverticesAtElement(1, iel1)
    i5 = rhadapt%p_IverticesAtElement(2, iel1)
    i4 = rhadapt%p_IverticesAtElement(3, iel1)
    i2 = rhadapt%p_IverticesAtElement(1, iel2)
    i6 = rhadapt%p_IverticesAtElement(2, iel2)
    i3 = rhadapt%p_IverticesAtElement(1, iel3)

    e1 = rhadapt%p_IneighboursAtElement(1, iel1)
    e4 = rhadapt%p_IneighboursAtElement(3, iel1)
    e2 = rhadapt%p_IneighboursAtElement(1, iel2)
    e5 = rhadapt%p_IneighboursAtElement(3, iel2)
    e3 = rhadapt%p_IneighboursAtElement(1, iel3)
    e6 = rhadapt%p_IneighboursAtElement(3, iel3)

    e9  = rhadapt%p_ImidneighboursAtElement(1, iel1)
    e8  = rhadapt%p_ImidneighboursAtElement(3, iel1)
    e11 = rhadapt%p_ImidneighboursAtElement(1, iel2)
    e10 = rhadapt%p_ImidneighboursAtElement(3, iel2)
    e7  = rhadapt%p_ImidneighboursAtElement(1, iel3)
    e12 = rhadapt%p_ImidneighboursAtElement(3, iel3)
    

    ! Add three new vertices I7, I8 and I9 at the midpoint of edges
    ! (I3,I4) and (I1,I4) and at the center of element IEL
    call add_vertex2D(rhadapt, i3, i4, e3, i7,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i4, i1, e4, i8,&
                      rcollection, fcb_hadaptCallback)
    call add_vertex2D(rhadapt, i1, i2, i3, i4, i9,&
                      rcollection, fcb_hadaptCallback)


    ! Replace all four elements
    call replace_element2D(rhadapt, iel1, i1, i5, i9, i8,&
                           e1, iel2, iel4, e8, e9, iel2, iel4, e8)
    call replace_element2D(rhadapt, iel2, i2, i6, i9, i5,&
                           e2, iel3, iel1, e5, e11, iel3, iel1, e10)
    call replace_element2D(rhadapt, iel3, i3, i7, i9, i6,&
                           e3, iel4, iel2, e6, e3, iel4, iel2, e12)
    call replace_element2D(rhadapt, iel4, i4, i8, i9, i7,&
                           e4, iel1, iel3, e7, e4, iel1, iel3, e7)


    ! Update element neighbors
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel3, iel4, iel3)
    call update_ElementNeighbors2D(rhadapt, e4, e8, iel1, iel1, iel4)


    ! Update list of elements meeting at vertices
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i5, iel4) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad4Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i6, iel4) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad4Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i4, iel1) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad4Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i4, iel3) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'convert_Quad4Tria')
      call sys_halt()
    end if
    
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, iel3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i7, iel4, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, iel1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i8, iel4, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel1, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel2, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel3, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i9, iel4, ipos)


    ! Finally, adjust numbers of triangles/quadrilaterals
    rhadapt%InelOfType(TRIA_NVETRI2D)  = rhadapt%InelOfType(TRIA_NVETRI2D)-4
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)+4


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_CVT_QUAD4TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine convert_Quad4Tria

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_2Tria1Tria(rhadapt, iel, rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines two triangles resulting from a 1-tria : 2-tria
    ! green refinement into the original macro triangle. Note that element IEL 
    ! must(!) be the left triangle which is combined with its right neighbour.
    ! This is not checked in the routine since this check is already performed
    ! in the marking routine.
    !
    ! Due to the numbering convention used in the refinement procedure
    ! the "second" element neighbor is the other green triangle that is removed.
    ! In order to restore the original orientation the outcome of the resulting
    ! triangle is considered. If the macro element belongs to the inital
    ! triangulation of if it is an inner red triangle, an arbitrary orientation
    ! is adopted. If the macro element is an outer red triangle, then the states
    ! 2 and 8 are trapped and converted into state 4.
    !
    !     initial triangle           subdivided triangle
    !
    !            i3                        i3
    !            +                         +
    !           /|\                       / \
    !     (e3) / | \ (e5)           (e3) /   \ (e5)
    !         /  |  \                   /     \
    !        /   |   \        ->       /       \
    !       /    |    \               /   jel   \
    ! (e6) / iel | iel1\ (e2)   (e6) /           \ (e2)
    !     /*     |     *\           /*            \
    !    +-------+-------+         +---------------+
    !    i1 (e1) i4 (e4) i2        i1 (e1)    (e4) i2
    !
!</description>

!<input>
    ! Element number of the inner red triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback routines
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! Adaptivity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection    
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(4) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(4) :: Ivertices
    integer(PREC_VERTEXIDX),  dimension(3) :: ImacroVertices
    integer, dimension(TRIA_NVETRI2D)      :: IvertexAge
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,e1,e2,e3,e4,e5,e6,jel,ielRemove,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4
    integer :: istate
    
          
    ! Get right-adjacent green elements
    iel1 = rhadapt%p_IneighboursAtElement(2, iel)
    
    ! Determine element with smaller element number
    if (iel < iel1) then
      jel=iel; ielRemove=iel1
    else
      jel=iel1; ielRemove=iel
    end if
    
    ! Store vertex- and element values of the two elements
    i1 = rhadapt%p_IverticesAtElement(1, iel)
    i4 = rhadapt%p_IverticesAtElement(2, iel)
    i3 = rhadapt%p_IverticesAtElement(3, iel)
    i2 = rhadapt%p_IverticesAtElement(1, iel1)
    
    e1 = rhadapt%p_IneighboursAtElement(1, iel)
    e3 = rhadapt%p_IneighboursAtElement(3, iel)
    e2 = rhadapt%p_IneighboursAtElement(1, iel1)
    e4 = rhadapt%p_IneighboursAtElement(3, iel1)
    
    e5 = rhadapt%p_ImidneighboursAtElement(1, iel1)
    e6 = rhadapt%p_ImidneighboursAtElement(3, iel)

    
    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e4, iel1, iel, jel, jel)
    if (iel < iel1) then
      call update_ElementNeighbors2D(rhadapt, e2, e5, iel1, jel, jel)
    else
      call update_ElementNeighbors2D(rhadapt, e3, e6, iel, jel, jel)
    end if

    
    ! The resulting triangle will possess one of the states STATE_TRIA_OUTERINNERx, whereby
    ! x can be blank, 1 or 2. Due to our refinement convention, the two states x=1 and x=2
    ! should not appear, that is, local numbering of the resulting triangle starts at the
    ! vertex which is opposite to the inner red triangle. To this end, we check the state of
    ! the provisional triangle (I1,I2,I3) and transform the orientation accordingly.
    ImacroVertices = (/i1,i2,i3/)
    IvertexAge = rhadapt%p_IvertexAge(ImacroVertices)
    istate     = redgreen_getstateTria(IvertexAge)
    
    select case(istate)
    case(STATE_TRIA_OUTERINNER,&
        STATE_TRIA_ROOT,&
        STATE_TRIA_REDINNER)
      ! Update element JEL = (I1,I2,I3)
      call replace_element2D(rhadapt, jel, i1, i2, i3,&
                             e1, e2, e3, e4, e5, e6)
      
    case(STATE_TRIA_OUTERINNER2)
      ! Update element JEL = (I2,I3,I1)
      call replace_element2D(rhadapt, jel, i2, i3, i1,&
                             e2, e3, e1, e5, e6, e4)
      
    case(STATE_TRIA_OUTERINNER1)
      ! Update element JEL = (I3,I1,I2)
      call replace_element2D(rhadapt,jel, i3, i1, i2,&
                             e3, e1, e2, e6, e4, e5)
      
    case DEFAULT
      call output_line('Invalid state of resulting triangle!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Tria1Tria')
      call sys_halt()
    end select
    

    ! Delete element IEL or IEL1 depending on which element has smaller
    ! element number, that is, is not equal to JEL
    call remove_element2D(rhadapt, ielRemove, ielReplace)
    if (ielReplace .ne. 0)&
        call update_AllElementNeighbors2D(rhadapt, ielReplace, ielRemove)
    
    
    ! Update list of elements meeting at vertices
    if (ielRemove .eq. iel1) then
      
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i2, ielRemove) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Tria1Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i3, ielRemove) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Tria1Tria')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, jel, ipos)
      
    else
      
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i1, ielRemove) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Tria1Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i3, ielRemove) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Tria1Tria')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, jel, ipos)
      
    end if
    
    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4/)
      Ielements = (/e1,e2,e3,e4/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_CRS_2TRIA1TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine coarsen_2Tria1Tria

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Tria1Tria(rhadapt, iel, rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines four triangles resulting from a
    ! 1-tria : 4-tria refinement into the original macro triangle.
    ! By definition, iel is the number of the inner red triangle.
    !
    !    initial triangle           subdivided triangle
    !
    !            i3                        i3
    !            +                         +
    !           /*\                       / \
    !     (e3) /   \ (e5)           (e3) /   \ (e5)
    !         / iel3\                   /     \
    !      i6+-------+i5      ->       /       \
    !       / \ iel / \               /   jel   \
    ! (e6) /   \   /   \ (e2)   (e6) /           \ (e2)
    !     /*iel1\*/iel2*\           /             \
    !    +-------+-------+         +---------------+
    !   i1 (e1)  i4 (e4) i2       i1  (e1)   (e4)  i2
    !
!</description>

!<input>
    ! Element number of the inner red triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! callback routines
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! Adaptivity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(6) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(4) :: IsortedElements
    integer(PREC_VERTEXIDX),  dimension(6) :: Ivertices
    integer(PREC_VERTEXIDX),  dimension(3) :: ImacroVertices
    integer, dimension(TRIA_NVETRI2D)      :: IvertexAge
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,jel,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6
    integer                    :: istate
    
    ! Retrieve patch of elements
    iel2 = rhadapt%p_IneighboursAtElement(1, iel)
    iel3 = rhadapt%p_IneighboursAtElement(2, iel)
    iel1 = rhadapt%p_IneighboursAtElement(3, iel)


    ! Store vertex- and element-values of the three neighboring elements
    i4 = rhadapt%p_IverticesAtElement(1, iel)
    i5 = rhadapt%p_IverticesAtElement(2, iel)
    i6 = rhadapt%p_IverticesAtElement(3, iel)
    i1 = rhadapt%p_IverticesAtElement(1, iel1)
    i2 = rhadapt%p_IverticesAtElement(1, iel2)
    i3 = rhadapt%p_IverticesAtElement(1, iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1, iel1)
    e6 = rhadapt%p_IneighboursAtElement(3, iel1)
    e2 = rhadapt%p_IneighboursAtElement(1, iel2)
    e4 = rhadapt%p_IneighboursAtElement(3, iel2)
    e3 = rhadapt%p_IneighboursAtElement(1, iel3)
    e5 = rhadapt%p_IneighboursAtElement(3, iel3)


    ! Sort the four elements according to their number and
    ! determine the element with the smallest element number
    IsortedElements = (/iel,iel1,iel2,iel3/)
    call sort_I32(IsortedElements, SORT_INSERT)
    jel = IsortedElements(1)


    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e4, iel2, iel1, jel, jel)
    call update_ElementNeighbors2D(rhadapt, e2, e5, iel3, iel2, jel, jel)
    call update_ElementNeighbors2D(rhadapt, e3, e6, iel1, iel3, jel, jel)

    
    ! The resulting triangle will posses one of the states STATE_TRIA_REDINNER or
    ! STATE_TRIA_OUTERINNERx, whereby x can be blank, 1 or 2. Due to our refinement 
    ! convention, the two states x=1 and x=2 should not appear, that is, local
    ! numbering of the resulting triangle starts at the vertex which is opposite 
    ! to the inner red triangle. To this end, we check the state of the provisional
    ! triangle (I1,I2,I3) and transform the orientation accordingly.
    ImacroVertices = (/i1,i2,i3/)
    IvertexAge = rhadapt%p_IvertexAge(ImacroVertices)
    istate     = redgreen_getstateTria(IvertexAge)
    
    select case(istate)
    case(STATE_TRIA_OUTERINNER,&
         STATE_TRIA_ROOT,&
         STATE_TRIA_REDINNER)
      ! Update element JEL = (I1,I2,I3)
      call replace_element2D(rhadapt, jel, i1, i2, i3,&
                             e1, e2, e3, e4, e5, e6)
      
    case(STATE_TRIA_OUTERINNER1)
      ! Update element JEL = (I3,I1,I2)
      call replace_element2D(rhadapt, jel, i3, i1, i2,&
                             e3, e1, e2, e6, e4, e5)

    case(STATE_TRIA_OUTERINNER2)
      ! Update element JEL = (I2,I3,I1)
      call replace_element2D(rhadapt, jel, i2, i3, i1,&
                             e2, e3, e1, e5, e6, e4)

    case DEFAULT
      call output_line('Invalid state of resulting triangle!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Tria')
      call sys_halt()
    end select


    ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
    ! element corresponds to element with minimum number JEL
    call remove_element2D(rhadapt, IsortedElements(4), ielReplace)
    if (ielReplace .ne. 0)&
        call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(4))

    call remove_element2D(rhadapt, IsortedElements(3), ielReplace)
    if (ielReplace .ne. 0)&
        call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(3))

    call remove_element2D(rhadapt, IsortedElements(2), ielReplace)
    if (ielReplace .ne. 0)&
        call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(2))


    ! Update list of elements meeting at vertices.
    ! Note that all elements are removed in the first step. Afterwards,
    ! element JEL is appended to the list of elements meeting at each vertex
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i1, iel1) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel2) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel3) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Tria')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, jel, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, jel, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, jel, ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6/)
      Ielements = (/e1,e2,e3,e4,e5,e6/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_CRS_4TRIA1TRIA,&
                              Ivertices, Ielements)
    end if
  end subroutine coarsen_4Tria1Tria

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Tria2Tria(rhadapt, iel, imarker,&
                                rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines four triangles resulting from a
    ! 1-tria : 4-tria refinement into two green triangle.
    ! The local position (node 1,2,3 of the interior element) of the midpoint 
    ! vertex that should be kept is identified by the marker imarker. 
    ! By definition, iel is the number of the inner red triangle.
    ! Be warned, this numbering convention is not checked since the
    ! routine is only called internally and cannot be used from outside.
    !
    ! Due to the numbering convention used in the refinement procedure
    ! the "third" element neighbor of the inner triangle has the number
    ! of the original macro element which will be used for the first resulting 
    ! triangle. The number of the second triangle will be the number of the 
    ! "first" element neighbor of the inner triangle.
    !
    !    initial triangle           subdivided triangle
    !
    !            i3                        i3
    !            +                         +
    !           /*\                       /|\
    !    (e3)  /   \ (e5)           (e3) / | \ (e5)
    !         /iel3 \                   /  |  \
    !     i6 +-------+ i5     ->       /   |   \
    !       / \ iel / \               /    |    \
    ! (e6) /   \   /   \ (e2)   (e6) /     |     \ (e2)
    !     /*iel1\*/iel2*\           /* jel1|jel2 *\
    !    +-------+-------+         +-------+-------+
    !    i1 (e1) i4 (e4) i2        i1 (e1) i4 (e4)  i2
    !
!</description>

!<input>
    ! Element number of the inner red triangle
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Identifiert for element marker
    integer, intent(IN)                  :: imarker

    ! callback routines
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! Adaptivity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(6) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(4) :: IsortedElements
    integer(PREC_VERTEXIDX),  dimension(6) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX) :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,jel1,jel2,ielReplace
    integer(PREC_VERTEXIDX)  :: i1,i2,i3,i4,i5,i6
    
    ! Retrieve patch of elements
    iel2 = rhadapt%p_IneighboursAtElement(1, iel)
    iel3 = rhadapt%p_IneighboursAtElement(2, iel)
    iel1 = rhadapt%p_IneighboursAtElement(3, iel)

    ! Store vertex- and element-values of the three neighboring elements
    i4 = rhadapt%p_IverticesAtElement(1, iel)
    i5 = rhadapt%p_IverticesAtElement(2, iel)
    i6 = rhadapt%p_IverticesAtElement(3, iel)
    i1 = rhadapt%p_IverticesAtElement(1, iel1)
    i2 = rhadapt%p_IverticesAtElement(1, iel2)
    i3 = rhadapt%p_IverticesAtElement(1, iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1, iel1)
    e6 = rhadapt%p_IneighboursAtElement(3, iel1)
    e2 = rhadapt%p_IneighboursAtElement(1, iel2)
    e4 = rhadapt%p_IneighboursAtElement(3, iel2)
    e3 = rhadapt%p_IneighboursAtElement(1, iel3)
    e5 = rhadapt%p_IneighboursAtElement(3, iel3)


    ! Sort the four elements according to their number and
    ! determine the two elements withthe smallest element numbers
    IsortedElements=(/iel,iel1,iel2,iel3/)
    call sort_I32(IsortedElements, SORT_INSERT)
    jel1 = IsortedElements(1)
    jel2 = IsortedElements(2)


    ! Which midpoint vertex should be kept?
    select case(imarker)
    case(MARK_CRS_4TRIA2TRIA_1)     
      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt, e1, e4, iel2, iel1, jel2, jel1)
      call update_ElementNeighbors2D(rhadapt, e2, e5, iel3, iel2, jel2, jel2)
      call update_ElementNeighbors2D(rhadapt, e3, e6, iel1, iel3, jel1, jel1)


      ! Update elements JEL1 and JEL2
      call replace_element2D(rhadapt, jel1, i1, i4, i3,&
                             e1, jel2, e3, e1, jel2, e6)
      call replace_element2D(rhadapt, jel2, i2, i3, i4,&
                             e2, jel1, e4, e5, jel1, e4)
      

      ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
      ! elements correspond to the two elements with smallest numbers
      call remove_element2D(rhadapt, IsortedElements(4), ielReplace)
      if (ielReplace .ne. 0)&
          call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(4))

      call remove_element2D(rhadapt, IsortedElements(3), ielReplace)
      if (ielReplace .ne. 0)&
          call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(3))

      
      ! Update list of elements meeting at vertices.
      ! Note that all elements are removed in the first step. Afterwards,
      ! element JEL is appended to the list of elements meeting at each vertex
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i1, iel1) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i2, iel2) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i3, iel3) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if

      ! Note, this can be improved by checking against JEL1 and JEL2
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i4, iel) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i4, iel1) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i4, iel2) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, jel2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, jel2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, jel2, ipos)


      ! Optionally, invoke callback routine
      if (present(fcb_hadaptCallback).and.present(rcollection)) then
        Ivertices = (/i1,i2,i3,i4,i5,i6/)
        Ielements = (/e1,e2,e3,e4,e5,e6/)
        call fcb_hadaptCallback(rcollection, HADAPT_OPR_CRS_4TRIA2TRIA1,&
                                Ivertices, Ielements)
      end if


    case(MARK_CRS_4TRIA2TRIA_2)
      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt, e1, e4, iel2, iel1, jel1, jel1)
      call update_ElementNeighbors2D(rhadapt, e2, e5, iel3, iel2, jel2, jel1)
      call update_ElementNeighbors2D(rhadapt, e3, e6, iel1, iel3, jel2, jel2)


      ! Update elements JEL1 and JEL2
      call replace_element2D(rhadapt, jel1, i2, i5, i1,&
                             e2, jel2, e1, e2, jel2, e4)
      call replace_element2D(rhadapt, jel2, i3, i1, i5,&
                             e3, jel1, e5, e6, jel1, e5)


      ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
      ! elements correspond to the two elements with smallest numbers
      call remove_element2D(rhadapt, IsortedElements(4), ielReplace)
      if (ielReplace .ne. 0)&
          call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(4))

      call remove_element2D(rhadapt, IsortedElements(3), ielReplace)
      if (ielReplace .ne. 0)&
          call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(3))


      ! Update list of elements meeting at vertices
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i1, iel1) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i2, iel2) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i3, iel3) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if

      ! Note, this can be improved by checking against JEL1 and JEL2
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i5, iel) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i5, iel2) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i5, iel3) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, jel2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, jel2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i5, jel2, ipos)


      ! Optionally, invoke callback routine
      if (present(fcb_hadaptCallback).and.present(rcollection)) then
        Ivertices = (/i1,i2,i3,i4,i5,i6/)
        Ielements = (/e1,e2,e3,e4,e5,e6/)
        call fcb_hadaptCallback(rcollection, HADAPT_OPR_CRS_4TRIA2TRIA2,&
                                Ivertices, Ielements)
      end if


    case(MARK_CRS_4TRIA2TRIA_3)
      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt, e1, e4, iel2, iel1, jel2, jel2)
      call update_ElementNeighbors2D(rhadapt, e2, e5, iel3, iel2, jel1, jel1)
      call update_ElementNeighbors2D(rhadapt, e3, e6, iel1, iel3, jel2, jel1)
      

      ! Update elements JEL1 and JEL2
      call replace_element2D(rhadapt, jel1, i3, i6, i2,&
                             e3, jel2, e2, e3, jel2, e5)
      call replace_element2D(rhadapt, jel2, i1, i2, i6,&
                             e1, jel1, e6, e4, jel1, e6)


      ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
      ! elements correspond to the two elements with smallest numbers
      call remove_element2D(rhadapt, IsortedElements(4), ielReplace)
      if (ielReplace .ne. 0)&
          call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(4))

      call remove_element2D(rhadapt, IsortedElements(3), ielReplace)
      if (ielReplace .ne. 0)&
          call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(3))


      ! Update list of elements meeting at vertices.
      ! Note that all elements are removed in the first step. Afterwards,
      ! element JEL is appended to the list of elements meeting at each vertex
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i1, iel1) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i2, iel2) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i3, iel3) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if

      ! Note, this can be improved by checking against JEL1 and JEL2
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i6, iel) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i6, iel1) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                     i6, iel3) .eq. ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, jel2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, jel2, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, jel1, ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i6, jel2, ipos)
      

      ! Optionally, invoke callback routine
      if (present(fcb_hadaptCallback).and.present(rcollection)) then
        Ivertices = (/i1,i2,i3,i4,i5,i6/) 
        Ielements = (/e1,e2,e3,e4,e5,e6/)
        call fcb_hadaptCallback(rcollection, HADAPT_OPR_CRS_4TRIA2TRIA3,&
                                Ivertices, Ielements)
      end if


    case DEFAULT
      call output_line('Invalid position of midpoint vertex!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria2Tria')
      call sys_halt()
    end select
  end subroutine coarsen_4Tria2Tria

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Quad1Quad(rhadapt, iel, rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine combines four quadrilaterals resulting from a
    ! 1-quad : 4-quad refinement into the original macro quadrilateral.
    ! The remaining element JEL is labeled by the smallest element number
    ! of the four neighboring elements. Due to the numbering convention
    ! all elements can be determined by visiting neighbors along the
    ! second edge starting at the given element IEL. The resulting element
    ! JEL is oriented such that local numbering starts at the vertex of the
    ! macro element, that is, such that the first vertex is the oldest one.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)      (e3) i3          i4 (e7) i7  (e3) i3
    !      +-------+-------+             +---------------+
    !      |*      |      *|             |               |
    ! (e4) | iel3  |  iel2 | (e6)   (e4) |               | (e6)
    !      |       |       |             |               |
    !    i8+-------+-------+i6    ->     |      jel      |
    !      |     i9|       |             |               |
    ! (e8) | iel   |  iel1 | (e2)   (e8) |               | (e2)
    !      |*      |      *|             |*              |
    !      +-------+-------+             +---------------+
    !     i1 (e1) i5  (e5) i2           i1 (e1)     (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(4) :: IsortedElements
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_VERTEXIDX),  dimension(TRIA_NVEQUAD2D) :: ImacroVertices
    integer, dimension(TRIA_NVEQUAD2D)                  :: IvertexAge
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,e7,e8,jel,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9
    integer                    :: istate

    ! Retrieve patch of elements
    iel1 = rhadapt%p_IneighboursAtElement(2, iel)
    iel2 = rhadapt%p_IneighboursAtElement(2, iel1)
    iel3 = rhadapt%p_IneighboursAtElement(2, iel2)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1, iel)
    i5 = rhadapt%p_IverticesAtElement(2, iel)
    i9 = rhadapt%p_IverticesAtElement(3, iel)
    i8 = rhadapt%p_IverticesAtElement(4, iel)
    i2 = rhadapt%p_IverticesAtElement(1, iel1)
    i6 = rhadapt%p_IverticesAtElement(2, iel1)
    i3 = rhadapt%p_IverticesAtElement(1, iel2)
    i7 = rhadapt%p_IverticesAtElement(2, iel2)
    i4 = rhadapt%p_IverticesAtElement(1, iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1, iel)
    e8 = rhadapt%p_IneighboursAtElement(4, iel)   
    e2 = rhadapt%p_IneighboursAtElement(1, iel1)
    e5 = rhadapt%p_IneighboursAtElement(4, iel1)
    e3 = rhadapt%p_IneighboursAtElement(1, iel2)
    e6 = rhadapt%p_IneighboursAtElement(4, iel2)
    e4 = rhadapt%p_IneighboursAtElement(1, iel3)
    e7 = rhadapt%p_IneighboursAtElement(4, iel3)


    ! Sort the four elements according to their number and
    ! determine the element with the smallest element number
    IsortedElements = (/iel,iel1,iel2,iel3/)
    call sort_I32(IsortedElements, SORT_INSERT)
    jel = IsortedElements(1)


    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt, e1, e5, iel1, iel, jel, jel)
    call update_ElementNeighbors2D(rhadapt, e2, e6, iel2, iel1, jel, jel)
    call update_ElementNeighbors2D(rhadapt, e3, e7, iel3, iel2, jel, jel)
    call update_ElementNeighbors2D(rhadapt, e4, e8, iel, iel3, jel, jel)


    ! The resulting quadrilateral will posses one of the states STATES_QUAD_REDx,
    ! whereby x can be 1,2,3 and 4. Die to our refinement convention, x=1,2,3
    ! should not appear, that is, local numbering of the resulting quadrilateral
    ! starts at the oldest vertex. to this end, we check the state of the 
    ! provisional quadrilateral (I1,I2,I3,I4) and transform the orientation.
    ImacroVertices = (/i1,i2,i3,i4/)
    IvertexAge = rhadapt%p_IvertexAge(ImacroVertices)
    istate     = redgreen_getstateQuad(IvertexAge)

    select case(istate)
    case(STATE_QUAD_ROOT,&
         STATE_QUAD_RED4)
      ! Update element JEL = (I1,I2,I3,I4)
      call replace_element2D(rhadapt, jel, i1, i2, i3, i4,&
                             e1, e2, e3, e4, e5, e6, e7, e8)

    case(STATE_QUAD_RED1)
      ! Update element JEL = (I2,I3,I4,I1)
      call replace_element2D(rhadapt, jel, i2, i3, i4, i1,&
                             e2, e3, e4, e1, e6, e7, e8, e5)

    case(STATE_QUAD_RED2)
      ! Update element JEL = (I3,I4,I1,I2)
      call replace_element2D(rhadapt, jel, i3, i4, i1, i2,&
                             e3, e4, e1, e2, e7, e8, e5, e6)

    case(STATE_QUAD_RED3)
      ! Update element JEL = (I4,I1,I2,I3)
      call replace_element2D(rhadapt, jel, i4, i1, i2, i3,&
                             e4, e1, e2, e3, e8, e5, e6, e7)
      
    case DEFAULT
      call output_line('Invalid state of resulting quadrilateral!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad1Quad')
      call sys_halt()
    end select


    ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
    ! element corresponds to element with minimum number JEL
    call remove_element2D(rhadapt,IsortedElements(4), ielReplace)
    if (ielReplace .ne. 0)&
        call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(4))

    call remove_element2D(rhadapt, IsortedElements(3), ielReplace)
    if (ielReplace .ne. 0)&
        call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(3))

    call remove_element2D(rhadapt, IsortedElements(2), ielReplace)
    if (ielReplace .ne. 0)&
        call update_AllElementNeighbors2D(rhadapt, ielReplace, IsortedElements(2))


    ! Update list of elements meeting at vertices.
    ! Note that all elements are removed in the first step. Afterwards,
    ! element JEL is appended to the list of elements meeting at each vertex
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i1, iel) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i2, iel1) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i3, iel2) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,&
                                   i4, iel3) .eq. ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad1Quad')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i1, jel, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i2, jel, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i3, jel, ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex, i4, jel, ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection, HADAPT_OPR_CRS_4QUAD1QUAD,&
                              Ivertices, Ielements)
    end if
  end subroutine coarsen_4Quad1Quad

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Quad2Quad(rhadapt,iel,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines four quadrilaterals resulting from a
    ! 1-quad : 4-quad refinement into two green quadrilaterals.
    ! The remaining elements JEL1 and JEL2 are labeled by the  two smallest
    ! element numbers of the four neighboring elements. Due to the numbering
    ! convention all elements can be determined by visiting neighbors along 
    ! the second edge starting at the given element IEL. The resulting elements
    ! JEL1 and JEL2 are oriented such that local numbering starts at the vertices
    ! of the macro element, that is, such that the first vertex is the oldest one.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7) i7  (e3) i3          i4 (e7)  i7  (e3) i3
    !      +-------+-------+             +-------+-------+
    !      |*      |      *|             |       |      *|
    ! (e4) | iel3  |  iel2 | (e6)   (e4) |       |       | (e6)
    !      |       |       |             |       |       |
    !    i8+-------+-------+i6    ->     | jel1  | jel2  |
    !      |     i9|       |             |       |       |
    ! (e8) | iel   |  iel1 | (e2)   (e8) |       |       | (e2)
    !      |*      |      *|             |*      |       |
    !      +-------+-------+             +-------+-------+
    !     i1 (e1) i5  (e5) i2           i1 (e1) i5  (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(4) :: IsortedElements    
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,e7,e8,jel1,jel2,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9

    ! Retrieve patch of elements
    iel1 = rhadapt%p_IneighboursAtElement(2,iel)
    iel2 = rhadapt%p_IneighboursAtElement(2,iel1)
    iel3 = rhadapt%p_IneighboursAtElement(2,iel2)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1,iel)
    i5 = rhadapt%p_IverticesAtElement(2,iel)
    i9 = rhadapt%p_IverticesAtElement(3,iel)
    i8 = rhadapt%p_IverticesAtElement(4,iel)
    i2 = rhadapt%p_IverticesAtElement(1,iel1)
    i6 = rhadapt%p_IverticesAtElement(2,iel1)
    i3 = rhadapt%p_IverticesAtElement(1,iel2)
    i7 = rhadapt%p_IverticesAtElement(2,iel2)
    i4 = rhadapt%p_IverticesAtElement(1,iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1,iel)
    e8 = rhadapt%p_IneighboursAtElement(4,iel)   
    e2 = rhadapt%p_IneighboursAtElement(1,iel1)
    e5 = rhadapt%p_IneighboursAtElement(4,iel1)
    e3 = rhadapt%p_IneighboursAtElement(1,iel2)
    e6 = rhadapt%p_IneighboursAtElement(4,iel2)
    e4 = rhadapt%p_IneighboursAtElement(1,iel3)
    e7 = rhadapt%p_IneighboursAtElement(4,iel3)


    ! Sort the four elements according to their number and
    ! determine the element with the smallest element number
    IsortedElements=(/iel,iel1,iel2,iel3/)
    call sort_I32(IsortedElements,SORT_INSERT)
    jel1=IsortedElements(1)
    jel2=IsortedElements(2)


    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt,e1,e5,iel1,iel,jel2,jel1)
    call update_ElementNeighbors2D(rhadapt,e2,e6,iel2,iel1,jel2,jel2)
    call update_ElementNeighbors2D(rhadapt,e3,e7,iel3,iel2,jel1,jel2)
    call update_ElementNeighbors2D(rhadapt,e4,e8,iel,iel3,jel1,jel1)


    ! Update elements JEL1 = (I1,I5,I7,I4) and JEL2=(I3,I7,I5,I2)
    call replace_element2D(rhadapt,jel1,i1,i5,i7,i4,e1,jel2,e7,e4,e1,jel2,e7,e8)
    call replace_element2D(rhadapt,jel2,i3,i7,i5,i2,e3,jel1,e5,e2,e3,jel1,e5,e6)

    
    ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
    ! elements corresponds to elements with minimum numbers JEL1 and JEL2
    call remove_element2D(rhadapt,IsortedElements(4),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(4))
    
    call remove_element2D(rhadapt,IsortedElements(3),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(3))


    ! Update list of elements meeting at vertices.
    ! Note that all elements are removed in the first step. Afterwards,
    ! element JEL is appended to the list of elements meeting at each vertex
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i2,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel2).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel3).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i5,iel).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i5,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i7,iel2).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i7,iel3).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad2Quad')
      call sys_halt()
    end if
   
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,jel2,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,jel2,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i5,jel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i5,jel2,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i7,jel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i7,jel2,ipos)


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_4QUAD2QUAD,&
          Ivertices,Ielements)
    end if
  end subroutine coarsen_4Quad2Quad

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Quad3Tria(rhadapt,iel,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines four quadrilaterals resulting from a
    ! 1-quad : 4-quad refinement into three green triangles.
    ! The elements remaining JEL1,JEL2, and JEL3 are the ones with
    ! the smallest element number, that is, only the largest element is
    ! removed. The numbering convention follows the strategy used for
    ! refinement, that is, the local numbering of the two outer triangles
    ! starts at the vertices of the macro element and the local numbering
    ! numbering of the interior triangle starts at the edge midpoint.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7) i7  (e3) i3          i4 (e7)      (e3) i3
    !      +-------+-------+             +---------------+
    !      |*      |      *|             |\             /|
    ! (e4) | iel3  |  iel2 | (e6)   (e4) | \           / | (e6)
    !      |       |       |             |  \         /  |
    !    i8+-------+-------+i6    ->     |   \  jel3 /   |
    !      |     i9|       |             |    \     /    |
    ! (e8) | iel   |  iel1 | (e2)   (e8) |jel1 \   / jel2| (e2)
    !      |*      |      *|             |*     \*/     *|
    !      +-------+-------+             +-------+-------+
    !     i1 (e1) i5  (e5) i2           i1 (e1) i5  (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(4) :: IsortedElements
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_ELEMENTIDX)   :: jel1,jel2,jel3,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9

    ! Retrieve patch of elements
    iel1 = rhadapt%p_IneighboursAtElement(2,iel)
    iel2 = rhadapt%p_IneighboursAtElement(2,iel1)
    iel3 = rhadapt%p_IneighboursAtElement(2,iel2)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1,iel)
    i5 = rhadapt%p_IverticesAtElement(2,iel)
    i9 = rhadapt%p_IverticesAtElement(3,iel)
    i8 = rhadapt%p_IverticesAtElement(4,iel)
    i2 = rhadapt%p_IverticesAtElement(1,iel1)
    i6 = rhadapt%p_IverticesAtElement(2,iel1)
    i3 = rhadapt%p_IverticesAtElement(1,iel2)
    i7 = rhadapt%p_IverticesAtElement(2,iel2)
    i4 = rhadapt%p_IverticesAtElement(1,iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1,iel)
    e8 = rhadapt%p_IneighboursAtElement(4,iel)   
    e2 = rhadapt%p_IneighboursAtElement(1,iel1)
    e5 = rhadapt%p_IneighboursAtElement(4,iel1)
    e3 = rhadapt%p_IneighboursAtElement(1,iel2)
    e6 = rhadapt%p_IneighboursAtElement(4,iel2)
    e4 = rhadapt%p_IneighboursAtElement(1,iel3)
    e7 = rhadapt%p_IneighboursAtElement(4,iel3)


    ! Sort the four elements according to their number and
    ! determine the elements with the smallest element numbers
    IsortedElements=(/iel,iel1,iel2,iel3/)
    call sort_I32(IsortedElements,SORT_INSERT)
    jel1=IsortedElements(1)
    jel2=IsortedElements(2)
    jel3=IsortedElements(3)


    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt,e1,e5,iel1,iel,jel2,jel1)
    call update_ElementNeighbors2D(rhadapt,e2,e6,iel2,iel1,jel2,jel2)
    call update_ElementNeighbors2D(rhadapt,e3,e7,iel3,iel2,jel3,jel3)
    call update_ElementNeighbors2D(rhadapt,e4,e8,iel,iel3,jel1,jel1)


    ! Update elements JEL1 = (I1,I5,I4), JEL2 = (I2,I3,I5), and JEL3 = (I5,I3,I4)
    call replace_element2D(rhadapt,jel1,i1,i5,i4,e1,jel3,e4,e1,jel3,e8)
    call replace_element2D(rhadapt,jel2,i2,i3,i5,e2,jel3,e5,e6,jel3,e5)
    call replace_element2D(rhadapt,jel3,i5,i3,i4,jel2,e3,jel1,jel2,e7,jel1)


    ! Delete the element with the largest element number
    call remove_element2D(rhadapt,IsortedElements(4),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(4))


    ! Update list of elements meeting at vertices.
    ! Note that all elements are removed in the first step. Afterwards,
    ! element JEL is appended to the list of elements meeting at each vertex
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i2,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel2).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel3).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i5,iel).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad3Tria')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i5,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Quad3Tria')
      call sys_halt()
    end if

    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,jel2,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,jel2,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,jel3,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel3,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i5,jel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i5,jel2,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i5,jel3,ipos)


    ! Adjust number of elements
    rhadapt%InelOfType(TRIA_NVETRI2D) = rhadapt%InelOfType(TRIA_NVETRI2D)+3
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)-3
    
    
    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_4QUAD3TRIA,&
          Ivertices,Ielements)
    end if
  end subroutine coarsen_4Quad3Tria

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Quad4Tria(rhadapt,iel,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines four quadrilaterals resulting from a
    ! 1-quad : 4-quad refinement into four green triangles. At first glance
    ! this "coarsening" does not make sense since the number of elements
    ! is not reduced. However, the number of vertices is decreased by one.
    ! Moreover, the removal of this vertex may lead to further coarsening
    ! starting at the elements which meet at the deleted vertex.
    ! The numbering convention follows the strategy used for
    ! refinement, that is, the local numbering of the two outer triangles
    ! starts at the vertices of the macro element and the local numbering
    ! numbering of the interior triangle starts at the edge midpoint.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7) i7  (e3) i3          i4 (e7)      (e3) i3
    !      +-------+-------+             +---------------+
    !      |*      |      *|             |*          ---/|
    ! (e4) | iel3  |  iel2 | (e6)   (e4) |iel3   ---/ */ | (e6)
    !      |       |       |             |   ---/     /  |
    !    i8+-------+-------+i6    ->   i8+--/  iel2  /   |
    !      |     i9|       |             |-\        /    |
    ! (e8) | iel   |  iel1 | (e2)   (e8) |  --\    /     | (e2)
    !      |*      |      *|             |*iel -\ / iel1*|
    !      +-------+-------+             +-------+-------+
    !     i1 (e1) i5  (e5) i2           i1 (e1) i5  (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(9) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i6,i7,i8,i9
    
    ! Retrieve patch of elements
    iel1 = rhadapt%p_IneighboursAtElement(2,iel)
    iel2 = rhadapt%p_IneighboursAtElement(2,iel1)
    iel3 = rhadapt%p_IneighboursAtElement(2,iel2)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1,iel)
    i5 = rhadapt%p_IverticesAtElement(2,iel)
    i9 = rhadapt%p_IverticesAtElement(3,iel)
    i8 = rhadapt%p_IverticesAtElement(4,iel)
    i2 = rhadapt%p_IverticesAtElement(1,iel1)
    i6 = rhadapt%p_IverticesAtElement(2,iel1)
    i3 = rhadapt%p_IverticesAtElement(1,iel2)
    i7 = rhadapt%p_IverticesAtElement(2,iel2)
    i4 = rhadapt%p_IverticesAtElement(1,iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1,iel)
    e8 = rhadapt%p_IneighboursAtElement(4,iel)   
    e2 = rhadapt%p_IneighboursAtElement(1,iel1)
    e5 = rhadapt%p_IneighboursAtElement(4,iel1)
    e3 = rhadapt%p_IneighboursAtElement(1,iel2)
    e6 = rhadapt%p_IneighboursAtElement(4,iel2)
    e4 = rhadapt%p_IneighboursAtElement(1,iel3)
    e7 = rhadapt%p_IneighboursAtElement(4,iel3)


    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt,e2,e6,iel2,iel1,iel1,iel1)
    call update_ElementNeighbors2D(rhadapt,e3,e7,iel3,iel2,iel3,iel3)

    
    ! Update the four element
    call replace_element2D(rhadapt,iel,i1,i5,i8,e1,iel2,e8,e1,iel2,e8)
    call replace_element2D(rhadapt,iel1,i2,i3,i5,e2,iel2,e5,e6,iel2,e5)
    call replace_element2D(rhadapt,iel2,i3,i8,i5,iel3,iel,iel1,iel3,iel,iel1)
    call replace_element2D(rhadapt,iel3,i4,i8,i3,e4,iel2,e3,e4,iel2,e7)


    ! Update list of elements meeting at vertices. Note that we only have to
    ! add some elements to the vertices since all four elements are already
    ! "attached" to one of the four corner nodes
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,iel1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,iel3,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i5,iel2,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i8,iel2,ipos)
    
    ! Adjust number of elements
    rhadapt%InelOfType(TRIA_NVETRI2D) = rhadapt%InelOfType(TRIA_NVETRI2D)+4
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)-4
    
    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,i6,i7,i8,i9/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_4QUAD4TRIA,&
          Ivertices,Ielements)
    end if
  end subroutine coarsen_4Quad4Tria
    
  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_2Quad1Quad(rhadapt,iel,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines two quadrilaterals resulting from a
    ! 1-quad : 2-quad refinement into the macro quadrilateral.
    ! The remaining element JEL is labeled by the smallest element number
    ! of the four neighboring elements. Due to the numbering convention
    ! all elements can be determined by visiting neighbors along the
    ! second edge starting at the given element IEL. The resulting element
    ! JEL is oriented such that local numbering starts at the vertex of the
    ! macro element, that is, such that the first vertex is the oldest one.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7) i7  (e3) i3          i4 (e7)      (e3) i3
    !      +-------+-------+             +---------------+
    !      |       |      *|             |               |
    ! (e4) |       |       | (e6)   (e4) |               | (e6)
    !      |       |       |             |               |
    !      |  iel  |  iel1 |      ->     |      jel      |
    !      |       |       |             |               |
    ! (e8) |       |       | (e2)   (e8) |               | (e2)
    !      |*      |      *|             |*              |
    !      +-------+-------+             +---------------+
    !     i1 (e1) i5  (e5) i2           i1 (e1)     (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(8) :: Ivertices
    integer(PREC_VERTEXIDX),  dimension(TRIA_NVEQUAD2D) :: ImacroVertices
    integer, dimension(TRIA_NVEQUAD2D)                  :: IvertexAge
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,e1,e2,e3,e4,e5,e6,e7,e8,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i7
    integer                    :: istate
    
    ! Retrieve neighboring element
    iel1 = rhadapt%p_IneighboursAtElement(2,iel)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1,iel)
    i5 = rhadapt%p_IverticesAtElement(2,iel)
    i7 = rhadapt%p_IverticesAtElement(3,iel)
    i4 = rhadapt%p_IverticesAtElement(4,iel)
    i3 = rhadapt%p_IverticesAtElement(1,iel1)
    i2 = rhadapt%p_IverticesAtElement(4,iel1)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1,iel)
    e7 = rhadapt%p_IneighboursAtElement(3,iel)
    e4 = rhadapt%p_IneighboursAtElement(4,iel)    
    e3 = rhadapt%p_IneighboursAtElement(1,iel1)
    e5 = rhadapt%p_IneighboursAtElement(3,iel1)
    e2 = rhadapt%p_IneighboursAtElement(4,iel1)

    e8 = rhadapt%p_ImidneighboursAtElement(4,iel)
    e6 = rhadapt%p_ImidneighboursAtElement(4,iel1)


    ! Which is the smaller element?
    if (iel < iel1) then
      
      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt,e1,e5,iel1,iel,iel,iel)
      call update_ElementNeighbors2D(rhadapt,e2,e6,iel1,iel,iel)
      call update_ElementNeighbors2D(rhadapt,e3,e7,iel,iel1,iel,iel)


      ! The resulting quadrilateral will posses one of the states STATES_QUAD_REDx,
      ! whereby x can be 1,2,3 and 4. Die to our refinement convention, x=1,2,3
      ! should not appear, that is, local numbering of the resulting quadrilateral
      ! starts at the oldest vertex. to this end, we check the state of the 
      ! provisional quadrilateral (I1,I2,I3,I4) and transform the orientation.
      ImacroVertices = (/i1,i2,i3,i4/)
      IvertexAge = rhadapt%p_IvertexAge(ImacroVertices)
      istate = redgreen_getstateQuad(IvertexAge)
      
      select case(istate)
      case(STATE_QUAD_ROOT,STATE_QUAD_RED4)
        ! Update element IEL = (I1,I2,I3,I4)
        call replace_element2D(rhadapt,iel,i1,i2,i3,i4,e1,e2,e3,e4,e5,e6,e7,e8)
        
      case(STATE_QUAD_RED1)
        ! Update element IEL = (I2,I3,I4,I1)
        call replace_element2D(rhadapt,iel,i2,i3,i4,i1,e2,e3,e4,e1,e6,e7,e8,e5)

      case(STATE_QUAD_RED2)
        ! Update element IEL = (I3,I4,I1,I2)
        call replace_element2D(rhadapt,iel,i3,i4,i1,i2,e3,e4,e1,e2,e7,e8,e5,e6)

      case(STATE_QUAD_RED3)
        ! Update element IEL = (I4,I1,I2,I3)
        call replace_element2D(rhadapt,iel,i4,i1,i2,i3,e4,e1,e2,e3,e8,e5,e6,e7)
        
      case DEFAULT
        call output_line('Invalid state of resulting quadrilateral!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Quad1Quad')
        call sys_halt()
      end select


      ! Delete element IEL1
      call remove_element2D(rhadapt,iel1,ielReplace)
      if (ielReplace.ne.0)&
          call update_AllElementNeighbors2D(rhadapt,ielReplace,iel1)


      ! Update list of elements meeting at vertices.
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i2,iel1).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Quad1Quad')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel1).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Quad1Quad')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,iel,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,iel,ipos)

    else

      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt,e1,e5,iel1,iel,iel1,iel1)
      call update_ElementNeighbors2D(rhadapt,e3,e7,iel,iel1,iel1,iel1)
      call update_ElementNeighbors2D(rhadapt,e4,e8,iel,iel1,iel1)
      
      ! The resulting quadrilateral will posses one of the states STATES_QUAD_REDx,
      ! whereby x can be 1,2,3 and 4. Die to our refinement convention, x=1,2,3
      ! should not appear, that is, local numbering of the resulting quadrilateral
      ! starts at the oldest vertex. to this end, we check the state of the 
      ! provisional quadrilateral (I1,I2,I3,I4) and transform the orientation.
      ImacroVertices = (/i1,i2,i3,i4/)
      IvertexAge = rhadapt%p_IvertexAge(ImacroVertices)
      istate = redgreen_getstateQuad(IvertexAge)
      
      select case(istate)
      case(STATE_QUAD_ROOT,STATE_QUAD_RED4)
        ! Update element IEL1 = (I1,I2,I3,I4)
        call replace_element2D(rhadapt,iel1,i1,i2,i3,i4,e1,e2,e3,e4,e5,e6,e7,e8)
        
      case(STATE_QUAD_RED1)
        ! Update element IEL1 = (I2,I3,I4,I1)
        call replace_element2D(rhadapt,iel1,i2,i3,i4,i1,e2,e3,e4,e1,e6,e7,e8,e5)

      case(STATE_QUAD_RED2)
        ! Update element IEL1 = (I3,I4,I1,I2)
        call replace_element2D(rhadapt,iel1,i3,i4,i1,i2,e3,e4,e1,e2,e7,e8,e5,e6)

      case(STATE_QUAD_RED3)
        ! Update element IEL1 = (I4,I1,I2,I3)
        call replace_element2D(rhadapt,iel1,i4,i1,i2,i3,e4,e1,e2,e3,e8,e5,e6,e7)
        
      case DEFAULT
        call output_line('Invalid state of resulting quadrilateral!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Quad1Quad')
        call sys_halt()
      end select


      ! Delete element IEL
      call remove_element2D(rhadapt,iel,ielReplace)
      if (ielReplace.ne.0)&
          call update_AllElementNeighbors2D(rhadapt,ielReplace,iel)
      

      ! Update list of elements meeting at vertices.
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Quad1Quad')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_2Quad1Quad')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,iel1,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,iel1,ipos)

    end if


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,0,i7,0/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_2QUAD1QUAD,&
          Ivertices,Ielements)
    end if
  end subroutine coarsen_2Quad1Quad

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_2Quad3Tria(rhadapt,iel,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines two quadrilaterals resulting from a
    ! 1-quad : 2-quad refinement into three green triangles. At first glance
    ! this "coarsening" does not make sense since the number of elements
    ! is even increased. However, the number of vertices is decreased by one.
    ! Moreover, the removal of this vertex may lead to further coarsening
    ! starting at the elements which meet at the deleted vertex.
    ! The numbering convention follows the strategy used for
    ! refinement, that is, the local numbering of the two outer triangles
    ! starts at the vertices of the macro element and the local numbering
    ! numbering of the interior triangle starts at the edge midpoint.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7) i7  (e3) i3          i4 (e7)      (e3) i3
    !      +-------+-------+             +---------------+
    !      |       |      *|             |\             /|
    ! (e4) |       |       | (e6)   (e4) | \           / | (e6)
    !      |       |       |             |  \  nel+1  /  |
    !      |  iel  |  iel1 |      ->     |   \       /   |
    !      |       |       |             |    \     /    |
    ! (e8) |       |       | (e2)   (e8) | iel \   / iel1| (e2)
    !      |*      |      *|             |*     \*/     *|
    !      +-------+-------+             +-------+-------+
    !     i1 (e1) i5  (e5) i2           i1 (e1) i5  (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_VERTEXIDX),  dimension(8) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,nel0,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5,i7

    ! Retrieve neighboring element
    iel1 = rhadapt%p_IneighboursAtElement(2,iel)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1,iel)
    i5 = rhadapt%p_IverticesAtElement(2,iel)
    i7 = rhadapt%p_IverticesAtElement(3,iel)
    i4 = rhadapt%p_IverticesAtElement(4,iel)
    i3 = rhadapt%p_IverticesAtElement(1,iel1)
    i2 = rhadapt%p_IverticesAtElement(4,iel1)

    ! Store values of the elements adjacent to the resulting macro element
    e1 = rhadapt%p_IneighboursAtElement(1,iel)
    e7 = rhadapt%p_IneighboursAtElement(3,iel)
    e4 = rhadapt%p_IneighboursAtElement(4,iel)
    e3 = rhadapt%p_IneighboursAtElement(1,iel1)
    e5 = rhadapt%p_IneighboursAtElement(3,iel1)
    e2 = rhadapt%p_IneighboursAtElement(4,iel1)

    e8 = rhadapt%p_ImidneighboursAtElement(4,iel)
    e6 = rhadapt%p_ImidneighboursAtElement(4,iel1)

    ! Store total number of elements before refinement
    nel0 = rhadapt%NEL
    

    ! Replace elements IEL and IEL1 and add one new element JEL
    call replace_element2D(rhadapt,iel,i1,i5,i4,e1,nel0+1,e4,e1,nel0+1,e8)
    call replace_element2D(rhadapt,iel1,i2,i3,i5,e2,nel0+1,e5,e6,nel0+1,e5)
    call add_element2D(rhadapt,i5,i3,i4,iel1,e3,iel,iel1,e7,iel)


    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt,e3,e7,iel,iel1,nel0+1,nel0+1)


    ! Update list of elements meeting at vertices.
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,nel0+1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,nel0+1,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i5,nel0+1,ipos)


    ! Adjust number of elements
    rhadapt%InelOfType(TRIA_NVETRI2D) = rhadapt%InelOfType(TRIA_NVETRI2D)+2
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)-2

    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5,0,i7,0/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_2QUAD3TRIA,&
          Ivertices,Ielements)
    end if
  end subroutine coarsen_2Quad3Tria

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_3Tria1Quad(rhadapt,iel,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines three triangles resulting from a
    ! 1-quad : 3-tria refinement into the macro quadrilateral.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)     (e3) i3          i4 (e7)      (e3) i3
    !      +---------------+             +---------------+
    !      |\             /|             |               |
    ! (e4) | \           / | (e6)   (e4) |               | (e6)
    !      |  \   iel   /  |             |               |
    !      |   \       /   |      ->     |      jel      |
    !      |    \     /    |             |               |
    ! (e8) | iel1\   /iel2 | (e2)   (e8) |               | (e2)
    !      |*     \*/     *|             |*              |
    !      +-------+-------+             +---------------+
    !     i1 (e1) i5  (e5) i2           i1 (e1)     (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>
    
    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(3) :: IsortedElements
    integer(PREC_VERTEXIDX),  dimension(5) :: Ivertices
    integer(PREC_VERTEXIDX),  dimension(TRIA_NVEQUAD2D) :: ImacroVertices
    integer, dimension(TRIA_NVEQUAD2D)                  :: IvertexAge
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,e1,e2,e3,e4,e5,e6,e7,e8,jel,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i5
    integer                    :: istate

    ! Retrieve neighboring element
    iel2 = rhadapt%p_IneighboursAtElement(1,iel)
    iel1 = rhadapt%p_IneighboursAtElement(3,iel)

    ! Store vertex- and element-values of the four neighboring elements
    i5 = rhadapt%p_IverticesAtElement(1,iel)
    i3 = rhadapt%p_IverticesAtElement(2,iel)
    i4 = rhadapt%p_IverticesAtElement(3,iel)
    i1 = rhadapt%p_IverticesAtElement(1,iel1)
    i2 = rhadapt%p_IverticesAtElement(1,iel2)

    ! Store values of the elements adjacent to the resulting macro element
    e3 = rhadapt%p_IneighboursAtElement(2,iel)
    e1 = rhadapt%p_IneighboursAtElement(1,iel1)
    e4 = rhadapt%p_IneighboursAtElement(3,iel1)
    e2 = rhadapt%p_IneighboursAtElement(1,iel2)
    e5 = rhadapt%p_IneighboursAtElement(3,iel2)

    e7 = rhadapt%p_ImidneighboursAtElement(2,iel)    
    e8 = rhadapt%p_ImidneighboursAtElement(3,iel1)
    e6 = rhadapt%p_ImidneighboursAtElement(1,iel2)


    ! Sort the three elements according to their number and
    ! determine the element with the smallest element number
    IsortedElements=(/iel,iel1,iel2/)
    call sort_I32(IsortedElements,SORT_INSERT)
    jel=IsortedElements(1)

    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt,e1,e5,iel2,iel1,jel,jel)
    call update_ElementNeighbors2D(rhadapt,e2,e6,iel2,jel,jel)
    call update_ElementNeighbors2D(rhadapt,e3,e7,iel,jel,jel)
    call update_ElementNeighbors2D(rhadapt,e4,e8,iel1,jel,jel)

    ! The resulting quadrilateral will posses one of the states STATES_QUAD_REDx,
    ! whereby x can be 1,2,3 and 4. Die to our refinement convention, x=1,2,3
    ! should not appear, that is, local numbering of the resulting quadrilateral
    ! starts at the oldest vertex. to this end, we check the state of the 
    ! provisional quadrilateral (I1,I2,I3,I4) and transform the orientation.
    ImacroVertices = (/i1,i2,i3,i4/)
    IvertexAge = rhadapt%p_IvertexAge(ImacroVertices)
    istate = redgreen_getstateQuad(IvertexAge)

    select case(istate)
    case(STATE_QUAD_ROOT,STATE_QUAD_RED4)
      ! Update element JEL = (I1,I2,I3,I4)
      call replace_element2D(rhadapt,jel,i1,i2,i3,i4,e1,e2,e3,e4,e5,e6,e7,e8)
      
    case(STATE_QUAD_RED1)
      ! Update element JEL = (I2,I3,I4,I1)
      call replace_element2D(rhadapt,jel,i2,i3,i4,i1,e2,e3,e4,e1,e6,e7,e8,e5)
      
    case(STATE_QUAD_RED2)
      ! Update element JEL = (I3,I4,I1,I2)
      call replace_element2D(rhadapt,jel,i3,i4,i1,i2,e3,e4,e1,e2,e7,e8,e5,e6)
      
    case(STATE_QUAD_RED3)
      ! Update element JEL = (I4,I1,I2,I3)
      call replace_element2D(rhadapt,jel,i4,i1,i2,i3,e4,e1,e2,e3,e8,e5,e6,e7)
      
    case DEFAULT
      call output_line('Invalid state of resulting quadrilateral!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_3Tria1Quad')
      call sys_halt()
    end select


    ! Delete the two elements with the largest element numbers
    call remove_element2D(rhadapt,IsortedElements(3),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(3))

    call remove_element2D(rhadapt,IsortedElements(2),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(2))


    ! Update list of elements meeting at vertices.
    ! Note that all elements are removed in the first step. Afterwards,
    ! element JEL is appended to the list of elements meeting at each vertex
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_3Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i2,iel2).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_3Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_3Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel2).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_3Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_3Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_3Tria1Quad')
      call sys_halt()
    end if
    
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel,ipos)      
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,jel,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,jel,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel,ipos)


    ! Adjust number of elements
    rhadapt%InelOfType(TRIA_NVETRI2D) = rhadapt%InelOfType(TRIA_NVETRI2D)-1
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)+1


    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,i5/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_3TRIA1QUAD,&
          Ivertices,Ielements)
    end if
  end subroutine coarsen_3Tria1Quad

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Tria1Quad(rhadapt,iel,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines four triangles resulting from a
    ! 1-quad : 4-tria refinement into the macro quadrilateral.
    ! The remaining element JEL is the ones with the smallest element number.
    ! The numbering convention follows the strategy used for refinement.
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)  i7 (e3) i3          i4 (e7)      (e3) i3
    !      +-------+-------+             +---------------+
    !      |*     / \-iel2*|             |               |
    ! (e4) |iel3 /    \--  | (e6)   (e4) |               | (e6)
    !      |    /        \-|             |               |
    !      |   /  iel    --+i6    ->     |      jel      |
    !      |  /      ---/  |             |               |
    ! (e8) | /*  ---/      | (e2)   (e8) |               | (e2)
    !      |/---/    iel1 *|             |*              |
    !      +---------------+             +---------------+
    !     i1 (e1)     (e5) i2           i1 (e1)     (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(4) :: IsortedElements
    integer(PREC_VERTEXIDX),  dimension(8) :: Ivertices
    integer(PREC_VERTEXIDX),  dimension(TRIA_NVEQUAD2D) :: ImacroVertices
    integer, dimension(TRIA_NVEQUAD2D)                  :: IvertexAge
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,e7,e8,jel,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i6,i7
    integer                    :: istate

    ! Retrieve patch of elements
    iel1 = rhadapt%p_IneighboursAtElement(1,iel)
    iel2 = rhadapt%p_IneighboursAtElement(2,iel)
    iel3 = rhadapt%p_IneighboursAtElement(3,iel)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1,iel)
    i6 = rhadapt%p_IverticesAtElement(2,iel)
    i7 = rhadapt%p_IverticesAtElement(3,iel)
    i2 = rhadapt%p_IverticesAtElement(1,iel1)
    i3 = rhadapt%p_IverticesAtElement(1,iel2)
    i4 = rhadapt%p_IverticesAtElement(1,iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e2 = rhadapt%p_IneighboursAtElement(1,iel1)  
    e1 = rhadapt%p_IneighboursAtElement(3,iel1)
    e3 = rhadapt%p_IneighboursAtElement(1,iel2)
    e6 = rhadapt%p_IneighboursAtElement(3,iel2)
    e4 = rhadapt%p_IneighboursAtElement(1,iel3)
    e7 = rhadapt%p_IneighboursAtElement(3,iel3)

    e5 = rhadapt%p_ImidneighboursAtElement(3,iel1)
    e8 = rhadapt%p_ImidneighboursAtElement(1,iel3)

    
    ! Sort the four elements according to their number and
    ! determine the elements with the smallest element numbers
    IsortedElements=(/iel,iel1,iel2,iel3/)
    call sort_I32(IsortedElements,SORT_INSERT)
    jel=IsortedElements(1)

    
    ! Update list of neighboring elements
    call update_ElementNeighbors2D(rhadapt,e1,e5,iel1,jel,jel)
    call update_ElementNeighbors2D(rhadapt,e2,e6,iel2,iel1,jel,jel)
    call update_ElementNeighbors2D(rhadapt,e3,e7,iel3,iel2,jel,jel)
    call update_ElementNeighbors2D(rhadapt,e4,e8,iel3,jel,jel)


    ! The resulting quadrilateral will posses one of the states STATES_QUAD_REDx,
    ! whereby x can be 1,2,3 and 4. Die to our refinement convention, x=1,2,3
    ! should not appear, that is, local numbering of the resulting quadrilateral
    ! starts at the oldest vertex. to this end, we check the state of the 
    ! provisional quadrilateral (I1,I2,I3,I4) and transform the orientation.
    ImacroVertices = (/i1,i2,i3,i4/)
    IvertexAge = rhadapt%p_IvertexAge(ImacroVertices)
    istate = redgreen_getstateQuad(IvertexAge)

    select case(istate)
    case(STATE_QUAD_ROOT,STATE_QUAD_RED4)
      ! Update element JEL = (I1,I2,I3,I4)
      call replace_element2D(rhadapt,jel,i1,i2,i3,i4,e1,e2,e3,e4,e5,e6,e7,e8)

    case(STATE_QUAD_RED1)
      ! Update element JEL = (I2,I3,I4,I1)
      call replace_element2D(rhadapt,jel,i2,i3,i4,i1,e2,e3,e4,e1,e6,e7,e8,e5)

    case(STATE_QUAD_RED2)
      ! Update element JEL = (I3,I4,I1,I2)
      call replace_element2D(rhadapt,jel,i3,i4,i1,i2,e3,e4,e1,e2,e7,e8,e5,e6)

    case(STATE_QUAD_RED3)
      ! Update element JEL = (I4,I1,I2,I3)
      call replace_element2D(rhadapt,jel,i4,i1,i2,i3,e4,e1,e2,e3,e8,e5,e6,e7)
      
    case DEFAULT
      call output_line('Invalid state of resulting quadrilateral!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Quad')
      call sys_halt()
    end select

    
    ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
    ! element corresponds to element with minimum number JEL
    call remove_element2D(rhadapt,IsortedElements(4),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(4))

    call remove_element2D(rhadapt,IsortedElements(3),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(3))
    
    call remove_element2D(rhadapt,IsortedElements(2),ielReplace)
    if (ielReplace.ne.0)&
        call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(2))

    
    ! Update list of elements meeting at vertices.
    ! Note that all elements are removed in the first step. Afterwards,
    ! element JEL is appended to the list of elements meeting at each vertex
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel3).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i2,iel1).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel2).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Quad')
      call sys_halt()
    end if
    if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel3).eq.&
        ARRAYLIST_NOT_FOUND) then
      call output_line('Unable to delete element from vertex list!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria1Quad')
      call sys_halt()
    end if
        
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,jel,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,jel,ipos)
    call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel,ipos)
    
    
    ! Adjust number of elements
    rhadapt%InelOfType(TRIA_NVETRI2D) = rhadapt%InelOfType(TRIA_NVETRI2D)-1
    rhadapt%InelOfType(TRIA_NVEQUAD2D) = rhadapt%InelOfType(TRIA_NVEQUAD2D)+1
    

    ! Optionally, invoke callback routine
    if (present(fcb_hadaptCallback).and.present(rcollection)) then
      Ivertices = (/i1,i2,i3,i4,0,i6,i7,0/)
      Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
      call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_4TRIA1QUAD,&
          Ivertices,Ielements)
    end if
  end subroutine coarsen_4Tria1Quad

  ! ***************************************************************************

!<subroutine>

  subroutine coarsen_4Tria3Tria(rhadapt,iel,imarker,rcollection,fcb_hadaptCallback)

!<description>
    ! This subroutine combines four triangles resulting from a
    ! 1-quad : 4-tria refinement into three green triangles. The remaining 
    ! elements JEL1, JEL2 and JEL3 are the ones with the smallest element number.
    ! The numbering convention follows the strategy used for refinement. 
    !
    !    initial quadrilateral      subdivided quadrilateral
    !
    !     i4 (e7)  i7 (e3) i3          i4 (e7)      (e3) i3
    !      +-------+-------+             +---------------+
    !      |*     / \-iel2*|             |---\          *|
    ! (e4) |iel3 /    \--  | (e6)   (e4) |    ---\ jel2  | (e6)
    !      |    /        \-|             |        ---\   |
    !      |   /  iel    --+i6    ->     |  jel3     *-- +i6
    !      |  /      ---/  |             |        ---/   |
    ! (e8) | /*  ---/      | (e2)   (e8) |    ---/       | (e2)
    !      |/---/    iel1 *|             |---/     jel1 *|
    !      +---------------+             +---------------+
    !     i1 (e1)     (e5) i2           i1 (e1)     (e5) i2
!</description>

!<input>
    ! Number of element to be refined
    integer(PREC_ELEMENTIDX), intent(IN) :: iel

    ! Identifiert for element marker
    integer, intent(IN)                  :: imarker

    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adativity structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer(PREC_ELEMENTIDX), dimension(8) :: Ielements
    integer(PREC_ELEMENTIDX), dimension(4) :: IsortedElements
    integer(PREC_VERTEXIDX),  dimension(8) :: Ivertices
    integer(PREC_ARRAYLISTIDX) :: ipos
    integer(PREC_ELEMENTIDX)   :: iel1,iel2,iel3,e1,e2,e3,e4,e5,e6,e7,e8
    integer(PREC_ELEMENTIDX)   :: jel1,jel2,jel3,ielReplace
    integer(PREC_VERTEXIDX)    :: i1,i2,i3,i4,i6,i7

    ! Retrieve patch of elements
    iel1 = rhadapt%p_IneighboursAtElement(1,iel)
    iel2 = rhadapt%p_IneighboursAtElement(2,iel)
    iel3 = rhadapt%p_IneighboursAtElement(3,iel)

    ! Store vertex- and element-values of the four neighboring elements
    i1 = rhadapt%p_IverticesAtElement(1,iel)
    i6 = rhadapt%p_IverticesAtElement(2,iel)
    i7 = rhadapt%p_IverticesAtElement(3,iel)
    i2 = rhadapt%p_IverticesAtElement(1,iel1)
    i3 = rhadapt%p_IverticesAtElement(1,iel2)
    i4 = rhadapt%p_IverticesAtElement(1,iel3)

    ! Store values of the elements adjacent to the resulting macro element
    e2 = rhadapt%p_IneighboursAtElement(1,iel1)  
    e1 = rhadapt%p_IneighboursAtElement(3,iel1)
    e3 = rhadapt%p_IneighboursAtElement(1,iel2)
    e6 = rhadapt%p_IneighboursAtElement(3,iel2)
    e4 = rhadapt%p_IneighboursAtElement(1,iel3)
    e7 = rhadapt%p_IneighboursAtElement(3,iel3)

    e5 = rhadapt%p_ImidneighboursAtElement(3,iel1)
    e8 = rhadapt%p_ImidneighboursAtElement(1,iel3)


    ! Sort the four elements according to their number and
    ! determine the elements with the smallest element numbers
    IsortedElements=(/iel,iel1,iel2,iel3/)
    call sort_I32(IsortedElements,SORT_INSERT)
    jel1=IsortedElements(1)
    jel2=IsortedElements(2)
    jel3=IsortedElements(3)
    
    ! Which midpoint vertex should be kept?
    select case(imarker)
    case(MARK_CRS_4TRIA3TRIA_RIGHT)
      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt,e1,e5,iel1,jel1,jel1)
      call update_ElementNeighbors2D(rhadapt,e2,e6,iel2,iel1,jel2,jel1)
      call update_ElementNeighbors2D(rhadapt,e3,e7,iel3,iel2,jel2,jel2)
      call update_ElementNeighbors2D(rhadapt,e4,e8,iel3,jel3,jel3)


      ! Update elements JEL1, JEL2 and JEL3
      call replace_element2D(rhadapt,jel1,i2,i6,i1,e2,jel3,e1,e2,jel3,e5)
      call replace_element2D(rhadapt,jel2,i3,i4,i6,e3,jel3,e6,e7,jel3,e6)
      call replace_element2D(rhadapt,jel3,i6,i4,i1,jel2,e4,jel1,jel2,e8,jel1)

      
      ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
      ! elements correspond to the two elements with smallest numbers
      call remove_element2D(rhadapt,IsortedElements(4),ielReplace)
      if (ielReplace.ne.0)&
          call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(4))


      ! Update list of elements meeting at vertices.
      ! Note that all elements are removed in the first step. Afterwards,
      ! element JEL is appended to the list of elements meeting at each vertex
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel1).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel3).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i2,iel1).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel2).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel3).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i6,iel).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i6,iel1).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i6,iel2).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel1,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel3,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,jel1,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,jel2,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel2,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel3,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i6,jel1,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i6,jel2,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i6,jel3,ipos)

      
      ! Optionally, invoke callback routine
      if (present(fcb_hadaptCallback).and.present(rcollection)) then
        Ivertices = (/i1,i2,i3,i4,0,i6,i7,0/)
        Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
        call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_4TRIA3TRIA2,&
            Ivertices,Ielements)
      end if
      

    case(MARK_CRS_4TRIA3TRIA_LEFT)
      ! Update list of neighboring elements
      call update_ElementNeighbors2D(rhadapt,e1,e5,iel1,jel3,jel3)
      call update_ElementNeighbors2D(rhadapt,e2,e6,iel2,iel1,jel1,jel1)
      call update_ElementNeighbors2D(rhadapt,e3,e7,iel3,iel2,jel2,jel1)
      call update_ElementNeighbors2D(rhadapt,e4,e8,iel3,jel2,jel2)

      
      ! Update elements JEL1, JEL2 and JEL3
      call replace_element2D(rhadapt,jel1,i3,i7,i2,e3,jel3,e2,e3,jel3,e6)
      call replace_element2D(rhadapt,jel2,i4,i1,i7,e4,jel3,e7,e8,jel3,e7)
      call replace_element2D(rhadapt,jel3,i7,i1,i2,jel2,e1,jel1,jel2,e5,jel1)

      
      ! Delete elements IEL, IEL1, IEL2 and IEL3 depending on which 
      ! elements correspond to the two elements with smallest numbers
      call remove_element2D(rhadapt,IsortedElements(4),ielReplace)
      if (ielReplace.ne.0)&
          call update_AllElementNeighbors2D(rhadapt,ielReplace,IsortedElements(4))


      ! Update list of elements meeting at vertices.
      ! Note that all elements are removed in the first step. Afterwards,
      ! element JEL is appended to the list of elements meeting at each vertex
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel1).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i1,iel3).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i2,iel1).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i3,iel2).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i4,iel3).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i7,iel).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i7,iel2).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if
      if (arrlst_deleteFromArraylist(rhadapt%relementsAtVertex,i7,iel3).eq.&
          ARRAYLIST_NOT_FOUND) then
        call output_line('Unable to delete element from vertex list!',&
            OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
        call sys_halt()
      end if

      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel2,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i1,jel3,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,jel1,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i2,jel3,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i3,jel1,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i4,jel2,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i7,jel1,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i7,jel2,ipos)
      call arrlst_appendToArraylist(rhadapt%relementsAtVertex,i7,jel3,ipos)

      ! Optionally, invoke callback routine
      if (present(fcb_hadaptCallback).and.present(rcollection)) then
        Ivertices = (/i1,i2,i3,i4,0,i6,i7,0/)
        Ielements = (/e1,e2,e3,e4,e5,e6,e7,e8/)
        call fcb_hadaptCallback(rcollection,HADAPT_OPR_CRS_4TRIA3TRIA3,&
            Ivertices,Ielements)
      end if

      
    case DEFAULT
      call output_line('Invalid position of midpoint vertex!',&
          OU_CLASS_ERROR,OU_MODE_STD,'coarsen_4Tria3Tria')
      call sys_halt()
    end select
  end subroutine coarsen_4Tria3Tria

  ! ***************************************************************************

!<subroutine>

  subroutine mark_refinement2D(rhadapt, rindicator)

!<description>
    ! This subroutine marks all elements that should be refined
    ! due to accuracy reasons. The decision is based on some 
    ! indicator vector which must be given element-wise.
!</description>

!<input>
    ! Indicator vector for refinement
    type(t_vectorScalar), intent(IN) :: rindicator
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT) :: rhadapt
!</inputoutput>
!</subroutine>

    ! local variables
    real(DP), dimension(:), pointer    :: p_Dindicator
    integer, dimension(:),  pointer    :: p_Imarker
    integer(PREC_VERTEXIDX),  dimension(TRIA_MAXNVE2D) :: IverticesAtElement
    integer(PREC_ELEMENTIDX), dimension(TRIA_MAXNVE2D) :: IneighboursAtElement
    integer, dimension(TRIA_MAXNVE)                    :: IvertexAge
    integer(PREC_VERTEXIDX)  :: ivt
    integer(PREC_ELEMENTIDX) :: iel,jel
    integer :: ive,nve,istate,jstate,isubdivide

    ! Check if dynamic data structures are generated and contain data
    if (iand(rhadapt%iSpec, HADAPT_HAS_DYNAMICDATA) .ne. HADAPT_HAS_DYNAMICDATA) then
      call output_line('Dynamic data structures are not generated!',&
          OU_CLASS_ERROR,OU_MODE_STD,'mark_refinement2D')
      call sys_halt()
    end if

    ! Initialize marker structure for NEL0 elements
    if (rhadapt%h_Imarker .ne. ST_NOHANDLE) call storage_free(rhadapt%h_Imarker)
    call storage_new('mark_refinement2D', 'Imarker', rhadapt%NEL0,&
                     ST_INT, rhadapt%h_Imarker, ST_NEWBLOCK_ZERO)


    ! Set pointers
    call lsyssc_getbase_double(rindicator, p_Dindicator)
    call storage_getbase_int(rhadapt%h_Imarker, p_Imarker)

    ! Set state of all vertices to "free". Note that vertices of the
    ! initial triangulation are always "locked", i.e. have no positive age.
    do ivt = 1, size(rhadapt%p_IvertexAge, 1)
      rhadapt%p_IvertexAge(ivt) = abs(rhadapt%p_IvertexAge(ivt))
    end do


    ! Loop over all elements and mark those for which the
    ! indicator is greater than the prescribed treshold
    mark_elem: do iel = 1, rhadapt%NEL

      ! Check if element indicator exceeds tolerance
      if (p_Dindicator(iel) .gt. rhadapt%drefinementTolerance) then
        
        ! Get number of vertices per elements
        nve = hadapt_getNVE(rhadapt, iel)

        ! Retrieve local data
        IverticesAtElement(1:nve)   = rhadapt%p_IverticesAtElement(1:nve, iel)
        IneighboursAtElement(1:nve) = rhadapt%p_IneighboursAtElement(1:nve, iel)

        ! An element can only be refined, if all of its vertices do
        ! not exceed the number of admissible subdivision steps.
        ! However, there is an exception to this rule: green elements can
        ! be refined/converted to the corresponding red elements.
        ! So, check the element type and loop over the 3 or 4 vertices.
        select case(nve)
          
        case(TRIA_NVETRI2D)
          ! If triangle has reached maximum number of refinement levels,
          ! then enforce no further refinement of this element
          isubdivide = maxval(abs(rhadapt%p_IvertexAge(&
                                  IverticesAtElement(1:TRIA_NVETRI2D))))

          if (isubdivide .eq. rhadapt%NSUBDIVIDEMAX) then

            ! Check if triangle is an inner/outer red triangle
            do ive = 1, TRIA_NVETRI2D
              IvertexAge(ive) = rhadapt%p_IvertexAge(IverticesAtElement(ive))
            end do
            istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))

            if ((istate .eq. STATE_TRIA_REDINNER) .or.&
                (istate .eq. STATE_TRIA_ROOT)) then

              ! Inner red triangle or root triangle 
              ! => no further refinement possible
              p_Imarker(iel) = MARK_ASIS
              
              ! According to the indicator, this element should be refined. Since the 
              ! maximum admissible refinement level has been reached no refinement 
              ! was performed. At the same time, all vertices of the element should
              ! be "locked" to prevent this element from coarsening
              do ive = 1, TRIA_NVETRI2D
                ivt = IverticesAtElement(ive)
                rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt)) 
              end do

              ! That's it for element IEL
              cycle mark_elem

            elseif (istate .eq. STATE_TRIA_OUTERINNER) then
              
              ! Possibly outer red triangle, get neighboring triangle
              jel = rhadapt%p_IneighboursAtElement(2, iel)

              ! Check state of neighboring triangle
              do ive = 1, TRIA_NVETRI2D
                IvertexAge(ive) = rhadapt%p_IvertexAge(rhadapt%p_IverticesAtElement(ive, jel))
              end do
              jstate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))

              if (jstate .eq. STATE_TRIA_REDINNER) then

                ! Outer red triangle => no further refinement
                p_Imarker(iel) = MARK_ASIS
                
                ! According to the indicator, this element should be refined. Since the 
                ! maximum admissible refinement level has been reached no refinement 
                ! was performed. At the same time, all vertices of the element should
                ! be "locked" to prevent this element from coarsening
                do ive = 1, TRIA_NVETRI2D
                  ivt = IverticesAtElement(ive)
                  rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt)) 
                end do

                ! That's it for element IEL
                cycle mark_elem
              end if
            end if
          end if   ! isubdivide = nsubdividemax

          
          ! Otherwise, we can mark the triangle for refinement
          p_Imarker(iel) = MARK_REF_TRIA4TRIA

          
          ! "Lock" all vertices connected to element IEL since the cannot be removed.
          do ive = 1, TRIA_NVETRI2D
            ivt = IverticesAtElement(ive)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
          end do
          
          
          ! Update number of new vertices. In principle, we can increase the number of 
          ! new vertices by 3, i.e., one for each edge. However, some care must be taken
          ! if the edge belongs to some adjacent element which has been marked for
          ! refinement previously. Hence, a new vertex is only added, if the edge is
          ! connected to the boundary or if the adjacent element has not been marked.
          do ive = 1, TRIA_NVETRI2D
            if (IneighboursAtElement(ive) .eq. 0 .or.&
                IneighboursAtElement(ive) .gt. rhadapt%NEL0) then

              ! Edge is adjacent to boundary or has not jet been processed
              rhadapt%increaseNVT = rhadapt%increaseNVT+1
              
            elseif((p_Imarker(IneighboursAtElement(ive)) .ne. MARK_REF_TRIA4TRIA) .and.&
                   (p_Imarker(IneighboursAtElement(ive)) .ne. MARK_REF_QUAD4QUAD)) then
              
              ! Edge has not been marked in previous steps
              rhadapt%increaseNVT = rhadapt%increaseNVT+1
            end if
          end do


        case(TRIA_NVEQUAD2D)
          ! If quadrilateral has reached maximum number of refinement levels,
          ! then enforce no further refinement of this element
          isubdivide = maxval(abs(rhadapt%p_IvertexAge(&
                                  IverticesAtElement(1:TRIA_NVEQUAD2D))))

          if (isubdivide .eq. rhadapt%NSUBDIVIDEMAX) then
            
            ! Check if quadrilateral is a red quadrilateral
            do ive = 1, TRIA_NVEQUAD2D
              IvertexAge(ive) = rhadapt%p_IvertexAge(IverticesAtElement(ive))
            end do
            istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))

            if ((istate .eq. STATE_QUAD_RED4) .or.&
                (istate .eq. STATE_QUAD_ROOT)) then
              
              ! Red quadrilateral => no further refinement
              p_Imarker(iel) = MARK_ASIS
              
              ! According to the indicator, this element should be refined. Since the 
              ! maximum admissible refinement level has been reached no refinement 
              ! was performed. At the same time, all vertices of the element should
              ! be "locked" to prevent this element from coarsening
              do ive = 1, TRIA_NVEQUAD2D
                ivt = IverticesAtElement(ive)
                rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt)) 
              end do              

              ! That's it for element IEL
              cycle mark_elem
            end if
          end if  ! isubdivide = nsubdividemax
          
          ! Otherwise, we can mark the quadrilateral for refinement
          p_Imarker(iel) = MARK_REF_QUAD4QUAD
          

          ! "Lock" all vertices connected to element IEL since the cannot be removed.
          do ive = 1, TRIA_NVEQUAD2D
            ivt = IverticesAtElement(ive)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
          end do

          
          ! Update number of new vertices. In principle, we can increase the number of 
          ! new vertices by 4, i.e., one for each edge. However, some care must be taken
          ! if the edge belongs to some adjacent element which has been marked for
          ! refinement previously. Hence, a new vertex is only added, if the edge is
          ! connected to the boundary or if the adjacent element has not been marked.

          do ive = 1, TRIA_NVEQUAD2D
            if (IneighboursAtElement(ive) .eq. 0 .or. &
                IneighboursAtElement(ive) .gt. rhadapt%NEL0) then

              ! Edge is adjacent to boundary or has not jet been processed
              rhadapt%increaseNVT = rhadapt%increaseNVT+1
              
            elseif((p_Imarker(IneighboursAtElement(ive)) .ne. MARK_REF_TRIA4TRIA) .and.&
                   (p_Imarker(IneighboursAtElement(ive)) .ne. MARK_REF_QUAD4QUAD)) then

              ! Edge has not been marked in previous steps
              rhadapt%increaseNVT = rhadapt%increaseNVT+1
            end if
          end do


        case DEFAULT
          call output_line('Invalid element type!',&
              OU_CLASS_ERROR,OU_MODE_STD,'mark_refinement2D')
          call sys_halt()
        end select
        
      else   ! p_Dindicator(IEL) <= drefinementTolerance

        ! Unmark element for refinement
        p_Imarker(iel) = MARK_ASIS

      end if
    end do mark_elem

    ! Set specifier to "marked for refinement"
    rhadapt%iSpec = ior(rhadapt%iSpec, HADAPT_MARKEDREFINE)

  end subroutine mark_refinement2D

!!$  ! ***************************************************************************
!!$
!!$!<subroutine>
!!$
!!$  SUBROUTINE redgreen_mark_coarsening2D(rhadapt, rindicator)
!!$
!!$!<description>
!!$    ! This routine marks all elements that sould be recoarsened due to accuracy
!!$    ! reasons. The decision is based on some indicator vector which must be 
!!$    ! given elementwise. The recoarsening strategy is as follows: A subset of
!!$    ! elements can only be coarsened if this subset results from a previous
!!$    ! refinement step. In other words, the grid cannot become coarser than the
!!$    ! initial triangulation. Moreover, one recoarsening step can only "undo"
!!$    ! what one refinement step can "do". This is in contrast to other "node-
!!$    ! removal" techniques, which remove all needless vertices and retriangulates
!!$    ! the generated "holes". However, such algorithms cannot guarantee a grid
!!$    ! hierarchy between refined and recoarsened grids.
!!$    !
!!$    ! In the context of hierarchical red-green mesh adaptivity, each recoarsening
!!$    ! step is the inverse operation of a previous refinement step. In other words,
!!$    ! the result of a complete recoarsening step could also be generated by locally
!!$    ! refining the initial triangulation. The algorithm is as follows:
!!$    !
!!$    ! 1) All vertices present in the initial triangulation cannot be removed. A 
!!$    ! vertex belongs to the initial triangulation if and only if its age is zero.
!!$    !
!!$    ! 2) All other nodes which do not belong to elements that are marked for 
!!$    ! refinement are potential candidates for removal. In order to prevent the
!!$    ! removel of such vertices, the nodes must be "locked" by some mechanism.
!!$    ! 
!!$    ! 3) All three/four nodes of a red triangle/quadrilateral are "locked" if 
!!$    ! the element should not be coarsened due to accuracy reasons. Otherwise, if
!!$    ! a red element should be coarsened then proceed as follows:
!!$    !  a) For a red quadrilateral "lock" the single vertex of the macro element
!!$    !  b) For a red outer triangle "lock" the single vertex of the macro element
!!$    !  c) For a red inner tringle do nothing
!!$    !
!!$    ! 4) For a green element "lock" the vertices of the macro element.
!!$    !
!!$    ! As a consequence, all vertices of macro elements are locked and in addition
!!$    ! all vertices belonging to red elements which should not be coarsened due to
!!$    ! accuracy reasons are removed from the list of removable nodes.
!!$    ! It remains to prevent the generaiton of blue elements to to nodal removal.
!!$    ! This must be done iteratively since "locking" of on vertex may alter the
!!$    ! situation for all adjacent elements. The generaiton of blue elements can
!!$    ! be prevented by applying the following rules:
!!$    !
!!$    ! 1) If an inner red triangle has two locked vertices, then the third vertex
!!$    ! is locked, too.
!!$    !
!!$    ! 2) If the youngest vertex of an outer green triangle (i.e. the vertex which
!!$    ! is responsible for the green refinement) is locked, then lock all nodes
!!$    ! connected to the green triangle. There is one exception to this rule. For
!!$    ! the "inner" green triangles resulting from a 1-quad : 4-tria refinement, 
!!$    ! this rule should not be applied since the four triangles can be converted
!!$    ! into three triangles if only one of the two "green vertices" are locked.
!!$    ! (apply 4-tria : 1-quad coarsening and eliminate the handing node by suitable
!!$    ! 1-quad : 3-tria refinement = 4-tria : 3-tria conversion).
!!$!</description>
!!$
!!$!<input>
!!$    ! Indicator vector for refinement
!!$    TYPE(t_vectorScalar), INTENT(IN) :: rindicator
!!$!</input>
!!$
!!$!<inputoutput>
!!$    ! Adaptive data structure
!!$    TYPE(t_hadapt), INTENT(INOUT) :: rhadapt
!!$!</inputoutput>
!!$!</subroutine>
!!$
!!$    ! local variables
!!$    REAL(DP), DIMENSION(:), POINTER                    :: p_Dindicator
!!$    INTEGER,  DIMENSION(:), POINTER                    :: p_Imarker
!!$    INTEGER(PREC_VERTEXIDX), DIMENSION(TRIA_MAXNVE2D)  :: IverticesAtElement
!!$    INTEGER(PREC_ELEMENTIDX), DIMENSION(TRIA_MAXNVE2D) :: ImacroElement
!!$    INTEGER, DIMENSION(TRIA_MAXNVE)                    :: IvertexAge
!!$    INTEGER(PREC_VERTEXIDX)  :: i,j
!!$    INTEGER(PREC_ELEMENTIDX) :: iel,jel,kel
!!$    INTEGER :: ive,nve,istate,jstate,ivertexLock
!!$    LOGICAL :: isModified
!!$
!!$    ! Check if dynamic data structures are generated and contain data
!!$    IF (IAND(rhadapt%iSpec,HADAPT_HAS_DYNAMICDATA) .NE. HADAPT_HAS_DYNAMICDATA .OR.&
!!$        IAND(rhadapt%iSpec,HADAPT_MARKEDREFINE)    .NE. HADAPT_MARKEDREFINE) THEN
!!$      CALL output_line('Dynamic data structures are not &
!!$          & generated or no marker for grid refinement exists!',&
!!$          OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$      CALL sys_halt()
!!$    END IF
!!$    
!!$    ! Set pointers
!!$    IF (rhadapt%h_Imarker .EQ. ST_NOHANDLE) THEN
!!$      CALL output_line('Marker array is not available!',&
!!$          OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$      CALL sys_halt()
!!$    END IF
!!$    CALL storage_getbase_int(rhadapt%h_Imarker, p_Imarker)
!!$    CALL lsyssc_getbase_double(rindicator, p_Dindicator)
!!$
!!$    ! All nodes of the initial triangulation have age-0 and, hence, will
!!$    ! never be deleted. Loop over all elements and "lock" nodes which 
!!$    ! should not be removed from the triangulation due to the indicator.
!!$    phase1: DO iel = 1, SIZE(p_Dindicator, 1)
!!$
!!$
!!$      ! Check if the current element is marked for refinement. Then
!!$      ! all vertices are/should be locked by the refinement procedure.
!!$      SELECT CASE(p_Imarker(iel))
!!$      CASE(MARK_REF_QUAD3TRIA_1,&
!!$           MARK_REF_QUAD3TRIA_2,&
!!$           MARK_REF_QUAD3TRIA_3,&
!!$           MARK_REF_QUAD3TRIA_4,&
!!$           MARK_REF_QUAD4TRIA_12,&
!!$           MARK_REF_QUAD4TRIA_23,&
!!$           MARK_REF_QUAD4TRIA_34,&
!!$           MARK_REF_QUAD4TRIA_14,&
!!$           MARK_REF_QUAD2QUAD_13,&
!!$           MARK_REF_QUAD2QUAD_24)
!!$        ! The current element is a quadrilateral that is marked for green 
!!$        ! refinement. In order to increase the performance of "phase 3" only
!!$        ! those elements are considered which are marked for coarsening.
!!$        ! Hence, we have to explicitely "lock" all vertices of quadrilaterals
!!$        ! which are marked or refinement "by hand"
!!$        DO ive=1,TRIA_NVEQUAD2D
!!$          i = rhadapt%p_IverticesAtElement(ive,iel)
!!$          rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$        END DO
!!$        CYCLE
!!$
!!$      CASE(MARK_ASIS_TRIA,MARK_ASIS_QUAD)
!!$        ! The current element is a candidate for coarsening
!!$        
!!$      CASE DEFAULT
!!$        ! The current element is markerd for refinement
!!$        CYCLE
!!$      END SELECT
!!$
!!$
!!$      ! Get number of vertices per element
!!$      nve=hadapt_getNVE(rhadapt,iel)
!!$
!!$      ! Get local data for element iel
!!$      IverticesAtElement(1:nve) = rhadapt%p_IverticesAtElement(1:nve,iel)
!!$
!!$      ! Get state of current element
!!$      SELECT CASE(nve)
!!$      CASE(TRIA_NVETRI2D)
!!$        IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
!!$            IverticesAtElement(1:TRIA_NVETRI2D))
!!$        istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
!!$
!!$      CASE(TRIA_NVEQUAD2D)
!!$        IvertexAge(1:TRIA_NVEQUAD2D) = rhadapt%p_IvertexAge(&
!!$            IverticesAtElement(1:TRIA_NVEQUAD2D))
!!$        istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))
!!$
!!$      CASE DEFAULT
!!$        CALL output_line('Invalid number of vertices per element!',&
!!$            OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$        CALL sys_halt()
!!$      END SELECT
!!$
!!$      
!!$      ! Phase 1: Depending on the state if the element IEL and the indicator
!!$      ! "lock" some or all of its nodes so that they will not be removed.
!!$      SELECT CASE(istate)
!!$
!!$        !-----------------------------------------------------------------------
!!$        ! The starting point of the re-coarsening algorithm are the red elements.
!!$        ! Strictly speaking, if all four subelements of a red-refinement should
!!$        ! be coarsened, then the aim is to convert them back into their original
!!$        ! macro element. On the other hand, if one or more red triangle cannot
!!$        ! be combined, then all of its nodes must be "locked".
!!$
!!$      CASE(STATE_TRIA_ROOT,STATE_QUAD_ROOT)
!!$        ! The vertices of a root triangle/quadrilateral have zero age by
!!$        ! definition. Hence, they are never deleted from the triangulation.
!!$
!!$        !-----------------------------------------------------------------------
!!$        ! Non-green elements: If the element is not marked for coarsening,
!!$        ! then "lock" all of its vertices. For quadrilateral elements, this
!!$        ! is sufficient to determine those elements which can be combined.
!!$        ! This algorithm works also for inner red triangles, but for outer
!!$        ! red triangles some more care must be taken. An outer red triangle
!!$        ! has the same state as an inner triangle of a 1-quad : 4-tria 
!!$        ! refinement. Hence, we must check, if the current triangle is 
!!$        ! adjacent to an inner red triangle in order to apply the algorithm.
!!$
!!$      CASE(STATE_QUAD_RED1,STATE_QUAD_RED2,STATE_QUAD_RED3)
!!$        ! Element IEL is red sub-element of a Quad4Quad refinement.
!!$        ! Due to our orientation convention these cases should not appear.
!!$        CALL output_line('This state should not appear!',&
!!$            OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$        CALL sys_halt()
!!$
!!$      CASE(STATE_QUAD_RED4)
!!$        ! Element IEL is red sub-element of a Quad4Quad refinement.
!!$
!!$        ! Should the element be coarsened?
!!$        IF (p_Dindicator(iel) .GE. rhadapt%dcoarseningTolerance) THEN
!!$
!!$          ! If this is not the case, then "lock" all of its four nodes
!!$          DO ive=1,TRIA_NVEQUAD2D
!!$            i = rhadapt%p_IverticesAtElement(ive,iel)
!!$            rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$          END DO
!!$        ELSE
!!$
!!$          ! Otherwise, "lock" only the node from the macro element.
!!$          ! Due to the refinement strategy, this is the first vertex.
!!$          i = rhadapt%p_IverticesAtElement(1,iel)
!!$          rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$          ! Provisionally, mark element for generic coarsening
!!$          p_Imarker(iel)=MARK_CRS_GENERIC
!!$        END IF
!!$
!!$      CASE(STATE_TRIA_REDINNER)
!!$        ! Element IEL is inner red triangle of a Tria4Tria refinement.
!!$        
!!$        ! Should the element be coarsened?
!!$        IF (p_Dindicator(iel) .GE. rhadapt%dcoarseningTolerance) THEN
!!$          
!!$          ! If this is not the case, then "lock" all of its three nodes
!!$          DO ive=1,TRIA_NVETRI2D
!!$            i = rhadapt%p_IverticesAtElement(ive,iel)
!!$            rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$          END DO
!!$
!!$        ELSE
!!$          ! Otherwise, mark element for generic coarsening
!!$          p_Imarker(iel)=MARK_CRS_GENERIC
!!$        END IF
!!$
!!$      CASE(STATE_TRIA_OUTERINNER)
!!$        ! Element IEL is either an outer red triangle of a 1-tria : 4-tria re-
!!$        ! finement or one of the two inner triangles of a 1-quad : 4-tria refinement
!!$        
!!$        ! Are we outer red triangle that was not created during the 
!!$        ! red-green marking routine as a result of element conversion?
!!$        jel = rhadapt%p_IneighboursAtElement(2,iel)
!!$        IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
!!$                 rhadapt%p_IverticesAtElement(1:TRIA_NVETRI2D,jel))
!!$        jstate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
!!$        
!!$        IF (jstate .EQ. STATE_TRIA_REDINNER) THEN
!!$          
!!$          ! Should the element be coarsened?
!!$          IF (p_Dindicator(iel) .GE. rhadapt%dcoarseningTolerance) THEN
!!$
!!$            ! If this is not the case, then "lock" all of its three nodes
!!$            DO ive=1,TRIA_NVETRI2D
!!$              i = rhadapt%p_IverticesAtElement(ive,iel)
!!$              rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$            END DO
!!$          ELSE
!!$            
!!$            ! Otherwise, "lock" only the node from the macro element.
!!$            ! Due to the refinement strategy, this is the first vertex.
!!$            i = rhadapt%p_IverticesAtElement(1,iel)
!!$            rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$            ! Provisionally, mark element for generic coarsening
!!$            p_Imarker(iel)=MARK_CRS_GENERIC
!!$          END IF
!!$        ELSE
!!$          
!!$          ! We are an inner green triangle resulting from a 1-quad : 4-tria
!!$          ! refinement. By construction, the first vertex belongs to the macro
!!$          ! element and, consequently, has to be "locked" from removal
!!$          i = rhadapt%p_IverticesAtElement(1,iel)
!!$          rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$          ! Provisionally, mark element for generic coarsening
!!$          p_Imarker(iel)=MARK_CRS_GENERIC
!!$        END IF
!!$
!!$        !-----------------------------------------------------------------------
!!$        ! Green elements: "Lock" the vertices of the macro element.
!!$        ! This sounds rather complicated but it is an easy task.
!!$        ! All non-green elements have been processed before, so we can be sure
!!$        ! to deal only with green elements. For a green element that results 
!!$        ! from a 1-tria : 2-tria refinement, we know that the vertices of the
!!$        ! macro element are located at the first position. The other "old" node
!!$        ! is the second/third vertex depending on the position of the green
!!$        ! triangle, i.e. right/left. By construction, this is also true for
!!$        ! the outer green triangles resulting from a 1-quad : 3/4-tria
!!$        ! refinement. It suffices to check for inner green triangles of a
!!$        ! 1-quad : 3-tria refinement, since the inner triangles of a 1-quad :
!!$        ! 4-tria refinement are processed in (STATE_TRIA_OUTERINNER)
!!$        !-----------------------------------------------------------------------
!!$        
!!$      CASE(STATE_TRIA_GREENOUTER_RIGHT)
!!$        ! Element IEL is right green triangle resulting from a 1-tria : 2-tria
!!$        ! refinement. Here, the third vertex is the one which was last inserted.
!!$        ! Hence, the first vertex is older then the third one by construction.
!!$        i = rhadapt%p_IverticesAtElement(1,iel)
!!$        rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$        i = rhadapt%p_IverticesAtElement(2,iel)
!!$        rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$        ! Provisionally, mark element for generic coarsening
!!$        p_Imarker(iel)=MARK_CRS_GENERIC
!!$        
!!$      CASE(STATE_TRIA_GREENOUTER_LEFT)
!!$        ! Element IEL is left green triangle resulting from a 1-tria : 2-tria
!!$        ! refinement. Here, the second vertex is the one which was last insrted.
!!$        ! Hence, the first vertex is older than the second one by construction.
!!$        i = rhadapt%p_IverticesAtElement(1,iel)
!!$        rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$        i = rhadapt%p_IverticesAtElement(3,iel)
!!$        rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$        ! Provisionally, mark element for generic coarsening
!!$        p_Imarker(iel)=MARK_CRS_GENERIC
!!$
!!$      CASE(STATE_TRIA_GREENINNER)
!!$        ! Element IEL is the inner green triangle resulting from a 1-quad :
!!$        ! 3-tria refinement. By construction, the first vertex is the newly
!!$        ! introduced one which is the youngest vertex of the element. Hence,
!!$        ! "lock" both the second and the third vertex which belong to the
!!$        ! original macro element which was a quadrilateral
!!$        i = rhadapt%p_IverticesAtElement(2,iel)
!!$        rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$        
!!$        j = rhadapt%p_IverticesAtElement(3,iel)
!!$        rhadapt%p_IvertexAge(j)=-ABS(rhadapt%p_IvertexAge(j))
!!$
!!$        ! Provisionally, mark element for generic coarsening
!!$        p_Imarker(iel)=MARK_CRS_GENERIC
!!$
!!$      CASE(STATE_QUAD_HALF1,STATE_QUAD_HALF2)
!!$        ! Element IEL is a green sub-element of a Quad2Quad refinement.
!!$        
!!$        ! Should the element be coarsened?
!!$        IF (p_Dindicator(iel) .GE. rhadapt%dcoarseningTolerance) THEN
!!$
!!$          ! If this is not the case, then "lock" all of its four nodes
!!$          DO ive=1,TRIA_NVEQUAD2D
!!$            i = rhadapt%p_IverticesAtElement(ive,iel)
!!$            rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$          END DO
!!$        ELSE
!!$          
!!$          ! Otherwise, "lock" only the node from the macro element.
!!$          ! Due to the refinement strategy, this is the first and fourth vertex.
!!$          i = rhadapt%p_IverticesAtElement(1,iel)
!!$          rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$          i = rhadapt%p_IverticesAtElement(4,iel)
!!$          rhadapt%p_IvertexAge(i)=-ABS(rhadapt%p_IvertexAge(i))
!!$
!!$          ! Provisionally, mark element for generic coarsening
!!$          p_Imarker(iel)=MARK_CRS_GENERIC
!!$        END IF
!!$
!!$      CASE DEFAULT
!!$        CALL output_line('Invalid element state!',&
!!$            OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$        CALL sys_halt()
!!$      END SELECT
!!$    END DO phase1
!!$
!!$    ! Phase 2: Prevent the recoarsening algorithm from generating blue elements.
!!$    ! The above loop "locked" all vertices, which should not be removed either
!!$    ! based on the indicator vector or due to the fact, that the vertex 
!!$    ! correcponds to the outer macro element. However, we have to keep in mind
!!$    ! that blue elements could be generated during recoarsening. In short,
!!$    ! inner red triangles with two "locked" vertices and red quadrilaterals
!!$    ! for which the macro element has only one or two "unlocked" nodes must
!!$    ! be locked completely. Moreover, all nodes of a green element must be
!!$    ! "locked" if one of its youngest vertices (which have been created during
!!$    ! the last green-refinement) must not be removed, i.e., it is locked.
!!$    ! Keep in mind, that the "locking" of a vertex requires the recursive check
!!$    ! of all surrounding elements. In order to prevent this recursion, we make 
!!$    ! use of a do-while loop which is terminated of no more vertices are touched.
!!$
!!$    isModified=.TRUE.
!!$    DO WHILE(isModified)
!!$      isModified=.FALSE.
!!$
!!$      ! Loop over all elements (from the initial triangulation + those which
!!$      ! have been created during the conversion of green into red elements)
!!$      DO iel=1,rhadapt%NEL
!!$
!!$        ! Only process those elements which are candidates for removal
!!$        IF (p_Imarker(iel) .NE. MARK_CRS_GENERIC) CYCLE
!!$
!!$        ! Get number of vertices per element
!!$        nve=hadapt_getNVE(rhadapt,iel)
!!$        
!!$        ! Get local data for element iel
!!$        IverticesAtElement(1:nve) = rhadapt%p_IverticesAtElement(1:nve,iel)
!!$
!!$        ! Check if all vertices of the element are locked then delete element
!!$        ! from the list of removable elements. This could also be done in the
!!$        ! third phase when the locked vertices are translated into coarsening
!!$        ! rules. However, this check is relatively cheap as compared to the
!!$        ! computation of the exact element state for some elements. Heuristically,
!!$        ! a large number of elements can be filtered out by this check in advance
!!$        ! so that no detailed investigation of their vertices is required.
!!$        IF (ALL(rhadapt%p_IvertexAge(IverticesAtElement(1:nve)).LE.0)) THEN
!!$          p_Imarker(iel)=MERGE(MARK_ASIS_TRIA,MARK_ASIS_QUAD,nve .EQ. 3)
!!$          CYCLE
!!$        END IF
!!$        
!!$        ! Get state of current element
!!$        SELECT CASE(nve)
!!$        CASE(TRIA_NVETRI2D)
!!$          IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
!!$              IverticesAtElement(1:TRIA_NVETRI2D))
!!$          istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
!!$
!!$        CASE(TRIA_NVEQUAD2D)
!!$          IvertexAge(1:TRIA_NVEQUAD2D) = rhadapt%p_IvertexAge(&
!!$              IverticesAtElement(1:TRIA_NVEQUAD2D))
!!$          istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))
!!$
!!$        CASE DEFAULT
!!$          CALL output_line('Invalid number of vertices per element!',&
!!$              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$          CALL sys_halt()
!!$        END SELECT
!!$        
!!$        ! Do we have to "lock" some vertices?
!!$        SELECT CASE(istate)
!!$
!!$        CASE(STATE_QUAD_RED4)
!!$          ! Element IEL is one of four red quadrilaterals of a 1-quad : 4-quad refinement.
!!$
!!$          ! If the interior vertex is locked then lock all vertices of the element
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$
!!$            ! Lock all other vertices. Note that the first vertiex and the third
!!$            ! one are already locked, so that we have to consider vertices 2 and 4
!!$            DO ive=2,TRIA_NVEQUAD2D,2
!!$              rhadapt%p_IvertexAge(IverticesAtElement(ive))=&
!!$                  -ABS(rhadapt%p_IvertexAge(IverticesAtElement(ive)))
!!$            END DO
!!$
!!$            ! Delete element from list of removable elements
!!$            p_Imarker(iel)=MARK_ASIS_QUAD
!!$            
!!$            ! We modified some vertex in this iteration
!!$            isModified=.TRUE.
!!$
!!$          ! If three midpoint vertices of adjacent quadrilaterals are locked
!!$          ! then all vertices of the four red sub-quadrilaterals must be locked
!!$          ! in order to prevent the generation of blue quadrilaterals
!!$          ELSEIF(rhadapt%p_IvertexAge(IverticesAtElement(2)) .LE. 0 .AND.&
!!$                 rhadapt%p_IvertexAge(IverticesAtElement(4)) .LE. 0) THEN
!!$            
!!$            ! Check the midpoint of the counterclockwise neighboring element
!!$            jel = rhadapt%p_IneighboursAtElement(2,iel)
!!$            i   = rhadapt%p_IverticesAtElement(2,jel)
!!$            IF (rhadapt%p_IvertexAge(i) .LE. 0) THEN
!!$              
!!$              ! Lock all vertices of element IEL. Due to the fact that the interior
!!$              ! vertex is locked, the nodes of all other quadrilaterals will be
!!$              ! locked in the next loop of phase 2.
!!$              DO ive=1,TRIA_NVEQUAD2D
!!$                rhadapt%p_IvertexAge(IverticesAtElement(ive))=&
!!$                    -ABS(rhadapt%p_IvertexAge(IverticesAtElement(ive)))
!!$              END DO
!!$
!!$              ! Delete element from list of removable elements
!!$              p_Imarker(iel)=MARK_ASIS_QUAD
!!$              
!!$              ! We modified some vertex in this iteration
!!$              isModified=.TRUE.
!!$              CYCLE
!!$            END IF
!!$
!!$            ! Check the midpoint of the clockwise neighboring element
!!$            jel = rhadapt%p_IneighboursAtElement(3,iel)
!!$            i   = rhadapt%p_IverticesAtElement(4,jel)
!!$            IF (rhadapt%p_IvertexAge(i) .LE. 0) THEN
!!$              
!!$              ! Lock all vertices of element IEL. Due to the fact that the interior
!!$              ! vertex is locked, the nodes of all other quadrilaterals will be
!!$              ! locked in the next loop of phase 2.
!!$              DO ive=1,TRIA_NVEQUAD2D
!!$                rhadapt%p_IvertexAge(IverticesAtElement(ive))=&
!!$                    -ABS(rhadapt%p_IvertexAge(IverticesAtElement(ive)))
!!$              END DO
!!$
!!$              ! Delete element from list of removable elements
!!$              p_Imarker(iel)=MARK_ASIS_QUAD
!!$              
!!$              ! We modified some vertex in this iteration
!!$              isModified=.TRUE.
!!$              CYCLE
!!$            END IF
!!$          END IF
!!$
!!$        CASE(STATE_TRIA_REDINNER)
!!$          ! Element IEL is inner red triangle of a 1-tria : 4-tria refinement.
!!$          
!!$          ! Determine number of locked vertices of the inner triangle.
!!$          ivertexLock=0
!!$          DO ive=1,TRIA_NVETRI2D
!!$            IF (rhadapt%p_IvertexAge(IverticesAtElement(ive)) .LE. 0)&
!!$                ivertexLock=ivertexLock+1
!!$          END DO
!!$          
!!$          ! How many vertices are locked?
!!$          SELECT CASE(ivertexLock)
!!$          CASE(2)
!!$            ! If exactly two vertices are locked, then "lock" the third one, too.
!!$            DO ive=1,TRIA_NVETRI2D
!!$              rhadapt%p_IvertexAge(IverticesAtElement(ive))=&
!!$                  -ABS(rhadapt%p_IvertexAge(IverticesAtElement(ive)))
!!$            END DO
!!$            
!!$            ! Delete element from list of removable elements
!!$            p_Imarker(iel)=MARK_ASIS
!!$            
!!$            ! We modified some vertex in this iteration
!!$            isModified=.TRUE.
!!$            
!!$          CASE(3)
!!$            ! If exactly three vertices are locked, then delete element from 
!!$            ! list of removable elements
!!$            p_Imarker(iel)=MARK_ASIS
!!$          END SELECT
!!$
!!$        CASE(STATE_TRIA_GREENOUTER_RIGHT)
!!$          ! Element IEL is right green triangle of a 1-tria : 2-tria refinement.
!!$          
!!$          ! If the third vertex is locked, then "lock" all other vertices, too.
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$            
!!$            ! Lock all other vertices
!!$            DO ive=1,2
!!$              rhadapt%p_IvertexAge(IverticesAtElement(ive))=&
!!$                  -ABS(rhadapt%p_IvertexAge(IverticesAtElement(ive)))
!!$            END DO
!!$            
!!$            ! Delete element from list of removable elements              
!!$            p_Imarker(iel)=MARK_ASIS
!!$            
!!$            ! We modified some vertex in this iteration
!!$            isModified=.TRUE.
!!$          END IF
!!$          
!!$        CASE(STATE_TRIA_GREENOUTER_LEFT)
!!$          ! Element IEL is left green triangle of a 1-tria : 2-tria refinement.
!!$          
!!$          ! If the second vertex is locked, then "lock" all other vertices, too.
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(2)) .LE. 0) THEN
!!$            
!!$            ! Lock all other vertices
!!$            DO ive=1,TRIA_NVETRI2D,2
!!$              rhadapt%p_IvertexAge(IverticesAtElement(ive))=&
!!$                  -ABS(rhadapt%p_IvertexAge(IverticesAtElement(ive)))
!!$            END DO
!!$            
!!$            ! Delete element from list of removable elements              
!!$            p_Imarker(iel)=MARK_ASIS
!!$            
!!$            ! We modified some vertex in this iteration
!!$            isModified=.TRUE.
!!$          END IF
!!$
!!$        END SELECT
!!$      END DO
!!$    END DO
!!$
!!$    ! Phase 3: All vertices that are still "free" can be removed from the
!!$    ! triangulation. At the moment, elements are only marked for generic
!!$    ! removal and some of them cannot be removed, e.g., if all of its vertices
!!$    ! are locked. In a loop over all elements which are marked for generic
!!$    ! removal we determine how to remove the element or delete it from the
!!$    ! list of removable elements if all of its vertices are locked.
!!$    DO iel=1,rhadapt%NEL
!!$      
!!$      ! Only process those elements which are candidates for removal
!!$      IF (p_Imarker(iel) .NE. MARK_CRS_GENERIC) CYCLE
!!$
!!$      ! Get number of vertices per element
!!$      nve=hadapt_getNVE(rhadapt,iel)
!!$
!!$      ! Get local data for element IEL
!!$      IverticesAtElement(1:nve) = rhadapt%p_IverticesAtElement(1:nve,iel)
!!$      
!!$      ! Get state of current element
!!$      SELECT CASE(nve)
!!$      CASE(TRIA_NVETRI2D)
!!$        IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
!!$            IverticesAtElement(1:TRIA_NVETRI2D))
!!$        istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
!!$
!!$      CASE(TRIA_NVEQUAD2D)
!!$        IvertexAge(1:TRIA_NVEQUAD2D) = rhadapt%p_IvertexAge(&
!!$            IverticesAtElement(1:TRIA_NVEQUAD2D))
!!$        istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))
!!$
!!$      CASE DEFAULT
!!$        CALL output_line('Invalid number of vertices per element!',&
!!$            OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$        CALL sys_halt()
!!$      END SELECT
!!$      
!!$      ! What state are we?
!!$      SELECT CASE(istate)
!!$      CASE(STATE_TRIA_OUTERINNER,STATE_TRIA_GREENINNER)
!!$        ! Dummy CASE to prevent immediate stop in the default branch.
!!$
!!$      CASE(STATE_TRIA_REDINNER)
!!$        ! If all vertices of the element are free, then the inner red triangle
!!$        ! can be combined with its three neighboring red triangles so as to
!!$        ! recover the original macro triangle. If one vertex of the inner
!!$        ! triangle is locked, then the inner red tiangle together with its three
!!$        ! neighboring elements can be convertec into two green triangles.
!!$        IF (rhadapt%p_IvertexAge(IverticesAtElement(1)) .LE. 0) THEN
!!$          p_Imarker(iel)=MARK_CRS_4TRIA2TRIA_1
!!$
!!$        ELSEIF(rhadapt%p_IvertexAge(IverticesAtElement(2)) .LE. 0) THEN
!!$          p_Imarker(iel)=MARK_CRS_4TRIA2TRIA_2
!!$          
!!$        ELSEIF(rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$          p_Imarker(iel)=MARK_CRS_4TRIA2TRIA_3
!!$          
!!$        ELSE
!!$          p_Imarker(iel)=MARK_CRS_4TRIA1TRIA
!!$        END IF
!!$        
!!$      CASE(STATE_TRIA_GREENOUTER_LEFT)
!!$        ! We have to considered several situations depending on the state
!!$        ! of the adjacent element that shares the second edge.
!!$        jel = rhadapt%p_IneighboursAtElement(2,iel)
!!$        IverticesAtElement(1:TRIA_NVETRI2D) = &
!!$            rhadapt%p_IverticesAtElement(1:TRIA_NVETRI2D,jel)
!!$        IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
!!$            IverticesAtElement(1:TRIA_NVETRI2D))
!!$        jstate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
!!$        
!!$        ! What is the state of the "second-edge" neighbor?
!!$        SELECT CASE(jstate)
!!$        CASE(STATE_TRIA_GREENOUTER_RIGHT)
!!$          ! Elements IEL and JEL represent the two green triangles which result from
!!$          ! a 1-tria : 2-tria refinement. Since the youngest vertex is not locked
!!$          ! we can mark the left triangle for coarsening and leave the right on as is.
!!$          p_Imarker(iel)=MARK_CRS_2TRIA1TRIA
!!$          p_Imarker(jel)=MARK_ASIS          
!!$          
!!$        CASE(STATE_TRIA_GREENINNER)
!!$          ! If all vertices of element JEL are locked, then we can delete the
!!$          ! element from the list of removable elements. Recall that both 
!!$          ! vertices of the macro element are locked by definition so that it
!!$          ! suffices to check the remaining (first) vertex.
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(1)) .LE. 0) THEN
!!$            ! Delete element from list of removable elements              
!!$            p_Imarker(iel)=MARK_ASIS
!!$            p_Imarker(jel)=MARK_ASIS
!!$            kel = rhadapt%p_IneighboursAtElement(1,jel)
!!$            p_Imarker(kel)=MARK_ASIS
!!$          ELSE
!!$            ! Mark element for recoarsening together with its two neighbors
!!$            p_Imarker(iel)=MARK_ASIS
!!$            p_Imarker(jel)=MARK_CRS_3TRIA1QUAD
!!$            kel = rhadapt%p_IneighboursAtElement(1,jel)
!!$            p_Imarker(kel)=MARK_ASIS
!!$          END IF
!!$
!!$        CASE(STATE_TRIA_OUTERINNER)
!!$          ! If all vertices of element JEL are locked, then we can delete the
!!$          ! element from the list of removable elements. Recall that the vertex
!!$          ! of the macro element is locked by definition so that it suffices to
!!$          ! check the remaining second and third vertex individually.
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(2)) .LE. 0) THEN
!!$            IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$              ! Delete element from list of removable elements              
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(3,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            ELSE
!!$              ! Mark element for recoarsening together with its three neighbors,
!!$              ! whereby the green outer triangle to the right is preserved.
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_CRS_4TRIA3TRIA_RIGHT
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(3,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            END IF
!!$          ELSE
!!$            IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$              ! Mark element for recoarsening together with its three neighbors,
!!$              ! whereby the green outer triangle to the left is preserved.
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_CRS_4TRIA3TRIA_LEFT
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(3,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            ELSE
!!$              ! Mark element for recoarsening together with its three neighbors
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_CRS_4TRIA1QUAD
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(3,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            END IF
!!$          END IF
!!$            
!!$        CASE DEFAULT
!!$          CALL output_line('Invalid element state!',&
!!$              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$          CALL sys_halt()
!!$        END SELECT
!!$        
!!$      CASE(STATE_TRIA_GREENOUTER_RIGHT)
!!$        ! This case is skew-symmetric to STATE_TRIA_GREENOUTER_LEFT so that 
!!$        ! typically nothing needs to be done here. However, there is one exception
!!$        ! to this rule. If element IEL is the right outer green triangle resulting
!!$        ! from a 1-quad : 4-tria refinement and all vertices of the left outer 
!!$        ! green triangle are locked, then the above CASE will never be reached.
!!$        jel = rhadapt%p_IneighboursAtElement(2,iel)
!!$        IverticesAtElement(1:TRIA_NVETRI2D) = &
!!$            rhadapt%p_IverticesAtElement(1:TRIA_NVETRI2D,jel)
!!$        IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
!!$            IverticesAtElement(1:TRIA_NVETRI2D))
!!$        jstate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
!!$        
!!$        ! What is the state of the "second-edge" neighbor?
!!$        SELECT CASE(jstate)
!!$        CASE(STATE_TRIA_GREENOUTER_LEFT)
!!$          ! Elements IEL and JEL represent the two green triangles which result from
!!$          ! a 1-tria : 2-tria refinement. Since the youngest vertex is not locked
!!$          ! we can mark the left triangle for coarsening and leave the right on as is.
!!$          p_Imarker(iel)=MARK_ASIS
!!$          p_Imarker(jel)=MARK_CRS_2TRIA1TRIA
!!$
!!$        CASE(STATE_TRIA_GREENINNER)
!!$          ! If all vertices of element JEL are locked, then we can delete the
!!$          ! element from the list of removable elements. Recall that both 
!!$          ! vertices of the macro element are locked by definition so that it
!!$          ! suffices to check the remaining (first) vertex.
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(1)) .LE. 0) THEN
!!$            ! Delete element from list of removable elements              
!!$            p_Imarker(iel)=MARK_ASIS
!!$            p_Imarker(jel)=MARK_ASIS
!!$            kel = rhadapt%p_IneighboursAtElement(3,jel)
!!$            p_Imarker(kel)=MARK_ASIS
!!$          ELSE
!!$            ! Mark element for recoarsening together with its two neighbors
!!$            p_Imarker(iel)=MARK_ASIS
!!$            p_Imarker(jel)=MARK_CRS_3TRIA1QUAD
!!$            kel = rhadapt%p_IneighboursAtElement(3,jel)
!!$            p_Imarker(kel)=MARK_ASIS
!!$          END IF
!!$
!!$        CASE(STATE_TRIA_OUTERINNER)
!!$          ! If all vertices of element JEL are locked, then we can delete the
!!$          ! element from the list of removable elements. Recall that the vertex
!!$          ! of the macro element is locked by definition so that it suffices to
!!$          ! check the remaining second and third vertex individually.
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(2)) .LE. 0) THEN
!!$            IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$              ! Delete element from list of removable elements              
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(1,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            ELSE
!!$              ! Mark element for recoarsening together with its three neighbors,
!!$              ! whereby the green outer triangle to the right is preserved.
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_CRS_4TRIA3TRIA_RIGHT
!!$              kel = rhadapt%p_IneighboursAtElement(1,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            END IF
!!$          ELSE
!!$            IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$              ! Mark element for recoarsening together with its three neighbors,
!!$              ! whereby the green outer triangle to the left is preserved.
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_CRS_4TRIA3TRIA_LEFT
!!$              kel = rhadapt%p_IneighboursAtElement(1,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            ELSE
!!$              ! Mark element for recoarsening together with its three neighbors
!!$              p_Imarker(iel)=MARK_ASIS
!!$              p_Imarker(jel)=MARK_CRS_4TRIA1QUAD
!!$              kel = rhadapt%p_IneighboursAtElement(1,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$              kel = rhadapt%p_IneighboursAtElement(2,jel)
!!$              p_Imarker(kel)=MARK_ASIS
!!$            END IF
!!$          END IF
!!$          
!!$        CASE DEFAULT
!!$          CALL output_line('Invalid element state!',&
!!$              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$          CALL sys_halt()
!!$        END SELECT
!!$
!!$      CASE(STATE_QUAD_HALF1,STATE_QUAD_HALF2)
!!$        ! If the second vertex of element IEL is locked, then remove the element
!!$        ! from the list of removable elements. However, it is still possible that
!!$        ! the second vertex of the adjacent element is not locked so that "coarsening"
!!$        ! into three triangles is initiated from that element. If the second vertex
!!$        ! is not locked, then we check if the third vertex is not locked, either.
!!$        ! in this case, we can mark the element for coarsening into the macro element
!!$        ! and remove the neighboring element from the list of removable elements.
!!$        jel = rhadapt%p_IneighboursAtElement(2,iel)
!!$        
!!$        ! Check if the second vertex is locked
!!$        IF (rhadapt%p_IvertexAge(IverticesAtElement(2)) .LE. 0) THEN
!!$          ! Check if the third vertex is also locked
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$            ! Delete both elements from list of removable elements
!!$            p_Imarker(iel)=MARK_ASIS
!!$            p_Imarker(jel)=MARK_ASIS
!!$          ELSE
!!$            ! Mark element IEL for coarsening into three triangles, 
!!$            ! whereby the second vertex of element IEL is preserved
!!$            p_Imarker(iel)=MARK_CRS_2QUAD3TRIA
!!$            p_Imarker(jel)=MARK_ASIS
!!$          END IF
!!$        ELSE
!!$          IF (rhadapt%p_IvertexAge(IverticesAtElement(3)) .LE. 0) THEN
!!$            ! Mark element JEL for coarsening into three triangles,
!!$            ! whereby the second vertex of element JEL is preserved
!!$            p_Imarker(iel)=MARK_ASIS
!!$            p_Imarker(jel)=MARK_CRS_2QUAD3TRIA
!!$          ELSE
!!$            ! Mark element IEL for recoarsening into the macro element
!!$            p_Imarker(iel)=MARK_CRS_2QUAD1QUAD
!!$            p_Imarker(jel)=MARK_ASIS
!!$          END IF
!!$        END IF
!!$                
!!$      CASE(STATE_QUAD_RED4)
!!$        ! This is one of four quadrilaterals which result from a 1-quad : 4-quad
!!$        ! refinement. Here, the situation is slightly more difficult because 
!!$        ! multiple rotationally-symmetric situations have to be considered. The
!!$        ! four elements forming the macro element can be collected by visiting the
!!$        ! neighboring element along the second edge starting at element IEL. 
!!$
!!$        ! As a first step, determine the number of locked midpoints. This is done
!!$        ! by visiting all four elements and checking the second vertex individually.
!!$        ! Note that we do not only count the number of locked vertices but also
!!$        ! remember its position by setting or clearing the corresponding bit of
!!$        ! the integer ivertexLocked. In the same loop, we determine the numbers 
!!$        ! of the four elements of the macro element.
!!$        ImacroElement(1)=iel
!!$        ivertexLock=MERGE(2,0,&
!!$            rhadapt%p_IvertexAge(rhadapt%p_IverticesAtElement(2,iel)) .LE. 0)
!!$        
!!$        DO ive=2,TRIA_NVEQUAD2D
!!$          ImacroElement(ive) = rhadapt%p_IneighboursAtElement(2,ImacroElement(ive-1))
!!$          IF (rhadapt%p_IvertexAge(rhadapt%p_IverticesAtElement(2,&
!!$              ImacroElement(ive))) .LE. 0) ivertexLock=ibset(ivertexLock,ive)
!!$        END DO
!!$        
!!$        ! How many vertices are locked?
!!$        SELECT CASE(ivertexLock)
!!$        CASE(0)
!!$          ! Mark element IEL for recoarsening into the macro element and delete
!!$          ! all remaining elements from the list of removable elements.
!!$          p_Imarker(iel)=MARK_CRS_4QUAD1QUAD
!!$          DO ive=2,TRIA_NVEQUAD2D
!!$            p_Imarker(ImacroElement(ive))=MARK_ASIS
!!$          END DO
!!$
!!$        CASE(2)
!!$          ! There is one vertex locked which is the second vertex of the first 
!!$          ! element. All other elements are deleted from the list of removable elements
!!$          p_Imarker(ImacroElement(1))=MARK_CRS_4QUAD3TRIA
!!$          p_Imarker(ImacroElement(2))=MARK_ASIS
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(4)
!!$          ! There is one vertex locked which is the second vertex of the second
!!$          ! element. All other elements are deleted from the list of removable elements
!!$          p_Imarker(ImacroElement(1))=MARK_ASIS
!!$          p_Imarker(ImacroElement(2))=MARK_CRS_4QUAD3TRIA
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(8)
!!$          ! There is one vertex locked which is the second vertex of the third
!!$          ! element. All other elements are deleted from the list of removable elements
!!$          p_Imarker(ImacroElement(1))=MARK_ASIS
!!$          p_Imarker(ImacroElement(2))=MARK_ASIS
!!$          p_Imarker(ImacroElement(3))=MARK_CRS_4QUAD3TRIA
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(16)
!!$          ! There is one vertex locked which is the second vertex of the fourth
!!$          ! element. All other elements are deleted from the list of removable elements
!!$          p_Imarker(ImacroElement(1))=MARK_ASIS
!!$          p_Imarker(ImacroElement(2))=MARK_ASIS
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_CRS_4QUAD3TRIA
!!$
!!$        CASE(10)
!!$          ! There are two vertices locked which are the second vertices of the
!!$          ! first and third elements. Mark the first element for recoarsening.
!!$          p_Imarker(ImacroElement(1))=MARK_CRS_4QUAD2QUAD
!!$          p_Imarker(ImacroElement(2))=MARK_ASIS
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(20)
!!$          ! There are two vertices locked which are the second vertices of the
!!$          ! second and fourth elements. Mark the second element for recoarsening.
!!$          p_Imarker(ImacroElement(1))=MARK_ASIS
!!$          p_Imarker(ImacroElement(2))=MARK_CRS_4QUAD2QUAD
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(18)
!!$          ! There are two vertices locked which are the second and fourth vertices
!!$          ! of the firth elements. Mark the firth element for recoarsening.
!!$          p_Imarker(ImacroElement(1))=MARK_CRS_4QUAD4TRIA
!!$          p_Imarker(ImacroElement(2))=MARK_ASIS
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(6)
!!$          ! There are two vertices locked which are the second and fourth vertices
!!$          ! of the second elements. Mark the second element for recoarsening.
!!$          p_Imarker(ImacroElement(1))=MARK_ASIS
!!$          p_Imarker(ImacroElement(2))=MARK_CRS_4QUAD4TRIA
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(12)
!!$          ! There are two vertices locked which are the second and fourth vertices
!!$          ! of the third elements. Mark the third element for recoarsening.
!!$          p_Imarker(ImacroElement(1))=MARK_ASIS
!!$          p_Imarker(ImacroElement(2))=MARK_ASIS
!!$          p_Imarker(ImacroElement(3))=MARK_CRS_4QUAD4TRIA
!!$          p_Imarker(ImacroElement(4))=MARK_ASIS
!!$
!!$        CASE(24)
!!$          ! There are two vertices locked which are the second and fourth vertices
!!$          ! of the fourth elements. Mark the fourth element for recoarsening.
!!$          p_Imarker(ImacroElement(1))=MARK_ASIS
!!$          p_Imarker(ImacroElement(2))=MARK_ASIS
!!$          p_Imarker(ImacroElement(3))=MARK_ASIS
!!$          p_Imarker(ImacroElement(4))=MARK_CRS_4QUAD4TRIA
!!$
!!$        CASE DEFAULT
!!$          ! Delete all four elements from list of removable elements
!!$          DO ive=1,TRIA_NVEQUAD2D
!!$            p_Imarker(ImacroElement(ive))=MARK_ASIS
!!$          END DO
!!$        END SELECT
!!$        
!!$      CASE DEFAULT
!!$        CALL output_line('Invalid number of locked vertices!',&
!!$            OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
!!$        CALL sys_halt()
!!$      END SELECT
!!$    END DO
!!$
!!$    ! Set specifier to "marked for coarsening"
!!$    rhadapt%iSpec=IOR(rhadapt%iSpec,HADAPT_MARKEDCOARSEN)
!!$  END SUBROUTINE redgreen_mark_coarsening2D

  ! ***************************************************************************

!<subroutine>

  subroutine redgreen_mark_coarsening2D(rhadapt, rindicator)

!<description>
    ! This routine marks all elements that sould be recoarsened due to accuracy
    ! reasons. The decision is based on some indicator vector which must be 
    ! given element-wise. The recoarsening strategy is as follows: A subset of
    ! elements can only be coarsened if this subset results from a previous
    ! refinement step. In other words, the grid cannot become coarser than the
    ! initial triangulation. Moreover, one recoarsening step can only "undo"
    ! what one refinement step can "do". This is in contrast to other "node-
    ! removal" techniques, which remove all superficial vertices and retriangulate
    ! the generated "holes". However, such algorithms cannot guarantee a grid
    ! hierarchy between refined and recoarsened grids.
    !
    ! In the context of hierarchical red-green mesh adaptivity, each recoarsening
    ! step is the inverse operation of a previous refinement step. In other words,
    ! the result of a complete recoarsening step could also be generated by locally
    ! refining the initial triangulation. The algorithm is as follows:
    !
    ! 1) All vertices present in the initial triangulation cannot be removed. A 
    ! vertex belongs to the initial triangulation if and only if its age is zero.
    !
    ! 2) All other nodes which do not belong to elements that are marked for 
    ! refinement are potential candidates for removal. In order to prevent the
    ! removel of such vertices, the nodes must be "locked" by some mechanism.
    ! 
    ! 3) All three/four nodes of a red triangle/quadrilateral are "locked" if 
    ! the element should not be coarsened due to accuracy reasons.
    !
    ! 4) All vertices which belong to the macro element are "locked". Thus it
    ! suffices to consider all edges and "lock" one endpoint if its generation
    ! number is smaller than the generation number of the opposite endpoint.
    !
    ! It remains to prevent the generaiton of blue elements to to nodal removal.
    ! This must be done iteratively since "locking" of one vertex may alter the
    ! situation for all adjacent elements. The generation of blue elements can
    ! be prevented by applying the following rules:
    !
    ! A) If an inner red triangle has two locked vertices, 
    ! then the third vertex is locked, too.
    !
    ! B) If the youngest vertex of an outer green triangle (i.e. the vertex which
    ! is responsible for the green refinement) is locked, then lock all nodes
    ! connected to the green triangle. There is one exception to this rule. For
    ! the "inner" green triangles resulting from a 1-quad : 4-tria refinement, 
    ! this rule should not be applied since the four triangles can be converted
    ! into three triangles if only one of the two "green vertices" are locked.
    ! (apply 4-tria : 1-quad coarsening and eliminate the handing node by suitable
    ! 1-quad : 3-tria refinement = 4-tria : 3-tria conversion).
!</description>

!<input>
    ! Indicator vector for refinement
    type(t_vectorScalar), intent(IN) :: rindicator
!</input>

!<inputoutput>
    ! Adaptive data structure
    type(t_hadapt), intent(INOUT) :: rhadapt
!</inputoutput>
!</subroutine>

    ! local variables
    real(DP), dimension(:), pointer                    :: p_Dindicator
    integer,  dimension(:), pointer                    :: p_Imarker
    integer(PREC_VERTEXIDX), dimension(TRIA_MAXNVE2D)  :: IverticesAtElement
    integer(PREC_ELEMENTIDX), dimension(TRIA_MAXNVE2D) :: ImacroElement
    integer, dimension(TRIA_MAXNVE)                    :: IvertexAge
    integer(PREC_VERTEXIDX)  :: ivt,jvt
    integer(PREC_ELEMENTIDX) :: iel,jel,jelmid,kel
    integer :: istate,jstate,ive,jve,kve,nve,nlocked
    logical :: bisModified

    ! Check if dynamic data structures are generated and contain data
    if (iand(rhadapt%iSpec, HADAPT_HAS_DYNAMICDATA) .ne. HADAPT_HAS_DYNAMICDATA .or.&
        iand(rhadapt%iSpec, HADAPT_MARKEDREFINE)    .ne. HADAPT_MARKEDREFINE) then
      call output_line('Dynamic data structures are not &
          & generated or no marker for grid refinement exists!',&
          OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
      call sys_halt()
    end if
    
    ! Set pointers
    call storage_getbase_int(rhadapt%h_Imarker, p_Imarker)
    call lsyssc_getbase_double(rindicator, p_Dindicator)

    
    ! All nodes of the initial triangulation have age-0, and hence, 
    ! they will never be deleted by the re-coarsening procedure.
    !
    ! Phase 1: Lock vertices which cannot be deleted at first sight.
    !
    ! In the first phase, all vertices which do belong to some
    ! macro-element are "locked" since they cannot be deleted.
    !
    ! For each element which is marked for red refinement,
    ! the three/four corner vertices are "locked" unconditionally.
    !
    ! For each element that is not marked for red refinement, the 
    ! indicator is considered and all vertices are "locked" if
    ! re-coarsening is not allowed due to accuracy reasons.
    ! 
    ! There is one special case which needs to be considered.
    ! If a green element is marked for refinement, then it is 
    ! converted into the corresponding red element prior to
    ! performing further refinement. Therefore, the intermediate
    ! grid after (!) the "redgreen-marking" procedure may not
    ! satisfy the conformity property, e.g. a quadrilateral that
    ! is marked for red refinement may be adjacent to some former
    ! green element which is (!) already subdivided regularly.
    ! In this case, the "hanging" node at the edge midpoint 
    ! needs to be "locked" since it cannot be deleted. Note that
    ! such "hanging" nodes are not "locked" if the adjacent (not
    ! yet subdivided) element is not marked for red refinement.
    phase1: do iel = 1, rhadapt%NEL
      
      ! Check if the current element is marked for red refinement.
      select case(p_Imarker(iel))
        
      case(MARK_REF_QUAD4QUAD,&
           MARK_REF_TRIA4TRIA)

        ! The current element is marked for red refinement.
        ! Thus, we have to "lock" all vertices connected to it.
        ! Moreover, we have to "lock" vertices located at edge 
        ! midpoints which may be generated due to conversion of
        ! neighboring green elements into corresponding red ones.
        do ive = 1, hadapt_getNVE(rhadapt, iel)

          ! "Lock" vertex at corner
          ivt = rhadapt%p_IverticesAtElement(ive, iel)
          rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
          
          ! Get numbers of element(s) adjacent to the current edge
          jel    = rhadapt%p_IneighboursAtElement(ive, iel)
          jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)

          ! Check of neighboring element has been subdivided
          if (jel .ne. jelmid) then

            ! Find element IEL in adjacency list of element JEL
            ! and "lock" the corresponding midpoint vertex
            do jve = 1, hadapt_getNVE(rhadapt, jel)
              if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) then
                jvt = rhadapt%p_IverticesAtElement(jve, jel)
                rhadapt%p_IvertexAge(jvt) = -abs(rhadapt%p_IvertexAge(jvt))
                exit
              end if
            end do

          elseif (jel .ne. 0) then   ! adjacent element has not been 
                                     ! subdivided and is not boundary

            ! Lock all vertices in adjacent element
            do jve = 1, hadapt_getNVE(rhadapt, jel)
              jvt = rhadapt%p_IverticesAtElement(jve, jel)
              rhadapt%p_IvertexAge(jvt) = -abs(rhadapt%p_IvertexAge(jvt))
            end do
            
          end if
        end do
        
      case(:MARK_ASIS_QUAD)

        ! The current element is not marked for red refinement, and hence,
        ! it is a potential candidate for the re-coarsening algorithm.
        
        ! Get number of vertices per element
        nve = hadapt_getNVE(rhadapt, iel)

        ! Get local data for element iel
        do ive = 1, nve
          IverticesAtElement(ive) = rhadapt%p_IverticesAtElement(ive, iel)
        end do
        
        ! Check if element should be "locked" due to accuracy reasons.
        if (lockElement(iel)) then
          
          phase1_lock_all: do ive = 1, nve

            ! "Lock" vertex at corner
            ivt = IverticesAtElement(ive)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

          end do phase1_lock_all
          
        else   ! no need to keep element due to accuray reasons
          
          ! Loop over adjacent edges and check if the two endpoints have
          ! different age. If this is the case then "lock" the one with
          ! smaller generation number since it cannot be removed.
          phase1_lock_older: do ive = 1, nve
            
            ! Get global vertex numbers
            ivt = IverticesAtElement(ive)
            jvt = IverticesAtElement(mod(ive, nve)+1)

            ! Get numbers of element(s) adjacent to the current edge
            jel    = rhadapt%p_IneighboursAtElement(ive, iel)
            jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)
            
            ! Check if neighboring element has been subdivided
            if (jel .ne. jelmid) then

              ! "Lock" both endpoints of the current edge
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              rhadapt%p_IvertexAge(jvt) = -abs(rhadapt%p_IvertexAge(jvt))
              
            else   ! adjacent element has not bee subdivided

              ! Check if endpoints have different age and "lock" the older one
              if (abs(rhadapt%p_IvertexAge(ivt)) .lt.&
                  abs(rhadapt%p_IvertexAge(jvt))) then
                rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              elseif (abs(rhadapt%p_IvertexAge(jvt)) .lt.&
                  abs(rhadapt%p_IvertexAge(ivt))) then
                rhadapt%p_IvertexAge(jvt) = -abs(rhadapt%p_IvertexAge(jvt))
              end if
              
            end if
          end do phase1_lock_older

        end if   ! lock element due to accuracy reasons?

        
      case DEFAULT

        ! The current element is marked for some sort of green
        ! refinement, and hence, only the corner nodes have to be
        ! locked. Note that the rest is done elsewhere in this
        ! subroutine.
        
        do ive = 1, hadapt_getNVE(rhadapt, iel)
          
          ! "Lock" vertex at corner
          ivt = rhadapt%p_IverticesAtElement(ive, iel)
          rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
        end do
        
      end select
    end do phase1

    
    ! Phase 2: Prevent the generation of blue elements.
    !
    ! In the second phase, vertices are "locked" which would give rise to
    ! the creation of blue refinement pattern. In particular, there are
    ! three different situations which have to be considered:
    !
    ! (a) If two vertices of an inner red triangle are locked,
    !     then the third vertex is also locked
    !
    ! (b) If the "inner" node of a patch of four red quadrilaterals
    !     is locked, then lock all nine vertices of the patch
    !
    ! (c) If three midpoint vertices of a patch of four red quadrilaterals
    !     are locked, then lock all nine vertices of the patch
    !
    ! The locking of vertices may require the re-investigation of surrounding
    ! elements since they may give rise to the creation of blue elements.
    ! In order to circumvent this recursion, we make use of an infinite
    ! do-while loop which is terminated if no vertices have been "modified".
    
    ! Let's start
    bisModified = .true.
    phase2: do while(bisModified)

      ! Ok, hopefully no vertex will be modified
      bisModified = .false.

      ! Loop over all elements
      phase2_elem: do iel = 1, rhadapt%NEL

        ! Get number of vertices per element
        nve = hadapt_getNVE(rhadapt, iel)
        
        ! Get state of element IEL
        select case(nve)
        case(TRIA_NVETRI2D)
          do ive = 1, TRIA_NVETRI2D
            ivt                     = rhadapt%p_IverticesAtElement(ive, iel)
            IverticesAtElement(ive) = ivt
            IvertexAge(ive)         = rhadapt%p_IvertexAge(ivt)
          end do
          istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))


        case(TRIA_NVEQUAD2D)
          do ive = 1, TRIA_NVEQUAD2D
            ivt                     = rhadapt%p_IverticesAtElement(ive, iel)
            IverticesAtElement(ive) = ivt
            IvertexAge(ive)         = rhadapt%p_IvertexAge(ivt)
          end do
          istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))


        case DEFAULT
          call output_line('Invalid number of vertices per element!',&
              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
          call sys_halt()
        end select


        ! What element state do we have?
        select case(istate)
          
        case(STATE_QUAD_RED4)
          ! Element IEL is one of four red quadrilaterals of a 1-quad : 4-quad refinement.
          
          ! Check if the interior vertex is locked, then lock all vertices in patch
          if (rhadapt%p_IvertexAge(IverticesAtElement(3)) .le. 0) then
            
            ! Lock all other vertices. Note that the first vertex and the third one
            ! are already locked, so that we have to consider vertices 2 and 4.
              
            ! Get global number of second vertex
            ivt = rhadapt%p_IverticesAtElement(2, iel)
            
            if (rhadapt%p_IvertexAge(ivt) .gt. 0) then
              ! Lock second vertex if required
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ! We modified some vertices in this iteration
              bisModified = .true.
            end if

          else   ! Interior vertex is not locked

            ! Count the number of locked midpoint vertices
            jel = iel; nlocked = 0
            do ive = 1, TRIA_NVEQUAD2D
              
              ! Get global number of second vertex
              ivt = rhadapt%p_IverticesAtElement(2, jel)

              ! Increase number of locked vertices if required
              if (rhadapt%p_IvertexAge(ivt) .le. 0) nlocked = nlocked+1

              ! Proceed to adjacent element along second edge
              jel = rhadapt%p_IneighboursAtElement(2, jel)
            end do

            ! Check if three or more vertices are locked, then lock all vertices
            if (nlocked .ge. 3) then
              
              ! Get global number of "inner" vertex
              ivt = rhadapt%p_IverticesAtElement(3, iel)
              
              if (rhadapt%p_IvertexAge(ivt) .gt. 0) then
                ! Lock inner vertex if required
                rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

                ! We modified some vertices in this iteration
                bisModified = .true.
              end if
              
              ! Lock all midpoint vertices if required
              jel = iel
              do ive = 1, TRIA_NVEQUAD2D

                ! Get global number of second vertex
                ivt = rhadapt%p_IverticesAtElement(2, jel)

                if (rhadapt%p_IvertexAge(ivt) .gt. 0) then
                  ! Lock second vertex if required
                  rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

                  ! We modified some vertices in this iteration
                  bisModified = .true.
                end if

                ! Proceed to adjacent element along second edge
                jel = rhadapt%p_IneighboursAtElement(2, jel)
              end do
              
            end if   ! nlocked >= 3
            
          end if   ! inner vertex is locked
          
          
        case(STATE_TRIA_REDINNER)
          ! Element IEL is inner red triangle of a 1-tria : 4-tria refinement.
          
          ! Determine number of locked vertices of the inner triangle.
          nlocked = 0
          do ive = 1, TRIA_NVETRI2D
            
            ! Get global number of vertex
            ivt = IverticesAtElement(ive)
            if (rhadapt%p_IvertexAge(ivt) .le. 0) nlocked = nlocked+1
          end do
          
          ! Check if two vertices are locked, then lock all vertices
          if (nlocked .eq. 2) then
            do ive = 1, TRIA_NVETRI2D
              ivt = IverticesAtElement(ive)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end do
            
            ! We definitively modified some vertex in this iteration
            bisModified = .true.           
          end if


        case DEFAULT

          ! Get number of vertices per element
          nve = hadapt_getNVE(rhadapt, iel)
          
          phase2_edge: do ive = 1, nve
            
            ! Get numbers of element(s) adjacent to the current edge
            jel    = rhadapt%p_IneighboursAtElement(ive, iel)
            jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)
            
            ! Check if neighboring element has been subdivided
            if (jel .ne. jelmid) then
              
              ! Find element IEL in adjacency list of element JEL
              phase2_edge_midpoint: do jve = 1, hadapt_getNVE(rhadapt, jel)
                if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) then

                  ! Get number of midpoint vertex
                  jvt = rhadapt%p_IverticesAtElement(jve, jel)
            
                  ! Check if midpoint vertex for the current edge is "locked", 
                  ! then lock all corner vertices of element IEL if required
                  if (rhadapt%p_IvertexAge(jvt) .le. 0) then
                    phase2_lock_all: do kve = 1, nve
                      ivt = rhadapt%p_IverticesAtElement(kve, iel)
                      if (rhadapt%p_IvertexAge(ivt) .gt. 0) then
                        rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

                        ! We definitively modified some vertex in this iteration
                        bisModified = .true.  
                      end if
                    end do phase2_lock_all

                    exit phase2_edge
                  end if

                  exit phase2_edge_midpoint
                end if
              end do phase2_edge_midpoint
              
            end if
          end do phase2_edge

        end select
      end do phase2_elem
    end do phase2


    ! Phase 3: Determine re-coarsening rule based on "free" vertices.
    !
    ! In the third phase, all elements are considered and the 
    ! corresponding re-coarsening rule is adopted based on the
    ! number and type of free vertices. Note that elements which
    ! have been marked for refinement may be modified.

    phase3: do iel = 1, rhadapt%NEL
      
      ! Check if the current element is marked for red refinement.
      select case(p_Imarker(iel))
        
      case(MARK_REF_QUAD4QUAD,&
           MARK_REF_TRIA4TRIA)

        ! The current element is marked for red refinement, and hence,
        ! it cannot be removed by the re-coarsening algorithm.


      case(MARK_REF_TRIA2TRIA_1,&
           MARK_REF_TRIA2TRIA_2,&
           MARK_REF_TRIA2TRIA_3)

        ! Get local edge number [2,4,8] -> [1,2,3]
        ive = ishft(p_Imarker(iel), -2)+1

        ! The current element is a triangle which is marker
        ! for green refinement along one single edge.
        jel    = rhadapt%p_IneighboursAtElement(ive, iel)
        jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)

        if (jel .ne. jelmid) then
          ! Find element IEL in adjacency list of element JEL
          do jve = 1, hadapt_getNVE(rhadapt, jel)
            if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) then
              jvt = rhadapt%p_IverticesAtElement(jve, jel)
              if (rhadapt%p_IvertexAge(jvt) .gt. 0) then
                p_Imarker(iel) = ibclr(p_Imarker(iel), ive)
              end if
              exit
            end if
          end do
        end if


      case(MARK_REF_QUAD2QUAD_13,&
           MARK_REF_QUAD2QUAD_24)

        ! Get local edge number [11,21] -> [1,2]
        nve = ishft(p_Imarker(iel), -3)

        ! The current element is a quadrilateral which is marker
        ! for green refinement along two opposive edges.
        do ive = nve, nve+2, 2
          
          jel    = rhadapt%p_IneighboursAtElement(ive, iel)
          jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)
          
          if (jel .ne. jelmid) then
            ! Find element IEL in adjacency list of element JEL
            do jve = 1, hadapt_getNVE(rhadapt, jel)
              if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) then
                jvt = rhadapt%p_IverticesAtElement(jve, jel)
                if (rhadapt%p_IvertexAge(jvt) .gt. 0) then
                  p_Imarker(iel) = ibclr(p_Imarker(iel), ive)
                end if
                exit
              end if
            end do
          end if
        end do
        
        
      case(MARK_REF_QUAD3TRIA_1,&
           MARK_REF_QUAD3TRIA_2,&
           MARK_REF_QUAD3TRIA_3,&
           MARK_REF_QUAD3TRIA_4)
        
        ! Get local edge number [3,5,9,17] -> [1,2,3,4]
        ive = min(4, ishft(p_Imarker(iel), -2)+1)

        ! The current element is a quadrilateral which is 
        ! marker for green refinement along one single edge.
        jel    = rhadapt%p_IneighboursAtElement(ive, iel)
        jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)

        if (jel .ne. jelmid) then
          ! Find element IEL in adjacency list of element JEL
          do jve = 1, hadapt_getNVE(rhadapt, jel)
            if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) then
              jvt = rhadapt%p_IverticesAtElement(jve, jel)
              if (rhadapt%p_IvertexAge(jvt) .gt. 0) then
                p_Imarker(iel) = ibclr(p_Imarker(iel), ive)
              end if
              exit
            end if
          end do
        end if

        
      case(MARK_REF_QUAD4TRIA_12,&
           MARK_REF_QUAD4TRIA_23,&
           MARK_REF_QUAD4TRIA_34,&
           MARK_REF_QUAD4TRIA_14)

        if (p_Imarker(iel) .eq. MARK_REF_QUAD4TRIA_12) then
          ive = 1
        elseif(p_Imarker(iel) .eq. MARK_REF_QUAD4TRIA_23) then
          ive = 2
        elseif(p_Imarker(iel) .eq. MARK_REF_QUAD4TRIA_34) then
          ive = 3
        else
          ive = 4
        end if

        ! The current element is a quadrilateral which is marker
        ! for green refinement along two connected edges.
          
        jel    = rhadapt%p_IneighboursAtElement(ive, iel)
        jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)
        
        if (jel .ne. jelmid) then
          ! Find element IEL in adjacency list of element JEL
          do jve = 1, hadapt_getNVE(rhadapt, jel)
            if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) then
              jvt = rhadapt%p_IverticesAtElement(jve, jel)
              if (rhadapt%p_IvertexAge(jvt) .gt. 0) then
                p_Imarker(iel) = ibclr(p_Imarker(iel), ive)
              end if
              exit
            end if
          end do
        end if

        ive = mod(ive, 4)+1

        jel    = rhadapt%p_IneighboursAtElement(ive, iel)
        jelmid = rhadapt%p_ImidneighboursAtElement(ive, iel)
        
        if (jel .ne. jelmid) then
          ! Find element IEL in adjacency list of element JEL
          do jve = 1, hadapt_getNVE(rhadapt, jel)
            if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) then
              jvt = rhadapt%p_IverticesAtElement(jve, jel)
              if (rhadapt%p_IvertexAge(jvt) .gt. 0) then
                p_Imarker(iel) = ibclr(p_Imarker(iel), ive)
              end if
              exit
            end if
          end do
        end if


      case DEFAULT
        
        ! The current element is not marked for red refinement, and hence,
        ! it is a potential candidate for the re-coarsening algorithm.
        
        ! Get number of vertices per element
        nve = hadapt_getNVE(rhadapt, iel)
        
        ! Get state of current element
        select case(nve)
        case(TRIA_NVETRI2D)
          do ive = 1, TRIA_NVETRI2D
            ivt                     = rhadapt%p_IverticesAtElement(ive, iel)
            IverticesAtElement(ive) = ivt
            IvertexAge(ive)         = rhadapt%p_IvertexAge(ivt)
          end do
          istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
          
          
        case(TRIA_NVEQUAD2D)
          do ive = 1, TRIA_NVEQUAD2D
            ivt                     = rhadapt%p_IverticesAtElement(ive, iel)
            IverticesAtElement(ive) = ivt
            IvertexAge(ive)         = rhadapt%p_IvertexAge(IverticesAtElement(ive))
          end do
          istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))
          
          
        case DEFAULT
          call output_line('Invalid number of vertices per element!',&
              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
          call sys_halt()
        end select
        
        
        ! What state are we?
        select case(istate)
        case(STATE_TRIA_ROOT,&
             STATE_QUAD_ROOT,&
             STATE_TRIA_OUTERINNER,&
             STATE_TRIA_GREENINNER,&
             STATE_TRIA_GREENOUTER_LEFT)
          ! Dummy states which are required to prevent
          ! immediate stop in the default branch.
          
          
        case(STATE_TRIA_REDINNER)
          ! If all vertices of the element are free, then the inner red 
          ! triangle can be combined with its three neighboring red triangles.
          ! If one vertex of the inner triangle is locked, then the inner
          ! red tiangle together with its three neighboring elements can
          ! be converted into two green triangles.
          
          ! Convert position of locked vertices into integer
          nlocked = 0
          do ive = 1, TRIA_NVETRI2D
            ivt = IverticesAtElement(ive)
            if (rhadapt%p_IvertexAge(ivt) .le. 0) nlocked = ibset(nlocked, ive)
          end do
          
          ! How many vertices are locked?
          select case(nlocked)
          case(0)
            ! Mark element IEL for re-coarsening into macro element
            p_Imarker(iel) = MARK_CRS_4TRIA1TRIA
            
          case(2)
            ! Mark element IEL for re-coarsening into two triangles
            p_Imarker(iel) = MARK_CRS_4TRIA2TRIA_1
            
          case(4)
            ! Mark element IEL for re-coarsening into two triangles
            p_Imarker(iel) = MARK_CRS_4TRIA2TRIA_2
            
          case(8)
            ! Mark element IEL for re-coarsening into two triangles
            p_Imarker(iel) = MARK_CRS_4TRIA2TRIA_3
            
          case DEFAULT
            cycle phase3
          end select
          
          ! Mark all adjacent elements 'as is'
          do ive = 1, TRIA_NVETRI2D
            jel = rhadapt%p_IneighboursAtElement(ive, iel)
            p_Imarker(jel) = MARK_ASIS_TRIA
          end do
          
          
        case(STATE_QUAD_RED4)
          ! This is one of four quadrilaterals which result from a 1-quad : 4-quad
          ! refinement. Here, the situation is slightly more difficult because 
          ! multiple rotationally-symmetric situations have to be considered. The
          ! four elements forming the macro element can be collected by visiting the
          ! neighboring element along the second edge starting at element IEL.
          
          ! Check if the "inner" vertex is locked, then no re-coarsening is possible.
          ivt = rhadapt%p_IverticesAtElement(3, iel)
          if (rhadapt%p_IvertexAge(ivt) .le. 0) cycle phase3
          
          ! Otherwise, determine the number of locked midpoints. This is done
          ! by visiting all four elements and checking the second vertex individually.
          ! Note that we do not only count the number of locked vertices but also
          ! remember its position by setting or clearing the corresponding bit of
          ! the integer nlocked. In the same loop, we determine the numbers of the
          ! four elements of the macro element. Of course, the first is element IEL
          ImacroElement(1) = iel
          
          ! Get global number of second vertex in element IEL
          ivt = rhadapt%p_IverticesAtElement(2, iel)
          nlocked = merge(2, 0, rhadapt%p_IvertexAge(ivt) .le. 0)
          do ive = 2, TRIA_NVEQUAD2D
            
            ! Get neighbouring element and store it
            jel                = rhadapt%p_IneighboursAtElement(2, ImacroElement(ive-1))
            ImacroElement(ive) = jel
            
            ! Get global number of second vertex in element JEL
            jvt = rhadapt%p_IverticesAtElement(2, jel)
            if (rhadapt%p_IvertexAge(jvt) .le. 0) nlocked = ibset(nlocked, ive)
          end do
          
          ! How many vertices are locked?
          select case(nlocked)
          case(0)
            ! Mark element IEL for re-coarsening into macro 
            ! element and  keep all remaining elements 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_CRS_4QUAD1QUAD
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(2)
            ! There is one vertex locked which is the second vertex
            ! of the first element. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_CRS_4QUAD3TRIA
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(4)
            ! There is one vertex locked which is the second vertex
            ! of the second element. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(2)) = MARK_CRS_4QUAD3TRIA
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(8)
            ! There is one vertex locked which is the second vertex
            ! of the third element. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_CRS_4QUAD3TRIA
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(16)
            ! There is one vertex locked which is the second vertex
            ! of the fourth element. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_CRS_4QUAD3TRIA
            
            
          case(10)
            ! There are two vertices locked which are the second vertices
            ! of the first and third elements. Mark the  first element
            ! for recoarsening. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_CRS_4QUAD2QUAD
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(20)
            ! There are two vertices locked which are the second vertices
            ! of the second and fourth elements. Mark the second element
            ! for recoarsening. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(2)) = MARK_CRS_4QUAD2QUAD
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(18)
            ! There are two vertices locked which are the second and 
            ! fourth vertices of the first elements. Mark the firth element
            ! for recoarsening. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_CRS_4QUAD4TRIA
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(6)
            ! There are two vertices locked which are the second and
            ! fourth vertices of the second elements. Mark the second element
            ! for recoarsening. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(2)) = MARK_CRS_4QUAD4TRIA
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(12)
            ! There are two vertices locked which are the second and
            ! fourth vertices of the third elements. Mark the third element
            ! for recoarsening. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_CRS_4QUAD4TRIA
            p_Imarker(ImacroElement(4)) = MARK_ASIS_QUAD
            
            
          case(24)
            ! There are two vertices locked which are the second and 
            ! fourth vertices of the fourth elements. Mark the fourth element
            ! for recoarsening. All other elements are kept 'as is'.
            p_Imarker(ImacroElement(1)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(2)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(3)) = MARK_ASIS_QUAD
            p_Imarker(ImacroElement(4)) = MARK_CRS_4QUAD4TRIA
            
            
          case DEFAULT
            call output_line('Invalid number of locked vertices!',&
                OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
            call sys_halt()
          end select
          
          
        case(STATE_TRIA_GREENOUTER_RIGHT)
          ! We have to considered several situations depending on the 
          ! state of the adjacent element that shares the second edge.
          jel = rhadapt%p_IneighboursAtElement(2, iel)
          
          do ive = 1, TRIA_NVETRI2D
            jvt             = rhadapt%p_IverticesAtElement(ive, jel)
            IvertexAge(ive) = rhadapt%p_IvertexAge(jvt)
          end do
          jstate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
          
          ! What is the state of the adjacent element?
          select case(jstate)
          case(STATE_TRIA_GREENOUTER_LEFT)
            ! If all vertices of element JEL are locked, then it is kept 'as is'.
            ! Since a left green triangle shares two vertices with its macro 
            ! element, it suffices to check the state of the second vertex.
            ivt = rhadapt%p_IverticesAtElement(2, jel)
            if (rhadapt%p_IvertexAge(ivt) .gt. 0) then
              
              ! Mark element for re-coarsening.
              p_Imarker(jel) = MARK_CRS_2TRIA1TRIA
              
              ! Keep its neighbour, i.e. element IEL, 'as is'.
              p_Imarker(iel) = MARK_ASIS_TRIA
            end if
            
            
          case(STATE_TRIA_GREENINNER)
            ! If all vertices of element JEL are locked, then it is kept 'as is'.
            ! Since an inner green triangle shares two vertices with its macro
            ! element, it suffices to check the state of the first vertex.
            ivt = rhadapt%p_IverticesAtElement(1, jel)
            if (rhadapt%p_IvertexAge(ivt) .gt. 0) then
              
              ! Mark element for re-coarsening.
              p_Imarker(jel) = MARK_CRS_3TRIA1QUAD
              
              ! Keep its neighbour along first edge 'as is'.
              kel = rhadapt%p_IneighboursAtElement(1, jel)
              p_Imarker(kel) = MARK_ASIS_TRIA
              
              ! Keep its neighbour along third edge 'as is'.
              kel = rhadapt%p_IneighboursAtElement(3, jel)
              p_Imarker(kel) = MARK_ASIS_TRIA
            end if
            
            
          case(STATE_TRIA_OUTERINNER)
            ! If all vertices of element JEL are locked, then it is kept 'as is'.
            ! Since an inner-outer green triangle shares two vertices with its 
            ! macro element, it suffices to check the state of the first vertex.
            ivt = rhadapt%p_IverticesAtElement(2, jel)
            jvt = rhadapt%p_IverticesAtElement(3, jel)
            
            if (rhadapt%p_IvertexAge(ivt) .gt. 0) then
              if (rhadapt%p_IvertexAge(jvt) .gt. 0) then
                
                ! Mark element for re-coarsening.
                p_Imarker(jel) = MARK_CRS_4TRIA1QUAD
                
                ! Keep its neighbour along first edge 'as is'
                kel = rhadapt%p_IneighboursAtElement(1, jel)
                p_Imarker(kel) = MARK_ASIS_TRIA
                
                ! Keep its neighbour along second edge 'as is'
                kel = rhadapt%p_IneighboursAtElement(2, jel)
                p_Imarker(kel) = MARK_ASIS_TRIA
                
                ! Keep its neighbour, i.e. element IEL, along third edge 'as is'
                p_Imarker(iel) = MARK_ASIS_TRIA
                
              else   ! third vertex is locked
                
                ! Mark element for re-coarsening, whereby the green
                ! outer triangle to the left is preserved.
                p_Imarker(jel) = MARK_CRS_4TRIA3TRIA_LEFT ! RIGHT
                
                ! Keep its neighbour along first edge 'as is'
                kel = rhadapt%p_IneighboursAtElement(1, jel)
                p_Imarker(kel) = MARK_ASIS_TRIA
                
                ! Keep its neighbour along second edge 'as is'
                kel = rhadapt%p_IneighboursAtElement(2, jel)
                p_Imarker(kel) = MARK_ASIS_TRIA
                
                ! Keep its neighbour, i.e. element IEL, along third edge 'as is'
                p_Imarker(iel) = MARK_ASIS_TRIA
                
              end if
              
            else    ! second vertex is locked
              
              if (rhadapt%p_IvertexAge(jvt) .gt. 0) then
                
                ! Mark element for re-coarsening, whereby the green 
                ! outer triangle to the right is preserved.
                p_Imarker(jel) = MARK_CRS_4TRIA3TRIA_RIGHT ! LEFT
                
                ! Keep its neighbour along first edge 'as is'
                kel = rhadapt%p_IneighboursAtElement(1, jel)
                p_Imarker(kel) = MARK_ASIS_TRIA
                
                ! Keep its neighbour along second edge 'as is'
                kel = rhadapt%p_IneighboursAtElement(2, jel)
                p_Imarker(kel) = MARK_ASIS_TRIA
                
                ! Keep its neighbour, i.e. element IEL, along third edge 'as is'
                p_Imarker(iel)=MARK_ASIS_TRIA
                
              else   ! third vertex is locked
                
                ! Keep all elements in patch 'as is'.
                p_Imarker(iel) = MARK_ASIS_TRIA
                p_Imarker(jel) = MARK_ASIS_TRIA
                
                kel = rhadapt%p_IneighboursAtElement(1, jel)
                p_Imarker(kel) = MARK_ASIS
                
                kel = rhadapt%p_IneighboursAtElement(2, jel)
                p_Imarker(kel) = MARK_ASIS
                
              end if
              
            end if
            
            
          case DEFAULT
            call output_line('Invalid element state of adjacent element!',&
                OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
            call sys_halt()
          end select
          

        case (STATE_QUAD_HALF1,STATE_QUAD_HALF2)
          ! This is one of two quadrilaterals which result from a
          ! 1-quad : 2-quad refinement. If both common vertices are
          ! locked, then the green quadrilaterals are kept 'as is'. If
          ! only one common vertex is locked, the two quadrilaterals
          ! can be coarsened into three triangles reducing the number
          ! of vertices by one. If both common vertices can be
          ! deleted, then both quadrilaterals are removed and the
          ! original macro element is restored.

          ! Get the number of the neighboring green element
          jel = rhadapt%p_IneighboursAtElement(2,iel)
          
          ! Check if the first common vertex of is locked
          if (rhadapt%p_IvertexAge(IverticesAtElement(2)) .le. 0) then

            ! Check if the second common vertex is also locked
            if (rhadapt%p_IvertexAge(IverticesAtElement(3)) .le. 0) then
              ! Keep both elements 'as is'
              p_Imarker(iel)=MARK_ASIS
              p_Imarker(jel)=MARK_ASIS
            else
              ! Mark element IEL for re-coarsening into three triangles, 
              ! whereby the second vertex of element IEL is preserved
              p_Imarker(iel)=MARK_CRS_2QUAD3TRIA
              p_Imarker(jel)=MARK_ASIS
            end if

          else

            ! Check if the second common vertex is locked
            if (rhadapt%p_IvertexAge(IverticesAtElement(3)) .le. 0) then
              ! Mark element JEL for re-coarsening into three triangles,
              ! whereby the second vertex of element JEL is preserved
              p_Imarker(iel)=MARK_ASIS
              p_Imarker(jel)=MARK_CRS_2QUAD3TRIA
            else
              ! Mark element IEL for re-coarsening into the macro element
              p_Imarker(iel)=MARK_CRS_2QUAD1QUAD
              p_Imarker(jel)=MARK_ASIS
            end if
          end if
          
          
        case DEFAULT
          call output_line('Invalid element state!',&
              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_coarsening2D')
          call sys_halt()
        end select

      end select
    end do phase3
   
    ! Set specifier to "marked for coarsening"
    rhadapt%iSpec = ior(rhadapt%iSpec, HADAPT_MARKEDCOARSEN)

  contains

    ! Here, the real working routines follow.

    !**************************************************************
    ! For a given element IEL, check if all corners vertices need
    ! to be locked. In particular, this is the case if the element
    ! is a red one or belongs to the initial triangulation and, in
    ! addition, the element marker reuqires to keep this element.

    function lockElement(iel) result (blockElement)

      integer(PREC_ELEMENTIDX), intent(IN) :: iel
      integer                              :: istate
      logical                              :: blockElement
      
      ! Check if element marker is available for this element
      blockElement = (iel .le. size(p_Dindicator, 1))
      
      if (blockElement) then
        
        ! Get element state
        istate = redgreen_getState2D(rhadapt, iel)
        
        select case(istate)

        case (STATE_TRIA_ROOT,&
              STATE_TRIA_REDINNER,&
              STATE_QUAD_ROOT,&
              STATE_QUAD_RED4)

          ! Element is a red element and/or belongs to the initial triangulation
          blockElement = (p_Dindicator(iel) .ge. rhadapt%dcoarseningTolerance)

        case DEFAULT
          blockElement = .false.
          
        end select
      end if
    end function lockElement

  end subroutine redgreen_mark_coarsening2D

!!$  ! ***************************************************************************
!!$
!!$!<subroutine>
!!$  
!!$  SUBROUTINE redgreen_mark_refinement2D(rhadapt, rcollection, fcb_hadaptCallback)
!!$
!!$!<description>
!!$    ! This subroutine initializes tha adaptive data structure for red-green refinement.
!!$    ! Starting from the marker array the neighbors of elements marked for refinement 
!!$    ! are also marked for refinement until the resulting mesh satiesfies global
!!$    ! conformity. This subroutine is implemented in an iterative fashion rather than
!!$    ! making use of recursive subroutine calls. 
!!$!</description>
!!$
!!$!<input>
!!$    ! Callback function
!!$    include 'intf_hadaptcallback.inc'
!!$    OPTIONAL :: fcb_hadaptCallback
!!$!</input>
!!$
!!$!<inputoutput>
!!$    ! adaptive data structure
!!$    TYPE(t_hadapt), INTENT(INOUT)               :: rhadapt
!!$
!!$    ! OPTIONAL: Collection
!!$    TYPE(t_collection), INTENT(INOUT), OPTIONAL :: rcollection
!!$!</inputoutput>
!!$!</subroutine>
!!$
!!$    ! local variables
!!$    INTEGER, DIMENSION(:), POINTER :: p_Imarker,p_Imodified
!!$    INTEGER(PREC_VERTEXIDX), DIMENSION(TRIA_MAXNVE2D) :: IverticesAtElement
!!$    INTEGER(PREC_ELEMENTIDX), DIMENSION(1) :: Ielements
!!$    INTEGER(PREC_VERTEXIDX), DIMENSION(1)  :: Ivertices
!!$    INTEGER(PREC_VERTEXIDX)  :: i,nvt
!!$    INTEGER(PREC_ELEMENTIDX) :: nel,iel,jel,kel,lel,iel1,iel2
!!$    INTEGER :: ive,jve,nve,mve,istate,jstate,kstate
!!$    INTEGER :: h_Imodified,imodifier
!!$    LOGICAL :: isConform
!!$    INTEGER, DIMENSION(TRIA_MAXNVE) :: IvertexAge
!!$    
!!$    !---------------------------------------------------------------------------
!!$    ! At the moment, only those cells are marked for regular refinementfor which 
!!$    ! the cell indicator does not satisfy some prescribed treshold. In order to 
!!$    ! globally restore the conformity of the final grid, repeatedly loop over all
!!$    ! elements and check if each of the three or four adjacent edges satisfies 
!!$    ! conformity. Some care must be taken for green elements. In order to retain
!!$    ! the shape quality of the elements, green elements need to be converted into
!!$    ! red ones before further refinement is allowed.
!!$    !--------------------------------------------------------------------------
!!$
!!$    ! In the course of element marking, some green elements may have to be converted
!!$    ! into regularly refined ones. In the worst case (Quad2Quad-refinement) each
!!$    ! green element gives rise to 1.5 vertices and 2 new elements.
!!$    ! Hence, the nodal arrays p_IvertexAge and p_InodalProperty as well as the
!!$    ! element arrays p_IverticesAtElement, p_IneighboursAtElement,
!!$    ! p_ImidneighboursAtElement and p_Imarker are enlarged precautionary. 
!!$    IF (rhadapt%nGreenElements > 0) THEN
!!$
!!$      ! Predict new dimensions for the worst case
!!$      nvt = CEILING(rhadapt%NVT0+1.5*rhadapt%nGreenElements)
!!$      nel = rhadapt%NEL0+2*rhadapt%nGreenElements
!!$
!!$      ! Adjust nodal/elemental arrays
!!$      CALL storage_realloc('redgreen_mark_refinement2D', nvt,&
!!$                           rhadapt%h_IvertexAge, ST_NEWBLOCK_ZERO, .TRUE.)
!!$      CALL storage_realloc('redgreen_mark_refinement2D', nvt,&
!!$                           rhadapt%h_InodalProperty, ST_NEWBLOCK_ZERO, .TRUE.)
!!$      CALL storage_realloc('redgreen_mark_refinement2D', nel,&
!!$                           rhadapt%h_Imarker, ST_NEWBLOCK_ZERO, .TRUE.)
!!$      CALL storage_realloc('redgreen_mark_refinement2D', nel,&
!!$                           rhadapt%h_IverticesAtElement, ST_NEWBLOCK_NOINIT, .TRUE.)
!!$      CALL storage_realloc('redgreen_mark_refinement2D', nel,&
!!$                           rhadapt%h_IneighboursAtElement, ST_NEWBLOCK_NOINIT, .TRUE.)
!!$      CALL storage_realloc('redgreen_mark_refinement2D', nel,&
!!$                           rhadapt%h_ImidneighboursAtElement, ST_NEWBLOCK_NOINIT, .TRUE.)
!!$      
!!$      ! Reset pointers
!!$      CALL storage_getbase_int(rhadapt%h_IvertexAge,&
!!$                               rhadapt%p_IvertexAge)
!!$      CALL storage_getbase_int(rhadapt%h_InodalProperty,&
!!$                               rhadapt%p_InodalProperty)
!!$      CALL storage_getbase_int2D(rhadapt%h_IverticesAtElement,&
!!$                                 rhadapt%p_IverticesAtElement)
!!$      CALL storage_getbase_int2D(rhadapt%h_IneighboursAtElement,&
!!$                                 rhadapt%p_IneighboursAtElement)
!!$      CALL storage_getbase_int2D(rhadapt%h_ImidneighboursAtElement,&
!!$                                 rhadapt%p_ImidneighboursAtElement)
!!$
!!$      ! Adjust dimension of solution vector
!!$      IF (PRESENT(fcb_hadaptCallback) .AND. PRESENT(rcollection)) THEN
!!$        Ivertices = (/nvt/)
!!$        Ielements = (/0/)
!!$        CALL fcb_hadaptCallback(rcollection, HADAPT_OPR_ADJUSTVERTEXDIM,&
!!$                                Ivertices, Ielements)
!!$      END IF
!!$
!!$      ! Create new array for modifier
!!$      CALL storage_new ('redgreen_mark_refinement2D', 'p_Imodified', nel,&
!!$                        ST_INT, h_Imodified, ST_NEWBLOCK_ZERO)
!!$      CALL storage_getbase_int(h_Imodified, p_Imodified)
!!$    
!!$    ELSE
!!$      
!!$      ! No green elements have to be considered, hence use NEL0      
!!$      CALL storage_new('redgreen_mark_refinement2D', 'p_Imodified', rhadapt%NEL0,&
!!$                        ST_INT, h_Imodified, ST_NEWBLOCK_ZERO)
!!$      CALL storage_getbase_int(h_Imodified, p_Imodified)
!!$
!!$    END IF
!!$
!!$    ! The task of the two arrays p_Imarker and p_Imodified are as follows:
!!$    ! p_Imarker stores for each element its individual state from which the task of
!!$    ! refinement can be uniquely determined (see above; data type t_hadapt).
!!$    ! If the state of one element is modified, then potentionally all neighboring
!!$    ! elements have to be checked, if conformity is violated. In order to prevent this
!!$    ! (expensive) check to be performed for all elements again and again, only those
!!$    ! elements are investigated for which the modifier p_Imodified is active, i.e.
!!$    ! p_Imodified(iel) .EQ. imodifier. In order to pre-select elements for investigation
!!$    ! in the next loop, p_Imodified(iel) is set to -imodifier and the modifier is reversed
!!$    ! after each iteration. This complicated step is necessary for the following reason:
!!$    ! If one element with mediate number initially is not marked but gets marked for
!!$    ! subdivision at one edge, then it will be considered in the same iteration and
!!$    ! green elements will eventually converted. However, it is possible that the same
!!$    ! element would be marked for subdivision at another edge due to an adjacent element
!!$    ! with large number. Hence, it is advisable to first process all elements which are
!!$    ! activated and pre-select their neighbors for the next iteration.
!!$
!!$    ! Ok, so let's start. Initially, indicate all elements as modified which are marked
!!$    ! for refinement due to accuracy reasons.
!!$    imodifier = 1
!!$    CALL storage_getbase_int(rhadapt%h_Imarker, p_Imarker)
!!$    DO iel = 1, rhadapt%NEL0
!!$      IF (p_Imarker(iel) .NE. MARK_ASIS) p_Imodified(iel) = imodifier
!!$    END DO
!!$
!!$    isConform = .FALSE.
!!$    conformity: DO
!!$
!!$      ! If conformity is guaranteed for all cells, then exit
!!$      IF (isConform) EXIT conformity
!!$      isConform = .TRUE.
!!$      
!!$      ! Otherwise, loop over all elements present in the initial grid (IEL <= NEL0)
!!$      ! which are modified and mark their neighbors for further refinement 
!!$      ! if conformity is violated for some edge     
!!$      DO iel = 1, rhadapt%NEL0
!!$        
!!$        ! Skip those element which have not been modified
!!$        IF (p_Imodified(iel) .NE. imodifier) CYCLE
!!$
!!$        ! Get number of vertices per element
!!$        nve = hadapt_getNVE(rhadapt,iel)
!!$        
!!$        ! Get local data for element iel
!!$        IverticesAtElement(1:nve) = rhadapt%p_IverticesAtElement(1:nve, iel)
!!$      
!!$        ! Are we triangular or quadrilateral element?
!!$        SELECT CASE(nve)
!!$        CASE(TRIA_NVETRI2D)
!!$          ! Triangular element
!!$          p_Imarker(iel) = ibclr(p_Imarker(iel), 0)
!!$          IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
!!$                                        IverticesAtElement(1:TRIA_NVETRI2D))
!!$          istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
!!$
!!$        CASE(TRIA_NVEQUAD2D)
!!$          ! Quadrilateral element
!!$          p_Imarker(iel) = ibset(p_Imarker(iel), 0)
!!$          IvertexAge(1:TRIA_NVEQUAD2D) = rhadapt%p_IvertexAge(&
!!$                                         IverticesAtElement(1:TRIA_NVEQUAD2D))
!!$          istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))
!!$
!!$        CASE DEFAULT
!!$          CALL output_line('Invalid number of vertices per element!',&
!!$              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
!!$          CALL sys_halt()
!!$        END SELECT
!!$
!!$        !-----------------------------------------------------------------------
!!$        ! Check if the state of the current element IEL allows direct
!!$        ! refinement or if the elements needs to be "converted" first
!!$        !-----------------------------------------------------------------------
!!$        SELECT CASE(istate)
!!$        CASE (STATE_TRIA_ROOT,&
!!$              STATE_QUAD_ROOT,&
!!$              STATE_TRIA_REDINNER,&
!!$              STATE_QUAD_RED1,&
!!$              STATE_QUAD_RED2,&
!!$              STATE_QUAD_RED3,&
!!$              STATE_QUAD_RED4)
!!$          ! States which can be directly accepted
!!$
!!$        CASE(STATE_TRIA_OUTERINNER1,&
!!$             STATE_TRIA_OUTERINNER2)
!!$          ! Theoretically, these states may occure and have to be treated 
!!$          ! like CASE(4), see below. Due to the fact, that these states can
!!$          ! only be generated by means of local red-green refinement and are
!!$          ! not present in the initial grid we make use of additional know-
!!$          ! ledge: Triangles which have too youngest vertices can either
!!$          ! be outer red elements resulting from a Tria4Tria refinement 
!!$          ! or one of the opposite triangles resulting from Quad4Tria refinement.
!!$          ! In all cases, the edge which connects the two nodes is opposite
!!$          ! to the first local vertex. Hence, work must only be done for CASE(4)
!!$          CALL output_line('These states must not occur!',&
!!$              OU_CLASS_ERROR, OU_MODE_STD, 'redgreen_mark_refinement2D')
!!$          CALL sys_halt()
!!$          
!!$        CASE(STATE_TRIA_OUTERINNER)
!!$          ! The triangle can either be an outer red element resulting from a Tria4Tria 
!!$          ! refinement or one of the two opposite triangles resulting from Quad4Tria 
!!$          ! refinement. This can be easily checked. If the opposite element is not 
!!$          ! an inner red triangle (14), then the element IEL and its opposite neighbor 
!!$          ! make up the inner "diamond" resulting from a Quad4Tria refinement. 
!!$          jel = rhadapt%p_IneighboursAtElement(2, iel)
!!$       
!!$          ! First, we need to check a special case. If the second edge of element IEL
!!$          ! has two different neighbors, then the original neighbor along this edge
!!$          ! was a green triangle that has been converted into an (outer) red one. In
!!$          ! this case, the current element IEL does not need further modifications.
!!$          IF (jel .NE. rhadapt%p_ImidneighboursAtElement(2, iel)) GOTO 100
!!$          
!!$          ! Otherwise, determine the state of the edge neighbor JEL
!!$          jstate = redgreen_getState2D(rhadapt, jel)
!!$          
!!$          IF (jstate .EQ. STATE_TRIA_OUTERINNER) THEN
!!$            ! We know that element IEL and JEL make up the inner "diamond" resulting
!!$            ! from a Quad4Tria refinement. It remains to find the two green triangle
!!$            ! which make up the outer part of the macro element. Since we do not know
!!$            ! if they are adjacent to element IEL or JEL we have to perform additional
!!$            ! checks: The element along the first edge of the inner triangle must
!!$            ! have state STATE_TRIA_GREENOUTER_LEFT.
!!$            kel = rhadapt%p_IneighboursAtElement(1, iel)
!!$            kstate = redgreen_getState2D(rhadapt, kel)
!!$
!!$            IF (kstate .NE. STATE_TRIA_GREENOUTER_LEFT .OR.&
!!$                rhadapt%p_IneighboursAtElement(2, kel) .NE. iel) THEN
!!$              ! At this stage we can be sure that element IEL is not (!) the inner
!!$              ! triangle, hence, it must be element JEL
!!$              
!!$              ! To begin with, we need to find the two missing triangles KEL and LEL
!!$              ! which make up the original quadrilateral
!!$              kel = rhadapt%p_IneighboursAtElement(1, jel)
!!$              lel = rhadapt%p_IneighboursAtElement(3, jel)
!!$
!!$              ! Mark the edge of the element adjacent to KEL for subdivision
!!$              iel1 = rhadapt%p_IneighboursAtElement(3, kel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(3, kel)
!!$              IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(kel, iel1)
!!$
!!$              ! Mark the edge of the element adjacent to LEL for subdivision
!!$              iel1 = rhadapt%p_IneighboursAtElement(1, lel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
!!$              IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(lel, iel1)
!!$
!!$              ! Now, we can physically convert the four triangles into four quadrilaterals
!!$              CALL convert_Quad4Tria(rhadapt, kel, iel, lel, jel,&
!!$                                     rcollection, fcb_hadaptCallback)
!!$              isConform = .FALSE.
!!$
!!$              ! All four elements have to be converted from triangles to quadrilaterals.
!!$              p_Imarker(jel) = ibset(0, 0)
!!$
!!$              ! The second and third edge of KEL must be unmarked. Moreover, the first edge is
!!$              ! marked for refinement if and only if it is also marked from the adjacent element.
!!$              iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$              IF (ismarked_edge(iel1, iel2, kel)) THEN
!!$                p_Imarker(kel) = ibset(ibset(0, 1), 0)
!!$              ELSE
!!$                p_Imarker(kel) = ibset(0, 0)
!!$              END IF
!!$
!!$              ! The second and third edge of IEL must be unmarked.
!!$              p_Imarker(iel) = ibset(0, 0)
!!$
!!$              ! The fourth edge is only marked if it is also marked from the adjacent element
!!$              iel1 = rhadapt%p_IneighboursAtElement(4, iel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
!!$              IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel), 4)
!!$              
!!$              ! The first edge is only marked if it is also marked from the adjacent element              
!!$              iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$              IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel), 1)
!!$                      
!!$              ! The first, second and third edge of LEL must be unmarked.
!!$              p_Imarker(lel) = ibset(0,0)
!!$              
!!$              ! The fourth edge is only marked if it is also marked from the adjacent element              
!!$              iel1 = rhadapt%p_IneighboursAtElement(4, lel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
!!$              IF (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel), 4)
!!$
!!$            ELSE
!!$
!!$              ! Otherwise, element IEL is (!) the inner triangle.
!!$              
!!$              ! To begin with, we need to find the two missing triangles KEL and LEL
!!$              ! which make up the original quadrilateral
!!$              kel = rhadapt%p_IneighboursAtElement(1, iel)
!!$              lel = rhadapt%p_IneighboursAtElement(3, iel)
!!$
!!$              ! Mark the edge of the element adjacent to KEL for subdivision
!!$              iel1 = rhadapt%p_IneighboursAtElement(3, kel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(3, kel)
!!$              IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(kel, iel1)
!!$              
!!$              ! Mark the edge of the element adjacent to LEL for subdivision
!!$              iel1 = rhadapt%p_IneighboursAtElement(1, lel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
!!$              IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(lel, iel1)
!!$
!!$              ! Now, we can physically convert the four triangles into four quadrilaterals
!!$              CALL convert_Quad4Tria(rhadapt, kel, jel, lel, iel,&
!!$                                     rcollection, fcb_hadaptCallback)
!!$              isConform = .FALSE.
!!$
!!$              ! All four elements have to be converted from triangles to quadrilaterals.
!!$              p_Imarker(iel) = ibset(0,0)
!!$
!!$              ! The second and third edge of KEL must be unmarked. Moreover, the first edge is
!!$              ! marked for refinement if and only if it is also marked from the adjacent element
!!$              iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$              IF (ismarked_edge(iel1, iel2, kel)) THEN
!!$                p_Imarker(kel) = ibset(ibset(0,1),0)
!!$              ELSE
!!$                p_Imarker(kel) = ibset(0,0)
!!$              END IF
!!$
!!$              ! The second and third edge of JEL must be unmarked. 
!!$              p_Imarker(jel) = ibset(0,0)
!!$
!!$              ! The fourth edge is only marked if it is also marked from the adjacent element
!!$              iel1 = rhadapt%p_IneighboursAtElement(4, jel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(4, jel)
!!$              IF (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),4)
!!$              
!!$              ! The first edge is only marked if it is also marked from the adjacent element
!!$              iel1 = rhadapt%p_IneighboursAtElement(1, jel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
!!$              IF (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),1)
!!$              
!!$              ! The first, second and third edge of LEL must be unmarked.
!!$              p_Imarker(lel) = ibset(0,0)
!!$
!!$              ! The fourth edge is only marked if it is also marked from the adjacent element
!!$              iel1 = rhadapt%p_IneighboursAtElement(4, lel)
!!$              iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
!!$              IF (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),4)
!!$              
!!$            END IF
!!$          END IF
!!$                    
!!$        CASE(STATE_QUAD_HALF1,&
!!$             STATE_QUAD_HALF2)
!!$          ! Element is quadrilateral that results from a Quad2Quad refinement.
!!$          ! Due to our orientation convention the other "halved" element is 
!!$          ! adjacent to the second edge. 
!!$          jel = rhadapt%p_IneighboursAtElement(2, iel)
!!$
!!$          ! Mark the fourth edge of elements IEL for subdivision
!!$          iel1 = rhadapt%p_IneighboursAtElement(4, iel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
!!$          IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$
!!$          ! Mark the fourth edge of elements JEL for subdivision
!!$          iel1 = rhadapt%p_IneighboursAtElement(4, jel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(4, jel)
!!$          IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(jel, iel1)
!!$          
!!$          ! Now, we can physically convert the two quadrilaterals into four quadrilaterals
!!$          CALL convert_Quad2Quad(rhadapt, iel, jel,&
!!$                                 rcollection, fcb_hadaptCallback)
!!$          isConform = .FALSE.
!!$
!!$          ! The new elements NEL0+1 and NEL0+2 have zero markers by construction.
!!$          kel= rhadapt%p_IneighboursAtElement(2, jel)
!!$          lel= rhadapt%p_IneighboursAtElement(3, iel)
!!$          
!!$          ! As a first step, clear all four elements and mark them as quadrilaterals.
!!$          p_Imarker(iel) = ibset(0,0)
!!$          p_Imarker(jel) = ibset(0,0)
!!$          p_Imarker(kel) = ibset(0,0)
!!$          p_Imarker(lel) = ibset(0,0)
!!$          
!!$          ! In addition, we have to transfer some markers from element IEL and JEL         
!!$          ! to the new elements NEL0+1, NEL0+2.           
!!$          iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$          IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)
!!$          
!!$          iel1 = rhadapt%p_IneighboursAtElement(4, jel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(4, jel)
!!$          IF (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),4)
!!$          
!!$          iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$          IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)
!!$          
!!$          iel1 = rhadapt%p_IneighboursAtElement(4, lel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
!!$          IF (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),4)
!!$         
!!$        CASE(STATE_TRIA_GREENINNER)
!!$          ! We are processing a green triangle. Due to our refinement convention, element IEL
!!$          ! can only be the inner triangle resulting from a Quad3Tria refinement.
!!$          jel = rhadapt%p_IneighboursAtElement(3, iel)
!!$          kel = rhadapt%p_IneighboursAtElement(1, iel)
!!$
!!$          ! To begin with, we need to mark the edges of the adjacent elements for subdivision.
!!$          iel1 = rhadapt%p_IneighboursAtElement(2, iel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(2, iel)
!!$          IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$          
!!$          ! Mark the edge of the element adjacent to JEL for subdivision
!!$          iel1 = rhadapt%p_IneighboursAtElement(3, jel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(3, jel)
!!$          IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(jel, iel1)
!!$
!!$          ! Mark the edge of the element adjacent to KEL for subdivision
!!$          iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$          IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(kel, iel1)
!!$
!!$          ! Now, we can physically convert the three elements IEL,JEL and KEL
!!$          ! into four similar quadrilaterals
!!$          CALL convert_Quad3Tria(rhadapt, jel, kel, iel,&
!!$                                 rcollection, fcb_hadaptCallback)
!!$          isConform = .FALSE.
!!$          
!!$          ! The new element NEL0+1 has zero marker by construction but that of IEL must
!!$          ! be nullified. The markers for the modified triangles also need to be adjusted.
!!$          p_Imarker(iel) = ibset(0,0)
!!$          p_Imarker(jel) = ibset(0,0)
!!$          p_Imarker(kel) = ibset(0,0)
!!$
!!$          ! The first edge is only marked if it is also marked from the adjacent element              
!!$          iel1 = rhadapt%p_IneighboursAtElement(1, jel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
!!$          IF (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),1)
!!$          
!!$          ! The fourth edge is only marked if it is also marked from the adjacent element              
!!$          iel1 = rhadapt%p_IneighboursAtElement(4, kel)
!!$          iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
!!$          IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)
!!$          
!!$        CASE(STATE_TRIA_GREENOUTER_LEFT)
!!$          ! We are processing a green triangle. Here, we have to consider several cases.
!!$          ! First, let us find out the state of the neighboring element JEL.
!!$          jel    = rhadapt%p_IneighboursAtElement(2, iel)
!!$          jstate = redgreen_getState2D(rhadapt, jel)
!!$
!!$          ! What state is element JEL
!!$          SELECT CASE(jstate)
!!$          CASE(STATE_TRIA_GREENOUTER_RIGHT)
!!$            ! Element IEL and JEL are the result of a Tria2Tria refinement, whereby
!!$            ! triangle IEL is located left to element JEL. We can safely convert both
!!$            ! elements into one and perform regular refinement afterwards.
!!$
!!$            ! To begin with, we need to mark the edges of the elements adjacent 
!!$            ! to IEL and JEL for subdivision. 
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$            
!!$            ! The same procedure must be applied to the neighbor of element JEL
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, jel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(jel, iel1)
!!$            
!!$            ! Now, we can physically convert the two elements IEL and JEL into four similar triangles
!!$            CALL convert_Tria2Tria(rhadapt, iel, jel,&
!!$                                   rcollection, fcb_hadaptCallback)
!!$            isConform = .FALSE.
!!$            
!!$            ! The new elements NEL0+1 and NEL0+2 have zero markers by construction.
!!$            ! The markers for the modified elements IEL and JEL need to be adjusted.
!!$            p_Imarker(iel) = 0
!!$            p_Imarker(jel) = 0
!!$
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$            IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)
!!$            
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, jel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, jel)
!!$            IF (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),3)
!!$
!!$          
!!$          CASE(STATE_TRIA_GREENINNER)
!!$            ! Element IEL and JEL are the result of a Quad3Tria refinement, whereby
!!$            ! element JEL is the inner triangle and IEL is its left neighbor.
!!$
!!$            ! To begin with, we need to mark the edges of the elements adjacent to IEL,
!!$            ! JEL and KEL for subdivision. Let us start with the third neighbor of IEL.
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$
!!$            ! The same procedure must be applied to the second neighbor of element JEL
!!$            iel1 = rhadapt%p_IneighboursAtElement(2, jel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(2, jel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(jel, iel1)
!!$            
!!$            ! And again, the same procedure must be applied to the first neighbor of 
!!$            ! element KEL which is the first neighbor of JEL, whereby KEL needs to 
!!$            ! be found in the dynamic data structure first
!!$            kel = rhadapt%p_IneighboursAtElement(1, jel)
!!$            
!!$            ! Ok, now we can proceed to its first neighbor
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(kel, iel1)
!!$            
!!$            ! Now, we can physically convert the three elements IEL,JEL and KEL
!!$            ! into four similar quadrilaterals
!!$            CALL convert_Quad3Tria(rhadapt, iel, kel, jel,&
!!$                                   rcollection, fcb_hadaptCallback)
!!$            isConform = .FALSE.
!!$            
!!$            ! The new element NEL0+1 has zero marker by construction but that of JEL must 
!!$            ! be nullified. The markers for the modified triangles also need to be adjusted.
!!$            p_Imarker(iel) = ibset(0,0)
!!$            p_Imarker(jel) = ibset(0,0)
!!$            p_Imarker(kel) = ibset(0,0)
!!$
!!$            ! The first edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$            IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)
!!$
!!$            ! The fourth edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(4, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
!!$            IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)
!!$           
!!$          CASE(STATE_TRIA_OUTERINNER)
!!$            ! Element IEL and JEL are the result of a Quad4Tria refinement, whereby
!!$            ! element JEL is the inner triangles  and IEL is its right neighbor.
!!$            kel = rhadapt%p_IneighboursAtElement(2, jel)
!!$            lel = rhadapt%p_IneighboursAtElement(3, jel)
!!$
!!$            ! Mark the edge of the element adjacent to IEL for subdivision
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$            
!!$            ! Mark the edge of the element adjacent to LEL for subdivision
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, lel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(lel, iel1)
!!$
!!$            ! Now, we can physically convert the four triangles into four quadrilaterals
!!$            CALL convert_Quad4Tria(rhadapt, iel, kel, lel, jel,&
!!$                                   rcollection, fcb_hadaptCallback)
!!$            isConform = .FALSE.
!!$            
!!$            ! All four elements have to be converted from triangles to quadrilaterals.
!!$            p_Imarker(iel) = ibset(0,0)
!!$            p_Imarker(jel) = ibset(0,0)
!!$            p_Imarker(kel) = ibset(0,0)
!!$            p_Imarker(lel) = ibset(0,0)
!!$            
!!$            ! The first edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$            IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)
!!$
!!$            ! The fourth edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(4, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
!!$            IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)
!!$
!!$            ! The first edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$            IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)
!!$
!!$            ! The fourth edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(4, lel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
!!$            IF (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),4)
!!$
!!$          CASE DEFAULT
!!$            CALL output_line('Invalid element state!',&
!!$                OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
!!$            CALL sys_halt()
!!$          END SELECT
!!$
!!$        CASE(STATE_TRIA_GREENOUTER_RIGHT)
!!$          ! We are processing a green triangle. Here, we have to consider several cases.
!!$          ! First, let us find out the state of the neighboring element JEL.
!!$          jel    = rhadapt%p_IneighboursAtElement(2, iel)
!!$          jstate = redgreen_getState2D(rhadapt, jel)
!!$          
!!$          ! What state is element JEL
!!$          SELECT CASE(jstate)
!!$          CASE(STATE_TRIA_GREENOUTER_LEFT)
!!$            ! Element IEL and JEL are the result of a Tria2Tria refinement, whereby
!!$            ! triangle IEL is located right to element JEL. We can safely convert both
!!$            ! elements into one and perform regular refinement afterwards.
!!$            
!!$            ! To begin with, we need to mark the edges of the elements adjacent
!!$            ! to IEL and JEL for subdivision.
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$            
!!$            ! The same procedure must be applied to the neighbor of element JEL
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, jel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, jel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(jel, iel1)
!!$            
!!$            ! Now, we can physically convert the two elements IEL and JEL into four similar triangles
!!$            CALL convert_Tria2Tria(rhadapt, jel, iel,&
!!$                                   rcollection, fcb_hadaptCallback)
!!$            isConform = .FALSE.
!!$            
!!$            ! The new elements NEL0+1 and NEL0+2 have zero markers by construction.
!!$            ! The markers for the modified elements IEL and JEL need to be adjusted
!!$            p_Imarker(iel) = 0
!!$            p_Imarker(jel) = 0
!!$            
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, jel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
!!$            IF (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),1)
!!$            
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
!!$            IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),3)
!!$
!!$
!!$          CASE(STATE_TRIA_GREENINNER)
!!$            ! Element IEL and JEL are the result of a Quad3Tria refinement, whereby
!!$            ! element JEL is the inner triangle and IEL is its left neighbor.
!!$
!!$            ! To begin with, we need to mark the edges of the elements adjacent to IEL,
!!$            ! JEL and KEL for subdivision. Let us start with the firth neighbor of IEL.
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$
!!$            ! The same procedure must be applied to the second neighbor of element JEL
!!$            iel1 = rhadapt%p_IneighboursAtElement(2, jel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(2, jel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(jel, iel1)
!!$
!!$            ! And again, the same procedure must be applied to the third neighbor of 
!!$            ! element KEL which is the third neighbor of JEL, whereby KEL needs to 
!!$            ! be found in the dynamic data structure first
!!$            kel = rhadapt%p_IneighboursAtElement(3, jel)
!!$
!!$            ! Ok, now we can proceed to its first neighbor
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, kel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(kel, iel1)
!!$
!!$            ! Now, we can physically convert the three elements IEL,JEL and KEL
!!$            ! into four similar quadrilaterals
!!$            CALL convert_Quad3Tria(rhadapt, kel, iel, jel,&
!!$                                   rcollection, fcb_hadaptCallback)
!!$            isConform = .FALSE.
!!$            
!!$            ! The new element NEL0+1 has zero marker by construction but that of JEL must
!!$            ! be nullified. The markers for the modified triangles also need to be adjusted.
!!$            p_Imarker(iel) = ibset(0,0)
!!$            p_Imarker(jel) = ibset(0,0)
!!$            p_Imarker(kel) = ibset(0,0)
!!$
!!$            ! The first edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$            IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)
!!$
!!$            ! The fourth edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(4, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
!!$            IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),4)
!!$            
!!$          CASE(STATE_TRIA_OUTERINNER)
!!$            ! Element IEL and JEL are the result of a Quad4Tria refinement, whereby
!!$            ! element JEL is the inner triangles  and IEL is its left neighbor.
!!$            kel = rhadapt%p_IneighboursAtElement(2, jel)
!!$            lel = rhadapt%p_IneighboursAtElement(1, jel)
!!$
!!$            ! Mark the edge of the element adjacent to IEL for subdivision
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(iel, iel1)
!!$
!!$            ! Mark the edge of the element adjacent to LEL for subdivision
!!$            iel1 = rhadapt%p_IneighboursAtElement(3, lel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(3, lel)
!!$            IF (iel1*iel2 .NE. 0 .AND. iel1 .EQ. iel2) CALL mark_edge(lel, iel1)
!!$
!!$            ! Now, we can physically convert the four triangles into four quadrilaterals
!!$            CALL convert_Quad4Tria(rhadapt, lel, kel, iel, jel,&
!!$                                   rcollection, fcb_hadaptCallback)
!!$            isConform = .FALSE.
!!$            
!!$            ! All four elements have to be converted from triangles to quadrilaterals.
!!$            p_Imarker(iel) = ibset(0,0)
!!$            p_Imarker(jel) = ibset(0,0)
!!$            p_Imarker(kel) = ibset(0,0)
!!$            p_Imarker(lel) = ibset(0,0)
!!$
!!$            ! The first edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, lel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
!!$            IF (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),1)
!!$
!!$            ! The fourth edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(4, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
!!$            IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)
!!$
!!$            ! The first edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
!!$            IF (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)
!!$
!!$            ! The fourth edge is only marked if it is also marked from the adjacent element
!!$            iel1 = rhadapt%p_IneighboursAtElement(4, iel)
!!$            iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
!!$            IF (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),4)
!!$
!!$          CASE DEFAULT
!!$            CALL output_line('Invalid element state!',&
!!$                OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
!!$            CALL sys_halt()
!!$          END SELECT
!!$          
!!$        CASE DEFAULT
!!$          CALL output_line('Invalid element state!',&
!!$              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
!!$          CALL sys_halt()
!!$        END SELECT
!!$100     CONTINUE
!!$
!!$        !------------------------------------------------------------
!!$        ! Now, we can safely loop over adjacent cells of element IEL
!!$        !------------------------------------------------------------
!!$        DO ive = 1, nve
!!$
!!$          ! If element IEL is adjacent to two different elements along one edge
!!$          ! then ignore this edge. This situation can arise, if the element IEL
!!$          ! is adjacent to a green element JEL which has been converted previously,
!!$          ! so that element IEL has two neighbors along the edge, i.e., IEL and one 
!!$          ! new element number >NEL0
!!$          IF (rhadapt%p_IneighboursAtElement(ive,iel) .NE. &
!!$              rhadapt%p_ImidneighboursAtElement(ive,iel)) CYCLE
!!$          
!!$          ! If the edge shared by element IEL and its neighbor JEL has been 
!!$          ! marked for refinement and JEL is not outside of the domain, i.e.,
!!$          ! element IEL is located at the boundary, then proceed to element JEL.
!!$          IF (btest(p_Imarker(iel), ive)) THEN
!!$            
!!$            ! Check if the current edge is located at the boundary, 
!!$            ! than nothing needs to be done
!!$            jel = rhadapt%p_IneighboursAtElement(ive, iel)
!!$            IF (jel .EQ. 0) CYCLE
!!$            
!!$            ! Get number of vertices per element
!!$            mve = hadapt_getNVE(rhadapt, jel)
!!$            
!!$            ! Are we triangular or quadrilateral element?
!!$            SELECT CASE(mve)
!!$            CASE(TRIA_NVETRI2D)
!!$              p_Imarker(jel) = ibclr(p_Imarker(jel),0)
!!$
!!$            CASE(TRIA_NVEQUAD2D)
!!$              p_Imarker(jel) = ibset(p_Imarker(jel),0)
!!$
!!$            CASE DEFAULT
!!$              CALL output_line('Invalid number of vertices per element!',&
!!$                  OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
!!$              CALL sys_halt()
!!$            END SELECT
!!$
!!$            ! Now, we need to find the local position of element IEL in the
!!$            ! adjacency list of the nieghboring element JEL
!!$            DO jve = 1, mve
!!$              IF (rhadapt%p_IneighboursAtElement(jve, jel) .EQ. iel) EXIT
!!$            END DO
!!$
!!$            IF (jve > mve) THEN
!!$              CALL output_line('Unable to find element!',&
!!$                  OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
!!$              CALL sys_halt()
!!$            END IF
!!$
!!$            ! If the edge is already marked for refinement then we can
!!$            ! guarantee conformity for the edge shared by IEL and JEL.
!!$            ! Otherwise, this edge needs to be marked "looking" from JEL
!!$            IF (.NOT.btest(p_Imarker(jel), jve)) THEN
!!$              p_Imarker(jel) = ibset(p_Imarker(jel), jve)
!!$              isConform      = .FALSE.
!!$              IF (p_Imodified(jel) .NE. imodifier) p_Imodified(jel)= -imodifier
!!$            END IF
!!$
!!$            ! Finally, "lock" all vertices of element JEL
!!$            IverticesAtElement(1:mve) = rhadapt%p_IverticesAtElement(1:mve,jel)
!!$            rhadapt%p_IvertexAge(IverticesAtElement(1:mve))=&
!!$                -ABS(rhadapt%p_IvertexAge(IverticesAtElement(1:mve)))
!!$          END IF
!!$        END DO
!!$      END DO
!!$      
!!$      ! Note that the number of elements (and vertices) may have changed
!!$      ! due to conversion of green into red elements. Hence, adjust dimensions.
!!$      rhadapt%NEL0 = rhadapt%NEL
!!$      rhadapt%NVT0 = rhadapt%NVT
!!$
!!$      !--------------------------------------------------------------
!!$      ! We don't want to have elements with two and/or three divided edges, 
!!$      ! aka, blue refinement for triangles and quadrilaterals, respectively.
!!$      ! As a remedy, these elements are filtered and marked for red refinement.
!!$      !--------------------------------------------------------------
!!$      DO iel = 1, rhadapt%NEL0
!!$        IF (p_Imodified(iel)*imodifier .EQ. 0) CYCLE
!!$        
!!$        ! What type of element are we?
!!$        SELECT CASE(p_Imarker(iel))
!!$        CASE(MARK_REF_TRIA3TRIA_12,&
!!$             MARK_REF_TRIA3TRIA_13,&
!!$             MARK_REF_TRIA3TRIA_23)
!!$          ! Blue refinement for triangles is not allowed.
!!$          ! Hence, mark triangle for red refinement
!!$          p_Imarker(iel)      =  MARK_REF_TRIA4TRIA
!!$          p_Imodified(iel)    = -imodifier
!!$          isConform           =  .FALSE.
!!$          rhadapt%increaseNVT =  rhadapt%increaseNVT+1
!!$          
!!$        CASE(MARK_REF_QUADBLUE_123,&
!!$             MARK_REF_QUADBLUE_412,&
!!$             MARK_REF_QUADBLUE_341,&
!!$             MARK_REF_QUADBLUE_234)
!!$          ! Blue refinement for quadrilaterals is not allowed. 
!!$          ! Hence, mark quadrilateral for red refinement
!!$          p_Imarker(iel)      =  MARK_REF_QUAD4QUAD
!!$          p_Imodified(iel)    = -imodifier
!!$          isConform           =  .FALSE.
!!$          rhadapt%increaseNVT =  rhadapt%increaseNVT+2
!!$
!!$        CASE DEFAULT
!!$          p_Imodified(iel) = (p_Imodified(iel)-imodifier)/2
!!$        END SELECT
!!$      END DO
!!$      
!!$      ! Reverse modifier
!!$      imodifier = -imodifier
!!$    END DO conformity
!!$
!!$    ! As a last step, lock all vertices of those elements which are marked 
!!$    ! for refinement and increase the number of new vertices by the number
!!$    ! of quadrilateral elements which are marked for red refinement
!!$    DO iel = 1, SIZE(p_Imarker, 1)
!!$      
!!$      ! What type of element are we?
!!$      SELECT CASE(p_Imarker(iel))
!!$      CASE(MARK_REF_TRIA2TRIA_1)
!!$        i = rhadapt%p_IverticesAtElement(3, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$        
!!$      CASE(MARK_REF_TRIA2TRIA_2)
!!$        i = rhadapt%p_IverticesAtElement(1, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$      CASE(MARK_REF_TRIA2TRIA_3)
!!$        i = rhadapt%p_IverticesAtElement(2, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$      CASE(MARK_REF_QUAD3TRIA_1)
!!$        i = rhadapt%p_IverticesAtElement(3, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$        i = rhadapt%p_IverticesAtElement(4, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$        
!!$      CASE(MARK_REF_QUAD3TRIA_2)
!!$        i = rhadapt%p_IverticesAtElement(1, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$        i = rhadapt%p_IverticesAtElement(4, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$      CASE(MARK_REF_QUAD3TRIA_3)
!!$        i = rhadapt%p_IverticesAtElement(1, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$        i = rhadapt%p_IverticesAtElement(2, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$      CASE(MARK_REF_QUAD3TRIA_4)
!!$        i = rhadapt%p_IverticesAtElement(2, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$        
!!$        i = rhadapt%p_IverticesAtElement(3, iel)
!!$        rhadapt%p_IvertexAge(i) = -ABS(rhadapt%p_IvertexAge(i))
!!$
!!$      CASE(MARK_REF_QUAD4QUAD)
!!$        rhadapt%increaseNVT = rhadapt%increaseNVT+1
!!$      END SELECT
!!$    END DO
!!$      
!!$    ! Free auxiliary storage
!!$    CALL storage_free(h_Imodified)
!!$
!!$  CONTAINS
!!$
!!$    ! Here, the real working routines follow.
!!$
!!$    !**************************************************************
!!$    ! For a given element IEL, mark the edge that connects IEL 
!!$    ! to its neighbor JEL in the marker array at position JEL
!!$    
!!$    SUBROUTINE mark_edge(iel, jel)
!!$
!!$      INTEGER(PREC_ELEMENTIDX), INTENT(IN) :: iel
!!$      INTEGER(PREC_ELEMENTIDX), INTENT(IN) :: jel
!!$
!!$      ! local variables
!!$      INTEGER :: ive,nve
!!$
!!$      ! Get number of vertices per element
!!$      nve = hadapt_getNVE(rhadapt, jel)
!!$      
!!$      ! Find local position of element IEL in adjacency list of JEL
!!$      SELECT CASE(nve)
!!$      CASE(TRIA_NVETRI2D)
!!$        ! Triangular elements
!!$        DO ive = 1, nve
!!$          IF (rhadapt%p_IneighboursAtElement(ive, jel) .EQ. iel) THEN
!!$            p_Imarker(jel) = ibclr(ibset(p_Imarker(jel), ive),0)
!!$            isConform      =.FALSE.
!!$            IF (p_Imodified(jel) .NE. imodifier) p_Imodified(jel) = -imodifier
!!$            EXIT
!!$          END IF
!!$        END DO
!!$
!!$      CASE(TRIA_NVEQUAD2D)
!!$        ! Quadrilateral element
!!$        DO ive = 1, nve
!!$          IF (rhadapt%p_IneighboursAtElement(ive, jel) .EQ. iel) THEN
!!$            p_Imarker(jel) = ibset(ibset(p_Imarker(jel), ive),0)
!!$            isConform      =.FALSE.
!!$            IF (p_Imodified(jel) .NE. imodifier) p_Imodified(jel) = -imodifier
!!$            EXIT
!!$          END IF
!!$        END DO
!!$
!!$      CASE DEFAULT
!!$        CALL output_line('Invalid number of vertices per element!',&
!!$            OU_CLASS_ERROR,OU_MODE_STD,'mark_edge')
!!$        CALL sys_halt()
!!$      END SELECT
!!$    END SUBROUTINE mark_edge
!!$
!!$    !**************************************************************
!!$    ! For a given element IEL, check if the edge that connects IEL
!!$    ! with its adjacent element JEL is marked
!!$
!!$    FUNCTION ismarked_edge(iel, ielmid, jel) RESULT (bismarked)
!!$
!!$      INTEGER(PREC_ELEMENTIDX), INTENT(IN) :: iel,ielmid,jel
!!$      LOGICAL :: bismarked
!!$
!!$      ! local variables
!!$      INTEGER :: ive,nve
!!$
!!$      ! Are we at the boundary?
!!$      IF (iel*ielmid .EQ. 0) THEN
!!$        bismarked = .FALSE.
!!$        RETURN
!!$      ELSEIF(iel .NE. ielmid) THEN
!!$        bismarked = .TRUE.
!!$        RETURN
!!$      END IF
!!$      
!!$      ! Loop over all edges of element IEL and try to find neighbor JEL
!!$      DO ive = 1, hadapt_getNVE(rhadapt, iel)
!!$        IF (rhadapt%p_IneighboursAtElement(ive, iel)    .EQ. jel .OR.&
!!$            rhadapt%p_ImidneighboursAtElement(ive, iel) .EQ. jel) THEN
!!$          bismarked = btest(p_Imarker(iel), ive)
!!$          RETURN
!!$        END IF
!!$      END DO
!!$      
!!$      CALL output_line('Unable to find common egde!',&
!!$          OU_CLASS_ERROR,OU_MODE_STD,'ismarked_edge')
!!$      CALL sys_halt()
!!$    END FUNCTION ismarked_edge
!!$  END SUBROUTINE redgreen_mark_refinement2D

  ! ***************************************************************************

!<subroutine>
  
  subroutine redgreen_mark_refinement2D(rhadapt, rcollection, fcb_hadaptCallback)

!<description>
    ! This subroutine initializes the adaptive data structure for red-green
    ! refinement. Starting from the marker array the neighbors of elements 
    ! which are marked for refinement are recursively marked for refinement
    ! until the resulting mesh satiesfies global conformity. 
    ! Note that this subroutine is implemented in an iterative fashion 
    ! rather than making use of recursive subroutine calls.
!</description>

!<input>
    ! Callback function
    include 'intf_hadaptcallback.inc'
    optional :: fcb_hadaptCallback
!</input>

!<inputoutput>
    ! adaptive data structure
    type(t_hadapt), intent(INOUT)               :: rhadapt

    ! OPTIONAL: Collection
    type(t_collection), intent(INOUT), optional :: rcollection
!</inputoutput>
!</subroutine>

    ! local variables
    integer, dimension(:), pointer                    :: p_Imarker,p_Imodifier
    integer(PREC_VERTEXIDX), dimension(TRIA_MAXNVE2D) :: IverticesAtElement
    integer(PREC_ELEMENTIDX), dimension(1)            :: Ielements
    integer(PREC_VERTEXIDX), dimension(1)             :: Ivertices
    integer(PREC_VERTEXIDX)  :: nvt,ivt
    integer(PREC_ELEMENTIDX) :: nel,iel,jel,kel,lel,iel1,iel2
    integer :: ive,jve,nve,mve,istate,jstate,kstate
    integer :: h_Imodifier,imodifier
    logical :: bisFirst,bisModified
    integer, dimension(TRIA_MAXNVE) :: IvertexAge
    
    !---------------------------------------------------------------------------
    ! At the moment, only those cells are marked for regular refinement 
    ! for which the cell indicator does not satisfy some prescribed treshold.
    ! In order to globally restore the conformity of the final grid, we have
    ! to loop repeatedly over all elements and check if each of the three/four
    ! adjacent edges satisfies conformity. 
    ! Some care must be taken for green elements. In order to retain the 
    ! shape quality of the elements, green elements need to be converted into
    ! red ones prior to performing further refinement. 
    !--------------------------------------------------------------------------
    !
    ! In the course of element marking, some green elements may have to be 
    ! converted into regularly refined ones. In the worst case, i.e.
    ! Quad2Quad-refinement, each green element gives rise to 1.5 vertices 
    ! and 2 new elements. Hence, the nodal arrays p_IvertexAge and 
    ! p_InodalProperty as well as the element arrays p_IverticesAtElement,
    ! p_IneighboursAtElement, p_ImidneighboursAtElement and p_Imarker are
    ! adjusted to the new dimensione.
    !
    if (rhadapt%nGreenElements .gt. 0) then

      ! Predict new dimensions for the worst case
      nvt = ceiling(rhadapt%NVT0 + 1.5*rhadapt%nGreenElements)
      nel = rhadapt%NEL0 + 2*rhadapt%nGreenElements

      ! Adjust nodal/elemental arrays
      call storage_realloc('redgreen_mark_refinement2D', nvt,&
                           rhadapt%h_IvertexAge, ST_NEWBLOCK_ZERO, .true.)
      call storage_realloc('redgreen_mark_refinement2D', nvt,&
                           rhadapt%h_InodalProperty, ST_NEWBLOCK_ZERO, .true.)
      call storage_realloc('redgreen_mark_refinement2D', nel,&
                           rhadapt%h_Imarker, ST_NEWBLOCK_ZERO, .true.)
      call storage_realloc('redgreen_mark_refinement2D', nel,&
                           rhadapt%h_IverticesAtElement, ST_NEWBLOCK_NOINIT, .true.)
      call storage_realloc('redgreen_mark_refinement2D', nel,&
                           rhadapt%h_IneighboursAtElement, ST_NEWBLOCK_NOINIT, .true.)
      call storage_realloc('redgreen_mark_refinement2D', nel,&
                           rhadapt%h_ImidneighboursAtElement, ST_NEWBLOCK_NOINIT, .true.)
      
      ! Reset pointers
      call storage_getbase_int(rhadapt%h_IvertexAge,&
                               rhadapt%p_IvertexAge)
      call storage_getbase_int(rhadapt%h_InodalProperty,&
                               rhadapt%p_InodalProperty)
      call storage_getbase_int2D(rhadapt%h_IverticesAtElement,&
                                 rhadapt%p_IverticesAtElement)
      call storage_getbase_int2D(rhadapt%h_IneighboursAtElement,&
                                 rhadapt%p_IneighboursAtElement)
      call storage_getbase_int2D(rhadapt%h_ImidneighboursAtElement,&
                                 rhadapt%p_ImidneighboursAtElement)

      ! Adjust dimension of solution vector
      if (present(fcb_hadaptCallback) .and. present(rcollection)) then
        Ivertices = (/nvt/)
        Ielements = (/0/)
        call fcb_hadaptCallback(rcollection, HADAPT_OPR_ADJUSTVERTEXDIM,&
                                Ivertices, Ielements)
      end if

      ! Create new array for modifier
      call storage_new('redgreen_mark_refinement2D', 'p_Imodifier', nel,&
                       ST_INT, h_Imodifier, ST_NEWBLOCK_ZERO)
      call storage_getbase_int(h_Imodifier, p_Imodifier)
      call storage_getbase_int(rhadapt%h_Imarker, p_Imarker)

    else
      
      ! No green elements have to be considered, hence use NEL0      
      call storage_new('redgreen_mark_refinement2D', 'p_Imodifier', rhadapt%NEL0,&
                        ST_INT, h_Imodifier, ST_NEWBLOCK_ZERO)
      call storage_getbase_int(h_Imodifier, p_Imodifier)
      call storage_getbase_int(rhadapt%h_Imarker, p_Imarker)

    end if

    ! The task of the two arrays p_Imarker and p_Imodifier are as follows:
    !
    ! - p_Imarker stores for each element its individual state from which
    !   the task of refinement can be uniquely determined (see above; 
    !   data type t_hadapt).
    !   If the state of one element is modified, then potentionally all
    !   neighboringelements have to be checked, if conformity is violated.
    !   In order to prevent this (expensive) check to be performed for all
    !   elements again and again, only those elements are investigated for
    !   which the modifier p_Imodifier is active, i.e. 
    !   p_Imodifier(iel) .EQ. imodifier. In order to pre-select elements
    !   for investigation in the next loop, p_Imodifier(iel) is set to 
    !   -imodifier and the modifier is reversed after each iteration.
    !
    !   This complicated step is necessary for the following reason:
    !
    !   If one element with mediate number initially is not marked but
    !   gets marked for subdivision at one edge, then it will be considered
    !   in the same iteration and green elements will eventually converted.
    !   However, it is possible that the same element would be marked for
    !   subdivision at another edge due to an adjacent element with large
    !   number. Hence, it is advisable to first process all elements which 
    !   are activated and pre-select their neighbors for the next iteration.
    
    ! Ok, so let's start.
    imodifier = 1
    
    ! Initially, set the modified for all elements of the given triangulation
    ! which are  marked for refinement due to accuracy reasons.
    do iel = 1, rhadapt%NEL0
      if (p_Imarker(iel) .ne. MARK_ASIS) p_Imodifier(iel) = imodifier
    end do

    ! Initialization
    bisModified = .true.
    bisFirst    = .true.
    
    ! Iterate until global conformity is achieved
    conform: do while(bisModified)
      
      ! Ok, hopefully nothing gets modified
      bisModified = .false.
      
      ! Loop over all elements present in the initial grid (IEL <= NEL0)
      ! which are modified and mark their neighbors for further refinement
      ! if conformity is violated for some edge.
      element: do iel = 1, rhadapt%NEL0
        
        ! Skip those element which have not been modified
        if (p_Imodifier(iel) .ne. imodifier) cycle element


        ! Get number of vertices per element
        nve = hadapt_getNVE(rhadapt, iel)
        
        ! Get local data for element IEL
        do ive = 1, nve
          IverticesAtElement(ive) = rhadapt%p_IverticesAtElement(ive, iel)
        end do
      
        ! Are we triangular or quadrilateral element?
        select case(nve)
        case(TRIA_NVETRI2D)
          ! Triangular element: Clear bit0
          p_Imarker(iel) = ibclr(p_Imarker(iel), 0)
          
          ! Get element state
          do ive = 1, TRIA_NVETRI2D
            IvertexAge(ive) = rhadapt%p_IvertexAge(IverticesAtElement(ive))
          end do
          istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))

        case(TRIA_NVEQUAD2D)
          ! Quadrilateral element: Set bit0
          p_Imarker(iel) = ibset(p_Imarker(iel), 0)

          ! Get element state
          do ive = 1, TRIA_NVEQUAD2D
            IvertexAge(ive) = rhadapt%p_IvertexAge(IverticesAtElement(ive))
          end do
          istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))

        case DEFAULT
          call output_line('Invalid number of vertices per element!',&
              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
          call sys_halt()
        end select


        !-----------------------------------------------------------------------
        ! Check if the state of the current element IEL allows direct
        ! refinement or if the elements needs to be "converted" first
        !-----------------------------------------------------------------------
        select case(istate)
        case (STATE_TRIA_ROOT,&
              STATE_QUAD_ROOT,&
              STATE_TRIA_REDINNER,&
              STATE_QUAD_RED1,&
              STATE_QUAD_RED2,&
              STATE_QUAD_RED3,&
              STATE_QUAD_RED4)
          ! States which can be directly accepted for local refinement


        case(STATE_TRIA_OUTERINNER1,&
             STATE_TRIA_OUTERINNER2)
          ! Theoretically, these states may occure and have to be treated 
          ! like CASE(4), see below. Due to the fact, that these states can
          ! only be generated by means of local red-green refinement and are
          ! not present in the initial grid we make use of additional know-
          ! ledge: Triangles which have too youngest vertices can either
          ! be outer red elements resulting from a Tria4Tria refinement 
          ! or one of the opposite triangles resulting from Quad4Tria refinement.
          ! In all cases, the edge which connects the two nodes is opposite
          ! to the first local vertex. Hence, work must only be done for CASE(4)
          call output_line('These states must not occur!',&
              OU_CLASS_ERROR, OU_MODE_STD, 'redgreen_mark_refinement2D')
          call sys_halt()

          
        case(STATE_TRIA_OUTERINNER)
          ! The triangle can either be an outer red element resulting from a Tria4Tria 
          ! refinement or one of the two opposite triangles resulting from Quad4Tria 
          ! refinement. This can be easily checked. If the opposite element is not 
          ! an inner red triangle (14), then the element IEL and its opposite neighbor 
          ! make up the inner "diamond" resulting from a Quad4Tria refinement. 
          jel = rhadapt%p_IneighboursAtElement(2, iel)
       
          ! First, we need to check a special case. If the second edge of element IEL
          ! has two different neighbors, then the original neighbor along this edge
          ! was a green triangle that has been converted into an (outer) red one. In
          ! this case, the current element IEL does not need further modifications.
          if (jel .ne. rhadapt%p_ImidneighboursAtElement(2, iel)) goto 100
          
          ! Otherwise, determine the state of the edge neighbor JEL
          jstate = redgreen_getState2D(rhadapt, jel)
          
          if (jstate .eq. STATE_TRIA_OUTERINNER) then
            
            ! We know that element IEL and JEL make up the inner "diamond" resulting
            ! from a Quad4Tria refinement. It remains to find the two green triangle
            ! which make up the outer part of the macro element.
            ! Since we do not know if they are adjacent to element IEL or JEL we 
            ! have to perform additional checks: 
            !
            ! - The element along the first edge of the inner triangle
            !   must have state STATE_TRIA_GREENOUTER_LEFT
            !
            kel    = rhadapt%p_IneighboursAtElement(1, iel)
            kstate = redgreen_getState2D(rhadapt, kel)

            if (kstate .ne. STATE_TRIA_GREENOUTER_LEFT .or.&
                rhadapt%p_IneighboursAtElement(2, kel) .ne. iel) then
              ! At this stage we can be sure that element IEL is not (!) 
              ! the inner triangle, hence, it must be element JEL
              
              ! We need to find the two missing triangles KEL and LEL
              ! which make up the original quadrilateral
              kel = rhadapt%p_IneighboursAtElement(1, jel)
              lel = rhadapt%p_IneighboursAtElement(3, jel)

              ! Mark the edge of the element adjacent to KEL for subdivision
              iel1 = rhadapt%p_IneighboursAtElement(3, kel)
              iel2 = rhadapt%p_ImidneighboursAtElement(3, kel)
              if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(kel, iel1)

              ! Mark the edge of the element adjacent to LEL for subdivision
              iel1 = rhadapt%p_IneighboursAtElement(1, lel)
              iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
              if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(lel, iel1)

              ! Physically convert the four triangles into four quadrilaterals
              call convert_Quad4Tria(rhadapt, kel, iel, lel, jel,&
                                     rcollection, fcb_hadaptCallback)
              
              ! We modified some elements in this iteration
              bisModified = .true.


              ! All edges of element JEL must be unmarked.
              p_Imarker(jel) = ibset(0, 0)


              ! The second and third edge of element KEL must be unmarked.
              ! Moreover, the first edge of element KEL is marked for 
              ! refinement if it is also marked from the adjacent element.
              iel1 = rhadapt%p_IneighboursAtElement(1, kel)
              iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
              if (ismarked_edge(iel1, iel2, kel)) then
                p_Imarker(kel) = ibset(ibset(0, 1), 0)
              else
                p_Imarker(kel) = ibset(0, 0)
              end if


              ! The second and third edge of element IEL must be unmarked.
              p_Imarker(iel) = ibset(0, 0)

              ! The fourth edge of element IEL is only marked if it
              ! is also marked from the adjacent element
              iel1 = rhadapt%p_IneighboursAtElement(4, iel)
              iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
              if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel), 4)
              
              ! The first edge of element IEL is only marked if it
              ! is also marked from the adjacent element              
              iel1 = rhadapt%p_IneighboursAtElement(1, iel)
              iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
              if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel), 1)
                      

              ! The first, second and third edge of element LEL must be unmarked.
              p_Imarker(lel) = ibset(0,0)
              
              ! The fourth edge of element LEL is only marked if it 
              ! is  also marked from the adjacent element              
              iel1 = rhadapt%p_IneighboursAtElement(4, lel)
              iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
              if (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel), 4)
              
            else

              ! Otherwise, element IEL is (!) the inner triangle.
              
              ! We need to find the two missing triangles KEL and LEL
              ! which make up the original quadrilateral
              kel = rhadapt%p_IneighboursAtElement(1, iel)
              lel = rhadapt%p_IneighboursAtElement(3, iel)

              ! Mark the edge of the element adjacent to KEL for subdivision
              iel1 = rhadapt%p_IneighboursAtElement(3, kel)
              iel2 = rhadapt%p_ImidneighboursAtElement(3, kel)
              if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(kel, iel1)
              
              ! Mark the edge of the element adjacent to LEL for subdivision
              iel1 = rhadapt%p_IneighboursAtElement(1, lel)
              iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
              if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(lel, iel1)

              ! Physically convert the four triangles into four quadrilaterals
              call convert_Quad4Tria(rhadapt, kel, jel, lel, iel,&
                                     rcollection, fcb_hadaptCallback)
              
              ! We modified some elements in this iteration
              bisModified = .true.

              
              ! All edges of element IEL must be unmarked.
              p_Imarker(iel) = ibset(0,0)
              
              ! The second and third edge of element KEL must be unmarked.
              ! Moreover, the first edge if element KEL is marked for 
              ! refinement if it is also marked from the adjacent element
              iel1 = rhadapt%p_IneighboursAtElement(1, kel)
              iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
              if (ismarked_edge(iel1, iel2, kel)) then
                p_Imarker(kel) = ibset(ibset(0,1),0)
              else
                p_Imarker(kel) = ibset(0,0)
              end if


              ! The second and third edge of element JEL must be unmarked. 
              p_Imarker(jel) = ibset(0,0)

              ! The fourth edge of element JEL is only marked if it
              ! is also marked from the adjacent element
              iel1 = rhadapt%p_IneighboursAtElement(4, jel)
              iel2 = rhadapt%p_ImidneighboursAtElement(4, jel)
              if (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),4)

              ! The first edge of element JEL is only marked if it 
              ! is also marked from the adjacent element
              iel1 = rhadapt%p_IneighboursAtElement(1, jel)
              iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
              if (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),1)
              

              ! The first, second and third edge of element LEL must be unmarked.
              p_Imarker(lel) = ibset(0,0)

              ! The fourth edge of element LEL is only marked if it
              ! is also marked from the adjacent element
              iel1 = rhadapt%p_IneighboursAtElement(4, lel)
              iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
              if (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),4)
              
            end if

            ! If we are in the first iteration which is caused by elements
            ! marked for refinement due to accuracy reasons, then "lock" 
            ! the four midpoint vertices which must not be deleted.
            if (bisFirst) then
              ivt = rhadapt%p_IverticesAtElement(2, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(3, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

              ivt = rhadapt%p_IverticesAtElement(2, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, kel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, lel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end if
            
          end if   ! jstate = STATE_TRIA_OUTERINNER

                    
        case(STATE_QUAD_HALF1,&
             STATE_QUAD_HALF2)
          ! Element is quadrilateral that results from a Quad2Quad 
          ! refinement. Due to the orientation convention the other 
          ! "halved" element is adjacent to the second edge. 
          jel = rhadapt%p_IneighboursAtElement(2, iel)

          ! Mark the fourth edge of elements IEL for subdivision
          iel1 = rhadapt%p_IneighboursAtElement(4, iel)
          iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
          if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)

          ! Mark the fourth edge of elements JEL for subdivision
          iel1 = rhadapt%p_IneighboursAtElement(4, jel)
          iel2 = rhadapt%p_ImidneighboursAtElement(4, jel)
          if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(jel, iel1)
          
          ! Physically convert the two quadrilaterals into four quadrilaterals
          call convert_Quad2Quad(rhadapt, iel, jel,&
                                 rcollection, fcb_hadaptCallback)

          ! We modified some elements in this iteration
          bisModified = .true.


          ! The new elements NEL0+1 and NEL0+2 have zero markers by construction.
          kel= rhadapt%p_IneighboursAtElement(2, jel)
          lel= rhadapt%p_IneighboursAtElement(3, iel)
          
          ! As a first step, clear all four elements and mark them as quadrilaterals.
          p_Imarker(iel) = ibset(0,0)
          p_Imarker(jel) = ibset(0,0)
          p_Imarker(kel) = ibset(0,0)
          p_Imarker(lel) = ibset(0,0)
          
          ! In addition, we have to transfer some markers from element IEL and JEL         
          ! to the new elements NEL0+1, NEL0+2.           
          iel1 = rhadapt%p_IneighboursAtElement(1, iel)
          iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
          if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)
          
          iel1 = rhadapt%p_IneighboursAtElement(4, jel)
          iel2 = rhadapt%p_ImidneighboursAtElement(4, jel)
          if (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),4)
          
          iel1 = rhadapt%p_IneighboursAtElement(1, kel)
          iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
          if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)
          
          iel1 = rhadapt%p_IneighboursAtElement(4, lel)
          iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
          if (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),4)


          ! If we are in the first iteration which is caused by elements
          ! marked for refinement due to accuracy reasons, then "lock" 
          ! the four midpoint vertices which must not be deleted.
          if (bisFirst) then
            ivt = rhadapt%p_IverticesAtElement(2, iel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            
            ivt = rhadapt%p_IverticesAtElement(3, iel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

            ivt = rhadapt%p_IverticesAtElement(2, jel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            
            ivt = rhadapt%p_IverticesAtElement(2, kel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            
            ivt = rhadapt%p_IverticesAtElement(2, lel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
          end if

         
        case(STATE_TRIA_GREENINNER)
          ! We are processing a green triangle. Due to our refinement 
          ! convention, element IEL can only be the inner triangle
          ! resulting from a Quad3Tria refinement.
          jel = rhadapt%p_IneighboursAtElement(3, iel)
          kel = rhadapt%p_IneighboursAtElement(1, iel)

          ! We need to mark the edges of the adjacent elements for subdivision.
          iel1 = rhadapt%p_IneighboursAtElement(2, iel)
          iel2 = rhadapt%p_ImidneighboursAtElement(2, iel)
          if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)
          
          ! Mark the edge of the element adjacent to JEL for subdivision
          iel1 = rhadapt%p_IneighboursAtElement(3, jel)
          iel2 = rhadapt%p_ImidneighboursAtElement(3, jel)
          if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(jel, iel1)

          ! Mark the edge of the element adjacent to KEL for subdivision
          iel1 = rhadapt%p_IneighboursAtElement(1, kel)
          iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
          if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(kel, iel1)

          ! Physically convert the three elements IEL, JEL and KEL
          ! into four similar quadrilaterals
          call convert_Quad3Tria(rhadapt, jel, kel, iel,&
                                 rcollection, fcb_hadaptCallback)

          ! We modified some elements in this iteration
          bisModified = .true.
          

          ! The new element NEL0+1 has zero marker by construction 
          ! but that of IEL must be nullified. The markers for the
          ! modified triangles also need to be adjusted.
          p_Imarker(iel) = ibset(0,0)
          p_Imarker(jel) = ibset(0,0)
          p_Imarker(kel) = ibset(0,0)

          ! The first edge is only marked if it is also marked from the adjacent element              
          iel1 = rhadapt%p_IneighboursAtElement(1, jel)
          iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
          if (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),1)
          
          ! The fourth edge is only marked if it is also marked from the adjacent element              
          iel1 = rhadapt%p_IneighboursAtElement(4, kel)
          iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
          if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)

          
          ! If we are in the first iteration which is caused by elements
          ! marked for refinement due to accuracy reasons, then "lock" 
          ! the four midpoint vertices which must not be deleted.
          if (bisFirst) then
            ivt = rhadapt%p_IverticesAtElement(2, iel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

            ivt = rhadapt%p_IverticesAtElement(3, iel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            
            ivt = rhadapt%p_IverticesAtElement(4, iel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

            ivt = rhadapt%p_IverticesAtElement(2, jel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            
            ivt = rhadapt%p_IverticesAtElement(4, jel)
            rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
          end if
          
          
        case(STATE_TRIA_GREENOUTER_LEFT)
          ! We are processing a green triangle. Here, we have to consider several
          ! cases. Thus, find out the state of the neighboring element JEL.
          jel    = rhadapt%p_IneighboursAtElement(2, iel)
          jstate = redgreen_getState2D(rhadapt, jel)

          ! What state is element JEL
          select case(jstate)
          case(STATE_TRIA_GREENOUTER_RIGHT)
            ! Element IEL and JEL are the result of a Tria2Tria refinement,
            ! whereby triangle IEL is located left to element JEL. 
            ! We can safely convert both elements into the macro element
            ! and perform regular refinement afterwards.

            ! We need to mark the edges of the elements adjacent 
            ! to IEL and JEL for subdivision. 
            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)
            
            ! The same procedure must be applied to the neighbor of element JEL
            iel1 = rhadapt%p_IneighboursAtElement(1, jel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(jel, iel1)
            
            ! Physically convert the two elements IEL and JEL into four similar triangles
            call convert_Tria2Tria(rhadapt, iel, jel,&
                                   rcollection, fcb_hadaptCallback)

            ! We modified some elements in this iteration
            bisModified = .true.
         
   
            ! The new elements NEL0+1 and NEL0+2 have zero markers by construction.
            ! The markers for the modified elements IEL and JEL need to be adjusted.
            p_Imarker(iel) = 0
            p_Imarker(jel) = 0

            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
            if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)
            
            iel1 = rhadapt%p_IneighboursAtElement(3, jel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, jel)
            if (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),3)

            ! If we are in the first iteration which is caused by elements
            ! marked for refinement due to accuracy reasons, then "lock" 
            ! the four midpoint vertices which must not be deleted.
            if (bisFirst) then
              ivt = rhadapt%p_IverticesAtElement(2, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

              ivt = rhadapt%p_IverticesAtElement(3, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

              ivt = rhadapt%p_IverticesAtElement(2, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end if

          
          case(STATE_TRIA_GREENINNER)
            ! Element IEL and JEL are the result of a Quad3Tria refinement, whereby
            ! element JEL is the inner triangle and IEL is its left neighbor.

            ! We need to mark the edges of the elements adjacent to IEL,
            ! JEL and KEL for subdivision. Let us start with the third neighbor of IEL.
            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)

            ! The same procedure must be applied to the second neighbor of element JEL
            iel1 = rhadapt%p_IneighboursAtElement(2, jel)
            iel2 = rhadapt%p_ImidneighboursAtElement(2, jel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(jel, iel1)
            
            ! And again, the same procedure must be applied to the first neighbor of 
            ! element KEL which is the first neighbor of JEL, whereby KEL needs to 
            ! be found in the dynamic data structure first
            kel = rhadapt%p_IneighboursAtElement(1, jel)
            
            ! Ok, now we can proceed to its first neighbor
            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(kel, iel1)
            
            ! Physically convert the three elements IEL,JEL and KEL
            ! into four similar quadrilaterals
            call convert_Quad3Tria(rhadapt, iel, kel, jel,&
                                   rcollection, fcb_hadaptCallback)

            ! We modified some elements in this iteration
            bisModified = .true.
            

            ! The new element NEL0+1 has zero marker by construction
            ! but that of JEL must be nullified. The markers for the
            ! modified triangles also need to be adjusted.
            p_Imarker(iel) = ibset(0,0)
            p_Imarker(jel) = ibset(0,0)
            p_Imarker(kel) = ibset(0,0)

            ! The first edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
            if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)

            ! The fourth edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(4, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
            if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)

            ! If we are in the first iteration which is caused by elements
            ! marked for refinement due to accuracy reasons, then "lock" 
            ! the four midpoint vertices which must not be deleted.
            if (bisFirst) then
              ivt = rhadapt%p_IverticesAtElement(2, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(4, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(3, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(4, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end if

           
          case(STATE_TRIA_OUTERINNER)
            ! Element IEL and JEL are the result of a Quad4Tria refinement, whereby
            ! element JEL is the inner triangles  and IEL is its right neighbor.
            kel = rhadapt%p_IneighboursAtElement(2, jel)
            lel = rhadapt%p_IneighboursAtElement(3, jel)

            ! Mark the edge of the element adjacent to IEL for subdivision
            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)
            
            ! Mark the edge of the element adjacent to LEL for subdivision
            iel1 = rhadapt%p_IneighboursAtElement(1, lel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(lel, iel1)

            ! Physically convert the four triangles into four quadrilaterals
            call convert_Quad4Tria(rhadapt, iel, kel, lel, jel,&
                                   rcollection, fcb_hadaptCallback)
            
            ! We modified some elements in this iteration
            bisModified = .true.

            
            ! All four elements have to be converted from triangles to quadrilaterals.
            p_Imarker(iel) = ibset(0,0)
            p_Imarker(jel) = ibset(0,0)
            p_Imarker(kel) = ibset(0,0)
            p_Imarker(lel) = ibset(0,0)
            
            ! The first edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
            if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),1)

            ! The fourth edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(4, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
            if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)

            ! The first edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
            if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)

            ! The fourth edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(4, lel)
            iel2 = rhadapt%p_ImidneighboursAtElement(4, lel)
            if (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),4)

            
            ! If we are in the first iteration which is caused by elements
            ! marked for refinement due to accuracy reasons, then "lock" 
            ! the four midpoint vertices which must not be deleted.
            if (bisFirst) then
              ivt = rhadapt%p_IverticesAtElement(2, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(3, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, kel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, lel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end if


          case DEFAULT
            call output_line('Invalid element state!',&
                OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
            call sys_halt()
          end select


        case(STATE_TRIA_GREENOUTER_RIGHT)
          ! We are processing a green triangle. Here, we have to consider several cases.
          ! First, let us find out the state of the neighboring element JEL.
          jel    = rhadapt%p_IneighboursAtElement(2, iel)
          jstate = redgreen_getState2D(rhadapt, jel)
          
          ! What state is element JEL
          select case(jstate)
          case(STATE_TRIA_GREENOUTER_LEFT)
            ! Element IEL and JEL are the result of a Tria2Tria refinement, whereby
            ! triangle IEL is located right to element JEL. We can safely convert both
            ! elements into one and perform regular refinement afterwards.
            
            ! We need to mark the edges of the elements 
            ! adjacent to IEL and JEL for subdivision.
            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)
            
            ! The same procedure must be applied to the neighbor of element JEL
            iel1 = rhadapt%p_IneighboursAtElement(3, jel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, jel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(jel, iel1)
            
            ! Physically convert the two elements IEL and JEL into four similar triangles
            call convert_Tria2Tria(rhadapt, jel, iel,&
                                   rcollection, fcb_hadaptCallback)
            
            ! We modified some elements in this iteration
            bisModified = .true.

            
            ! The new elements NEL0+1 and NEL0+2 have zero markers by construction.
            ! The markers for the modified elements IEL and JEL need to be adjusted.
            p_Imarker(iel) = 0
            p_Imarker(jel) = 0
            
            iel1 = rhadapt%p_IneighboursAtElement(1, jel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, jel)
            if (ismarked_edge(iel1, iel2, jel)) p_Imarker(jel) = ibset(p_Imarker(jel),1)
            
            iel1 = rhadapt%p_IneighboursAtElement(3, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, iel)
            if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),3)
            
            ! If we are in the first iteration which is caused by elements
            ! marked for refinement due to accuracy reasons, then "lock" 
            ! the four midpoint vertices which must not be deleted.
            if (bisFirst) then
              ivt = rhadapt%p_IverticesAtElement(2, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))

              ivt = rhadapt%p_IverticesAtElement(3, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(3, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end if


          case(STATE_TRIA_GREENINNER)
            ! Element IEL and JEL are the result of a Quad3Tria refinement, whereby
            ! element JEL is the inner triangle and IEL is its left neighbor.

            ! We need to mark the edges of the elements adjacent to IEL, JEL and
            ! KEL for subdivision. Let us start with the firth neighbor of IEL.
            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)

            ! The same procedure must be applied to the second neighbor of element JEL
            iel1 = rhadapt%p_IneighboursAtElement(2, jel)
            iel2 = rhadapt%p_ImidneighboursAtElement(2, jel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(jel, iel1)

            ! And again, the same procedure must be applied to the third neighbor of 
            ! element KEL which is the third neighbor of JEL.
            kel  = rhadapt%p_IneighboursAtElement(3, jel)
            iel1 = rhadapt%p_IneighboursAtElement(3, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, kel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(kel, iel1)

            ! Physically convert the three elements IEL,JEL and KEL
            ! into four similar quadrilaterals
            call convert_Quad3Tria(rhadapt, kel, iel, jel,&
                                   rcollection, fcb_hadaptCallback)
            
            ! We modified some elements in this iteration
            bisModified = .true.
            
            
            ! The new element NEL0+1 has zero marker by construction
            ! but that of JEL must be nullified. The markers for the
            ! modified triangles also need to be adjusted.
            p_Imarker(iel) = ibset(0,0)
            p_Imarker(jel) = ibset(0,0)
            p_Imarker(kel) = ibset(0,0)

            ! The first edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
            if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)

            ! The fourth edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(4, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
            if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),4)

            ! If we are in the first iteration which is caused by elements
            ! marked for refinement due to accuracy reasons, then "lock" 
            ! the four midpoint vertices which must not be deleted.
            if (bisFirst) then
              ivt = rhadapt%p_IverticesAtElement(2, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(3, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(4, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, kel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(4, kel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end if

            
          case(STATE_TRIA_OUTERINNER)
            ! Element IEL and JEL are the result of a Quad4Tria refinement, whereby
            ! element JEL is the inner triangles  and IEL is its left neighbor.
            kel = rhadapt%p_IneighboursAtElement(2, jel)
            lel = rhadapt%p_IneighboursAtElement(1, jel)

            ! Mark the edge of the element adjacent to IEL for subdivision
            iel1 = rhadapt%p_IneighboursAtElement(1, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, iel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(iel, iel1)

            ! Mark the edge of the element adjacent to LEL for subdivision
            iel1 = rhadapt%p_IneighboursAtElement(3, lel)
            iel2 = rhadapt%p_ImidneighboursAtElement(3, lel)
            if (iel1*iel2 .ne. 0 .and. iel1 .eq. iel2) call mark_edge(lel, iel1)

            ! Physically convert the four triangles into four quadrilaterals
            call convert_Quad4Tria(rhadapt, lel, kel, iel, jel,&
                                   rcollection, fcb_hadaptCallback)

            ! We modified some elements in this iteration
            bisModified = .true.
            

            ! All four elements have to be converted from triangles to quadrilaterals.
            p_Imarker(iel) = ibset(0,0)
            p_Imarker(jel) = ibset(0,0)
            p_Imarker(kel) = ibset(0,0)
            p_Imarker(lel) = ibset(0,0)

            ! The first edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(1, lel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, lel)
            if (ismarked_edge(iel1, iel2, lel)) p_Imarker(lel) = ibset(p_Imarker(lel),1)

            ! The fourth edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(4, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(4, kel)
            if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),4)

            ! The first edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(1, kel)
            iel2 = rhadapt%p_ImidneighboursAtElement(1, kel)
            if (ismarked_edge(iel1, iel2, kel)) p_Imarker(kel) = ibset(p_Imarker(kel),1)

            ! The fourth edge is only marked if it is also marked from the adjacent element
            iel1 = rhadapt%p_IneighboursAtElement(4, iel)
            iel2 = rhadapt%p_ImidneighboursAtElement(4, iel)
            if (ismarked_edge(iel1, iel2, iel)) p_Imarker(iel) = ibset(p_Imarker(iel),4)

            ! If we are in the first iteration which is caused by elements
            ! marked for refinement due to accuracy reasons, then "lock" 
            ! the four midpoint vertices which must not be deleted.
            if (bisFirst) then
              ivt = rhadapt%p_IverticesAtElement(2, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(3, iel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, jel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, kel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
              
              ivt = rhadapt%p_IverticesAtElement(2, lel)
              rhadapt%p_IvertexAge(ivt) = -abs(rhadapt%p_IvertexAge(ivt))
            end if


          case DEFAULT
            call output_line('Invalid element state!',&
                OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
            call sys_halt()
          end select

          
        case DEFAULT
          call output_line('Invalid element state!',&
              OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
          call sys_halt()
        end select
100     continue
        
        
        !-----------------------------------------------------------------------
        ! Loop over all adjacent cells of element IEL
        !-----------------------------------------------------------------------
        adjacent: do ive = 1, nve

          ! If element IEL is adjacent to two different elements along one edge
          ! then ignore this edge. This situation can arise, if the element IEL
          ! is adjacent to a green element JEL which has been converted previously,
          ! so that element IEL has two neighbors along the edge, i.e., IEL and one 
          ! new element number >NEL0
          if (rhadapt%p_IneighboursAtElement(ive, iel) .ne. &
              rhadapt%p_ImidneighboursAtElement(ive, iel)) cycle adjacent
          
          ! If the edge shared by element IEL and its neighbor JEL has been 
          ! marked for refinement and JEL is not outside of the domain, i.e.,
          ! element IEL is located at the boundary, then proceed to element JEL.
          if (btest(p_Imarker(iel), ive)) then
            
            ! Check if the current edge is located at the 
            ! boundary, then nothing needs to be done
            jel = rhadapt%p_IneighboursAtElement(ive, iel)
            if (jel .eq. 0) cycle adjacent
            
            ! Get number of vertices per element
            mve = hadapt_getNVE(rhadapt, jel)
            
            ! Are we triangular or quadrilateral element?
            select case(mve)
            case(TRIA_NVETRI2D)
              p_Imarker(jel) = ibclr(p_Imarker(jel),0)

            case(TRIA_NVEQUAD2D)
              p_Imarker(jel) = ibset(p_Imarker(jel),0)

            case DEFAULT
              call output_line('Invalid number of vertices per element!',&
                  OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
              call sys_halt()
            end select

            ! Now, we need to find the local position of element IEL in the
            ! adjacency list of the nieghboring element JEL
            do jve = 1, mve
              if (rhadapt%p_IneighboursAtElement(jve, jel) .eq. iel) exit
            end do

            if (jve > mve) then
              call output_line('Unable to find element!',&
                  OU_CLASS_ERROR,OU_MODE_STD,'redgreen_mark_refinement2D')
              call sys_halt()
            end if

            ! If the edge is already marked for refinement then we can
            ! guarantee conformity for the edge shared by IEL and JEL.
            ! Otherwise, this edge needs to be marked "looking" from JEL
            if (.not.btest(p_Imarker(jel), jve)) then
              p_Imarker(jel) = ibset(p_Imarker(jel), jve)

              ! This element should not be considered in this iteration.
              ! It is therefore pre-marked for the next iteration.
              if (p_Imodifier(jel) .ne. imodifier) p_Imodifier(jel)= -imodifier

              ! We modified some elements in this iteration
              bisModified = .true.
            end if

          end if
        end do adjacent
      end do element
      
      
      ! Note that the number of elements (and vertices) may have 
      ! changed due to conversion of green into red elements. 
      
      ! Hence, adjust dimensions.
      rhadapt%NEL0 = rhadapt%NEL
      rhadapt%NVT0 = rhadapt%NVT

      !-------------------------------------------------------------------------
      ! We don't want to have elements with two and/or three divided edges, 
      ! aka, blue refinement for triangles and quadrilaterals, respectively.
      ! Therefore, these elements are filtered and marked for red refinement.
      !-------------------------------------------------------------------------
      noblue: do iel = 1, rhadapt%NEL0
        if (p_Imodifier(iel)*imodifier .eq. 0) cycle noblue
        
        ! What type of element are we?
        select case(p_Imarker(iel))
        case(MARK_REF_TRIA3TRIA_12,&
             MARK_REF_TRIA3TRIA_13,&
             MARK_REF_TRIA3TRIA_23)
          ! Blue refinement for triangles is not allowed.
          ! Hence, mark triangle for red refinement
          p_Imarker(iel)      =  MARK_REF_TRIA4TRIA
          p_Imodifier(iel)    = -imodifier
          bisModified         =  .true.
          rhadapt%increaseNVT =  rhadapt%increaseNVT+1

          
        case(MARK_REF_QUADBLUE_123,&
             MARK_REF_QUADBLUE_412,&
             MARK_REF_QUADBLUE_341,&
             MARK_REF_QUADBLUE_234)
          ! Blue refinement for quadrilaterals is not allowed. 
          ! Hence, mark quadrilateral for red refinement
          p_Imarker(iel)      =  MARK_REF_QUAD4QUAD
          p_Imodifier(iel)    = -imodifier
          bisModified         =  .true.
          rhadapt%increaseNVT =  rhadapt%increaseNVT+2


        case DEFAULT
          p_Imodifier(iel) = (p_Imodifier(iel)-imodifier)/2
        end select
      end do noblue
      
      ! Reverse modifier
      imodifier = -imodifier

      ! Once we arrived at this point, the first iteration is done
      bisFirst = .false.
    end do conform


    ! Loop over all elements and increase the number of vertices according
    ! to the number of quadrilaterals which are marked for red refinement.
    do iel = 1, size(p_Imarker, 1)
      if (p_Imarker(iel) .eq. MARK_REF_QUAD4QUAD) then
        rhadapt%increaseNVT = rhadapt%increaseNVT+1
      end if
    end do
    
    ! Free auxiliary storage
    call storage_free(h_Imodifier)

  contains

    ! Here, the real working routines follow.

    !**************************************************************
    ! For a given element IEL, mark the edge that connects IEL 
    ! to its neighbor JEL in the marker array at position JEL
    
    subroutine mark_edge(iel, jel)

      integer(PREC_ELEMENTIDX), intent(IN) :: iel
      integer(PREC_ELEMENTIDX), intent(IN) :: jel

      ! local variables
      integer :: ive,nve

      ! Get number of vertices per element
      nve = hadapt_getNVE(rhadapt, jel)
      
      ! Find local position of element IEL in adjacency list of JEL
      select case(nve)
      case(TRIA_NVETRI2D)
        ! Triangular elements
        do ive = 1, nve
          if (rhadapt%p_IneighboursAtElement(ive, jel) .eq. iel) then
            p_Imarker(jel) = ibclr(ibset(p_Imarker(jel), ive),0)
            bisModified    =.true.
            if (p_Imodifier(jel) .ne. imodifier) p_Imodifier(jel) = -imodifier
            return
          end if
        end do

      case(TRIA_NVEQUAD2D)
        ! Quadrilateral element
        do ive = 1, nve
          if (rhadapt%p_IneighboursAtElement(ive, jel) .eq. iel) then
            p_Imarker(jel) = ibset(ibset(p_Imarker(jel), ive),0)
            bisModified    =.true.
            if (p_Imodifier(jel) .ne. imodifier) p_Imodifier(jel) = -imodifier
            return
          end if
        end do

      case DEFAULT
        call output_line('Invalid number of vertices per element!',&
            OU_CLASS_ERROR,OU_MODE_STD,'mark_edge')
        call sys_halt()
      end select
    end subroutine mark_edge

    !**************************************************************
    ! For a given element IEL, check if the edge that connects IEL
    ! with its adjacent element JEL is marked

    function ismarked_edge(iel, ielmid, jel) result (bismarked)

      integer(PREC_ELEMENTIDX), intent(IN) :: iel,ielmid,jel
      logical :: bismarked

      ! local variables
      integer :: ive,nve

      ! Are we at the boundary?
      if (iel*ielmid .eq. 0) then
        bismarked = .false.
        return
      elseif(iel .ne. ielmid) then
        bismarked = .true.
        return
      end if
      
      ! Loop over all edges of element IEL and try to find neighbor JEL
      do ive = 1, hadapt_getNVE(rhadapt, iel)
        if (rhadapt%p_IneighboursAtElement(ive, iel)    .eq. jel .or.&
            rhadapt%p_ImidneighboursAtElement(ive, iel) .eq. jel) then
          bismarked = btest(p_Imarker(iel), ive)
          return
        end if
      end do
      
      call output_line('Unable to find common egde!',&
          OU_CLASS_ERROR,OU_MODE_STD,'ismarked_edge')
      call sys_halt()
    end function ismarked_edge
  end subroutine redgreen_mark_refinement2D

  ! ***************************************************************************

!<function>

  pure function redgreen_getState2D(rhadapt, iel) result(istate)

!<description>
    ! This function encodes the state of an element iel in 2D.
    ! Note: The state of an element is solely determined from the 
    ! age information of its surrounding vertices.
!</description>

!<input>
    ! Adaptive data structure
    type(t_hadapt), intent(IN)      :: rhadapt

    ! Number of element for which state should be computed
    integer(PREC_ELEMENTIDX), intent(IN) :: iel
!</input>

!<result>
    ! State of element
    integer :: istate
!</result>
!</function>

    integer, dimension(TRIA_MAXNVE) :: IvertexAge

    ! Do we have quadrilaterals in the triangulation?
    if (rhadapt%InelOfType(TRIA_NVEQUAD2D) .eq. 0) then
      
      ! There are no quadrilaterals in the current triangulation.
      IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
          rhadapt%p_IverticesAtElement(1:TRIA_NVETRI2D,iel))
      istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
      
    else
      
      ! There are quadrilaterals and possible also triangles in
      ! the current triangulation. If the last entry of the vertices
      ! at element list is nonzero then the current element is a 
      ! quadrilateral. Otherwise, we are dealing with  a triangle
      if (rhadapt%p_IverticesAtElement(TRIA_NVEQUAD2D,iel) .eq. 0) then
        IvertexAge(1:TRIA_NVETRI2D) = rhadapt%p_IvertexAge(&
            rhadapt%p_IverticesAtElement(1:TRIA_NVETRI2D,iel)) 
        istate = redgreen_getStateTria(IvertexAge(1:TRIA_NVETRI2D))
      else
        IvertexAge(1:TRIA_NVEQUAD2D) = rhadapt%p_IvertexAge(&
            rhadapt%p_IverticesAtElement(1:TRIA_NVEQUAD2D,iel)) 
        istate = redgreen_getStateQuad(IvertexAge(1:TRIA_NVEQUAD2D))
      end if
      
    end if
  end function redgreen_getState2D

  ! ***************************************************************************

!<function>

  pure function redgreen_getStateTria(IvertexAge) result(istate)

!<description>
    ! This pure functions encodes the state of the given triangle
    ! into a unique positive integer value. If the state cannot
    ! be determined uniquely, then the position of the youngest
    ! vertex is encoded but with negative sign.
!</description>

!<input>
    ! Age of the three vertices
    integer, dimension(TRIA_NVETRI2D), intent(IN) :: IvertexAge
!</input>

!<result>
    ! State of the triangle
    integer :: istate
!</result>
!</function>

    ! local variables
    integer :: ive,ipos

    ! Reset state
    istate = 0
    
    ! Check if triangle belongs to the initial triangulation. Then nothing
    ! needs to be done. Otherwise, perform additional checks
    if (sum(abs(IvertexAge)) .ne. 0) then
      
      ! Check if any two vertices have the same age and mark that edge.
      ! In addition, determine the largest age and its position
      ipos = 1
      do ive = 1, TRIA_NVETRI2D
        if (abs(IvertexAge(ive)) .eq. abs(IvertexAge(mod(ive, TRIA_NVETRI2D)+1))) then
          ! Edge connects two nodes with the same age
          istate = ibset(istate, ive)
        elseif (abs(IvertexAge(ive)) .gt. abs(IvertexAge(ipos))) then
          ! The age of the "next" node is larger, so than it might be the largest
          ipos = ive
        end if
      end do
      
      ! If ISTATE=0, then there must be one youngest vertex. Its local number
      ! is returned but with negative sign. In this case the state of the
      ! triangle cannot be uniquely determined and additional checks are required.
      !
      ! Otherwise, either all nodes have the same age (1110 : inner red triangle)
      ! or exactly two nodes have the same age. In the latter case, we must check
      ! if the opposite vertex is the youngest one in the triple of nodes.
      select case(istate)
      case(STATE_TRIA_ROOT)
        istate = -ibset(0, ipos)

      case(STATE_TRIA_OUTERINNER1)
        if (ipos .eq. 3) istate = -ibset(0, ipos)

      case(STATE_TRIA_OUTERINNER)
        if (ipos .eq. 1) istate = -ibset(0, ipos)

      case(STATE_TRIA_OUTERINNER2)
        if (ipos .eq. 2) istate = -ibset(0, ipos)

      end select
    end if

    ! Mark state for triangle
    istate = ibclr(istate,0)
  end function redgreen_getStateTria

  ! ***************************************************************************

!<function>

  pure function redgreen_getStateQuad(IvertexAge) result(istate)

!<description>
    ! This pure functions encodes the state of the given quadrilateral
    ! into a unique integer value
!</description>

!<input>
    ! Age of the four vertices
    integer, dimension(TRIA_NVEQUAD2D), intent(IN) :: IvertexAge
!</input>

!<result>
    ! State of the quadrilateral
    integer :: istate
!</result>
!</function>

    ! local variables
    integer :: ive

    ! Reset state
    istate = 0

    ! Check if quadrilateral belongs to the initial triangulation. Then nothing
    ! needs to be done. Otherwise, perform additional checks.
    if (sum(abs(IvertexAge)) .ne. 0) then
      
      ! Check if any two vertices have the same age and mark that edge.
      ! After this procedure, ISTATE must be different from 0 and a unique
      ! state for the quadrilateral has been determined.
      do ive = 1, TRIA_NVEQUAD2D
        if (abs(IvertexAge(ive)) .eq. abs(IvertexAge(mod(ive, TRIA_NVEQUAD2D)+1))) then
          ! Edge connects two nodes with the same age
          istate = ibset(istate,ive)
        end if
      end do
    end if

    ! Mark state for quadrilateral
    istate = ibset(istate,0)
  end function redgreen_getStateQuad

  ! ***************************************************************************

!<function>
  
  pure function redgreen_rotateState2D(istate, irotate) result(inewstate)
    
!<description>
    ! This pure function "rotates" a given state
!</description>

!<input>
    ! Current state
    integer, intent(IN) :: istate

    ! Positive rotation
    integer, intent(IN) :: irotate
!</input>

!<result>
    ! New state
    integer :: inewstate
!</result>
!</function>

    ! Are we triangular or quadrilateral?
    if (btest(istate,0)) then
      inewstate = ishft(istate, -1)
      inewstate = ishftc(inewstate, irotate, 4)
      inewstate = ishft(inewstate, 1)
      inewstate = ibset(inewstate, 0)
    else
      inewstate = ishft(istate, -1)
      inewstate = ishftc(inewstate, irotate, 3)
      inewstate = ishft(inewstate, 1)
      inewstate = ibclr(inewstate, 0)
    end if
  end function redgreen_rotateState2D

end module hadaptaux2d
