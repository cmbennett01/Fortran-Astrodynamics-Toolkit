!*****************************************************************************************
    module ephemeris_module
!*****************************************************************************************
!****h* FAT/ephemeris_module
!
!  NAME
!    ephemeris_module
!
!  DESCRIPTION
!    For reading the JPL planetary and lunar ephemerides.
!
!  SEE ALSO
!    [1] ftp://ssd.jpl.nasa.gov/pub/eph/planets/fortran/
!
!*****************************************************************************************

    use kind_module,    only: wp

    private

    integer,parameter,public :: nmax = 1000
    integer,parameter :: oldmax = 400

    !  nrecl=1 if "recl" in the open statement is the record length in s.p. words
    !  nrecl=4 if "recl" in the open statement is the record length in bytes
    integer,parameter :: nrecl = 4 

    !  namfil is the external name of the binary ephemeris file
    character(len=80),parameter :: namfil='../eph/JPLEPH_2000-2100.405'

    !  ksize must be set by the user according to the ephemeris to be read
    !  for  de200, set ksize to 1652
    !  for  de405, set ksize to 2036
    !  for  de406, set ksize to 1456
    !  for  de414, set ksize to 2036
    !  for  de418, set ksize to 2036
    !  for  de421, set ksize to 2036
    !  for  de422, set ksize to 2036
    !  for  de423, set ksize to 2036
    !  for  de424, set ksize to 2036
    !  for  de430, set ksize to 2036
    integer,parameter :: ksize = 2036

    !ephhdr
    real(wp) :: cval(nmax)
    real(wp) :: ss(3)
    real(wp) :: au,emrat
    integer  :: ncon,numde,ipt(3,13) ! ipt(39)
    
    !stcomx
    !
    !    km   logical flag defining physical units of the output states.
    !             km = .true.  : km and km/sec
    !             km = .false. : au and au/day
    !         for nutations and librations.  angle unit is always radians.
    ! 
    !  bary   logical flag defining output center.
    !         only the 9 planets are affected.
    !                  bary = .true.  : center is solar-system barycenter
    !                  bary = .false. : center is sun
    ! 
    ! pvsun   dp 6-word array containing the barycentric position and
    !         velocity of the sun.
    !
    logical  :: km = .true.   ! use km and km/s
    logical  :: bary = .false.
    real(wp),dimension(6) :: pvsun = 0.0_wp

    !chrhdr
    character(len=6),dimension(14,3) :: ttl = ''
    character(len=6),dimension(nmax) :: cnam = ''
    
    !public routines:
    public :: pleph
    public :: const
    public :: test_ephemeris

    contains
!*****************************************************************************************
    
!*****************************************************************************************
!****f* ephemeris_module/pleph
! 
!  NAME
!    pleph
!
!  DESCRIPTION
!  this subroutine reads the jpl planetary ephemeris
!  and gives the position and velocity of the point 'ntarg'
!  with respect to 'ncent'.
! 
!  calling sequence parameters:
! 
!    et = d.p. julian ephemeris date at which interpolation
!         is wanted.
! 
!  ntarg = integer number of 'target' point.
! 
!  ncent = integer number of center point.
! 
!         the numbering convention for 'ntarg' and 'ncent' is:
! 
!             1 = mercury           8 = neptune
!             2 = venus             9 = pluto
!             3 = earth            10 = moon
!             4 = mars             11 = sun
!             5 = jupiter          12 = solar-system barycenter
!             6 = saturn           13 = earth-moon barycenter
!             7 = uranus           14 = nutations (longitude and obliq)
!                                  15 = librations, if on eph file
! 
!          (if nutations are wanted, set ntarg = 14. for librations,
!           set ntarg = 15. set ncent=0.)
! 
!   rrd = output 6-word d.p. array containing position and velocity
!         of point 'ntarg' relative to 'ncent'. the units are au and
!         au/day. for librations the units are radians and radians
!         per day. in the case of nutations the first four words of
!         rrd will be set to nutations and rates, having units of
!         radians and radians/day.
! 
!         the option is available to have the units in km and km/sec.
!         for this, set km=.true. in the stcomx common block.
!
!  SOURCE

    subroutine pleph ( et, ntarg, ncent, rrd )

    implicit none  

    real(wp),intent(in) :: et
    integer,intent(in) :: ntarg
    integer,intent(in) :: ncent
    real(wp),dimension(6),intent(out) :: rrd

    real(wp),dimension(2) :: et2        
    real(wp) :: pv(6,13)
    real(wp) :: pvst(6,11),pnut(4)
    integer :: list(12),i,j,k
    logical :: bsave

    logical :: first = .true.    !a saved variable

    real(wp),dimension(2),parameter :: zips = 0.0_wp

    ! initialize et2 for 'state' and set up component count

    et2(1)=et
    et2(2)=0.0_wp

    if (first) then
        call state(zips,list,pvst,pnut)  !initialize the ephemeris
        first=.false.
    end if
    
    if (ntarg == ncent) then
        rrd = 0.0_wp   !jw
        return
    end if

    list = 0        !jw

    ! check for nutation call

    if (ntarg==14) then
        if (ipt(2,12)>0) then            !ipt(35)
            list(11)=2
            call state(et2,list,pvst,pnut)
            do i=1,4
                rrd(i)=pnut(i)
            enddo
            rrd(5) = 0.0_wp
            rrd(6) = 0.0_wp
            return
        else
            do i=1,4
                rrd(i)=0.0_wp
            enddo
            write(6,'(A)') ' *****  no nutations on the ephemeris file  *****'
            stop
        endif
    end if

    ! check for librations

    rrd = 0.0_wp

    if (ntarg==15) then
        if (ipt(2,13)>0) then            !ipt(38)
            list(12)=2
            call state(et2,list,pvst,pnut)
            do i=1,6
                rrd(i)=pvst(i,11)
            enddo
            return
        else
            write(6,'(A)') ' *****  no librations on the ephemeris file  *****'
            stop
        endif
    end if

    ! force barycentric output by 'state'

    bsave=bary
    bary=.true.

    ! set up proper entries in 'list' array for state call

    do i=1,2
        k=ntarg
        if (i == 2) k=ncent
        if (k <= 10) list(k)=2
        if (k == 10) list(3)=2
        if (k == 3)  list(10)=2
        if (k == 13) list(3)=2
    enddo

    ! make call to state

    call state(et2,list,pvst,pnut)

    do i=1,10
        do j = 1,6
            pv(j,i) = pvst(j,i)
        enddo
    enddo

    if (ntarg == 11 .or. ncent == 11) then
        do i=1,6
            pv(i,11)=pvsun(i)
        enddo
    endif

    if (ntarg == 12 .or. ncent == 12) then
        do i=1,6
            pv(i,12)=0.0_wp
        enddo
    endif

    if (ntarg == 13 .or. ncent == 13) then
        do i=1,6
            pv(i,13) = pvst(i,3)
        enddo
    endif

    if (ntarg*ncent == 30 .and. ntarg+ncent == 13) then
        do i=1,6
            pv(i,3)=0.0_wp
        enddo
        go to 99
    endif

    if (list(3) == 2) then
        do i=1,6
            pv(i,3)=pvst(i,3)-pvst(i,10)/(1.0_wp+emrat)
        enddo
    endif

    if (list(10) == 2) then
        do i=1,6
            pv(i,10) = pv(i,3)+pvst(i,10)
        enddo
    endif

99  do i=1,6
        rrd(i)=pv(i,ntarg)-pv(i,ncent)
    enddo

    bary=bsave

    end subroutine pleph
!*****************************************************************************************
    
!*****************************************************************************************
!****f* ephemeris_module/interp
! 
!  NAME
!    interp
!
!  DESCRIPTION
!   this subroutine differentiates and interpolates a
!   set of chebyshev coefficients to give position and velocity
!
!   calling sequence parameters:
!
!     input:
!
!       buf   1st location of array of d.p. chebyshev coefficients of position
!
!         t   t(1) is dp fractional time in interval covered by
!             coefficients at which interpolation is wanted
!             (0 <= t(1) <= 1).  t(2) is dp length of whole
!             interval in input time units.
!
!       ncf   # of coefficients per component
!
!       ncm   # of components per set of coefficients
!
!        na   # of sets of coefficients in full array
!             (i.e., # of sub-intervals in full interval)
!
!        ifl  integer flag: =1 for positions only
!                           =2 for pos and vel
!
!     output:
!
!       pv   interpolated quantities requested.  dimension
!             expected is pv(ncm,ifl), dp.
!
!  SOURCE

    subroutine interp(buf,t,ncf,ncm,na,ifl,pv)
    
      implicit real(wp) (a-h,o-z)

      save

      real(wp) buf(ncf,ncm,*),t(2),pv(ncm,*),pc(18),vc(18)

      data np/2/
      data nv/3/
      data twot/0.0_wp/
      data pc(1),pc(2)/1.0_wp,0.0_wp/
      data vc(2)/1.0_wp/
!
!       entry point. get correct sub-interval number for this set
!       of coefficients and then get normalized chebyshev time
!       within that subinterval.
!
      dna=dble(na)
      dt1=int(t(1))
      temp=dna*t(1)
      l=idint(temp-dt1)+1

!         tc is the normalized chebyshev time (-1 <= tc <= 1)

      tc=2.0_wp*(mod(temp,1.0_wp)+dt1)-1.0_wp

!       check to see whether chebyshev time has changed,
!       and compute new polynomial values if it has.
!       (the element pc(2) is the value of t1(tc) and hence
!       contains the value of tc on the previous call.)

      if (tc/=pc(2)) then
        np=2
        nv=3
        pc(2)=tc
        twot=tc+tc
      endif
!
!       be sure that at least 'ncf' polynomials have been evaluated
!       and are stored in the array 'pc'.
!
      if (np<ncf) then
        do i=np+1,ncf
            pc(i)=twot*pc(i-1)-pc(i-2)
        end do
        np=ncf
      endif
!
!       interpolate to get position for each component
!
      do i=1,ncm
          pv(i,1)=0.0_wp
          do j=ncf,1,-1
              pv(i,1)=pv(i,1)+pc(j)*buf(j,i,l)
          end do
      end do
      if (ifl<=1) return
!
!       if velocity interpolation is wanted, be sure enough
!       derivative polynomials have been generated and stored.
!
      vfac=(dna+dna)/t(2)
      vc(3)=twot+twot
      if (nv<ncf) then
        do i=nv+1,ncf
            vc(i)=twot*vc(i-1)+pc(i-1)+pc(i-1)-vc(i-2)
        end do
        nv=ncf
      endif
!
!       interpolate to get velocity for each component
!
      do i=1,ncm
          pv(i,2)=0.0_wp
          do j=ncf,2,-1
              pv(i,2)=pv(i,2)+vc(j)*buf(j,i,l)
          end do
          pv(i,2)=pv(i,2)*vfac
      end do

    end subroutine interp
!*****************************************************************************************

!*****************************************************************************************
!****f* ephemeris_module/split
! 
!  NAME
!    split
!
!  DESCRIPTION
!    this subroutine breaks a d.p. number into a d.p. integer
!    and a d.p. fractional part.
!
!    calling sequence parameters:
!
!    tt = d.p. input number
!
!    fr = d.p. 2-word output array.
!         fr(1) contains integer part
!         fr(2) contains fractional part
!
!         for negative input numbers, fr(1) contains the next
!         more negative integer; fr(2) contains a positive fraction.
!
!  SOURCE

    subroutine split(tt,fr)

    implicit none

    real(wp),intent(in) :: tt
    real(wp),dimension(2),intent(out) :: fr

    ! get integer and fractional parts

    fr(1)=int(tt)
    fr(2)=tt-fr(1)

    if (tt>=0.0_wp .or. fr(2)==0.0_wp) return

    ! make adjustments for negative input number

    fr(1)=fr(1)-1.0_wp
    fr(2)=fr(2)+1.0_wp

    end subroutine split
!*****************************************************************************************

!*****************************************************************************************
!****f* ephemeris_module/state
! 
!  NAME
!    state
!
!  DESCRIPTION
!    this subroutine reads and interpolates the jpl planetary ephemeris file
!
!     calling sequence parameters:
!
!     input:
!
!         et2   dp 2-word julian ephemeris epoch at which interpolation
!               is wanted.  any combination of et2(1)+et2(2) which falls
!               within the time span on the file is a permissible epoch.
!
!                a. for ease in programming, the user may put the
!                   entire epoch in et2(1) and set et2(2)=0.
!
!                b. for maximum interpolation accuracy, set et2(1) =
!                   the most recent midnight at or before interpolation
!                   epoch and set et2(2) = fractional part of a day
!                   elapsed between et2(1) and epoch.
!
!                c. as an alternative, it may prove convenient to set
!                   et2(1) = some fixed epoch, such as start of integration,
!                   and et2(2) = elapsed interval between then and epoch.
!
!        list   12-word integer array specifying what interpolation
!               is wanted for each of the bodies on the file.
!
!                         list(i)=0, no interpolation for body i
!                                =1, position only
!                                =2, position and velocity
!
!               the designation of the astronomical bodies by i is:
!
!                         i = 1: mercury
!                           = 2: venus
!                           = 3: earth-moon barycenter
!                           = 4: mars
!                           = 5: jupiter
!                           = 6: saturn
!                           = 7: uranus
!                           = 8: neptune
!                           = 9: pluto
!                           =10: geocentric moon
!                           =11: nutations in longitude and obliquity
!                           =12: lunar librations (if on file)
!
!     output:
!
!          pv   dp 6 x 11 array that will contain requested interpolated
!               quantities (other than nutation, stored in pnut).  
!               the body specified by list(i) will have its
!               state in the array starting at pv(1,i).  
!               (on any given call, only those words in 'pv' which are 
!                affected by the  first 10 'list' entries, and by list(12)
!                if librations are on the file, are set.  
!                the rest of the 'pv' array is untouched.)  
!               the order of components starting in pv(1,i) is: x,y,z,dx,dy,dz.
!
!               all output vectors are referenced to the earth mean
!               equator and equinox of j2000 if the de number is 200 or
!               greater; of b1950 if the de number is less than 200. 
!
!               the moon state is always geocentric; the other nine states 
!               are either heliocentric or solar-system barycentric, 
!               depending on the setting of common flags (see below).
!
!               lunar librations, if on file, are put into pv(k,11) if
!               list(12) is 1 or 2.
!
!         pnut  dp 4-word array that will contain nutations and rates,
!               depending on the setting of list(11).  the order of
!               quantities in pnut is:
! 
!                 d psi  (nutation in longitude)
!                 d epsilon (nutation in obliquity)
!                 d psi dot
!                 d epsilon dot
!
!  SOURCE

      subroutine state(et2,list,pv,pnut)
      
      implicit real(wp) (a-h,o-z)

      save 
      
      dimension et2(2),pv(6,11),pnut(4),t(2),pjd(4),buf(1500)

      integer,dimension(12) :: list
      integer :: nrfile
      integer :: istat
      
      logical :: first = .true.

    !1st time in, get pointer data, etc., from eph file

      if (first) then
        
          first=.false.

          irecsz=nrecl*ksize
          ncoeffs=ksize/2

            open(newunit=nrfile,     &
                 file=namfil,         &
                 access='direct',     &
                 form='unformatted', &
                 recl=irecsz,         &
                 status='old')

          read(nrfile,rec=1) ttl,(cnam(k),k=1,oldmax),ss,ncon,au,emrat,&
                              ((ipt(i,j),i=1,3),j=1,12),numde,(ipt(i,13),i=1,3) &
                              ,(cnam(l),l=oldmax+1,ncon)

          if (ncon <= oldmax)then
            read(nrfile,rec=2)(cval(i),i=1,oldmax)
          else
            read(nrfile,rec=2)(cval(i),i=1,ncon)
          endif

          nrl=0

      endif

      if (et2(1) == 0.0_wp) return   ! this is when this routine
                                     ! is called just to initialize the files

      s=et2(1)-0.5_wp
      call split(s,pjd(1))
      call split(et2(2),pjd(3))
      pjd(1)=pjd(1)+pjd(3)+0.5_wp
      pjd(2)=pjd(2)+pjd(4)
      call split(pjd(2),pjd(3))
      pjd(1)=pjd(1)+pjd(3)

    ! error return for epoch out of range

      if (pjd(1)+pjd(4)<ss(1) .or. pjd(1)+pjd(4)>ss(2)) then
      
          write(*,198) et2(1)+et2(2),ss(1),ss(2)
 198      format(' ***  requested jed,',f12.2, ' not within ephemeris limits,',2f12.2,'  ***')

          stop
                
      end if

    ! calculate record # and relative time in interval

      nr=idint((pjd(1)-ss(1))/ss(3))+3
      if (pjd(1)==ss(2)) nr=nr-1

        tmp1 = dble(nr-3)*ss(3) + ss(1)
        tmp2 = pjd(1) - tmp1
        t(1) = (tmp2 + pjd(4))/ss(3)

! read correct record if not in core

      if (nr/=nrl) then
        nrl=nr
        read(nrfile,rec=nr,iostat=istat)(buf(k),k=1,ncoeffs)
        if (istat/=0) then
              write(*,'(2f12.2,a80)') et2,'error return in state'
              stop      
        end if
      endif

      if (km) then
         t(2)=ss(3)*86400.0_wp
         aufac=1.0_wp
      else
         t(2)=ss(3)
         aufac=1.0_wp/au
      endif

! interpolate ssbary sun

      call interp(buf(ipt(1,11)),t,ipt(2,11),3,ipt(3,11),2,pvsun)

      do i=1,6
          pvsun(i)=pvsun(i)*aufac
      enddo

! check and interpolate whichever bodies are requested

      do i=1,10
          if (list(i)==0) cycle
          call interp(buf(ipt(1,i)),t,ipt(2,i),3,ipt(3,i),list(i),pv(1,i))
          do j=1,6
           if (i<=9 .and. .not.bary) then
               pv(j,i)=pv(j,i)*aufac-pvsun(j)
           else
               pv(j,i)=pv(j,i)*aufac
           endif
          enddo
     end do

! do nutations if requested (and if on file)

      if (list(11)>0 .and. ipt(2,12)>0)&
       call interp(buf(ipt(1,12)),t,ipt(2,12),2,ipt(3,12),&
       list(11),pnut)

! get librations if requested (and if on file)

      if (list(12)>0 .and. ipt(2,13)>0)&
       call interp(buf(ipt(1,13)),t,ipt(2,13),3,ipt(3,13),&
       list(12),pv(1,11))

    end subroutine state
!*****************************************************************************************

!*****************************************************************************************
!****f* ephemeris_module/const
! 
!  NAME
!    const
!
!  DESCRIPTION
!     this entry obtains the constants from the ephemeris file
!
!     calling seqeunce parameters (all output):
!
!       nam = character*6 array of constant names
!       val = d.p. array of values of constants
!       sss = d.p. jd start, jd stop, step of ephemeris
!         n = integer number of entries in 'nam' and 'val' arrays
!
!  SOURCE

    subroutine const(nam,val,sss,n)

    implicit none

    character(len=6),dimension(:),intent(out) :: nam
    integer,intent(out) :: n
    real(wp),dimension(*),intent(out) :: val
    real(wp),dimension(3),intent(out) :: sss

    save        !... JW : don't know if this is necessary ...

    integer :: i
    real(wp) :: pvst(6,11),pnut(4)
    integer :: list(12)

    real(wp),dimension(2),parameter :: zips = 0.0_wp     

    logical :: first = .true.

    !call state to initialize the ephemeris and read in the constants

    if (first) then
        call state(zips,list,pvst,pnut)  !initialize the ephemeris
        first=.false.
    end if
    
    n=ncon

    do i=1,3
        sss(i)=ss(i)
    enddo

    do i=1,n
        nam(i)=cnam(i)
        val(i)=cval(i)
    enddo

    end subroutine const
!*****************************************************************************************

!*****************************************************************************************
!****f* ephemeris_module/test_ephemeris
!
!  NAME
!    test_ephemeris
!
!  DESCRIPTION
!    Ephemeris test routine.
!
!  NOTES 
!
!    Disclaimer in original source [1]:
!
!     this software and any related materials were created by the
!     california institute of technology (caltech) under a u.s.
!     government contract with the national aeronautics and space
!     administration (nasa). the software is technology and software
!     publicly available under u.s. export laws and is provided "as-is"
!     to the recipient without warranty of any kind, including any
!     warranties of performance or merchantability or fitness for a
!     particular use or purpose (as set forth in united states ucc
!     sections 2312-2313) or for any purpose whatsoever, for the
!     software and related materials, however used.
!
!     in no event shall caltech, its jet propulsion laboratory, or nasa
!     be liable for any damages and/or costs, including, but not
!     limited to, incidental or consequential damages of any kind,
!     including economic damage or injury to property and lost profits,
!     regardless of whether caltech, jpl, or nasa be advised, have
!     reason to know, or, in fact, shall know of the possibility.
!
!     recipient bears all risk relating to quality and performance of
!     the software and any related materials, and agrees to indemnify
!     caltech and nasa for all third-party claims resulting from the
!     actions of recipient in the use of the software.
!
!                version : march 25, 2013
!
!  SEE ALSO
!    [1] testeph.f in the original package: 
!        ftp://ssd.jpl.nasa.gov/pub/eph/planets/fortran/
!
!  SOURCE

    subroutine test_ephemeris()

    implicit none

    character*6 :: nams(nmax)
    character*3 :: alf3
    real(wp) :: del
    real(wp) :: jd
    real(wp) :: r(6)
    real(wp) :: ss(3)
    real(wp) :: vals(nmax)
    real(wp) :: jdepoc
    integer :: nvs,ntarg,nctr,ncoord

    !get some constants from the file:
    call const (nams, vals, ss, nvs)

    jd    = 2451536.5d0        !julian date
    ntarg = 3                !earth
    nctr  = 11                !sun

    write(*,*) 'ntarg   = ', ntarg
    write(*,*) 'nctr    = ', nctr

    if (jd < ss(1) .or. jd > ss(2)) then

        write(*,*) 'error: jed out of bounds.'
        write(*,*) 'jed   = ', jd
        write(*,*) 'ss(1) = ', ss(1)
        write(*,*) 'ss(2) = ', ss(2)

    else

        call  pleph ( jd, ntarg, nctr, r )

        write(*,*) 'et   = ', jd
        write(*,'(1x,a/,*(e30.16,1x/))') 'r    = ', r
        write(*,*) 'rmag = ', norm2(r(1:3))
        write(*,*) '' 

    end if

    end subroutine test_ephemeris
!*****************************************************************************************

!*****************************************************************************************
    end module ephemeris_module
!*****************************************************************************************