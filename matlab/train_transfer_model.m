%% 迁移学习：随机森林 + 特征工程 + 独立测试集与稳健校正
% 本代码将室外数据划分为：80%训练+验证集（用于模型训练和交叉验证），20%测试集（最终评估）
% 测试集不参与特征筛选、模型训练或偏差校正，仅用于最终评估
% 偏差校正采用简单线性回归，避免 lasso 可能的结构体问题
% 新增：测试集散点图添加95%置信区间，增加CDF、Q-Q图、特征重要性、误差随样本变化图
% 新增：在散点图上显示R²、RMSE、MAE指标
% 新增：模型直接应用与迁移学习残差对比柱状图、误差箱形图
% 修改：去除S特征，仅使用R_norm, G_norm, B_norm
% 更新：统一图形尺寸为700×600，确保所有图例线条与图中一致

clc; clear; close all;

%% 0. 设置全局字体（Times New Roman + 中文兼容）
set(0, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontName', 'Times New Roman');
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultTextFontSize', 12);

%% 1. 加载基础模型和数据
fprintf('==================== 迁移学习系统（仅颜色特征） ====================\n');
try
    load('final_model_tuned.mat', 'final_model');
    fprintf('基础模型加载成功。\n');
catch
    error('请确保 final_model_tuned.mat 存在。');
end

feature_names_orig = {'R_norm','G_norm','B_norm'};  % 去除S
fprintf('特征: %s\n', strjoin(feature_names_orig, ', '));

%% 2. 导入数据
fprintf('\n----- 数据导入 -----\n');
% 室内数据（全部用于训练，仅取颜色特征）
try
    indoor_data = readtable('室内数据.csv');
    X_indoor = [indoor_data.R_norm, indoor_data.G_norm, indoor_data.B_norm]; % 去除S
    y_indoor = indoor_data.watercontent;
    valid = ~any(isnan(X_indoor),2) & ~isnan(y_indoor);
    X_indoor = X_indoor(valid,:);
    y_indoor = y_indoor(valid);
    fprintf('室内数据: %d样本\n', size(X_indoor,1));
catch ME
    error('室内数据加载失败: %s', ME.message);
end

% 室外数据（仅取颜色特征）
outdoor_filename = '室外90.csv';
if ~exist(outdoor_filename, 'file')
    [fname, pname] = uigetfile('*.csv', '选择室外数据文件');
    outdoor_filename = fullfile(pname, fname);
end
outdoor_data = readtable(outdoor_filename);
X_outdoor = [outdoor_data.R_norm, outdoor_data.G_norm, outdoor_data.B_norm]; % 去除S
y_outdoor = outdoor_data.watercontent;
valid = ~any(isnan(X_outdoor),2) & ~isnan(y_outdoor);
X_outdoor = X_outdoor(valid,:);
y_outdoor = y_outdoor(valid);
fprintf('室外数据: %d样本\n', size(X_outdoor,1));

%% 3. 特征工程（基于三个颜色特征）
fprintf('\n===== 特征工程 =====\n');
% 原始特征：3个
% 交互项：3选2组合，共3个
X_eng = [X_outdoor, ...
         X_outdoor(:,1).*X_outdoor(:,2), ...  % R*G
         X_outdoor(:,1).*X_outdoor(:,3), ...  % R*B
         X_outdoor(:,2).*X_outdoor(:,3)];     % G*B
% 平方项：3个
X_eng = [X_eng, X_outdoor.^2];
% 归一化差值指数：NDI = (R - G) / (R + G)
ndi_rg = (X_outdoor(:,1) - X_outdoor(:,2)) ./ (X_outdoor(:,1) + X_outdoor(:,2) + eps);
X_eng = [X_eng, ndi_rg];
% 比值特征
ratio_rg = X_outdoor(:,1) ./ (X_outdoor(:,2) + eps);  % R/G
ratio_rb = X_outdoor(:,1) ./ (X_outdoor(:,3) + eps);  % R/B
X_eng = [X_eng, ratio_rg, ratio_rb];
fprintf('原始特征数: %d, 工程后特征数: %d\n', size(X_outdoor,2), size(X_eng,2));

% 对室内数据同样处理
X_indoor_eng = [X_indoor, ...
                X_indoor(:,1).*X_indoor(:,2), ...
                X_indoor(:,1).*X_indoor(:,3), ...
                X_indoor(:,2).*X_indoor(:,3), ...
                X_indoor.^2];
ndi_rg_indoor = (X_indoor(:,1) - X_indoor(:,2)) ./ (X_indoor(:,1) + X_indoor(:,2) + eps);
X_indoor_eng = [X_indoor_eng, ndi_rg_indoor];
ratio_rg_indoor = X_indoor(:,1) ./ (X_indoor(:,2) + eps);
ratio_rb_indoor = X_indoor(:,1) ./ (X_indoor(:,3) + eps);
X_indoor_eng = [X_indoor_eng, ratio_rg_indoor, ratio_rb_indoor];

%% 4. 划分独立测试集（20%室外数据）
rng(42);                             % 固定种子保证可重复
test_ratio = 0.2;
n_outdoor = size(X_outdoor,1);
test_size = round(n_outdoor * test_ratio);
rand_idx = randperm(n_outdoor);
test_idx = rand_idx(1:test_size);
train_val_idx = rand_idx(test_size+1:end);

y_test = y_outdoor(test_idx);
y_train_val = y_outdoor(train_val_idx);

% 保存室外原始特征测试集（用于直接应用室内模型）
X_outdoor_test = X_outdoor(test_idx, :);

fprintf('\n===== 数据划分 =====\n');
fprintf('室外数据总数: %d\n', n_outdoor);
fprintf('训练+验证集: %d (%.1f%%)\n', length(train_val_idx), 100*(1-test_ratio));
fprintf('独立测试集: %d (%.1f%%)\n', length(test_idx), 100*test_ratio);

%% 5. 特征重要性筛选（仅使用室内数据和室外训练+验证集）
fprintf('\n===== 特征重要性筛选 =====\n');
X_indoor_eng_full = X_indoor_eng;
X_train_val_full = X_eng(train_val_idx, :);
X_test_full = X_eng(test_idx, :);
X_temp = [X_indoor_eng_full; X_train_val_full];
y_temp = [y_indoor; y_train_val];
rng(42);                             % 固定特征筛选模型的随机过程
rf_temp = TreeBagger(100, X_temp, y_temp, 'Method','regression',...
    'OOBPredictorImportance','on');
imp = rf_temp.OOBPermutedPredictorDeltaError;
[~, idx_sorted] = sort(imp, 'descend');
thresh = mean(imp);
keep_idx = idx_sorted(imp(idx_sorted) > thresh);
if isempty(keep_idx)
    keep_idx = 1:size(X_temp,2);
end
fprintf('原始特征数: %d, 筛选后保留: %d\n', size(X_temp,2), length(keep_idx));
X_indoor_eng = X_indoor_eng_full(:, keep_idx);
X_train_val = X_train_val_full(:, keep_idx);
X_test = X_test_full(:, keep_idx);

%% 6. 在训练+验证集上执行5折交叉验证（评估模型稳定性）
rng(42);                             % 再次重置种子，确保交叉验证划分可重复
kfold = 5;
cv = cvpartition(length(y_train_val), 'KFold', kfold);
fprintf('\n===== %d折交叉验证（室外训练+验证子集） =====\n', kfold);

fold_r2 = zeros(kfold,1);
fold_r2_corr = zeros(kfold,1);
for fold = 1:kfold
    train_idx_fold = cv.training(fold);
    val_idx_fold = cv.test(fold);
    
    X_train_fold_full = X_train_val_full(train_idx_fold, :);
    y_train_fold = y_train_val(train_idx_fold);
    X_val_fold_full = X_train_val_full(val_idx_fold, :);
    y_val_fold = y_train_val(val_idx_fold);
    
    % 每一折仅使用该折训练数据进行特征筛选
    X_select_fold = [X_indoor_eng_full; X_train_fold_full];
    y_select_fold = [y_indoor; y_train_fold];
    rng(42 + fold);
    rf_select_fold = TreeBagger(100, X_select_fold, y_select_fold, ...
        'Method','regression','OOBPredictorImportance','on');
    imp_fold = rf_select_fold.OOBPermutedPredictorDeltaError;
    [~, idx_sorted_fold] = sort(imp_fold, 'descend');
    keep_idx_fold = idx_sorted_fold(imp_fold(idx_sorted_fold) > mean(imp_fold));
    if isempty(keep_idx_fold)
        keep_idx_fold = 1:size(X_select_fold,2);
    end

    X_indoor_fold = X_indoor_eng_full(:, keep_idx_fold);
    X_train_fold = X_train_fold_full(:, keep_idx_fold);
    X_val_fold = X_val_fold_full(:, keep_idx_fold);

    % 合并室内数据
    X_comb_fold = [X_indoor_fold; X_train_fold];
    y_comb_fold = [y_indoor; y_train_fold];
    w_comb_fold = [0.2*ones(size(X_indoor_fold,1),1); 0.8*ones(size(X_train_fold,1),1)];
    
    % 训练模型（不计算重要性以提速）
    rng(100 + fold);
    rf_fold = TreeBagger(200, X_comb_fold, y_comb_fold, ...
        'Method','regression','MinLeafSize',3,...
        'NumPredictorsToSample','all','Weights',w_comb_fold,...
        'OOBPredictorImportance','off');
    pred_val = predict(rf_fold, X_val_fold);
    if iscell(pred_val); pred_val = cellfun(@str2double, pred_val); end
    r2 = 1 - sum((y_val_fold - pred_val).^2)/sum((y_val_fold - mean(y_val_fold)).^2);
    fold_r2(fold) = r2;
    
    % 偏差校正（在训练集上拟合线性模型，应用于验证集）
    pred_train = predict(rf_fold, X_train_fold);
    if iscell(pred_train); pred_train = cellfun(@str2double, pred_train); end
    resid_train = y_train_fold - pred_train;
    % 使用简单线性回归拟合残差与预测值的关系
    mdl_corr = fitlm(pred_train, resid_train);
    pred_val_corr = pred_val + predict(mdl_corr, pred_val);
    r2_corr = 1 - sum((y_val_fold - pred_val_corr).^2)/sum((y_val_fold - mean(y_val_fold)).^2);
    fold_r2_corr(fold) = r2_corr;
    
    fprintf('第%d折: 原始R²=%.4f, 校正后R²=%.4f\n', fold, r2, r2_corr);
end

fprintf('\n交叉验证结果（基于训练+验证集）:\n');
fprintf('原始模型 R² = %.4f ± %.4f\n', mean(fold_r2), std(fold_r2));
fprintf('校正后模型 R² = %.4f ± %.4f\n', mean(fold_r2_corr), std(fold_r2_corr));

%% 7. 最终模型训练（使用所有非测试数据：室内 + 室外训练+验证集）
rng(42);                             % 重置种子，保证最终模型训练可重复
fprintf('\n===== 训练最终模型 =====\n');
X_train_final = X_train_val;
y_train_final = y_train_val;
X_comb_final = [X_indoor_eng; X_train_final];
y_comb_final = [y_indoor; y_train_final];
w_comb_final = [0.2*ones(size(X_indoor_eng,1),1); 0.8*ones(size(X_train_final,1),1)];

rf_final = TreeBagger(200, X_comb_final, y_comb_final, ...
    'Method','regression','MinLeafSize',3,'NumPredictorsToSample','all',...
    'Weights',w_comb_final,'OOBPredictorImportance','on');

% 在训练集上拟合校正模型（线性回归）
pred_train_final = predict(rf_final, X_train_final);
if iscell(pred_train_final); pred_train_final = cellfun(@str2double, pred_train_final); end
resid_train_final = y_train_final - pred_train_final;
mdl_corr_final = fitlm(pred_train_final, resid_train_final);

%% 8. 在独立测试集上评估最终模型及直接应用室内模型
fprintf('\n===== 独立测试集评估 =====\n');

% --- 迁移学习模型预测（校正后） ---
pred_test = predict(rf_final, X_test);
if iscell(pred_test); pred_test = cellfun(@str2double, pred_test); end
pred_test_corr = pred_test + predict(mdl_corr_final, pred_test);
resid_transfer = y_test - pred_test_corr;
mae_transfer = mean(abs(resid_transfer));
rmse_transfer = sqrt(mean(resid_transfer.^2));
r2_transfer = 1 - sum(resid_transfer.^2)/sum((y_test - mean(y_test)).^2);

% --- 直接应用室内模型（无迁移学习） ---
pred_direct = predict(final_model, X_outdoor_test);
if iscell(pred_direct); pred_direct = cellfun(@str2double, pred_direct); end
resid_direct = y_test - pred_direct;
mae_direct = mean(abs(resid_direct));
rmse_direct = sqrt(mean(resid_direct.^2));
r2_direct = 1 - sum(resid_direct.^2)/sum((y_test - mean(y_test)).^2);

fprintf('直接应用室内模型: R²=%.4f, RMSE=%.4f, MAE=%.4f\n', r2_direct, rmse_direct, mae_direct);
fprintf('迁移学习校正模型: R²=%.4f, RMSE=%.4f, MAE=%.4f\n', r2_transfer, rmse_transfer, mae_transfer);

%% 9. 保存结果（测试集）
results_table = table(y_test, pred_direct, pred_test_corr, ...
    'VariableNames', {'TrueValue', 'Direct_Pred', 'Transfer_Pred'});
writetable(results_table, 'predictions_testset.csv');
fprintf('测试集预测结果已保存至 predictions_testset.csv\n');

%% 10. 高质量论文图形（统一尺寸 700×600，所有图例线条匹配）
fprintf('\n===== 生成论文用图形（基于测试集） =====\n');
figWidth = 700;
figHeight = 600;

% 图1：预测值 vs 真实值（迁移学习校正后）带95%置信区间（坐标放大100倍）
figure('Position', [100, 100, figWidth, figHeight]);

% 将数据乘以100用于绘图
y_test_disp = y_test * 100;
pred_test_corr_disp = pred_test_corr * 100;

scatter(y_test_disp, pred_test_corr_disp, 60, 'filled', ...
    'MarkerFaceColor', [0.2,0.6,0.8], 'MarkerFaceAlpha', 0.7, ...
    'DisplayName', '数据点');
hold on;

% 1:1线（基于放大后的坐标）
plot([min(y_test_disp), max(y_test_disp)], [min(y_test_disp), max(y_test_disp)], 'k--', 'LineWidth', 2, ...
    'DisplayName', '1:1线');

% 线性拟合及置信区间（基于放大后的数据）
p = polyfit(y_test_disp, pred_test_corr_disp, 1);
y_fit_disp = polyval(p, y_test_disp);
plot(y_test_disp, y_fit_disp, 'r-', 'LineWidth', 2, ...
    'DisplayName', sprintf('拟合线: y=%.3fx+%.3f', p(1), p(2)));

n = length(y_test_disp);
x_mean = mean(y_test_disp);
Sxx = sum((y_test_disp - x_mean).^2);
se = sqrt(sum((y_test_disp - y_fit_disp).^2)/(n-2) .* (1/n + (y_test_disp - x_mean).^2/Sxx));
ci_upper = y_fit_disp + 1.96*se;
ci_lower = y_fit_disp - 1.96*se;

h_fill = fill([y_test_disp; flipud(y_test_disp)], [ci_upper; flipud(ci_lower)], [1, 0.8, 0.8], ...
    'FaceAlpha', 0.5, 'EdgeColor', 'none');
set(h_fill, 'DisplayName', '95%置信区间');

xlabel('实测含水量 (%)', 'FontSize', 14);
ylabel('预测含水量 (%)', 'FontSize', 14);
title('迁移学习模型预测效果', 'FontSize', 12);
legend('Location', 'best');
grid on;
axis equal;
% 文本框指标保留原始数值（未放大）
text(0.05, 0.95, sprintf('R² = %.4f\nRMSE = %.4f\nMAE = %.4f', ...
    r2_transfer, rmse_transfer, mae_transfer), ...
    'Units', 'normalized', 'FontSize', 12, 'BackgroundColor', 'white', ...
    'EdgeColor', 'black', 'VerticalAlignment', 'top');
print('-dpng', '-r300', 'TestSet_Prediction_CI.png');
drawnow;

% 图2：残差分布直方图 + 正态拟合（迁移学习）
figure('Position', [150, 150, figWidth, figHeight]);
histogram(resid_transfer, 15, 'Normalization', 'pdf', 'FaceColor', [0.8,0.4,0.4], 'EdgeColor', 'k');
hold on;
x_grid = linspace(min(resid_transfer), max(resid_transfer), 200);
mu = mean(resid_transfer); sigma = std(resid_transfer);
pdf_norm = normpdf(x_grid, mu, sigma);
plot(x_grid, pdf_norm, 'b-', 'LineWidth', 2);
xlabel('残差 (%)', 'FontSize', 14);
ylabel('概率密度', 'FontSize', 14);
title('测试集残差分布（迁移学习）', 'FontSize', 12);
legend('直方图', '正态拟合', 'Location', 'best');
grid on;
print('-dpng', '-r300', 'TestSet_Residuals.png');
drawnow;

% 图3：残差Q-Q图（迁移学习，圆形点，蓝色填充，无边缘）
figure('Position', [200, 200, figWidth, figHeight]);
h = qqplot(resid_transfer);
set(h(1), 'Marker', 'o', ...
          'MarkerEdgeColor', 'none', ...
          'MarkerFaceColor', [0.2, 0.6, 0.8], ...
          'MarkerSize', 5);
set(h(2), 'LineStyle', '--', 'Color', 'r', 'LineWidth', 1.5);
legend([h(1), h(2)], {'数据点', '理论线'}, 'Location', 'southeast');
title('测试集残差Q-Q图', 'FontSize', 12);
xlabel('理论分位数', 'FontSize', 14);
ylabel('样本分位数', 'FontSize', 14);
grid on;
print('-dpng', '-r300', 'TestSet_QQPlot.png');
drawnow;

% 图4：绝对误差累积分布（CDF，迁移学习）
figure('Position', [250, 250, figWidth, figHeight]);
[fe, xe] = ecdf(abs(resid_transfer));
plot(xe, fe, 'b-', 'LineWidth', 2);
xlabel('绝对误差 (%)', 'FontSize', 14);
ylabel('累积比例', 'FontSize', 14);
title('绝对误差累积分布曲线', 'FontSize', 12);
grid on;
print('-dpng', '-r300', 'TestSet_ErrorCDF.png');
drawnow;

% 图5：预测误差随样本编号变化（迁移学习）
figure('Position', [300, 300, figWidth, figHeight]);
plot(1:length(resid_transfer), resid_transfer, 'bo-', 'LineWidth', 1, 'MarkerSize', 4);
hold on;
yline(0, 'r--', 'LineWidth', 1.5);
xlabel('测试样本编号', 'FontSize', 14);
ylabel('残差 (%)', 'FontSize', 14);
title('测试集残差随样本变化', 'FontSize', 12);
legend('残差', '零线', 'Location', 'best');
grid on;
print('-dpng', '-r300', 'TestSet_ResidualsVsIndex.png');
drawnow;

% 图6：交叉验证箱线图
figure('Position', [350, 350, figWidth, figHeight]);
boxplot([fold_r2, fold_r2_corr], 'Labels', {'原始模型','校正模型'});
ylabel('R²'); title('5折交叉验证R²分布（训练+验证子集）'); grid on;
print('-dpng', '-r300', 'CrossValidation_R2.png');
drawnow;

% 图7：特征重要性（最终随机森林）
imp_final = rf_final.OOBPermutedPredictorDeltaError;
[imp_sorted, idx_imp] = sort(imp_final, 'descend');
figure('Position', [400, 400, figWidth, figHeight]);
bar(imp_sorted, 'FaceColor', [0.6,0.4,0.8]);
xlabel('特征索引 (按重要性排序)', 'FontSize', 14);
ylabel('重要性', 'FontSize', 14);
title('最终随机森林特征重要性', 'FontSize', 12);
grid on;
for i = 1:length(imp_sorted)
    text(i, imp_sorted(i) + 0.01, sprintf('%.3f', imp_sorted(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end
print('-dpng', '-r300', 'FeatureImportance.png');
drawnow;

% 图8：学习曲线
train_ratio = linspace(0.2, 1, 10);
cv_learning = zeros(length(train_ratio), 1);
for i = 1:length(train_ratio)
    n_train = round(train_ratio(i) * size(X_train_val,1));
    r2_tmp = zeros(5,1);
    for rep = 1:5
        idx = randperm(size(X_train_val,1), n_train);
        X_cur = X_train_val(idx,:);
        y_cur = y_train_val(idx);
        X_comb_cur = [X_indoor_eng; X_cur];
        y_comb_cur = [y_indoor; y_cur];
        w_cur = [0.2*ones(size(X_indoor_eng,1),1); 0.8*ones(size(X_cur,1),1)];
        rf_cur = TreeBagger(150, X_comb_cur, y_comb_cur, 'Method','regression',...
            'MinLeafSize',3,'NumPredictorsToSample','all','Weights',w_cur);
        pred_cur = predict(rf_cur, X_train_val);
        if iscell(pred_cur); pred_cur = cellfun(@str2double, pred_cur); end
        r2_tmp(rep) = 1 - sum((y_train_val - pred_cur).^2)/sum((y_train_val - mean(y_train_val)).^2);
    end
    cv_learning(i) = mean(r2_tmp);
end
figure('Position', [450, 450, figWidth, figHeight]);
plot(train_ratio*100, cv_learning, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('训练数据比例 (%)', 'FontSize', 14);
ylabel('R²', 'FontSize', 14);
title('学习曲线（随机森林，平均5次随机采样）', 'FontSize', 12);
grid on;
print('-dpng', '-r300', 'LearningCurve.png');
drawnow;

% 图9：真实值 vs 迁移学习校正预测 vs 直接预测（排序对比，Y轴×100，不同标记）
figure('Position', [500, 500, figWidth, figHeight]);
[~, sorted_idx] = sort(y_test);               % 按真实值升序排序
y_true_sorted = y_test(sorted_idx);           % 真实值（原始单位）
y_pred_corr_sorted = pred_test_corr(sorted_idx); % 迁移学习预测（原始单位）
y_pred_direct_sorted = pred_direct(sorted_idx);   % 直接预测（原始单位）

% 乘以100转换为百分比显示
y_true_disp = y_true_sorted * 100;
y_pred_corr_disp = y_pred_corr_sorted * 100;
y_pred_direct_disp = y_pred_direct_sorted * 100;

% 真实值：蓝色实线 + 圆点
plot(1:length(y_test), y_true_disp, 'b-o', 'LineWidth', 1.5, ...
    'MarkerSize', 5, 'MarkerFaceColor', 'b', 'DisplayName', '真实含水率');
hold on;

% 直接预测（基准）：绿色点划线 + 星号
plot(1:length(y_test), y_pred_direct_disp, 'g-.*', 'LineWidth', 1.5, ...
    'MarkerSize', 7, 'MarkerFaceColor', 'g', 'DisplayName', '直接预测（基准）');

% 迁移学习预测：红色虚线 + 三角形
plot(1:length(y_test), y_pred_corr_disp, 'r--^', 'LineWidth', 1.5, ...
    'MarkerSize', 5, 'MarkerFaceColor', 'r', 'DisplayName', '迁移学习预测');

xlabel('样本序号 (按真实值排序)', 'FontSize', 14);
ylabel('含水量 (%)', 'FontSize', 14);
title(sprintf('不同模型预测效果对比 (迁移学习R²=%.4f, 直接R²=%.4f)', r2_transfer, r2_direct), 'FontSize', 12);
legend('Location', 'best');
grid on;
print('-dpng', '-r300', 'BiasCorrection_Comparison.png');
drawnow;

% 图10：模型直接应用 vs 迁移学习 MAE 对比柱状图
figure('Position', [550, 550, figWidth, figHeight]);
bar([mae_direct, mae_transfer], 'FaceColor', [0.95, 0.6, 0.6]);
set(gca, 'XTickLabel', {'直接应用', '迁移学习'});
ylabel('平均绝对误差 MAE (%)', 'FontSize', 14);
title('模型直接应用与迁移学习 MAE 对比', 'FontSize', 12);
grid on;
for i = 1:2
    values = [mae_direct, mae_transfer];
    text(i, values(i) + 0.01, sprintf('%.4f', values(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end
print('-dpng', '-r300', 'ModelComparison_MAE.png');
drawnow;

% 图11：模型直接应用 vs 迁移学习绝对误差箱形图
figure('Position', [600, 600, figWidth, figHeight]);
abs_direct = abs(resid_direct);
abs_transfer = abs(resid_transfer);
boxplot([abs_direct, abs_transfer], 'Labels', {'直接应用', '迁移学习'}, ...
    'Colors', [[0.95, 0.6, 0.6]; [0.2, 0.6, 0.8]]);
ylabel('绝对误差 (%)', 'FontSize', 14);
title('模型直接应用与迁移学习绝对误差分布', 'FontSize', 12);
grid on;
print('-dpng', '-r300', 'ModelComparison_Boxplot.png');
drawnow;

fprintf('\n所有图形已保存。\n');
fprintf('程序执行完成！\n');
