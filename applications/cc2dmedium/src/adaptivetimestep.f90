!##############################################################################
!# ****************************************************************************
!# <name> adaptivetimestep </name>
!# ****************************************************************************
!#
!# <purpose>
!# This module contains routines to control the adaptive time stepping in 
!# a nonstationary simulation with explicit time stepping.
!#
!# The adaptive time stepping basically works the following way:
!#  a) Perform a predictor step to compute a 'predictor solution' u1 at time
!#     $t_{n}$ (e.g. by 1st order method)
!#  b) Perform the real computation to compute a solution u2 at time
!#     $t_{n}$ (e.g. 2nd order method)
!#  c) Use an error functional to compute J(.) to compute a time error
!#     using u1 and u2
!# These tasks are done application specific. Afterwards,
!#  d) Use adtstp_calcTimeStep to calculate a new time step size for
!#     explicit time stepping based on the time error J(.).
!#
!# The following routines can be found here:
!#
!#  1.) adtstp_init
!#      -> Initialise the 'adaptive time stepping structure' using a
!#         parameter list.
!#
!#  2.) adtstp_calcTimeStep
!#      -> Calculate a new time step size
!# </purpose>
!##############################################################################

MODULE adaptivetimestep

  USE fsystem
  USE paramlist
    
  IMPLICIT NONE
  
!<constants>

!<constantblock description="Identifiers for the type of the adaptive time stepping.">

  ! Fixed time step size, no adaptive time stepping.
  INTEGER, PARAMETER :: TADTS_FIXED = 0
  
  ! Adaptive time stepping with prediction,
  ! no repetition except for when the solver breaks down.
  INTEGER, PARAMETER :: TADTS_PREDICTION = 1
  
  ! Adaptive time stepping with prediction,
  ! repetition of the time step if nonlinear stopping
  ! criterion is too large or the solver breaks down.
  INTEGER, PARAMETER :: TADTS_PREDICTREPEAT = 2
  
  ! Adaptive time stepping with prediction,
  ! repetition of the time step if nonlinear stopping
  ! criterion is too large or the time error is too large
  ! or the solver breaks down.
  INTEGER, PARAMETER :: TADTS_PREDREPTIMECONTROL = 3

!</constantblock>

!<constantblock description="Identifiers for the type of the adaptive time stepping during the start phase.">

  ! Use depsadi for controlling the error in the start phase (Standard).
  INTEGER, PARAMETER :: TADTS_START_STANDARD    = 0

  ! Use linear blending between dadTimeStepEpsDuringInit and dadTimeStepEpsAfterInit
  ! to control the error in the start phase.
  INTEGER, PARAMETER :: TADTS_START_LINEAR      = 1
  
  ! Use logarithmic blending between dadTimeStepEpsDuringInit and dadTimeStepEpsAfterInit
  ! to control the error in the start phase.
  INTEGER, PARAMETER :: TADTS_START_LOGARITHMIC = 2

!</constantblock>

!</constants>  

  
!<types>

!<typeblock>

  ! Basic structure guiding the adaptive time stepping, in the start phase
  ! and during the simulation, as well as configuring how to estimate the time
  ! error.
  TYPE t_adaptimeTimeStepping
  
    ! Type of adaptive time stepping. One of the TADTS_xxxx constants.
    ! Standard is TADTS_FIXED = No adaptive time stepping.
    INTEGER :: ctype                          = TADTS_FIXED
    
    ! Maximum number of repetitions if ctype=TADTS_PREDICTREPEAT or
    ! ctype=TADTS_PREDREPTIMECONTROL.
    INTEGER  :: nrepetitions                  = 3
    
    ! Minimum time step.
    REAL(DP) :: dtimeStepMin                  = 0.000001_DP
    
    ! Maximum time step.
    REAL(DP) :: dtimeStepMax                  = 1.000000001_DP
    
    ! Factor for modifying time step size. 
    ! Only if ctype != TADTS_FIXED.
    ! Time step size is reduced by sqrt(DTFACT) upon broke down
    ! of nonlinear solver, and by DTFACT upon broke down of linear solver.
    ! When decreasing the time step size, the new time step size is 
    ! estimated in the range
    !  (old time step)/dtimeStepFactor .. (old time step)/SQRT(dtimeStepFactor).
    ! When increasing the time step size, the new time step size is
    ! estimated in the range
    !  (old time step size) .. (old time step size) * dtimeStepFactor**(1/#performed repetitions)
    REAL(DP) :: dtimeStepFactor               = 9.000000001_DP
  
    ! Parameter for error control in the start phase. One of the
    ! TADTS_START_xxxx constants. Standard value is TADTS_START_STANDARD,
    ! which controls the time stepping in the start phase by depsadi only.
    ! This parameter affects the simulation only if 
    ! ctype=TADTS_PREDREPTIMECONTROL!
    ! If 
    !  (new time step size)/(old time step size) < depsilonAdaptiveRelTimeStep, 
    ! the time step is repeated.
    REAL(DP) :: depsAdaptiveRelTimeStep       = 0.5_DP
    
    ! Type of start procedure (IADIN) when starting a nonstationary 
    ! simulation if iadaptiveTimeStepping<>0 (to prevent time step to be reduced to 0.0).
    ! One of the TADTS_START_xxxx constants.
    ! TADTS_START_STANDARD    = constant start
    ! TADTS_START_LINEAR      = linear start
    ! TADTS_START_LOGARITHMIC = logarithmic start
    INTEGER :: cadTimeStepInit                = TADTS_START_LOGARITHMIC

    ! Time length of start procedure; must be >0 if iadaptiveTimeStepping<>0,
    ! otherwise nonsteady simulations will stuck at the initial time
    ! reducing the time step size to 0.0
    REAL(DP) :: dadTimeStepInitDuration       = 0.5_DP

    ! Type of error indicator to measure error in time (IEPSAD) when doing
    ! adaptive time stepping;
    ! 1=u(L2),2=u(MX),3=p(L2),4=p(MX),5-8=mix
    INTEGER :: iadTimeStepErrorControl        = 1

    ! Low accuracy for acceptance during start procedure (EPSADI);
    ! if time error is larger, the step is repeated
    REAL(DP) :: dadTimeStepEpsDuringInit      = 1.25E-1_DP

    ! Low accuracy for acceptance after start procedure (EPSADL);
    ! if time error is larger, the step is repeated
    REAL(DP) :: dadTimeStepEpsAfterInit       = 1.25E-3_DP
  
  END TYPE

!</typeblock>

!</types>
  
CONTAINS

!******************************************************************************

!<subroutine>

  SUBROUTINE adtstp_init (rparams,ssection,radTimeStepping)
  
!<description>
  ! Initialises the adaptive time stepping scheme using the parameter block
  ! rparams. The parameters of the scheme are read from the paremeter
  ! section ssection.
!</description>
  
!<input>
  ! The parameter block with the parameters.
  TYPE(t_parlist), INTENT(IN) :: rparams
  
  ! The name of the section containing the parameters of the adaptive time
  ! stepping.
  CHARACTER(LEN=*), INTENT(IN) :: ssection
!</input>

!<output>
  ! A configuration block that configures the adaptive time stepping.
  ! Is filled with the parameters from rparams.
  TYPE(t_adaptimeTimeStepping), INTENT(OUT) :: radTimeStepping
!</output>
  
!</subroutine>

    ! local variables
    TYPE(t_parlstSection), POINTER :: p_rsection
  
    ! Get the section containing our parameters
    CALL parlst_querysection(rparams, ssection, p_rsection) 
    
    IF (.NOT. ASSOCIATED(p_rsection)) THEN
      PRINT *,'Cannot configure adaptive time stepping! Parameter section not found!'
      STOP
    END IF
    
    ! Get the paramters and fill our structure. Use the standard parameters
    ! from the Fortran initialisation (by INTENT(OUT)) for those who don't exist.
    CALL parlst_getvalue_int(p_rsection,'cadaptiveTimeStepping',&
                            radTimeStepping%ctype,&
                            radTimeStepping%ctype)
               
    CALL parlst_getvalue_int(p_rsection,'nrepetitions',&
                            radTimeStepping%nrepetitions,&
                            radTimeStepping%nrepetitions)

    CALL parlst_getvalue_double(p_rsection,'dtimeStepMin',&
                            radTimeStepping%dtimeStepMin,&
                            radTimeStepping%dtimeStepMin)

    CALL parlst_getvalue_double(p_rsection,'dtimeStepMax',&
                            radTimeStepping%dtimeStepMax,&
                            radTimeStepping%dtimeStepMax)
            
    CALL parlst_getvalue_double(p_rsection,'dtimeStepFactor',&
                            radTimeStepping%dtimeStepFactor,&
                            radTimeStepping%dtimeStepFactor)
    
    CALL parlst_getvalue_double(p_rsection,'depsAdaptiveRelTimeStep',&
                            radTimeStepping%depsAdaptiveRelTimeStep,&
                            radTimeStepping%depsAdaptiveRelTimeStep)
                          
    CALL parlst_getvalue_int(p_rsection,'cadTimeStepInit',&
                            radTimeStepping%cadTimeStepInit,&
                            radTimeStepping%cadTimeStepInit)
     
    CALL parlst_getvalue_double(p_rsection,'dadTimeStepInitDuration',&
                            radTimeStepping%dadTimeStepInitDuration,&
                            radTimeStepping%dadTimeStepInitDuration)

    CALL parlst_getvalue_int(p_rsection,'iadTimeStepErrorControl',&
                           radTimeStepping%iadTimeStepErrorControl,&
                           radTimeStepping%iadTimeStepErrorControl)

    CALL parlst_getvalue_double(p_rsection,'dadTimeStepEpsDuringInit',&
                            radTimeStepping%dadTimeStepEpsDuringInit,&
                            radTimeStepping%dadTimeStepEpsDuringInit)

    CALL parlst_getvalue_double(p_rsection,'dadTimeStepEpsAfterInit',&
                            radTimeStepping%dadTimeStepEpsAfterInit,&
                            radTimeStepping%dadTimeStepEpsAfterInit)

  END SUBROUTINE
  
!******************************************************************************

!<function>

  PURE REAL(DP) FUNCTION adtstp_getTolerance (radTimeStepping,dtimeInit,dtime) &
                RESULT(depsad)
  
!<description>
  ! Auxiliary routine.
  ! Based on the configuration of the adaptive time stepping, this function 
  ! computes a bound that can be used in the adaptive time stepping as 
  ! stopping criterion.
!</description>

!<input>
  ! Configuration block of the adaptive time stepping.
  TYPE(t_adaptimeTimeStepping), INTENT(IN) :: radTimeStepping
  
  ! Initial simulation time.
  REAL(DP), INTENT(IN)                     :: dtimeInit
  
  ! Current simulation time.
  REAL(DP), INTENT(IN)                     :: dtime
!</input>

!<result>
  ! Stopping criterion for adaptive time step control.
  ! During the startup phase (time T in the range 
  ! dtimeInit..dtimeInit+dadTimeStepInitDuration), the stopping criterion
  ! will be calculated according to IADIN. After the
  ! startup phase, EPSADL will be used.
!</result>

!</function>

    ! lcoal variables
    REAL(DP) :: dtdiff

    ! Standard result: dadTimeStepEpsAfterInit
           
    depsad = radTimeStepping%dadTimeStepEpsAfterInit

    ! Do we have a startup phase at all? Would be better, otherwise
    ! Navier-Stokes might stagnate with decreasing time steps at the
    ! beginning...

    dtdiff = dtime - dtimeInit

    IF ((radTimeStepping%dadTimeStepInitDuration .GT. 0.0_DP) .AND. &
       (dtdiff .LE. radTimeStepping%dadTimeStepInitDuration)) THEN
    
      ! Calculate the "current position" of the simulation time in
      ! the interval TIMEST..TIMEST+TIMEIN
    
      SELECT CASE (radTimeStepping%cadTimeStepInit)
      CASE (TADTS_START_STANDARD)
        ! Standard error control during the startup phase
        ! Use dadTimeStepEpsDuringInit or dadTimeStepEpsAfterInit, depending on
        ! whether we left the start phase or not.
        depsad = radTimeStepping%dadTimeStepEpsDuringInit
      
      CASE (TADTS_START_LINEAR)
        ! Linear blending as control in the startup phase.
        ! Blend linearly between dadTimeStepEpsDuringInit and dadTimeStepEpsAfterInit 
        ! from the initial simulation time TIMEST to the end of the startup phase
        ! TIMEST+TIMEIN.
        ! After the startup phase, use dadTimeStepEpsAfterInit.
        depsad = radTimeStepping%dadTimeStepEpsDuringInit + &
                  dtdiff / radTimeStepping%dadTimeStepInitDuration * &
                  (radTimeStepping%dadTimeStepEpsAfterInit - &
                    radTimeStepping%dadTimeStepEpsDuringInit)

      CASE (TADTS_START_LOGARITHMIC)
        ! Logarithmic blending as control in the startup phase.
        ! Blend logarithmically between dadTimeStepEpsDuringInit 
        ! and dadTimeStepEpsAfterInit from the initial simulation time TIMNEST 
        ! to the end of the startup phase TIMEST+TIMEIN.
        ! After the startup phase, use dadTimeStepEpsAfterInit.
        depsad = radTimeStepping%dadTimeStepEpsDuringInit** &
                    (1.0_DP-dtdiff/radTimeStepping%dadTimeStepInitDuration) * &
                  radTimeStepping%dadTimeStepEpsAfterInit** &
                    (dtdiff/radTimeStepping%dadTimeStepInitDuration)
      
      END SELECT

    ENDIF

  END FUNCTION

!******************************************************************************

!<function>

  PURE REAL(DP) FUNCTION adtstp_calcTimeStep (radTimeStepping, derrorIndicator, &
                           dtimeInit,dtime,dtimeStep, itimeApproximationOrder, &
                           isolverStatus,irepetitionCounter) &
                RESULT(dnewTimeStep)
  
!<description>
  ! Calculates a new time step size based on a time error indicator derrorIndicator.
!</description>

!<input>
  ! Configuration block of the adaptive time stepping.
  TYPE(t_adaptimeTimeStepping), INTENT(IN) :: radTimeStepping

  ! A value of a time error functional. Is used to calculate the new time 
  ! step size. Can be set to 0.0 if bit 0 or 1 in isolverStatus below is set.
  REAL(DP), INTENT(IN)                     :: derrorIndicator

  ! Initial simulation time.
  REAL(DP), INTENT(IN)                     :: dtimeInit
  
  ! Current simulation time.
  REAL(DP), INTENT(IN)                     :: dtime

  ! Current (theoretical) time step size.
  ! Can vary from the actual time step size, depending on
  ! the time stepping scheme.
  REAL(DP), INTENT(IN)                     :: dtimeStep
  
  ! Order of the time approximation
  ! =1: time approximation is of 1st order(Euler)
  ! =2: time approximation is of 2nd order
  !     (Crank Nicolson, Fractional Step)  
  INTEGER, INTENT(IN)                      :: itimeApproximationOrder
  
  ! Status of the solver. Indicates whether any of the solvers broke down during
  ! the solution process. Bitfield. Standard value = 0 = all solvers worked fine.
  ! Lower bits represent a failue of critical solver components while higher bits
  ! indicate the failure of noncritical solver components:
  !
  !  Bit 0 = failure of the (linear) preconditioner
  !  Bit 1 = failore of the nonlinear solver
  !  Bit 2 = failure of the (linear) preconditioner in the predictor step
  !  Bit 3 = failure of the nonlinear solver in the predictor step
  !
  ! If Bit 0 or 1 are set, the value of derrorIndicator is ignored.
  INTEGER(I32), INTENT(IN)                 :: isolverStatus
  
  ! Repetition counter.
  ! =0, if the current time step is calculated for the first time; standard.
  ! >0: if the current time step is calculated more than once because
  !     it had to be repeated.
  INTEGER, INTENT(IN)                      :: irepetitionCounter
!</input>

!<result>
  ! The new time step size to use.
!</result>

!</function>

    ! local variables
    REAL(DP) :: depsTime
    REAL(DP) :: dhfact

    ! As standard, take the old stepsize as the new
    dnewTimeStep = dtimeStep
    
    IF (radTimeStepping%ctype .EQ.TADTS_FIXED) RETURN
    
    ! Check if we can use time analysis...
    IF (IAND(isolverStatus,3) .NE. 0) THEN
    
      ! A critical solver component broke down, we cannot do time analysis.
      ! we really don't have much information in this case.
      ! We can just "guess" a new time step - if we are at all allowed
      ! to change it!

      IF (IAND(isolverStatus,2**1+2**2) .NE. 0) THEN
      
        ! If the linear solvers of the predictior step or
        ! the nonlinear solver of the correction step broke down,
        ! broke down, reduce the time step by sqrt(dtimeStepFactor)
      
        dnewTimeStep = dtimeStep / SQRT(radTimeStepping%dtimeStepFactor)
      
      ELSE IF (IAND(isolverStatus,2**0).NE.0) THEN

        ! If the linear solvers of the correction step broke down,
        ! broke down, reduce the time step by DTFACT
      
        dnewTimeStep = dtimeStep / radTimeStepping%dtimeStepFactor
      
      END IF
        
      ! Otherwise we leave the time step as it is...
      
    ELSE
   
      ! All critical solvers worked fine, we can now calculate a new time step
      ! depending on our error indicator.
      !
      ! At first, calculate the time tolerance.
      depsTime = adtstp_getTolerance (radTimeStepping,dtimeInit,dtime)
      
      ! Depending on the order of the time stepping algorithm, calculate an initial 
      ! guess for the time step.
      
      IF (itimeApproximationOrder .LE. 1) THEN

        ! Time approximation of 1st order; used for all one-step
        ! schemes. The error can be represented as:
        !   J(v_k) - J(v) = k e(v) + O(k^2)

        dnewTimeStep = dtimeStep*2.0_DP*depsTime/derrorIndicator
        
      ELSE
      
        ! Time approximation of 2st order; used for Fractional
        ! step Theta scheme. The error can be represented as:
        !   J(v_k) - J(v) = k^2 e(v) + O(k^4)

        dnewTimeStep = dtimeStep*SQRT(8.0_DP*depsTime/derrorIndicator)
        
      ENDIF

      ! The nonlinear solver in the predictior step might break
      ! down, while the other solvers work.
      ! When the nonlinear solver broke down and we are in a time
      ! stepping mode that allowes repetition of the time step,
      ! bound the time step: dnewTimeStep must result in the interval
      ! [ dtimeStep/SQRT(radTimeStepping%dtimeStepFactor) .. dtimeStep ]:

      IF (IAND(isolverStatus,2**3).NE. 0) THEN
        dnewTimeStep = MAX( dtimeStep/SQRT(radTimeStepping%dtimeStepFactor), &
                            MIN(dnewTimeStep,dtimeStep) )
      ENDIF

      ! dnewTimeStep must not be smaller than dtimeStep/dtimeStepFactor

      dnewTimeStep = MAX( dnewTimeStep, dtimeStep/radTimeStepping%dtimeStepFactor)

      ! Use another upper bound if the solution was calculated
      ! by repetition of a time step:

      IF (irepetitionCounter .GT. 0) THEN
        dhfact=radTimeStepping%dtimeStepFactor**(1.0_DP/REAL(irepetitionCounter+1,DP))
        dnewTimeStep = MIN(dnewTimeStep,dtimeStep*dhfact) 
      ELSE       
        dnewTimeStep = MIN(dnewTimeStep,dtimeStep*radTimeStepping%dtimeStepFactor) 
      ENDIF       
      
    END IF

    ! Bound the time step to the interval DTMIN..DTMAX - for sure
          
    dnewTimeStep = MIN(radTimeStepping%dtimeStepMax, &
                       MAX(dnewTimeStep, radTimeStepping%dtimeStepMin))

  END FUNCTION
  
END MODULE
