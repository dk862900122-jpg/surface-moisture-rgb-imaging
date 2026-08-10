function rgb_to_hsv_lab_converter()
    % RGB_TO_HSV_LAB_CONVERTER - 主函数
    % 提供GUI界面让用户选择输入方式，执行转换并保存结果
    
    clc;
    fprintf('RGB转HSV、LAB、Lch、XYZ和CMYK颜色空间转换工具\n\n');
    
    % 选择输入方式
    disp('请选择输入方式:');
    disp('1 - 从CSV文件导入');
    disp('2 - 从Excel文件导入');
    disp('3 - 从MATLAB工作区变量导入');
    disp('4 - 手动输入RGB值');
    
    % 确保输入是标量值
    while true
        try
            choice = input('请输入选项(1-4): ');
            if isscalar(choice) && isnumeric(choice) && ismember(choice, 1:4)
                break;
            else
                disp('请输入1-4之间的整数选项');
            end
        catch
            disp('无效输入，请重新输入');
        end
    end
    
    % 获取RGB数据
    switch choice
        case 1
            [rgbData, fileName] = importFromCSV();
        case 2
            [rgbData, fileName] = importFromExcel();
        case 3
            rgbData = importFromWorkspace();
            fileName = 'workspace_data';
        case 4
            rgbData = manualInput();
            fileName = 'manual_input';
    end
    
    % 验证数据
    rgbData = validateRGBData(rgbData);
    
    % 执行转换
    [hsvData, labData, lchData, xyzData, cmykData] = convertColorSpaces(rgbData);
    
    % 显示前5行结果预览
    displayPreview(rgbData, hsvData, labData, lchData, xyzData, cmykData);
    
    % 保存结果
    saveResults(rgbData, hsvData, labData, lchData, xyzData, cmykData, fileName);
    
    fprintf('\n转换完成!\n');
end

function [rgbData, fileName] = importFromCSV()
    % 从CSV文件导入数据
    [file, path] = uigetfile('*.csv', '选择CSV文件');
    if isequal(file, 0)
        error('未选择文件');
    end
    fileName = fullfile(path, file);
    
    % 尝试自动检测是否有表头
    try
        opts = detectImportOptions(fileName);
        if any(contains(opts.VariableNames, {'R','G','B'}, 'IgnoreCase', true))
            % 有表头且包含R,G,B列名
            data = readtable(fileName);
            rgbData = [data.R, data.G, data.B];
        else
            % 无表头或不符合命名规范
            data = readmatrix(fileName);
            if size(data, 2) == 3
                rgbData = data;
            else
                error('CSV文件必须包含恰好三列数据');
            end
        end
    catch ME
        error('读取CSV文件时出错: %s', ME.message);
    end
end

function [rgbData, fileName] = importFromExcel()
    % 从Excel文件导入数据
    [file, path] = uigetfile({'*.xlsx;*.xls', 'Excel文件'}, '选择Excel文件');
    if isequal(file, 0)
        error('未选择文件');
    end
    fileName = fullfile(path, file);
    
    try
        % 读取第一张工作表
        [~, ~, raw] = xlsread(fileName);
        
        % 检查是否有表头
        if all(cellfun(@ischar, raw(1,:))) && ...
           any(contains(raw(1,:), {'R','G','B'}, 'IgnoreCase', true))
            % 有表头
            header = lower(raw(1,:));
            rCol = find(contains(header, 'r'), 1);
            gCol = find(contains(header, 'g'), 1);
            bCol = find(contains(header, 'b'), 1);
            
            if isempty(rCol) || isempty(gCol) || isempty(bCol)
                error('Excel文件中必须包含R,G,B列');
            end
            
            % 确保只提取数值数据
            dataRows = raw(2:end, [rCol, gCol, bCol]);
            if any(cellfun(@(x) ~isnumeric(x) && ~islogical(x), dataRows(:)))
                error('Excel文件中包含非数值数据');
            end
            
            rgbData = cell2mat(dataRows);
        else
            % 无表头
            if any(cellfun(@(x) ~isnumeric(x) && ~islogical(x), raw(:)))
                error('Excel文件中包含非数值数据');
            end
            
            rgbData = cell2mat(raw);
            if size(rgbData, 2) ~= 3
                error('Excel数据必须包含恰好三列');
            end
        end
    catch ME
        error('读取Excel文件时出错: %s', ME.message);
    end
end

function rgbData = importFromWorkspace()
    % 从工作区变量导入
    vars = evalin('base', 'who');
    if isempty(vars)
        error('工作区中没有变量');
    end
    
    disp('工作区中的变量:');
    disp(vars);
    
    while true
        varName = input('请输入包含RGB数据的变量名: ', 's');
        if isempty(varName)
            continue;
        end
        
        try
            rgbData = evalin('base', varName);
            break;
        catch
            disp('变量不存在，请重新输入');
        end
    end
    
    % 检查变量格式
    if ~isnumeric(rgbData) || size(rgbData, 2) ~= 3
        error('变量必须是N×3的数值矩阵');
    end
end

function rgbData = manualInput()
    % 手动输入RGB值
    while true
        n = input('要输入多少组RGB值? ');
        if isscalar(n) && isnumeric(n) && n > 0
            break;
        else
            disp('请输入一个正整数');
        end
    end
    
    rgbData = zeros(n, 3);
    
    fprintf('\n请输入RGB值(0-255)，每组一行，用空格分隔:\n');
    for i = 1:n
        while true
            str = input(sprintf('RGB值 %d/%d: ', i, n), 's');
            if isempty(str)
                continue;
            end
            
            vals = sscanf(str, '%f %f %f');
            
            if length(vals) == 3 && all(vals >= 0) && all(vals <= 255)
                rgbData(i,:) = vals;
                break;
            else
                fprintf('无效输入，请重新输入3个0-255之间的数值\n');
            end
        end
    end
end

function rgbData = validateRGBData(rgbData)
    % 验证RGB数据
    if ~isnumeric(rgbData) || size(rgbData, 2) ~= 3
        error('RGB数据必须是N×3的数值矩阵');
    end
    
    % 检查范围并转换类型
    rgbData = double(rgbData);
    
    % 自动修正超出范围的值
    rgbData(rgbData < 0) = 0;
    rgbData(rgbData > 255) = 255;
    
    % 显示统计信息
    fprintf('\nRGB数据统计:\n');
    fprintf('样本数: %d\n', size(rgbData, 1));
    fprintf('R范围: %.1f - %.1f\n', min(rgbData(:,1)), max(rgbData(:,1)));
    fprintf('G范围: %.1f - %.1f\n', min(rgbData(:,2)), max(rgbData(:,2)));
    fprintf('B范围: %.1f - %.1f\n\n', min(rgbData(:,3)), max(rgbData(:,3)));
end

function [hsvData, labData, lchData, xyzData, cmykData] = convertColorSpaces(rgbData)
    % 颜色空间转换
    fprintf('正在执行颜色空间转换...\n');
    
    % 归一化RGB到0-1范围
    rgbNormalized = rgbData / 255;
    
    % 预分配结果矩阵
    n = size(rgbData, 1);
    hsvData = zeros(n, 3);
    labData = zeros(n, 3);
    lchData = zeros(n, 3);
    xyzData = zeros(n, 3);
    cmykData = zeros(n, 4);
    
    % D65标准光源 (色温6500K的标准日光光源):cite[4]:cite[9]
    D65 = [0.95047, 1.00000, 1.08883];
    
    % 创建ICC颜色转换结构（使用可感知的渲染意图）
    try
        % 使用MATLAB的ICC颜色管理工具
        cform = makecform('icc', ...
            'SourceRenderingIntent', 'Perceptual', ...
            'DestRenderingIntent', 'Perceptual', ...
            'SourceWhitePoint', D65, ...
            'DestWhitePoint', D65);
    catch
        % 如果ICC功能不可用，使用备用方法
        cform = [];
        fprintf('警告: ICC颜色管理不可用，使用备用CMYK转换方法\n');
    end
    
    for i = 1:n
        % 转换为HSV
        hsv = rgb2hsv(rgbNormalized(i,:));
        hsvData(i,:) = [hsv(1)*360, hsv(2)*100, hsv(3)*100]; % 转换为常用范围
        
        % RGB转XYZ
        xyz = rgb2xyz(rgbNormalized(i,:));
        xyzData(i,:) = xyz * 100; % 转换为常用范围(0-100)
        
        % XYZ转LAB
        xn = xyz(1)/D65(1);
        yn = xyz(2)/D65(2);
        zn = xyz(3)/D65(3);
        
        % 计算L分量
        if yn > 0.008856
            L = 116 * nthroot(yn, 3) - 16;
        else
            L = 903.3 * yn;
        end
        
        % 计算a和b分量
        fx = (xn > 0.008856) * nthroot(xn, 3) + (xn <= 0.008856) * (7.787 * xn + 16/116);
        fy = (yn > 0.008856) * nthroot(yn, 3) + (yn <= 0.008856) * (7.787 * yn + 16/116);
        fz = (zn > 0.008856) * nthroot(zn, 3) + (zn <= 0.008856) * (7.787 * zn + 16/116);
        
        a = 500 * (fx - fy);
        b = 200 * (fy - fz);
        
        labData(i,:) = [L, a, b];
        
        % LAB转LCH
        L_val = L;
        C_val = sqrt(a^2 + b^2);
        H_val = mod(atan2(b, a) * 180/pi, 360); % 转换为角度并确保在0-360范围内
        lchData(i,:) = [L_val, C_val, H_val];
        
        % RGB转CMYK (使用ICC配置文件方法)
        if ~isempty(cform)
            % 使用ICC颜色转换
            cmyk_normalized = applycform(rgbNormalized(i,:), cform);
            cmykData(i,:) = cmyk_normalized * 100; % 转换为百分比
        else
            % 备用方法：使用标准RGB到CMYK转换
            r = rgbNormalized(i,1);
            g = rgbNormalized(i,2);
            b_val = rgbNormalized(i,3);
            
            k = 1 - max([r, g, b_val]);
            if k == 1
                % 纯黑色
                c = 0;
                m = 0;
                y = 0;
            else
                c = (1 - r - k) / (1 - k);
                m = (1 - g - k) / (1 - k);
                y = (1 - b_val - k) / (1 - k);
            end
            
            cmykData(i,:) = [c, m, y, k] * 100; % 转换为百分比
        end
    end
    
    fprintf('转换完成!\n');
end

function displayPreview(rgbData, hsvData, labData, lchData, xyzData, cmykData)
    % 显示前5行结果预览
    fprintf('\n前5行结果预览:\n');
    fprintf('   R     G     B     H(°)   S(%%)   V(%%)   L       a       b\n');
    fprintf('----------------------------------------------------------------\n');
    
    n = min(5, size(rgbData, 1));
    for i = 1:n
        fprintf('%4.0f  %4.0f  %4.0f  %5.1f  %5.1f  %5.1f  %6.2f  %7.2f  %7.2f\n', ...
            rgbData(i,1), rgbData(i,2), rgbData(i,3), ...
            hsvData(i,1), hsvData(i,2), hsvData(i,3), ...
            labData(i,1), labData(i,2), labData(i,3));
    end
    
    fprintf('\n   L       C       H(°)   X       Y       Z       C(%%%%)   M(%%%%)   Y(%%%%)   K(%%%%) \n');
    fprintf('----------------------------------------------------------------------------------------\n');
    for i = 1:n
        fprintf('%6.2f  %6.2f  %5.1f  %6.2f  %6.2f  %6.2f  %6.1f  %6.1f  %6.1f  %6.1f\n', ...
            lchData(i,1), lchData(i,2), lchData(i,3), ...
            xyzData(i,1), xyzData(i,2), xyzData(i,3), ...
            cmykData(i,1), cmykData(i,2), cmykData(i,3), cmykData(i,4));
    end
    fprintf('\n');
end

function saveResults(rgbData, hsvData, labData, lchData, xyzData, cmykData, baseName)
    % 保存结果
    % 创建结果表格
    resultTable = table(...
        rgbData(:,1), rgbData(:,2), rgbData(:,3), ...
        hsvData(:,1), hsvData(:,2), hsvData(:,3), ...
        labData(:,1), labData(:,2), labData(:,3), ...
        lchData(:,1), lchData(:,2), lchData(:,3), ...
        xyzData(:,1), xyzData(:,2), xyzData(:,3), ...
        cmykData(:,1), cmykData(:,2), cmykData(:,3), cmykData(:,4), ...
        'VariableNames', {'R', 'G', 'B', ...
                          'H', 'S', 'V', ...
                          'L', 'a', 'b', ...
                          'L_lch', 'C', 'H_lch', ...
                          'X', 'Y', 'Z', ...
                          'C_cmyk', 'M', 'Y_cmyk', 'K'});
    
    % 选择保存格式
    disp('请选择保存格式:');
    disp('1 - CSV文件');
    disp('2 - Excel文件');
    disp('3 - MAT文件');
    disp('4 - 保存到工作区变量');
    
    % 确保输入是标量值
    while true
        try
            choice = input('请输入选项(1-4): ');
            if isscalar(choice) && isnumeric(choice) && ismember(choice, 1:4)
                break;
            else
                disp('请输入1-4之间的整数选项');
            end
        catch
            disp('无效输入，请重新输入');
        end
    end
    
    switch choice
        case 1
            [file, path] = uiputfile('*.csv', '保存CSV文件', [baseName '_converted.csv']);
            if ~isequal(file, 0)
                writetable(resultTable, fullfile(path, file));
                fprintf('结果已保存到: %s\n', fullfile(path, file));
            else
                disp('操作已取消');
            end
        case 2
            [file, path] = uiputfile({'*.xlsx';'*.xls'}, '保存Excel文件', [baseName '_converted.xlsx']);
            if ~isequal(file, 0)
                writetable(resultTable, fullfile(path, file));
                fprintf('结果已保存到: %s\n', fullfile(path, file));
            else
                disp('操作已取消');
            end
        case 3
            [file, path] = uiputfile('*.mat', '保存MAT文件', [baseName '_converted.mat']);
            if ~isequal(file, 0)
                save(fullfile(path, file), 'resultTable');
                fprintf('结果已保存到: %s\n', fullfile(path, file));
            else
                disp('操作已取消');
            end
        case 4
            varName = '';
            while isempty(varName)
                varName = input('请输入变量名: ', 's');
                if isempty(varName) || ~isvarname(varName)
                    disp('无效的变量名，请重新输入');
                    varName = '';
                end
            end
            assignin('base', varName, resultTable);
            fprintf('结果已保存到工作区变量: %s\n', varName);
    end
end