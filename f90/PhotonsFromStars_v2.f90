program PhotonsFromStars
  
  ! generate photons emitted by star particles within a given domain

  use module_photon
  use module_utils
  use module_domain
  use module_random
  use module_constants
  use module_ramses

  implicit none
  
  type(domain)    :: emission_domain
  integer         :: narg
  character(2000) :: parameter_file
  real(kind=8),allocatable :: star_pos(:,:),star_age(:),star_mass(:),star_vel(:,:),star_met(:)
  real(kind=8),allocatable :: star_pos2(:,:),star_vel2(:,:)
  integer(kind=4) :: iran
  integer(kind=8) :: i,nstars,nyoung,ilast,j
  real(kind=8) :: minmass,scalar,nu,r1,r2
  type(photon_init),dimension(:),allocatable :: photgrid
  ! for analysis purposes (a posteriori weighting) we want to save the emitter-frame
  ! frequency (here the freq. in the emitting stellar particle's frame)
  real(kind=8), allocatable :: nu_star(:)
  ! SED-related variables
  integer(kind=4) :: sed_nage,sed_nmet,imet,iage
  integer(kind=8) :: nflux,n
  real(kind=8),allocatable :: sed_age(:),sed_met(:),sed_flux(:,:),sweight(:),sed_slope(:,:)
  integer(kind=8), allocatable :: cum_flux_prob(:)
  real(kind=8),allocatable :: star_beta(:) 
  real(kind=8) :: total_flux,photon_flux,minflux,check_flux,f0,beta,betaplus2
  character(2000) :: file
  
  ! --------------------------------------------------------------------------
  ! user-defined parameters - read from section [PhotonsFromStars] of the parameter file
  ! --------------------------------------------------------------------------
  ! --- input / outputs
  character(2000)           :: outputfile = 'PhotICs.dat' ! file to which outputs will be written
  character(2000)           :: repository = './'      ! ramses run directory (where all output_xxxxx dirs are).
  integer(kind=4)           :: snapnum = 1            ! ramses output number to use
  ! --- domain whithin which star particles will be selected (should be within computational domain used for RT). 
  character(10)             :: star_dom_type      = 'sphere'         ! shape type of domain  // default is sphere.
  real(kind=8),dimension(3) :: star_dom_pos       = (/0.5,0.5,0.5/)  ! center of domain [code units]
  real(kind=8)              :: star_dom_rsp       = 0.3              ! radius of spher [code units]
  real(kind=8)              :: star_dom_size      = 0.3              ! size of cube [code units]
  real(kind=8)              :: star_dom_rin       = 0.0              ! inner radius of shell [code units]
  real(kind=8)              :: star_dom_rout      = 0.3              ! outer radius of shell [code units]
  real(kind=8)              :: star_dom_thickness = 0.1              ! thickness of slab [code units]
  ! --- define star particles luminosities (in total nb of photons)
  character(30)             :: weight_type = 'SED'  ! May be 'SED', 'age_step_function' 
  ! SED-option parameters
  character(2000)           :: weight_sed_file = 'F1600.txt' ! file containing weights from SEDs
  
  ! age_step_function-option parameters
  real(kind=8)              :: weight_max_age = 10.0d0       ! stars older than this don't shine [Myr]
  real(kind=8)              :: weight_powlaw_l0_Ang = 1216.  ! F_l = F_0 * (lambda/sed_powlaw_l0)**beta), with F_0 and beta given in tables...

  
  ! --- define how star particles emit (i.e. the star-particle-frame spectral shape)
  character(30)             :: spec_type = 'Gaussian' ! May be 'monochromatic', 'Gaussian', 'PowerLaw' ...   
  ! parameters for spec_type == 'monochromatic'
  real(kind=8)              :: spec_mono_lambda0_Ang = 1215.6701  ! emission wavelength [A] -> this is the parameter read from file. 
  real(kind=8)              :: spec_mono_nu0         = clight/spec_mono_lambda0_Ang*1d8 ! emission frequency [Hz]
  ! parameters for spec_type == 'Gaussian'
  real(kind=8)              :: spec_gauss_lambda0_Ang = spec_mono_lambda0_Ang ! emission wavelength at center [A] -> read from file.
  real(kind=8)              :: spec_gauss_nu0 = clight / spec_gauss_lambda0_Ang * 1d8 ! central frequency [Hz]
  real(kind=8)              :: spec_gauss_velwidth_kms = 10.0                  ! line width in velocity [km/s] -> red from file. 
  ! ------ spec_type == 'PowerLaw' : a power-law fit to continuum of each star particle, vs. its age and met.
  ! (NB: only wavelength range is defined here. The power-law associated to each star particle is read from weights file...)
  real(kind=8)              :: spec_powlaw_lmin_Ang = 1120.    ! min wavelength to sample (should be in the range where fit was made ...)
  real(kind=8)              :: spec_powlaw_lmax_Ang = 1320.    ! max ...
  
  ! --- miscelaneous
  integer(kind=4)           :: nphot   = 1000000      ! number of photons to generate
  integer(kind=4)           :: ranseed = -100         ! seed for random generator
  logical                   :: verbose = .true.
  logical                   :: cosmo = .true.         ! cosmo flag
  ! --------------------------------------------------------------------------

  
  
  ! -------------------- read parameters --------------------
  narg = command_argument_count()
  if(narg .lt. 1)then
     write(*,*)'You should type: PhotonsFromStars path/to/params.dat'
     write(*,*)'File params.dat should contain a parameter namelist'
     stop
  end if
  call get_command_argument(1, parameter_file)
  call read_PhotonsFromStars_params(parameter_file)
  if (verbose) call print_PhotonsFromStars_params
  ! ------------------------------------------------------------


  ! --------------------------------------------------------------------------------------
  ! define domain within which stars may shine
  ! --------------------------------------------------------------------------------------
  select case(star_dom_type)
  case('sphere')
     call domain_constructor_from_scratch(emission_domain,star_dom_type, &
          xc=star_dom_pos(1),yc=star_dom_pos(2),zc=star_dom_pos(3),r=star_dom_rsp)
  case('shell')
     call domain_constructor_from_scratch(emission_domain,star_dom_type, &
          xc=star_dom_pos(1),yc=star_dom_pos(2),zc=star_dom_pos(3),r_inbound=star_dom_rin,r_outbound=star_dom_rout)
  case('cube')
     call domain_constructor_from_scratch(emission_domain,star_dom_type, & 
          xc=star_dom_pos(1),yc=star_dom_pos(2),zc=star_dom_pos(3),size=star_dom_size)
  case('slab')
     call domain_constructor_from_scratch(emission_domain,star_dom_type, &
          xc=star_dom_pos(1),yc=star_dom_pos(2),zc=star_dom_pos(3),thickness=star_dom_thickness)
  end select
  ! --------------------------------------------------------------------------------------

  
  ! --------------------------------------------------------------------------------------
  ! read star particles within domain
  ! --------------------------------------------------------------------------------------
  if (verbose) write(*,*) '> reading star particles'
  call ramses_read_stars_in_domain(repository,snapnum,emission_domain,star_pos,star_age,star_mass,star_vel,star_met,cosmo)

  ! debug -
  !star_vel = 0.0
  !f0 = sum(star_mass) ! total mass
  !star_mass = star_mass / f0  * 1.989d33 ! now total mass is 1 Msun (in g)
  !star_age = star_age + 11.
  ! - debug
  ! --------------------------------------------------------------------------------------


  if (trim(spec_type) == 'SED' .or. trim(spec_type)=='SED-Gauss' .or. trim(spec_type) == 'SED-PowLaw') then

     ! --------------------------------------------------------------------------------------
     ! SED weighting ... 
     ! --------------------------------------------------------------------------------------
     if (verbose) write(*,*) '> performing SED weighting ... '
     ! read weight tables (precomputed fluxes from BC03).
     select case(trim(spec_type))
     case('SED-Gauss')
        open(unit=15,file=sed_gauss_file,status='old',form='formatted')
     case('SED')
        open(unit=15,file=SED_file,status='old',form='formatted')
     case('SED-PowLaw')
        open(unit=15,file=SED_powlaw_file,status='old',form='formatted')
     end select
     read(15,*) ! skip header
     read(15,*) ! skip header
     read(15,*) ! skip header
     read(15,*) sed_nage,sed_nmet
     allocate(sed_age(sed_nage),sed_met(sed_nmet),sed_flux(sed_nage,sed_nmet))
     if (trim(spec_type) == 'SED-PowLaw') allocate(sed_slope(sed_nage,sed_nmet))
     read(15,*) sed_age ! in Myr
     read(15,*) sed_met 
     do imet = 1,sed_nmet
        read(15,*) sed_flux(:,imet)  ! in erg/s/A/Msun (or erg/s/Msun for Lya)
        if (trim(spec_type) == 'SED-PowLaw') read(15,*) sed_slope(:,imet)
     end do
     close(15)
     ! compute weight (luminosity) of each star particle
     nstars = size(star_age)
     allocate(sweight(nstars))
     if (trim(spec_type) == 'SED-PowLaw') allocate(star_beta(nstars))
     do i = 1,nstars
        call locatedb(sed_met,sed_nmet,star_met(i),imet)
        if (imet < 1) imet = 1
        call locatedb(sed_age,sed_nage,star_age(i),iage)
        if (iage < 1) iage = 1
        select case(trim(spec_type))
        case('SED-Gauss')
           sweight(i) = star_mass(i) / 1.989d33 * sed_flux(iage,imet)  ! erg/s/A (or erg/s for Lya)
        case('SED')
           sweight(i) = star_mass(i) / 1.989d33 * sed_flux(iage,imet)  ! erg/s/A (or erg/s for Lya)
        case('SED-PowLaw')
           ! integrate powerlaw from min to max wavelengths.
           ! We actually want to sample the number of photons per lambda bin.
           ! Given that F_lbda = F_0 (lbda / lbda_0)**beta (in erg/s/A),
           ! the number of photons (in /s/A) is N_lbda = F_0*lbda_0/hc * (lbda/lbda_0)**(1+beta).
           ! (NB: the first lbda_0 here has to be in cm)
           ! This integrates to (in #/s) :
           ! (F_0 lbda_0 / hc) * lbda_0/(beta+2)  * [ (lbda_max/lbda_0)**(2+beta) - (lbda_min/lbda_0)**(2+beta)]
           ! (NB: the first lbda_0 here is in cm, the second in A). 
           ! OR, if beta == -2, the integral is
           ! (F_0*lbda_0/hc) * lbda_0 * ln(lbda_max/lbda_min)     [again, first lbda_0 in cm, second in A]
           f0 = sed_flux(iage,imet)
           beta = sed_slope(iage,imet)
           if (beta == -2.0d0) then
              sweight(i) = star_mass(i) / 1.989d33 * (f0*sed_powlaw_l0*1e-8/planck/clight)
              sweight(i) = sweight(i) * sed_powlaw_l0 * log(sed_powlaw_lmax/sed_powlaw_lmin)
           else
              sweight(i) = star_mass(i) / 1.989d33 * (f0*sed_powlaw_l0*1e-8*sed_powlaw_l0/planck/clight/(2.+beta))
              sweight(i) = sweight(i) * ( (sed_powlaw_lmax/sed_powlaw_l0)**(2.+beta) - (sed_powlaw_lmin/sed_powlaw_l0)**(2.+beta) )
           end if
           ! -> this is the number of photons in [lbda_min;lbda_max]
           star_beta(i) = beta ! keep for later. 
        end select
        if (sed_age(iage) < 10.) then ! SNs go off at 10Myr ... 
           sweight(i) = sweight(i)/0.8  !! correct for recycling ... we want the mass of stars formed ...
        end if
     end do

     ! Check that linear sampling with particle luminosity allows to represent most of the total flux 
     ! the total flux and flux per photon are 
     total_flux = 0.0d0
     do i=1,nstars
        total_flux = total_flux + sweight(i)
     end do
     photon_flux = total_flux / nphot 
     if (verbose) write(*,*) '> Total luminosity (erg/s/A or erg/s or nb of photons): ',total_flux
     ! construct the cumulative flux distribution, with enough bins to have the smallest star-particle flux in a bin. 
     minflux = minval(sweight)
     ! it may happen that the range of luminosities is too large (esp. for Lya). In that case we need to ignore faint particles.
     if (total_flux / minflux > 2d8) minflux = total_flux / 2d8  ! NB: dont go much higher than 1d8 (to stay below a few GB RAM). 
     ! check that we dont loose significant flux
     check_flux = 0.0d0
     do i=1,nstars
        if (sweight(i)>minflux) check_flux = check_flux+sweight(i)
     end do
     print*,'sampling only this fraction of total flux: ',check_flux / total_flux
     if ((total_flux - check_flux) / total_flux > 0.001) then
        print*,'Flux losses > 0.1 percent... change algorithm ...'
        ! debug - stop
     end if
     
     allocate(cum_flux_prob(int(3*total_flux / minflux,kind=8)))
     ilast = 1
     do i=1,nstars
        if (sweight(i) > minflux) then 
           n = int(3*sweight(i)/minflux,kind=8)
           cum_flux_prob(ilast:ilast+n) = i
           ilast = ilast + n
        end if
     end do
     nflux = ilast
     print*,'nflux, size(cum_fllux_prob):', nflux, size(cum_flux_prob)
     
     ! now we can draw integers from 1 to nflux and assign photons to stars ...
     allocate(photgrid(nphot),nu_star(nphot))
     iran = ranseed
     do i = 1,nphot
        j = int(ran3(iran)*nflux,kind=8)+1
        if (j > nflux) j = nflux
        j = cum_flux_prob(j) 
        photgrid(i)%ID    = i
        photgrid(i)%x_em  = star_pos(:,j)
        photgrid(i)%iran  = -i 
        call isotropic_direction(photgrid(i)%k_em,iran)
        select case(trim(spec_type))
        case('SED-PowLaw')
           ! sample F_lbda = F_0 (lbda / lbda_0)**beta (in erg/s/A) ...
           ! -> we actually want to sample the nb of photons : N_lbda = F_lbda * lbda / (hc) = F_0*lbda_0/(h*c) * (lbda/lbda_0)**(beta+1)
           ! FOR BETA /= 2 : 
           ! -> the probability of drawing a photon with l in [lbda_min;lbda] is:
           !      P(<lbda) = (lbda**(2+beta) - lbda_min**(2+beta))/(lbda_max**(2+beta)-lbda_min**(2+beta))
           ! -> and thus for a random number x in [0,1], we get
           !      lbda = [ lbda_min**(2+beta) + x * ( lbda_max**(2+beta) - lbda_min**(2+beta) ) ]**(1/(2+beta))
           ! FOR BETA == 2:
           ! -> the probability of drawing a photon with l in [lbda_min;lbda] is:
           !      P(<lbda) = log(lbda/lbda_min) / log(lbda_max/lbda_min)
           ! -> and thus for a random number x in [0,1], we get
           !      lbda = lbda_min * exp[ x * log(lbda_max/lbda_min)] 
           r1   = ran3(iran)
           if (star_beta(j) == -2.0d0) then
              nu = sed_powlaw_lmin * exp(r1 * log(sed_powlaw_lmax / sed_powlaw_lmin) ) ! this is lbda [A]
              nu   = clight / (nu*1e-8) ! this is freq. [Hz]
           else
              betaplus2 = star_beta(j) + 2.0d0
              nu   = (sed_powlaw_lmin**betaplus2 + r1 * (sed_powlaw_lmax**betaplus2 - sed_powlaw_lmin**betaplus2))**(1./betaplus2) ! this is lbda [A]
              nu   = clight / (nu*1e-8) ! this is freq. [Hz]
           end if
        case('SED-Gauss')
           r1 = ran3(iran)
           r2 = ran3(iran)
           nu = sqrt(-log(r1)) * cos(2.0d0*pi*r2)
           nu = (sed_gauss_velwidth * 1d5 * sed_gauss_nu / clight) * nu + sed_gauss_nu
        case('SED')
           nu = nu_sed
        end select
        nu_star(i) = nu  ! star-particle-frame frequency
        ! now put in external frame using particle's velocity. 
        scalar = photgrid(i)%k_em(1)*star_vel(1,j) + photgrid(i)%k_em(2)*star_vel(2,j) + photgrid(i)%k_em(3)*star_vel(3,j)
        photgrid(i)%nu_em = nu / (1d0 - scalar/clight)
     end do
     ! --------------------------------------------------------------------------------------
     
  else

     ! --------------------------------------------------------------------------------------
     ! keep only stars younger than max_age and oversample according to mass of particles
     ! --------------------------------------------------------------------------------------
     if (verbose) write(*,*) '> selecting young star particles '
     nstars = size(star_age)
     nyoung = 0
     minmass = minval(star_mass)
     ! count stars in unit of min-mass-star-particles so that stars will emit proportionally to their mass ... 
     do i = 1,nstars
        if (star_age(i) <= max_age) nyoung = nyoung + nint(star_mass(i)/minmass)
     end do
     if (nyoung == 0) then
        print*,'No young stars ... '
        stop
     end if
     ! copy arrays
     allocate(star_pos2(3,nyoung),star_vel2(3,nyoung))
     ilast = 1
     do i = 1,nstars
        if (star_age(i) <= max_age) then
           do j = ilast, ilast + nint(star_mass(i)/minmass)-1
              star_pos2(:,j) = star_pos(:,i)
              star_vel2(:,j) = star_pos(:,i)
           end do
           ilast = ilast + nint(star_mass(i)/minmass)
        end if
     end do
     ! --------------------------------------------------------------------------------------

     ! --------------------------------------------------------------------------------------
     ! make particles shine
     ! --------------------------------------------------------------------------------------
     if (verbose) write(*,*) '> generating photons'
     allocate(photgrid(nphot),nu_star(nphot))
     iran = ranseed
     do i = 1,nphot
        ! pick a star particle
        j = int(ran3(iran)*nyoung) + 1
        if (j > nyoung) j = nyoung
        ! define photon accordingly
        photgrid(i)%ID    = i
        photgrid(i)%x_em  = star_pos2(:,j)
        photgrid(i)%iran  = -i !! iran
        call isotropic_direction(photgrid(i)%k_em,iran)
        ! define star-particle-frame emission frequency
        select case(trim(spec_type))
        case('monochromatic')
           nu = nu_0
        case('flat_fnu')
           nu = ran3(iran) * (nu_max-nu_min) + nu_min 
        case('gauss')
           r1 = ran3(iran)
           r2 = ran3(iran)
           nu = sqrt(-log(r1)) * cos(2.0d0*pi*r2)
           nu = (velwidth * 1d5 * nu_cen / clight) * nu + nu_cen
        case default
           print*,'ERROR: unknown spec_type :',trim(spec_type)
        end select
        nu_star(i) = nu
        ! knowing the direction of emission and the velocity of the source (star particle), we
        ! compute the external-frame frequency :
        scalar = photgrid(i)%k_em(1)*star_vel2(1,j) + photgrid(i)%k_em(2)*star_vel2(2,j) + photgrid(i)%k_em(3)*star_vel2(3,j)
        photgrid(i)%nu_em = nu / (1d0 - scalar/clight)
     end do
     deallocate(star_pos2,star_vel2)
     ! --------------------------------------------------------------------------------------
     
  end if


  ! --------------------------------------------------------------------------------------
  ! write ICs
  ! --------------------------------------------------------------------------------------
  if (verbose) write(*,*) '> writing file'
  open(unit=14, file=trim(outputfile), status='unknown', form='unformatted', action='write')
  write(14) nphot
  write(14) ranseed
  write(14) (photgrid(i)%ID,i=1,nphot)
  write(14) (photgrid(i)%nu_em,i=1,nphot)
  write(14) (photgrid(i)%x_em(:),i=1,nphot)
  write(14) (photgrid(i)%k_em(:),i=1,nphot)
  write(14) (photgrid(i)%iran,i=1,nphot)
  write(14) (nu_star(i),i=1,nphot)
  close(14)
  if (trim(spec_type) == 'SED' .or. trim(spec_type)=='SED-Gauss' .or. trim(spec_type)=='SED-PowLaw') then ! write the total luminosity in a text file 
     write(file,'(a,a)') trim(outputfile),'.tot_lum'
     open(unit=14, file=trim(file), status='unknown',form='formatted',action='write')
     write(14,'(e14.6)') total_flux
     close(14)
  end if
  ! --------------------------------------------------------------------------------------

  deallocate(star_pos,star_vel,star_mass,star_age,photgrid,nu_star,star_met)
  
contains
  
  subroutine read_PhotonsFromStars_params(pfile)

    ! ---------------------------------------------------------------------------------
    ! subroutine which reads parameters of current module in the parameter file pfile
    ! default parameter values are set at declaration (head of module)
    ! ---------------------------------------------------------------------------------

    character(*),intent(in) :: pfile
    character(1000) :: line,name,value
    integer(kind=4) :: err,i
    logical         :: section_present
    
    section_present = .false.
    open(unit=10,file=trim(pfile),status='old',form='formatted')
    ! search for section start
    do
       read (10,'(a)',iostat=err) line
       if(err/=0) exit
       if (line(1:18) == '[PhotonsFromStars]') then
          section_present = .true.
          exit
       end if
    end do
    ! read section if present
    if (section_present) then
       do
          read (10,'(a)',iostat=err) line
          if(err/=0) exit
          if (line(1:1) == '[') exit ! next section starting... -> leave
          i = scan(line,'=')
          if (i==0 .or. line(1:1)=='#' .or. line(1:1)=='!') cycle  ! skip blank or commented lines
          name=trim(adjustl(line(:i-1)))
          value=trim(adjustl(line(i+1:)))
          i = scan(value,'!')
          if (i /= 0) value = trim(adjustl(value(:i-1)))
          select case (trim(name))
          case ('star_dom_pos')
             read(value,*) star_dom_pos(1),star_dom_pos(2),star_dom_pos(3)
          case ('star_dom_rsp')
             read(value,*) star_dom_rsp
          case ('star_dom_type')
             write(star_dom_type,'(a)') trim(value)
          case ('star_dom_size')
             read(value,*) star_dom_size
          case ('star_dom_rin')
             read(value,*) star_dom_rin
          case ('star_dom_rout')
             read(value,*) star_dom_rout
          case ('star_dom_thickness')
             read(value,*) star_dom_thickness
          case ('verbose')
             read(value,*) verbose
          case ('ranseed')
             read(value,*) ranseed
          case ('cosmo')
             read(value,*) cosmo
          case ('outputfile')
             write(outputfile,'(a)') trim(value)
          case ('repository')
             write(repository,'(a)') trim(value)
          case ('snapnum')
             read(value,*) snapnum
          case ('max_age')
             read(value,*) max_age
          case ('spec_type')
             write(spec_type,'(a)') trim(value)
          case ('nu_0')
             read(value,*) nu_0
          case ('nu_cen')
             read(value,*) nu_cen
          case ('velwidth')
             read(value,*) velwidth
          case ('nu_min')
             read(value,*) nu_min
          case ('nu_max')
             read(value,*) nu_max
          case ('nphot')
             read(value,*) nphot
          case ('nu_sed')
             read(value,*) nu_sed
          case ('SED_file')
             write(SED_file,'(a)') trim(value)
          case('sed_gauss_nu')
             read(value,*) sed_gauss_nu
          case('sed_gauss_file')
             write(sed_gauss_file,'(a)') trim(sed_gauss_file)
          case('sed_gauss_velwidth')
             read(value,*) sed_gauss_velwidth
          ! SED-PowLaw params :
          case('sed_powlaw_file')
             write(sed_powlaw_file,'(a)') trim(value)
          case('sed_powlaw_lmin')
             read(value,*) sed_powlaw_lmin
          case('sed_powlaw_lmax')
             read(value,*) sed_powlaw_lmax
          case('sed_powlaw_l0')
             read(value,*) sed_powlaw_l0
          end select
       end do
    end if
    close(10)

    return

  end subroutine read_PhotonsFromStars_params

  
  subroutine print_PhotonsFromStars_params(unit)

    ! ---------------------------------------------------------------------------------
    ! write parameter values to std output or to an open file if argument unit is
    ! present.
    ! ---------------------------------------------------------------------------------

    integer(kind=4),optional,intent(in) :: unit

    if (present(unit)) then 
       write(unit,'(a,a,a)')         '[PhotonsFromStars]'
       write(unit,'(a)')             '# input / output parameters'
       write(unit,'(a,a)')           '  outputfile      = ',trim(outputfile)
       write(unit,'(a,a)')           '  repository      = ',trim(repository)
       write(unit,'(a,i5)')          '  snapnum         = ',snapnum
       write(unit,'(a)')             '# computational domain parameters'
       write(unit,'(a,a)')           '  star_dom_type      = ',trim(star_dom_type)
       write(unit,'(a,3(ES9.3,1x))') '  star_dom_pos       = ',star_dom_pos(1),star_dom_pos(2),star_dom_pos(3)
       write(unit,'(a,ES9.3)')       '  star_dom_rsp       = ',star_dom_rsp
       write(unit,'(a,ES9.3)')       '  star_dom_size      = ',star_dom_size
       write(unit,'(a,ES9.3)')       '  star_dom_rin       = ',star_dom_rin
       write(unit,'(a,ES9.3)')       '  star_dom_rout      = ',star_dom_rout
       write(unit,'(a,ES9.3)')       '  star_dom_thickness = ',star_dom_thickness
       write(unit,'(a)')             '# how stars shine'
       write(unit,'(a,i8)')          '  nphot           = ',nphot
       write(unit,'(a,es9.3,a)')     '  max_age         = ',max_age, ' ! [Myr]' 
       write(unit,'(a,a)')           '  spec_type       = ',trim(spec_type)
       select case(trim(spec_type))
       case('monochromatic')
          write(unit,'(a,es9.3,a)')     '  nu_0            = ',nu_0, ' ! [Hz]'
       case('flat_fnu')
          write(unit,'(a,es9.3,a)')     '  nu_min          = ',nu_min, ' ! [Hz]'
          write(unit,'(a,es9.3,a)')     '  nu_max          = ',nu_max, ' ! [Hz]'
       case('gauss')
          write(unit,'(a,es9.3,a)')     '  nu_cen          = ',nu_cen, ' ! [Hz]'
          write(unit,'(a,es9.3,a)')     '  velwidth        = ',velwidth, ' ! [km/s]'
       case('SED')
          write(unit,'(a,es9.3,a)')     '  nu_sed          = ',nu_sed, ' ! [Hz]'
          write(unit,'(a,a)')           '  SED_file        = ',trim(SED_file)
       case('SED-Gauss')
          write(unit,'(a,es9.3,a)')     '  sed_gauss_nu       = ',sed_gauss_nu, ' ! [Hz]'
          write(unit,'(a,a)')           '  sed_gauss_file     = ',trim(sed_gauss_file)
          write(unit,'(a,es9.3,a)')     '  sed_gauss_velwidth = ',sed_gauss_velwidth, ' ! [km/s]'
       case('SED-PowLaw')
          write(unit,'(a,a)')           '  sed_powlaw_file = ',trim(sed_powlaw_file)
          write(unit,'(a,es9.3,a)')     '  sed_powlaw_lmin = ',sed_powlaw_lmin, ' ! [A]'
          write(unit,'(a,es9.3,a)')     '  sed_powlaw_lmax = ',sed_powlaw_lmax, ' ! [A]'
          write(unit,'(a,es9.3,a)')     '  sed_powlaw_l0   = ',sed_powlaw_l0, ' ! [A]'
       case default
          print*,'ERROR: unknown spec_type :',trim(spec_type)
       end select
       write(unit,'(a)')             '# miscelaneous parameters'
       write(unit,'(a,i8)')          '  ranseed         = ',ranseed
       write(unit,'(a,L1)')          '  verbose         = ',verbose
       write(unit,'(a,L1)')          '  cosmo           = ',cosmo
       write(unit,'(a)')             ' '
    else
       write(*,'(a,a,a)')         '[PhotonsFromStars]'
       write(*,'(a)')             '# input / output parameters'
       write(*,'(a,a)')           '  outputfile    = ',trim(outputfile)
       write(*,'(a,a)')           '  repository    = ',trim(repository)
       write(*,'(a,i5)')          '  snapnum       = ',snapnum
       write(*,'(a)')             '# computational domain parameters'
       write(*,'(a,a)')           '  star_dom_type      = ',trim(star_dom_type)
       write(*,'(a,3(ES9.3,1x))') '  star_dom_pos       = ',star_dom_pos(1),star_dom_pos(2),star_dom_pos(3)
       write(*,'(a,ES9.3)')       '  star_dom_rsp       = ',star_dom_rsp
       write(*,'(a,ES9.3)')       '  star_dom_size      = ',star_dom_size
       write(*,'(a,ES9.3)')       '  star_dom_rin       = ',star_dom_rin
       write(*,'(a,ES9.3)')       '  star_dom_rout      = ',star_dom_rout
       write(*,'(a,ES9.3)')       '  star_dom_thickness = ',star_dom_thickness

       write(*,'(a)')             '# how stars shine'
       write(*,'(a,i8)')          '  nphot         = ',nphot
       write(*,'(a,es9.3,a)')     '  max_age       = ',max_age, ' ! [Myr]'
       write(*,'(a,a)')           '  spec_type     = ',trim(spec_type)
       select case(trim(spec_type))
       case('monochromatic')
          write(*,'(a,es9.3,a)')     '  nu_0            = ',nu_0, ' ! [Hz]'
       case('flat_fnu')
          write(*,'(a,es9.3,a)')     '  nu_min          = ',nu_min, ' ! [Hz]'
          write(*,'(a,es9.3,a)')     '  nu_max          = ',nu_max, ' ! [Hz]'
       case('gauss')
          write(*,'(a,es9.3,a)')     '  nu_cen          = ',nu_cen, ' ! [Hz]'
          write(*,'(a,es9.3,a)')     '  velwidth        = ',velwidth, ' ! [km/s]'
       case('SED')
          write(*,'(a,es9.3,a)')     '  nu_sed          = ',nu_sed, ' ! [Hz]'
          write(*,'(a,a)')           '  SED_file        = ',trim(SED_file)
       case('SED-Gauss')
          write(*,'(a,es9.3,a)')     '  sed_gauss_nu       = ',sed_gauss_nu, ' ! [Hz]'
          write(*,'(a,a)')           '  sed_gauss_file     = ',trim(sed_gauss_file)
          write(*,'(a,es9.3,a)')     '  sed_gauss_velwidth = ',sed_gauss_velwidth, ' ! [km/s]'
       case('SED-PowLaw')
          write(*,'(a,a)')           '  sed_powlaw_file = ',trim(sed_powlaw_file)
          write(*,'(a,es9.3,a)')     '  sed_powlaw_lmin = ',sed_powlaw_lmin, ' ! [A]'
          write(*,'(a,es9.3,a)')     '  sed_powlaw_lmax = ',sed_powlaw_lmax, ' ! [A]'
          write(*,'(a,es9.3,a)')     '  sed_powlaw_l0   = ',sed_powlaw_l0, ' ! [A]'
       case default
          print*,'ERROR: unknown spec_type :',trim(spec_type)
       end select
       write(*,'(a)')             '# miscelaneous parameters'
       write(*,'(a,i8)')          '  ranseed     = ',ranseed
       write(*,'(a,L1)')          '  verbose    = ',verbose
       write(*,'(a,L1)')          '  cosmo      = ',cosmo
       write(*,'(a)')             ' '       
    end if

    return

  end subroutine print_PhotonsFromStars_params

  
  subroutine locatedb(xx,n,x,j)

    ! subroutine which locates the position j of a value x in an array xx of n elements
    ! NB : here xx is double precision
    
    implicit none
    
    integer(kind=4) ::  n,j,jl,ju,jm
    real(kind=8)    ::  xx(n),x
    
    jl = 0
    ju = n+1
    do while (ju-jl > 1) 
       jm = (ju+jl)/2
       if ((xx(n) > xx(1)) .eqv. (x > xx(jm))) then
          jl = jm
       else
          ju = jm
       endif
    enddo
    j = jl

    return

  end subroutine locatedb


  
end program PhotonsFromStars


  
