module module_gray_ray

  ! This is a trimmed and slightly modified version of module_photon.
  !
  ! THIS IMPLENMENTATION HAS NO WAVELENGTH / VELOCITY INFO (used for escape fraction measurements). 
  
  use module_gas_composition
  use module_mesh
  use module_constants
  use module_random
  use module_domain
  use module_utils, only: path, isotropic_direction

  implicit none

  ! todonext define accuracy
  real(kind=8),parameter :: accuracy=1.d-15
  integer(kind=4) :: iran = -10
  logical::identical_ray_distribution=.false. ! Same ray directions for all sources?
  logical:: use_halos = .false.


  

  type ray_type
     integer(kind=4)           :: ID       ! a positive unique ID 
     real(kind=8)              :: dist     ! distance traveled along ray (box units)
     real(kind=8)              :: tau,tau2,tau3      ! integrated opacity along ray  for the different groups
     real(kind=8),dimension(3) :: x_em     ! emission location (box units)
     integer(kind=4)           :: halo_ID  ! a positive unique ID 
     real(kind=8),dimension(3) :: k_em     ! emission direction == propagation direction (normalised vector)
     real(kind=8)              :: fesc     ! escape fraction 
  end type ray_type

  type halo_type
     integer(kind=4)           :: ID       ! a positive unique ID
     type(domain)              :: domain   ! rvir and center (box units)
  end type halo_type

  type(halo_type),dimension(:),allocatable :: halos

  public  :: ComputeFesc, ray_advance, init_rays_from_file, init_halos_from_file, dump_rays
  private :: path

contains

  subroutine ComputeFesc(nrays,rays,lum1,lum2,lum3,mesh_dom,compute_dom,maxdist,maxtau,minnH,ndirections,file)   ! lum1,2 et 3 for the different photon groups

    integer(kind=4), intent(in)                     :: nrays
    type(ray_type), dimension(nrays), intent(inout) :: rays
    real(kind=8), dimension(nrays), intent(inout)   :: lum1,lum2, lum3
    type(mesh), intent(in)                          :: mesh_dom
    type(domain), intent(in)                        :: compute_dom
    real(kind=8),intent(in)                         :: maxdist,maxtau,minnH
    integer(kind=4)                                 :: ndirections ! Number of directions from each source
    integer(kind=4)                                 :: i,j,idir,iloop
  !  real(kind=8)                                    :: fesc  on va plutôt faire une liste des fesc
    character(2000),intent(in)                      :: file

    real(kind=8)             :: nhtot, e1, e2, e3            ! average energy of each photons group (in J)
    real(kind=8),allocatable :: directions(:,:)
    real(kind=8),allocatable :: fesc(:)
    real(kind=8),allocatable :: Npho(:)
    real(kind=8),allocatable :: densh(:)
    real(kind=8),allocatable :: distance(:)

    real(kind=8) :: x_em(3),k_em(3), tau, tau2,tau3, dist, lumi1,lumi2,lumi3,lumtot

    !!!! variable pour stocker les resultats (fesc (ndir))


    e1 = 28.9033E-19       ! average energies of a photon for groups 1,2 and 3
    e2 = 51.9748E-19
    e3 = 107.619E-19    




    !! Ici on lit les directions choisies (et leur nombre) dans un fichier.
    open(unit=14, file=trim(file), status='unknown', form='formatted', action='read')
    read(14,*) ndirections
    allocate(directions(3,ndirections))
    do i = 1,ndirections
       read(14,*) directions(1,i),directions(2,i),directions(3,i)
    end do
    close(14)
   
    allocate(fesc(ndirections))
    allocate(Npho(ndirections))
    allocate(densh(ndirections))
    allocate(distance(ndirections))
   ! open(unit=14, file='result_nside16.txt',Access= 'append', status='old', form='formatted', action='write') ! fichier de résultats avec fesc par directions, moyenne sur toutes étoiles
   
    iloop=0
!$OMP PARALLEL &
!$OMP DEFAULT(shared) &
!$OMP PRIVATE(i,nhtot,tau,tau2,tau3, dist,k_em,x_em,lumi1,lumi2,lumi3,lumtot)               
!$OMP DO SCHEDULE(DYNAMIC, 100) 
 

    do j=1,ndirections
       print*,j,lumtot, fesc(j)
       fesc(j) = 0.0d0
       Npho(j) = 0.0d0
       distance(j) = 0.0d0
       lumtot =0.0d0
       k_em(:) = directions(:,j) 
       do i=1,nrays  ! these are actually star particle positions
          x_em(:) = rays(i)%x_em(:)
          lumi1 = lum1(i)
          lumi2 = lum2(i)
          lumi3 = lum3(i)
          tau   = 0.0d0
          tau2  = 0.0d0
          tau3  = 0.0d0
          dist  = 0.0d0
          nhtot = 0.0d0
          call ray_advance(x_em,k_em,tau,tau2,tau3,dist,nhtot,mesh_dom,compute_dom,maxdist,maxtau,minnH)
          fesc(j) = fesc(j) + exp(-tau)*lumi1 + exp(-tau2)*lumi2 + exp(-tau3)*lumi3       
      !     Npho(j) = Npho(j) + exp(-tau)*lumi1/e1 + exp(-tau2)*lumi2/e2 + exp(-tau3)*lumi3/e3
          lumtot = lumtot +lumi1+lumi2+lumi3   
          densh(j) =densh(j) + nhtot
          distance(j)=distance(j) + dist
       end do
!       print*,j, fesc(j), lumtot
       fesc(j) = fesc(j)/(lumtot) 
       densh(j)= densh(j)/(real(nrays,8))
       distance(j)=distance(j)/(real(nrays,8))
    enddo
    
!$OMP END DO
!$OMP END PARALLEL

    !new loop to write the file
    open(unit=14, file='result_nside24_lum_group.txt', status='replace', form='formatted', action='write')
    do j=1,ndirections
       write(14,*) fesc(j)
    enddo 
    close(14)
    open(unit=14, file='nH_nside24.txt', status='replace', form='formatted', action='write')
    do j=1,ndirections
       write(14,*) densh(j)
    enddo
    close(14)    
    open(unit=14, file='dist_nside24.txt', status='replace', form='formatted', action='write')
    do j=1,ndirections
       write(14,*) distance(j)
    enddo
    close(14)
  
  deallocate(directions)
  deallocate(fesc)
  deallocate(densh)
  end subroutine ComputeFesc


  subroutine ray_advance(x_em,k_em,tau,tau2,tau3,dist,nhtot,domesh,domaine_calcul,maxdist,maxtau,minnH)

!    type(ray_type),intent(inout)   :: ray            ! a ray 
    real(kind=8),intent(in) :: x_em(3),k_em(3)
    real(kind=8),intent(out) :: tau,tau2,tau3,dist
    type(mesh),intent(in)          :: domesh         ! mesh
    type(domain),intent(in)        :: domaine_calcul ! domaine dans lequel on propage les photons...
    real(kind=8),intent(in)        :: maxdist,maxtau ! stop propagation at either maxdist or maxtau (the one which is positive). 
    real(kind=8),intent(in)        :: minnH          ! stop propagation when reaching hydrogen density below this value
    real(kind=8),intent(out)       :: nhtot             ! projection of H and He density along the ray
    type(gas)                      :: cell_gas       ! gas in the current cell 
    integer(kind=4)                :: icell, ioct, ind, ileaf, cell_level  ! current cell indices and level
    real(kind=8)                   :: cell_size, cell_size_cm, scalar, nu_cell, maxdist_cm
    real(kind=8),dimension(3)      :: ppos,ppos_cell ! working coordinates of photon (in box and in cell units)
    real(kind=8)                   :: distance_to_border,distance_to_border_cm
    real(kind=8)                   :: tau_cell,tau2_cell,tau3_cell, dborder
    integer(kind=4)                :: i, icellnew, npush, k    !k le nombre de cellules le long de la ray
    real(kind=8),dimension(3)      :: vgas, kray, cell_corner, posoct
    logical                        :: flagoutvol, in_domain
    real(kind=8)                   :: excess, tmp
    
    ! initialise ray tracing 
!!$    ppos  = ray%x_em   ! emission position 
!!$    kray  = ray%k_em   ! propagation direction
    ppos  = x_em   ! emission position 
    kray  = k_em   ! propagation direction
    dist  = 0.0d0      ! distance covered
    tau   = 0.0d0      ! corresponding optical depth
    tau2  = 0.0d0
    tau3  = 0.0d0
    nhtot = 0.0d0    !initialise nhtot density along the ray
    maxdist_cm = maxdist ! maxdist is now provided in cm ... 


    ! check that the ray starts in the domain
    if (.not. domain_contains_point(ppos,domaine_calcul)) then
       print * ,'Ray outside domain at start '
       print*, ppos
       stop
    end if
    
    ! find the (leaf) cell in which the photon is, and define all its indices
    icell = in_cell_finder(domesh,ppos)
    if(domesh%son(icell)>=0)then
       print*,'ERROR: not a leaf cell ',ppos
       stop
    endif
    ileaf = - domesh%son(icell)
    ind   = (icell - domesh%nCoarse - 1) / domesh%nOct + 1   ! JB: should we make a few simple functions to do all this ? 
    ioct  = icell - domesh%nCoarse - (ind - 1) * domesh%nOct


    k = 0 

    ! advance ray until it escapes the computational domain ... 
    ray_propagation : do
       


       ! gather properties properties of current cell
       cell_level   = domesh%octlevel(ioct)      ! level of current cell
       cell_size    = 0.5d0**cell_level          ! size of current cell in box units
       cell_size_cm = cell_size * box_size_cm    ! size of the current cell in cm
       cell_gas     = domesh%gas(ileaf)  

       ! H  projection density along the ray
    !   k = k + 1
    !   nhtot = nhtot + cell_gas%nHI

       ! compute position of photon in current-cell units
       posoct(:)    = domesh%xoct(ioct,:)
       cell_corner  = get_cell_corner(posoct,ind,cell_level)   ! position of cell corner, in box units.
       ppos_cell    = (ppos - cell_corner) / cell_size         ! position of photon in cell units (x,y,z in [0,1] within cell)
       if((ppos_cell(1)>1.0d0).or.(ppos_cell(2)>1.0d0).or.(ppos_cell(3)>1.0d0).or. &
            (ppos_cell(1)<0.0d0).or.(ppos_cell(2)<0.0d0).or.(ppos_cell(3)<0.0d0))then
          print*,"ERROR: problem in computing ppos_cell ",ppos_cell(1),ppos_cell(2),ppos_cell(3)
          stop
       endif
       
       ! compute distance of photon to border of cell or domain along propagation direction
       distance_to_border    = path(ppos_cell,kray) * cell_size            ! in box units

       !! -> if au lieu du min, plus un flag qui nous dit quon va sortir ...
       distance_to_border    = min(distance_to_border, &
            & domain_distance_to_border_along_k(ppos,kray,domaine_calcul)) ! in box units
       distance_to_border_cm = distance_to_border * box_size_cm ! cm
  
     
       ! compute (total) optical depth along ray in cell 
       tau_cell  = gas_get_tau(cell_gas, distance_to_border_cm)
       tau2_cell = gas_get_tau2(cell_gas, distance_to_border_cm)
       tau3_cell = gas_get_tau3(cell_gas, distance_to_border_cm)
       nhtot = nhtot + distance_to_border_cm*cell_gas%nHI            !column density

       ! update traveled distance and optical depth
       tau  = tau + tau_cell 
       tau2 = tau2 + tau2_cell
       tau3 = tau3 + tau3_cell
       if (tau < 1) then
             dist = dist + distance_to_border_cm
       endif 
       ! check if we reached tau or distance limits
!       if (dist > maxdist_cm .and. tau > maxtau) then
          ! dist or tau exceeding boundary -> correct excess and exit. 
!          if (maxdist_cm > 0) then
!             excess   = maxdist_cm - dist
!             ray%dist = dist
!             ray%tau  = tau - (excess / distance_to_border_cm)*tau_cell
         ! else
         !    excess   = maxtau - tau
         !    ray%dist = dist - (excess / tau_cell) * distance_to_border_cm     pour l'instant on enlève car pas de conditions sur maxtau > 0 dc on a systématiquement tau = maxtau
         !    ray%tau  = maxtau                                                 
!          end if
!          exit ray_propagation  ! no need to update other unused properties of ray. 

!       end if
!       if ( cell_gas%nH < minnH ) then ! Gone below the minimum density
!          ray%dist = dist
!          ray%tau  = tau
!          exit ray_propagation
!       endif

       ! update head of ray position
       ppos = ppos + kray * distance_to_border *(1.0d0 + epsilon(1.0d0))
       ! correct for periodicity
       do i=1,3
          if (ppos(i) < 0.0d0) ppos(i)=ppos(i)+1.0d0
          if (ppos(i) > 1.0d0) ppos(i)=ppos(i)-1.0d0
       enddo
       
      ! check if photon still in computational domain after position update
       in_domain = domain_contains_point(ppos,domaine_calcul)
       if (.not.(in_domain)) then
          dist = dist
          tau  = tau
          tau2 = tau2
          tau3 = tau3
          !print*,'WARNING: escaping domain before maxdist or maxtau is reached... '
          !print*,'initial distance to border of domain [cm] : ',domain_distance_to_border(ray%x_em,domaine_calcul)*box_size_cm
          !print*,'maxdist [cm]                              : ',maxdist_cm
          exit ray_propagation  ! ray is done 
         
       end if
       ! Ray moves to next cell : find it
       call whereIsPhotonGoing(domesh,icell,ppos,icellnew,flagoutvol)
       ! It may happen due to numerical precision that the photon is still in the current cell (i.e. icell == icellnew).
       ! -> give it an extra push untill it is out. 
       npush = 0
       do while (icell==icellnew)
          npush = npush + 1
          if (npush>100) then
             print*,ppos
             print*,kray
             print*,'Too many pushes, npush>100 '
             exit ray_propagation
          endif

          ! hack
          do i=1,3
             ppos(i) = ppos(i) + kray(i) * 1d7 * epsilon(ppos(i))
          end do
          !!$ ppos(1) = ppos(1) + merge(-1.0d0,1.0d0,kray(1)<0.0d0) * epsilon(ppos(1))
          !!$ ppos(2) = ppos(2) + merge(-1.0d0,1.0d0,kray(2)<0.0d0) * epsilon(ppos(2))
          !!$ ppos(3) = ppos(3) + merge(-1.0d0,1.0d0,kray(3)<0.0d0) * epsilon(ppos(3))
          ! kcah
          
          ! correct for periodicity
          do i=1,3
             if (ppos(i) < 0.0d0) ppos(i)=ppos(i)+1.0d0
             if (ppos(i) > 1.0d0) ppos(i)=ppos(i)-1.0d0
          enddo
          ! test that we are still in domain before calling WhereIsPhotonGoing... 
          in_domain = domain_contains_point(ppos,domaine_calcul)
          if (.not.(in_domain)) then
             dist = dist
             tau  = tau
             tau2  = tau2
             tau3  = tau3
             exit ray_propagation  ! ray is done 
          end if
          call whereIsPhotonGoing(domesh,icell,ppos,icellnew,flagoutvol)
       end do
       if (npush > 1) print*,'WARNING : npush > 1 needed in module_gray_ray:propagate.'
       
       ! check if photon outside of cpu domain (flagoutvol)
       if(flagoutvol)then
          ! photon out of cpu domain -> we have a problem... 
          print*,'ERROR: photon out of CPU domain when it should not ... '
          stop
       endif
       
       ! else, new cell is in the cpu domain and photon goes to this new cell
       icell = icellnew
       if(domesh%son(icell)>=0)then
          print*,'ERROR: not a leaf cell',icell,flagoutvol
          print*,'This should not happen in module_ray (on single domains). '
          stop
       endif
       ileaf = - domesh%son(icell)
       ind   = (icell - domesh%nCoarse - 1) / domesh%nOct + 1   ! JB: should we make a few simple functions to do all this ? 
       ioct  = icell - domesh%nCoarse - (ind - 1) * domesh%nOct       
   
    end do ray_propagation
 
    ! nhtot = nhtot /real(k,8)                ! average of nhtot on all the cells of the ray

  end subroutine ray_advance
  

  subroutine init_rays_from_file(file,rays,lum1,lum2,lum3)

    character(2000),intent(in)                           :: file    
    !character(2000),intent(in)                           :: dirFile  
    type(ray_type),dimension(:),allocatable, intent(out) :: rays
    real(kind=8),dimension(:),allocatable, intent(out)   :: lum1,lum2,lum3
    integer(kind=4)                                      :: i, n_rays

    ! read ICs
    open(unit=14, file=trim(file), status='unknown', form='formatted', action='read')
    read(14,*) n_rays
    allocate(rays(n_rays))
    allocate(lum1(n_rays))
    allocate(lum2(n_rays))
    allocate(lum3(n_rays))

    if (n_rays==0) return
  
   ! read(14) (rays(i)%ID,         i=1,n_rays)
     read(14,*) (rays(i)%x_em(1),    i=1,n_rays)
     read(14,*) (rays(i)%x_em(2),    i=1,n_rays)
     read(14,*) (rays(i)%x_em(3),    i=1,n_rays)
     read(14,*) (lum1(i),            i=1,n_rays)
     read(14,*) (lum2(i),            i=1,n_rays)
     read(14,*) (lum3(i),            i=1,n_rays)
!    read(14) (rays(i)%halo_ID,     i=1,n_rays)   pour l'instant pas besoin puisuqe uniquement sur un Halo
     close(14)
    ! initialise other properties. 


   
   print*,minval(rays(:)%x_em(1)),maxval(rays(:)%x_em(1))
   print*,minval(rays(:)%x_em(2)),maxval(rays(:)%x_em(2))
   print*,minval(rays(:)%x_em(3)),maxval(rays(:)%x_em(3))
   
   
   ! lecture des directions dans le fichier dirFile
   ! open 
   ! read ndirections
   ! read all directions
   ! close le fichier
         


  end subroutine init_rays_from_file 


  subroutine init_halos_from_file(file,halos)

    character(2000),intent(in)                            :: file
    type(halo_type),dimension(:),allocatable, intent(out) :: halos
    integer(kind=4)                                       :: i, n_halos

    print*,'Initialising halos from file (in module_gray_ray.f90)'
    ! read Halos (for escape fractions out of virial radii)
    open(unit=14, file=trim(file), status='unknown', form='unformatted', action='read')
    read(14) n_halos
    allocate(halos(n_halos))
    halos(1:n_halos)%domain%type='sphere'
    read(14) (halos(i)%ID,               i=1,n_halos)
    read(14) (halos(i)%domain%sp%radius,    i=1,n_halos)
    read(14) (halos(i)%domain%sp%center(1), i=1,n_halos)
    read(14) (halos(i)%domain%sp%center(2), i=1,n_halos)
    read(14) (halos(i)%domain%sp%center(3), i=1,n_halos)
    close(14)
    
  end subroutine init_halos_from_file


  subroutine dump_rays(file,rays)

    character(2000),intent(in)             :: file
    type(ray_type),dimension(:),intent(in) :: rays
    integer(kind=4)                        :: i,np

    np = size(rays)
    open(unit=14, file=trim(file), status='unknown', form='unformatted', action='write')
    write(14) np
    if(np.gt.0) then
       write(14) (rays(i)%fesc,i=1,np)
       write(14) (rays(i)%ID,i=1,np)
    endif
    close(14)

  end subroutine dump_rays

end module module_gray_ray