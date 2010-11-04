# -*- mode: makefile -*-

##############################################################################
# command to create archive from object files
##############################################################################
AR        = ar -rv -X 64

##############################################################################
# command to create index to archive
#############################################################################
RANLIB    = ranlib -X 64

##############################################################################
# subroutines/functions missing in system libraries
##############################################################################
SRCEXTRA := $(SRCEXTRA) \
	    # kernel/arch/amub.f90 kernel/arch/ib21.f kernel/arch/if117.f \
	    # kernel/arch/ifd17.f kernel/arch/sysextra.c kernel/arch/transp.f90 

##############################################################################
# Sparse Banded Blas benchmark
##############################################################################
SBB_SRCEXTRA = ztime_ibmregatta.f


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
# In this file, the first two tokens have been set: architecture and cpu.
# Set the flags accordingly.
TOKEN1 := 1
TOKEN2 := 1
