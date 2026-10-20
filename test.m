clear;

sampling_rate = 15360000;
scs = 30e3;
fft_size = 512;
Ncp = 36;
Ncp0 = 16; % Ncp + Ncp0 = 52 -> first symbol

target_file = 'dump_skt_20260908_145721.dat';


x = loaddump(target_file);

figure(1);
plot(abs(x).^2);
grid on;
xlabel('Sample Index');
ylabel('Instantaneous Power');
title(['Dump Signal Power: ', target_file], 'Interpreter', 'none');

% NR pss sequence generation


% ofdm symbol generation (iFFT)
for i = 1:3
    PSSseq(i,:) = gen_PSSNR(i-1); % (3 127)
end
% NR pss detection


% remove CP and FFT

% 2D grid mapping and plot