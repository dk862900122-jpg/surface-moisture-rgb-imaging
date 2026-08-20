%% =====================================================
% Pore Evolution Deterioration Index (PEDI)
%
% PEDI = 0.5Pa + 0.3Np + 0.2Cp
%
% Pa : pore area ratio
% Np : pore density
% Cp : pore connectivity
%
% =====================================================


clear;
clc;
close all;



%% ===========================
% 输入图片
% ===========================

files={
'soil1.jpg'
'soil2.jpg'
'soil3.jpg'
'soil4.jpg'
};


N=length(files);



% 初始化

Pa=zeros(N,1);
Np=zeros(N,1);
Cp=zeros(N,1);



%% =====================================================
% 图像处理
% =====================================================


for i=1:N


    img=imread(files{i});


    if size(img,3)==3
        gray=rgb2gray(img);
    else
        gray=img;
    end


    gray=im2double(gray);



    %% ==========================================
    % 1. 局部背景校正
    % ==========================================


    % 去除光照影响

    background=imgaussfilt(gray,30);


    diffImg=background-gray;



    % 归一化

    diffImg=(diffImg-min(diffImg(:)))...
        /(max(diffImg(:))-min(diffImg(:)));



    %% ==========================================
    % 2. 自适应孔洞识别
    % ==========================================


    % 均值+标准差阈值

    mu=mean(diffImg(:));

    sigma=std(diffImg(:));


    k=1.2;


    bw=diffImg>mu+k*sigma;



    %% 去除小颗粒

    bw=bwareaopen(bw,80);



    %% 形态连接

    bw=imclose(bw,...
        strel('disk',4));



    %% 填充

    bw=imfill(bw,'holes');



    %% ==========================================
    % 3. 孔洞面积率 Pa
    % ==========================================


    Pa(i)=sum(bw(:))/numel(bw);




    %% ==========================================
    % 4. 孔洞数量密度 Np
    % ==========================================


    CC=bwconncomp(bw);


    poreNum=CC.NumObjects;


    Np(i)=poreNum/numel(bw);




    %% ==========================================
    % 5. 最大孔洞连通率 Cp
    % ==========================================


    stats=regionprops(bw,...
        'Area');


    if isempty(stats)

        Cp(i)=0;

    else

        areas=[stats.Area];


        Cp(i)=max(areas)/sum(areas);

    end




    %% ==========================================
    % 显示识别结果
    % ==========================================


    figure;


    subplot(1,3,1)

    imshow(gray)

    title(['Image ',num2str(i)])



    subplot(1,3,2)

    imshow(diffImg,[])

    title('Local difference')



    subplot(1,3,3)

    imshow(bw)

    title('Detected pores')



end



%% =====================================================
% 归一化
% =====================================================


Pa_n=normalize(Pa,...
    'range',[0 1]);


Np_n=normalize(Np,...
    'range',[0 1]);


Cp_n=normalize(Cp,...
    'range',[0 1]);




%% =====================================================
% PEDI计算
% =====================================================


PEDI=...
0.5*Pa_n+...
0.3*Np_n+...
0.2*Cp_n;



%% =====================================================
% 输出结果
% =====================================================


Result=table((1:N)',...
Pa,...
Np,...
Cp,...
Pa_n,...
Np_n,...
Cp_n,...
PEDI,...
'VariableNames',...
{'Image',...
'PoreArea',...
'PoreDensity',...
'Connectivity',...
'Pa_norm',...
'Np_norm',...
'Cp_norm',...
'PEDI'});


disp(Result)



%% =====================================================
% 绘制PEDI
% =====================================================


figure;


bar(PEDI)


xlabel('Image number',...
'FontName','Times New Roman',...
'FontSize',14);


ylabel('PEDI',...
'FontName','Times New Roman',...
'FontSize',14);


set(gca,...
'FontName','Times New Roman',...
'FontSize',12);


xticks(1:4)


grid on;

