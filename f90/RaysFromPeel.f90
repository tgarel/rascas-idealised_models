!--PEEL--
program RaysFromPeel

  use module_ray
  use module_photon
  
  implicit none

  type(peel),allocatable     :: pgrid(:)
  type(ray_type),allocatable :: rays(:)
  integer(kind=4)            :: nrays,i,narg,n,ifile
  integer(kind=4)            :: npeels
  character(2000)            :: parameter_file
  ! ------------------------------------------------------------------------------------------------------------------------
  ! user-defined parameters - read from section [RaysFromSourceModel] of the parameter file
  ! ------------------------------------------------------------------------------------------------------------------------
  ! --- input / outputs
  character(2000)            :: PeelFile   = 'PeeleePeelee' ! peeling-off files are named DataDir/PeelFile.peelxxxxx, with 
  integer(kind=4)            :: ifirst = 1, ilast = 1       ! xxxxx in [ifirst,ilast]
  character(2000)            :: outputfile = 'RaysIC.dat'   ! file to which outputs will be written
  real(kind=8)               :: kobs(3)    = (/0.,0.,1./)   ! direction of observation . 
  logical                    :: verbose = .true.
  ! domains
  character(2000)           :: DataDir      = 'test/'                   ! where domain-dump files are 
  character(2000)           :: DomDumpFile  = 'domain_decomposition_params.dat' ! the file describing the outputs of CreateDomDump.
  ! ------------------------------------------------------------------------------------------------------------------------


  
  ! ------------------------------------------------------------------------------------------------------------------------
  ! -------------------- read parameters --------------------
  ! ------------------------------------------------------------------------------------------------------------------------
  narg = command_argument_count()
  if(narg .lt. 1)then
     write(*,*)'You should type: RaysFromPhotons path/to/params.dat'
     write(*,*)'File params.dat should contain a parameter namelist'
     stop
  end if
  call get_command_argument(1, parameter_file)
  call read_RaysFromPhotons_params(parameter_file)
  if (verbose) call print_RaysFromPhotons_params
  ! ------------------------------------------------------------------------------------------------------------------------


  
  ! ------------------------------------------------------------------------------------------------------------------------
  ! Read peels (result of a rascas run)
  ! ------------------------------------------------------------------------------------------------------------------------
  if (verbose) write(*,*) 'reading peels ...'
  npeels = 0
  ! first pass to count rays
  do ifile = ifirst, ilast
     write(peeloff_file,'(a,a,i5.5)') trim(PeelFile),'.peel',ifile
     open(unit=peeloff_unit, file=trim(peeloff_file), status='unknown', form='unformatted', action='write')
     do 
        read(peeloff_unit) n
        if (n == 0) exit
        npeels = npeels + n
        read(peeloff_unit);read(peeloff_unit);read(peeloff_unit);read(peeloff_unit);read(peeloff_unit)
     end do
     close(peelof_unit)
  end do
  ! allocate peels 
  allocate(pgrid(npeels))
  ! second pass to read the rays
  npeels = 0
  do ifile = ifirst, ilast
     write(peeloff_file,'(a,a,i5.5)') trim(PeelFile),'.peel',ifile
     open(unit=peeloff_unit, file=trim(peeloff_file), status='unknown', form='unformatted', action='write')
     do 
        read(peeloff_unit) n
        if (n == 0) exit
        read(peeloff_unit) (pgrid(npeels+i)%peeloff_fraction,i=1,n)
        read(peeloff_unit) (pgrid(npeels+i)%nu,i=1,n)
        read(peeloff_unit) (pgrid(npeels+i)%x(:),i=1,n)
        read(peeloff_unit) (pgrid(npeels+i)%k(:),i=1,n)
        read(peeloff_unit) (pgrid(npeels+i)%scatter_flag,i=1,n)
        npeels = npeels + n
     end do
     close(peelof_unit)
  end do
  ! ------------------------------------------------------------------------------------------------------------------------


  
  ! ------------------------------------------------------------------------------------------------------------------------
  ! read domains and meshe information 
  ! ------------------------------------------------------------------------------------------------------------------------
  ! here, we parse the file written out by CreateDomDump, which contains all file names and nb of domains.
  if (verbose) print *,'--> reading domain and mesh...'
  open(unit=18,file=DomDumpFile,status='old',form='formatted')
  read(18,'(a)') line ; i = scan(line,'=') ; file_compute_dom = trim(DataDir)//trim(adjustl(line(i+1:)))
  read(18,'(a)') line ; i = scan(line,'=') ; read(line(i+1:),*) ndomain
  allocate(mesh_file_list(ndomain))
  do j = 1, ndomain
     read(18,'(a)') line ! this is .dom files -> we want the .mesh next line 
     read(18,'(a)') line ; i = scan(line,'=') ; mesh_file_list(j) = trim(DataDir)//trim(adjustl(line(i+1:)))
  end do
  close(18)
  call domain_constructor_from_file(file_compute_dom,compute_dom)
  if (verbose) then
     print *,'--> Ndomain =',ndomain
     print *,'    |_ ',trim(file_compute_dom)
     do j=1,ndomain
        print *,'    |_ ',trim(mesh_file_list(j))
     end do
  endif
  ! ------------------------------------------------------------------------------------------------------------------------




  ! ------------------------------------------------------------------------------------------------------------------------
  ! loop on domains:
  ! - read mesh
  ! - locate peels in mesh, find their cell and draw their weights.
  ! - clear domain
  ! ------------------------------------------------------------------------------------------------------------------------
  do j = 1, ndomain
     if (verbose) print*,"Reading domain ", j
     call mesh_from_file(mesh_file_list(j),meshdom)
     


  
  ! ------------------------------------------------------------------------------------------------------------------------
  ! spawn rays from these peels in a chosen direction
  ! ------------------------------------------------------------------------------------------------------------------------
  ! -> need to know upar,uper, vcell(1:3), vth ...
  ! -> or we use mesh, find cell from xlast, get (vcell, vth) and re-draw upar and uper ... 
  ! ------------------------------------------------------------------------------------------------------------------------
  if (verbose) write(*,*) 'defining rays ... '
  nrays = size(pgrid)
  allocate(rays(nrays))
  do i=1,nrays
     rays(i)%ID     = pgrid(i)%ID
     rays(i)%x_em   = pgrid(i)%xlast
     rays(i)%k_em   = kobs
     rays(i)%nu_ext = pgrid(i)%nu_ext
  end do
  ! ------------------------------------------------------------------------------------------------------------------------

  

  
  ! ------------------------------------------------------------------------------------------------------------------------
  ! write ICs
  ! ------------------------------------------------------------------------------------------------------------------------
  if (verbose) write(*,*) '--> writing file'
  open(unit=14, file=trim(outputfile), status='unknown', form='unformatted', action='write')
  write(14) n
  write(14) (rays(i)%ID,i=1,n)
  write(14) (rays(i)%nu_ext,i=1,n)
  write(14) (rays(i)%x_em(:),i=1,n)
  write(14) (rays(i)%k_em(:),i=1,n)
  close(14)
  ! ------------------------------------------------------------------------------------------------------------------------

contains

  subroutine read_RaysFromPhotons_params(pfile)

    ! ---------------------------------------------------------------------------------
    ! subroutine which reads parameters of current module in the parameter file pfile
    ! default parameter values are set at declaration (head of module)
    ! ---------------------------------------------------------------------------------

    character(*),intent(in) :: pfile
    character(1000) :: line,name,value
    integer(kind=4) :: err,i
    logical         :: section_present
    real(kind=8)    :: norm 
    
    section_present = .false.
    open(unit=10,file=trim(pfile),status='old',form='formatted')
    ! search for section start
    do
       read (10,'(a)',iostat=err) line
       if(err/=0) exit
       if (line(1:17) == '[RaysFromPhotons]') then
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
          case ('outputfile')
             write(outputfile,'(a)') trim(value)
          case ('PhotonFile')
             write(PhotonFile,'(a)') trim(value)
          case ('DataDir')
             write(DataDir,'(a)') trim(value)
          case ('DomDumpFile')
             write(DomDumpFile,'(a)') trim(value)
          case ('kobs')
             read(value,*) kobs(1:3)
             ! force normalisation of kobs
             norm = kobs(1)*kobs(1)+kobs(2)*kobs(2)+kobs(3)*kobs(3)
             if (norm > 0) then
                kobs = kobs / sqrt(norm)
             else
                print*,'kobs has to be non zero... '
                stop
             end if
          case ('verbose')
             read(value,*) verbose
          end select
       end do
    end if
    close(10)

    ! add path (datadir) to input files 
    DomDumpFile  = trim(DataDir)//trim(DomDumpFile)

    return

  end subroutine read_RaysFromPhotons_params


  subroutine print_RaysFromPhotons_params(unit)

    ! ---------------------------------------------------------------------------------
    ! write parameter values to std output or to an open file if argument unit is
    ! present.
    ! ---------------------------------------------------------------------------------

    integer(kind=4),optional,intent(in) :: unit

    if (present(unit)) then 
       write(unit,'(a,a,a)')         '[RaysFromPhotons]'
       write(unit,'(a)')             '# input / output parameters'
       write(unit,'(a,a)')           '  outputfile      = ',trim(outputfile)
       write(unit,'(a,a)')           '  PhotonFile      = ',trim(PhotonFile)
       write(unit,'(a)')             '# miscelaneous parameters'
       write(unit,'(a,L1)')          '  verbose         = ',verbose
       write(unit,'(a)')             ' '
    else
       write(*,'(a,a,a)')         '[RaysFromPhotons]'
       write(*,'(a)')             '# input / output parameters'
       write(*,'(a,a)')           '  outputfile      = ',trim(outputfile)
       write(*,'(a,a)')           '  PhotonFile      = ',trim(PhotonFile)
       write(*,'(a)')             '# miscelaneous parameters'
       write(*,'(a,L1)')          '  verbose         = ',verbose
       write(*,'(a)')             ' '
    end if

    return

  end subroutine print_RaysFromPhotons_params

end program RaysFromPeel
!--LEEP--
