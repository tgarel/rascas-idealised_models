module module_utils
  
  ! general-purpose functions : 
  ! 
  ! - voigt_fit
  ! - isotropic_direction
  ! - anisotropic_direction_HIcore
  ! - anisotropic_direction_Rayleigh
  
  use module_constants, only : pi, sqrtpi, twopi
  use module_random
  
  public

contains

  function voigt_fit(x,a)

    ! returns ... what exactly?
    ! REF to where the fit is taken from ?
    ! comment on accuracy ?
    
    implicit none
    
    real(kind=8),intent(in) :: x,a
    real(kind=8)            :: voigt_fit 
    real(kind=8)            :: q,z,x2
    
    x2 = x**2
    z  = (x2 - 0.855d0) / (x2 + 3.42d0)
    if (z > 0) then 
       q = z * (1.0d0 + 21.0d0/x2) * a / pi / (x2 + 1.0d0)
       q = q * (((5.674d0*z - 9.207d0)*z + 4.421d0)*z + 0.1117)
    else
       q = 0.0d0 
    end if
    voigt_fit = q + exp(-x2) / sqrtpi
    
    return
    
  end function voigt_fit

 

  subroutine isotropic_direction(k,iran)

    ! ---------------------------------------------------------------------------------
    ! return k vector pointing to a random direction (uniform on the sphere)
    ! ---------------------------------------------------------------------------------
    ! INPUTS:
    ! - iran : state of random number generator
    ! OUTPUTS :
    ! - k    : normalized direction vector
    ! - iran : updated state of random number generator
    ! ---------------------------------------------------------------------------------

    implicit none

    real(kind=8),intent(out)      :: k(3)
    integer(kind=4),intent(inout) :: iran
    real(kind=8)                  :: cos_theta,sin_theta,phi
    
    phi   = twopi*ran3(iran)
    cos_theta = 1.0d0 - 2.0d0 * ran3(iran)  ! in [-1,1]
    sin_theta = sqrt(1.0d0 - cos_theta**2) ! in [0,1]
    k(1) = sin_theta * cos(phi)   !x
    k(2) = sin_theta * sin(phi)   !y
    k(3) = cos_theta              !z
    
  end subroutine isotropic_direction

  

  subroutine anisotropic_direction_HIcore(kin,kout,mu,bu,iran)

    ! ---------------------------------------------------------------------------------
    ! sends back new direction vector kout as a function of incident direction kin, for a phase function
    ! described by P(mu) = 11/24 + 3/24 * mu**2 (with mu = cos(theta) = kin.kout). This is a good
    ! description, e.g., of core scatterings on HI atoms.
    ! ---------------------------------------------------------------------------------
    ! INPUTS:
    ! - kin  : normalized direction vector of incident photon
    ! - iran : state of random number generator
    ! OUTPUTS:
    ! - kout : normalized direction vector of scattered photon
    ! - mu   : dod-product between kin and kout (i.e. cos(theta))
    ! - bu   : sin(theta) (i.e. sqrt(1-mu**2))
    ! - iran : updated state of random number generator
    ! 
    ! Notes on the method : 
    ! ---------------------
    ! To draw theta values, we compute the cumulative probability from above :
    ! P(< mu) = 1/2 + 11/24 * mu + 1/24 * mu**3
    ! We fit the reciprocal function with the following polynomial function giving a better
    ! than 0.52% accuracy everywhere:
    ! mu = -0.703204 x^3 + 1.054807 x^2 + 1.643182 x^1 -0.997392  
    ! -> to get a value of mu (hence theta), we draw x in [0,1] and compute mu from the above fit
    ! ---------------------------------------------------------------------------------

    implicit none

    real(kind=8),intent(in)       :: kin(3)
    real(kind=8),intent(out)      :: kout(3)
    real(kind=8),intent(out)      :: mu,bu
    integer(kind=4),intent(inout) :: iran
    real(kind=8)                  :: phi,x,cti,sti,cpi,spi,ct1,st1,cp1,sp1
    
    phi = twopi * ran3(iran)
    x   = ran3(iran)
    mu = ((-0.703204*x + 1.054807)* x + 1.643182) * x - 0.997392  
    ! angular description of kin in external frame (box coordinates)
    cti = kin(3)
    sti = sqrt(1.d0 - cti**2)  ! sin(theta) is positive for theta in [0,pi]. 
    if (sti > 0) then 
       cpi = kin(1)/sti
       spi = kin(2)/sti
    else
       cpi = 1.
       spi = 0.
    end if
    ! angular description of kout (relative to k)
    ct1 = mu
    st1 = sqrt(1.0d0 - ct1*ct1)
    bu  = st1
    cp1 = cos(phi)
    sp1 = sin(phi)
    ! vector kout (such that indeed knew . k = ct1) in external frame (box coords.)
    kout(1) = cti*cpi*st1*cp1 + sti*cpi*ct1 - spi*st1*sp1
    kout(2) = cti*spi*st1*cp1 + sti*spi*ct1 + cpi*st1*sp1
    kout(3) = -sti*st1*cp1 + cti*ct1

  end subroutine anisotropic_direction_HIcore

  
  subroutine anisotropic_direction_Rayleigh(kin,kout,mu,bu,iran)

    ! ---------------------------------------------------------------------------------
    ! Sends back new direction vector kout as a function of incident direction kin, for a phase function
    ! described by P(mu) = 3/8 * (1 + mu**2) (with mu = cos(theta) = kin.kout). This is a good
    ! description, e.g., of wing scatterings on HI atoms.
    ! It is actually the phase function of Rayleigh scattering.
    ! ---------------------------------------------------------------------------------
    ! INPUTS:
    ! - kin  : normalized direction vector of incident photon
    ! - iran : state of random number generator
    ! OUTPUTS:
    ! - kout : normalized direction vector of scattered photon
    ! - mu   : dod-product between kin and kout (i.e. cos(theta))
    ! - bu   : sin(theta) (i.e. sqrt(1-mu**2))
    ! - iran : updated state of random number generator
    ! 
    ! Notes on the method : 
    ! ---------------------
    ! To draw theta values, we compute the cumulative probability from above :
    ! P(< mu) = 1/2 + 3/8 * mu + 1/8 * mu**3
    ! We fit the reciprocal function with the following polynomial function giving a better
    ! than 0.53% accuracy everywhere:
    ! mu = -24.901267 x^7 + 87.154434 x^6 -114.220525 x^5 + 67.665227 x^4 -18.389694 x^3 + 3.496531 x^2 + 1.191722 x^1 -0.998214
    ! -> to get a value of mu (hence theta), we draw x in [0,1] and compute mu from the above fit
    ! ---------------------------------------------------------------------------------

    implicit none
    
    real(kind=8),intent(in)       :: kin(3)
    real(kind=8),intent(out)      :: kout(3)
    real(kind=8),intent(out)      :: mu,bu
    integer(kind=4),intent(inout) :: iran
    real(kind=8)                  :: phi,x,cti,sti,cpi,spi,ct1,st1,cp1,sp1

    phi = twopi * ran3(iran)
    x   = ran3(iran)
    mu = ((((((-24.901267*x + 87.154434)*x -114.220525)*x + 67.665227)*x -18.389694)*x + 3.496531)*x + 1.191722)*x -0.998214
    ! angular description of kin in external frame (box coordinates)
    cti = kin(3)
    sti = sqrt(1.d0 - cti**2)  ! sin(theta) is positive for theta in [0,pi]. 
    if (sti > 0) then 
       cpi = kin(1)/sti
       spi = kin(2)/sti
    else
       cpi = 1.
       spi = 0.
    end if
    ! angular description of kout (relative to k)
    ct1 = mu
    st1 = sqrt(1.0d0 - ct1*ct1)
    bu  = st1
    cp1 = cos(phi)
    sp1 = sin(phi)
    ! vector kout (such that indeed knew . k = ct1) in external frame (box coords.)
    kout(1) = cti*cpi*st1*cp1 + sti*cpi*ct1 - spi*st1*sp1
    kout(2) = cti*spi*st1*cp1 + sti*spi*ct1 + cpi*st1*sp1
    kout(3) = -sti*st1*cp1 + cti*ct1

  end subroutine anisotropic_direction_Rayleigh


  subroutine anisotropic_direction_Dust(kin,kout,mu,iran,g_dust)

    ! -------------------------------------------------------------------------------------------------
    ! Returns new direction vector kout as a function of incident direction kin, for a phase function
    ! given by Henyey-Greenstein.
    ! INPUTS:
    ! - kin  : normalized direction vector of incident photon
    ! - iran : state of random number generator
    ! OUTPUTS:
    ! - kout : normalized direction vector of scattered photon
    ! - mu   : dod-product between kin and kout (i.e. cos(theta))
    ! - iran : updated state of random number generator
    ! -------------------------------------------------------------------------------------------------

    implicit none

    real(kind=8),intent(in)       :: kin(3)
    real(kind=8),intent(out)      :: kout(3)
    real(kind=8),intent(out)      :: mu
    integer(kind=4),intent(inout) :: iran
    real(kind=8)                  :: phi,cti,sti,cpi,spi,ct1,st1,cp1,sp1,ra
    real(kind=8),intent(in)       :: g_dust


    !! determine scattering angle (in atom's frame)
    ! use White 79 approximation for the "reciprocal" of cumulative Henyey-Greenstein phase fct:
    ra=ran3(iran) 
    mu = (1.+g_dust*g_dust-((1.-g_dust*g_dust)/(1.-g_dust+2.*g_dust*ra))**2)/(2.*g_dust)

    !! angular description of kin in external frame (box coordinates)
    ! ---------------------------------------------------------------------------------
    ! kx = sin(theta) * cos(phi)
    ! ky = sin(theta) * sin(phi)
    ! kz = cos(theta)
    ! cti, sti, cpi, spi correspond to kin
    ! ---------------------------------------------------------------------------------
    cti = kin(3)              
    sti = sqrt(1.d0 - cti**2)  ! sin(theta) is positive for theta in [0,pi]. 
    if (sti > 0) then 
       cpi = kin(1)/sti       
       spi = kin(2)/sti       
    else
       cpi = 1.
       spi = 0.
    end if
    
    !! angular description of kout (relative to kin)
    ct1 = mu
    st1 = sqrt(1.0d0 - ct1*ct1)
    phi = twopi * ran3(iran)
    cp1 = cos(phi)
    sp1 = sin(phi)
    
    !! vector kout (such that indeed kout . kin = ct1) in external frame (box coords.)
    kout(1) = cti*cpi*st1*cp1 + sti*cpi*ct1 - spi*st1*sp1
    kout(2) = cti*spi*st1*cp1 + sti*spi*ct1 + cpi*st1*sp1
    kout(3) = -sti*st1*cp1 + cti*ct1
    
  end subroutine anisotropic_direction_Dust


end module module_utils
