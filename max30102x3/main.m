clc;
clear all;
close all;

for i = 1:65536
    m = i/16;
    spo2(i) = -45.060*(m^2) + 30.354*(m) + 94.845;
end