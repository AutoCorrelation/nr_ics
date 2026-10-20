function plot_ablation_results(results)
%%PLOT_ABLATION_RESULTS Generate ablation study comparison figures.

    snr = results.snr;
    figDir = 'figures';
    if ~exist(figDir, 'dir'), mkdir(figDir); end

    speedNames = {'pedestrian_3kmph', 'vehicular_120kmph'};
    speedLabels = {'Pedestrian 3 km/h', 'Vehicular 120 km/h'};

    %% Figure 1: PBCH BLER Ablation
    fig1 = figure('Position', [50, 50, 1200, 500], 'Color', 'w');
    for sp = 1:2
        r = results.(speedNames{sp});
        subplot(1, 2, sp);
        ax = gca;
        set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', [0.8 0.8 0.8]);
        semilogy(snr, r.bler_legacy, '-ko', 'LineWidth', 2, 'MarkerSize', 7, 'DisplayName', 'Legacy (4-sym)');
        hold on;
        semilogy(snr, max(r.bler_sss_only, 1e-4), '--b^', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'SSS-Only (no E-RS)');
        semilogy(snr, max(r.bler_ers_only, 1e-4), '--gv', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'ERS-Only (no SSS-rep)');
        semilogy(snr, max(r.bler_full, 1e-4), '-rs', 'LineWidth', 2, 'MarkerSize', 7, 'DisplayName', 'Full Proposed');
        hold off;
        grid on; xlabel('SNR (dB)', 'FontSize', 11); ylabel('PBCH BLER', 'FontSize', 11);
        title(speedLabels{sp}, 'FontSize', 12);
        legend('Location', 'southwest', 'FontSize', 9);
        ylim([1e-3 1]); xlim([snr(1) snr(end)]);
    end
    sgtitle('Ablation Study: PBCH BLER — SSS-Only vs ERS-Only vs Full', 'FontSize', 13, 'FontWeight', 'bold');
    exportgraphics(fig1, fullfile(figDir, 'fig_ablation_bler.png'), 'Resolution', 300, 'BackgroundColor', 'white');
    savefig(fig1, fullfile(figDir, 'fig_ablation_bler.fig'));
    fprintf('Saved: fig_ablation_bler.png\n');

    %% Figure 2: SSS MDR Ablation (Non-Coherent)
    fig2 = figure('Position', [50, 50, 1200, 500], 'Color', 'w');
    for sp = 1:2
        r = results.(speedNames{sp});
        subplot(1, 2, sp);
        ax = gca;
        set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', [0.8 0.8 0.8]);
        semilogy(snr, max(r.mdr_legacy, 1e-4), '-ko', 'LineWidth', 2, 'MarkerSize', 7, 'DisplayName', 'Legacy (4-sym)');
        hold on;
        semilogy(snr, max(r.mdr_sss_only_nc, 1e-4), '--b^', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'SSS-Only NC');
        semilogy(snr, max(r.mdr_ers_only_nc, 1e-4), '--gv', 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', 'ERS-Only NC');
        semilogy(snr, max(r.mdr_full_nc, 1e-4), '-rs', 'LineWidth', 2, 'MarkerSize', 7, 'DisplayName', 'Full Proposed NC');
        hold off;
        grid on; xlabel('SNR (dB)', 'FontSize', 11); ylabel('SSS MDR', 'FontSize', 11);
        title(speedLabels{sp}, 'FontSize', 12);
        legend('Location', 'southwest', 'FontSize', 9);
        ylim([1e-3 1]); xlim([snr(1) snr(end)]);
    end
    sgtitle('Ablation Study: SSS MDR (Non-Coherent) — SSS-Only vs ERS-Only vs Full', 'FontSize', 13, 'FontWeight', 'bold');
    exportgraphics(fig2, fullfile(figDir, 'fig_ablation_mdr.png'), 'Resolution', 300, 'BackgroundColor', 'white');
    savefig(fig2, fullfile(figDir, 'fig_ablation_mdr.fig'));
    fprintf('Saved: fig_ablation_mdr.png\n');
end
