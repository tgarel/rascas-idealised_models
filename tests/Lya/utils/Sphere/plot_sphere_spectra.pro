pro plot_sphere_spectra

  ;; tau0_arr_st = ['4','5','6','7'];,'8']
  ;; tau0_arr    = [1.d4,1.d5,1.d6,1.d7];,1.d8]

  tau0_arr_st = ['6','6']      ;,'8']
  tau0_arr    = [1.d6,1.d6]  ;,1.d8]
   
  vth         = 128500.0d0       ; cm/s

  PS_Start, File='plots/sphere_spectraDIJK_temp100K_tau6_OneCell.ps',nomatch=1,font=0

  device, helvetica=1,/bold
  device, isolatin1=1,/bold

  ct = 39

  loadct,ct 

  !x.style=1
  !y.style=1
  !x.thick=7
  !y.thick=7
  !x.charsize=1.3
  !y.charsize=1.4
  !p.thick=7
  !p.charthick=20

  for i=0,n_elements(tau0_arr)-1 do begin

     if i eq 0 then myfile = '/Users/tgarel/Rascas_tests/output/sphere_dom/sphere_np1e6_T1e2_ndust0.0_DH0.0_tauH1e'+tau0_arr_st[i]+'_vexp0_NoRecoil_iso/photons_out.dat'

     if i eq 1 then myfile = '/Users/tgarel/Rascas_tests/output/cube_dom/sphere_np1e6_T1e2_ndust0.0_DH0.0_tauH1e'+tau0_arr_st[i]+'_vexp0_NoRecoil_iso_OneCell/photons_out.dat'

     print,myfile
     tau0 = tau0_arr[i]
 

     temp        = (vth / 12.85d5)^2. * 1.d4
     a           = 4.71d-4 * (temp/1.d4)^(-0.5) ;(12.85 / b)
     b           = vth / 1.d5                   ; km/s
     print,temp,vth
     
     read_photons,myfile,vth,x_out,tau0,status,xlast,nb_abs,time,ids
     
     ;; Doppler units - x
     
     xx = dindgen(4000) / 3999. * 400. - 200.
     histo,x_out,-250.,250.,750,h

     col = [70,254]
     if i eq 0 then begin
        plot,h.x,h.dn/h.dx/total(h.dn),xtitle='x',ytitle='J(x,'+greek('tau')+'!d0!n)',charthick=5,xr=[-40.,40.],/xs,thick=8,yr=[0.0001,max(h.dn/h.dx/total(h.dn))*1.2],/nodata ;,/ylog
        legendold,['R!dsphere!n = 0.3 L!dbox!n','R!dsphere!n within 1 cell'],textcolors=col,box=0,/left,charsize=1.3,spacing=2.1
     endif

     oplot,h.x,h.dn/h.dx/total(h.dn),thick=5,color=col[i],psym=10 ;,linestyle=i

     ;; Exact Eq. 9 from Dijkstra06 - his tau0 is same as us
     j_x = sqrt(!pi) / sqrt(24.) / a / tau0 * xx * xx * (1.d0 / (1. + cosh(sqrt(2.*!pi^3./27.) * abs(xx*xx*xx)/ a / tau0)))
     x_peak = 0.92 * (a * tau0)^(1./3.)
     oplot,xx,j_x*2.*!pi,color=0,linestyle=2,thick=3 ;,psym=10
     ;; plots,[-1.*x_peak,-1.*x_peak],[0.,1.*max(j_x*2.*!pi)],linestyle=2.,color=254
     ;; plots,[1.*x_peak,1.*x_peak],[0.,1.*max(j_x*2.*!pi)],linestyle=2,color=254


     print,total(j_x*2.*!pi*(xx[1]-xx[0]))
     
     
     ;; Velocity
  
     ;; v_out = b * x_out * (-1.)
     ;; v     = dindgen(100000) / 99999. * 10000. - 5000. ; km/s
     ;; dv    = v(2)-v(1)
     
     ;; ;window,1
     ;; histo,v_out,-2000.,2000.,25000,h
     ;; plot,h.x,h.dn/h.dx/total(h.dn),psym=10,xr=[-50.,50.],/xs
     ;; j_v    = sqrt(!pi) / sqrt(24.) * v * v / a / b / b / tau0 * 1.d0 / (1.0 + cosh(sqrt(2.*!pi^3./27.) * abs(v*v*v)/a / b^3. / tau0))
     ;; v_peak = b * 0.92 * (a * tau0)^(1./3.)
     
     
     ;; oplot,v*(-1.),j_v*2.*!pi / b,color=254,linestyle=2,psym=10
     ;; plots,[-1.*v_peak,-1.*v_peak],[0.,1.*max(j_v*2.*!pi / b)],linestyle=2.,color=254
     ;; plots,[1.*v_peak,1.*v_peak],[0.,1.*max(j_v*2.*!pi / b)],linestyle=2,color=254
     
     
  endfor

  ;legendold,['Nxbin = 2000','Nxbin=500'],textcolors=col,box=0,/right,charsize=1.4

 ; legendold,[greek('tau')+'!d0!n = 10!u4!n',greek('tau')+'!d0!n = 10!u5!n',greek('tau')+'!d0!n = 10!u6!n',greek('tau')+'!d0!n = 10!u7!n'],textcolors=(1+indgen(4))*50,box=0,/right,charsize=1.4

  
  ;legendold,[greek('tau')+'!d0!n = 10!u4!n',greek('tau')+'!d0!n = 10!u5!n',greek('tau')+'!d0!n = 10!u6!n',greek('tau')+'!d0!n = 10!u7!n',greek('tau')+'!d0!n = 10!u8!n'],textcolors=(1+indgen(5))*50,box=0,/right,charsize=1.4
  
  PS_End, /PDF, /Delete_PS
  
  
end
