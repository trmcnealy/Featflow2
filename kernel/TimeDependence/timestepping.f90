!##############################################################################
!# ****************************************************************************
!# <name> timestepping </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains a realisation of 1D time-stepping schemes used
!# for the time discretisation of PDE`s. Examples for this are Explicit Euler,
!# Crank Nicolson or the Fractional Step Theta scheme.
!#
!# The basic time stepping is governed by the structure t_explicitTimeStepping,
!# which is maintained by the routines in this module. It contains information
!# about the length of the next time step, number of current time step,
!# current simulation time, etc.
!#
!# The following routines can be found here:
!#
!# 1.) timstp_init
!#     -> Initialise time stepping structure for advancing in time
!#
!# 2.) timstp_nextSubstep
!#     -> Go to next time (sub-)step
!#
!# 3.) timstp_nextSubstepTime
!#     -> Increase the simulation time without updating the weights
!#
!# 4.) timstp_nextSubstepWeights
!#     -> Set the weights for the next substep without updating the time
!#
!# 5.) timstp_getOrder
!#     -> Retrieves the order of the time error that is expected from a
!#        defined time stepping algorithm.
!#
!# 6.) timstp_setBaseSteplength
!#     Modify the base step length of a time stepping scheme
!#
!# How to use this module?
!#
!# Well, that is simple. It is like this:
!#
!# <code>
!#    TYPE(t_explicitTimeStepping) :: tstepping
!#
!#    ! Initialise time stepping
!#    CALL timstp_init (tstepping,...)
!#
!#    DO istep = 1,#max number of time steps
!#
!#      ... (do some work at the current time tstepping%dcurrentTime)
!#
!#      ! Proceed to next time step
!#      CALL timstp_nextSubstep (tstepping)
!#
!#    END DO
!# </code>
!#
!# First initialise the time stepping scheme by timstp_init, then call
!# timstp_nextSubstep in a loop to proceed from time dcurrentTime
!# to time dcurrentTime+dtstep. That is all.
!#
!# The time stepping structure contains definitions for various constants that
!# are to be used in front of the different terms in the PDE. See the
!# documentation of t_explicitTimeStepping which constants are to be used
!# for what.
!#
!# Note: The timstp_nextSubstep routine increases the simulation time and
!#   updates the weights in one step. In some simulations, this has to be
!#   decoupled, e.g. when some things on the right hand side of a system
!#   must be assembled at timestep $t^n$ and some on timestep $t^{n+1}$.
!#   In this case, one can use timstp_nextSubstepTime and
!#   timstp_nextSubstepWeights. The usage is as follows:
!#
!# <code>
!#    TYPE(t_explicitTimeStepping) :: tstepping
!#
!#    ! Initialise time stepping
!#    CALL timstp_init (tstepping,...)
!#
!#    DO istep = 1,#max number of time steps
!#
!#      ... (do some assembly at the timestep $t^n$)
!#
!#      ! Increase the simulation time
!#      CALL timstp_nextSubstepTime (tstepping)
!#
!#      ... (do some assembly at the timestep $t^{n+1}$
!#
!#      ! Proceed to next time step. Increase step number and update weights.
!#      CALL timstp_nextSubstepWeights (tstepping)
!#
!#    END DO
!# </code>
!#
!# </purpose>
!##############################################################################

module timestepping

!$ use omp_lib
  use fsystem
  use genoutput

  implicit none

  private

!<constants>

!<constantblock description="Identifiers for time step schemes">

  ! Identifier for one step scheme (e.g. Explicit Euler)
  integer, parameter, public :: TSCHM_ONESTEP        = 0

  ! Identifier for classic fractional-step theta scheme
  integer, parameter, public :: TSCHM_FRACTIONALSTEP = 1

  ! Identifier for fractional-step theta scheme as proposed by Glowinski
  integer, parameter, public :: TSCHM_FS_GLOWINSKI   = 2

  ! Identifier for classic fractional-step theta scheme in DIRK context
  integer, parameter, public :: TSCHM_FS_DIRK        = 3

  ! Identifier for DIRK34L as proposed by Joachim Rang
  integer, parameter, public :: TSCHM_DIRK34La       = 4

  ! Identifier for another solution of the defining equations for DIRK34L
  integer, parameter, public :: TSCHM_DIRK34Lb       = 5

  ! Identifier for DIRK44L as proposed by Joachim Rang
  integer, parameter, public :: TSCHM_DIRK44L        = 6

!</constantblock>

!</constants>


!<types>

!<typeblock>

  ! Time stepping structure used in explicit time stepping schemes like
  ! explicit Euler, Crank Nicolson etc.
  ! The time stepping scheme is designed to discretise a rather general
  ! equation in time for a solution $u$ and a time variable $t$:
  !
  !               <tex> $$ u_t(x,t) + N(u(x,t)) = f(x,t) $$ </tex>
  !
  ! Given a time step $k$ and a time stepping scheme parameter $\theta$,
  ! this is discretised in as:
  ! <tex>
  !
  !  $$ (u_{n+1} - u_n) / k  +  \theta N(u_{n+1})
  !
  !    = -(1-\theta) N(u_n)  +  \theta f_{n+1}  +  (1-\theta) f_n $$
  !
  ! </tex>
  ! Now, regroup this equation with $u_{n+1}$ on the LHS and $u_n$ on the
  ! RHS and give the coefficients in front of all terms an appropriate
  ! name. Then the time stepping scheme realised by this structure yields:
  ! <tex>
  !
  ! $$ u_{n+1} + dweightMatrixLHS*N(u_n+1)
  !
  ! =  u_n + dweightMatrixRHS*N(u_n)  +  dweightNewRHS*f_{n+1}  +  dweightOldRHS*f_n $$
  !
  ! </tex>
  ! If the simulation has steady (in)homogenuous boundary conditions
  ! and a One-Step Theta-Scheme is used, the RHS build from f_{n+1}
  ! and f_n can be simplified. In this case:
  ! <tex>
  !  $$  dweightNewRHS*f_n+1  +  dweightOldRHS*f_n
  !    = dweightNewRHS*f_n    +  dweightOldRHS*f_n
  !    = dweightStationaryRHS*f_n                    $$
  ! </tex>

  type t_explicitTimeStepping

    ! Time step scheme identifier. One of the TSCHM_xxxx-constants.
    ! Usually TSCHM_ONESTEP for one step schemes
    integer                  :: ctimestepType = -1

    ! Current substep in time step scheme. Normally =1.
    ! For time stepping schemes with multiple substeps (Fractional Step),
    ! this counts the current substep 1..nsubsteps.
    integer                  :: isubstep

    ! Number of substeps of the time stepping scheme. Normally =1.
    ! For time stepping schemes with multiple substeps (Fractional Step),
    ! this is the number of substeps.
    integer                  :: nsubsteps

    ! Current simulation time, this structure represents
    real(DP)                 :: dcurrentTime

    ! Current simulation time of the macrostep. For standard $\theta$-schemes,
    ! there is dcurrentTime=dtimeMacrostep. For schemes with multiple substeps
    ! like Fractional-Step, dcurrentTime is the current time of the substep,
    ! while dtimeMacrostep saves the 'last' simulation time stamp with
    ! "isubstep=1", i.e. the beginning of the 'macrostep'.
    real(DP)                 :: dtimeMacrostep

    ! Length of the previous timestep. =0 if there was no previous timestep.
    real(DP)                 :: dtlaststep

    ! Length of the next time step
    real(DP)                 :: dtstep

    ! Main configuration parameter of the Theta scheme
    real(DP)                 :: dtheta

    ! Theta-scheme identifier for the substeps of the step.
    ! For 1-step schemes:
    !  =0: Forward Euler,
    !  =1: Backward Euler,
    !  =0.5: Crank Nicolson.
    ! Special values for Fractional Step.
    real(DP)                 :: dthStep

    ! Coefficients for diagonally implicit Runge-Kutta schemes
    real(DP), dimension(4,4) :: dcoeffA

    ! Coefficients for diagonally implicit Runge-Kutta schemes
    real(DP), dimension(4)   :: dcoeffB

    ! Coefficients for diagonally implicit Runge-Kutta schemes
    real(DP), dimension(4)   :: dcoeffC

    ! Simulation time in stage 1 of a diagonally implicit Runge-Kutta schemes, substeps
    ! determine their time using this base
    real(DP)                 :: dtimeDIRKstage1

    ! step length parameter for diagonally implicit Runge-Kutta schemes
    real(DP)                 :: dtau

    ! Weight in front of the matrix on the LHS.
    real(DP)                 :: dweightMatrixLHS

    ! Weight in front of the matrix on the RHS.
    real(DP)                 :: dweightMatrixRHS

    ! Weight to be used in the current time step for the "new" RHS $f_{n+1}$.
    real(DP)                 :: dweightNewRHS

    ! Weight to be used in the current time step for the "old" RHS $f_{n}$.
    real(DP)                 :: dweightOldRHS

    ! Weight to be used in the current time step if a stationary RHS is used
    ! (instead of a combination of dweightNewRHS and dweightOldRHS).
    real(DP)                 :: dweightStationaryRHS

    ! "Adjungated" parameter Theta` of the Theta scheme.
    ! Only used internally in the Fractional Step scheme.
    ! Standard = 0.0 = no fractional step used.
    real(DP)                 :: dthetaPrime = 0.0

    ! ALPHA-parameter for fractional step. Not used for standard
    ! time stepping scheme.
    ! Only used internally in the Fractional Step scheme.
    ! Standard = 0.0 = no fractional step used.
    real(DP)                 :: dalpha = 0.0

    ! BETA-parameter for fractional step. Not used for standard
    ! time stepping scheme.
    ! Only used internally in the Fractional Step scheme.
    ! Standard = 0.0 = no fractional step used.
    real(DP)                 :: dbeta = 0.0

    ! Length of the next time step when using an equidistant time
    ! discretisation.
    ! Only used internally.
    real(DP)                 :: dtstepFixed

  end type

  public :: t_explicitTimeStepping

!</typeblock>

!</types>

  public :: timstp_init
  public :: timstp_nextSubstep
  public :: timstp_nextSubstepTime
  public :: timstp_nextSubstepWeights
  public :: timstp_getOrder
  public :: timstp_setBaseSteplength

contains

  !****************************************************************************

!<function>

  pure integer function timstp_getOrder (rtstepScheme) result(iorder)

!<description>
  ! This routine analyses the time stepping structure rtstepScheme and returns
  ! the expected order of the time stepping algorithm that is described by
  ! that structure (e.g. 1 for explicit Euler, 2 for Crank Nicolson).
!</description>

!<input>
  ! Time stepping structure that describes an explicit time stepping scheme.
  type(t_explicitTimeStepping), intent(in) :: rtstepScheme
!</input>

!<result>
  ! Expected order of the time stepping algorithm described by rtstepScheme.
!</result>

!</function>

    select case (rtstepScheme%ctimestepType)
    case (TSCHM_DIRK44L)
      iorder = 4
    case (TSCHM_DIRK34La, TSCHM_DIRK34Lb)
      iorder = 3
    case (TSCHM_FRACTIONALSTEP, TSCHM_FS_GLOWINSKI, TSCHM_FS_DIRK)
      iorder = 2
    case (TSCHM_ONESTEP)
      if (rtstepScheme%dthStep .eq. 0.5_DP) then
        iorder = 2
      else
        iorder = 1
      end if
    case default
      ! Error case
      iorder = 0
    end select

  end function

  !****************************************************************************

!<subroutine>

  subroutine timstp_init (rtstepScheme, ctimestepType, dtime, dtstep, dtheta)

!<description>
  ! Initialisation of the time stepping scheme. This routine initialises
  ! the structure rtstepScheme for the discretisation in time.
!</description>

!<input>
  ! The type of time stepping to use. TSCHM_ONESTEP for a one-step scheme
  ! or TSCHM_FRACTIONALSTEP/TSCHM_FS_GLOWINSKI for Fractional Step or
  ! TSCHM_DIRK34La/b or TSCHM_DIRK44L for diagonally implicit, stiffly
  ! accurate, L-stable Runge-Kutta method of 3rd or 4th order
  integer, intent(in)    :: ctimestepType

  ! The initial simulational time.
  real(DP), intent(in)   :: dtime

  ! (Theoretical) Time step length of the simulation / 'base' step length of the
  ! time stepping scheme.
  ! Might vary from the real time step size by the type of the
  ! scheme. The real time step size is found in rtstepScheme%dtstep.
  real(DP), intent(in)   :: dtstep

  ! OPTIONAL: Theta scheme identifier.
  ! Only used for ctimestepType=TSCHM_ONESTEP.
  !  =0.0: Forward Euler
  !  =1.0: Backward Euler
  !  =0.5: Crank Nicolson
  ! Ignored for fractional-step and DIRK schemes. If not specified, dtheta=1.0 (Backward
  ! Euler) is used in one-step schemes.
  real(DP), intent(in), optional   :: dtheta
!</input>

!<output>
  ! The time stepping structure. This is initialised to perform the first
  ! time step.
  type(t_explicitTimeStepping), intent(out) :: rtstepScheme
!</output>

!</subroutine>

    real(DP) :: dtheta1,dthetp1,dalpha,dbeta

    dtheta1 = 1.0
    if (present(dtheta)) dtheta1 = dtheta

    ! Standard initialisation of the structure.
    rtstepScheme%isubstep         = 1
    rtstepScheme%dcurrentTime     = dtime
    rtstepScheme%dtimeMacrostep   = dtime
    rtstepScheme%dtlaststep       = 0.0_DP

    if (ctimestepType .eq. TSCHM_ONESTEP) then

      rtstepScheme%ctimestepType    = TSCHM_ONESTEP

      ! Standard time stepping. Here the parameters are a little bit
      ! easier to initialise.
      rtstepScheme%nsubsteps        = 1

      rtstepScheme%dtstep           = dtstep
      rtstepScheme%dtheta           = dtheta1
      rtstepScheme%dthStep          = dtstep * dtheta1

    else if (ctimestepType .eq. TSCHM_FRACTIONALSTEP) then

      rtstepScheme%ctimestepType    = TSCHM_FRACTIONALSTEP

      ! The classic FS-theta scheme consists of 3 substeps...
      rtstepScheme%nsubsteps        = 3

      ! ... and uses by theory 4 parameters:
      !
      !   Theta   = 1 - sqrt(2) / 2
      !   Theta`  = 1 - 2 * Theta
      !   alpha   = ( 1 - 2 * Theta ) / ( 1 - Theta )
      !   beta    = 1 - alpha
      !
      ! The parameter THETA in the DAT-file is ignored and replaced
      ! by a hard-coded setting.

      dtheta1 = 1.0_DP-sqrt(0.5_DP)
      dthetp1 = 1.0_DP-2.0_DP*dtheta1
      dalpha  = dthetp1 / (1.0_DP-dtheta1)
      dbeta   = dtheta1 / (1.0_DP-dtheta1)

      rtstepScheme%dtheta           = dtheta1
      rtstepScheme%dthetaPrime      = dthetp1
      rtstepScheme%dalpha           = dalpha
      rtstepScheme%dbeta            = dbeta

    else if (ctimestepType .eq. TSCHM_FS_GLOWINSKI) then

      rtstepScheme%ctimestepType    = TSCHM_FS_GLOWINSKI

      ! The new FS-theta scheme as proposed in
      !  @InBook{Glowinski2003,
      !     author    = {Roland Glowinski},
      !     title     = {Numerical Methods for Fluids, Part 3. Finite Element Methods
      !                  for Incompressible Viscous Flow},
      !     publisher = {North-Holland},
      !     address   = {Amsterdam},
      !     year      = {2003},
      !     series    = {Handbook of Numerical Analysis, edited by Ciarlet, Philippe G.
      !                  and Lions, Jacques Louis},
      !     volume    = {9},
      !     pages     = {3-1176},
      !     note      = {ISBN 0-444-51224-1}
      !  }
      ! and analysed in
      !  @ARTICLE{TurekRivkindHronGlowinski2006,
      !     author       = {Turek, Stefan and Rivkind, Ludmilla and Hron, Jaroslav and
      !                     Glowinski, Roland},
      !     title        = {Numerical study of a modified time-stepping theta-scheme for
      !                     incompressible flow simulations},
      !     journal      = {J. Sci. Comput.},
      !     year         = {2006},
      !     volume       = {28},
      !     number       = {2--3},
      !     pages        = {533--547},
      !     note         = {doi: 10.1007/s10915-006-9083-y},
      !  }
      ! consists of 3 substeps...
      rtstepScheme%nsubsteps        = 3

      ! ... and uses one main parameter:
      !
      !   Theta   = 1 - sqrt(2) / 2
      !
      ! The parameter THETA in the DAT-file is ignored and replaced
      ! by a hard-coded setting.
      dtheta1 = 1.0_DP-sqrt(0.5_DP)
      dthetp1 = 1.0_DP-2.0_DP*dtheta1

      rtstepScheme%dtstep           = dtstep
      rtstepScheme%dtheta           = dtheta1
      rtstepScheme%dthetaPrime      = dthetp1
      rtstepScheme%dthStep          = dtstep * dtheta1

    else if (ctimestepType .eq. TSCHM_FS_DIRK) then

      rtstepScheme%ctimestepType    = TSCHM_FS_DIRK

      ! The classic fractional-step theta scheme reinterpreted as DIRK scheme,
      ! see section 5 of
      !    @article{Rang2008747,
      !       author  = "J. Rang",
      !       title   = "Pressure corrected implicit $\theta$-schemes for %!" fix compiler
      !                  the incompressible Navier--Stokes equations",    %!" warnings
      !       journal = "Applied Mathematics and Computation",
      !       volume  = "201",
      !       number  = "1--2",
      !       pages   = "747--761",
      !       year    = "2008",
      !       issn    = "0096-3003",
      !       doi     = "http://dx.doi.org/10.1016/j.amc.2008.01.010",
      !       url  = "http://www.sciencedirect.com/science/article/pii/S0096300308000428",
      !       note    = "",
      !    }
      ! consists of 4 stages, but only 3 substeps...
      rtstepScheme%nsubsteps        = 3

      ! ... and uses several parameter:
      dtheta1 = 1.0_DP-sqrt(0.5_DP)
      dthetp1 = 1.0_DP-2.0_DP*dtheta1
      dalpha  = dthetp1 / (1.0_DP-dtheta1)
      dbeta   = dtheta1 / (1.0_DP-dtheta1)
      rtstepScheme%dcoeffA = &
       ! (0             0                        0                       0           )
       ! (\theta\beta   \theta\alpha             0                       0           )
       ! (\theta\beta   (\theta+\theta')\alpha   \theta'\beta            0           )
       ! (\theta\beta   (\theta+\theta')\alpha   (\theta+\theta')\beta   \theta\alpha)
       reshape( source = (/ &
                            ! first column
                            0.0_DP, &
                            dtheta1*dbeta, &
                            dtheta1*dbeta, &
                            dtheta1*dbeta, &
                            ! second column
                            0.0_DP, &
                            dtheta1*dalpha, &
                            (dtheta1+dthetp1)*dalpha, &
                            (dtheta1+dthetp1)*dalpha, &
                            ! third column
                            0.0_DP, &
                            0.0_DP, &
                            dthetp1*dbeta, &
                            (dtheta1+dthetp1)*dbeta, &
                            ! fourth column
                            0.0_DP, &
                            0.0_DP, &
                            0.0_DP, &
                            dtheta1*dalpha /), shape = (/ 4,4 /) )
      ! b_i = a_{4i}     (see \cite[p. 518, condition (H4)]{John2010514})
      rtstepScheme%dcoeffB = rtstepScheme%dcoeffA(4,:)
      ! c_i = \sum_{j=1}^i a_{ij}   (see \cite[p. 518]{John2010514})
      rtstepScheme%dcoeffC = &
           (/ 0.0_DP, &                 ! sum(rtstepScheme%dcoeffA(1,:))
              dtheta1, &                ! sum(rtstepScheme%dcoeffA(2,:))
              dtheta1+dthetp1, &        ! sum(rtstepScheme%dcoeffA(3,:))
              1.0_DP /)                 ! sum(rtstepScheme%dcoeffA(4,:))

    else if (ctimestepType .eq. TSCHM_DIRK34La) then

      rtstepScheme%ctimestepType    = TSCHM_DIRK34La

      ! The DIRK34L scheme as proposed in section 4.1 of
      !  @TechReport{Rang200702,
      !     author      = {Rang, Joachim},
      !     title       = {Design of {DIRK} schemes for solving the
      !                    {N}avier--{S}tokes equations},
      !     institution = {Institute of Scientific Computing},
      !     address     = {Technical University Braunschweig, Brunswick, Germany},
      !     year        = {2007},
      !     month       = feb,
      !     url         = {http://www.digibib.tu-bs.de/?docid=00020655},
      !     note        = {Informatikbericht Nr. 2007-02},
      !  }
      ! and compared to other time-stepping schemes in
      !  @article{John2010514,
      !     author  = "Volker John and Joachim Rang",
      !     title   = "Adaptive time step control for the incompressible
      !                {N}avier--{S}tokes equations",
      !     journal = "Computer Methods in Applied Mechanics and Engineering ",
      !     volume  = "199",
      !     number  = "9--12",
      !     pages   = "514--524",
      !     year    = "2010",
      !     note    = "",
      !     issn    = "0045-7825",
      !     doi     = "http://dx.doi.org/10.1016/j.cma.2009.10.005",
      !     url    = "http://www.sciencedirect.com/science/article/pii/S0045782509003417",
      !  }
      ! consists of 4 stages, but only 3 substeps...
      rtstepScheme%nsubsteps        = 3

      ! ... and uses several parameter:
      rtstepScheme%dcoeffA = &
       ! see \cite[p. 14]{Rang200702}:
       !
       ! (0                      0                  0                   0                )
       ! (0.158983899988677      0.158983899988677  0                   0                )
       ! (1-1.072..-0.158..      1.07248627073437   0.158983899988677   0                )
       ! (1-0.76..-0.09..-0.15.. 0.7685298292769537 0.0966483609791597  0.158983899988677)
       !
       ! Note: the values 0.1558983899988677 and 0.09666483609791597 given in the paper
       !       are wrong as does prove a test where the coefficients are inserted into the
       !       four defining equations B(2), B(3), \hat{B}(2) and R(\infty) on page 15 of
       !       said paper.
       reshape( source = (/ &
                            ! first column
                            0.0_DP, &
                            0.158983899988677_DP, &
                            1.0_DP - 0.158983899988677_DP  - 1.07248627073437_DP, &
                            1.0_DP - 0.7685298292769537_DP - 0.0966483609791597_DP &
                                   - 0.158983899988677_DP, &
                            ! second column
                            0.0_DP, &
                            0.158983899988677_DP, &
                            1.07248627073437_DP, &
                            0.7685298292769537_DP, &
                            ! third column
                            0.0_DP, &
                            0.0_DP, &
                            0.158983899988677_DP, &
                            0.0966483609791597_DP, &
                            ! fourth column
                            0.0_DP, &
                            0.0_DP, &
                            0.0_DP, &
                            0.158983899988677_DP /), shape = (/ 4,4 /) )
      ! b_i = a_{4i}     (see \cite[p. 518, condition (H4)]{John2010514})
      rtstepScheme%dcoeffB = rtstepScheme%dcoeffA(4,:)
      ! c_i = \sum_{j=1}^i a_{ij}   (see \cite[p. 518]{John2010514})
      rtstepScheme%dcoeffC = &
           (/ 0.0_DP, &                 ! sum(rtstepScheme%dcoeffA(1,:))
              0.317967799977354_DP, &   ! sum(rtstepScheme%dcoeffA(2,:))
              1.0_DP, &                 ! sum(rtstepScheme%dcoeffA(3,:))
              1.0_DP /)                 ! sum(rtstepScheme%dcoeffA(4,:))

    else if (ctimestepType .eq. TSCHM_DIRK34Lb) then

      rtstepScheme%ctimestepType    = TSCHM_DIRK34Lb

      ! The definint equations of the DIRK34L scheme as proposed in section 4.1 of
      !  @TechReport{Rang200702,
      !     author      = {Rang, Joachim},
      !     title       = {Design of {DIRK} schemes for solving the
      !                    {N}avier--{S}tokes equations},
      !     institution = {Institute of Scientific Computing},
      !     address     = {Technical University Braunschweig, Brunswick, Germany},
      !     year        = {2007},
      !     month       = feb,
      !     url         = {http://www.digibib.tu-bs.de/?docid=00020655},
      !     note        = {Informatikbericht Nr. 2007-02},
      !  }
      ! have a second viable solution not presented in said paper. These equations are
      !     a22*(1-2*a42-a22)+(2*a32-1)*a43 = 0
      !                       2*a32*a22+a22 = 1/2
      !                   2*a22*a42+a43+a22 = 1/2
      !                 4*a22^2*a42+a43+a22 = 1/3
      ! As DIRK34L it consists of 4 stages, but only 3 substeps...
      rtstepScheme%nsubsteps        = 3

      ! ... and uses several parameter. Matrix A of the Butcher table has he following
      ! entries:
      rtstepScheme%dcoeffA = &
       !  A := Matrix([[0, 0, 0, 0],
       !               [a22, a22, 0, 0],
       !               [1-a32-a22, a32, a22, 0],
       !               [1-a42-a43-a22, a42, a43, a22]])
       !     =
       ! (0                      0                  0                   0            )
       ! (0.4358665214           0.4358665214       0                   0            )
       ! (1-.073..-0.435..       0.0735700902       0.4358665214        0            )
       ! (1-1.49..+1.23..-0.43.. 1.490563387       -1.235239880         0.4358665214 )
       reshape( source = (/ &
                            ! first column
                            0.0_DP, &
                            0.4358665214_DP, &
                            1.0_DP - 0.0735700902_DP - 0.4358665214_DP, &
                            1.0_DP - 1.490563387_DP +  1.235239880_DP &
                                   - 0.4358665214_DP, &
                            ! second column
                            0.0_DP, &
                            0.4358665214_DP, &
                            0.0735700902_DP, &
                            1.490563387_DP, &
                            ! third column
                            0.0_DP, &
                            0.0_DP, &
                            0.4358665214_DP, &
                            -1.235239880_DP, &
                            ! fourth column
                            0.0_DP, &
                            0.0_DP, &
                            0.0_DP, &
                            0.4358665214_DP /), shape = (/ 4,4 /) )
      ! b_i = a_{4i}     (see \cite[p. 518, condition (H4)]{John2010514})
      rtstepScheme%dcoeffB = rtstepScheme%dcoeffA(4,:)
      ! c_i = \sum_{j=1}^i a_{ij}   (see \cite[p. 518]{John2010514})
      rtstepScheme%dcoeffC = &
           (/ 0.0_DP, &                 ! sum(rtstepScheme%dcoeffA(1,:))
              0.8717330428_DP, &        ! sum(rtstepScheme%dcoeffA(2,:))
              1.0_DP, &                 ! sum(rtstepScheme%dcoeffA(3,:))
              1.0_DP /)                 ! sum(rtstepScheme%dcoeffA(4,:))

    else if (ctimestepType .eq. TSCHM_DIRK44L) then

      rtstepScheme%ctimestepType    = TSCHM_DIRK44L

      ! The DIRK44L scheme as proposed in section 4.2 of
      !  @TechReport{Rang200702,
      !     author      = {Rang, Joachim},
      !     title       = {Design of {DIRK} schemes for solving the
      !                    {N}avier--{S}tokes equations},
      !     institution = {Institute of Scientific Computing},
      !     address     = {Technical University Braunschweig, Brunswick, Germany},
      !     year        = {2007},
      !     month       = feb,
      !     url         = {http://www.digibib.tu-bs.de/?docid=00020655},
      !     note        = {Informatikbericht Nr. 2007-02},
      !  }
      ! consists of 4 stages, but only 3 substeps...
      rtstepScheme%nsubsteps        = 3

      ! ... and uses several parameter:
      rtstepScheme%dcoeffA = &
       ! see \cite[p. 16]{Rang200702}:
       !
       ! (0                    0                           0                          0  )
       ! (1/4                  1/4                         0                          0  )
       ! (1 - a32 - a33        (3 a44 - 2)/(3(3 a44 - 1))  (6 a44 - 1)/(6(3 a44 - 1)) 0  )
       ! (1 - a42 - a43 - a44  2/3                         1/6 - a44                  a44)
       !
       ! with a44 := 1/3-sqrt(2)/6 yields
       !
       ! (0                    0                           0                          0  )
       ! (1/4                  1/4                         0                          0  )
       ! (1/3 - sqrt(2)/6      1/3 + sqrt(2)/3             1/3 - sqrt(2)/6            0  )
       ! 1/6                   2/3                         sqrt(2)/6 - 1/6  1/3-sqrt(2)/6)
       reshape( source = (/ &
                            ! first column
                            0.0_DP, &
                            0.25_DP, &
                            (2.0_DP - sqrt(2.0_DP))/6.0_DP, &
                            1.0_DP/6.0_DP, &
                            ! second column
                            0.0_DP, &
                            0.25_DP, &
                            (1.0_DP + sqrt(2.0_DP))/3.0_DP, &
                            2.0_DP/3.0_DP, &
                            ! third column
                            0.0_DP, &
                            0.0_DP, &
                            (2.0_DP - sqrt(2.0_DP))/6.0_DP, &
                            (sqrt(2.0_DP) - 1.0_DP)/6.0_DP, &
                            ! fourth column
                            0.0_DP, &
                            0.0_DP, &
                            0.0_DP, &
                            (2.0_DP - sqrt(2.0_DP))/6.0_DP /), shape = (/ 4,4 /) )
      ! b_i = a_{4i}     (see \cite[p. 518, condition (H4)]{John2010514})
      rtstepScheme%dcoeffB = rtstepScheme%dcoeffA(4,:)
      ! c_i = \sum_{j=1}^i a_{ij}   (see \cite[p. 518]{John2010514})
      rtstepScheme%dcoeffC = &
           (/ 0.0_DP, &  ! sum(rtstepScheme%dcoeffA(1,:))
              0.5_DP, &  ! sum(rtstepScheme%dcoeffA(2,:))
              1.0_DP, &  ! sum(rtstepScheme%dcoeffA(3,:))
              1.0_DP /)  ! sum(rtstepScheme%dcoeffA(4,:))

    end if

    ! Initialise the weights for the first time step by calling
    ! timstp_setBaseSteplength with time step length = dtstep
    call timstp_setBaseSteplength (rtstepScheme, dtstep)

  end subroutine

  !****************************************************************************

!<subroutine>

  subroutine timstp_setBaseSteplength (rtstepScheme, dtstep)

!<description>
  ! Modifies the base step length of the time stepping scheme in rtstepScheme
  ! to dtstep. The base step length is the theoretical time step length
  ! if an equidistant time discretisation is used. It coincides with the actual
  ! time step length only if a one step scheme is used.
  ! Reinitialises all weights according to the current time step configuration
  ! in rtstepScheme.
!</description>

!<input>
  ! (Theoretical) Time step length of the simulation.
  ! Might vary from the real time step size by the type of the
  ! scheme, which is indicated by rtstepScheme%dtstep
  real(DP), intent(in)   :: dtstep
!</input>

!<output>
  ! The time stepping structure. This is initialised according to the
  ! new time step length.
  type(t_explicitTimeStepping), intent(inout) :: rtstepScheme
!</output>

!</subroutine>

    ! local variables
    real(DP) :: dtheta1, dthetp1, dalpha, dbeta


    ! Set the new step length
    rtstepScheme%dtstepFixed        = dtstep

    if (rtstepScheme%ctimestepType .eq. TSCHM_ONESTEP) then
      ! Standard time stepping scheme.
      rtstepScheme%nsubsteps        = 1

      dtheta1                       = rtstepScheme%dtheta

      rtstepScheme%dtstep           = dtstep
      rtstepScheme%dthStep          = dtstep * dtheta1

      ! Initialise weights for matrices and RHS:
      rtstepScheme%dweightMatrixLHS = dtstep * dtheta1
      rtstepScheme%dweightMatrixRHS = - dtstep * (1.0_DP - dtheta1)
      rtstepScheme%dweightNewRHS    = dtstep * dtheta1
      rtstepScheme%dweightOldRHS    = dtstep * (1.0_DP - dtheta1)
      rtstepScheme%dweightStationaryRHS = dtstep

    else if (rtstepScheme%ctimestepType .eq. TSCHM_FRACTIONALSTEP) then

      ! In case of fractional-step, we have to modify the length of the
      ! current time step according to the substep:
      !
      ! For fractional-step the handling of the time step size dtstep
      ! is slightly different than for a 1-step scheme.
      ! There we are orienting on the length of the macrostep of
      ! step length 3*dtstep and break up that into three different
      ! substeps at different points in time, not corresponding to
      ! dtstep. Depending on the number of the current substep, we
      ! have two settings for the weights and time length:

      dtheta1 = rtstepScheme%dtheta
      dthetp1 = rtstepScheme%dthetaPrime
      dalpha  = rtstepScheme%dalpha
      dbeta   = rtstepScheme%dbeta

      ! Note: the factor 3 the time step gets scaled with below is necessary to be
      !       consistent with the increment of the macro time step as done in
      !       timstp_nextSubstepWeights():
      !            real(rtstepScheme%nsubsteps,DP) * rtstepScheme%dtstepFixed
      !       This, in turn, is done to be able to compare the results of 3 Backward Euler
      !       or Crank-Nicolson steps with 1 (macro) step of the classic fractional-step
      !       theta scheme - this way all three schemes have had comparable computational
      !       costs and after completion of this macro time step their respective
      !       solutions live in the same point in time.

      if (rtstepScheme%isubstep .ne. 2) then

        ! 1st and 3rd substep

        rtstepScheme%dtstep           =  3.0_DP * dtstep * dtheta1

        rtstepScheme%dweightMatrixLHS =  3.0_DP * dtstep * dalpha * dtheta1
        rtstepScheme%dweightMatrixRHS = -3.0_DP * dtstep * dbeta * dtheta1
        rtstepScheme%dweightNewRHS    =  3.0_DP * dtstep * dalpha * dtheta1
        rtstepScheme%dweightOldRHS    =  3.0_DP * dtstep * dbeta * dtheta1
        rtstepScheme%dweightStationaryRHS = 3.0_DP * dtstep * dtheta1

      else

        ! 2nd substep

        rtstepScheme%dtstep           =  3.0_DP * dtstep * dthetp1

        rtstepScheme%dweightMatrixLHS =  3.0_DP * dtstep * dalpha * dtheta1
        rtstepScheme%dweightMatrixRHS = -3.0_DP * dtstep * dalpha * dthetp1
        rtstepScheme%dweightNewRHS    =  3.0_DP * dtstep * dbeta * dthetp1
        rtstepScheme%dweightOldRHS    =  3.0_DP * dtstep * dalpha * dthetp1
        rtstepScheme%dweightStationaryRHS = 3.0_DP * dtstep * dthetp1

      end if

    else if (rtstepScheme%ctimestepType .eq. TSCHM_FS_GLOWINSKI) then

      dtheta1 = rtstepScheme%dtheta
      dthetp1 = rtstepScheme%dthetaPrime

      ! See page 6 of
      !  @ARTICLE{TurekRivkindHronGlowinski2006,
      !     author       = {Turek, S. and Rivkind, L. and Hron, J. and Glowinski, R.},
      !     title        = {Numerical study of a modified time-stepping theta-scheme
      !                     for incompressible flow simulations},
      !     journal      = {J. Sci. Comput.},
      !     year         = {2006},
      !     volume       = {28},
      !     number       = {2--3},
      !     pages        = {533--547},
      !     note         = {doi: 10.1007/s10915-006-9083-y},
      !  }

      ! Note: the factor 3 the time step gets scaled with below is necessary to be
      !       consistent with the increment of the macro time step as done in
      !       timstp_nextSubstepWeights():
      !            real(rtstepScheme%nsubsteps,DP) * rtstepScheme%dtstepFixed
      !       This, in turn, is done to be able to compare the results of 3 Backward Euler
      !       or Crank-Nicolson steps with 1 (macro) step of the classic fractional-step
      !       theta scheme - this way all three schemes have had comparable computational
      !       costs and after completion of this macro time step their respective
      !       solutions live in the same point in time.
      select case (rtstepScheme%isubstep)
      case (1)
        rtstepScheme%dtstep               = 3.0_DP * dtstep * dtheta1

        rtstepScheme%dweightMatrixLHS     = 3.0_DP * dtstep * dtheta1
        rtstepScheme%dweightMatrixRHS     = SYS_MAXREAL_DP ! not applicable
        rtstepScheme%dweightNewRHS        = 3.0_DP * dtstep * dtheta1
        rtstepScheme%dweightOldRHS        = 0.0_DP
        rtstepScheme%dweightStationaryRHS = 3.0_DP * dtstep * dtheta1

      case (2)
        rtstepScheme%dtstep               = 3.0_DP * dtstep * dthetp1

        ! no system to be solved
        rtstepScheme%dweightMatrixLHS     = SYS_MAXREAL_DP ! not applicable
        rtstepScheme%dweightMatrixRHS     = SYS_MAXREAL_DP ! not applicable
        rtstepScheme%dweightNewRHS        = SYS_MAXREAL_DP ! not applicable
        rtstepScheme%dweightOldRHS        = SYS_MAXREAL_DP ! not applicable
        rtstepScheme%dweightStationaryRHS = SYS_MAXREAL_DP ! not applicable

      case (3)
        rtstepScheme%dtstep               = 3.0_DP * dtstep * dtheta1

        rtstepScheme%dweightMatrixLHS     = 3.0_DP * dtstep * dtheta1
        rtstepScheme%dweightMatrixRHS     = SYS_MAXREAL_DP ! not applicable
        rtstepScheme%dweightNewRHS        = 3.0_DP * dtstep * dtheta1
        rtstepScheme%dweightOldRHS        = 0.0_DP
        rtstepScheme%dweightStationaryRHS = 3.0_DP * dtstep * dtheta1
      end select

    else if (rtstepScheme%ctimestepType .eq. TSCHM_FS_DIRK  .or. &
             rtstepScheme%ctimestepType .eq. TSCHM_DIRK34La .or. &
             rtstepScheme%ctimestepType .eq. TSCHM_DIRK34Lb .or. &
             rtstepScheme%ctimestepType .eq. TSCHM_DIRK44L) then
      ! tau, corresponding to the \tau from \cite[p. 517]{John2010514}, gets chosen such
      ! that
      !                      tau = 3 * prescribed time step size
      ! Note: the factor 3 is necessary to be consistent with the increment of the macro
      !       time step as done in timstp_nextSubstepWeights():
      !            real(rtstepScheme%nsubsteps,DP) * rtstepScheme%dtstepFixed
      !       This, in turn, is done to be able to compare the results of 3 Backward Euler
      !       or Crank-Nicolson steps with 1 (macro) step of the classic fractional-step
      !       theta scheme or one sweep of DIRK34L or DIRK44L - this way all five time
      !       stepping schemes involved comparable computational costs and after
      !       completion of this macro time step their respective solutions live in the
      !       same point in time.
      rtstepScheme%dtau = 3.0_DP * dtstep
      select case (rtstepScheme%isubstep)
      case (1)
        rtstepScheme%dtimeDIRKstage1      = rtstepScheme%dcurrentTime
        rtstepScheme%dtstep               = rtstepScheme%dtau * rtstepScheme%dcoeffC(2)
        rtstepScheme%dweightMatrixLHS     = rtstepScheme%dtau * rtstepScheme%dcoeffA(2,2)
        rtstepScheme%dweightMatrixRHS     = SYS_MAXREAL_DP ! not applicable for
        rtstepScheme%dweightNewRHS        = SYS_MAXREAL_DP ! symmetry reasons
        rtstepScheme%dweightOldRHS        = SYS_MAXREAL_DP ! with substeps 2 and 3
        rtstepScheme%dweightStationaryRHS = rtstepScheme%dtau * &
                                            sum(rtstepScheme%dcoeffA(2,:))

      case (2)
        rtstepScheme%dtstep               = rtstepScheme%dtau * (rtstepScheme%dcoeffC(3)-&
                                                                 rtstepScheme%dcoeffC(2))
        rtstepScheme%dweightMatrixLHS     = rtstepScheme%dtau * rtstepScheme%dcoeffA(3,3)
        rtstepScheme%dweightMatrixRHS     = SYS_MAXREAL_DP ! not applicable, because old
        rtstepScheme%dweightNewRHS        = SYS_MAXREAL_DP ! solutions get queried at 2
        rtstepScheme%dweightOldRHS        = SYS_MAXREAL_DP ! and right hand side at 3
                                                           ! points in time, not merely 2.
        rtstepScheme%dweightStationaryRHS = rtstepScheme%dtau * &
                                            sum(rtstepScheme%dcoeffA(3,:))

      case (3)
        ! Yes, this particular setting ...%dtstep choice leads indeed for DIRK34L and
        ! DIRK44L to a seemingly time step size of 0. At least that is what gets displayed
        ! in the log. But this setting is only for display, internally the DIRK algorithms
        ! rely on the parameter tau and coefficients c_i to determine the time step size.
        rtstepScheme%dtstep               = rtstepScheme%dtau * (rtstepScheme%dcoeffC(4)-&
                                                                 rtstepScheme%dcoeffC(3))

        rtstepScheme%dweightMatrixLHS     = rtstepScheme%dtau * rtstepScheme%dcoeffA(4,4)
        rtstepScheme%dweightMatrixRHS     = SYS_MAXREAL_DP ! not applicable, because old
        rtstepScheme%dweightNewRHS        = SYS_MAXREAL_DP ! solutions get queried at 3
        rtstepScheme%dweightOldRHS        = SYS_MAXREAL_DP ! and right hand side at 4
                                                           ! points in time, not merely 2.
        rtstepScheme%dweightStationaryRHS = rtstepScheme%dtau * &
                                            sum(rtstepScheme%dcoeffA(4,:))

      end select

    end if

  end subroutine

  !****************************************************************************

!<subroutine>

  subroutine timstp_nextSubstep (rtstepScheme)

!<description>
  ! Advances in time. In rtstepScheme, the current simulation time is increased
  ! to the next point in time. The weights for the terms in the differential
  ! equation are updated according to the next substep in the time stepping scheme.
!</description>

!<inputoutput>
  ! The time stepping structure. Is modified to represent the next time step.
  type(t_explicitTimeStepping), intent(inout) :: rtstepScheme
!</inputoutput>

!</subroutine>

    ! Remember the last step length.
    rtstepScheme%dtlaststep = rtstepScheme%dtstep

    ! Update simulation time and weights, right after each other.
    call timstp_nextSubstepTime (rtstepScheme)
    call timstp_nextSubstepWeights (rtstepScheme)

  end subroutine

  !****************************************************************************

!<subroutine>

  subroutine timstp_nextSubstepTime (rtstepScheme)

!<description>
  ! Advances in time. In rtstepScheme, the current simulation time is increased
  ! to the next point in time.
  ! Note that the weights and the number of the current (sub)step are not
  ! changed! These have to be updated with an additional call to
  ! timstp_nextSubstepWeights!
!</description>

!<inputoutput>
  ! The time stepping structure. Is modified to represent the next time step.
  type(t_explicitTimeStepping), intent(inout) :: rtstepScheme
!</inputoutput>

!</subroutine>

    if (rtstepScheme%ctimestepType .lt. 0) then
      call output_line ('timstp_nextSubstep: Time stepping structure not initialised!')
    end if

    ! Increase the simulation time
    rtstepScheme%dcurrentTime = rtstepScheme%dcurrentTime + rtstepScheme%dtstep

  end subroutine

  !****************************************************************************

!<subroutine>

  subroutine timstp_nextSubstepWeights (rtstepScheme)

!<description>
  ! Advances the weights of the time step scheme in time. The number of the
  ! current time (sub)step in increased and the weights for the terms in the
  ! differential equation are updated according to the next substep in
  ! the time stepping scheme.
!</description>

!<inputoutput>
  ! The time stepping structure. Is modified to represent the next time step.
  type(t_explicitTimeStepping), intent(inout) :: rtstepScheme
!</inputoutput>

!</subroutine>

    if (rtstepScheme%ctimestepType .lt. 0) then
      call output_line ('timstp_nextSubstep: Time stepping structure not initialised!')
    end if

    ! Increase number of current substep
    rtstepScheme%isubstep = rtstepScheme%isubstep + 1

    if (rtstepScheme%isubstep .gt. rtstepScheme%nsubsteps) then
      rtstepScheme%isubstep = 1
      ! Set the time with a slightly different approach to prevent rounding errors.
      rtstepScheme%dtimeMacrostep = rtstepScheme%dtimeMacrostep + &
          real(rtstepScheme%nsubsteps,DP) * rtstepScheme%dtstepFixed
      rtstepScheme%dcurrentTime = rtstepScheme%dtimeMacrostep
    end if

    ! Initialise all weights by calling the timstp_setBaseSteplength routine
    ! with time step length = current time step length, saved in the dtstepFixed
    ! variable of rtstepScheme.
    call timstp_setBaseSteplength (rtstepScheme, rtstepScheme%dtstepFixed)

  end subroutine

end module
