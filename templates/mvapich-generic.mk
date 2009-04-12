# -*- mode: makefile -*-

##############################################################################
# MVAPICH compiler flags 
##############################################################################

# If preprocessor switch -DENABLE_SERIAL_BUILD does not occur in compiler flags,
# a build for parallel execution is requested. MPI header and libraries possibly
# need to be added to INC, LIBS, LIBDIR.
ifeq (,$(findstring -DENABLE_SERIAL_BUILD ,$(APPONLYFLAGS) $(CFLAGSF90) ))

# In case MPI wrapper commands are used to compile code, no changes to INC, LIBS
# and LIBDIR are necessary. The MPI wrapper commands will take care of all the
# dirty stuff.
# If no MPI wrapper commands are to be used (sometimes they are not available at
# all or for different reasons one wishes to do so), add MVAPICH-related settings
# manually here.
ifeq ($(strip $(MPIWRAPPERS)), NO)

# Set MVAPICH_HOME if unset
ifeq ($(strip $(MVAPICH_HOME)),)
MVAPICH_HOME = /usr/local/mvapich
MESSAGE  := $(MESSAGE) \
	    echo '*** Warning: MVAPICH_HOME unset. Has been set to $(MVAPICH_HOME)'; \
	    echo '*** Warning: This has implications on include and library paths!'; \
	    echo '*** Warning: AND HAS NEVER BEEN TESTED BEFORE!!!'; 
endif

# Set include and library directory
MPIINC    = -I$(MVAPICH_HOME)/include
MPILIBDIR = -L$(MVAPICH_HOME)/lib
MPILIBS  := $(MPILIBS) -lmpi 

# INTENTIONAL_BUG Settings below are complete crap. We only have MVAPICH 
# on LiDO, and so we might as well use mpiwrapper commands, since this is 
# the recommended approach according to the MVAPICH web site:
# http://mvapich.cse.ohio-state.edu/
# dom, September 14, 2008

# With OpenMPI 1.2.x FEAT2 needs symbols from libmpi_f77 to link properly.
# OpenMPI 1.1.x did not have this library. Include it only if it's available.
# Add -lmpi_f77 if it's available.
ifneq (,$(wildcard $(MVAPICH_HOME)/lib/libmpi_f77.*))
MPILIBS := $(MPILIBS) -lmpi_f77 
endif

# OpenMPI needs Pthread library on PC systems
ifeq ($(firstword $(subst -, ,$(ID))), pc)
MPILIBS  := $(MPILIBS) -lpthread
endif

# OpenMPI needs the dynamic linker library on Linux systems
ifeq ($(firstword $(subst -, ,$(ID))), pc)
MPILIBS  := $(MPILIBS) -ldl
endif

endif  # MPIWRAPPERS=NO

endif  # MODE=PARALLEL aka -DENABLE_SERIAL_BUILD not set


# The settings needed to compile a FEAT2 application are "wildly" distributed
# over several files ((Makefile.inc and templates/*.mk) and if-branches 
# (in an attempt to reduce duplicate code and inconsistencies among all build 
# IDs that e.g. use the same MPI environment). Not having all settings at 
# *one* place entails the risk (especially in the event of setting up a new 
# build ID) that settings are incompletely defined. A simple typo in a matching 
# rule in Makefile.inc may prevent that the compiler and compiler command line
# flags are set. Compilation would fail with the most peculiar errors - if not
# the Makefile had been set up to catch such a case.
# Each build ID in FEAT2 has 6 tokens: architecture, cpu, operating system,
# compiler family, BLAS implementation, MPI environment. Whenever setting
# one of these, an according flag is set. They are named TOKEN1 up to TOKEN6.
# Before starting to actually compile a FEAT2 application, every Makefile
# generated by bin/configure checks whether all six tokens are set *for the
# choosen build ID*. If not, the user gets an error message describing exactly 
# what information is missing, e.g. token 5 not set which means there is no
# information available which BLAS implementation to use and where to find the
# library.
#
# In this file, the sixth token has been set: MPI environment. 
# Set the flag accordingly.
TOKEN6 := 1


