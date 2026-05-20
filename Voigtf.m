function [W]= Voigtf(X,Y)
T1 = complex(Y,-X); S = abs(X)+Y;
if S >= 15 %Region I
W= T1.*0.5641896./(0.5+T1.*T1);
else
if S >= 5.5 %Region II
U= T1.*T1;
W= T1.*(1.410474+U.*0.5641896)./(0.75+U.*(3+U));
else
if Y >= (0.195.*abs(X)-0.176) %Region III
Wnum= (16.4955+T1.*(20.20933+T1.*(11.96482+T1.*(3.778987+T1.*0.5642236))));
Wden= (16.4955+T1.*(38.82363+T1.*(39.27121+T1.*(21.69274+T1.*(6.699398+T1)))));
W=Wnum./Wden;
else %Region IV
U= T1.*T1;
Wnum=T1.*(36183.31-U.*(3321.9905-U.*(1540.787-U.*( 219.0313-U.*(35.76683-U.*(1.320522-U.*0.56419))))));
Wden =(32066.6-U.*(24322.84-U.*(9022.228-U.*(2186.181-U.*(364.2191-U.*(61.57037-U.*(1.841439-U)))))));
W=Wnum./Wden;
W= complex(exp(real(U)).*cos(imag(U)),0)-W;
end
end
end
W = real(W);
end