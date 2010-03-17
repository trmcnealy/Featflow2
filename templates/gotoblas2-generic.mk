# -*- mode: makefile -*-

##############################################################################
# High-Performance BLAS by Kazushige Goto
# (see http://www.tacc.utexas.edu/resources/software/gotoblasfaq/)
#
# advantage above GotoBLAS 1:
# all LAPACK functions already contained in GotoBLAS 2!
# No need to compile LAPACK reference implemention
##############################################################################

ifneq ($(strip $(GOTOBLAS2_LIB)),)
# Split up string if multiple directories are given
# Note: Do not put whitespace between comma and the environment variable!
LIBDIR   := $(LIBDIR) -L$(subst :, -L,$(GOTOBLAS2_LIB))
endif

LIBS     := $(LIBS) -lgoto2
# If preprocessor switch -DENABLE_SERIAL_BUILD does occur in compiler flags,
# a build for serial execution is requested.
ifneq (,$(findstring -DENABLE_SERIAL_BUILD ,$(APPONLYFLAGS) $(CFLAGSF90) ))
LIBS     := $(LIBS) -lpthread
endif




##############################################################################
# GotoBLAS 2 also needed by the Sparse Banded Blas benchmark
##############################################################################
SBB_LIBS     := $(SBB_LIBS) -lgoto2
# If preprocessor switch -DENABLE_SERIAL_BUILD does occur in compiler flags,
# a build for serial execution is requested.
ifneq (,$(findstring -DENABLE_SERIAL_BUILD ,$(APPONLYFLAGS) $(CFLAGSF90) ))
SBB_LIBS     := $(SBB_LIBS) -lpthread
endif


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
# In this file, the fifth token has been set: BLAS and LAPACK implementation.
# Set the flag accordingly.
TOKEN5 := 1
