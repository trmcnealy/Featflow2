  interface

!<subroutine>

  subroutine fcb_calcOperatorNodeSys(rgroupFEMSet, rx, rmatrix, dscale, bclear,&
      cconstrType, fcb_calcMatrixDiagSys_sim, rcollection, rafcstab)

    use afcstabbase
    use collection
    use fsystem
    use groupfembase
    use linearsystemblock

!<description>
    ! This subroutine assembles the discrete operator for systems of
    ! equations using the group finite element formulation by Fletcher.
!</description>

!<input>
    ! Group finite element set
    type(t_groupFEMSet), intent(in) :: rgroupFEMSet

    ! Vector on which the matrix entries may depend.
    type(t_vectorBlock), intent(in) :: rx

    ! Scaling factor
    real(DP), intent(in) :: dscale

    ! Switch for matrix assembly
    ! TRUE  : clear matrix before assembly
    ! FLASE : assemble matrix in an additive way
    logical, intent(in) :: bclear

    ! OPTIONAL: One of the GFEM_MATC_xxxx constants that allow to
    ! specify the matrix construction method. If not specified,
    ! GFEM_MATC_CONSISTENT is used.
    integer, intent(in), optional :: cconstrType

    ! OPTIONAL: callback function to compute local matrices
    include 'intf_calcMatrixDiagSys_sim.inc'
    optional :: fcb_calcMatrixDiagSys_sim
!</input>

!<inputoutput>
    ! Global operator
    type(t_matrixBlock), intent(inout) :: rmatrix

    ! OPTIONAL: collection structure
    type(t_collection), intent(inout), optional :: rcollection

    ! OPTIONAL: stabilisation structure
    type(t_afcstab), intent(inout), optional :: rafcstab
!</inputoutput>
!</subroutine>

  end subroutine fcb_calcOperatorNodeSys

  end interface
