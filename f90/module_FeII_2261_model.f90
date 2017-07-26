module module_FeII_2261_model ! Fe_II UV4

  ! This module describes the absorption of photons by FeII from level  3d^6 4s 9/2 to level 3d^6 4p 9/2.
  ! This transition is at 2260.78 A. (named 2261)
  ! The module also implements the two decay channels (resonant and fluorescent) at 2260.78 A and 2280.62 A. 

  use module_constants
  use module_utils, only : voigt_fit, isotropic_direction
  use module_uparallel
  use module_random

  implicit none

  private

  ! Atomic data, taken from Zhu et al, 2015 (Table 2)
  ! In this module, we use the following convention :
  ! level 1 is 3d^6 4s 9/2
  ! level 2 is 3d^6 4s 7/2
  ! level 3 is 3d^6 4p 9/2

  ! transition between levels 1 and 3
  real(kind=8),parameter :: lambda13       = 2260.78d0                ! transition wavelength [A]
  real(kind=8),parameter :: lambda13_cm    = lambda13 / cmtoA         ! [cm]
  real(kind=8),parameter :: nu13           = clight / lambda13_cm     ! [Hz]
  real(kind=8),parameter :: f13            = 2.44d-3                  ! oscillator strength
  real(kind=8),parameter :: sigma13_factor = pi*e_ch**2*f13/me/clight ! multiply by Voigt(x,a)/nu_D to get sigma.
  real(kind=8),parameter :: A31            = 3.18d6                   ! spontaneous decay [/s]

  ! transition between levels 3 and 2
  real(kind=8),parameter :: lambda23       = 2280.62d0                ! transition wavelength [A]
  real(kind=8),parameter :: lambda23_cm    = lambda23 / cmtoA         ! [cm]
  real(kind=8),parameter :: nu23           = clight / lambda23_cm     ! [Hz]
  real(kind=8),parameter :: A32            = 4.49d6                   ! spontaneous decay [/s]

  real(kind=8),parameter :: A31_over_A31_plus_A32 = A31 / (A31+A32)
  
  public :: get_tau_FeII_2261, scatter_FeII_2261

contains

  function get_tau_FeII_2261(nFeII, vth, distance_to_border_cm, nu_cell)

    ! --------------------------------------------------------------------------
    ! compute optical depth of SiII-2260.78 over a given distance
    ! --------------------------------------------------------------------------
    ! INPUTS:
    ! - nFeII    : number density of FeII ions                              [ cm^-3 ]
    ! - vth      : thermal (+ small-scale turbulence) velocity of FeII ions [ cm / s ]
    ! - distance_to_border_cm : distance over which we compute tau          [ cm ]
    ! - nu_cell  : photon's frequency in the frame of the cell              [ Hz ]
    ! OUTPUT :
    ! - get_tau_FeII_2261 : optical depth of Fer's line over distance_to_border_cm
    ! --------------------------------------------------------------------------
    
    real(kind=8),intent(in) :: nFeII,vth,distance_to_border_cm,nu_cell
    real(kind=8)            :: nu_D,x_cell,sigma,a,h,get_tau_FeII_2261

    ! compute Doppler width and a-parameter
    nu_D = vth / lambda13_cm
    a    = A31 / (fourpi * nu_D)

    ! cross section of FeII-2260.78
    x_cell = (nu_cell - nu13) / nu_D
    h      = voigt_fit(x_cell,a)
    sigma  = sigma13_factor / nu_D * h

    get_tau_FeII_2261 = sigma * nFeII * distance_to_border_cm
   
    return

  end function get_tau_FeII_2261

  
  subroutine scatter_FeII_2261(vcell,vth,nu_cell,k,nu_ext,iran)

    ! ---------------------------------------------------------------------------------
    ! perform scattering event on a FeII ion
    ! The photon is absorbed in transition 1->3 and may decay as 3->1 or 3->2. 
    ! ---------------------------------------------------------------------------------
    ! INPUTS :
    ! - vcell    : bulk velocity of the gas (i.e. cell velocity)       [ cm / s ] 
    ! - vth      : thermal (+turbulent) velocity dispersion of H atoms [ cm / s ] 
    ! - nu_cell  : frequency of incoming photon in cell's rest-frame   [ Hz ] 
    ! - k        : propagaction vector (normalized) 
    ! - nu_ext   : frequency of incoming photon, in external frame     [ Hz ]
    ! - iran     : random number generator seed
    ! OUTPUTS :
    ! - nu_cell  : updated frequency in cell's frame   [ Hz ]
    ! - nu_ext   : updated frequency in external frame [ Hz ]
    ! - k        : updated propagation direction
    ! _ iran     : updated value of seed
    ! ---------------------------------------------------------------------------------

    real(kind=8),intent(inout)              :: nu_cell, nu_ext
    real(kind=8),dimension(3),intent(inout) :: k
    real(kind=8),dimension(3),intent(in)    :: vcell
    real(kind=8),intent(in)                 :: vth
    integer(kind=4),intent(inout)           :: iran
    real(kind=8)                            :: delta_nu_doppler, a, x_cell, blah, upar, ruper
    real(kind=8)                            :: r2, uper, nu_atom, mu, bu, scalar
    real(kind=8),dimension(3)               :: knew

    ! define x_cell & a
    delta_nu_doppler = vth / lambda13_cm 
    a = A31 / fourpi / delta_nu_doppler
    x_cell = (nu_cell - nu13) / delta_nu_doppler

    ! 1/ component parallel to photon's propagation
    ! -> get velocity of interacting atom parallel to propagation
    blah = ran3(iran)
#ifdef SWITCH_OFF_UPARALLEL
    upar = 0.
#else
    upar = get_uparallel(a,x_cell,blah)
#endif
    upar = upar * vth    ! upar is an x -> convert to a velocity 

    ! 2/ component perpendicular to photon's propagation
    ruper  = ran3(iran)
    r2     = ran3(iran)
    uper   = sqrt(-log(ruper))*cos(twopi*r2)
    uper   = uper * vth  ! from x to velocity

    ! 3/ chose de-excitation channel to determine output freq. in atom's frame
    r2 = ran3(iran)
    if (r2 <= A31_over_A31_plus_A32) then
       ! photon goes down to level 1 -> coherent scattering
       nu_atom = nu_cell - nu_ext * upar/clight ! incoming frequency in atom's frame = outcoming freq in same frame
    else
       ! photons goes down to level two ...
       nu_atom = nu23 
    end if
    
    ! 4/ determine direction of scattered photon
    call isotropic_direction(knew,iran)
    mu = k(1)*knew(1) + k(2)*knew(2) + k(3)*knew(3)
    bu = sqrt(1.0d0 - mu*mu)
    
    ! 5/ compute atom freq. in external frame, after scattering
    scalar = knew(1) * vcell(1) + knew(2) * vcell(2) + knew(3)* vcell(3)
    nu_ext = nu_atom * (1.0d0 + scalar/clight + (upar*mu + bu*uper)/clight)
    nu_cell = (1.d0 - scalar/clight) * nu_ext 
    k = knew

  end subroutine scatter_FeII_2261

end module module_FeII_2261_model