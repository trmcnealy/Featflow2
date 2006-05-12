      BLOCK DATA ZVALUE1

      IMPLICIT NONE

      INCLUDE 'cmem.inc'
      INCLUDE 'cmem2.inc'
      INCLUDE 'cout.inc'
      INCLUDE 'cerr.inc'
      
      INCLUDE 'cbasictria.inc'
      INCLUDE 'ctria.inc'
      
      INCLUDE 'cbasicmg.inc'

      INTEGER NBLOCA, NBLOCB, NBLOCF
      INTEGER NBLA1, NBLB1, NBLF1
      
      PARAMETER (NBLOCA=1,NBLOCB=2,NBLOCF=2)
      PARAMETER (NBLA1=NBLOCA*NNLEV,NBLB1=NBLOCB*NNLEV,
     *           NBLF1=NBLOCF*NNLEV)

      DATA M/2/,MT/2/,MKEYB/5/,MTERM/6/,IER/0/,ICHECK/1/
      DATA MERR/11/,MPROT/12/,MSYS/13/,MTRC/14/,IRECL8/512/
      DATA SUB/'MAIN  '/
      DATA FMT/'(3D25.16)','(5E16.7)','(6I12)'/
      DATA CPARAM/120*' '/
      DATA NEL/0/,NVT/0/,NMT/0/,NVE/0/,NBCT/0/,NVEL/0/,NVBD/0/
      DATA LCORVG/0/,LCORMG/0/,LVERT/0/,LMID/0/,LADJ/0/,LVEL/0/,LMEL/0/,
     *     LNPR/0/,LMM/0/,LVBD/0/,LEBD/0/,LBCT/0/,LVBDP/0/,LMBDP/0/
      DATA KTYPE/NNARR*0/,KLEN/NNARR*0/,KLEN8/NNARR*0/,IFLAG/0/
C
      END
      
