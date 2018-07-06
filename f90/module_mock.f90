module module_mock

  use module_constants, only:clight
  
  public

  ! direction of observation
  real(kind=8) :: kobs(3),kobs_perp_1(3),kobs_perp_2(3)

  ! center of observation
  real(kind=8) :: mock_center(3)

  ! extent of observation
  real(kind=8) :: mock_image_side ! box units
  
  ! image 
  integer(kind=4) :: npix
  real(kind=8),allocatable :: image(:,:)

  ! spectrum
  integer(kind=4) :: npix_spec
  real(kind=8)    :: spec_lmin, spec_lmax
  real(kind=8),allocatable :: spectrum(:)

  
contains

  subroutine mock_init()

    implicit none
    allocate(image(npix,npix))
    image = 0.0d0
    allocate(spectrum(npix_spec))
    spectrum = 0.0d0 
    ! define direction of observation (normalise vector)
    kobs = kobs / sqrt(kobs(1)*kobs(1)+kobs(2)*kobs(2)+kobs(3)*kobs(3))
    ! define basis for sky plane
    if (kobs(1) < 1.) then
       ! kobs_perp_1 is cross prod. of kobs and x 
       kobs_perp_1(1) = 0.
       kobs_perp_1(2) = kobs(3)
       kobs_perp_1(3) = -kobs(2)
       kobs_perp_1 = kobs_perp_1 / sqrt(kobs_perp_1(1)*kobs_perp_1(1)+kobs_perp_1(2)*kobs_perp_1(2)+kobs_perp_1(3)*kobs_perp_1(3))
       ! kobs_perp_2 = kobs x kobs_perp_1
       kobs_perp_2(1) = kobs(2)*kobs_perp_1(3) - kobs(3)*kobs_perp_1(2)
       kobs_perp_2(2) = -kobs(1)*kobs_perp_1(3)
       kobs_perp_2(3) = kobs(1)*kobs_perp_1(2)
       kobs_perp_2 = kobs_perp_2 / sqrt(kobs_perp_2(1)*kobs_perp_2(1)+kobs_perp_2(2)*kobs_perp_2(2)+kobs_perp_2(3)*kobs_perp_2(3))       
    else
       ! kobs is aligned with x -> use kobs_perp_1 = y, kobs_perp_2 = z
       kobs_perp_1 = (/0.0d0,1.0d0,0.0d0/)
       kobs_perp_2 = (/0.0d0,0.0d0,1.0d0/)
    end if
        
    return
  end subroutine mock_init
  
  
  subroutine projected_pos(pos,pp)
    implicit none
    real(kind=8),intent(in) :: pos(3)
    real(kind=8),intent(inout) :: pp(2)
    
    pp(1) = (pos(1)-mock_center(1))*kobs_perp_1(1) + (pos(2)-mock_center(2))*kobs_perp_1(2) + (pos(3)-mock_center(3))*kobs_perp_1(3)
    pp(2) = (pos(1)-mock_center(1))*kobs_perp_2(1) + (pos(2)-mock_center(2))*kobs_perp_2(2) + (pos(3)-mock_center(3))*kobs_perp_2(3)

    return 
  end subroutine projected_pos
    
  
  subroutine peel_to_map(peel_pos,peel_contribution)
    implicit none

    real(kind=8),intent(in) :: peel_pos(3),peel_contribution
    real(kind=8)    :: pp(2) 
    integer(kind=4) :: ix,iy

    call projected_pos(peel_pos,pp)
    ix = int((pp(1) + 0.5d0 * mock_image_side) /mock_image_side * npix)
    iy = int((pp(2) + 0.5d0 * mock_image_side) /mock_image_side * npix)
    if (ix>0 .and. ix<=npix .and. iy>0 .and. iy<=npix) image(ix,iy) = image(ix,iy) + peel_contribution
    
    return
  end subroutine peel_to_map

  subroutine peel_to_spec(peel_nu,peel_contribution)
    implicit none

    real(kind=8),intent(in) :: peel_nu,peel_contribution
    real(kind=8)            :: lambda 
    integer(kind=4) :: i

    lambda = clight / peel_nu * 1d8 ! [Angstrom]
    i = int( (lambda - spec_lmin) / (spec_lmax - spec_lmin) * npix_spec)
    if ((i > 0) .and. (i<=npix_spec)) then
       spectrum(i) = spectrum(i) + peel_contribution
    end if
    
    return
  end subroutine peel_to_spec


  subroutine read_mock_params(pfile)
    
    ! ---------------------------------------------------------------------------------
    ! subroutine which reads parameters of current module in the parameter file pfile
    !
    ! default parameter values are set at declaration (head of module)
    ! ---------------------------------------------------------------------------------

    character(*),intent(in) :: pfile
    character(1000)         :: line,name,value
    integer(kind=4)         :: err,i
    logical                 :: section_present

    section_present = .false.
    open(unit=10,file=trim(pfile),status='old',form='formatted')
    ! search for section start
    do
       read (10,'(a)',iostat=err) line
       if(err/=0) exit
       if (line(1:6) == '[mock]') then
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
          case ('mock_center')
             read(value,*) mock_center(:)
          case ('kobs')
             read(value,*) kobs
          case ('npix')
             read(value,*) npix
          case ('mock_image_side')
             read(value,*) mock_image_side
          case ('npix_spec')
             read(value,*) npix_spec
          case ('spec_lmin')
             read(value,*) spec_lmin
          case ('spec_lmax')
             read(value,*) spec_lmax
          end select
       end do
    end if
    close(10)

    call mock_init

    return

  end subroutine read_mock_params


end module module_mock
