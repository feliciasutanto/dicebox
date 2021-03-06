!***********************************************************************
PROGRAM DICE_EVENT
use omp_lib
use lokalni_fce
use spolecne
use vsechno
!
implicit none
INTEGER,PARAMETER::    MAXJC  = 49
!PRIVATE
CHARACTER(80)::                       NAME
LOGICAL::        ponverze,sidlev,ponverk
INTEGER::        IR0,IR1,IR2,IR3,IR4,ITID,IFLAG,NTOTAL,IREGI,IBIN,ILIN
INTEGER::        ilinc,ip,is,il,i,K,IEV,STEPS,IPFI,IBFI,ILFI,IPIN,ISUB
REAL::           U,dummy,SPFI,DMIX2,SIGN,SPIN
real,dimension(:,:),allocatable::     sall
integer,dimension(:,:,:),allocatable::LEVCON
integer,dimension(:),allocatable::    IRCONc,IRCON
integer,dimension(:,:,:,:),allocatable::ISDIS

double precision,dimension(0:2,-2:2,0:1)::     GACON
double precision,dimension(:,:,:,:),allocatable::  STCON
double precision,dimension(0:2)::     TOTCON
integer,dimension(:,:,:,:),allocatable:: ISCON
real, dimension(0:2,0:20,-2:2,0:1)::  STDIS
real, dimension(0:2,-2:2,0:1)::       GADIS
real, dimension(0:2)::                TOTDIS

real,dimension(:,:),allocatable::    ELQQ,SPQQ,DMQQ,GTOTQQ
integer,dimension(:,:),allocatable:: IPQQ,ICQQ
integer,dimension(:),allocatable::   NR_STEPS

!SHARED
LOGICAL::        lopopgs
INTEGER::        NVLAKEN,NDEAD,NUC,NISOM
integer,dimension(:,:),allocatable:: KONTROLMATRIX,gamma_multiplicita
integer,dimension(:,:,:),allocatable:: intermediate2
integer,dimension(:,:,:,:),allocatable:: intermediate3,XSC_work

real,dimension(:),allocatable::      RADW
real,dimension(:,:),allocatable::    POPTLEV,POPSLEV

!FINAL SINGLE THREAD
real,dimension(:),allocatable::   POPULT,POPERT,POPULS,POPERS
real,dimension(:,:),allocatable:: COVAP,COVAS
real::                            RADWID,RADWDI

!$OMP PARALLEL DEFAULT(PRIVATE) &
!$OMP SHARED(lopopgs,kpopgs,NVLAKEN,NDEAD,NISOM,KONTROLMATRIX,RADW,POPTLEV,POPSLEV,&
!$OMP ISWWR,ISWBN,ISWEL,ISWSP,ISWPA,ISWIC,ISWMX,ISWGT,&
!$OMP NOPTFL,NOPTE1,NOPTM1,NOPTE2,NOPTDE,LMODE,LDENP,&
!$OMP NREAL, NEVENTS, NUMLEV, NSUB,&
!$OMP NGIGE,ER,W0,SIG,NGIGM,ERM,WM0,SIGM,ETR,NGIGE2,ERE,WE0,SIGE,&
!$OMP DEG,DMG,QEL,FERMC,EK0,EGZERO,&
!$OMP DIPELO,DIPEHI,DIPSUP,DIPSLP,DIPZER,&
!$OMP EZERO,DEL,TEMPER,ASHELL,AMASS,ZNUM,PAIRING,&
!$OMP ASHELL09,DEL09,TEMPER09,EZERO09,PAIRING09,&
!$OMP DENPPC,DENPA0,DENPA1,DENPA2,&
!$OMP DENPL,DENPU,DENPA,DENPB,DENPC,DENPD,&
!$OMP BN,SPINc,IPINC,NOPTCS,NLINC,CAPFR,&
!$OMP XRAYK,XRAYL,NENT,ELENT,CONVT,NENK,ELENK,CONVK,&
!$OMP ECRIT,EALL,max_decays,max_spin,&
!$OMP ndis,endis,dekod,denum,delev,despin,deparity,deltx,&
!$OMP sal,errsal,alpha,ponv,ponvk,elowlev,elowsp,ilowip,isbspin,ityp,nddd,&
!$OMP TABENLD,TABLD,NLD,&
!$OMP NBIN,DELTA,gamma_multiplicita,N_MSC_FS,MIN_MULTIPLICITA,MAX_MULTIPLICITA,MSC_FS,BIN_WIDTH,&
!$OMP intermediate2,intermediate3,XSC_work)
      ITID = OMP_GET_THREAD_NUM()
      IFLAG=0
      U=0.
!$OMP BARRIER
      IF (ITID.EQ.0) THEN
!******initial reading**************************************************
        CALL get_command_argument(1, NAME)
        IF (LEN_TRIM(NAME).EQ.0) THEN
          STOP 'Invalid input: need an input name as the first argument'
        ENDIF
        NAME=TRIM(NAME)
        INQUIRE(FILE=NAME, EXIST=ponverze)
        IF (.not.ponverze) THEN
          STOP 'Invalid input: file not found'
        ENDIF
        CALL READ_EV(NAME,lopopgs,KONTROLMATRIX)
!******adjustace*nbin***************************************************
        CALL ADJUST_NBIN(SPINC(1),NBIN)
        NVLAKEN=OMP_GET_NUM_THREADS()
        if (.not.allocated(gamma_multiplicita)) then
         allocate(gamma_multiplicita(1:NREAL*NSUB,0:MAX_MULTIPLICITA))
        endif
        DO NUC=1,NREAL*NSUB
          DO I=0,MAX_MULTIPLICITA
            gamma_multiplicita(NUC,I)=0
          ENDDO
        ENDDO
        if (.not.allocated(intermediate2)) then
         allocate(intermediate2(1:N_MSC_FS,1:NREAL*NSUB,0:INT(BN/BIN_WIDTH)))
        endif 
        if (.not.allocated(intermediate3)) then
         allocate(intermediate3(1:N_MSC_FS,1:NREAL*NSUB,0:INT(BN/BIN_WIDTH),0:INT(BN/BIN_WIDTH)))
        endif 
        if (.not.allocated(XSC_work)) then
         allocate(XSC_work(1:N_MSC_FS,1:NREAL*NSUB,MIN_MULTIPLICITA:MAX_MULTIPLICITA,0:INT(BN/BIN_WIDTH)))
        endif 
        CALL CNTRLMTRX(KONTROLMATRIX,4,NREAL)  !should be OK
        CALL INICIALIZACE(NDEAD,NISOM,RADW,POPTLEV,POPSLEV)
!        IR0=KONTROLMATRIX(1,NREAL)
        IF (LMODE.EQ.1) THEN
          CALL GENERATE_GOE_EIGEN_VAL(IR1,700,IFLAG,U) !Maximum allowed dimension (2nd parameter) is 1000
        ENDIF
      ENDIF
!$OMP BARRIER
        if (.not.allocated(ELQQ)) then
          allocate(ELQQ(1:NEVENTS,0:126))
        endif
        if (.not.allocated(SPQQ)) then
          allocate(SPQQ(1:NEVENTS,0:126))
        endif
        if (.not.allocated(IPQQ)) then
          allocate(IPQQ(1:NEVENTS,0:126))
        endif
        if (.not.allocated(ICQQ)) then
          allocate(ICQQ(1:NEVENTS,0:126))
        endif
        if (.not.allocated(DMQQ)) then
          allocate(DMQQ(1:NEVENTS,0:126))
        endif
        if (.not.allocated(GTOTQQ)) then
          allocate(GTOTQQ(1:NEVENTS,0:126))
        endif
        if (.not.allocated(NR_STEPS)) then
          allocate(NR_STEPS(1:NEVENTS))
        endif
!$OMP DO SCHEDULE(DYNAMIC)
      DO NUC=1,NREAL
       IR1=KONTROLMATRIX(1,NUC) !level scheme
       IR2=KONTROLMATRIX(2,NUC) !radiation widths in form of precursors and low-lying intensity fluctuations
       IR3=KONTROLMATRIX(3,NUC) !MC of cascades - actual search for the final state
       IR4=KONTROLMATRIX(4,NUC) !MC of cascades - the seed for a) mixing of primaries b) "coin flip" of internal conversion
!
       CALL LEVELSCH (IR1,NUC,IFLAG,NTOTAL,ITID,SPINC(1),U,LEVCON)
       CALL GERMS(IR2,NTOTAL,NDDD,IRCONc,IRCON)
!      Intensities of low-lying transitions can fluctuate
       CALL READ_INT(sall,IFLAG,U,IR2)
       DO ISUB=1,NSUB !TODO alokace a pocitani pozorovatelnych
!
!      The following DO loop serves for computing of mixing ratios
!      delta for primary transitions (E2 admixture is probably not
!      very important, so this is done in a very simple way - and
!      probably not fully correctly in the case NLINc=2)
!
        if (.not.allocated(ISDIS)) then
         allocate(ISDIS(0:NLINc,1:20,0:ISUBSC(max_spin),0:1))
        endif 
        DO ilinc=1,nlinc
         DO ip=0,1
          DO is=0,8
           DO il=1,NDIS(is,ip)
            DO i=1,100
             dummy=ran0(IR4)
            ENDDO
            isdis(ilinc,il,is,ip)=IR4
           ENDDO
          ENDDO
         ENDDO
        ENDDO
!
!     Here, the procedure 'WIDTHS' is called in order to evaluate a total
!     radiative width and proper values of STDISp.
!
        if (.not.allocated(STCON)) then
         allocate(STCON(0:2,0:NBIN,-2:2,0:1))
        endif 
        if (.not.allocated(ISCON)) then
         allocate(ISCON(0:2,0:NBIN,-2:2,0:1))
        endif 
        IREGI=0
        IBIN=1
        ILIN=1
        RADW(ISUB+(NUC-1)*NSUB)=0.
!
        DO ILINc=1,NLINc
          CALL WIDTHS_R(ILINc,IPINC,SPINC(ILINc),IBIN,ILIN,TOTCON,STCON,GACON,ISCON,TOTDIS,STDIS,GADIS,&
                        ISDIS,LEVCON,IRCON,IRCONc,IFLAG,U,IREGI,EIN,EFI)
        ENDDO
        DO ILINc=1,NLINc
           RADW(ISUB+(NUC-1)*NSUB)=RADW(ISUB+(NUC-1)*NSUB)+sngl(TOTCON(ILINc))+TOTDIS(ILINc)
        ENDDO
        IREGI=0
        IBIN=1
        ILIN=1
!        write(*,*) 'cascading starting'
!
!       The master DO-loop
        DO IEV=1,NEVENTS
          IF (MOD(IEV-1,10000).EQ.0) WRITE(*,5410) ITID,IEV
 5410     FORMAT('+',21X,I6,2X,I10)
          ponverze=.FALSE.
          ponverk=.FALSE.
          sidlev=.FALSE.
          EIN=BN
          STEPS=1
!
!         Determination of spin of capture state
          ILINc=1
          ELQQ(IEV,0)=BN
          SPQQ(IEV,0)=SPINc(ILINc)
          IPQQ(IEV,0)=IPINc
          GTOTQQ(IEV,0)=RADW(ISUB+(NUC-1)*NSUB)
          IREGI=0
          IBIN=1
          ILIN=1
          CALL ONESTEP(ILINc,IPINC,SPINC(ILINc),IBIN,ILIN,TOTCON,STCON,GACON,ISCON,TOTDIS,STDIS,GADIS,&
                       ISDIS,IPFI,SPFI,IBFI,ILFI,DMIX2,sign,IR3,IR4,LEVCON,sall,U,IFLAG,EIN,EFI,IREGI,&
                       ponverze,ponverk,IRCON,IRCONc)
!          WRITE(*,*) '..'
          DO WHILE (EFI.GT.0.)
            ELQQ(IEV,steps)=EFI
            SPQQ(IEV,steps)=SPFI
            IPQQ(IEV,steps)=IPFI
            DMQQ(IEV,steps)=sign*sqrt(dmix2)
            IF (IREGI.GT.0) THEN
              do I=1,numlev
                if (efi.eq.elowlev(I)) then
                  poptlev(I,ISUB+(NUC-1)*NSUB)=poptlev(I,ISUB+(NUC-1)*NSUB)+1.
                  if (.NOT.sidlev) then
                    popslev(I,ISUB+(NUC-1)*NSUB)=popslev(I,ISUB+(NUC-1)*NSUB)+1.
                    sidlev=.TRUE.
                  endif
                endif
              enddo
            ENDIF
            if (ponverze) then
              if (ponverk) then
                ICQQ(IEV,steps)=1
              else
                ICQQ(IEV,steps)=2
              endif
            else
              ICQQ(IEV,steps)=0
            endif
            ponverze=.FALSE.
            ponverk=.FALSE.
            IPIN=IPFI
            SPIN=SPFI
            IBIN=IBFI
            ILIN=ILFI
            IF (IREGI.LT.2) THEN
              CALL WIDTHS_R(0,IPIN,SPIN,IBIN,ILIN,TOTCON,STCON,GACON,ISCON,TOTDIS,STDIS,GADIS,ISDIS,LEVCON,&
                            IRCON,IRCONc,IFLAG,U,IREGI,EIN,EFI)
              IF ((SNGL(TOTCON(0))+TOTDIS(0)).LE.0.) THEN
                NDEAD=NDEAD+1
                GO TO 5
              ENDIF
            ENDIF
            if (iregi.eq.2) then 
              if (denum(dekod(ilfi,isubsc(spfi),ipfi)).eq.0) then
                NISOM=NISOM+1
                !WRITE(*,*) 'so you declared isomeric state that does not decay'
                go to 6
              endif
            endif
            GTOTQQ(IEV,steps)=SNGL(TOTCON(0))+TOTDIS(0)
            STEPS=STEPS+1
            CALL ONESTEP(0,IPIN,SPIN,IBIN,ILIN,TOTCON,STCON,GACON,ISCON,TOTDIS,STDIS,GADIS,ISDIS,IPFI,SPFI,&
                IBFI,ILFI,dmix2,sign,IR3,IR4,LEVCON,sall,U,IFLAG,EIN,EFI,IREGI,ponverze,ponverk,IRCON,IRCONc)
          ENDDO  !WHILE EFI
   6      ELQQ(IEV,steps)=EFI
          SPQQ(IEV,steps)=SPFI
          IPQQ(IEV,steps)=IPFI
          GTOTQQ(IEV,steps)=0.0
          DMQQ(IEV,steps)=sign*sqrt(dmix2)
!   **** feeding of ground state ****
          if (lopopgs) then
            poptlev(kpopgs,ISUB+(NUC-1)*NSUB)=poptlev(kpopgs,ISUB+(NUC-1)*NSUB)+1.
            if (.NOT.sidlev) then
              popslev(kpopgs,ISUB+(NUC-1)*NSUB)=popslev(kpopgs,ISUB+(NUC-1)*NSUB)+1.
            endif
          endif
          if (ponverze) then
            if (ponverk) then
              ICQQ(IEV,steps)=1
            else
              ICQQ(IEV,steps)=2
            endif
          else
            ICQQ(IEV,steps)=0
          endif
          ponverze=.FALSE.
          ponverk=.FALSE.
          NR_STEPS(IEV)=STEPS
   5      CONTINUE
        ENDDO
!       writin the cascades
!        write(*,*) 'cascading ended'
        CALL SPECTRA((ISUB+(NUC-1)*NSUB),ELQQ,SPQQ,DMQQ,IPQQ,ICQQ,NR_STEPS,intermediate2,intermediate3,XSC_work,gamma_multiplicita)
        IF (ISWWR.EQ.1) CALL DO_IT((ISUB+(NUC-1)*NSUB),ELQQ,SPQQ,DMQQ,IPQQ,ICQQ,GTOTQQ,NR_STEPS,ITID)
        IRCONc(1)=IR3 !TODO staci takhle z hlediska reprodukovatelnosti?
       ENDDO !DO ISUB=1,NSUB
      ENDDO !DO NUC=1,NREAL
!$OMP END DO
!$OMP END PARALLEL
      CALL WR_SPECTRA (intermediate2,intermediate3,XSC_work,gamma_multiplicita)
      RADWID=0.
      RADWDI=0.
      DO NUC=1,NREAL*NSUB
        RADWID=RADWID+RADW(NUC)
        RADWDI=RADWDI+RADW(NUC)*RADW(NUC)
      ENDDO
      RADWID=RADWID/(NREAL*NSUB)
      RADWDI=RADWDI/(NREAL*NSUB)-RADWID*RADWID
!TODO vysledky s populacemi nizkolezicich hladin
      allocate(POPULT(1:NUMLEV))
      allocate(POPERT(1:NUMLEV))
      allocate(POPULS(1:NUMLEV))
      allocate(POPERS(1:NUMLEV))
      allocate(COVAP(1:NUMLEV,1:NUMLEV))
      allocate(COVAS(1:NUMLEV,1:NUMLEV))
      DO K=1,NUMLEV
        POPULT(K)=0.0
        POPERT(K)=0.0
        POPULS(K)=0.0
        POPERS(K)=0.0
        DO I=1,NUMLEV
          COVAP(K,I)=0.0
          COVAS(K,I)=0.0
        ENDDO
      ENDDO
      DO K=1,NUMLEV
        DO NUC=1,NREAL*NSUB
          POPULT(K)=POPULT(K)+POPTLEV(K,NUC)/FLOAT(NEVENTS)
          POPULS(K)=POPULS(K)+POPSLEV(K,NUC)/FLOAT(NEVENTS)
          POPERT(K)=POPERT(K)+(POPTLEV(K,NUC)/FLOAT(NEVENTS))**2
          POPERS(K)=POPERS(K)+(POPSLEV(K,NUC)/FLOAT(NEVENTS))**2
          DO I=1,K
            COVAP(K,I)=COVAP(K,I)+POPTLEV(K,NUC)/FLOAT(NEVENTS)*POPTLEV(I,NUC)/FLOAT(NEVENTS)
            COVAS(K,I)=COVAS(K,I)+POPSLEV(K,NUC)/FLOAT(NEVENTS)*POPSLEV(I,NUC)/FLOAT(NEVENTS)
          ENDDO
        ENDDO
        POPULT(K)=POPULT(K)/(NREAL*NSUB)
        POPULS(K)=POPULS(K)/(NREAL*NSUB)
        POPERT(K)=POPERT(K)/(NREAL*NSUB)-POPULT(K)**2
        POPERS(K)=POPERS(K)/(NREAL*NSUB)-POPULS(K)**2
        DO I=1,K
          COVAP(K,I)=COVAP(K,I)/(NREAL*NSUB)-POPULT(K)*POPULT(I)
          COVAS(K,I)=COVAS(K,I)/(NREAL*NSUB)-POPULS(K)*POPULS(I)
        ENDDO
        !write(*,*) elowlev(k), popult(k), (poptlev(k,i), i=1,NREAL)
      ENDDO

      CALL WRITE_DICE_PRO(RADWID,RADWDI,NUC,NDEAD,NISOM,POPULT,POPULS,POPERT,POPERS,COVAP,COVAS)
      END PROGRAM DICE_EVENT
!
!**********************************************************************
      SUBROUTINE LABELS(NOPTDE,NOPTE1,NOPTM1,NOPTE2,tdens,tsfe1,tsfm1,tsfe2)
!************************************************************************
        CHARACTER*8 tdens,tsfe1,tsfm1,tsfe2
!
!    Conversion number of model to string label of the model
!
      tdens='???'
      tsfe1='???'
      tsfm1='???'
      tsfe2='???'

      IF (noptde.EQ.0) THEN
        tdens='CTF'
      ELSEIF (noptde.EQ.1) THEN
        tdens='BSFG'
      ENDIF

      IF (nopte1.EQ.0) THEN
        tsfe1='SP'
      ELSEIF (nopte1.EQ.1) THEN
        tsfe1='BA'
      ELSEIF (nopte1.EQ.2) THEN
        tsfe1='TD-BA'
      ELSEIF (nopte1.EQ.3) THEN
        tsfe1='KMF+Chr'
      ELSEIF (nopte1.EQ.4) THEN
        tsfe1='KMF'
      ELSEIF (nopte1.EQ.5) THEN
        tsfe1='Chr'
      ELSEIF (nopte1.EQ.6) THEN
        tsfe1='Chr-phD'
      ELSEIF (nopte1.EQ.7) THEN
        tsfe1='Kop'
      ELSEIF (nopte1.EQ.8) THEN
        tsfe1='8'
      ELSEIF (nopte1.EQ.9) THEN
        tsfe1='9'
      ELSEIF (nopte1.EQ.10) THEN
        tsfe1='10'
      ELSEIF (nopte1.EQ.11) THEN
        tsfe1='11'
      ENDIF

      IF (noptm1.EQ.0) THEN
        tsfm1='SP'
      ELSEIF (noptm1.EQ.1) THEN
        tsfm1='BA'
      ELSEIF (noptm1.EQ.2) THEN
        tsfm1='BAonSP'
      ELSEIF (noptm1.EQ.3) THEN
        tsfm1='Pow'
      ELSEIF (noptm1.EQ.4) THEN
        tsfm1='4'
      ENDIF

      IF (nopte2.EQ.0) THEN
        tsfe2='SP'
      ELSEIF (nopte2.EQ.1) THEN
        tsfe2='BA'
      ENDIF

      END SUBROUTINE LABELS

