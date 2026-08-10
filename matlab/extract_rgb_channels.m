clear;
clc;

% 设置文件夹路径
imageFolder = '裁剪';
outputFile = 'GaussianFitResults.xlsx';

% 获取图片列表
filePattern = fullfile(imageFolder, '*.jpg');
jpegFiles = dir(filePattern);
numFiles = length(jpegFiles);

% 检查文件数量
if numFiles == 0
    error('未找到图片文件，请检查路径: %s', imageFolder);
end

% 提取文件名中的数字（用于排序）并保留原始文件名
fileNames = {jpegFiles.name};
fileNumbers = zeros(1, numFiles);
for i = 1:numFiles
    % 尝试匹配 % 后面的数字（例如 %123）用于排序
    percentNum = regexp(fileNames{i}, '%(\d+)', 'tokens');
    if ~isempty(percentNum)
        fileNumbers(i) = str2double(percentNum{1}{1});
    else
        % 如果没有 % 符号，则提取所有数字并组合
        numStr = regexp(fileNames{i}, '\d+', 'match');
        if isempty(numStr)
            fileNumbers(i) = i;   % 无数字时使用索引
        else
            combinedNum = strjoin(numStr, '');
            fileNumbers(i) = str2double(combinedNum);
        end
    end
end

% 按提取的数字排序文件（确保处理顺序与之前一致）
[sortedNums, sortIdx] = sort(fileNumbers);
sortedFiles = jpegFiles(sortIdx);
sortedOriginalNames = {sortedFiles.name};  % 排序后的原始文件名

% 预分配结果存储（使用 cell 数组，因为文件名是字符串）
results = cell(numFiles, 4); % 列：原始文件名, R_mu, G_mu, B_mu

% 创建等待条
hWait = waitbar(0, '开始处理图片...', 'Name', '批量处理进度');

% 循环处理每张图片
for k = 1:numFiles
    % 更新等待条
    waitbar(k/numFiles, hWait, sprintf('处理中: %d/%d (%.1f%%)', k, numFiles, k/numFiles*100));
    
    % 读取当前图片
    baseFileName = sortedOriginalNames{k};
    fullFileName = fullfile(imageFolder, baseFileName);
    fprintf('\n处理文件: %s\n', baseFileName);
    
    try
        f = imread(fullFileName);
        [m, n, p] = size(f);
        
        % 初始化直方图数据
        histR = zeros(1, 256);
        histG = zeros(1, 256);
        histB = zeros(1, 256);
        
        % 计算各通道直方图
        for i = 1:m
            for j = 1:n
                histR(f(i,j,1)+1) = histR(f(i,j,1)+1) + 1;
                histG(f(i,j,2)+1) = histG(f(i,j,2)+1) + 1;
                histB(f(i,j,3)+1) = histB(f(i,j,3)+1) + 1;
            end
        end
        
        % 创建灰度级向量
        x = 0:255;
        
        % 红色通道拟合
        [fitR, ~] = createFitStandard(x, histR);
        
        % 绿色通道拟合
        [fitG, ~] = createFitStandard(x, histG);
        
        % 蓝色通道拟合
        [fitB, ~] = createFitStandard(x, histB);
        
        % 存储结果：原始文件名（字符串）和三个拟合均值（数值）
        results{k, 1} = baseFileName;
        results{k, 2} = fitR.mu;
        results{k, 3} = fitG.mu;
        results{k, 4} = fitB.mu;
        
        fprintf('R_mu = %.2f, G_mu = %.2f, B_mu = %.2f\n', ...
                fitR.mu, fitG.mu, fitB.mu);
                
    catch ME
        warning('处理文件 %s 时出错: %s', baseFileName, ME.message);
        results{k, 1} = baseFileName;
        results{k, 2} = NaN;
        results{k, 3} = NaN;
        results{k, 4} = NaN;
    end
end

% 关闭等待条
close(hWait);

% 将结果转换为表格
resultTable = cell2table(results, 'VariableNames', ...
    {'FileName', 'R_mu', 'G_mu', 'B_mu'});

% 保存到Excel
writetable(resultTable, outputFile);
fprintf('\n结果已保存到: %s\n', outputFile);

% 显示结果预览
disp('结果预览:');
disp(head(resultTable));

% ===== 标准高斯拟合函数 =====
function [fitresult, gof] = createFitStandard(x, y)
    % 创建拟合对象
    [xData, yData] = prepareCurveData(x, y);
    
    % 设置自定义高斯模型 (标准形式)
    % f(x) = a/(σ√(2π)) * exp(-(x-μ)^2/(2σ^2))
    ft = fittype('a/(sigma*sqrt(2*pi)) * exp(-(x-mu)^2/(2*sigma^2))', ...
        'independent', 'x', ...
        'coefficients', {'a', 'mu', 'sigma'});
    
    % 计算初始参数估计
    totalCount = sum(y);  % 总像素数（曲线下面积）
    weightedSum = sum(x .* y);
    mu0 = weightedSum / totalCount;  % 加权平均值作为μ的初始值
    
    % 计算加权标准差作为σ的初始值
    variance = sum(y .* (x - mu0).^2) / totalCount;
    sigma0 = sqrt(variance);
    
    % 设置拟合选项
    opts = fitoptions('Method', 'NonlinearLeastSquares');
    opts.StartPoint = [totalCount, mu0, sigma0]; % [a, mu, sigma]
    opts.Lower = [0, min(x), 0.1];   % a>0, mu在范围内, sigma>0
    opts.Upper = [Inf, max(x), 100]; % 设置合理的上限
    
    % 执行拟合
    [fitresult, gof] = fit(xData, yData, ft, opts);
end