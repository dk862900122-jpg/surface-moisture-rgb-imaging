%% ==================== 1. 数据导入与预处理 ====================
clc; clear; close all;

% 数据文件名
filename = '室内数据.csv'; % 请根据实际文件名修改

% 检查文件是否存在
if ~exist(filename, 'file')
    error('文件 %s 不存在，请确保文件在当前目录或提供完整路径', filename);
end

% 读取数据
try
    data = readtable(filename);
catch ME
    error('无法读取文件 %s，请检查文件格式。错误信息: %s', filename, ME.message);
end

% 检查数据列
disp('数据列信息：');
disp(data.Properties.VariableNames);

% 确保必需列存在
required_columns = {'R_norm', 'G_norm', 'B_norm', 'watercontent'};
for i = 1:length(required_columns)
    if ~ismember(required_columns{i}, data.Properties.VariableNames)
        error('数据表中缺少必需的列: %s', required_columns{i});
    end
end

% 提取特征和目标变量
X = [data.R_norm, data.G_norm, data.B_norm];
y = data.watercontent;
if size(y, 1) == 1
    y = y';
end

% 显示数据统计信息
disp('数据统计信息:');
disp(table({'R_norm'; 'G_norm'; 'B_norm'; 'watercontent'}, ...
    [mean(X(:,1)); mean(X(:,2)); mean(X(:,3)); mean(y)], ...
    [std(X(:,1)); std(X(:,2)); std(X(:,3)); std(y)], ...
    [min(X(:,1)); min(X(:,2)); min(X(:,3)); min(y)], ...
    [max(X(:,1)); max(X(:,2)); max(X(:,3)); max(y)], ...
    'VariableNames', {'Variable', 'Mean', 'Std', 'Min', 'Max'}));

%% ==================== 2. 划分训练集和验证集 ====================
rng(42);
cv_part = cvpartition(length(y), 'HoldOut', 0.3);
train_idx = training(cv_part);
test_idx  = test(cv_part);

X_train = X(train_idx, :);
y_train = y(train_idx);
X_test  = X(test_idx, :);
y_test  = y(test_idx);

fprintf('\n==================== 数据划分 ====================\n');
fprintf('训练集样本数: %d\n', length(y_train));
fprintf('验证集样本数: %d\n', length(y_test));
fprintf('================================================\n');

%% ==================== 3. 五折交叉验证（默认参数） ====================
rng(42);
k = 5;
cv = cvpartition(length(y_train), 'KFold', k);

r2_scores_cv = zeros(k, 1);
rmse_scores_cv = zeros(k, 1);
mae_scores_cv = zeros(k, 1);
all_y_test_cv = [];
all_y_pred_cv = [];

fprintf('\n开始五折交叉验证（基于训练集，默认参数）...\n');
for fold = 1:k
    fprintf('正在训练第 %d 折...\n', fold);
    
    train_fold_idx = training(cv, fold);
    val_fold_idx   = test(cv, fold);
    
    X_tr_fold = X_train(train_fold_idx, :);
    y_tr_fold = y_train(train_fold_idx);
    X_val_fold = X_train(val_fold_idx, :);
    y_val_fold = y_train(val_fold_idx);
    
    model_fold = TreeBagger(100, X_tr_fold, y_tr_fold, ...
        'Method', 'regression', 'OOBPrediction', 'off', ...
        'MinLeafSize', 5, 'NumPredictorsToSample', 'all');
    
    y_pred_cell = predict(model_fold, X_val_fold);
    if iscell(y_pred_cell)
        y_pred_fold = cellfun(@str2double, y_pred_cell);
    else
        y_pred_fold = double(y_pred_cell);
    end
    
    y_val_fold = y_val_fold(:);
    y_pred_fold = y_pred_fold(:);
    
    all_y_test_cv = [all_y_test_cv; y_val_fold];
    all_y_pred_cv = [all_y_pred_cv; y_pred_fold];
    
    ss_res = sum((y_val_fold - y_pred_fold).^2);
    ss_tot = sum((y_val_fold - mean(y_val_fold)).^2);
    r2 = 1 - (ss_res / ss_tot);
    rmse = sqrt(mean((y_val_fold - y_pred_fold).^2));
    mae = mean(abs(y_val_fold - y_pred_fold));
    
    r2_scores_cv(fold) = r2;
    rmse_scores_cv(fold) = rmse;
    mae_scores_cv(fold) = mae;
    
    fprintf('  第%d折 - R²: %.4f, RMSE: %.4f, MAE: %.4f\n', fold, r2, rmse, mae);
end

mean_r2_cv = mean(r2_scores_cv);
mean_rmse_cv = mean(rmse_scores_cv);
mean_mae_cv = mean(mae_scores_cv);

fprintf('\n==================== 五折交叉验证结果（训练集）====================\n');
fprintf('平均 R²: %.4f\n', mean_r2_cv);
fprintf('平均 RMSE: %.4f\n', mean_rmse_cv);
fprintf('平均 MAE: %.4f\n', mean_mae_cv);
fprintf('R²标准差: %.4f\n', std(r2_scores_cv));
fprintf('RMSE标准差: %.4f\n', std(rmse_scores_cv));
fprintf('MAE标准差: %.4f\n', std(mae_scores_cv));
fprintf('================================================================\n');

%% ==================== 4. 训练集交叉验证散点图（70%训练集） ====================
y_test_cv_display = all_y_test_cv * 100;
y_pred_cv_display = all_y_pred_cv * 100;

figure('Position', [100, 100, 600, 500]);
scatter(y_test_cv_display, y_pred_cv_display, 50, 'filled', 'MarkerFaceAlpha', 0.6);
hold on;
min_val_cv = min([y_test_cv_display; y_pred_cv_display]);
max_val_cv = max([y_test_cv_display; y_pred_cv_display]);
plot([min_val_cv, max_val_cv], [min_val_cv, max_val_cv], 'r--', 'LineWidth', 2);

% 线性拟合及95%置信区间
mdl_cv = fitlm(y_test_cv_display, y_pred_cv_display);
[ypred_cv, yci_cv] = predict(mdl_cv, [min_val_cv; max_val_cv], 'Alpha', 0.05, 'Simultaneous', false);
plot([min_val_cv; max_val_cv], ypred_cv, 'b-', 'LineWidth', 2);
x_fill_cv = [[min_val_cv; max_val_cv]; flipud([min_val_cv; max_val_cv])];
y_fill_cv = [yci_cv(:,1); flipud(yci_cv(:,2))];
fill(x_fill_cv, y_fill_cv, [1 0.8 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'none');

xlabel('真实含水量 (%)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('预测含水量 (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('真实值 vs 预测值 (五折交叉验证, 训练集)', 'FontSize', 14, 'FontWeight', 'bold');
legend('数据点', '1:1线', '拟合线', '95% 置信区间', 'Location', 'best');
grid on;
axis equal;

r2_cv_total = corr(all_y_test_cv, all_y_pred_cv)^2;
rmse_cv_total = sqrt(mean((all_y_test_cv - all_y_pred_cv).^2));
mae_cv_total = mean(abs(all_y_test_cv - all_y_pred_cv));
text(0.05, 0.95, sprintf('R² = %.4f\nRMSE = %.4f\nMAE = %.4f', r2_cv_total, rmse_cv_total, mae_cv_total), ...
    'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', 'black');

saveas(gcf, 'Figure_训练集散点图.png');

%% ==================== 5. 训练集交叉验证残差 Q-Q 图（红色虚线理论线） ====================
residuals_train_cv = all_y_test_cv - all_y_pred_cv;

figure('Position', [100, 150, 600, 500]);
h = qqplot(residuals_train_cv);
set(h(1), 'Marker', 'o', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', [0.2 0.6 0.8], 'MarkerSize', 5);
set(h(2), 'LineStyle', '--', 'Color', 'r', 'LineWidth', 1.5);
legend([h(1), h(2)], {'数据点', '理论线'}, 'Location', 'southeast');
title('训练集（70%）残差 Q-Q 图（五折交叉验证合并）', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('标准正态分位数', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('残差分位数', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
saveas(gcf, 'Figure_训练集残差QQ图.png');

%% ==================== 6. 超参数调优（网格搜索 + 5折交叉验证） ====================
fprintf('\n开始超参数调优（网格搜索 + 5折交叉验证）...\n');
nTreesList = [50, 100, 200];
minLeafList = [1, 5, 10];
numPredToList = [1, 2, 3];

paramResults = [];
bestRMSE = inf;
bestParams = struct();

for nTrees = nTreesList
    for minLeaf = minLeafList
        for numPred = numPredToList
            fprintf('正在测试: nTrees=%d, MinLeaf=%d, NumPred=%d\n', nTrees, minLeaf, numPred);
            cv5 = cvpartition(length(y_train), 'KFold', 5);
            rmse_folds = zeros(5,1);
            for fold = 1:5
                train_fold_idx = training(cv5, fold);
                val_fold_idx   = test(cv5, fold);
                X_tr_fold = X_train(train_fold_idx, :);
                y_tr_fold = y_train(train_fold_idx);
                X_val_fold = X_train(val_fold_idx, :);
                y_val_fold = y_train(val_fold_idx);
                model_fold = TreeBagger(nTrees, X_tr_fold, y_tr_fold, ...
                    'Method', 'regression', 'MinLeafSize', minLeaf, ...
                    'NumPredictorsToSample', numPred, 'OOBPrediction', 'off');
                y_pred_cell = predict(model_fold, X_val_fold);
                if iscell(y_pred_cell)
                    y_pred_fold = cellfun(@str2double, y_pred_cell);
                else
                    y_pred_fold = double(y_pred_cell);
                end
                rmse_folds(fold) = sqrt(mean((y_val_fold - y_pred_fold).^2));
            end
            meanRMSE = mean(rmse_folds);
            fprintf('  平均RMSE = %.4f\n', meanRMSE);
            paramResults = [paramResults; nTrees, minLeaf, numPred, meanRMSE];
            if meanRMSE < bestRMSE
                bestRMSE = meanRMSE;
                bestParams.nTrees = nTrees;
                bestParams.minLeaf = minLeaf;
                bestParams.numPred = numPred;
            end
        end
    end
end

fprintf('\n==================== 最优超参数 ====================\n');
fprintf('树的数量 (nTrees)         : %d\n', bestParams.nTrees);
fprintf('最小叶子大小 (MinLeafSize) : %d\n', bestParams.minLeaf);
fprintf('每次分裂特征数 (NumPred)   : %d\n', bestParams.numPred);
fprintf('交叉验证平均RMSE           : %.4f\n', bestRMSE);
fprintf('====================================================\n');

paramTable = array2table(paramResults, ...
    'VariableNames', {'nTrees', 'MinLeaf', 'NumPred', 'MeanRMSE'});
writetable(paramTable, 'param_search_results.csv');

%% ==================== 7. 使用最优参数训练最终模型 ====================
fprintf('\n使用最优参数在完整训练集上训练最终模型...\n');
final_model = TreeBagger(bestParams.nTrees, X_train, y_train, ...
    'Method', 'regression', 'OOBPrediction', 'off', ...
    'MinLeafSize', bestParams.minLeaf, ...
    'NumPredictorsToSample', bestParams.numPred);

%% ==================== 8. 在验证集上评估最终模型 ====================
fprintf('\n在验证集上评估最终模型...\n');
y_pred_cell = predict(final_model, X_test);
if iscell(y_pred_cell)
    y_pred = cellfun(@str2double, y_pred_cell);
else
    y_pred = double(y_pred_cell);
end
y_pred = y_pred(:);
y_test = y_test(:);

ss_res = sum((y_test - y_pred).^2);
ss_tot = sum((y_test - mean(y_test)).^2);
r2_val   = 1 - ss_res/ss_tot;
rmse_val = sqrt(mean((y_test - y_pred).^2));
mae_val  = mean(abs(y_test - y_pred));

fprintf('\n==================== 验证集性能 ====================\n');
fprintf('R²  : %.4f\n', r2_val);
fprintf('RMSE: %.4f\n', rmse_val);
fprintf('MAE : %.4f\n', mae_val);
fprintf('====================================================\n');

%% ==================== 9. 验证集结果独立绘图（所有图统一尺寸600x500） ====================
% 放大100倍显示
y_test_display = y_test * 100;
y_pred_display = y_pred * 100;
residuals_val = y_test - y_pred;

% 图A: 验证集散点图 + 置信区间
figure('Position', [200, 100, 600, 500]);
scatter(y_test_display, y_pred_display, 50, 'filled', 'MarkerFaceAlpha', 0.6);
hold on;
min_val = min([y_test_display; y_pred_display]);
max_val = max([y_test_display; y_pred_display]);
plot([min_val max_val], [min_val max_val], 'r--', 'LineWidth', 2);
mdl = fitlm(y_test_display, y_pred_display);
[ypred_fit, yci] = predict(mdl, [min_val; max_val], 'Alpha', 0.05, 'Simultaneous', false);
plot([min_val; max_val], ypred_fit, 'b-', 'LineWidth', 2);
x_fill = [[min_val; max_val]; flipud([min_val; max_val])];
y_fill = [yci(:,1); flipud(yci(:,2))];
fill(x_fill, y_fill, [1 0.8 0.8], 'FaceAlpha', 0.5, 'EdgeColor', 'none');
xlabel('真实含水量 (%)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('预测含水量 (%)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('验证集预测 (R²=%.3f, RMSE=%.3f, MAE=%.3f)', r2_val, rmse_val, mae_val));
legend('数据点', '1:1线', '拟合线', '95% 置信区间', 'Location', 'best');
grid on; axis equal;
text(0.05, 0.95, sprintf('R² = %.4f\nRMSE = %.4f\nMAE = %.4f', r2_val, rmse_val, mae_val), ...
    'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', 'black');
saveas(gcf, 'Figure_验证集散点图.png');

% 图B: 验证集残差直方图
figure('Position', [300, 150, 600, 500]);
histogram(residuals_val, 15, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
xlabel('残差', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('频数', 'FontSize', 12, 'FontWeight', 'bold');
title('验证集残差分布', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
saveas(gcf, 'Figure_验证集残差分布.png');

% 图C: 验证集残差 vs 预测值
figure('Position', [400, 200, 600, 500]);
scatter(y_pred, residuals_val, 30, 'filled', 'MarkerFaceAlpha', 0.6);
hold on; yline(0, 'r-', 'LineWidth', 2);
xlabel('预测值', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('残差', 'FontSize', 12, 'FontWeight', 'bold');
title('残差 vs 预测值 (验证集)', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
saveas(gcf, 'Figure_残差vs预测值.png');

% 图D: 验证集排序对比图
figure('Position', [100, 250, 600, 500]);
[~, sorted_idx] = sort(y_test);
y_true_sorted = y_test(sorted_idx) * 100;
y_pred_sorted = y_pred(sorted_idx) * 100;
plot(1:length(y_test), y_true_sorted, 'r-o', 'LineWidth', 2, ...
    'MarkerSize', 5, 'MarkerFaceColor', 'r', 'DisplayName', '真实含水率');
hold on;
plot(1:length(y_test), y_pred_sorted, 'b--^', 'LineWidth', 2, ...
    'MarkerSize', 5, 'MarkerFaceColor', 'b', 'DisplayName', '预测含水率');
xlabel('样本序号 (按真实值排序)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('含水量 (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('预测值与真实值对比 (排序后)', 'FontSize', 14, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on;
saveas(gcf, 'Figure_排序对比图.png');

% 图E: 验证集残差 Q-Q 图（红色虚线理论线）
figure('Position', [200, 300, 600, 500]);
h_val = qqplot(residuals_val);
set(h_val(1), 'Marker', 'o', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', [0.2 0.6 0.8], 'MarkerSize', 5);
set(h_val(2), 'LineStyle', '--', 'Color', 'r', 'LineWidth', 1.5);
legend([h_val(1), h_val(2)], {'数据点', '理论线'}, 'Location', 'southeast');
title('验证集（30%）残差 Q-Q 图', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('标准正态分位数', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('残差分位数', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
saveas(gcf, 'Figure_验证集残差QQ图.png');

%% ==================== 10. 保存结果 ====================
cv_results_train = struct();
cv_results_train.r2_scores = r2_scores_cv;
cv_results_train.rmse_scores = rmse_scores_cv;
cv_results_train.mae_scores = mae_scores_cv;
cv_results_train.mean_r2 = mean_r2_cv;
cv_results_train.mean_rmse = mean_rmse_cv;
cv_results_train.mean_mae = mean_mae_cv;
cv_results_train.all_y_test = all_y_test_cv;
cv_results_train.all_y_pred = all_y_pred_cv;
save('cross_validation_train.mat', 'cv_results_train');

save('final_model_tuned.mat', 'final_model', 'bestParams');

val_results = table(y_test, y_pred, residuals_val, ...
    'VariableNames', {'True', 'Predicted', 'Residual'});
writetable(val_results, 'validation_predictions.csv');

%% ==================== 11. 生成综合报告 ====================
report_filename = 'model_report_final.txt';
fid = fopen(report_filename, 'w');
fprintf(fid, '随机森林含水量预测模型最终报告\n');
fprintf(fid, '================================================\n');
fprintf(fid, '生成时间: %s\n', datestr(now));
fprintf(fid, '数据文件: %s\n', filename);
fprintf(fid, '总样本数: %d\n', length(y));
fprintf(fid, '训练集样本数: %d\n', length(y_train));
fprintf(fid, '验证集样本数: %d\n', length(y_test));
fprintf(fid, '\n--- 训练集五折交叉验证（默认参数） ---\n');
fprintf(fid, '平均 R² : %.4f ± %.4f\n', mean_r2_cv, std(r2_scores_cv));
fprintf(fid, '平均 RMSE: %.4f ± %.4f\n', mean_rmse_cv, std(rmse_scores_cv));
fprintf(fid, '平均 MAE : %.4f ± %.4f\n', mean_mae_cv, std(mae_scores_cv));
fprintf(fid, '\n--- 超参数调优结果 ---\n');
fprintf(fid, '最优超参数:\n');
fprintf(fid, '  树的数量 (nTrees)         : %d\n', bestParams.nTrees);
fprintf(fid, '  最小叶子大小 (MinLeafSize) : %d\n', bestParams.minLeaf);
fprintf(fid, '  每次分裂特征数 (NumPred)   : %d\n', bestParams.numPred);
fprintf(fid, '调优交叉验证平均RMSE       : %.4f\n', bestRMSE);
fprintf(fid, '\n--- 独立验证集性能 ---\n');
fprintf(fid, 'R²  : %.4f\n', r2_val);
fprintf(fid, 'RMSE: %.4f\n', rmse_val);
fprintf(fid, 'MAE : %.4f\n', mae_val);
fprintf(fid, '\n--- 输出文件 ---\n');
fprintf(fid, '1. cross_validation_train.mat\n');
fprintf(fid, '2. final_model_tuned.mat\n');
fprintf(fid, '3. validation_predictions.csv\n');
fprintf(fid, '4. param_search_results.csv\n');
fprintf(fid, '5. model_report_final.txt\n');
fprintf(fid, '6. Figure_训练集散点图.png       - 训练集(70%)\n');
fprintf(fid, '7. Figure_训练集残差QQ图.png     - 训练集Q-Q (红色虚线)\n');
fprintf(fid, '8. Figure_验证集散点图.png       - 验证集(30%)\n');
fprintf(fid, '9. Figure_验证集残差分布.png     - 验证集直方图\n');
fprintf(fid, '10. Figure_残差vs预测值.png      - 验证集残差\n');
fprintf(fid, '11. Figure_排序对比图.png        - 验证集排序\n');
fprintf(fid, '12. Figure_验证集残差QQ图.png    - 验证集Q-Q (红色虚线)\n');
fclose(fid);

fprintf('\n所有结果已保存。报告文件: %s\n', report_filename);
fprintf('程序执行完成！\n');