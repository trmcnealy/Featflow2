#!/usr/bin/env make

########################################################################
#                                                                      #
#                   FINITE ELEMENT ANALYSIS TOOLS 2                    #
#                                                                      #
# Authors: M. Koester, M. Moeller, S. Turek, S. Buijssen               #
#                                                                      #
#                                                                      #
# Contact: Applied Mathematics, TU Dortmund University                 #
#          Vogelpothsweg 87, 44227 Dortmund                            #
#          Germany                                                     #
#                                                                      #
# Web:     http://www.featflow.de/en/software/featflow2.html           #
#          mailto:featflow@featflow.de                                 #
#                                                                      #
########################################################################
#                                                                      #
# Makefile to create FEAT2 Documentation from FEAT2 and LaTeX sources  #
#                                                                      #
# Author: Sven H.M. Buijssen (sven.buijssen@math.tu-dortmund.de)       #
# Author: Dominik Goeddeke   (dominik.goeddeke@math.tu-dortmund.de)    #
########################################################################

# Master document, the only one with \begin{document} and \end{document}.
TEX_MASTER_FILE = feat2



########################################################################
# Programs and their flags
#
########################################################################

# docu parser
FORTRANDOC = ../bin/fortrandoc.py



########################################################################
# Paths and invocation of FEAT2-specific scripts and settings
#
########################################################################

# Location of FEAT2 configure script
CONFIGURE = ../../bin/configure
CONFIGUREFLAGS = --make="$(MAKE) MAKEFLAGS= "

# Location of FEAT2's Makefile.inc
MAKEFILE_INC = ../../kernel/arch/Makefile.inc

# List of kernel modules
FEAT2_KERNEL_MODULES_WITH_PATH = \
	$(shell $(CONFIGURE) $(CONFIGUREFLAGS) --list-kernel-modules | grep "\.f90" || exit 1;) 
FEAT2_KERNEL_MODULES           = $(sort $(foreach file, $(FEAT2_KERNEL_MODULES_WITH_PATH), $(notdir $(file))))

# List of application modules
# (remember to filter out any links to prevent duplicates)
FEAT2_APP_MODULES_WITH_PATH = \
	$(sort $(wildcard ../../applications/tutorial/*.f90)) 

# Local copies of application modules (having unique names)
# (The problem is that all applications provide modules with at least
#  the names slavemod and userdef. Make would not know which one to
#  take if the search path would get simply extended (via a vpath command).
#  Hence we create local copies with unique names in order to be
#  able to include application's documentation.)
APPDIR_DELIMITER = ~
FEAT2_APP_MODULES = \
	$(foreach file, $(FEAT2_APP_MODULES_WITH_PATH), \
		$(basename $(notdir $(file)))$(APPDIR_DELIMITER)$(word 4, $(subst /, ,$(dir $(file)))).f90)

# CSS-file for LaTeX
DEFINITIONS_FILE = definitions.tex



########################################################################
# additional LaTeX files
#
########################################################################

# Name of LaTeX file that includes detailed documentation of each module
TEX_MASTER_FILE_MODULE = modules_dynamic.tex

# Suffix for files containing a detailed documentation of a module
SUFFIX_MODULE = tex


########################################################################
# The targets
#
########################################################################

# Default target

.PHONY: all
all:	help

.PHONY: tex
tex:	$(TEX_MASTER_FILE).tex

.PHONY: dvi
dvi:	tex $(TEX_MASTER_FILE).dvi

.PHONY: pdf
pdf:	dvi $(TEX_MASTER_FILE).pdf
	@echo "$(TEX_MASTER_FILE).pdf successfully created."

.PHONY: ps
ps:	dvi $(TEX_MASTER_FILE).ps
	@echo "$(TEX_MASTER_FILE).ps successfully created."


# source all LaTeX Makefile magic from a shared Makefile
include ../latex.mk

$(TEX_MASTER_FILE).dvi: $(DEFINITIONS_FILE) $(TEX_MASTER_FILE_MODULE)

# create latex file with all required newcommands, newenvironments etc.
$(DEFINITIONS_FILE): $(FORTRANDOC)
	$(FORTRANDOC) --generate-latex-definitions $(DEFINITIONS_FILE)


# Main dependencies of the LaTeX file, also serves to replace all filenames with \input{filename}
INCLUDES = $(shell $(PERL) -ne 'print if (m/^[^%]*\s*\\input/);' $(TEX_MASTER_FILE).tex)
DEPS     = $(INCLUDES:\input{%}=%.tex)


# Create a LaTeX file that includes detailed documentation
# for all FEAT2 kernel modules (via LaTeX \input{}).
$(TEX_MASTER_FILE_MODULE): \
		$(CONFIGURE) \
		$(FEAT2_KERNEL_MODULES:%=%.$(SUFFIX_MODULE)) \
		$(FEAT2_APP_MODULES:%=%.$(SUFFIX_MODULE)) \
		$(DEFINITIONS_FILE)
	-rm -f $(TEX_MASTER_FILE_MODULE);
	@echo "# Creating LaTeX file with references to module documentation...";
	@$(foreach file, $(FEAT2_KERNEL_MODULES) $(FEAT2_APP_MODULES), \
		texfile=$(addsuffix .$(SUFFIX_MODULE), $(file)); \
		(cat $${texfile}; \
		 echo) >> $(TEX_MASTER_FILE_MODULE); )


# Create local copies of application modules
$(FEAT2_APP_MODULES): create_local_copies
.PHONY: create_local_copies
create_local_copies:
	@echo "# Creating local copies of application modules..."
	$(foreach file, $(FEAT2_APP_MODULES_WITH_PATH), \
		appdirname=$(word 4, $(subst /, ,$(dir $(file)))); \
		filenameWOsuffix=$(basename $(notdir $(file))); \
		copy=$${filenameWOsuffix}$(APPDIR_DELIMITER)$${appdirname}.f90; \
		$(copy_file))
	@echo "# Copies created."


.PHONY: clean
clean:	$(TEX_MASTER_FILE).clean
	-$(foreach file, \
	    $(DEPS:%.tex=%.aux) \
	    $(FEAT2_APP_MODULES) \
	    $(addsuffix .$(SUFFIX_MODULE), $(FEAT2_KERNEL_MODULES) $(FEAT2_APP_MODULES)) \
	    $(TEX_MASTER_FILE_MODULE) \
	    definitions.tex styleguide.aux modules_dynamic.aux modules_overview.aux, \
	    $(remove_file))

.PHONY: purge
purge:	$(TEX_MASTER_FILE).clean clean $(TEX_MASTER_FILE).purge


########################################################################
# Implicit rules
#
########################################################################


# Extend search path for Fortran 90 source files to include
# FEAT2 kernel paths
vpath %.f90 $(sort $(dir $(FEAT2_KERNEL_MODULES_WITH_PATH)))


# Extract module documentation from wrapped FEAT2 kernel module
%.f90.$(SUFFIX_MODULE): %.f90 
	$(FORTRANDOC) --tex --output-dir=. $<;



########################################################################
# Auxiliary targets
#
########################################################################

# Function to copy a single file
# (The magic why this works lies within the blank line after the copy command. 
#  This way the remove commands in a foreach-loop are triggered one after another
#  - in separate sub-shells. Not in a single sub-shell command. As this may result
#  on some machines in error messages of type:
#  execvp: rm: Arg list too long)
define copy_file
    cp -p $(file) $${copy}

endef

# Tell make to delete the target of a rule if it has changed and its commands 
# exit with a nonzero exit status (just as it does when it receives a signal).
# By this rule, make will not create an empty .tex file when the java parser
# detects a syntax error in an input file. If we would allow such empty files
# being created, such an error would go undetected in subsequent invocations 
# of make resulting in an incomplete documentation.
.DELETE_ON_ERROR:

# Disable default implicit rules
.SUFFIXES:
