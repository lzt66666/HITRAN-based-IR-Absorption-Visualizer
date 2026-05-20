function [F,ST,DeltavC,DeltavD,A,a,w]= abline(v,v0,ST0,gammair0,gammaself0,E11,nair,M,X_target,QT0,QT,T,P,L,delta_air)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
%   Unit in this function:
%    v,v0/cm^-1; ST0/-cm^-1./(mol cm^-2)
%    gammair0,gammairself0/ -cm^-1./atm
%    E11(E'') /-cm-1; nair/ 1; M:molar mass /kg*mol^-1
%    X_target: mole fraction for target species/ 1;
%    QT0,QT/ partition function at 296K and T;
%    T /K; P /atm; L /cm
%    Set delta_air as 0 to ignore pressure shift.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
h=6.62606896e-34;%planck -J.*s
c=299792458*100;%lightspeed        -cm./s
k=1.3806505e-23;%boltzmann  -J./K
T0=296;%HITRAN T      -K
Xair=1-X_target;

v0 = v0 + P*Xair*delta_air*(296/T)^0.96;

ST=ST0.*(QT0./QT).*exp(-h.*c.*E11./k.*(1./T-1./T0)).*(1-exp(-h.*c.*v0./k./T))./(1-exp(-h.*c.*v0./k./T0));
%ST -cm-1./atm
ST=7.34e21./T.*ST;
%vC
gammaself=gammaself0.*(T0./T).^0.75;
gammair=gammair0.*(T0./T).^nair;
DeltavC=P.*(X_target.*2.*gammaself+Xair.*2.*gammair);
%vD
DeltavD=v0.*7.1623e-7.*(T./M).^0.5;
%a,w
a=log(2)^0.5.*DeltavC./DeltavD;

w=2.*log(2)^0.5.*(v-v0)./DeltavD;%!!!
%phiV-v
phiV=2./DeltavD.*(log(2)./pi).^0.5.*Voigtf(w,a);
%abline
A = ST.*P.*X_target.*L;
F=A.*phiV;
end
