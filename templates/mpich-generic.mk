# -*- mode: makefile -*-

##############################################################################
# MPICH environment flags 
# (see http://www.mcs.anl.gov/mpi/mpich/)
##############################################################################
ifeq ($(strip $(MPIWRAPPERS)), NO)

# Set MPICHHOME if unset
ifeq ($(strip $(MPICHHOME)),)
# If preprocessor switch -DENABLE_SERIAL_BUILD does not occur in compiler flags,
# a build for parallel execution is requested.
ifeq (,$(findstring -DENABLE_SERIAL_BUILD ,$(APPONLYFLAGS) $(CFLAGSF90) ))
MPICHHOME = /usr/local/mpich
MESSAGE  := $(MESSAGE) \
	    echo '*** Warning: MPICHHOME unset. Has been set to $(MPICHHOME)'; \
	    echo '*** Warning: This has implications on include and library paths!';
endif
endif

# Set include and library directory
MPIINC    = -I$(MPICHHOME)/include
MPILIBDIR = -L$(MPICHHOME)/lib
MPILIBS   = -lmpich

endif  # MPIWRAPPERS=NO


# The settings needed to compile a FEAST application are "wildly" distributed
# over several files ((Makefile.inc and templates/*.mk) and if-branches 
# (in an attempt to reduce duplicate code and inconsistencies among all build 
# IDs that e.g. use the same MPI environment). Not having all settings at 
# *one* place entails the risk (especially in the event of setting up a new 
# build ID) that settings are incompletely defined. A simple typo in a matching 
# rule in Makefile.inc may prevent that the compiler and compiler command line
# flags are set. Compilation would fail with the most peculiar errors - if not
# the Makefile had been set up to catch such a case.
# Each build ID in FEAST has 6 tokens: architecture, cpu, operating system,
# compiler family, BLAS implementation, MPI environment. Whenever setting
# one of these, an according flag is set. They are named TOKEN1 up to TOKEN6.
# Before starting to actually compile a FEAST application, every Makefile
# generated by bin/configure checks whether all six tokens are set *for the
# choosen build ID*. If not, the user gets an error message describing exactly 
# what information is missing, e.g. token 5 not set which means there is no
# information available which BLAS implementation to use and where to find the
# library.
#
# In this file, the sixth token has been set: MPI environment. 
# Set the flag accordingly.
TOKEN6 := 1

