function plot_simulation_results(simResults, varargin)
%PLOT_SIMULATION_RESULTS Generates publication-grade figures for 6G SSB evaluation.
%
%   PLOT_SIMULATION_RESULTS(SIMRESULTS)
%   plots and exports Figures 1 to 4:
%     - Figure 1: PBCH BLER vs SNR at 3 km/h (Pedestrian)
%     - Figure 2: PBCH BLER vs SNR at 120 km/h (Vehicular Doppler Aging)
%     - Figure 3: Joint PSS/SSS MDR vs SNR (127 RE vs 240 RE SSS)
%     - Figure 4: Channel Estimation MSE vs SNR
%
%   (Figure 5: 2D SSB Resource Grid Layout is pre-generated in M1)

p = inputParser;
addParameter(p, 'OutputDir', 'figures', @ischar);
parse(p, varargin{:});
outDir = p.Results.OutputDir;

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

snrdB = simResults.snrdB;
archs = simResults.architectures;

% Colors and styling
colors = struct(...
    'Legacy',  [0.8500 0.3250 0.0980], ... % Red/Orange
    'DesignA', [0.0000 0.4470 0.7410], ... % Blue
    'DesignB', [0.4660 0.6740 0.1880], ... % Green
    'Jio',     [0.4940 0.1840 0.5560]  ... % Purple
);

markers = struct(...
    'Legacy',  's-', ...
    'DesignA', 'o-', ...
    'DesignB', '^-', ...
    'Jio',     'd-'  ...
);

% -------------------------------------------------------------------------
% Figure 1: PBCH BLER vs SNR at 3 km/h (Pedestrian)
% -------------------------------------------------------------------------
f1 = figure('Name', 'Fig1_BLER_Pedestrian', 'Position', [100, 100, 750, 520], 'Color', 'w');
hold on; grid on; box on;
set(gca, 'YScale', 'log', 'FontSize', 12, 'LineWidth', 1.1);

for i = 1:length(archs)
    arch = archs{i};
    bler_data = max(simResults.bler_3kmph.(arch), 1e-4);
    semilogy(snrdB, bler_data, markers.(arch), 'LineWidth', 2.0, ...
        'MarkerSize', 8, 'Color', colors.(arch), ...
        'DisplayName', sprintf('%s (Rate R=%.4f)', getArchLabel(arch), simResults.codeRates.(arch)));
end

% Reference lines at 10% and 1% BLER
yline(0.10, '--k', '10% BLER Baseline', 'LineWidth', 1.2, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');
yline(0.01, ':k', '1% BLER Target', 'LineWidth', 1.2, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');

xlabel('SNR per RE (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('PBCH Block Error Rate (BLER)', 'FontSize', 13, 'FontWeight', 'bold');
title({'3GPP Rel-20 6G SSB: PBCH BLER vs SNR (Pedestrian 3 km/h)', ...
       'Carrier: 7 GHz, SCS: 30 kHz, TDL-C 300ns, 1T4R SIMO MRC, SCL L=8'}, 'FontSize', 12);
legend('Location', 'southwest', 'FontSize', 10);
xlim([min(snrdB), max(snrdB)]);
ylim([1e-4, 1.2]);

saveas(f1, fullfile(outDir, 'fig1_bler_pedestrian.png'));
savefig(f1, fullfile(outDir, 'fig1_bler_pedestrian.fig'));
fprintf('  [SAVED] Figure 1: %s\n', fullfile(outDir, 'fig1_bler_pedestrian.png'));

% -------------------------------------------------------------------------
% Figure 2: PBCH BLER vs SNR at 120 km/h (Vehicular Mobility)
% -------------------------------------------------------------------------
f2 = figure('Name', 'Fig2_BLER_Vehicular', 'Position', [150, 150, 750, 520], 'Color', 'w');
hold on; grid on; box on;
set(gca, 'YScale', 'log', 'FontSize', 12, 'LineWidth', 1.1);

for i = 1:length(archs)
    arch = archs{i};
    bler_data = max(simResults.bler_120kmph.(arch), 1e-4);
    semilogy(snrdB, bler_data, markers.(arch), 'LineWidth', 2.0, ...
        'MarkerSize', 8, 'Color', colors.(arch), ...
        'DisplayName', sprintf('%s', getArchLabel(arch)));
end

yline(0.10, '--k', '10% BLER', 'LineWidth', 1.2, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');
yline(0.01, ':k', '1% BLER', 'LineWidth', 1.2, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');

xlabel('SNR per RE (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('PBCH Block Error Rate (BLER)', 'FontSize', 13, 'FontWeight', 'bold');
title({'3GPP Rel-20 6G SSB: PBCH BLER vs SNR (Vehicular 120 km/h)', ...
       'Highlighting Doppler Aging Breakdown of Design A vs Comb-SSS Resilience'}, 'FontSize', 12);
legend('Location', 'southwest', 'FontSize', 10);
xlim([min(snrdB), max(snrdB)]);
ylim([1e-4, 1.2]);

saveas(f2, fullfile(outDir, 'fig2_bler_vehicular.png'));
savefig(f2, fullfile(outDir, 'fig2_bler_vehicular.fig'));
fprintf('  [SAVED] Figure 2: %s\n', fullfile(outDir, 'fig2_bler_vehicular.png'));

% -------------------------------------------------------------------------
% Figure 3: Joint PSS/SSS Missed Detection Rate (MDR)
% -------------------------------------------------------------------------
f3 = figure('Name', 'Fig3_SSS_MDR', 'Position', [200, 200, 750, 520], 'Color', 'w');
hold on; grid on; box on;
set(gca, 'YScale', 'log', 'FontSize', 12, 'LineWidth', 1.1);

mdr_legacy = max(simResults.mdr_legacy, 1e-4);
mdr_ext = max(simResults.mdr_extended, 1e-4);

semilogy(snrdB, mdr_legacy, 's--', 'LineWidth', 2.2, 'MarkerSize', 8, ...
    'Color', colors.Legacy, 'DisplayName', 'Legacy SSS (127 REs, 10.5 RB)');
semilogy(snrdB, mdr_ext, 'o-', 'LineWidth', 2.2, 'MarkerSize', 8, ...
    'Color', colors.DesignA, 'DisplayName', '6G Extended SSS (240 REs, 20 RB)');

yline(0.01, ':k', '1% MDR Target (3GPP Baseline)', 'LineWidth', 1.2, 'FontSize', 10, 'LabelHorizontalAlignment', 'left');

xlabel('SNR per RE (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Cell ID Missed Detection Rate (MDR)', 'FontSize', 13, 'FontWeight', 'bold');
title({'3GPP Rel-20 6G SSB: SSS Detection Performance (MDR)', ...
       '240 RE Extended SSS vs 127 RE Legacy SSS (TDL-C 300ns, 7 GHz)'}, 'FontSize', 12);
legend('Location', 'northeast', 'FontSize', 11);
xlim([min(snrdB), max(snrdB)]);
ylim([1e-4, 1.2]);

saveas(f3, fullfile(outDir, 'fig3_mdr_comparison.png'));
savefig(f3, fullfile(outDir, 'fig3_mdr_comparison.fig'));
fprintf('  [SAVED] Figure 3: %s\n', fullfile(outDir, 'fig3_mdr_comparison.png'));

% -------------------------------------------------------------------------
% Figure 4: Channel Estimation MSE vs SNR
% -------------------------------------------------------------------------
f4 = figure('Name', 'Fig4_Channel_MSE', 'Position', [250, 250, 750, 520], 'Color', 'w');
hold on; grid on; box on;
set(gca, 'YScale', 'log', 'FontSize', 12, 'LineWidth', 1.1);

for i = 1:length(archs)
    arch = archs{i};
    mse_3 = simResults.mse_3kmph.(arch);
    semilogy(snrdB, mse_3, markers.(arch), 'LineWidth', 2.0, 'MarkerSize', 8, ...
        'Color', colors.(arch), 'DisplayName', sprintf('%s (3 km/h)', getArchLabel(arch)));
    
    % Plot 120 km/h dashed
    mse_120 = simResults.mse_120kmph.(arch);
    semilogy(snrdB, mse_120, [markers.(arch)(1), '--'], 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', colors.(arch), 'DisplayName', sprintf('%s (120 km/h)', getArchLabel(arch)));
end

xlabel('SNR per RE (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Channel Estimation MSE', 'FontSize', 13, 'FontWeight', 'bold');
title({'3GPP Rel-20 6G SSB: Channel Estimation MSE vs SNR', ...
       'Solid: 3 km/h (Pedestrian), Dashed: 120 km/h (Vehicular Doppler Aging)'}, 'FontSize', 12);
legend('Location', 'southwest', 'FontSize', 9, 'NumColumns', 2);
xlim([min(snrdB), max(snrdB)]);

saveas(f4, fullfile(outDir, 'fig4_ch_est_mse.png'));
savefig(f4, fullfile(outDir, 'fig4_ch_est_mse.fig'));
fprintf('  [SAVED] Figure 4: %s\n', fullfile(outDir, 'fig4_ch_est_mse.png'));

end

function lbl = getArchLabel(arch)
switch arch
    case 'Legacy'
        lbl = 'Legacy 5G NR (127 SSS + Comb-4 DMRS)';
    case 'DesignA'
        lbl = 'QC Design A (240 SSS-as-DMRS Concentrated)';
    case 'DesignB'
        lbl = 'QC Design B / MTK (Comb-3 SSS Distributed)';
    case 'Jio'
        lbl = 'Jio Platforms (DMRS + SSS-Assisted)';
    otherwise
        lbl = arch;
end
end
