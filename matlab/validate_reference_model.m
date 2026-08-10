%% 室外数据验证 - 随机森林含水量预测模型（仅颜色特征 R_norm, G_norm, B_norm）
clc; clear; close all;

% 设置全局字体为 Times New Roman
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultLegendFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultTextFontSize', 12);

%% 1. 加载已训练的模型
fprintf('正在加载已训练的随机森林模型...\n');
try
    load('final_model_tuned.mat', 'final_model', 'bestParams');
    fprintf('模型加载成功！\n');
    feature_names = {'R_norm', 'G_norm', 'B_norm'};
    fprintf('特征名称: %s\n', strjoin(feature_names, ', '));
catch ME
    error('无法加载模型文件。请确保final_model_tuned.mat文件存在。错误: %s', ME.message);
end

%% 2. 导入室外验证数据
fprintf('\n正在导入室外验证数据...\n');
outdoor_filename = '室外18.csv';
if ~exist(outdoor_filename, 'file')
    [filename, pathname] = uigetfile({'*.csv;*.xls;*.xlsx;*.txt', '数据文件 (*.csv, *.xls, *.xlsx, *.txt)'}, ...
                                      '选择室外数据文件');
    if isequal(filename, 0)
        error('未选择文件，程序终止。');
    end
    outdoor_filename = fullfile(pathname, filename);
end
try
    outdoor_data = readtable(outdoor_filename);
    fprintf('室外数据文件: %s\n', outdoor_filename);
catch ME
    error('无法读取室外数据文件。请检查文件格式。错误: %s', ME.message);
end
fprintf('室外数据列信息：\n');
disp(outdoor_data.Properties.VariableNames);
fprintf('室外数据样本数: %d\n', height(outdoor_data));

%% 3. 数据预处理和特征提取
fprintf('\n正在预处理室外数据...\n');
required_columns = {'R_norm', 'G_norm', 'B_norm', 'watercontent'};
missing_columns = {};
for i = 1:length(required_columns)
    if ~ismember(required_columns{i}, outdoor_data.Properties.VariableNames)
        missing_columns{end+1} = required_columns{i};
    end
end
if ~isempty(missing_columns)
    error('室外数据缺少以下必需列: %s', strjoin(missing_columns, ', '));
end

X_outdoor = [outdoor_data.R_norm, outdoor_data.G_norm, outdoor_data.B_norm];
y_outdoor_true = outdoor_data.watercontent;

if size(X_outdoor, 2) ~= length(feature_names)
    error('模型特征数量（%d）与输入数据特征数量（%d）不匹配。', ...
          length(feature_names), size(X_outdoor,2));
end

nan_features = sum(isnan(X_outdoor), 1);
nan_target = sum(isnan(y_outdoor_true));
if any(nan_features) || nan_target > 0
    fprintf('警告：数据中存在缺失值。\n');
    fprintf('特征缺失值数量: R_norm=%d, G_norm=%d, B_norm=%d\n', ...
            nan_features(1), nan_features(2), nan_features(3));
    fprintf('目标变量缺失值数量: %d\n', nan_target);
    valid_idx = ~any(isnan(X_outdoor), 2) & ~isnan(y_outdoor_true);
    X_outdoor = X_outdoor(valid_idx, :);
    y_outdoor_true = y_outdoor_true(valid_idx);
    fprintf('已移除包含缺失值的行，剩余样本数: %d\n', sum(valid_idx));
end

fprintf('\n室外数据统计信息:\n');
outdoor_stats = table({'R_norm'; 'G_norm'; 'B_norm'; 'watercontent'}, ...
    [mean(X_outdoor(:,1)); mean(X_outdoor(:,2)); mean(X_outdoor(:,3)); mean(y_outdoor_true)], ...
    [std(X_outdoor(:,1)); std(X_outdoor(:,2)); std(X_outdoor(:,3)); std(y_outdoor_true)], ...
    [min(X_outdoor(:,1)); min(X_outdoor(:,2)); min(X_outdoor(:,3)); min(y_outdoor_true)], ...
    [max(X_outdoor(:,1)); max(X_outdoor(:,2)); max(X_outdoor(:,3)); max(y_outdoor_true)], ...
    'VariableNames', {'Variable', 'Mean', 'Std', 'Min', 'Max'});
disp(outdoor_stats);

%% 4. 使用模型进行预测
fprintf('\n使用随机森林模型进行预测...\n');
y_pred_cell = predict(final_model, X_outdoor);
if iscell(y_pred_cell)
    y_outdoor_pred = cellfun(@str2double, y_pred_cell);
else
    y_outdoor_pred = double(y_pred_cell);
end
y_outdoor_true = y_outdoor_true(:);
y_outdoor_pred = y_outdoor_pred(:);
fprintf('预测完成！\n');

%% 5. 计算模型性能指标
fprintf('\n计算模型在室外数据上的性能指标...\n');
n_samples = length(y_outdoor_true);
ss_res = sum((y_outdoor_true - y_outdoor_pred).^2);
ss_tot = sum((y_outdoor_true - mean(y_outdoor_true)).^2);
r2_outdoor = 1 - (ss_res / ss_tot);
rmse_outdoor = sqrt(mean((y_outdoor_true - y_outdoor_pred).^2));
mae_outdoor = mean(abs(y_outdoor_true - y_outdoor_pred));

nonzero_idx = y_outdoor_true ~= 0;
if any(nonzero_idx)
    mape_outdoor = 100 * mean(abs((y_outdoor_true(nonzero_idx) - y_outdoor_pred(nonzero_idx)) ./ y_outdoor_true(nonzero_idx)));
else
    mape_outdoor = NaN;
    fprintf('注意：所有真实值都为0，无法计算MAPE。\n');
end
bias_outdoor = mean(y_outdoor_pred - y_outdoor_true);
corr_coef = corr(y_outdoor_true, y_outdoor_pred);

fprintf('\n==================== 室外数据验证结果 ====================\n');
fprintf('样本数量: %d\n', n_samples);
fprintf('R² (决定系数): %.4f\n', r2_outdoor);
fprintf('RMSE (均方根误差): %.4f\n', rmse_outdoor);
fprintf('MAE (平均绝对误差): %.4f\n', mae_outdoor);
if ~isnan(mape_outdoor)
    fprintf('MAPE (平均绝对百分比误差): %.2f%%\n', mape_outdoor);
end
fprintf('Bias (偏差): %.4f\n', bias_outdoor);
fprintf('相关系数 (r): %.4f\n', corr_coef);
fprintf('预测值范围: %.4f ~ %.4f\n', min(y_outdoor_pred), max(y_outdoor_pred));
fprintf('真实值范围: %.4f ~ %.4f\n', min(y_outdoor_true), max(y_outdoor_true));
fprintf('==========================================================\n');

%% ==================== 6. 可视化 - 所有图像单独绘制 ====================
% 计算残差、误差等
residuals = y_outdoor_true - y_outdoor_pred;
abs_errors = abs(residuals);
error_percentage = 100 * abs_errors ./ abs(y_outdoor_true);
% 放大100倍用于显示
y_true_display = y_outdoor_true * 100;
y_pred_display = y_outdoor_pred * 100;

% 设置统一的图形尺寸
figWidth = 600;
figHeight = 500;

%% 图1: 真实值 vs 预测值散点图（带95%置信区间）
figure('Position', [100, 100, figWidth, figHeight]);
scatter(y_true_display, y_pred_display, 50, 'filled', ...
        'MarkerFaceColor', [0.2, 0.6, 0.8], 'MarkerEdgeColor', 'k', ...
        'MarkerFaceAlpha', 0.7);
hold on;
min_val_disp = min([y_true_display; y_pred_display]);
max_val_disp = max([y_true_display; y_pred_display]);
plot([min_val_disp, max_val_disp], [min_val_disp, max_val_disp], 'r--', 'LineWidth', 2);

% 线性拟合及95%置信区间
mdl_disp = fitlm(y_true_display, y_pred_display);
coeffs = mdl_disp.Coefficients.Estimate;
[ypred_fit_disp, yci_disp] = predict(mdl_disp, [min_val_disp; max_val_disp], 'Alpha', 0.05, ...
                                     'Simultaneous', false);
x_ci = [min_val_disp; max_val_disp];
plot(x_ci, ypred_fit_disp, 'b-', 'LineWidth', 2);
x_fill = [x_ci; flipud(x_ci)];
y_fill = [yci_disp(:,1); flipud(yci_disp(:,2))];
fill(x_fill, y_fill, [1, 0.8, 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'none');

xlabel('真实含水量 (%)');
ylabel('预测含水量 (%)');
title('室外数据: 真实值 vs 预测值 (散点图)');
legend('数据点', '1:1线', sprintf('拟合线: y=%.3fx+%.3f', coeffs(2), coeffs(1)), ...
       '95% 置信区间', 'Location', 'best');
grid on; axis equal;
text(0.05, 0.95, sprintf('R² = %.4f\nRMSE = %.4f\nMAE = %.4f\nn = %d', ...
     r2_outdoor, rmse_outdoor, mae_outdoor, n_samples), ...
     'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
     'BackgroundColor', 'white', 'EdgeColor', 'black');
saveas(gcf, 'Figure1_室外散点图.png');

%% 图2: 残差 vs 预测值
figure('Position', [200, 100, figWidth, figHeight]);
scatter(y_outdoor_pred, residuals, 50, 'filled', ...
        'MarkerFaceColor', [0.8, 0.4, 0.4], 'MarkerFaceAlpha', 0.7);
hold on;
yline(0, 'r-', 'LineWidth', 2);
yline(mean(residuals), 'g--', 'LineWidth', 1.5);
xlabel('预测含水量');
ylabel('残差 (真实值 - 预测值)');
title('残差分析: 残差 vs 预测值');
legend('残差', '零线', sprintf('均值: %.3f', mean(residuals)), 'Location', 'best');
grid on;
text(0.05, 0.95, sprintf('残差统计:\n均值 = %.3f\n标准差 = %.3f\n偏度 = %.3f', ...
     mean(residuals), std(residuals), skewness(residuals)), ...
     'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', 'black');
saveas(gcf, 'Figure2_残差vs预测值.png');

%% 图3: 残差直方图 + 正态拟合
figure('Position', [300, 100, figWidth, figHeight]);
histogram(residuals, 20, 'FaceColor', [0.8, 0.4, 0.4], 'EdgeColor', 'black', 'FaceAlpha', 0.7);
hold on;
pd = fitdist(residuals, 'Normal');
x_pdf = linspace(min(residuals), max(residuals), 100);
y_pdf = pdf(pd, x_pdf);
hist_counts = histcounts(residuals, 20);
max_count = max(hist_counts);
max_pdf = max(y_pdf);
y_pdf_scaled = y_pdf * max_count / max_pdf;
plot(x_pdf, y_pdf_scaled, 'b-', 'LineWidth', 2);
xlabel('残差');
ylabel('频数');
title('残差分布 (直方图)');
legend('残差分布', sprintf('正态拟合 (μ=%.3f, σ=%.3f)', pd.mu, pd.sigma), 'Location', 'best');
grid on;
saveas(gcf, 'Figure3_残差直方图.png');

%% 图4: 百分比误差分布
figure('Position', [400, 100, figWidth, figHeight]);
histogram(error_percentage, 20, 'FaceColor', [0.4, 0.8, 0.4], 'EdgeColor', 'black', 'FaceAlpha', 0.7);
xlabel('绝对百分比误差 (%)');
ylabel('频数');
title('百分比误差分布');
grid on;
text(0.05, 0.95, sprintf('误差统计:\n中位数 = %.1f%%\n90%%分位数 = %.1f%%\n最大误差 = %.1f%%', ...
     median(error_percentage), prctile(error_percentage, 90), max(error_percentage)), ...
     'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
     'BackgroundColor', 'white', 'EdgeColor', 'black');
saveas(gcf, 'Figure4_百分比误差分布.png');

%% 图5: 预测值与真实值排序对比图（Y轴乘以100）
figure('Position', [100, 200, figWidth, figHeight]);
[~, sorted_idx] = sort(y_outdoor_true);
y_true_sorted = y_outdoor_true(sorted_idx) * 100;
y_pred_sorted = y_outdoor_pred(sorted_idx) * 100;

plot(1:n_samples, y_true_sorted, 'r-', 'LineWidth', 2, 'DisplayName', '真实值');
hold on;
plot(1:n_samples, y_pred_sorted, 'b--', 'LineWidth', 2, 'DisplayName', '预测值');
scatter(1:n_samples, y_true_sorted, 30, 'r', 'filled', 'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');
scatter(1:n_samples, y_pred_sorted, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.5, 'HandleVisibility', 'off');

xlabel('样本序号 (按真实值排序)');
ylabel('含水量 (%)');
title('预测值与真实值对比 (排序后)');
legend('Location', 'best');
grid on;
saveas(gcf, 'Figure5_排序对比图.png');

%% 图6: 误差与特征相关性
figure('Position', [200, 200, figWidth, figHeight]);
feature_names_disp = {'R_{norm}', 'G_{norm}', 'B_{norm}'};
corr_with_error = zeros(1, 3);
for i = 1:3
    corr_with_error(i) = corr(X_outdoor(:, i), abs_errors);
end
bar(corr_with_error, 'FaceColor', [0.6, 0.2, 0.8]);
set(gca, 'XTickLabel', feature_names_disp);
ylabel('与绝对误差的相关系数');
title('误差与特征相关性');
grid on;
for i = 1:length(corr_with_error)
    text(i, corr_with_error(i) + 0.02 * sign(corr_with_error(i)), ...
         sprintf('%.3f', corr_with_error(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end
saveas(gcf, 'Figure6_误差特征相关性.png');

%% 图7: 特征空间分布与误差关系（3个组合，分别绘制）
feature_combinations = [1, 2; 1, 3; 2, 3];
titles = {'R_{norm} vs G_{norm}', 'R_{norm} vs B_{norm}', 'G_{norm} vs B_{norm}'};
for i = 1:3
    figure('Position', [100*i, 300, figWidth, figHeight]);
    feat1 = feature_combinations(i, 1);
    feat2 = feature_combinations(i, 2);
    scatter(X_outdoor(:, feat1), X_outdoor(:, feat2), 50, ...
            abs_errors, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.5);
    xlabel(feature_names_disp{feat1});
    ylabel(feature_names_disp{feat2});
    title(titles{i});
    colorbar;
    colormap(jet);
    caxis([0, prctile(abs_errors, 95)]);
    grid on;
    r_feat = corr(X_outdoor(:, feat1), X_outdoor(:, feat2));
    text(0.05, 0.95, sprintf('r = %.3f', r_feat), ...
         'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
         'BackgroundColor', 'white', 'EdgeColor', 'black');
    saveas(gcf, sprintf('Figure7_特征组合%d.png', i));
end

%% 图8: 误差与各个特征的关系（3个子图分别绘制）
for i = 1:3
    figure('Position', [100*i, 400, figWidth, figHeight]);
    scatter(X_outdoor(:, i), abs_errors, 40, 'filled', ...
            'MarkerFaceColor', [0.2, 0.6, 0.8], 'MarkerFaceAlpha', 0.6);
    hold on;
    [x_sorted, sort_idx] = sort(X_outdoor(:, i));
    y_sorted = abs_errors(sort_idx);
    try
        smooth_vals = smooth(x_sorted, y_sorted, 0.3, 'loess');
        plot(x_sorted, smooth_vals, 'r-', 'LineWidth', 2);
        legend('数据点', '趋势线', 'Location', 'best');
    catch
        window_size = max(5, floor(length(x_sorted)/20));
        mov_avg = movmean(y_sorted, window_size);
        plot(x_sorted, mov_avg, 'r-', 'LineWidth', 2);
        legend('数据点', '移动平均', 'Location', 'best');
    end
    xlabel(feature_names_disp{i});
    ylabel('绝对误差');
    title(sprintf('误差 vs %s', feature_names_disp{i}));
    grid on;
    r_error = corr(X_outdoor(:, i), abs_errors);
    text(0.05, 0.95, sprintf('r = %.3f', r_error), ...
         'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
         'BackgroundColor', 'white', 'EdgeColor', 'black');
    saveas(gcf, sprintf('Figure8_误差与特征%d.png', i));
end

%% 图9: 性能总结（双柱状图，分为两个子图单独绘制）
% 子图1: 原始指标
figure('Position', [100, 500, figWidth, figHeight]);
metrics_names = {'R²', 'RMSE', 'MAE', 'MAPE (%)', 'Bias', '相关系数'};
metrics_values = [r2_outdoor, rmse_outdoor, mae_outdoor, ...
                  mape_outdoor, bias_outdoor, corr_coef];
bar(metrics_values, 'FaceColor', [0.2, 0.6, 0.8]);
set(gca, 'XTickLabel', metrics_names, 'XTickLabelRotation', 45);
ylabel('指标值');
title('室外数据验证性能指标');
grid on;
for i = 1:length(metrics_values)
    if i == 4 && ~isnan(mape_outdoor)
        text(i, metrics_values(i) + 0.05*max(metrics_values), ...
             sprintf('%.2f', metrics_values(i)), ...
             'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
    else
        text(i, metrics_values(i) + 0.05*max(metrics_values), ...
             sprintf('%.4f', metrics_values(i)), ...
             'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
    end
end
saveas(gcf, 'Figure9_性能指标原始.png');

% 子图2: 标准化指标
figure('Position', [200, 500, figWidth, figHeight]);
normalized_metrics = zeros(size(metrics_values));
normalized_metrics(1) = r2_outdoor;
normalized_metrics(2) = 1 / (1 + rmse_outdoor);
normalized_metrics(3) = 1 / (1 + mae_outdoor);
normalized_metrics(4) = 1 / (1 + mape_outdoor/100);
normalized_metrics(5) = 1 / (1 + abs(bias_outdoor));
normalized_metrics(6) = corr_coef;
bar(normalized_metrics, 'FaceColor', [0.8, 0.4, 0.4]);
set(gca, 'XTickLabel', metrics_names, 'XTickLabelRotation', 45);
ylabel('标准化指标 (0-1, 越大越好)');
title('标准化性能指标');
ylim([0, 1.1]);
grid on;
for i = 1:length(normalized_metrics)
    text(i, normalized_metrics(i) + 0.05, ...
         sprintf('%.3f', normalized_metrics(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
end
saveas(gcf, 'Figure10_性能指标标准化.png');

%% 图11: 残差 Q-Q 图
figure('Position', [300, 500, figWidth, figHeight]);
h = qqplot(residuals);
set(h(1), 'Marker', 'o', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', [0.2, 0.6, 0.8], 'MarkerSize', 5);
set(h(2), 'LineStyle', '--', 'Color', 'r', 'LineWidth', 1.5);
legend([h(1), h(2)], {'数据点', '理论线'}, 'Location', 'southeast');
title('室外验证残差 Q-Q 图');
xlabel('标准正态分位数');
ylabel('残差分位数');
grid on;
saveas(gcf, 'Figure11_残差QQ图.png');

%% 7. 保存验证结果（与原程序相同，略）
fprintf('\n正在保存验证结果...\n');
validation_results = table(y_outdoor_true, y_outdoor_pred, residuals, ...
                           abs_errors, error_percentage, ...
                           X_outdoor(:,1), X_outdoor(:,2), X_outdoor(:,3), ...
                           'VariableNames', {'True_WaterContent', ...
                                             'Predicted_WaterContent', ...
                                             'Residual', ...
                                             'Absolute_Error', ...
                                             'Percentage_Error', ...
                                             'R_norm', 'G_norm', 'B_norm'});
writetable(validation_results, 'outdoor_validation_results.csv');

performance_metrics = table(metrics_names', metrics_values', normalized_metrics', ...
                           'VariableNames', {'Metric', 'Value', 'Normalized_Value'});
writetable(performance_metrics, 'outdoor_performance_metrics.csv');

report_filename = 'outdoor_validation_report.txt';
fid = fopen(report_filename, 'w');
fprintf(fid, '室外数据模型验证报告（仅颜色特征）\n');
fprintf(fid, '========================================\n');
fprintf(fid, '生成时间: %s\n', datestr(now));
fprintf(fid, '模型文件: final_model_tuned.mat\n');
fprintf(fid, '验证数据: %s\n', outdoor_filename);
fprintf(fid, '样本数量: %d\n', n_samples);
fprintf(fid, '\n一、数据基本信息\n');
fprintf(fid, '特征范围:\n');
fprintf(fid, '  R_norm: %.4f ~ %.4f (均值=%.4f)\n', ...
        min(X_outdoor(:,1)), max(X_outdoor(:,1)), mean(X_outdoor(:,1)));
fprintf(fid, '  G_norm: %.4f ~ %.4f (均值=%.4f)\n', ...
        min(X_outdoor(:,2)), max(X_outdoor(:,2)), mean(X_outdoor(:,2)));
fprintf(fid, '  B_norm: %.4f ~ %.4f (均值=%.4f)\n', ...
        min(X_outdoor(:,3)), max(X_outdoor(:,3)), mean(X_outdoor(:,3)));
fprintf(fid, '含水量范围: %.4f ~ %.4f (均值=%.4f)\n', ...
        min(y_outdoor_true), max(y_outdoor_true), mean(y_outdoor_true));

fprintf(fid, '\n二、模型性能指标\n');
for i = 1:length(metrics_names)
    if i == 4 && ~isnan(mape_outdoor)
        fprintf(fid, '  %s: %.2f\n', metrics_names{i}, metrics_values(i));
    else
        fprintf(fid, '  %s: %.4f\n', metrics_names{i}, metrics_values(i));
    end
end

fprintf(fid, '\n三、模型适用性评估\n');
if r2_outdoor > 0.7
    fprintf(fid, '  模型在室外数据上表现优秀 (R² > 0.7)\n');
elseif r2_outdoor > 0.5
    fprintf(fid, '  模型在室外数据上表现良好 (R² > 0.5)\n');
elseif r2_outdoor > 0.3
    fprintf(fid, '  模型在室外数据上表现一般 (R² > 0.3)\n');
else
    fprintf(fid, '  模型在室外数据上表现较差 (R² ≤ 0.3)\n');
end

fprintf(fid, '\n四、误差分析\n');
fprintf(fid, '  残差统计:\n');
fprintf(fid, '    均值: %.4f\n', mean(residuals));
fprintf(fid, '    标准差: %.4f\n', std(residuals));
fprintf(fid, '    偏度: %.4f\n', skewness(residuals));
fprintf(fid, '    峰度: %.4f\n', kurtosis(residuals));
fprintf(fid, '\n  绝对百分比误差统计:\n');
if ~isnan(mape_outdoor)
    fprintf(fid, '    平均值: %.2f%%\n', mean(error_percentage));
    fprintf(fid, '    中位数: %.2f%%\n', median(error_percentage));
    fprintf(fid, '    90%%分位数: %.2f%%\n', prctile(error_percentage, 90));
    fprintf(fid, '    最大误差: %.2f%%\n', max(error_percentage));
end

fprintf(fid, '\n五、文件输出\n');
fprintf(fid, '  1. 验证结果: outdoor_validation_results.csv\n');
fprintf(fid, '  2. 性能指标: outdoor_performance_metrics.csv\n');
fprintf(fid, '  3. 可视化图形: 已保存为PNG文件\n');
fclose(fid);

fprintf('\n验证结果已保存！\n');
fprintf('1. 验证结果: outdoor_validation_results.csv\n');
fprintf('2. 性能指标: outdoor_performance_metrics.csv\n');
fprintf('3. 验证报告: outdoor_validation_report.txt\n');
fprintf('4. 图形文件: Figure1~11.png\n');

%% 8. 最终建议（与原程序相同）
fprintf('\n========================================\n');
fprintf('模型适用性建议:\n');
fprintf('========================================\n');
if r2_outdoor > 0.7
    fprintf('✓ 模型在室外数据上表现优秀，可以直接应用。\n');
elseif r2_outdoor > 0.5
    fprintf('✓ 模型在室外数据上表现良好，可以考虑直接应用或微调。\n');
    fprintf('  建议检查特征分布是否与训练数据一致。\n');
elseif r2_outdoor > 0.3
    fprintf('⚠ 模型在室外数据上表现一般，建议进行模型微调或重新训练。\n');
    fprintf('  可能原因：室内外数据分布差异较大。\n');
else
    fprintf('✗ 模型在室外数据上表现较差，不建议直接应用。\n');
    fprintf('  建议：\n');
    fprintf('  1. 检查室内外数据的一致性\n');
    fprintf('  2. 考虑重新训练模型或使用迁移学习\n');
    fprintf('  3. 可能需要更多室外数据进行模型调整\n');
end
fprintf('\n主要发现:\n');
if abs(bias_outdoor) > 0.1 * std(y_outdoor_true)
    fprintf('  - 模型存在显著偏差 (Bias = %.4f)\n', bias_outdoor);
end
if max(error_percentage) > 50
    fprintf('  - 部分样本预测误差较大 (最大误差 %.1f%%)\n', max(error_percentage));
end
high_corr_features = find(abs(corr_with_error) > 0.3);
if ~isempty(high_corr_features)
    fprintf('  - 以下特征与预测误差相关性较高:\n');
    for i = 1:length(high_corr_features)
        fprintf('    * %s: r = %.3f\n', ...
                feature_names_disp{high_corr_features(i)}, ...
                corr_with_error(high_corr_features(i)));
    end
    fprintf('    这可能意味着在这些特征范围内模型泛化能力不足。\n');
end
fprintf('\n========================================\n');
fprintf('验证完成！\n');